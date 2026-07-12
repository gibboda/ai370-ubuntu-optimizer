#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Compatibility wrapper (Package C): CPU plan is part of 40-platform-tuning.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[INFO] 40-optimize-cpu.sh → 40-platform-tuning.sh (combined platform tuning)"
exec bash "$SCRIPT_DIR/40-platform-tuning.sh" "$@"
