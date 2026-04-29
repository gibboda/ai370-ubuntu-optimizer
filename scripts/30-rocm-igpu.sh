#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
STATUS_FILE="$LATEST_DIR/gpu-acceleration-status.txt"
RECOMMENDATIONS_FILE="$LATEST_DIR/gpu-acceleration-recommendations.md"

require_runtime_persistence() {
  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent GPU tuning is not implemented yet. Use --persistence=runtime."
    exit 2
  fi
}

detect_gpu_stack() {
  mkdir -p "$LATEST_DIR"

  local amdgpu_state="missing"
  local gpu_text=""
  local gpu_arch="unknown"
  local vulkan_state="not-visible"
  local opencl_state="not-visible"
  local rocm_state="not-visible"
  local mesa_state="unknown"

  gpu_text="$(lspci -nnk 2>/dev/null | grep -Ei -A4 'vga|display|3d|amd|radeon' || true)"

  if lsmod 2>/dev/null | grep -q '^amdgpu'; then
    amdgpu_state="loaded"
  fi

  if printf '%s\n' "$gpu_text" | grep -Eiq '890M|gfx1150|Strix'; then
    gpu_arch="gfx1150"
  fi

  if command -v glxinfo >/dev/null 2>&1; then
    mesa_state="$(glxinfo -B 2>/dev/null | awk -F: '/OpenGL version string/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
    [[ -z "$mesa_state" ]] && mesa_state="unknown"
  fi

  if command -v vulkaninfo >/dev/null 2>&1 && vulkaninfo --summary >/dev/null 2>&1; then
    vulkan_state="visible"
  fi

  if command -v clinfo >/dev/null 2>&1 && clinfo >/dev/null 2>&1; then
    opencl_state="visible"
  fi

  if command -v rocminfo >/dev/null 2>&1 && rocminfo >/dev/null 2>&1; then
    rocm_state="visible"
  fi

  {
    echo "GPU Acceleration Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Timestamp: $(date -Is)"
    echo
    echo "amdgpu: $amdgpu_state"
    echo "gpu_arch: $gpu_arch"
    echo "mesa: $mesa_state"
    echo "vulkan: $vulkan_state"
    echo "opencl: $opencl_state"
    echo "rocm: $rocm_state"
    echo
    echo "PCI GPU text:"
    printf '%s\n' "$gpu_text"
  } > "$STATUS_FILE"

  {
    echo "# GPU Acceleration Track"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo
    echo "## Detected state"
    echo
    echo "- amdgpu: $amdgpu_state"
    echo "- GPU architecture: $gpu_arch"
    echo "- Mesa/OpenGL: $mesa_state"
    echo "- Vulkan: $vulkan_state"
    echo "- OpenCL: $opencl_state"
    echo "- ROCm/HIP: $rocm_state"
    echo
    echo "## Policy"
    echo
    echo "This track validates iGPU acceleration visibility without forcing ROCm installation."
    echo "The Radeon 890M / gfx1150 path is handled conservatively because integrated GPU support may differ from discrete Radeon GPU support."
    echo
    echo "## Recommendations"
    echo
    if [[ "$amdgpu_state" != "loaded" ]]; then
      echo "- Investigate kernel/firmware support: amdgpu is not loaded."
    fi
    if [[ "$vulkan_state" != "visible" ]]; then
      echo "- Install or repair Vulkan userspace before GPU-backed local AI workloads."
    fi
    if [[ "$opencl_state" != "visible" ]]; then
      echo "- OpenCL is not visible; this may limit some compute workloads."
    fi
    if [[ "$rocm_state" != "visible" ]]; then
      echo "- Do not assume ROCm/HIP is available for this iGPU until explicitly validated."
    fi
    echo "- Keep SAFE mode as the default until GPU workloads pass smoke tests."
  } > "$RECOMMENDATIONS_FILE"

  echo "[INFO] Wrote $STATUS_FILE"
  echo "[INFO] Wrote $RECOMMENDATIONS_FILE"
}

main() {
  echo "[INFO] Phase 5A: GPU acceleration track"
  require_runtime_persistence
  detect_gpu_stack
  echo "[INFO] GPU acceleration track complete."
}

main "$@"
