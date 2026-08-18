#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Portable smoke for Stage 2 platform command wiring (PR 3a + profile contract).
# Uses versioned S1-M5 fixtures. Does not probe host /sys, PCI, or modules.
# Safe without AI370 hardware and without network.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
PROFILE_FIXTURE="$PROJECT_ROOT/tests/fixtures/system-profile/v3/valid-reference.json"
SMOKE_PROFILE="generic-ryzen-ai"
SMOKE_MODE="safe"

echo "[INFO] Stage 2 platform smoke test starting (selected profile=$SMOKE_PROFILE)"

for s in \
  ai370-optimize.sh \
  scripts/20-check-bios.sh \
  scripts/30-validate-kernel.sh \
  scripts/40-platform-tuning.sh \
  scripts/s2-m3-validate-gpu-stack.sh \
  scripts/s2-m4-validate-npu-stack.sh \
  scripts/90-validate.sh
do
  bash -n "$PROJECT_ROOT/$s"
  echo "[OK] syntax: $s"
done

help_out="$("$PROJECT_ROOT/ai370-optimize.sh" help 2>&1 || true)"
echo "$help_out" | grep -q "stage2-platform-validate" || { echo "[FAIL] help missing stage2-platform-validate"; exit 3; }
echo "$help_out" | grep -q "stage2-firmware-validate" || { echo "[FAIL] help missing stage2-firmware-validate"; exit 3; }
echo "$help_out" | grep -q "stage2-kernel-validate" || { echo "[FAIL] help missing stage2-kernel-validate"; exit 3; }
echo "$help_out" | grep -q "stage2-optimize-plan" || { echo "[FAIL] help missing stage2-optimize-plan"; exit 3; }
echo "$help_out" | grep -q "stage2-optimize-apply --approve" || { echo "[FAIL] help missing stage2-optimize-apply --approve"; exit 3; }
echo "$help_out" | grep -q "stage2-validate is a cheap runtime/NPU gate refresh" || {
  echo "[FAIL] help must keep stage2-validate as the runtime gate, not the platform aggregate"
  exit 3
}
echo "[OK] help documents Stage 2 platform commands and leaves stage2-validate as runtime gate"

if "$PROJECT_ROOT/ai370-optimize.sh" stage2-optimize-apply --profile="$SMOKE_PROFILE" --mode="$SMOKE_MODE"; then
  echo "[FAIL] stage2-optimize-apply without --approve must exit non-zero"
  exit 3
fi
echo "[OK] stage2-optimize-apply without --approve is rejected"

if [[ ! -f "$PROFILE_FIXTURE" ]]; then
  echo "[FAIL] missing versioned profile fixture: $PROFILE_FIXTURE"
  exit 2
fi

mkdir -p "$LATEST_DIR"
rm -f \
  "$LATEST_DIR/tier1-firmware.json" \
  "$LATEST_DIR/tier1-firmware-validation.json" \
  "$LATEST_DIR/s1-m1-raw-inventory.json"
cp "$PROFILE_FIXTURE" "$LATEST_DIR/s1-m5-system-profile.json"

"$PROJECT_ROOT/ai370-optimize.sh" stage2-firmware-validate \
  --profile="$SMOKE_PROFILE" --mode="$SMOKE_MODE"

for f in s1-m5-system-profile.json tier1-firmware.json tier1-firmware-validation.json
do
  if [[ ! -f "$LATEST_DIR/$f" ]]; then
    echo "[FAIL] missing artifact after stage2-firmware-validate: $f"
    exit 2
  fi
  echo "[OK] artifact present: $f"
done

python3 - "$LATEST_DIR/tier1-firmware.json" "$PROFILE_FIXTURE" <<'PY'
import json, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
fixture = json.load(open(sys.argv[2], encoding="utf-8"))
assert report.get("profile") == "generic-ryzen-ai", report.get("profile")
assert report.get("classified_platform_id") == "ai370", report.get("classified_platform_id")
assert report.get("bios_expected") == "2.01", report.get("bios_expected")
consumed = report.get("consumed_profile") or {}
assert consumed.get("schema", {}).get("version") == 3, consumed
assert consumed.get("fingerprint", {}).get("value") == fixture["fingerprint"]["value"], consumed
print("[OK] firmware validate consumed classified ai370 policy and Stage 1 fingerprint")
PY

echo "[PASS] Stage 2 platform smoke test completed successfully."
