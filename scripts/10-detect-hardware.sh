#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Compatibility wrapper. Use the canonical S1-M1 stage1-probe command.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[WARN] 10-detect-hardware.sh is deprecated; use ./ai370-optimize.sh stage1-probe" >&2
if (($#)) && [[ "$1" != --* ]]; then
  # Historical PROFILE MODE PERSISTENCE arguments no longer influence facts.
  shift "$(( $# < 3 ? $# : 3 ))"
fi
exec bash "$SCRIPT_DIR/s1-m1-probe-system.sh" "$@"
