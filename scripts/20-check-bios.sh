#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Stage 2: BIOS + firmware baseline (Package C merge of former 20 + 25).
# Consumes s1-m5-system-profile.json for BIOS facts and platform policy.
# Supplemental fwupd/microcode/Secure Boot checks are live and read-only.
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
  echo "[INFO] Stage 2 / 20-check-bios.sh (BIOS + firmware baseline)"
  echo "[INFO] Selected profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE"

  local PROFILE_FILE="$LATEST_DIR/s1-m5-system-profile.json"
  if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "[ERROR] Stage 2 firmware validation requires the canonical Stage 1 profile:"
    echo "[ERROR]   $PROFILE_FILE"
    echo "[ERROR] Run: ./ai370-optimize.sh stage1"
    exit 2
  fi

  local FWUPD_DEVICES
  FWUPD_DEVICES="$(detect_fwupd_devices)"

  PROJECT_ROOT="$PROJECT_ROOT" \
  PROFILE_FILE="$PROFILE_FILE" \
  SELECTED_PROFILE="$PROFILE" \
  TIMESTAMP="$(ai370_utc_now)" \
  FWUPD_PRESENT="$([[ -n "$FWUPD_DEVICES" ]] && echo true || echo false)" \
  OUTPUT_JSON="$LATEST_DIR/tier1-firmware.json" \
  python3 - <<'PY'
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(os.environ["PROJECT_ROOT"]) / "scripts/lib"))
import firmware_policy

profile = firmware_policy.load_system_profile(Path(os.environ["PROFILE_FILE"]))
report = firmware_policy.build_firmware_baseline(
    profile,
    selected_profile=os.environ.get("SELECTED_PROFILE", "ai370"),
    timestamp=os.environ["TIMESTAMP"],
    fwupd_devices_present=os.environ.get("FWUPD_PRESENT", "false") == "true",
)
Path(os.environ["OUTPUT_JSON"]).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
PY

  local BIOS_VERSION BIOS_DATE BIOS_VENDOR SYSTEM_PRODUCT SYSTEM_VENDOR EXPECTED_BIOS BIOS_ACCEPTABLE PLATFORM_ID
  local firmware_json="$LATEST_DIR/tier1-firmware.json"
  BIOS_VERSION="$(jq -r '.bios_version // "unknown"' "$firmware_json")"
  BIOS_DATE="$(jq -r '.bios_date // "unknown"' "$firmware_json")"
  BIOS_VENDOR="$(jq -r '.bios_vendor // "unknown"' "$firmware_json")"
  SYSTEM_VENDOR="$(jq -r '.system.vendor // "unknown"' "$firmware_json")"
  SYSTEM_PRODUCT="$(jq -r '.system.product // "unknown"' "$firmware_json")"
  EXPECTED_BIOS="$(jq -r '.bios_expected // ""' "$firmware_json")"
  BIOS_ACCEPTABLE="$(jq -r '.bios_acceptable // "unknown"' "$firmware_json")"
  PLATFORM_ID="$(jq -r '.classified_platform_id // ""' "$firmware_json")"

  {
    echo "# Tier 1 Firmware / BIOS Baseline"
    echo
    echo "- Selected CLI profile: $PROFILE"
    echo "- Classified platform_id: ${PLATFORM_ID:-unknown}"
    echo "- System (from Stage 1 profile): ${SYSTEM_VENDOR:-unknown} ${SYSTEM_PRODUCT:-unknown}"
    echo "- BIOS version (from Stage 1 profile): ${BIOS_VERSION:-unknown}"
    echo "- BIOS release date: ${BIOS_DATE:-unknown}"
    echo "- BIOS vendor: ${BIOS_VENDOR:-unknown}"
    if [[ -n "$EXPECTED_BIOS" ]]; then
      echo "- Target BIOS for classified platform ${PLATFORM_ID:-unknown}: $EXPECTED_BIOS (acceptable: $BIOS_ACCEPTABLE)"
    else
      echo "- No EXPECTED_BIOS_VERSION for classified platform ${PLATFORM_ID:-unknown}"
    fi
    echo "- fwupd devices visible: $([[ -n "$FWUPD_DEVICES" ]] && echo yes || echo "no (or tool missing)")"
    echo
    echo "Note: BIOS policy uses the consumed Stage 1 profile, not CLI --profile alone."
    echo "This phase only records baseline state. No firmware updates are applied."
    if [[ -n "$EXPECTED_BIOS" ]]; then
      echo "Recommended BIOS for this classified platform is $EXPECTED_BIOS (or newer compatible). Review vendor notes before flashing."
    fi
  } > "$LATEST_DIR/tier1-firmware.md"

  cp "$LATEST_DIR/tier1-firmware.json" "$LATEST_DIR/firmware-baseline.json" 2>/dev/null || true

  # --- Former 25-check-firmware validation ---
  local status="PASS"
  local warnings=()
  record_warn() { [[ "$status" == "PASS" ]] && status="WARN"; warnings+=("$1"); }

  local fwupd_version fwupd_devices fwupdmgr_status linux_firmware_version microcode_packages secure_boot_state kernel_firmware_dir
  fwupd_version="$(capture_or_status fwupdmgr --version | head -n 20)"
  fwupd_devices="$(capture_or_status fwupdmgr get-devices)"
  fwupdmgr_status="available"
  [[ "$fwupd_version" == command-not-found:* ]] && fwupdmgr_status="missing"

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

  local warnings_json
  warnings_json="$(printf '%s\n' "${warnings[@]:-}" | json_array_from_lines)"

  FWUPD_VERSION="$fwupd_version" \
  FWUPD_DEVICES="$fwupd_devices" \
  FWUPDMGR_STATUS="$fwupdmgr_status" \
  LINUX_FIRMWARE_VERSION="$linux_firmware_version" \
  MICROCODE_PACKAGES="$microcode_packages" \
  SECURE_BOOT_STATE="$secure_boot_state" \
  KERNEL_FIRMWARE_DIR="$kernel_firmware_dir" \
  WARNINGS_JSON="$warnings_json" \
  STATUS="$status" \
  PROFILE="$PROFILE" \
  PLATFORM_ID="$PLATFORM_ID" \
  PROJECT_ROOT="$PROJECT_ROOT" \
  PROFILE_FILE="$PROFILE_FILE" \
  python3 - <<'PY' > "$LATEST_DIR/tier1-firmware-validation.json"
import datetime
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(os.environ["PROJECT_ROOT"]) / "scripts/lib"))
import firmware_policy

def lines(name):
    return [x for x in os.environ.get(name, '').splitlines() if x.strip()]

profile = firmware_policy.load_system_profile(Path(os.environ["PROFILE_FILE"]))
data = {
  "tier": 1,
  "phase": "check-firmware",
  "timestamp": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
  "profile": os.environ.get("PROFILE", "ai370"),
  "classified_platform_id": os.environ.get("PLATFORM_ID") or None,
  "status": os.environ.get("STATUS", "PASS"),
  "checks": {
    "fwupdmgr": {
      "status": os.environ.get("FWUPDMGR_STATUS", "unknown"),
      "version_output": lines("FWUPD_VERSION"),
      "devices_visible": bool(lines("FWUPD_DEVICES")) and not os.environ.get("FWUPD_DEVICES", "").startswith("command-not-found:")
    },
    "linux_firmware": {
      "package_version": os.environ.get("LINUX_FIRMWARE_VERSION", "") or "unknown",
      "firmware_root_present": os.path.isdir("/lib/firmware"),
      "kernel_firmware_dir": os.environ.get("KERNEL_FIRMWARE_DIR", "unknown")
    },
    "secure_boot": {
      "state": os.environ.get("SECURE_BOOT_STATE", "unknown")
    },
    "microcode": {
      "packages": lines("MICROCODE_PACKAGES")
    }
  },
  "warnings": json.loads(os.environ.get("WARNINGS_JSON", "[]")),
  "consumed_profile": firmware_policy.consumed_profile_block(profile),
}
print(json.dumps(data, indent=2))
PY

  {
    echo "# Tier 1 Firmware Validation"
    echo
    echo "**Status:** $status"
    echo "Profile: $PROFILE | Mode: $MODE | Persistence: $PERSISTENCE"
    echo
    echo "## Checks"
    echo "- fwupdmgr: $fwupdmgr_status"
    echo "- linux-firmware package: ${linux_firmware_version:-unknown}"
    echo "- Secure Boot: ${secure_boot_state:-unknown}"
    echo "- Microcode packages: $([[ -n "$microcode_packages" ]] && echo "detected" || echo "not detected")"
    echo "- /lib/firmware present: $([[ -d /lib/firmware ]] && echo yes || echo no)"
    if (( ${#warnings[@]} > 0 )); then
      echo
      echo "## Warnings"
      local warning
      for warning in "${warnings[@]}"; do
        echo "- $warning"
      done
    fi
    echo
    echo "Note: This phase is validation-only. It never flashes firmware or changes Secure Boot state."
    echo "BIOS policy and identity come from the consumed Stage 1 profile; see tier1-firmware.md."
  } > "$LATEST_DIR/tier1-firmware-validation.md"

  echo "[INFO] Wrote tier1-firmware.* and tier1-firmware-validation.*"
  echo "[INFO] Firmware validation status: $status"
  echo "[INFO] 20-check-bios.sh complete."
}

main "$@"
