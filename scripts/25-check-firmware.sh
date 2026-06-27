#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 1 script: firmware validation (detection only – no flashing).

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
OUT_JSON="$LATEST_DIR/tier1-firmware-validation.json"
OUT_MD="$LATEST_DIR/tier1-firmware-validation.md"
mkdir -p "$LATEST_DIR"

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

status="PASS"
warnings=()
record_warn() { [[ "$status" == "PASS" ]] && status="WARN"; warnings+=("$1"); }

json_array_from_lines() {
  python3 -c 'import json,sys; print(json.dumps([x for x in sys.stdin.read().splitlines() if x.strip()]))'
}

main() {
  echo "[INFO] Tier 1 / 25-check-firmware.sh"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE"

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
  python3 - <<'PY' > "$OUT_JSON"
import json, os, datetime

def lines(name):
    return [x for x in os.environ.get(name, '').splitlines() if x.strip()]

data = {
  "tier": 1,
  "phase": "check-firmware",
  "timestamp": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
  "profile": os.environ.get("PROFILE", "ai370"),
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
  "warnings": json.loads(os.environ.get("WARNINGS_JSON", "[]"))
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
  } > "$OUT_MD"

  echo "[INFO] Firmware validation status: $status"
  echo "[INFO] Wrote $OUT_JSON"
  echo "[INFO] Wrote $OUT_MD"
}

main "$@"
