#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="reports/${TIMESTAMP}"
mkdir -p "$OUT_DIR"

JSON_FILE="$OUT_DIR/hardware.json"
TXT_FILE="$OUT_DIR/hardware-audit.txt"

command_exists() { command -v "$1" >/dev/null 2>&1; }

{
  echo "=== SYSTEM ==="
  uname -a || true
  lsb_release -a 2>/dev/null || true

  echo "\n=== CPU ==="
  lscpu || true

  echo "\n=== MEMORY ==="
  free -h || true

  echo "\n=== PCI ==="
  lspci -nnk || true

  echo "\n=== STORAGE ==="
  lsblk -o NAME,MODEL,SIZE,TYPE || true

  echo "\n=== GPU MODULE ==="
  lsmod | grep amdgpu || true

  echo "\n=== NPU (XDNA) ==="
  lsmod | grep -Ei 'amdxdna|xrt' || true

  echo "\n=== FIRMWARE ==="
  fwupdmgr get-devices 2>/dev/null || true

} | tee "$TXT_FILE"

# Minimal JSON (expand in next phase)
cat > "$JSON_FILE" <<EOF
{
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "timestamp": "$TIMESTAMP"
}
EOF

echo "[INFO] Audit complete: $OUT_DIR"
