#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""
S2-M7 model analysis helper.

Prefers Digest AI (digestai / digest package) when importable.
Falls back to a pure-ONNX inventory analysis so offline reports still work
when Digest AI cannot install (e.g. host Python outside 3.9–3.10).

NEVER claims NPU execution from analysis statistics alone.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _try_digest_analyze(model_path: Path, out_dir: Path) -> dict[str, Any] | None:
    """Run Digest AI API if installed. Returns result dict or None."""
    try:
        from digest.model_class.digest_onnx_model import DigestOnnxModel  # type: ignore
        from utils.onnx_utils import get_dynamic_input_dims, load_onnx  # type: ignore
    except Exception:
        try:
            # Some installs use digest.* only
            from digest.model_class.digest_onnx_model import DigestOnnxModel  # type: ignore

            load_onnx = None  # type: ignore
            get_dynamic_input_dims = None  # type: ignore
        except Exception:
            return None

    model_name = model_path.stem
    try:
        if load_onnx is not None:
            model_proto = load_onnx(str(model_path), False)
            dynamic_dims = get_dynamic_input_dims(model_proto) if get_dynamic_input_dims else []
            digest_model = DigestOnnxModel(
                model_proto, onnx_filepath=str(model_path), model_name=model_name
            )
        else:
            import onnx

            model_proto = onnx.load(str(model_path))
            dynamic_dims = []
            digest_model = DigestOnnxModel(
                model_proto, onnx_filepath=str(model_path), model_name=model_name
            )

        summary_txt = out_dir / f"{model_name}_summary.txt"
        summary_yaml = out_dir / f"{model_name}_summary.yaml"
        nodes_csv = out_dir / f"{model_name}_nodes.csv"
        node_type_csv = out_dir / f"{model_name}_node_type_counts.csv"

        if hasattr(digest_model, "save_text_report"):
            digest_model.save_text_report(str(summary_txt))
        if hasattr(digest_model, "save_yaml_report"):
            digest_model.save_yaml_report(str(summary_yaml))
        if hasattr(digest_model, "save_nodes_csv_report"):
            digest_model.save_nodes_csv_report(str(nodes_csv))
        if hasattr(digest_model, "save_node_type_counts_csv_report"):
            digest_model.save_node_type_counts_csv_report(str(node_type_csv))

        return {
            "engine": "digestai",
            "model_name": model_name,
            "model_path": str(model_path),
            "opset": getattr(digest_model, "opset", None),
            "parameters": getattr(digest_model, "parameters", None),
            "flops": getattr(digest_model, "flops", None),
            "dynamic_input_dims": list(dynamic_dims) if dynamic_dims else [],
            "reports": {
                "summary_txt": str(summary_txt) if summary_txt.exists() else None,
                "summary_yaml": str(summary_yaml) if summary_yaml.exists() else None,
                "nodes_csv": str(nodes_csv) if nodes_csv.exists() else None,
                "node_type_csv": str(node_type_csv) if node_type_csv.exists() else None,
            },
            "npu_execution_claimed": False,
            "note": "Digest AI statistics are model structure metrics only — not NPU inference proof.",
        }
    except Exception as exc:  # noqa: BLE001
        return {
            "engine": "digestai-error",
            "error": str(exc),
            "model_path": str(model_path),
            "npu_execution_claimed": False,
        }


def _fallback_onnx_analyze(model_path: Path, out_dir: Path) -> dict[str, Any]:
    """Pure ONNX analysis when Digest AI is unavailable."""
    import onnx
    from onnx import numpy_helper

    model_name = model_path.stem
    model = onnx.load(str(model_path))
    graph = model.graph

    opset = None
    if model.opset_import:
        opset = int(model.opset_import[0].version)

    op_counts: Counter[str] = Counter(n.op_type for n in graph.node)
    total_nodes = sum(op_counts.values())

    # Parameter tensor element count (initializers)
    param_elems = 0
    param_bytes = 0
    for init in graph.initializer:
        arr = numpy_helper.to_array(init)
        param_elems += int(arr.size)
        param_bytes += int(arr.nbytes)

    def tensor_info(value_infos):
        rows = []
        for vi in value_infos:
            shape = []
            dtype = None
            t = vi.type.tensor_type
            dtype = int(t.elem_type) if t.elem_type else None
            if t.HasField("shape"):
                for d in t.shape.dim:
                    if d.dim_value:
                        shape.append(int(d.dim_value))
                    elif d.dim_param:
                        shape.append(d.dim_param)
                    else:
                        shape.append("?")
            rows.append({"name": vi.name, "shape": shape, "elem_type": dtype})
        return rows

    inputs = tensor_info(graph.input)
    outputs = tensor_info(graph.output)

    # Dynamic dims heuristic
    dynamic = []
    for item in inputs:
        for dim in item.get("shape") or []:
            if isinstance(dim, str) or dim == "?":
                dynamic.append(f"{item['name']}:{dim}")

    result = {
        "engine": "onnx-fallback",
        "model_name": model_name,
        "model_path": str(model_path),
        "ir_version": int(model.ir_version) if model.ir_version else None,
        "opset": opset,
        "producer_name": model.producer_name or None,
        "graph_name": graph.name or None,
        "node_count": total_nodes,
        "op_type_counts": dict(op_counts.most_common()),
        "initializer_count": len(graph.initializer),
        "parameter_elements": param_elems,
        "parameter_bytes": param_bytes,
        "parameters": param_elems,  # alias for Digest-like field
        "flops": None,  # FLOPs need Digest AI or shape-static tooling
        "inputs": inputs,
        "outputs": outputs,
        "dynamic_input_dims": dynamic,
        "npu_execution_claimed": False,
        "note": (
            "ONNX fallback analysis (Digest AI not installed or not importable). "
            "Statistics are structural only — not NPU inference proof. "
            "Install Digest AI with Python 3.9–3.10 for FLOPs/histograms via Digest API."
        ),
    }

    summary_path = out_dir / f"{model_name}_summary.txt"
    lines = [
        f"Model: {model_name}",
        f"Path: {model_path}",
        f"Engine: onnx-fallback",
        f"Opset: {opset}",
        f"IR version: {result['ir_version']}",
        f"Nodes: {total_nodes}",
        f"Parameter elements: {param_elems}",
        f"Parameter bytes: {param_bytes}",
        f"FLOPs: n/a (requires Digest AI)",
        "",
        "Op type counts:",
    ]
    for op, count in op_counts.most_common():
        lines.append(f"  {op}: {count}")
    lines.extend(["", "Inputs:"])
    for inp in inputs:
        lines.append(f"  {inp['name']} shape={inp['shape']} elem_type={inp['elem_type']}")
    lines.extend(["", "Outputs:"])
    for out in outputs:
        lines.append(f"  {out['name']} shape={out['shape']} elem_type={out['elem_type']}")
    lines.extend(
        [
            "",
            "IMPORTANT: This report does NOT prove NPU execution.",
            "Use profiled EP verification (npu_ep_verify) or Lemonade smokes for inference truth.",
        ]
    )
    summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    json_path = out_dir / f"{model_name}_summary.json"
    json_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")

    result["reports"] = {
        "summary_txt": str(summary_path),
        "summary_json": str(json_path),
    }
    return result


def analyze_model(model_path: Path, out_dir: Path, prefer_digest: bool = True) -> dict[str, Any]:
    out_dir.mkdir(parents=True, exist_ok=True)
    if prefer_digest:
        digest_result = _try_digest_analyze(model_path, out_dir)
        if digest_result is not None and digest_result.get("engine") == "digestai":
            return digest_result
        if digest_result is not None and digest_result.get("engine") == "digestai-error":
            # Fall through to onnx after recording error
            fallback = _fallback_onnx_analyze(model_path, out_dir)
            fallback["digest_error"] = digest_result.get("error")
            return fallback
    return _fallback_onnx_analyze(model_path, out_dir)


def find_onnx_models(roots: list[Path], limit: int = 5) -> list[Path]:
    found: list[Path] = []
    for root in roots:
        if not root.exists():
            continue
        if root.is_file() and root.suffix.lower() == ".onnx":
            found.append(root)
            continue
        if root.is_dir():
            for p in sorted(root.rglob("*.onnx")):
                # Skip site-packages noise unless explicitly under models/
                parts = {x.lower() for x in p.parts}
                if "site-packages" in parts and "models" not in str(p):
                    continue
                found.append(p)
                if len(found) >= limit:
                    return found
    return found[:limit]


def write_markdown_report(results: list[dict[str, Any]], path: Path, meta: dict[str, Any]) -> None:
    lines = [
        "# Digest / Model Analysis Report (S2-M7)",
        "",
        f"Generated: {meta.get('timestamp', '')}",
        f"Profile: {meta.get('profile', '')} | Mode: {meta.get('mode', '')} | Offline: {meta.get('offline', '')}",
        f"Status: **{meta.get('status', 'WARN')}**",
        "",
        "## Policy",
        "",
        "- Digest AI / ONNX analysis is **diagnostics only**.",
        "- **Never** treat parameters, FLOPs, or op histograms as NPU inference proof.",
        "- Inference truth sources: profiled EP verification (`npu_ep_verify`) and Lemonade smokes (S2-M6).",
        "",
        f"Engine preference: Digest AI when importable; ONNX fallback otherwise.",
        "",
    ]
    if not results:
        lines.extend(
            [
                "## Results",
                "",
                "No ONNX models analyzed. Stage a model under `.ai370-ai/models/` or set `DIGEST_MODEL_PATH`.",
                "",
            ]
        )
    for r in results:
        lines.extend(
            [
                f"## {r.get('model_name', 'model')}",
                "",
                f"- Engine: `{r.get('engine')}`",
                f"- Path: `{r.get('model_path')}`",
                f"- Opset: {r.get('opset')}",
                f"- Parameters (elems): {r.get('parameters')}",
                f"- FLOPs: {r.get('flops')}",
                f"- Nodes: {r.get('node_count', 'n/a')}",
                f"- NPU execution claimed: **{r.get('npu_execution_claimed', False)}**",
                f"- Note: {r.get('note', '')}",
                "",
            ]
        )
        if r.get("op_type_counts"):
            lines.append("### Op type counts (top)")
            lines.append("")
            for op, count in list(r["op_type_counts"].items())[:15]:
                lines.append(f"- `{op}`: {count}")
            lines.append("")
        if r.get("reports"):
            lines.append("### Artifacts")
            lines.append("")
            for k, v in r["reports"].items():
                if v:
                    lines.append(f"- {k}: `{v}`")
            lines.append("")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="S2-M7 Digest/ONNX model analysis")
    parser.add_argument("--model", action="append", default=[], help="ONNX file or directory (repeatable)")
    parser.add_argument("--out-dir", required=True, help="Output directory for analysis artifacts")
    parser.add_argument("--report-json", required=True, help="Aggregate JSON path")
    parser.add_argument("--report-md", required=True, help="Markdown report path")
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--profile", default="ai370")
    parser.add_argument("--mode", default="safe")
    parser.add_argument("--offline", default="false")
    parser.add_argument("--no-digest", action="store_true", help="Force ONNX fallback")
    args = parser.parse_args(argv)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    roots = [Path(p) for p in args.model] if args.model else []
    models = find_onnx_models(roots, limit=args.limit) if roots else []

    results: list[dict[str, Any]] = []
    for model_path in models:
        results.append(analyze_model(model_path, out_dir, prefer_digest=not args.no_digest))

    engines = {r.get("engine") for r in results}
    if not results:
        status = "WARN"
        detail = "No ONNX models found to analyze."
    elif any(r.get("engine") == "digestai" for r in results):
        status = "PASS"
        detail = f"Analyzed {len(results)} model(s) with Digest AI."
    elif any(r.get("engine") == "onnx-fallback" for r in results):
        status = "PASS"
        detail = (
            f"Analyzed {len(results)} model(s) with ONNX fallback "
            "(Digest AI not available on this Python)."
        )
    else:
        status = "WARN"
        detail = "Analysis attempted with errors."

    meta = {
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "profile": args.profile,
        "mode": args.mode,
        "offline": args.offline,
        "status": status,
        "engines": sorted(e for e in engines if e),
        "detail": detail,
        "npu_execution_claimed": False,
    }

    aggregate = {
        "tier": 2,
        "phase": "analyze-model-digest",
        "milestone": "S2-M7",
        "status": status,
        "profile": args.profile,
        "mode": args.mode,
        "offline": args.offline == "true",
        "models_analyzed": len(results),
        "results": results,
        "npu_execution_claimed": False,
        "policy": "Diagnostics only; not NPU inference proof.",
        "detail": detail,
    }

    Path(args.report_json).write_text(json.dumps(aggregate, indent=2) + "\n", encoding="utf-8")
    write_markdown_report(results, Path(args.report_md), meta)
    print(json.dumps({"status": status, "models_analyzed": len(results), "detail": detail}))
    return 0 if status != "FAIL" else 1


if __name__ == "__main__":
    raise SystemExit(main())
