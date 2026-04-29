#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

OUT="reports/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

{
  echo "=== CPU ==="
  lscpu

  echo "=== GPU ==="
  lspci | grep -i vga || true

  echo "=== MEMORY ==="
  free -h

  echo "=== STORAGE ==="
  lsblk

  echo "=== NPU (XDNA) ==="
  ls /dev | grep -i accel || true

} | tee "$OUT/audit.txt"

 echo "Report saved to $OUT"
