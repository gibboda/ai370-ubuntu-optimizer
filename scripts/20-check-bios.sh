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
  BIOS_DATE="$(detect_bios_release_date)"
  BIOS_VENDOR="$(detect_bios_vendor)"
  SYSTEM_PRODUCT="$(detect_system_product)"
  SYSTEM_VENDOR="$(detect_system_vendor)"
  FWUPD_DEVICES="$(detect_fwupd_devices)"

  EXPECTED_BIOS=""
  PROFILE_ENV="$PROJECT_ROOT/configs/profiles/$PROFILE.env"
  if [[ -f "$PROFILE_ENV" ]]; then
    # shellcheck source=/dev/null
    source "$PROFILE_ENV"
    EXPECTED_BIOS="${EXPECTED_BIOS_VERSION:-}"
  fi

  if [[ -n "$EXPECTED_BIOS" && -n "${BIOS_VERSION:-}" ]]; then
    if [[ "$BIOS_VERSION" == "$EXPECTED_BIOS" || "$BIOS_VERSION" == *"$EXPECTED_BIOS"* ]]; then
      BIOS_ACCEPTABLE="true"
    else
      BIOS_ACCEPTABLE="false"
    fi
  else
    BIOS_ACCEPTABLE="unknown"
  fi

  cat > "$LATEST_DIR/tier1-firmware.json" <<EOF
{
  "tier": 1,
  "phase": "check-bios",
  "timestamp": "$(date -Is)",
  "profile": "$PROFILE",
  "bios_version": "${BIOS_VERSION:-unknown}",
  "bios_date": "${BIOS_DATE:-unknown}",
  "bios_vendor": "${BIOS_VENDOR:-unknown}",
  "bios_expected": "${EXPECTED_BIOS:-}",
  "bios_acceptable": "${BIOS_ACCEPTABLE}",
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
    echo "- BIOS release date: ${BIOS_DATE:-unknown}"
    echo "- BIOS vendor: ${BIOS_VENDOR:-unknown}"
    if [[ -n "$EXPECTED_BIOS" ]]; then
      echo "- Target BIOS for $PROFILE: $EXPECTED_BIOS (acceptable: $BIOS_ACCEPTABLE)"
    fi
    echo "- fwupd devices visible: $([[ -n "$FWUPD_DEVICES" ]] && echo yes || echo "no (or tool missing)")"
    echo
    echo "Note: This phase only records baseline state. No firmware updates are applied."
    if [[ -n "$EXPECTED_BIOS" ]]; then
      echo "For Minisforum EliteMini AI370 the recommended BIOS is $EXPECTED_BIOS (or newer compatible). Review vendor notes before flashing."
    fi
  } > "$LATEST_DIR/tier1-firmware.md"

  # Legacy artifact (best effort)
  cp "$LATEST_DIR/tier1-firmware.json" "$LATEST_DIR/firmware-baseline.json" 2>/dev/null || true

  echo "[INFO] Wrote tier1-firmware.json and tier1-firmware.md"
  echo "[INFO] 20-check-bios.sh complete."
}

main "$@"
