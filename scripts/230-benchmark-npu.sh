#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M2: local NPU benchmark/diagnostic report for AMD Ryzen AI / Vitis AI EP.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/npu-venv.sh
source "$PROJECT_ROOT/scripts/lib/npu-venv.sh"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
# Prefer Ryzen AI venv so NPU benchmarks can see VitisAIExecutionProvider.
# XRT + VOE/flexml LD_LIBRARY_PATH are required or EP silently falls back to CPU.
prepare_npu_runtime_env "$PROJECT_ROOT"
VENV_PYTHON="$(resolve_npu_python "$PROJECT_ROOT" || true)"
VENV_SOURCE="$(npu_python_source_label "${VENV_PYTHON:-}")"
BENCHMARK_JSON="$LATEST_DIR/npu-benchmark.json"
BENCHMARK_MD="$LATEST_DIR/npu-benchmark.md"

main() {
  mkdir -p "$LATEST_DIR"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent NPU benchmark configuration is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local python_bin="python3"
  if [[ -n "${VENV_PYTHON:-}" && -x "$VENV_PYTHON" ]]; then
    python_bin="$VENV_PYTHON"
  fi

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" \
  VENV_PYTHON="${VENV_PYTHON:-$python_bin}" VENV_SOURCE="${VENV_SOURCE:-other}" \
  PROJECT_ROOT="$PROJECT_ROOT" \
  "$python_bin" - "$BENCHMARK_JSON" "$BENCHMARK_MD" <<'PY'
import datetime
import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path

json_path = Path(sys.argv[1])
md_path = Path(sys.argv[2])
profile = os.environ["PROFILE"]
mode = os.environ["MODE"]
persistence = os.environ["PERSISTENCE"]
offline = os.environ["OFFLINE"] == "true"
venv_python = os.environ.get("VENV_PYTHON", "")
venv_source = os.environ.get("VENV_SOURCE", "unknown")
project_root = Path(os.environ.get("PROJECT_ROOT", "")).resolve()
sys.path.insert(0, str(project_root / "scripts" / "lib"))
provider_tokens = ("vitis", "vai", "ryzen", "xilinx", "amd", "xdna")

status = "WARN"
providers = []
amd_candidates = []
benchmarks = []
limitations = []
error = ""
model_path = ""

if importlib.util.find_spec("onnxruntime") is None:
    limitations.append(
        "ONNX Runtime is not installed in the selected venv. "
        "For NPU: scripts/205-install-xrt-ryzen-ai.sh --accept-amd-acceleration-risk. "
        "For CPU baseline: scripts/200-install-onnxruntime.sh."
    )
elif importlib.util.find_spec("onnx") is None:
    limitations.append("Python package 'onnx' is not installed; it is required to generate the local benchmark model.")
elif importlib.util.find_spec("numpy") is None:
    limitations.append("Python package 'numpy' is not installed; it is required for benchmark inputs.")
else:
    import numpy as np
    import onnx
    import onnx.helper as oh
    import onnx.numpy_helper as nh
    import onnxruntime as ort
    from npu_ep_verify import run_provider_benchmark

    try:
        providers = list(ort.get_available_providers())
        amd_candidates = [p for p in providers if any(token in p.lower() for token in provider_tokens)]

        with tempfile.TemporaryDirectory(prefix="ai370-npu-bench-") as tmpdir:
            model_file = Path(tmpdir) / "matmul_add.onnx"
            model_path = str(model_file)
            input_tensor = oh.make_tensor_value_info("input", onnx.TensorProto.FLOAT, [1, 64])
            output_tensor = oh.make_tensor_value_info("output", onnx.TensorProto.FLOAT, [1, 64])
            weight = nh.from_array(np.eye(64, dtype=np.float32), name="weight")
            bias = nh.from_array(np.ones((64,), dtype=np.float32), name="bias")
            graph = oh.make_graph(
                [oh.make_node("MatMul", ["input", "weight"], ["mm"]), oh.make_node("Add", ["mm", "bias"], ["output"])],
                "ai370_npu_smoke",
                [input_tensor],
                [output_tensor],
                [weight, bias],
            )
            model = oh.make_model(graph, opset_imports=[oh.make_operatorsetid("", 17)])
            model.ir_version = min(model.ir_version, 10)
            onnx.checker.check_model(model)
            onnx.save(model, model_file)
            input_data = {"input": np.ones((1, 64), dtype=np.float32)}

            if "CPUExecutionProvider" in providers:
                benchmarks.append(
                    run_provider_benchmark(
                        model_file,
                        "CPUExecutionProvider",
                        input_feed=input_data,
                        tokens=provider_tokens,
                        require_ep_execution=False,
                        enable_vitis_options=False,
                    )
                )
            else:
                limitations.append("CPUExecutionProvider is unavailable, so no CPU baseline was generated.")

            for provider in amd_candidates[:1]:
                try:
                    result = run_provider_benchmark(
                        model_file,
                        provider,
                        input_feed=input_data,
                        tokens=provider_tokens,
                        require_ep_execution=True,
                        enable_vitis_options=True,
                    )
                    benchmarks.append(result)
                    # Session-level fallback (provider list) — common when native libs missing.
                    if result.get("actual_provider") != provider and result.get("actual_provider") == "CPUExecutionProvider":
                        limitations.append(
                            f"Requested {provider} but session used CPUExecutionProvider "
                            "(native EP libs / XRT env likely missing). "
                            "Source reports/latest/xrt-ryzen-ai-env.sh and ensure "
                            "scripts/lib/npu-venv.sh prepare_npu_runtime_env paths are set."
                        )
                    # Profile-level fallback: EP listed first but kernels still on CPU.
                    elif not result.get("ep_verified"):
                        note = result.get("note") or "NPU EP did not execute profiled kernels"
                        limitations.append(
                            f"{provider} did not pass EP execution verification: {note} "
                            "Treat NPU as not proven until ORT profiling shows nodes on the AMD EP "
                            "(or use an NPU-supported model / VAIML partition)."
                        )
                except Exception as exc:
                    limitations.append(
                        f"AMD provider {provider} was visible but benchmark execution failed: "
                        f"{type(exc).__name__}: {exc}"
                    )

        amd_ran_on_ep = any(
            b.get("requested_provider") in amd_candidates
            and b.get("ep_verified")
            and b.get("ep_executed")
            and b.get("actual_provider") == b.get("requested_provider")
            for b in benchmarks
        )
        if amd_candidates and amd_ran_on_ep:
            status = "PASS"
        elif amd_candidates:
            status = "WARN"
            if not any(b.get("requested_provider") in amd_candidates for b in benchmarks):
                limitations.append("AMD provider is visible, but no successful AMD-provider benchmark was completed.")
            elif not amd_ran_on_ep and not any(
                "did not pass EP execution verification" in item for item in limitations
            ):
                limitations.append(
                    "AMD provider is visible, but ORT profiling did not confirm kernel execution on that EP."
                )
        else:
            status = "WARN"
            limitations.append("No AMD/Vitis/Ryzen AI ONNX Runtime provider was detected; NPU benchmark was not run.")
            if venv_source != "ryzen-ai":
                limitations.append(
                    "Selected venv is not .ai370-ai/ryzen-ai/venv; stock CPU onnxruntime cannot expose VitisAI EP."
                )
    except Exception as exc:
        error = f"{type(exc).__name__}: {exc}"
        limitations.append("Benchmark failed before completion; inspect the error and provider status reports.")

data = {
    "tier": 2,
    "milestone": "S2-M2",
    "phase": "benchmark-npu",
    "status": status,
    "timestamp": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
    "profile": profile,
    "mode": mode,
    "persistence": persistence,
    "offline": offline,
    "venv_python": venv_python,
    "venv_source": venv_source,
    "providers": providers,
    "amd_provider_candidates": amd_candidates,
    "benchmarks": benchmarks,
    "limitations": limitations,
    "error": error,
    "model": "generated local MatMul+Add smoke model" if model_path else "not-generated",
}
json_path.write_text(json.dumps(data, indent=2) + "\n")

lines = [
    "# NPU Benchmark",
    "",
    f"Profile: {profile} | Mode: {mode} | Offline: {offline}",
    "",
    f"Status: {status}",
    "",
    f"- Venv: {venv_python} ({venv_source})",
    f"- Providers: {', '.join(providers) if providers else 'none'}",
    f"- AMD/Vitis candidates: {', '.join(amd_candidates) if amd_candidates else 'none detected'}",
    "",
    "## Results",
    "",
]
if benchmarks:
    for bench in benchmarks:
        mean = bench.get("mean_ms")
        median = bench.get("median_ms")
        min_ms = bench.get("min_ms")
        max_ms = bench.get("max_ms")
        profile_counts = (bench.get("profile") or {}).get("node_provider_counts") or {}
        lines.extend([
            f"### {bench['requested_provider']}",
            "",
            f"- Actual provider: {bench.get('actual_provider')}",
            f"- EP executed (profiled): {str(bool(bench.get('ep_executed'))).lower()}",
            f"- EP verified: {str(bool(bench.get('ep_verified'))).lower()}",
            f"- Profile node providers: {profile_counts or 'none'}",
            f"- Runs: {bench.get('runs')}",
            f"- Mean: {mean:.4f} ms" if isinstance(mean, (int, float)) else f"- Mean: {mean}",
            f"- Median: {median:.4f} ms" if isinstance(median, (int, float)) else f"- Median: {median}",
            f"- Min: {min_ms:.4f} ms" if isinstance(min_ms, (int, float)) else f"- Min: {min_ms}",
            f"- Max: {max_ms:.4f} ms" if isinstance(max_ms, (int, float)) else f"- Max: {max_ms}",
        ])
        if bench.get("note"):
            lines.append(f"- Note: {bench['note']}")
        lines.append("")
else:
    lines.append("No benchmark timings were generated.")
    lines.append("")
if limitations:
    lines.extend(["## Limitations / Diagnostics", ""])
    lines.extend(f"- {item}" for item in limitations)
    lines.append("")
if error:
    lines.extend(["## Error", "", "```text", error, "```", ""])
md_path.write_text("\n".join(lines))
PY

  echo "[INFO] Wrote $BENCHMARK_JSON"
  echo "[INFO] Wrote $BENCHMARK_MD"
  local status="WARN"
  if [[ -f "$BENCHMARK_JSON" ]]; then
    status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status","WARN"))' "$BENCHMARK_JSON" 2>/dev/null || echo WARN)"
  fi
  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
