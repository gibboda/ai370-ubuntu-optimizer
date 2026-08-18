#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Smoke test for Stage 2 platform commands (PR 3a). Non-mutating.
# Safe without AI370 hardware and without network.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
SMOKE_PROFILE="ai370"
SMOKE_MODE="safe"

echo "[INFO] Stage 2 platform smoke test starting (profile=$SMOKE_PROFILE)"

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

"$PROJECT_ROOT/ai370-optimize.sh" stage1 --profile="$SMOKE_PROFILE" --mode="$SMOKE_MODE" || true
if [[ ! -f "$LATEST_DIR/s1-m5-system-profile.json" ]]; then
  echo "[FAIL] stage1 must publish s1-m5-system-profile.json"
  exit 2
fi
echo "[OK] stage1 published s1-m5-system-profile.json"

"$PROJECT_ROOT/ai370-optimize.sh" stage2-platform-validate --profile="$SMOKE_PROFILE" --mode="$SMOKE_MODE" || true

for f in \
  s1-m5-system-profile.json \
  tier1-firmware.json \
  s2-m3-gpu-runtime-visibility.json \
  s2-m4-npu-runtime-validation.json \
  tier1-validation.json
do
  if [[ ! -f "$LATEST_DIR/$f" ]]; then
    echo "[FAIL] missing artifact after stage2-platform-validate: $f"
    exit 2
  fi
  echo "[OK] artifact present: $f"
done

python3 - "$LATEST_DIR/tier1-validation.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("scope") == "inventory", f"platform-validate uses inventory-scope 90-validate, got {data.get('scope')}"
assert data.get("acceptance", {}).get("ai_smoke_required") is False
print("[OK] platform-validate compatibility aggregate is inventory-scope (no tuning/smoke required)")
PY

python3 - "$LATEST_DIR/s2-m4-npu-runtime-validation.json" "$PROJECT_ROOT" <<'PY'
import importlib.util, json, sys
from pathlib import Path
root = Path(sys.argv[2])
spec = importlib.util.spec_from_file_location("system_profile", root / "scripts/lib/system_profile.py")
ladder_spec = importlib.util.spec_from_file_location("capability_ladder", root / "scripts/lib/capability_ladder.py")
system_profile = importlib.util.module_from_spec(spec)
capability_ladder = importlib.util.module_from_spec(ladder_spec)
spec.loader.exec_module(system_profile)
ladder_spec.loader.exec_module(capability_ladder)
report = json.load(open(sys.argv[1], encoding="utf-8"))
system_profile.validate_document(report, capability_ladder.S2_M4_SCHEMA, "S2-M4")
assert report["ladder"]["validation_claim"] is False
print("[OK] platform-validate NPU report is visibility-only")
PY

"$PROJECT_ROOT/ai370-optimize.sh" stage2-optimize-plan --profile="$SMOKE_PROFILE" --mode="$SMOKE_MODE" || true
if [[ ! -f "$LATEST_DIR/tier1-platform-tuning.json" ]]; then
  echo "[FAIL] missing artifact: tier1-platform-tuning.json"
  exit 2
fi

"$PROJECT_ROOT/ai370-optimize.sh" stage2-optimize-apply --dry-run --approve \
  --profile="$SMOKE_PROFILE" --mode="$SMOKE_MODE" || true
python3 - "$LATEST_DIR/tier1-platform-tuning.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
ra = data.get("runtime_apply") or {}
assert ra.get("requested") is True, "approved apply should request apply"
assert ra.get("dry_run") is True, "dry-run must be recorded"
assert ra.get("applied") is False, "dry-run must not apply commands"
print("[OK] stage2-optimize-apply --approve --dry-run is non-mutating")
PY

echo "[PASS] Stage 2 platform smoke test completed successfully."
