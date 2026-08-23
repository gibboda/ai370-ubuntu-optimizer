#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Compatibility wrapper (Package C): firmware validation is part of 20-check-bios.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[WARN] 25-check-firmware.sh is deprecated; use ./ai370-optimize.sh stage2-firmware-validate"
exec bash "$SCRIPT_DIR/20-check-bios.sh" "$@"
