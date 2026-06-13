#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 1: GPU stack validation (Radeon 890M / gfx1150, Vulkan, OpenCL, ROCm visibility).
# This is a read-only validation / smoke phase. No installation of ROCm happens here.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

LATEST_DIR="$PROJECT_ROOT/reports/latest"
mkdir -p "$LATEST_DIR"

STATUS_FILE="$LATEST_DIR/tier1-gpu-stack.txt"
JSON_FILE="$LATEST_DIR/tier1-gpu-stack.json"

run_capture() {
  local cmd="$1"; shift || true
  if command -v "$cmd" >/dev/null 2>&1; then
    "$cmd" "$@" 2>&1 || true
  else
    echo "command-not-found: $cmd"
  fi
}

main() {
  echo "[INFO] Tier 1 / 70-validate-gpu-stack.sh"
  echo "[INFO] Offline: $OFFLINE"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent GPU tuning not implemented."
    exit 2
  fi

  amdgpu_state="missing"
  gpu_arch="unknown"
  vulkan_state="not-visible"
  opencl_state="not-visible"
  rocm_state="not-visible"

  gpu_text="$(lspci -nnk 2>/dev/null | grep -Ei -A4 'vga|display|3d|amd|radeon' || true)"

  if lsmod 2>/dev/null | grep -q '^amdgpu'; then
    amdgpu_state="loaded"
  fi

  if printf '%s\n' "$gpu_text" | grep -Eiq '890M|gfx1150|Strix'; then
    gpu_arch="gfx1150"
  fi

  vulkan_summary="$(run_capture vulkaninfo --summary)"
  if [[ "$vulkan_summary" != command-not-found:* ]] && ! printf '%s\n' "$vulkan_summary" | grep -qi 'error'; then
    vulkan_state="visible"
  fi

  clinfo_summary="$(run_capture clinfo)"
  if [[ "$clinfo_summary" != command-not-found:* ]] && printf '%s\n' "$clinfo_summary" | grep -Eiq 'Platform|Device'; then
    opencl_state="visible"
  fi

  rocminfo_summary="$(run_capture rocminfo)"
  if [[ "$rocminfo_summary" != command-not-found:* ]] && printf '%s\n' "$rocminfo_summary" | grep -Eiq 'Agent|Name|gfx'; then
    rocm_state="visible"
  fi

  # Write human status
  {
    echo "Tier 1 GPU Stack Validation"
    echo "Profile: $PROFILE  Mode: $MODE  Offline: $OFFLINE"
    echo
    echo "amdgpu: $amdgpu_state"
    echo "gpu_arch: $gpu_arch"
    echo "vulkan: $vulkan_state"
    echo "opencl: $opencl_state"
    echo "rocm: $rocm_state"
    echo
    echo "PCI GPU text:"
    printf '%s\n' "$gpu_text"
  } > "$STATUS_FILE"

  # Machine readable for gates / summaries
  export amdgpu_state gpu_arch vulkan_state opencl_state rocm_state
  python3 - <<'PY' > "$JSON_FILE"
import json, os
print(json.dumps({
  "tier": 1,
  "phase": "validate-gpu-stack",
  "amdgpu": os.environ.get("amdgpu_state", "missing"),
  "gpu_arch": os.environ.get("gpu_arch", "unknown"),
  "vulkan": os.environ.get("vulkan_state", "not-visible"),
  "opencl": os.environ.get("opencl_state", "not-visible"),
  "rocm": os.environ.get("rocm_state", "not-visible"),
  "target_gpu_arch": "gfx1150"
}, indent=2))
PY

  # Recommendations with acceptance language
  {
    echo "# Tier 1 GPU Stack Validation"
    echo
    echo "- Radeon 890M / gfx1150 detected: $([[ "$gpu_arch" == "gfx1150" ]] && echo YES || echo NO)"
    echo "- amdgpu loaded: $([[ "$amdgpu_state" == "loaded" ]] && echo YES || echo NO)"
    echo "- Vulkan visible: $vulkan_state"
    echo "- ROCm (rocminfo) visible: $rocm_state"
    echo
    echo "This phase validates visibility. Full ROCm installation is a separate opt-in step (amd-accel-install / tier5 after risk acceptance)."
  } > "$LATEST_DIR/tier1-gpu-stack-recommendations.md"

  echo "[INFO] Wrote tier1-gpu-stack.*"
  echo "[INFO] 70-validate-gpu-stack.sh complete."
}

main "$@"
