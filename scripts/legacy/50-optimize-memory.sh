#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 1: Memory optimization (visibility + zram/swap notes). Runtime only.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

LATEST_DIR="$PROJECT_ROOT/reports/latest"
mkdir -p "$LATEST_DIR"

main() {
  echo "[INFO] Tier 1 / 50-optimize-memory.sh"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent memory tuning not implemented. Use --persistence=runtime."
    exit 2
  fi

  MEM_TOTAL="$(detect_memory_total)"
  ZRAM_ACTIVE="$(systemctl is-active systemd-zram-setup@zram0.service 2>/dev/null || echo inactive)"
  SWAP_SHOW="$(swapon --show --noheadings 2>/dev/null || true)"

  {
    echo "# Tier 1 Memory Report"
    echo
    echo "- Total memory: $MEM_TOTAL"
    echo "- zram0 active: $ZRAM_ACTIVE"
    echo "- Current swap:"
    echo "$SWAP_SHOW"
    echo
    echo "Recommendations (runtime-only):"
    echo "- Consider enabling zram for better interactive behavior on 32/64 GB LPDDR5X systems."
    echo "- Review swappiness if using heavy local LLM inference."
  } > "$LATEST_DIR/tier1-memory.md"

  echo "[INFO] 50-optimize-memory.sh complete."
}

main "$@"
