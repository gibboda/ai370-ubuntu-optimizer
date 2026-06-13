#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 1: Kernel and firmware validation for AI370 hardware enablement.
# This is a read-only validation phase; it records facts and recommendations
# without changing kernel parameters, packages, or firmware files.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
DRY_RUN="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

LATEST_DIR="$PROJECT_ROOT/reports/latest"
STATUS_JSON="$LATEST_DIR/tier1-kernel-plan.json"
SUMMARY_MD="$LATEST_DIR/tier1-kernel-plan.md"
STATUS_TXT="$LATEST_DIR/tier1-kernel-plan.txt"
mkdir -p "$LATEST_DIR"

version_ge() {
  python3 - "$1" "$2" <<'PY'
import re
import sys

def parts(value):
    return [int(x) for x in re.findall(r"\d+", value)[:3]]

left = parts(sys.argv[1])
right = parts(sys.argv[2])
left += [0] * (3 - len(left))
right += [0] * (3 - len(right))
sys.exit(0 if left >= right else 1)
PY
}

main() {
  echo "[INFO] Tier 1 / 30-validate-kernel.sh"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE  Dry run: $DRY_RUN"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent kernel tuning is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local kernel os_description os_version os_codename amdgpu_module npu_module firmware_dir linux_firmware_state status
  local target_kernel="6.11"
  local kernel_ok="unknown"
  local amdgpu_ok="false"
  local amdxdna_seen="false"
  local recommendations=()

  kernel="$(detect_kernel)"
  os_description="$(detect_os_description)"
  os_version="$(detect_os_version_id)"
  os_codename="$(detect_os_codename)"
  amdgpu_module="$(detect_amdgpu_module)"
  npu_module="$(detect_npu_module_text)"
  firmware_dir="/lib/firmware/amdgpu"

  if [[ -n "$kernel" ]]; then
    if version_ge "$kernel" "$target_kernel"; then
      kernel_ok="true"
    else
      kernel_ok="false"
      recommendations+=("Use Ubuntu OEM/HWE kernel $target_kernel or newer for Strix Point / AI370 enablement.")
    fi
  fi

  if [[ -n "$amdgpu_module" ]]; then
    amdgpu_ok="true"
  else
    recommendations+=("amdgpu is not currently loaded; verify kernel config, firmware, and Secure Boot/module policy.")
  fi

  if [[ -n "$npu_module" ]]; then
    amdxdna_seen="true"
  else
    recommendations+=("AMDXDNA/XDNA module not loaded; this is acceptable at Tier 1 if reported cleanly and Tier 3 handles NPU enablement.")
  fi

  if [[ -d "$firmware_dir" ]]; then
    linux_firmware_state="present"
  else
    linux_firmware_state="missing"
    recommendations+=("AMDGPU firmware directory $firmware_dir is missing; install/update linux-firmware before expecting Radeon 890M acceleration.")
  fi

  status="PASS"
  if [[ "$kernel_ok" != "true" || "$amdgpu_ok" != "true" || "$linux_firmware_state" != "present" ]]; then
    status="WARN"
  fi

  export PROFILE MODE PERSISTENCE DRY_RUN kernel os_description os_version os_codename target_kernel kernel_ok amdgpu_ok amdxdna_seen linux_firmware_state status
  RECOMMENDATIONS="$(printf '%s\n' "${recommendations[@]:-}")"
  export RECOMMENDATIONS
  python3 - <<'PY' > "$STATUS_JSON"
import json
import os
from datetime import datetime, UTC

recommendations = [line for line in os.environ.get("RECOMMENDATIONS", "").splitlines() if line.strip()]
print(json.dumps({
    "tier": 1,
    "phase": "validate-kernel",
    "timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
    "profile": os.environ.get("PROFILE", "ai370"),
    "mode": os.environ.get("MODE", "safe"),
    "persistence": os.environ.get("PERSISTENCE", "runtime"),
    "dry_run": os.environ.get("DRY_RUN", "false") == "true",
    "status": os.environ.get("status", "WARN"),
    "kernel": {
        "version": os.environ.get("kernel", "unknown"),
        "target_minimum": os.environ.get("target_kernel", "6.11"),
        "acceptable": None if os.environ.get("kernel_ok", "unknown") == "unknown" else os.environ.get("kernel_ok") == "true",
    },
    "os": {
        "description": os.environ.get("os_description", "unknown"),
        "version_id": os.environ.get("os_version", "unknown"),
        "codename": os.environ.get("os_codename", "unknown"),
    },
    "modules": {
        "amdgpu_loaded": os.environ.get("amdgpu_ok", "false") == "true",
        "amdxdna_seen": os.environ.get("amdxdna_seen", "false") == "true",
    },
    "firmware": {
        "amdgpu_directory": os.environ.get("linux_firmware_state", "unknown"),
    },
    "recommendations": recommendations,
}, indent=2))
PY

  {
    echo "# Tier 1 Kernel and Firmware Validation"
    echo
    echo "**Status:** $status"
    echo
    echo "- OS: $os_description ($os_version / $os_codename)"
    echo "- Kernel: $kernel"
    echo "- Target minimum kernel: $target_kernel"
    echo "- Kernel acceptable: $kernel_ok"
    echo "- amdgpu loaded: $amdgpu_ok"
    echo "- AMDXDNA/XDNA module seen: $amdxdna_seen"
    echo "- AMDGPU firmware directory: $linux_firmware_state"
    echo
    echo "## Recommendations"
    if (( ${#recommendations[@]} == 0 )); then
      echo "- No Tier 1 kernel or firmware recommendations."
    else
      printf -- '- %s\n' "${recommendations[@]}"
    fi
  } > "$SUMMARY_MD"

  echo "$status" > "$STATUS_TXT"
  echo "[INFO] Wrote tier1-kernel-plan.*"
  echo "[INFO] 30-validate-kernel.sh complete."
}

main "$@"
