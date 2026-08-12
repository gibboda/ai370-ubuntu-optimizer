#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# S1-M1: publish the read-only raw system inventory.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$PROJECT_ROOT/reports/latest/s1-m1-raw-inventory.json"
FIXTURE=""
while (($#)); do
  case "$1" in
    --output) OUTPUT="${2:?--output requires a path}"; shift 2 ;;
    --fixture) FIXTURE="${2:?--fixture requires a path}"; shift 2 ;;
    --help|-h) printf '%s\n' 'Usage: s1-m1-probe-system.sh [--output PATH] [--fixture PATH]' 'S1-M1 read-only probe; --fixture replays sanitized test evidence.'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
mkdir -p "$(dirname "$OUTPUT")"
temporary="$(mktemp "$(dirname "$OUTPUT")/.s1-m1-raw-inventory.XXXXXX")"
trap 'rm -f "$temporary"' EXIT
if [[ -n "$FIXTURE" ]]; then
  python3 - "$FIXTURE" >"$temporary" <<'PY'
import json, sys
from pathlib import Path
print(json.dumps(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")), indent=2, sort_keys=True))
PY
else
  # shellcheck source=scripts/lib/hardware-detect.sh
  source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"
  collect_stage1_raw_probes "$@" >"$temporary"
fi
python3 -m json.tool "$temporary" >/dev/null
mv -f "$temporary" "$OUTPUT"
trap - EXIT
echo "[INFO] S1-M1 raw inventory written to $OUTPUT"
