#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
INVENTORY_JSON="$LATEST_DIR/hardware-inventory.json"
STATUS_TXT="$LATEST_DIR/firmware-baseline-status.txt"
STATUS_JSON="$LATEST_DIR/firmware-baseline.json"
SUMMARY_MD="$LATEST_DIR/firmware-baseline.md"

json_value() {
  local path="$1"
  if [[ -f "$INVENTORY_JSON" ]]; then
    python3 - "$INVENTORY_JSON" "$path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
value = data
for key in sys.argv[2].split("."):
    if isinstance(value, dict):
        value = value.get(key, "")
    else:
        value = ""
        break
print(value if value is not None else "")
PY
  fi
}

capture_command() {
  local command_name="$1"
  shift
  if command -v "$command_name" >/dev/null 2>&1; then
    "$command_name" "$@" 2>&1 || true
  else
    echo "command-not-found: $command_name"
  fi
}

main() {
  echo "[INFO] Phase 2: BIOS / firmware baseline"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"

  mkdir -p "$LATEST_DIR"

  local bios_version system_vendor system_product fwupd_devices fwupd_updates fwupdmgr_state linux_firmware_state status
  bios_version="$(json_value "system.bios_version")"
  system_vendor="$(json_value "system.vendor")"
  system_product="$(json_value "system.product")"
  : "${bios_version:=unknown}"
  : "${system_vendor:=unknown}"
  : "${system_product:=unknown}"

  fwupd_devices="$(capture_command fwupdmgr get-devices)"
  fwupd_updates="$(capture_command fwupdmgr get-updates)"
  if [[ "$fwupd_devices" == command-not-found:* ]]; then
    fwupdmgr_state="missing"
  else
    fwupdmgr_state="available"
  fi

  if dpkg-query -W -f='${Status}' linux-firmware 2>/dev/null | grep -q "install ok installed"; then
    linux_firmware_state="installed"
  else
    linux_firmware_state="missing"
  fi

  status="PASS"
  if [[ "$bios_version" == "unknown" || -z "$bios_version" || "$fwupdmgr_state" == "missing" || "$linux_firmware_state" == "missing" ]]; then
    status="WARN"
  fi

  {
    echo "Firmware Baseline Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Status: $status"
    echo "Timestamp: $(date -Is)"
    echo
    echo "system_vendor: $system_vendor"
    echo "system_product: $system_product"
    echo "bios_version: $bios_version"
    echo "fwupdmgr: $fwupdmgr_state"
    echo "linux_firmware: $linux_firmware_state"
  } > "$STATUS_TXT"

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" STATUS="$status" \
  SYSTEM_VENDOR="$system_vendor" SYSTEM_PRODUCT="$system_product" BIOS_VERSION="$bios_version" \
  FWUPDMGR_STATE="$fwupdmgr_state" LINUX_FIRMWARE_STATE="$linux_firmware_state" \
  FWUPD_DEVICES="$fwupd_devices" FWUPD_UPDATES="$fwupd_updates" \
  python3 - "$STATUS_JSON" <<'PY'
import json
import os
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(json.dumps({
    "profile": os.environ["PROFILE"],
    "mode": os.environ["MODE"],
    "persistence": os.environ["PERSISTENCE"],
    "status": os.environ["STATUS"],
    "system": {
        "vendor": os.environ["SYSTEM_VENDOR"],
        "product": os.environ["SYSTEM_PRODUCT"],
        "bios_version": os.environ["BIOS_VERSION"],
    },
    "firmware": {
        "fwupdmgr": os.environ["FWUPDMGR_STATE"],
        "linux_firmware": os.environ["LINUX_FIRMWARE_STATE"],
        "fwupd_devices": os.environ.get("FWUPD_DEVICES", ""),
        "fwupd_updates": os.environ.get("FWUPD_UPDATES", ""),
    },
    "policy": "report-only baseline; review vendor BIOS and fwupd updates before applying firmware changes",
}, indent=2) + "\n")
PY

  {
    echo "# BIOS / Firmware Baseline"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Status: $status"
    echo
    echo "## Detected system"
    echo
    echo "- Vendor: $system_vendor"
    echo "- Product: $system_product"
    echo "- BIOS version: $bios_version"
    echo
    echo "## Firmware tooling"
    echo
    echo "- fwupdmgr: $fwupdmgr_state"
    echo "- linux-firmware package: $linux_firmware_state"
    echo
    echo "## Policy"
    echo
    echo "This phase records the BIOS/firmware baseline only. It does not flash BIOS images or apply fwupd updates automatically. Review vendor release notes and update safety requirements before applying firmware changes."
    echo
    echo "## fwupd devices"
    echo
    printf '```text\n%s\n```\n' "$fwupd_devices"
    echo
    echo "## fwupd updates"
    echo
    printf '```text\n%s\n```\n' "$fwupd_updates"
  } > "$SUMMARY_MD"

  echo "[INFO] Firmware baseline status: $status"
  echo "[INFO] Wrote $STATUS_TXT"
  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
}

main "$@"
