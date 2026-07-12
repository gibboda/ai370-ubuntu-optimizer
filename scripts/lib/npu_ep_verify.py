# SPDX-License-Identifier: GPL-3.0-only
"""Helpers to verify that ONNX Runtime actually executed on an NPU EP.

ORT may list VitisAIExecutionProvider and even put it first in
``session.get_providers()`` while every kernel still runs on
CPUExecutionProvider (operator not supported / partition empty). Smoke
PASS must require profiled node execution on the requested EP.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import statistics
import tempfile
import time
from collections import Counter
from pathlib import Path
from typing import Any

DEFAULT_PROVIDER_TOKENS = ("vitis", "vai", "ryzen", "xilinx", "amd", "xdna")


def is_amd_provider(name: str, tokens: tuple[str, ...] = DEFAULT_PROVIDER_TOKENS) -> bool:
    lower = (name or "").lower()
    return any(token in lower for token in tokens)


def find_vaip_config() -> str:
    """Locate vaip_config.json from the Ryzen AI / VOE install tree."""
    candidates: list[Path] = []
    env_roots = [
        os.environ.get("RYZEN_AI_INSTALLATION_PATH", ""),
        os.environ.get("VITIS_AI_ROOT", ""),
        os.environ.get("XLNX_VART_FIRMWARE", ""),
    ]
    for root in env_roots:
        if not root:
            continue
        base = Path(root)
        candidates.extend(
            [
                base / "voe-4.0-linux_x86_64" / "vaip_config.json",
                base / "vaip_config.json",
                base.parent / "voe-4.0-linux_x86_64" / "vaip_config.json",
            ]
        )
        # Installation path sometimes points at .../ryzen-ai/venv
        candidates.append(base / "lib" / "python3.12" / "site-packages" / "voe-4.0-linux_x86_64" / "vaip_config.json")

    try:
        import onnxruntime as ort

        ort_file = Path(ort.__file__).resolve()
        for parent in [ort_file.parent, *ort_file.parents[:8]]:
            candidates.extend(
                [
                    parent / "voe-4.0-linux_x86_64" / "vaip_config.json",
                    parent / "site-packages" / "voe-4.0-linux_x86_64" / "vaip_config.json",
                    parent / "vaip_config.json",
                ]
            )
    except Exception:
        pass

    seen: set[str] = set()
    for path in candidates:
        try:
            resolved = str(path.resolve())
        except Exception:
            continue
        if resolved in seen:
            continue
        seen.add(resolved)
        if path.is_file():
            return resolved
    return ""


def parse_vaiml_summary(cache_dir: str | Path | None) -> dict[str, Any]:
    """Parse VAIML preliminary summary if the EP wrote one under cacheDir."""
    info: dict[str, Any] = {
        "summary_path": "",
        "operators_supported": None,
        "operators_total": None,
        "subgraphs_supported": None,
        "raw_excerpt": "",
    }
    if not cache_dir:
        return info
    root = Path(cache_dir)
    if not root.is_dir():
        return info
    matches = sorted(root.rglob("preliminary-vaiml-pass-summary.txt"))
    if not matches:
        return info
    path = matches[0]
    text = path.read_text(encoding="utf-8", errors="replace")
    info["summary_path"] = str(path)
    info["raw_excerpt"] = text[:800]
    m_ops = re.search(
        r"Number of operators supported by VAIML:\s*(\d+)",
        text,
        re.IGNORECASE,
    )
    if m_ops:
        info["operators_supported"] = int(m_ops.group(1))
    m_total = re.search(
        r"Number of operators in the model:\s*(\d+)",
        text,
        re.IGNORECASE,
    )
    if m_total:
        info["operators_total"] = int(m_total.group(1))
    m_sub = re.search(
        r"Number of subgraphs supported by VAIML:\s*(\d+)",
        text,
        re.IGNORECASE,
    )
    if m_sub:
        info["subgraphs_supported"] = int(m_sub.group(1))
    return info


def analyze_ort_profile(
    profile_path: str | Path,
    requested_provider: str,
    tokens: tuple[str, ...] = DEFAULT_PROVIDER_TOKENS,
) -> dict[str, Any]:
    """Return provider counts from an ORT JSON profile and whether EP ran."""
    counts: Counter[str] = Counter()
    path = Path(profile_path)
    if path.is_file():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, list):
                for event in data:
                    if not isinstance(event, dict):
                        continue
                    args = event.get("args") or {}
                    if isinstance(args, dict) and "provider" in args:
                        counts[str(args["provider"])] += 1
        except Exception:
            pass

    total = sum(counts.values())
    requested_hits = int(counts.get(requested_provider, 0))
    amd_hits = sum(n for p, n in counts.items() if is_amd_provider(p, tokens))
    cpu_hits = sum(n for p, n in counts.items() if "cpu" in p.lower())

    # Actual EP execution: at least one profiled node on the requested (or any AMD) EP.
    if is_amd_provider(requested_provider, tokens):
        ep_executed = amd_hits > 0
    else:
        ep_executed = requested_hits > 0 or (
            total > 0 and "cpu" in requested_provider.lower() and cpu_hits > 0
        )

    return {
        "profile_path": str(path) if path else "",
        "node_provider_counts": dict(counts),
        "profiled_nodes": total,
        "requested_provider_nodes": requested_hits,
        "amd_provider_nodes": amd_hits,
        "cpu_provider_nodes": cpu_hits,
        "ep_executed": bool(ep_executed),
    }


def run_provider_benchmark(
    model_file: str | Path,
    provider: str,
    *,
    input_feed: dict[str, Any],
    warmup: int = 5,
    runs: int = 25,
    tokens: tuple[str, ...] = DEFAULT_PROVIDER_TOKENS,
    require_ep_execution: bool | None = None,
    enable_vitis_options: bool = True,
) -> dict[str, Any]:
    """Run a timed InferenceSession and verify profiled EP assignment.

    When ``require_ep_execution`` is True (default for AMD providers), the
    result is not a success unless ORT profiling shows at least one node
    executed on the requested/AMD execution provider.
    """
    import onnxruntime as ort

    if require_ep_execution is None:
        require_ep_execution = is_amd_provider(provider, tokens)

    prof_dir = tempfile.mkdtemp(prefix="ai370-ort-prof-")
    cache_dir = tempfile.mkdtemp(prefix="ai370-vai-cache-") if is_amd_provider(provider, tokens) else ""
    profile_path = ""
    vaiml: dict[str, Any] = {}
    session_providers: list[str] = []
    note_parts: list[str] = []

    try:
        so = ort.SessionOptions()
        so.enable_profiling = True
        so.profile_file_prefix = str(Path(prof_dir) / "ort")

        provider_options = None
        if enable_vitis_options and is_amd_provider(provider, tokens):
            opts: dict[str, str] = {
                "cacheDir": cache_dir,
                "cacheKey": "ai370_npu_smoke",
            }
            config = find_vaip_config()
            if config:
                opts["config_file"] = config
            else:
                note_parts.append("vaip_config.json not found; running without config_file")
            provider_options = [opts]

        if provider_options is not None:
            sess = ort.InferenceSession(
                str(model_file),
                sess_options=so,
                providers=[provider],
                provider_options=provider_options,
            )
        else:
            sess = ort.InferenceSession(
                str(model_file),
                sess_options=so,
                providers=[provider],
            )

        session_providers = list(sess.get_providers() or [])
        actual_provider = session_providers[0] if session_providers else provider

        for _ in range(max(0, warmup)):
            sess.run(None, input_feed)

        timings: list[float] = []
        for _ in range(max(1, runs)):
            start = time.perf_counter()
            sess.run(None, input_feed)
            timings.append((time.perf_counter() - start) * 1000.0)

        try:
            profile_path = sess.end_profiling() or ""
        except Exception as exc:
            note_parts.append(f"end_profiling failed: {type(exc).__name__}: {exc}")
            profile_path = ""

        profile_info = analyze_ort_profile(profile_path, provider, tokens)
        if cache_dir:
            vaiml = parse_vaiml_summary(cache_dir)

        session_ok = actual_provider == provider or (
            "cpu" in provider.lower() and "cpu" in (actual_provider or "").lower()
        )
        ep_executed = bool(profile_info.get("ep_executed"))

        # Prefer profile evidence; also fail closed if session fell back.
        if require_ep_execution:
            verified = bool(session_ok and ep_executed)
        else:
            verified = bool(session_ok)
            # CPU path: profile should show CPU nodes when available.
            if profile_info.get("profiled_nodes", 0) > 0 and not ep_executed:
                verified = False

        status = "pass" if verified else ("fail" if require_ep_execution else "warn")
        if not session_ok:
            note_parts.append(f"requested {provider} but session used {actual_provider}")
        if require_ep_execution and session_ok and not ep_executed:
            counts = profile_info.get("node_provider_counts") or {}
            note_parts.append(
                "session listed "
                f"{actual_provider} but ORT profiling shows no nodes executed on that EP "
                f"(node providers: {counts or 'none'}). "
                "Graph likely fell back to CPU (unsupported ops / empty VAIML partition)."
            )
            if vaiml.get("operators_supported") == 0:
                note_parts.append(
                    "VAIML summary reports 0 operators supported on NPU for this smoke model."
                )

        return {
            "requested_provider": provider,
            "actual_provider": actual_provider,
            "session_providers": session_providers,
            "runs": len(timings),
            "mean_ms": statistics.fmean(timings) if timings else None,
            "median_ms": statistics.median(timings) if timings else None,
            "min_ms": min(timings) if timings else None,
            "max_ms": max(timings) if timings else None,
            "ep_executed": ep_executed,
            "ep_verified": verified,
            "status": status,
            "note": "; ".join(note_parts),
            "profile": profile_info,
            "vaiml": vaiml,
        }
    finally:
        shutil.rmtree(prof_dir, ignore_errors=True)
        if cache_dir:
            shutil.rmtree(cache_dir, ignore_errors=True)
