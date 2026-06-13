#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
INVENTORY_JSON="$LATEST_DIR/hardware-inventory.json"
BASELINE_PLAN_JSON="$LATEST_DIR/baseline-plan.json"
BASELINE_POSTCHECK_JSON="$LATEST_DIR/baseline-postcheck.json"
BASELINE_VALIDATION_TXT="$LATEST_DIR/baseline-validation.txt"
BASELINE_VALIDATION_MD="$LATEST_DIR/baseline-validation.md"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "[ERROR] Missing required baseline artifact: $path"
    exit 3
  fi
}

main() {
  echo "[INFO] Phase 3: Kernel + AMD driver baseline validation"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"

  require_file "$BASELINE_PLAN_JSON"
  require_file "$BASELINE_POSTCHECK_JSON"

  local status
  status="$(python3 - "$BASELINE_PLAN_JSON" "$BASELINE_POSTCHECK_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    plan=json.load(fh)
with open(sys.argv[2], encoding="utf-8") as fh:
    post=json.load(fh)
if plan.get("plan_status") == "blocked":
    print("FAIL")
elif post.get("dry_run"):
    print("WARN")
elif post.get("status") == "PASS":
    print("PASS")
else:
    print("WARN")
PY
  )"

  {
    echo "$status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Inventory: $([[ -f "$INVENTORY_JSON" ]] && echo "$INVENTORY_JSON" || echo not-generated)"
    echo "Baseline plan: $BASELINE_PLAN_JSON"
    echo "Baseline postcheck: $BASELINE_POSTCHECK_JSON"
    echo "Postcheck dry run: $(python3 - "$BASELINE_POSTCHECK_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    print("true" if json.load(fh).get("dry_run") else "false")
PY
)"
  } > "$BASELINE_VALIDATION_TXT"

  python3 - "$BASELINE_PLAN_JSON" "$BASELINE_POSTCHECK_JSON" "$INVENTORY_JSON" > "$BASELINE_VALIDATION_MD" <<'PY'
import json, os, sys
plan_path, post_path, inventory_path = sys.argv[1:4]
with open(plan_path, encoding="utf-8") as fh:
    plan=json.load(fh)
with open(post_path, encoding="utf-8") as fh:
    post=json.load(fh)
print("# Baseline Validation")
print()
print(f"Plan status: {plan.get('plan_status', 'unknown')}")
print(f"Validation status: {plan.get('validation', {}).get('status', 'unknown')}")
print(f"Postcheck status: {post.get('status', 'unknown')}")
print(f"Postcheck dry run: {post.get('dry_run', False)}")
print(f"Inventory: {inventory_path if os.path.exists(inventory_path) else 'not-generated'}")
print()
print("## Postcheck results")
for name, result in post.get("checks", {}).items():
    print(f"- {result.get('status', 'UNKNOWN')} {name}")
print()
print("## Next steps")
if plan.get("plan_status") == "blocked":
    print("- Resolve blocked validation rules before applying AI runtime or acceleration phases.")
elif post.get("dry_run"):
    print("- Run baseline-apply without --dry-run before proceeding to ai-runtime or acceleration phases.")
elif post.get("status") == "PASS":
    print("- Proceed to ai-runtime if local Python AI packages are needed.")
    print("- Proceed to GPU/NPU detection before attempting acceleration enablement.")
else:
    print("- Review WARN postchecks; baseline may be usable, but acceleration should remain gated.")
PY

  echo "[INFO] Baseline validation status: $status"
  echo "[INFO] Wrote $BASELINE_VALIDATION_TXT"
  echo "[INFO] Wrote $BASELINE_VALIDATION_MD"

  if [[ "$status" == "FAIL" ]]; then
    exit 3
  fi
}

main "$@"
