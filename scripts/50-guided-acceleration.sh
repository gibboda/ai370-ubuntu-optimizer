#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
GPU_STATUS="$LATEST_DIR/gpu-acceleration-status.txt"
NPU_STATUS="$LATEST_DIR/npu-acceleration-status.txt"
AI_STATUS="$LATEST_DIR/ai-stack-status.txt"
AI_BENCHMARK="$LATEST_DIR/ai-runtime-benchmark.json"
PLAN_FILE="$LATEST_DIR/guided-acceleration-plan.md"
COMMANDS_FILE="$LATEST_DIR/guided-acceleration-commands.sh"
READINESS_MD="$LATEST_DIR/offline-hardware-readiness.md"
READINESS_JSON="$LATEST_DIR/offline-hardware-readiness.json"
ARTIFACTS_MD="$LATEST_DIR/offline-required-artifacts.md"
OFFLINE_CONFIG="$PROJECT_ROOT/config/offline/ai-runtime.env"

require_runtime_persistence() {
  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent acceleration enablement is not implemented yet. Use --persistence=runtime."
    exit 2
  fi
}

resolve_project_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s\n' "$PROJECT_ROOT/$path"
  fi
}

load_offline_config() {
  OFFLINE_WHEELHOUSE="$PROJECT_ROOT/.ai370-ai/wheelhouse"
  OFFLINE_MODEL_ROOT="$PROJECT_ROOT/.ai370-ai/models"
  OFFLINE_TOOL_ROOT="$PROJECT_ROOT/.ai370-ai/tools"
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

read_value() {
  local file="$1"
  local key="$2"
  if [[ -f "$file" ]]; then
    awk -F': ' -v k="$key" '$1 == k {print $2; exit}' "$file"
  fi
}

state_ready() {
  local value="$1"
  case "$value" in
    visible|loaded|present|available) printf 'ready\n' ;;
    not-visible|missing|not-installed) printf 'blocked\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

generate_plan() {
  mkdir -p "$LATEST_DIR"

  local gpu_arch amdgpu vulkan opencl rocm npu_module npu_device npu_runtime ort_providers
  gpu_arch="$(read_value "$GPU_STATUS" "gpu_arch")"
  amdgpu="$(read_value "$GPU_STATUS" "amdgpu")"
  vulkan="$(read_value "$GPU_STATUS" "vulkan")"
  opencl="$(read_value "$GPU_STATUS" "opencl")"
  rocm="$(read_value "$GPU_STATUS" "rocm")"
  npu_module="$(read_value "$NPU_STATUS" "kernel_module")"
  npu_device="$(read_value "$NPU_STATUS" "device_node")"
  npu_runtime="$(read_value "$NPU_STATUS" "runtime_tools")"
  ort_providers="$(read_value "$AI_STATUS" "ONNX Runtime providers")"

  : "${gpu_arch:=unknown}"
  : "${amdgpu:=unknown}"
  : "${vulkan:=unknown}"
  : "${opencl:=unknown}"
  : "${rocm:=unknown}"
  : "${npu_module:=unknown}"
  : "${npu_device:=unknown}"
  : "${npu_runtime:=unknown}"
  : "${ort_providers:=unknown}"

  local cpu_status wheel_status requirements_status model_status tool_status vulkan_status opencl_status rocm_status npu_status
  if [[ -f "$AI_BENCHMARK" ]] && grep -q 'CPUExecutionProvider' "$AI_BENCHMARK"; then
    cpu_status="ready"
  else
    cpu_status="blocked"
  fi
  [[ -d "$OFFLINE_WHEELHOUSE" ]] && wheel_status="ready" || wheel_status="blocked"
  [[ -f "$OFFLINE_REQUIREMENTS" ]] && requirements_status="ready" || requirements_status="blocked"
  [[ -d "$OFFLINE_MODEL_ROOT" ]] && find "$OFFLINE_MODEL_ROOT" -type f 2>/dev/null | grep -q . && model_status="ready" || model_status="blocked"
  [[ -d "$OFFLINE_TOOL_ROOT" ]] && find "$OFFLINE_TOOL_ROOT" -type f 2>/dev/null | grep -q . && tool_status="ready" || tool_status="blocked"
  vulkan_status="$(state_ready "$vulkan")"
  opencl_status="$(state_ready "$opencl")"
  rocm_status="$(state_ready "$rocm")"
  if [[ "$npu_module" == "loaded" && "$npu_device" == "present" && "$npu_runtime" == "available" ]]; then
    npu_status="ready"
  elif [[ "$npu_module" == "unknown" && "$npu_device" == "unknown" ]]; then
    npu_status="unknown"
  else
    npu_status="blocked"
  fi

  cat > "$READINESS_MD" <<EOF_MD
# Offline Hardware Readiness Matrix

Profile: $PROFILE
Mode: $MODE
Persistence: $PERSISTENCE
Offline: $OFFLINE
Generated: $(date -Is)

| Track | Status | Local evidence |
|---|---|---|
| CPU ONNX Runtime | $cpu_status | Providers: $ort_providers; benchmark: $AI_BENCHMARK |
| iGPU Vulkan | $vulkan_status | Vulkan: $vulkan; amdgpu: $amdgpu |
| iGPU OpenCL | $opencl_status | OpenCL: $opencl |
| ROCm/HIP | $rocm_status | ROCm/HIP: $rocm |
| NPU/XDNA | $npu_status | module: $npu_module; device: $npu_device; tools: $npu_runtime |
| Wheels | $wheel_status | $OFFLINE_WHEELHOUSE |
| Requirements | $requirements_status | $OFFLINE_REQUIREMENTS |
| Models | $model_status | $OFFLINE_MODEL_ROOT |
| Tools | $tool_status | $OFFLINE_TOOL_ROOT |

This matrix is generated from local files and locally installed tools only; it does not fetch compatibility data or install vendor runtimes.
EOF_MD

  CPU_STATUS="$cpu_status" VULKAN_STATUS="$vulkan_status" OPENCL_STATUS="$opencl_status" ROCM_STATUS="$rocm_status" \
  NPU_STATUS_VALUE="$npu_status" WHEEL_STATUS="$wheel_status" REQUIREMENTS_STATUS="$requirements_status" MODEL_STATUS="$model_status" TOOL_STATUS="$tool_status" \
  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" GPU_ARCH="$gpu_arch" AMDGPU="$amdgpu" \
  VULKAN="$vulkan" OPENCL="$opencl" ROCM="$rocm" NPU_MODULE="$npu_module" NPU_DEVICE="$npu_device" NPU_RUNTIME="$npu_runtime" \
  ORT_PROVIDERS="$ort_providers" OFFLINE_WHEELHOUSE="$OFFLINE_WHEELHOUSE" OFFLINE_REQUIREMENTS="$OFFLINE_REQUIREMENTS" \
  OFFLINE_MODEL_ROOT="$OFFLINE_MODEL_ROOT" OFFLINE_TOOL_ROOT="$OFFLINE_TOOL_ROOT" \
  python3 - "$READINESS_JSON" <<'PY'
import json
import os
import sys
from pathlib import Path
tracks = {
    "cpu_onnxruntime": {"status": os.environ["CPU_STATUS"], "providers": os.environ["ORT_PROVIDERS"]},
    "igpu_vulkan": {"status": os.environ["VULKAN_STATUS"], "vulkan": os.environ["VULKAN"], "amdgpu": os.environ["AMDGPU"]},
    "igpu_opencl": {"status": os.environ["OPENCL_STATUS"], "opencl": os.environ["OPENCL"]},
    "rocm_hip": {"status": os.environ["ROCM_STATUS"], "rocm": os.environ["ROCM"]},
    "npu_xdna": {"status": os.environ["NPU_STATUS_VALUE"], "module": os.environ["NPU_MODULE"], "device": os.environ["NPU_DEVICE"], "runtime": os.environ["NPU_RUNTIME"]},
    "wheels": {"status": os.environ["WHEEL_STATUS"], "path": os.environ["OFFLINE_WHEELHOUSE"]},
    "requirements": {"status": os.environ["REQUIREMENTS_STATUS"], "path": os.environ["OFFLINE_REQUIREMENTS"]},
    "models": {"status": os.environ["MODEL_STATUS"], "path": os.environ["OFFLINE_MODEL_ROOT"]},
    "tools": {"status": os.environ["TOOL_STATUS"], "path": os.environ["OFFLINE_TOOL_ROOT"]},
}
Path(sys.argv[1]).write_text(json.dumps({
    "profile": os.environ["PROFILE"],
    "mode": os.environ["MODE"],
    "persistence": os.environ["PERSISTENCE"],
    "offline": os.environ["OFFLINE"] == "true",
    "gpu_arch": os.environ["GPU_ARCH"],
    "tracks": tracks,
}, indent=2) + "\n")
PY

  cat > "$ARTIFACTS_MD" <<EOF_ARTIFACTS
# Offline Required Artifacts

Use this checklist before running Phase 4-7 in --offline mode.

- Wheelhouse: \`$OFFLINE_WHEELHOUSE\` ($wheel_status)
- Requirements lock/list: \`$OFFLINE_REQUIREMENTS\` ($requirements_status)
- Local models: \`$OFFLINE_MODEL_ROOT\` ($model_status)
- Local tools/benchmarks: \`$OFFLINE_TOOL_ROOT\` ($tool_status)
- Optional AMD runtime packages: keep staged offline and install only after independent compatibility confirmation.
- Checksums: store alongside wheels, models, and tools when reproducibility matters.
EOF_ARTIFACTS

  cat > "$PLAN_FILE" <<EOF_PLAN
# Guided Offline Acceleration Enablement Plan

Profile: $PROFILE
Mode: $MODE
Persistence: $PERSISTENCE
Offline: $OFFLINE
Generated: $(date -Is)

## Readiness Summary

See \`reports/latest/offline-hardware-readiness.md\` for the full matrix.

## Current GPU State

- amdgpu: $amdgpu
- GPU architecture: $gpu_arch
- Vulkan: $vulkan
- OpenCL: $opencl
- ROCm/HIP: $rocm

## Current NPU State

- kernel module: $npu_module
- device node: $npu_device
- runtime tools: $npu_runtime

## Policy

This phase is offline-first and approval-gated. It generates suggested local validation commands but does not execute fragile GPU/NPU acceleration installs automatically.

## Recommended Order

1. Make CPU ONNX Runtime ready using the offline wheelhouse.
2. Validate local GPU visibility with Vulkan/OpenCL/ROCm tools already on the machine.
3. Validate local NPU visibility with XRT/Ryzen AI tools only if already staged and installed from approved offline artifacts.
4. Run Phase 7 generated benchmark/checklist scripts.
5. Install ComfyUI only after hardware/runtime reports are stable.
EOF_PLAN

  cat > "$COMMANDS_FILE" <<'EOF_COMMANDS'
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Generated guided offline acceleration commands.
# Review every command before running. This file is intentionally not executed by the optimizer.

set -euo pipefail

printf '%s\n' '[INFO] CPU/ONNX Runtime visibility checks'
if [[ -x .ai370-ai/venv/bin/python ]]; then
  .ai370-ai/venv/bin/python -c 'import onnxruntime as ort; print(ort.get_available_providers())'
else
  echo '[WARN] AI virtual environment not found. Run Phase 4 first.'
fi

printf '%s\n' '[INFO] GPU visibility checks'
lspci -nnk | grep -Ei -A4 'vga|display|3d|amd|radeon' || true
lsmod | grep amdgpu || true
vulkaninfo --summary || true
clinfo || true
rocminfo || true

printf '%s\n' '[INFO] NPU visibility checks'
lsmod | grep -Ei 'amdxdna|xrt|xdna' || true
find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null || true
command -v xrt-smi >/dev/null 2>&1 && xrt-smi examine || true
command -v xrt-smi >/dev/null 2>&1 && xrt-smi validate || true

printf '%s\n' '[INFO] No downloads or runtime installs were attempted.'
EOF_COMMANDS

  chmod +x "$COMMANDS_FILE"

  echo "[INFO] Wrote $PLAN_FILE"
  echo "[INFO] Wrote $COMMANDS_FILE"
  echo "[INFO] Wrote $READINESS_MD"
  echo "[INFO] Wrote $READINESS_JSON"
  echo "[INFO] Wrote $ARTIFACTS_MD"
}

main() {
  echo "[INFO] Phase 6: Guided offline acceleration enablement"
  echo "[INFO] Offline: $OFFLINE"
  require_runtime_persistence
  load_offline_config

  if [[ ! -f "$GPU_STATUS" ]]; then
    echo "[WARN] Missing GPU status. Run: ./scripts/30-rocm-igpu.sh $PROFILE $MODE $PERSISTENCE $OFFLINE"
  fi

  if [[ ! -f "$NPU_STATUS" ]]; then
    echo "[WARN] Missing NPU status. Run: ./scripts/40-ryzen-ai-npu.sh $PROFILE $MODE $PERSISTENCE $OFFLINE"
  fi

  generate_plan
  echo "[INFO] Phase 6 complete. Review the generated offline readiness plan before installing acceleration runtimes."
}

main "$@"
