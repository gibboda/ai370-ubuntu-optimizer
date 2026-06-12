#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 1 script: BIOS / firmware baseline (detection only – no flashing)

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

LATEST_DIR="$PROJECT_ROOT/reports/latest"
mkdir -p "$LATEST_DIR"

main() {
  echo "[INFO] Tier 1 / 20-check-bios.sh"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE"

  BIOS_VERSION="$(detect_bios_version)"
  SYSTEM_PRODUCT="$(detect_system_product)"
  SYSTEM_VENDOR="$(detect_system_vendor)"
  FWUPD_DEVICES="$(detect_fwupd_devices)"

  cat > "$LATEST_DIR/tier1-firmware.json" <<EOF
{
  "tier": 1,
  "phase": "check-bios",
  "timestamp": "$(date -Is)",
  "profile": "$PROFILE",
  "bios_version": "${BIOS_VERSION:-unknown}",
  "system": {
    "vendor": "${SYSTEM_VENDOR:-unknown}",
    "product": "${SYSTEM_PRODUCT:-unknown}"
  },
  "fwupd": { "devices_present": $([[ -n "$FWUPD_DEVICES" ]] && echo true || echo false) }
}
EOF

  {
    echo "# Tier 1 Firmware / BIOS Baseline"
    echo
    echo "- System: ${SYSTEM_VENDOR:-unknown} ${SYSTEM_PRODUCT:-unknown}"
    echo "- BIOS version: ${BIOS_VERSION:-unknown}"
    echo "- fwupd devices visible: $([[ -n "$FWUPD_DEVICES" ]] && echo yes || echo "no (or tool missing)")"
    echo
    echo "Note: This phase only records baseline state. No firmware updates are applied."
  } > "$LATEST_DIR/tier1-firmware.md"

  # Legacy artifact
  cp "$LATEST_DIR/tier1-firmware.json" "$LATEST_DIR/firmware-baseline.json" 2>/dev/null || true

  echo "[INFO] Wrote tier1-firmware.json and tier1-firmware.md"
  echo "[INFO] 20-check-bios.sh complete."
}

main "$@"
