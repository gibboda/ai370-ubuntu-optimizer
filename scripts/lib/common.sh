# SPDX-License-Identifier: GPL-3.0-only
# shellcheck shell=bash
#
# Shared helpers for Stage 1/2 scripts.
# Requires PROJECT_ROOT to be set to the repository root before sourcing.
#
# Usage:
#   PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
#   # shellcheck source=lib/common.sh
#   source "$PROJECT_ROOT/scripts/lib/common.sh"
#   ai370_parse_standard_args "$@"
#   ai370_init_latest_dir

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  echo "[ERROR] common.sh requires PROJECT_ROOT to be set" >&2
  return 1 2>/dev/null || exit 1
fi

# Parse standard positional args used across installers/validators.
# Usage: ai370_parse_standard_args "$@"
# Sets: PROFILE MODE PERSISTENCE OFFLINE (and optional 5th RISK_ACCEPTED if present)
ai370_parse_standard_args() {
  PROFILE="${1:-ai370}"
  MODE="${2:-safe}"
  PERSISTENCE="${3:-runtime}"
  OFFLINE="${4:-false}"
  ACCEPT_AMD_ACCELERATION_RISK="${5:-false}"
}

ai370_init_latest_dir() {
  LATEST_DIR="${LATEST_DIR:-$PROJECT_ROOT/reports/latest}"
  mkdir -p "$LATEST_DIR"
}

ai370_require_runtime_persistence() {
  local feature="${1:-this feature}"
  if [[ "${PERSISTENCE:-runtime}" == "system" ]]; then
    echo "[ERROR] Persistent $feature is not implemented. Use --persistence=runtime."
    exit 2
  fi
}

ai370_utc_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Print status field from a JSON report (or MISSING / UNREADABLE).
# Usage: ai370_json_status path [comma,separated,keys]
ai370_json_status() {
  local path="$1"
  local keys="${2:-status}"
  if [[ ! -f "$path" ]]; then
    echo "MISSING"
    return 0
  fi
  python3 - "$path" "$keys" <<'PY' 2>/dev/null || echo "UNREADABLE"
import json, sys
path, keys = sys.argv[1], sys.argv[2].split(",")
try:
    data = json.load(open(path))
except Exception:
    print("UNREADABLE")
    raise SystemExit
status = None
for key in keys:
    if key in data and data[key] is not None:
        status = data[key]
        break
print(str(status if status is not None else "UNKNOWN").upper())
PY
}

# True if path exists and mtime is newer than max_age_sec (default 6h).
ai370_report_fresh() {
  local path="$1"
  local max_age_sec="${2:-21600}"
  [[ -f "$path" ]] || return 1
  local now mtime age
  now="$(date +%s)"
  mtime="$(stat -c %Y "$path" 2>/dev/null || echo 0)"
  age=$((now - mtime))
  [[ "$age" -ge 0 && "$age" -le "$max_age_sec" ]]
}

# Write reports/latest/INDEX.md summarizing gate vs diagnostic artifacts.
ai370_write_report_index() {
  local latest="${1:-${LATEST_DIR:-$PROJECT_ROOT/reports/latest}}"
  mkdir -p "$latest"
  local index="$latest/INDEX.md"
  {
    echo "# reports/latest index"
    echo
    echo "Generated: $(ai370_utc_now)"
    echo
    echo "## Stage gate artifacts"
    echo
    echo "| Artifact | Status | Role |"
    echo "| --- | --- | --- |"
    local f st
    for f in tier1-validation.json tier2-validation.json offline-model-storage.json tier3-validation.json; do
      st="$(ai370_json_status "$latest/$f" "status,tier1_status")"
      echo "| \`$f\` | $st | Stage 3 gate input |"
    done
    echo
    echo "## Diagnostic / optional reports (present files)"
    echo
    echo "| File | Status |"
    echo "| --- | --- |"
    local path base
    shopt -s nullglob
    for path in "$latest"/*.json; do
      base="$(basename "$path")"
      case "$base" in
        tier1-validation.json|tier2-validation.json|offline-model-storage.json|tier3-validation.json) continue ;;
      esac
      st="$(ai370_json_status "$path" "status")"
      echo "| \`$base\` | $st |"
    done
    shopt -u nullglob
    echo
    echo "Gate policy: see docs/ROADMAP.md (Stage gate policy)."
  } > "$index"
  echo "[INFO] Wrote $index"
}
