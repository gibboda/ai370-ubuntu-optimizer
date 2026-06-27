#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Generated Tier 1 CPU runtime tuning commands. Review before execution.
set -euo pipefail

echo "[TUNE] Setting power profile (runtime)..."
if command -v powerprofilesctl >/dev/null 2>&1; then
  powerprofilesctl set balanced || true
else
  echo "[WARN] powerprofilesctl not available."
fi

echo "[TUNE] CPU frequency info (if cpupower present)..."
if command -v cpupower >/dev/null 2>&1; then
  cpupower frequency-info || true
fi
