#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M3: GPU stack visibility (AMDGPU, Vulkan, OpenCL, ROCm).
# Architecture comes from PCI vendor:device lookup or consumed Stage 1 profile,
# not marketing names. Read-only validation; no ROCm installation here.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

LATEST_DIR="$PROJECT_ROOT/reports/latest"
mkdir -p "$LATEST_DIR"

STATUS_FILE="$LATEST_DIR/tier1-gpu-stack.txt"
JSON_FILE="$LATEST_DIR/tier1-gpu-stack.json"
VISIBILITY_FILE="$LATEST_DIR/s2-m3-gpu-runtime-visibility.json"
PROFILE_FILE="$LATEST_DIR/s1-m5-system-profile.json"
CHECKS_FILE="$(mktemp "${TMPDIR:-/tmp}/s2-m3-gpu-checks.XXXXXX")"
trap 'rm -f "$CHECKS_FILE"' EXIT

run_capture() {
  local cmd="$1"; shift || true
  if command -v "$cmd" >/dev/null 2>&1; then
    "$cmd" "$@" 2>&1 || true
  else
    echo "command-not-found: $cmd"
  fi
}

main() {
  echo "[INFO] S2-M3 / s2-m3-validate-gpu-stack.sh"
  echo "[INFO] Offline: $OFFLINE"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent GPU tuning not implemented."
    exit 2
  fi

  local amdgpu_state="missing"
  local gpu_arch="unknown"
  local vulkan_state="not-visible"
  local opencl_state="not-visible"
  local rocm_state="not-visible"
  local target_gpu_arch="null"

  local gpu_text
  gpu_text="$(lspci -nnk 2>/dev/null | grep -Ei -A4 'vga|display|3d|amd|radeon' || true)"

  if lsmod 2>/dev/null | grep -q '^amdgpu'; then
    amdgpu_state="loaded"
  elif printf '%s\n' "$gpu_text" | grep -Eiq 'Kernel driver in use:[[:space:]]*amdgpu'; then
    amdgpu_state="loaded"
  fi

  gpu_arch="$(detect_gpu_arch "$gpu_text")"

  local vulkan_summary clinfo_summary rocminfo_summary
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

  if [[ -f "$PROFILE_FILE" ]]; then
    target_gpu_arch="$(python3 - "$PROFILE_FILE" "$PROJECT_ROOT" <<'PY'
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[2]) / "scripts/lib"))
import capability_ladder
profile = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
value = capability_ladder.target_gpu_arch_from_profile(profile)
print(json.dumps(value))
PY
)"
  fi

  {
    echo "S2-M3 GPU Stack Validation"
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

  python3 - "$CHECKS_FILE" "$amdgpu_state" "$gpu_arch" "$vulkan_state" "$opencl_state" "$rocm_state" "$gpu_text" <<'PY'
import json, sys
path, amdgpu, gpu_arch, vulkan, opencl, rocm, gpu_text = sys.argv[1:8]
payload = {
    "amdgpu": amdgpu,
    "gpu_arch": None if gpu_arch in ("", "unknown", "null") else gpu_arch,
    "vulkan": vulkan,
    "opencl": opencl,
    "rocm": rocm,
    "gpu_text": gpu_text,
}
Path = __import__("pathlib").Path
Path(path).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

  local publish_args=(--checks "$CHECKS_FILE" --output "$VISIBILITY_FILE")
  if [[ -f "$PROFILE_FILE" ]]; then
    publish_args+=(--profile "$PROFILE_FILE")
    echo "[INFO] Consuming Stage 1 profile: $PROFILE_FILE"
  else
    echo "[WARN] Stage 1 profile missing; publishing visibility without consumed fingerprint"
  fi
  python3 "$PROJECT_ROOT/scripts/s2-m3-publish-gpu-visibility.py" "${publish_args[@]}"

  export amdgpu_state gpu_arch vulkan_state opencl_state rocm_state target_gpu_arch
  python3 - <<'PY' > "$JSON_FILE"
import json, os
target = json.loads(os.environ.get("target_gpu_arch", "null"))
print(json.dumps({
  "tier": 1,
  "phase": "validate-gpu-stack",
  "amdgpu": os.environ.get("amdgpu_state", "missing"),
  "gpu_arch": os.environ.get("gpu_arch", "unknown"),
  "vulkan": os.environ.get("vulkan_state", "not-visible"),
  "opencl": os.environ.get("opencl_state", "not-visible"),
  "rocm": os.environ.get("rocm_state", "not-visible"),
  "target_gpu_arch": target,
}, indent=2))
PY

  local target_display
  target_display="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]))' "$target_gpu_arch" 2>/dev/null || echo unknown)"
  {
    echo "# S2-M3 GPU Stack Validation"
    echo
    echo "- Target GPU architecture (from profile): ${target_display:-unknown}"
    echo "- Observed GPU architecture: $gpu_arch"
    echo "- amdgpu loaded: $([[ "$amdgpu_state" == "loaded" ]] && echo YES || echo NO)"
    echo "- Vulkan visible: $vulkan_state"
    echo "- ROCm (rocminfo) visible: $rocm_state"
    echo
    echo "Canonical report: reports/latest/s2-m3-gpu-runtime-visibility.json"
    echo "This phase validates visibility. Full ROCm installation is a separate opt-in step."
  } > "$LATEST_DIR/tier1-gpu-stack-recommendations.md"

  local exit_status=0
  exit_status="$(python3 - "$VISIBILITY_FILE" <<'PY'
import json, sys
report = json.loads(open(sys.argv[1], encoding="utf-8").read())
status = report.get("status", "WARN")
print(1 if status == "FAIL" else 0)
PY
)"

  echo "[INFO] Wrote tier1-gpu-stack.* and s2-m3-gpu-runtime-visibility.json"
  echo "[INFO] s2-m3-validate-gpu-stack.sh complete."
  exit "$exit_status"
}

main "$@"
