#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
VALIDATION_STATUS="$LATEST_DIR/validation-status.txt"
AI_DIR="$PROJECT_ROOT/.ai370-ai"
VENV_DIR="$AI_DIR/venv"
STATUS_FILE="$LATEST_DIR/ai-stack-status.txt"
RECOMMENDATIONS_FILE="$LATEST_DIR/ai-stack-recommendations.md"

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

require_phase2_not_failed() {
  if [[ ! -f "$VALIDATION_STATUS" ]]; then
    echo "[ERROR] Missing Phase 2 validation output: $VALIDATION_STATUS"
    echo "[ERROR] Run: ./ai370-optimize.sh audit && ./ai370-optimize.sh plan --profile=$PROFILE"
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
    echo "[ERROR] Phase 4 does not implement persistent system tuning. Use --persistence=runtime."
    exit 2
  fi
}

ensure_python_venv() {
  mkdir -p "$AI_DIR"

  if [[ ! -d "$VENV_DIR" ]]; then
    echo "[INFO] Creating Python virtual environment: $VENV_DIR"
    python3 -m venv "$VENV_DIR"
  fi

  # shellcheck source=/dev/null
  source "$VENV_DIR/bin/activate"

  echo "[INFO] Upgrading Python packaging tools and installing baseline AI packages..."
  python -m pip install --upgrade "${PYTHON_PACKAGES[@]}"
}

install_optional_packages() {
  # Keep PyTorch CPU-only by default. ROCm/iGPU support is intentionally not forced here.
  # Future phases can add explicit backend selectors once compatibility is verified.
  # shellcheck source=/dev/null
  source "$VENV_DIR/bin/activate"

  echo "[INFO] Installing conservative local-AI Python helpers..."
  python -m pip install --upgrade transformers tokenizers safetensors huggingface-hub || true
}

detect_acceleration() {
  local amdgpu_state="missing"
  local vulkan_state="unknown"
  local opencl_state="unknown"
  local npu_state="missing"
  local rocm_state="missing"

  if lsmod | grep -q '^amdgpu'; then
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

  if lsmod | grep -Eiq 'amdxdna|xrt|xdna' || find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null | grep -q .; then
    npu_state="visible"
  fi

  if command -v rocminfo >/dev/null 2>&1 && rocminfo >/dev/null 2>&1; then
    rocm_state="visible"
  fi

  mkdir -p "$LATEST_DIR"
  {
    echo "AI Stack Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Timestamp: $(date -Is)"
    echo
    echo "Python virtual environment: $VENV_DIR"
    echo "amdgpu: $amdgpu_state"
    echo "Vulkan: $vulkan_state"
    echo "OpenCL: $opencl_state"
    echo "NPU/XDNA: $npu_state"
    echo "ROCm/HIP: $rocm_state"
    echo
    echo "Python packages:"
    "$VENV_DIR/bin/python" -m pip list
  } > "$STATUS_FILE"

  {
    echo "# AI Stack Recommendations"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo
    echo "## Current acceleration visibility"
    echo
    echo "- amdgpu: $amdgpu_state"
    echo "- Vulkan: $vulkan_state"
    echo "- OpenCL: $opencl_state"
    echo "- NPU/XDNA: $npu_state"
    echo "- ROCm/HIP: $rocm_state"
    echo
    echo "## Policy"
    echo
    echo "This phase prepares the local AI Python environment and records acceleration visibility."
    echo "It does not force ROCm installation for the integrated Radeon 890M iGPU."
    echo "It does not install proprietary AMD Ryzen AI binaries directly."
    echo
    echo "## Next actions"
    echo
    echo "- Use the virtual environment at \`$VENV_DIR\`."
    echo "- Verify ONNX Runtime import with: \`$VENV_DIR/bin/python -c 'import onnxruntime as ort; print(ort.get_available_providers())'\`."
    echo "- Proceed to a dedicated ROCm/iGPU phase only after confirming AMD support for this exact Ubuntu and iGPU path."
    echo "- Proceed to a dedicated Ryzen AI NPU phase only after confirming XDNA runtime availability on this machine."
  } > "$RECOMMENDATIONS_FILE"

  echo "[INFO] Wrote $STATUS_FILE"
  echo "[INFO] Wrote $RECOMMENDATIONS_FILE"
}

main() {
  echo "[INFO] Phase 4: AI stack preparation"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"

  require_phase2_not_failed
  require_runtime_persistence
  ensure_python_venv
  install_optional_packages
  detect_acceleration

  echo "[INFO] Phase 4 complete. Conservative AI stack is prepared."
}

main "$@"
