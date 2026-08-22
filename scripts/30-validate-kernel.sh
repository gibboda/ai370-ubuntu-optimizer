#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Stage 2 / S2-M2: Kernel and driver validation.
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

LATEST_DIR="${LATEST_DIR:-$PROJECT_ROOT/reports/latest}"
CANONICAL_JSON="$LATEST_DIR/s2-m2-kernel-driver-validation.json"
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
  echo "[INFO] Stage 2 / 30-validate-kernel.sh (S2-M2 kernel and driver validation)"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE  Dry run: $DRY_RUN"

  local PROFILE_FILE="$LATEST_DIR/s1-m5-system-profile.json"
  if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "[ERROR] Stage 2 kernel validation requires the canonical Stage 1 profile:"
    echo "[ERROR]   $PROFILE_FILE"
    echo "[ERROR] Run: ./ai370-optimize.sh stage1"
    exit 2
  fi

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

  local facts_json recommendations_json
  facts_json="$(mktemp "${TMPDIR:-/tmp}/s2-m2-facts.XXXXXX")"
  recommendations_json="$(printf '%s\n' "${recommendations[@]:-}" | python3 -c 'import json,sys; print(json.dumps([x for x in sys.stdin.read().splitlines() if x.strip()]))')"
  python3 - "$facts_json" "$kernel" "$target_kernel" "$kernel_ok" "$amdgpu_ok" \
    "$amdxdna_seen" "$linux_firmware_state" "$status" \
    "$os_description" "$os_version" "$os_codename" "$recommendations_json" <<'PY'
import json, sys
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps({
    "kernel": sys.argv[2],
    "target_kernel": sys.argv[3],
    "kernel_ok": sys.argv[4],
    "amdgpu_ok": sys.argv[5] == "true",
    "amdxdna_seen": sys.argv[6] == "true",
    "linux_firmware_state": sys.argv[7],
    "status": sys.argv[8],
    "os_description": sys.argv[9],
    "os_version": sys.argv[10],
    "os_codename": sys.argv[11],
    "recommendations": json.loads(sys.argv[12] or "[]"),
}, indent=2) + "\n", encoding="utf-8")
PY

  python3 "$PROJECT_ROOT/scripts/s2-m2-publish-kernel-driver-validation.py" \
    --profile "$PROFILE_FILE" \
    --facts "$facts_json" \
    --output "$CANONICAL_JSON" \
    --compat-output "$STATUS_JSON" \
    --cli-profile "$PROFILE" \
    --mode "$MODE" \
    --persistence "$PERSISTENCE" \
    --dry-run "$DRY_RUN"
  rm -f "$facts_json"

  status="$(jq -r '.status // "WARN"' "$CANONICAL_JSON")"

  {
    echo "# Stage 2 / S2-M2 Kernel and Driver Validation"
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
      echo "- No S2-M2 kernel or firmware recommendations."
    else
      printf -- '- %s\n' "${recommendations[@]}"
    fi
    echo
    echo "Canonical report: reports/latest/s2-m2-kernel-driver-validation.json"
  } > "$SUMMARY_MD"
  cp "$SUMMARY_MD" "$LATEST_DIR/s2-m2-kernel-driver-validation.md"

  echo "$status" > "$STATUS_TXT"
  echo "[INFO] Wrote s2-m2-kernel-driver-validation.json and compatibility tier1-kernel-plan.*"
  echo "[INFO] 30-validate-kernel.sh complete."
}

main "$@"
