#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

AI370_OPTIMIZER_SOURCE_ONLY="${AI370_OPTIMIZER_SOURCE_ONLY:-false}"

if [[ "$AI370_OPTIMIZER_SOURCE_ONLY" != "true" ]]; then
  set -euo pipefail

  PROFILE="${1:-ai370}"
  MODE="${2:-safe}"
  PERSISTENCE="${3:-runtime}"
  OFFLINE="${4:-false}"
else
  PROFILE="${PROFILE:-ai370}"
  MODE="${MODE:-safe}"
  PERSISTENCE="${PERSISTENCE:-runtime}"
  OFFLINE="${OFFLINE:-false}"
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
VALIDATION_STATUS="$LATEST_DIR/validation-status.txt"
AI_DIR="$PROJECT_ROOT/.ai370-ai"
VENV_DIR="$AI_DIR/venv"
STATUS_FILE="$LATEST_DIR/ai-stack-status.txt"
STATUS_JSON="$LATEST_DIR/ai-stack-status.json"
RECOMMENDATIONS_FILE="$LATEST_DIR/ai-stack-recommendations.md"
BENCHMARK_JSON="$LATEST_DIR/ai-runtime-benchmark.json"
BENCHMARK_MD="$LATEST_DIR/ai-runtime-benchmark.md"
OFFLINE_CONFIG="$PROJECT_ROOT/config/offline/ai-runtime.env"

PYTHON_PACKAGES=(
  pip
  setuptools
  wheel
  numpy
  scipy
  pandas
  pillow
  psutil
  py-cpuinfo
  onnx
  onnxruntime
)

OPTIONAL_PACKAGES=(
  transformers
  tokenizers
  safetensors
  huggingface-hub
)

resolve_project_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s\n' "$PROJECT_ROOT/$path"
  fi
}

load_offline_config() {
  OFFLINE_WHEELHOUSE="$AI_DIR/wheelhouse"
  OFFLINE_MODEL_ROOT="$AI_DIR/models"
  OFFLINE_TOOL_ROOT="$AI_DIR/tools"
  OFFLINE_REQUIREMENTS="$PROJECT_ROOT/config/ai-runtime/requirements-offline.txt"

  if [[ -f "$OFFLINE_CONFIG" ]]; then
    # shellcheck source=/dev/null
    source "$OFFLINE_CONFIG"
    OFFLINE_WHEELHOUSE="$(resolve_project_path "$OFFLINE_WHEELHOUSE")"
    OFFLINE_MODEL_ROOT="$(resolve_project_path "$OFFLINE_MODEL_ROOT")"
    OFFLINE_TOOL_ROOT="$(resolve_project_path "$OFFLINE_TOOL_ROOT")"
    OFFLINE_REQUIREMENTS="$(resolve_project_path "$OFFLINE_REQUIREMENTS")"
  fi
}

require_phase2_not_failed() {
  # Accept the new Tier 1 gate artifact as a sufficient pre-check
  local tier1_json="$PROJECT_ROOT/reports/latest/tier1-validation.json"
  if [[ -f "$tier1_json" ]]; then
    local t1_status
    t1_status="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("status","UNKNOWN"))' "$tier1_json" 2>/dev/null || echo "UNKNOWN")"
    if [[ "$t1_status" == "FAIL" ]]; then
      echo "[ERROR] Tier 1 validation failed. Refusing AI stack setup."
      exit 3
    fi
    return 0
  fi

  if [[ ! -f "$VALIDATION_STATUS" ]]; then
    echo "[ERROR] Missing Phase 2 validation output: $VALIDATION_STATUS"
    echo "[ERROR] Run: ./ai370-optimize.sh tier1"
    echo "[ERROR] Or (legacy): ./ai370-optimize.sh audit && ./ai370-optimize.sh plan --profile=$PROFILE"
    exit 3
  fi

  local status
  status="$(head -n 1 "$VALIDATION_STATUS" | tr -d '[:space:]')"

  if [[ "$status" == "FAIL" ]]; then
    echo "[ERROR] Phase 2 validation failed. Refusing AI stack setup."
    sed -n '1,80p' "$VALIDATION_STATUS"
    exit 3
  fi
}

require_runtime_persistence() {
  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Phase 6 does not implement persistent AI benchmark tuning. Use --persistence=runtime."
    exit 2
  fi
}

install_online_packages() {
  # shellcheck source=/dev/null
  source "$VENV_DIR/bin/activate"

  echo "[INFO] Upgrading Python packaging tools and installing baseline AI packages..."
  python -m pip install --upgrade "${PYTHON_PACKAGES[@]}"

  # Keep PyTorch CPU-only by default. ROCm/iGPU support is intentionally not forced here.
  echo "[INFO] Installing conservative local-AI Python helpers..."
  python -m pip install --upgrade "${OPTIONAL_PACKAGES[@]}" || true
}

offline_requirements_satisfied() {
  "$VENV_DIR/bin/python" - "$OFFLINE_REQUIREMENTS" <<'PY'
import importlib.metadata as metadata
import sys
from pathlib import Path

try:
    from packaging.requirements import Requirement
except ImportError:
    from pip._vendor.packaging.requirements import Requirement

requirements_path = Path(sys.argv[1])
unsatisfied = []
for raw_line in requirements_path.read_text().splitlines():
    line = raw_line.split("#", 1)[0].strip()
    if not line or line.startswith(("-", "--")):
        continue
    try:
        requirement = Requirement(line)
    except Exception:
        continue

    if requirement.marker and not requirement.marker.evaluate():
        continue

    try:
        installed_version = metadata.version(requirement.name)
    except metadata.PackageNotFoundError:
        unsatisfied.append(str(requirement))
        continue

    if requirement.specifier and installed_version not in requirement.specifier:
        unsatisfied.append(f"{requirement} (installed {installed_version})")

if unsatisfied:
    print(", ".join(unsatisfied))
    sys.exit(1)
PY
}

install_offline_packages() {
  # shellcheck source=/dev/null
  source "$VENV_DIR/bin/activate"

  if [[ ! -f "$OFFLINE_REQUIREMENTS" ]]; then
    echo "[ERROR] Offline requirements file is missing: $OFFLINE_REQUIREMENTS"
    exit 4
  fi

  if [[ ! -d "$OFFLINE_WHEELHOUSE" ]]; then
    local missing_packages
    if missing_packages="$(offline_requirements_satisfied)"; then
      echo "[WARN] Offline wheelhouse is missing, but the existing virtual environment satisfies $OFFLINE_REQUIREMENTS."
      echo "[WARN] Skipping offline package installation and continuing with installed local packages."
      return
    fi

    echo "[ERROR] Offline wheelhouse is missing: $OFFLINE_WHEELHOUSE"
    echo "[ERROR] Unsatisfied offline requirements in $VENV_DIR: $missing_packages"
    echo "[ERROR] Stage wheels in the configured wheelhouse, update $OFFLINE_CONFIG, or preinstall the requirements into the existing venv before rerunning --offline."
    exit 4
  fi

  echo "[INFO] Installing AI runtime from offline wheelhouse: $OFFLINE_WHEELHOUSE"
  python -m pip install --no-index --find-links "$OFFLINE_WHEELHOUSE" -r "$OFFLINE_REQUIREMENTS"
}

ensure_python_venv() {
  mkdir -p "$AI_DIR" "$LATEST_DIR"

  if [[ ! -d "$VENV_DIR" ]]; then
    echo "[INFO] Creating Python virtual environment: $VENV_DIR"
    python3 -m venv "$VENV_DIR"
  fi

  if [[ "$OFFLINE" == "true" ]]; then
    install_offline_packages
  else
    install_online_packages
  fi
}

run_cpu_benchmark() {
  echo "[INFO] Running offline-safe CPU/ONNX Runtime benchmark..."
  "$VENV_DIR/bin/python" - "$BENCHMARK_JSON" "$BENCHMARK_MD" "$PROFILE" "$MODE" "$PERSISTENCE" "$OFFLINE" <<'PY'
import json
import os
import platform
import statistics
import sys
import tempfile
import time
from pathlib import Path

json_path, md_path, profile, mode, persistence, offline = sys.argv[1:]
results = {
    "profile": profile,
    "mode": mode,
    "persistence": persistence,
    "offline": offline == "true",
    "python": sys.version.split()[0],
    "platform": platform.platform(),
    "cpu_count": os.cpu_count(),
    "env_threads": {k: os.environ.get(k, "") for k in ["OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "ORT_NUM_THREADS"]},
    "packages": {},
    "onnxruntime_providers": [],
    "benchmarks": {},
    "errors": [],
}

import importlib.metadata as metadata
for package in ["numpy", "onnx", "onnxruntime", "psutil", "py-cpuinfo"]:
    try:
        results["packages"][package] = metadata.version(package)
    except metadata.PackageNotFoundError:
        results["packages"][package] = "missing"

try:
    import numpy as np
    sizes = [256, 512]
    for size in sizes:
        a = np.ones((size, size), dtype=np.float32)
        b = np.ones((size, size), dtype=np.float32)
        timings = []
        for _ in range(3):
            start = time.perf_counter()
            _ = a @ b
            timings.append(time.perf_counter() - start)
        results["benchmarks"][f"numpy_matmul_{size}"] = {
            "runs": timings,
            "median_seconds": statistics.median(timings),
        }
except Exception as exc:
    results["errors"].append(f"numpy benchmark failed: {exc}")

try:
    import numpy as np
    import onnx
    import onnx.helper as helper
    import onnxruntime as ort
    from onnx import TensorProto

    results["onnxruntime_providers"] = ort.get_available_providers()
    with tempfile.TemporaryDirectory() as tmpdir:
        model_path = Path(tmpdir) / "identity.onnx"
        graph = helper.make_graph(
            [helper.make_node("Identity", ["input"], ["output"])],
            "ai370_identity_smoke",
            [helper.make_tensor_value_info("input", TensorProto.FLOAT, [1, 4])],
            [helper.make_tensor_value_info("output", TensorProto.FLOAT, [1, 4])],
        )
        model = helper.make_model(graph, producer_name="ai370-ubuntu-optimizer")
        model.ir_version = 10
        for opset in model.opset_import:
            opset.version = 13
        onnx.save(model, model_path)
        session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
        sample = np.ones((1, 4), dtype=np.float32)
        timings = []
        for _ in range(10):
            start = time.perf_counter()
            session.run(None, {"input": sample})
            timings.append(time.perf_counter() - start)
        results["benchmarks"]["onnxruntime_cpu_identity"] = {
            "runs": timings,
            "median_seconds": statistics.median(timings),
        }
except Exception as exc:
    results["errors"].append(f"onnxruntime CPU smoke test failed: {exc}")

Path(json_path).write_text(json.dumps(results, indent=2) + "\n")
lines = [
    "# AI Runtime Benchmark",
    "",
    f"Profile: {profile}  ",
    f"Mode: {mode}  ",
    f"Persistence: {persistence}  ",
    f"Offline: {offline}",
    "",
    "## ONNX Runtime providers",
    "",
    *(f"- {provider}" for provider in results["onnxruntime_providers"]),
    "",
    "## Benchmarks",
    "",
]
for name, data in results["benchmarks"].items():
    lines.append(f"- {name}: median {data['median_seconds']:.6f} seconds")
if results["errors"]:
    lines.extend(["", "## Errors", ""])
    lines.extend(f"- {error}" for error in results["errors"])
Path(md_path).write_text("\n".join(lines) + "\n")
if results["errors"]:
    sys.exit(5)
PY
}

detect_acceleration() {
  local amdgpu_state="missing"
  local vulkan_state="unknown"
  local opencl_state="unknown"
  local npu_state="missing"
  local rocm_state="missing"
  local providers="unknown"

  if lsmod 2>/dev/null | grep -q '^amdgpu'; then
    amdgpu_state="loaded"
  fi

  if command -v vulkaninfo >/dev/null 2>&1 && vulkaninfo --summary >/dev/null 2>&1; then
    vulkan_state="visible"
  else
    vulkan_state="not-visible"
  fi

  if command -v clinfo >/dev/null 2>&1 && clinfo >/dev/null 2>&1; then
    opencl_state="visible"
  else
    opencl_state="not-visible"
  fi

  if lsmod 2>/dev/null | grep -Eiq 'amdxdna|xrt|xdna' || find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null | grep -q .; then
    npu_state="visible"
  fi

  if command -v rocminfo >/dev/null 2>&1 && rocminfo >/dev/null 2>&1; then
    rocm_state="visible"
  fi

  providers="$($VENV_DIR/bin/python - <<'PY'
import onnxruntime as ort
print(",".join(ort.get_available_providers()))
PY
)"

  {
    echo "AI Stack Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
    echo "Timestamp: $(date -Is)"
    echo
    echo "Python virtual environment: $VENV_DIR"
    echo "Offline wheelhouse: ${OFFLINE_WHEELHOUSE:-}"
    echo "Offline model root: ${OFFLINE_MODEL_ROOT:-}"
    echo "Offline tool root: ${OFFLINE_TOOL_ROOT:-}"
    echo "amdgpu: $amdgpu_state"
    echo "Vulkan: $vulkan_state"
    echo "OpenCL: $opencl_state"
    echo "NPU/XDNA: $npu_state"
    echo "ROCm/HIP: $rocm_state"
    echo "ONNX Runtime providers: $providers"
    echo
    echo "Python packages:"
    "$VENV_DIR/bin/python" -m pip list
  } > "$STATUS_FILE"

  cat > "$STATUS_JSON" <<EOF_JSON
{
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $OFFLINE,
  "venv": "$VENV_DIR",
  "offline_wheelhouse": "${OFFLINE_WHEELHOUSE:-}",
  "offline_model_root": "${OFFLINE_MODEL_ROOT:-}",
  "offline_tool_root": "${OFFLINE_TOOL_ROOT:-}",
  "amdgpu": "$amdgpu_state",
  "vulkan": "$vulkan_state",
  "opencl": "$opencl_state",
  "npu_xdna": "$npu_state",
  "rocm_hip": "$rocm_state",
  "onnxruntime_providers": "$providers"
}
EOF_JSON

  {
    echo "# AI Stack Recommendations"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
    echo
    echo "## Current acceleration visibility"
    echo
    echo "- amdgpu: $amdgpu_state"
    echo "- Vulkan: $vulkan_state"
    echo "- OpenCL: $opencl_state"
    echo "- NPU/XDNA: $npu_state"
    echo "- ROCm/HIP: $rocm_state"
    echo "- ONNX Runtime providers: $providers"
    echo
    echo "## Offline policy"
    echo
    echo "Phase 6 prepares a local AI Python environment, validates CPU ONNX Runtime execution, and records acceleration visibility."
    echo "When --offline is used, packages come from the configured wheelhouse."
    echo "If the wheelhouse is missing, this phase can continue only when the existing venv already satisfies the configured offline requirements."
    echo "This phase does not force ROCm installation for the integrated Radeon 890M iGPU and does not install proprietary AMD Ryzen AI binaries."
    echo
    echo "## Next actions"
    echo
    echo "- Review \`$BENCHMARK_MD\` before GPU/NPU optimization."
    echo "- Run Phase 5 acceleration validation to capture local hardware capability reports."
  } > "$RECOMMENDATIONS_FILE"

  echo "[INFO] Wrote $STATUS_FILE"
  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $RECOMMENDATIONS_FILE"
}

main() {
  echo "[INFO] Phase 6: Local AI benchmark suite"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"
  echo "[INFO] Offline: $OFFLINE"

  require_phase2_not_failed
  require_runtime_persistence
  load_offline_config
  ensure_python_venv
  run_cpu_benchmark
  detect_acceleration

  echo "[INFO] Phase 6 complete. Conservative AI stack is prepared and benchmarked."
}

if [[ "$AI370_OPTIMIZER_SOURCE_ONLY" != "true" ]]; then
  main "$@"
fi
