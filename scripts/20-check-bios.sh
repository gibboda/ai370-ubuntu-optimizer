#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Stage 2 / S2-M1: BIOS + firmware validation (Package C merge of former 20 + 25).
# Identity facts come from s1-m5-system-profile.json. Policy uses classified
# platform_id. Supplemental fwupd/microcode/Secure Boot checks are live.
# Never flashes firmware or changes Secure Boot.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$PROJECT_ROOT/scripts/lib/common.sh"
# shellcheck source=lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

ai370_parse_standard_args "$@"
ai370_init_latest_dir

command_exists() { command -v "$1" >/dev/null 2>&1; }

capture_or_status() {
  local cmd="$1"
  shift || true
  if command_exists "$cmd"; then
    "$cmd" "$@" 2>&1 || true
  else
    echo "command-not-found: $cmd"
  fi
}

json_array_from_lines() {
  python3 -c 'import json,sys; print(json.dumps([x for x in sys.stdin.read().splitlines() if x.strip()]))'
}

main() {
  echo "[INFO] Stage 2 / 20-check-bios.sh (BIOS facts + firmware policy)"
  echo "[INFO] Selected profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE"

  local PROFILE_FILE="$LATEST_DIR/s1-m5-system-profile.json"
  if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "[ERROR] Stage 2 firmware validation requires the canonical Stage 1 profile:"
    echo "[ERROR]   $PROFILE_FILE"
    echo "[ERROR] Run: ./ai370-optimize.sh stage1"
    exit 2
  fi

  local warnings=()
  record_warn() { warnings+=("$1"); }

  local fwupd_version fwupd_devices fwupdmgr_status linux_firmware_version microcode_packages secure_boot_state kernel_firmware_dir
  local fwupd_devices_rc=0
  fwupd_version="$(capture_or_status fwupdmgr --version | head -n 20)"
  fwupdmgr_status="available"
  [[ "$fwupd_version" == command-not-found:* ]] && fwupdmgr_status="missing"
  if [[ "$fwupdmgr_status" == "missing" ]]; then
    fwupd_devices="command-not-found: fwupdmgr"
    fwupd_devices_rc=127
  else
    fwupd_devices="$(fwupdmgr get-devices 2>&1)" && fwupd_devices_rc=0 || fwupd_devices_rc=$?
  fi

  if command_exists dpkg-query; then
    linux_firmware_version="$(dpkg-query -W -f='${Version}' linux-firmware 2>/dev/null || true)"
    microcode_packages="$(dpkg-query -W -f='${binary:Package} ${Version}\n' amd64-microcode intel-microcode 2>/dev/null || true)"
  else
    linux_firmware_version=""
    microcode_packages=""
  fi

  if [[ -z "$linux_firmware_version" ]]; then
    record_warn "linux-firmware package version could not be detected."
  fi
  if [[ -z "$microcode_packages" ]]; then
    record_warn "CPU microcode package could not be detected. Install amd64-microcode for AMD systems when available."
  fi
  if [[ "$fwupdmgr_status" == "missing" ]]; then
    record_warn "fwupdmgr is not installed or not in PATH; firmware device inventory is unavailable."
  elif [[ "$fwupd_devices_rc" -ne 0 ]]; then
    record_warn "fwupdmgr get-devices failed (exit ${fwupd_devices_rc}); firmware device inventory is unavailable."
  fi

  if command_exists mokutil; then
    secure_boot_state="$(mokutil --sb-state 2>/dev/null || true)"
  else
    secure_boot_state="command-not-found: mokutil"
    record_warn "mokutil is not installed or not in PATH; Secure Boot state is unavailable."
  fi

  kernel_firmware_dir="/lib/firmware/$(uname -r 2>/dev/null || echo unknown)"
  if [[ ! -d /lib/firmware ]]; then
    record_warn "/lib/firmware is missing; kernel firmware files are unavailable."
  fi

  local devices_visible="false"
  if [[ "$fwupdmgr_status" == "available" && "$fwupd_devices_rc" -eq 0 && -n "$fwupd_devices" ]]; then
    devices_visible="true"
  fi

  local checks_json warnings_json
  checks_json="$(mktemp "${TMPDIR:-/tmp}/s2-m1-checks.XXXXXX")"
  warnings_json="$(printf '%s\n' "${warnings[@]:-}" | json_array_from_lines)"
  python3 - "$checks_json" "$fwupdmgr_status" "$devices_visible" \
    "$linux_firmware_version" "$kernel_firmware_dir" "$secure_boot_state" \
    "$warnings_json" "$fwupd_version" "$microcode_packages" <<'PY'
import json, os, sys
from pathlib import Path

def lines(text):
    return [x for x in (text or "").splitlines() if x.strip()]

payload = {
    "fwupdmgr_status": sys.argv[2],
    "fwupd_devices_visible": sys.argv[3] == "true",
    "linux_firmware_version": sys.argv[4],
    "firmware_root_present": os.path.isdir("/lib/firmware"),
    "kernel_firmware_dir": sys.argv[5],
    "secure_boot_state": sys.argv[6],
    "warnings": json.loads(sys.argv[7] or "[]"),
    "fwupd_version_output": lines(sys.argv[8]),
    "microcode_packages": lines(sys.argv[9]),
}
Path(sys.argv[1]).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

  python3 "$PROJECT_ROOT/scripts/s2-m1-publish-firmware-validation.py" \
    --profile "$PROFILE_FILE" \
    --checks "$checks_json" \
    --output "$LATEST_DIR/s2-m1-firmware-validation.json" \
    --compat-baseline "$LATEST_DIR/tier1-firmware.json" \
    --compat-validation "$LATEST_DIR/tier1-firmware-validation.json" \
    --cli-profile "$PROFILE"
  rm -f "$checks_json"

  local firmware_json="$LATEST_DIR/s2-m1-firmware-validation.json"
  local BIOS_VERSION BIOS_DATE BIOS_VENDOR SYSTEM_PRODUCT SYSTEM_VENDOR EXPECTED_BIOS BIOS_ACCEPTABLE PLATFORM_ID status
  BIOS_VERSION="$(jq -r '.facts.bios.version // "unknown"' "$firmware_json")"
  BIOS_DATE="$(jq -r '.facts.bios.date // "unknown"' "$firmware_json")"
  BIOS_VENDOR="$(jq -r '.facts.bios.vendor // "unknown"' "$firmware_json")"
  SYSTEM_VENDOR="$(jq -r '.facts.system.vendor // "unknown"' "$firmware_json")"
  SYSTEM_PRODUCT="$(jq -r '.facts.system.product // "unknown"' "$firmware_json")"
  EXPECTED_BIOS="$(jq -r '.policy.bios_expected // ""' "$firmware_json")"
  BIOS_ACCEPTABLE="$(jq -r '.policy.bios_acceptable // "unknown"' "$firmware_json")"
  PLATFORM_ID="$(jq -r '.classified_platform_id // empty' "$firmware_json")"
  status="$(jq -r '.status // "WARN"' "$firmware_json")"

  {
    echo "# Stage 2 / S2-M1 Firmware Facts"
    echo
    echo "- Selected CLI profile: $PROFILE"
    echo "- Classified platform_id: ${PLATFORM_ID:-unknown}"
    echo "- System (from Stage 1 profile): ${SYSTEM_VENDOR:-unknown} ${SYSTEM_PRODUCT:-unknown}"
    echo "- BIOS version (from Stage 1 profile): ${BIOS_VERSION:-unknown}"
    echo "- BIOS release date: ${BIOS_DATE:-unknown}"
    echo "- BIOS vendor: ${BIOS_VENDOR:-unknown}"
    echo "- fwupd devices visible: $([[ "$devices_visible" == "true" ]] && echo yes || echo "no (or tool missing)")"
    echo
    echo "This section records identity facts only. Policy is in s2-m1-firmware-validation.json."
    echo "This phase only records baseline state. No firmware updates are applied."
  } > "$LATEST_DIR/tier1-firmware.md"

  {
    echo "# Stage 2 / S2-M1 Firmware Policy"
    echo
    echo "**Status:** $status"
    echo "Profile: $PROFILE | Mode: $MODE | Persistence: $PERSISTENCE"
    echo "- Classified platform_id: ${PLATFORM_ID:-unknown}"
    if [[ -n "$EXPECTED_BIOS" ]]; then
      echo "- Target BIOS for classified platform ${PLATFORM_ID:-unknown}: $EXPECTED_BIOS (acceptable: $BIOS_ACCEPTABLE)"
    else
      echo "- No EXPECTED_BIOS_VERSION for classified platform ${PLATFORM_ID:-unknown}"
    fi
    echo
    echo "## Supplemental checks"
    echo "- fwupdmgr: $fwupdmgr_status"
    echo "- linux-firmware package: ${linux_firmware_version:-unknown}"
    echo "- Secure Boot: ${secure_boot_state:-unknown}"
    echo "- Microcode packages: $([[ -n "$microcode_packages" ]] && echo "detected" || echo "not detected")"
    echo "- /lib/firmware present: $([[ -d /lib/firmware ]] && echo yes || echo no)"
    declare -a published_warnings=()
    mapfile -t published_warnings < <(jq -r '.warnings[]?' "$firmware_json" 2>/dev/null || true)
    if (( ${#published_warnings[@]} > 0 )); then
      echo
      echo "## Warnings"
      for warning in "${published_warnings[@]}"; do
        echo "- $warning"
      done
    fi
    echo
    echo "Note: This phase is validation-only. It never flashes firmware or changes Secure Boot state."
    echo "BIOS identity facts come from the consumed Stage 1 profile; policy uses classified platform_id."
    echo "Canonical report: reports/latest/s2-m1-firmware-validation.json"
  } > "$LATEST_DIR/tier1-firmware-validation.md"

  cp "$LATEST_DIR/tier1-firmware.json" "$LATEST_DIR/firmware-baseline.json" 2>/dev/null || true
  {
    echo "# Stage 2 / S2-M1 Firmware Validation"
    echo
    cat "$LATEST_DIR/tier1-firmware.md"
    echo
    cat "$LATEST_DIR/tier1-firmware-validation.md"
  } > "$LATEST_DIR/s2-m1-firmware-validation.md"

  echo "[INFO] Wrote s2-m1-firmware-validation.json and compatibility tier1-firmware*"
  echo "[INFO] Firmware validation status: $status"
  echo "[INFO] 20-check-bios.sh complete."
}

main "$@"
