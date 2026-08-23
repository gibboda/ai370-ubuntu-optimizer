#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Compatibility shim for S2-M7 platform validation (90-validate.sh).
# Canonical report: reports/latest/s2-m7-platform-validation.json
# Compatibility report: reports/latest/tier1-validation.json
# (require_tier123_pass fallback until R2)
#
# Requires reports/latest/s1-m5-system-profile.json. Does not re-detect
# gfx1150 or NPU from live PCI/sysfs. Facts come from the consumed Stage 1
# profile and fingerprint-matched Stage 2 milestone reports.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
# full (default) | inventory | smoke
#   inventory — hardware/firmware/kernel/GPU only (no platform-tuning / local-AI smoke)
#   full      — platform Stage 2 (no required script 80 artifact)
#   smoke     — full + require tier1-local-ai-benchmark.json from optional script 80
SCOPE="${4:-full}"
case "$SCOPE" in
  full|inventory|smoke) ;;
  true|false)
    SCOPE="full"
    ;;
  *)
    echo "[WARN] Unknown Stage 2 validate scope '$SCOPE'; using full"
    SCOPE="full"
    ;;
esac

# Optional strict mode elevates missing gfx1150 / NPU from WARN to FAIL.
# Default remains experimental-friendly (PASS with acceptance WARNs is OK for Stage 3 gate).
STRICT="${AI370_STAGE1_STRICT:-false}"
case "$STRICT" in
  true|1|yes|on) STRICT="true" ;;
  *) STRICT="false" ;;
esac

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="${AI370_REPORTS_DIR:-$PROJECT_ROOT/reports/latest}"
PROFILE_FILE="$LATEST_DIR/s1-m5-system-profile.json"
CANONICAL_JSON="$LATEST_DIR/s2-m7-platform-validation.json"
OUT_JSON="$LATEST_DIR/tier1-validation.json"
OUT_MD="$LATEST_DIR/tier1-summary.md"
OUT_TXT="$LATEST_DIR/tier1-validation.txt"

main() {
  mkdir -p "$LATEST_DIR"

  echo "[INFO] S2-M7 / 90-validate.sh compatibility shim"
  echo "[INFO] Canonical report: s2-m7-platform-validation.json"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE  Scope: $SCOPE  Strict: $STRICT"
  echo "[INFO] Re-check: ./ai370-optimize.sh stage2-platform-validate [--strict]"
  echo "[INFO] Inventory-only re-check: ./ai370-optimize.sh stage2-platform-inventory [--strict]"

  local publish_args=(
    --reports-dir "$LATEST_DIR"
    --output "$CANONICAL_JSON"
    --compat-output "$OUT_JSON"
    --compat-markdown "$OUT_MD"
    --compat-status "$OUT_TXT"
    --scope "$SCOPE"
    --strict "$STRICT"
    --cli-profile "$PROFILE"
  )
  if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "[ERROR] Stage 1 profile missing: $PROFILE_FILE"
    echo "[ERROR] Stage 2 platform validation requires the canonical Stage 1 profile (schema version + fingerprint)."
    echo "[ERROR] Run: ./ai370-optimize.sh stage1-probe && ./ai370-optimize.sh stage1-profile"
    exit 2
  fi
  echo "[INFO] Consuming Stage 1 profile: $PROFILE_FILE"
  publish_args+=(--profile "$PROFILE_FILE")

  python3 "$PROJECT_ROOT/scripts/s2-m7-publish-platform-validation.py" "${publish_args[@]}"
}

main "$@"
