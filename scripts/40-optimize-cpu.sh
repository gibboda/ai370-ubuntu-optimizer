#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Compatibility wrapper (Package C): CPU plan is part of 40-platform-tuning.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[WARN] 40-optimize-cpu.sh is deprecated; use ./ai370-optimize.sh stage2-optimize-plan"
exec bash "$SCRIPT_DIR/40-platform-tuning.sh" "$@"
