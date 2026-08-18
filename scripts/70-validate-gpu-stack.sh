#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Compatibility wrapper for S2-M3 GPU stack visibility.
# Canonical owner: scripts/s2-m3-validate-gpu-stack.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[WARN] 70-validate-gpu-stack.sh is compatibility-only; prefer stage2-gpu-validate / s2-m3-validate-gpu-stack.sh"
exec bash "$SCRIPT_DIR/s2-m3-validate-gpu-stack.sh" "$@"
