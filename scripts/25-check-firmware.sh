#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Compatibility wrapper (Package C): firmware validation is part of 20-check-bios.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[INFO] 25-check-firmware.sh → 20-check-bios.sh (combined BIOS + firmware baseline)"
exec bash "$SCRIPT_DIR/20-check-bios.sh" "$@"
