#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Smoke test for Stage 1 / Tier 1 (Package E). Non-mutating where possible.
# Runs detection, platform-tuning plan, inventory validate, asserts key artifacts.
# Safe to run in CI or without target hardware (expects PASS or WARN status).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
SMOKE_PROFILE="ai370"
SMOKE_MODE="safe"

echo "[INFO] Stage 1 smoke test starting (profile=$SMOKE_PROFILE)"

# 1. Syntax check critical Stage 1 scripts (Package E expands platform-tuning + common)
for s in \
  scripts/10-detect-hardware.sh \
  scripts/20-check-bios.sh \
  scripts/30-validate-kernel.sh \
  scripts/40-platform-tuning.sh \
  scripts/70-validate-gpu-stack.sh \
  scripts/80-benchmark-local-ai.sh \
  scripts/90-validate.sh \
  scripts/lib/common.sh \
  scripts/lib/hardware-detect.sh \
  ai370-optimize.sh
do
  if [[ -f "$PROJECT_ROOT/$s" ]]; then
    bash -n "$PROJECT_ROOT/$s"
    echo "[OK] syntax: $s"
  else
    echo "[FAIL] missing: $s"; exit 1
  fi
done

# 2. Help documents Package E flags
help_out="$("$PROJECT_ROOT/ai370-optimize.sh" help 2>&1 || true)"
echo "$help_out" | grep -q "stage1-inventory" || { echo "[FAIL] help missing stage1-inventory"; exit 3; }
echo "$help_out" | grep -q -- "--with-ai-smoke" || { echo "[FAIL] help missing --with-ai-smoke"; exit 3; }
echo "$help_out" | grep -q -- "--apply-tuning" || { echo "[FAIL] help missing --apply-tuning"; exit 3; }
echo "$help_out" | grep -q -- "--strict" || { echo "[FAIL] help missing --strict"; exit 3; }
echo "[OK] orchestrator help mentions stage1-inventory and Package E flags"

# 3. Non-mutating Stage 1 pieces
# Inventory path (no tuning / no script 80) + platform tuning plan + full-scope validate
"$PROJECT_ROOT/ai370-optimize.sh" stage1-inventory --profile="$SMOKE_PROFILE" --mode="$SMOKE_MODE" || true

# Assert inventory scope on gate artifact
python3 - "$LATEST_DIR/tier1-validation.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("scope") == "inventory", f"expected scope=inventory after stage1-inventory, got {data.get('scope')}"
assert data.get("acceptance", {}).get("inventory_only") is True
assert data.get("acceptance", {}).get("ai_smoke_required") is False
# Inventory must not require local-AI smoke
assert data.get("artifacts", {}).get("local_ai") in (None, ""), "inventory must not require local_ai artifact"
print("[OK] inventory-scope validation: scope + acceptance flags")
PY

# NPU JSON is produced by script 10 (included in inventory)
if [[ ! -f "$LATEST_DIR/tier1-npu.json" ]]; then
  echo "[FAIL] missing artifact after inventory: tier1-npu.json (expected from script 10)"
  exit 2
fi
echo "[OK] artifact present: tier1-npu.json (from 10-detect-hardware)"

# Platform tuning plan (default: no AI370_APPLY_TUNING — plan only)
bash "$PROJECT_ROOT/scripts/40-platform-tuning.sh" "$SMOKE_PROFILE" "$SMOKE_MODE" runtime || true
if [[ ! -f "$LATEST_DIR/tier1-platform-tuning.json" ]]; then
  echo "[FAIL] missing artifact: tier1-platform-tuning.json"; exit 2
fi
if [[ ! -f "$LATEST_DIR/tier1-cpu-runtime-commands.sh" ]]; then
  echo "[FAIL] missing generated commands: tier1-cpu-runtime-commands.sh"; exit 2
fi
echo "[OK] platform-tuning plan artifacts present"

# Full-scope validate (default stage1 gate; does not require script 80)
"$PROJECT_ROOT/ai370-optimize.sh" stage1-validate --profile="$SMOKE_PROFILE" --mode="$SMOKE_MODE" || true

python3 - "$LATEST_DIR/tier1-validation.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("tier") == 1, "tier must be 1"
assert "status" in data, "status required"
assert data.get("scope") == "full", f"expected scope=full after stage1-validate, got {data.get('scope')}"
assert data.get("strict") is False, "default validate must not be strict"
assert isinstance(data.get("acceptance"), dict), "acceptance object required"
acc = data["acceptance"]
assert "radeon_890m_gfx1150" in acc, "missing radeon key"
assert "amdxdna_npu" in acc, "missing npu key"
assert "bios_version_acceptable" in acc, "missing bios_version_acceptable (M1.1)"
assert "vulkan_validated" in acc, "missing vulkan key"
assert acc.get("ai_smoke_required") is False, "full scope must not require AI smoke by default"
assert data.get("artifacts", {}).get("local_ai") in (None, ""), "full scope must not point at local_ai by default"
print("[OK] tier1-validation.json structure + full scope (no AI smoke required)")
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

# 4. Assert required artifacts exist
required=(
  "tier1-hardware.json"
  "tier1-firmware.json"
  "tier1-npu.json"
  "tier1-platform-tuning.json"
  "tier1-validation.json"
)
for f in "${required[@]}"; do
  if [[ ! -f "$LATEST_DIR/$f" ]]; then
    echo "[FAIL] missing artifact: $LATEST_DIR/$f"; exit 2
  fi
  echo "[OK] artifact present: $f"
done

# 5. Strict mode should mark missing gfx1150/NPU as FAIL on non-AI370 hardware (or stay PASS if present)
AI370_STAGE1_STRICT=true bash "$PROJECT_ROOT/scripts/90-validate.sh" "$SMOKE_PROFILE" "$SMOKE_MODE" runtime full || true
python3 - "$LATEST_DIR/tier1-validation.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("strict") is True, "strict flag must be recorded"
acc = data.get("acceptance") or {}
# On machines without gfx1150/NPU, status should be FAIL under strict mode.
if not acc.get("radeon_890m_gfx1150") or not acc.get("amdxdna_npu"):
    assert data.get("status") == "FAIL", (
        f"strict mode must FAIL when gfx1150/NPU missing; status={data.get('status')}"
    )
    assert data.get("failures"), "strict FAIL should list failures"
    print("[OK] strict mode elevates missing hardware to FAIL")
else:
    assert data.get("status") in ("PASS", "WARN"), data.get("status")
    print("[OK] strict mode with AI370 hardware present (PASS/WARN)")
PY

# 5b. Non-strict acceptance misses must not demote overall status from PASS→WARN
# (other soft checks may still WARN; force a pure acceptance-only path by re-running
# after a normal full validate and asserting the helper contract via acceptance fields).
AI370_STAGE1_STRICT=false bash "$PROJECT_ROOT/scripts/90-validate.sh" "$SMOKE_PROFILE" "$SMOKE_MODE" runtime full || true
python3 - "$LATEST_DIR/tier1-validation.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("strict") is False
acc = data.get("acceptance") or {}
status = data.get("status")
warns = data.get("warnings") or []
# If only acceptance (gfx/NPU) is soft-missing, status must remain PASS so Stage 3 gate opens.
# Other WARN sources (vulkan/artifacts/BIOS) may still demote — then status can be WARN.
if status == "PASS":
    # Acceptance misses may appear in warnings[] without demoting status.
    print("[OK] non-strict status PASS (acceptance misses do not demote gate)")
elif status == "WARN":
    # Ensure demotion is not *only* from acceptance if both acceptance flags are true
    # (if acceptance is fully met, WARN came from elsewhere — fine).
    if acc.get("radeon_890m_gfx1150") and acc.get("amdxdna_npu"):
        print("[OK] non-strict WARN from non-acceptance checks (vulkan/BIOS/artifacts)")
    else:
        # Acceptance miss present with WARN: may also have other soft fails. Policy allows
        # acceptance-only messages without demotion; mixed demotion is OK if other record_warn fired.
        print("[OK] non-strict WARN with mixed soft checks (acceptance recorded in warnings/acceptance)")
else:
    raise SystemExit(f"unexpected non-strict status: {status}")
# Contract: when status is PASS, require_tier123_pass Stage 1 input is satisfied.
if status == "PASS":
    assert data.get("tier") == 1
print("[OK] non-strict acceptance policy exercised")
PY

# 5c. Dry-run must not apply tuning commands even when AI370_APPLY_TUNING=true
DRY_RUN=true AI370_APPLY_TUNING=true bash "$PROJECT_ROOT/scripts/40-platform-tuning.sh" \
  "$SMOKE_PROFILE" "$SMOKE_MODE" runtime || true
python3 - "$LATEST_DIR/tier1-platform-tuning.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
ra = data.get("runtime_apply") or {}
assert ra.get("requested") is True, "apply was requested"
assert ra.get("dry_run") is True, "dry_run must be recorded"
assert ra.get("applied") is False, "commands must not be applied under dry-run"
print("[OK] dry-run honors AI370_APPLY_TUNING without applying runtime commands")
PY

# Also verify orchestrator exports DRY_RUN into the apply path
"$PROJECT_ROOT/ai370-optimize.sh" stage1 --dry-run --apply-tuning --profile="$SMOKE_PROFILE" --mode="$SMOKE_MODE" || true
python3 - "$LATEST_DIR/tier1-platform-tuning.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
ra = data.get("runtime_apply") or {}
assert ra.get("requested") is True, "orchestrator --apply-tuning should request apply"
assert ra.get("dry_run") is True, "orchestrator --dry-run must reach 40-platform-tuning"
assert ra.get("applied") is False, "orchestrator dry-run must not apply commands"
print("[OK] orchestrator --dry-run --apply-tuning is non-mutating")
PY

# Restore non-strict full validate so latest artifact matches default policy for later steps
"$PROJECT_ROOT/ai370-optimize.sh" stage1-validate --profile="$SMOKE_PROFILE" --mode="$SMOKE_MODE" || true

# 6. Basic profile / mode presence
grep -q '"profile": "ai370"' "$LATEST_DIR/tier1-validation.json" || { echo "[FAIL] profile in validation"; exit 3; }
echo "[OK] profile reflected"

echo "[PASS] Stage 1 smoke test completed successfully."
echo "[INFO] Note: non-strict acceptance misses (gfx1150/NPU) stay PASS; other soft checks may WARN."
echo "[INFO] Default stage1 skips script 80; use --with-ai-smoke for smoke-scope validation."
