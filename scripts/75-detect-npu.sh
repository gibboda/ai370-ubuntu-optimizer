#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Compatibility wrapper (Package C): NPU detection is part of 10-detect-hardware.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[INFO] 75-detect-npu.sh → 10-detect-hardware.sh (NPU section included in hardware inventory)"
# Drop optional 4th OFFLINE arg for hardware script compatibility
exec bash "$SCRIPT_DIR/10-detect-hardware.sh" "${1:-ai370}" "${2:-safe}" "${3:-runtime}"
