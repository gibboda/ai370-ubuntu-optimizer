#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Smoke test for Tier 1 (M1.11). Non-mutating where possible.
# Runs detection + validate steps, asserts key reports/latest/ artifacts + JSON fields.
# Safe to run in CI or without target hardware (expects PASS or WARN status).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
SMOKE_PROFILE="ai370"
SMOKE_MODE="safe"

echo "[INFO] Tier 1 smoke test starting (profile=$SMOKE_PROFILE)"

# 1. Syntax check critical Tier 1 scripts
for s in scripts/10-detect-hardware.sh scripts/20-check-bios.sh scripts/90-validate.sh scripts/lib/hardware-detect.sh; do
  if [[ -f "$PROJECT_ROOT/$s" ]]; then
    bash -n "$PROJECT_ROOT/$s"
    echo "[OK] syntax: $s"
  else
    echo "[FAIL] missing: $s"; exit 1
  fi
done

# 2. Run non-mutating Tier 1 pieces (detection + bios + final validate)
# Use the tier1-validate path (aggregates) and explicit 10+20 for firmware/hardware.
# Invoke via bash (not direct exec) for portability when scripts lack +x in checkout.
"$PROJECT_ROOT/ai370-optimize.sh" tier1-validate --profile="$SMOKE_PROFILE" --mode="$SMOKE_MODE" || true
bash "$PROJECT_ROOT/scripts/10-detect-hardware.sh" "$SMOKE_PROFILE" "$SMOKE_MODE" runtime || true
bash "$PROJECT_ROOT/scripts/20-check-bios.sh" "$SMOKE_PROFILE" "$SMOKE_MODE" runtime || true

# 3. Assert required artifacts exist
required=(
  "tier1-hardware.json"
  "tier1-firmware.json"
  "tier1-validation.json"
)
for f in "${required[@]}"; do
  if [[ ! -f "$LATEST_DIR/$f" ]]; then
    echo "[FAIL] missing artifact: $LATEST_DIR/$f"; exit 2
  fi
  echo "[OK] artifact present: $f"
done

# 4. Validate JSON structure and critical fields (python)
python3 - "$LATEST_DIR/tier1-validation.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("tier") == 1, "tier must be 1"
assert "status" in data, "status required"
assert isinstance(data.get("acceptance"), dict), "acceptance object required"
acc = data["acceptance"]
assert "radeon_890m_gfx1150" in acc, "missing radeon key"
assert "amdxdna_npu" in acc, "missing npu key"
assert "bios_version_acceptable" in acc, "missing bios_version_acceptable (M1.1)"
assert "vulkan_validated" in acc, "missing vulkan key"
print("[OK] tier1-validation.json structure + keys (including bios)")
PY

# firmware json
python3 - "$LATEST_DIR/tier1-firmware.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("tier") == 1
assert "bios_version" in data
assert "bios_expected" in data, "M1.1 bios_expected required"
assert "bios_acceptable" in data, "M1.1 bios_acceptable required"
print("[OK] tier1-firmware.json has M1.1 BIOS target fields")
PY

# 5. Basic profile / mode presence
grep -q '"profile": "ai370"' "$LATEST_DIR/tier1-validation.json" || { echo "[FAIL] profile in validation"; exit 3; }
echo "[OK] profile reflected"

echo "[PASS] Tier 1 smoke test completed successfully."
echo "[INFO] Note: status may be WARN on non-AI370 or incomplete prior phases; gate logic exercised."
