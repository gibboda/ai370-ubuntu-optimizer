#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
STATUS_FILE="$LATEST_DIR/gpu-acceleration-status.txt"
STATUS_JSON="$LATEST_DIR/gpu-acceleration-status.json"
RECOMMENDATIONS_FILE="$LATEST_DIR/gpu-acceleration-recommendations.md"
CAPABILITIES_JSON="$LATEST_DIR/gpu-capabilities.json"
SMOKE_FILE="$LATEST_DIR/gpu-smoke-benchmark.md"

require_runtime_persistence() {
  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent GPU tuning is not implemented yet. Use --persistence=runtime."
    exit 2
  fi
}

run_capture() {
  local command_name="$1"
  shift
  if command -v "$command_name" >/dev/null 2>&1; then
    "$command_name" "$@" 2>&1 || true
  else
    echo "command-not-found: $command_name"
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
  local vulkan_summary=""
  local clinfo_summary=""
  local rocminfo_summary=""
  local drm_facts=""

  gpu_text="$(lspci -nnk 2>/dev/null | grep -Ei -A4 'vga|display|3d|amd|radeon' || true)"

  if lsmod 2>/dev/null | grep -q '^amdgpu'; then
    amdgpu_state="loaded"
  fi

  if printf '%s\n' "$gpu_text" | grep -Eiq '890M|gfx1150|Strix'; then
    gpu_arch="gfx1150"
  fi

  if command -v glxinfo >/dev/null 2>&1; then
    mesa_state="$(glxinfo -B 2>/dev/null | awk -F: '/OpenGL version string/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' || true)"
    [[ -z "$mesa_state" ]] && mesa_state="unknown"
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

  drm_facts="$(find /sys/class/drm -maxdepth 3 -type f \( -name vendor -o -name device -o -name revision -o -name subsystem_device -o -name subsystem_vendor \) -print -exec cat {} \; 2>/dev/null || true)"

  {
    echo "GPU Acceleration Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
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

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" \
  AMDGPU_STATE="$amdgpu_state" GPU_ARCH="$gpu_arch" MESA_STATE="$mesa_state" \
  VULKAN_STATE="$vulkan_state" OPENCL_STATE="$opencl_state" ROCM_STATE="$rocm_state" \
  GPU_TEXT="$gpu_text" VULKAN_SUMMARY="$vulkan_summary" CLINFO_SUMMARY="$clinfo_summary" \
  ROCMINFO_SUMMARY="$rocminfo_summary" DRM_FACTS="$drm_facts" \
  python3 - "$STATUS_JSON" "$CAPABILITIES_JSON" <<'PY'
import json
import os
import sys
from pathlib import Path
status_path, capabilities_path = sys.argv[1:]
status = {
    "profile": os.environ["PROFILE"],
    "mode": os.environ["MODE"],
    "persistence": os.environ["PERSISTENCE"],
    "offline": os.environ["OFFLINE"] == "true",
    "amdgpu": os.environ["AMDGPU_STATE"],
    "gpu_arch": os.environ["GPU_ARCH"],
    "mesa": os.environ["MESA_STATE"],
    "vulkan": os.environ["VULKAN_STATE"],
    "opencl": os.environ["OPENCL_STATE"],
    "rocm": os.environ["ROCM_STATE"],
}
capabilities = dict(status)
capabilities.update({
    "pci_gpu_text": os.environ.get("GPU_TEXT", ""),
    "vulkan_summary": os.environ.get("VULKAN_SUMMARY", ""),
    "clinfo_summary": os.environ.get("CLINFO_SUMMARY", ""),
    "rocminfo_summary": os.environ.get("ROCMINFO_SUMMARY", ""),
    "drm_facts": os.environ.get("DRM_FACTS", ""),
})
Path(status_path).write_text(json.dumps(status, indent=2) + "\n")
Path(capabilities_path).write_text(json.dumps(capabilities, indent=2) + "\n")
PY

  {
    echo "# GPU Offline Smoke Benchmark"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
    echo
    echo "## Results"
    echo
    echo "- amdgpu: $amdgpu_state"
    echo "- GPU architecture: $gpu_arch"
    echo "- Mesa/OpenGL: $mesa_state"
    echo "- Vulkan enumeration: $vulkan_state"
    echo "- OpenCL enumeration: $opencl_state"
    echo "- ROCm/HIP enumeration: $rocm_state"
    echo
    echo "No downloads or installs were attempted. This smoke report only validates locally installed drivers/tools."
  } > "$SMOKE_FILE"

  {
    echo "# GPU Acceleration Track"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
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
    echo "This track validates local iGPU acceleration visibility without fetching or forcing ROCm installation."
    echo "The Radeon 890M / gfx1150 path is handled conservatively because integrated GPU support may differ from discrete Radeon GPU support."
    echo
    echo "## Recommendations"
    echo
    if [[ "$amdgpu_state" != "loaded" ]]; then
      echo "- Investigate kernel/firmware support: amdgpu is not loaded."
    fi
    if [[ "$vulkan_state" != "visible" ]]; then
      echo "- Install or repair Vulkan userspace from your approved offline package source before GPU-backed local AI workloads."
    fi
    if [[ "$opencl_state" != "visible" ]]; then
      echo "- OpenCL is not visible; this may limit some compute workloads."
    fi
    if [[ "$rocm_state" != "visible" ]]; then
      echo "- Do not assume ROCm/HIP is available for this iGPU until locally validated."
    fi
    echo "- Keep SAFE mode as the default until GPU workloads pass smoke tests."
  } > "$RECOMMENDATIONS_FILE"

  echo "[INFO] Wrote $STATUS_FILE"
  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $CAPABILITIES_JSON"
  echo "[INFO] Wrote $SMOKE_FILE"
  echo "[INFO] Wrote $RECOMMENDATIONS_FILE"
}

main() {
  echo "[INFO] Phase 5A: GPU acceleration track"
  echo "[INFO] Offline: $OFFLINE"
  require_runtime_persistence
  detect_gpu_stack
  echo "[INFO] GPU acceleration track complete."
}

main "$@"
