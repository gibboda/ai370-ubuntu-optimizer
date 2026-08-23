#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Compatibility wrapper (Package C): memory plan is part of 40-platform-tuning.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[WARN] 50-optimize-memory.sh is deprecated; use ./ai370-optimize.sh stage2-optimize-plan"
exec bash "$SCRIPT_DIR/40-platform-tuning.sh" "$@"
