#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Compatibility wrapper (Package C): NPU detection is part of 10-detect-hardware.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[WARN] 75-detect-npu.sh is deprecated; use ./ai370-optimize.sh stage1-probe" >&2
exec bash "$SCRIPT_DIR/s1-m1-probe-system.sh"
