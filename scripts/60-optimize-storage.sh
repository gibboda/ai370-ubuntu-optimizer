#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 1: Storage optimization / health visibility (NVMe, smart, lsblk). Runtime recommendations only.

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
  echo "[INFO] Tier 1 / 60-optimize-storage.sh"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE"

  STORAGE="$(detect_storage_text)"
  NVME="$(detect_nvme_text)"

  {
    echo "# Tier 1 Storage Health"
    echo
    echo "## Block devices"
    lsblk -o NAME,MODEL,SIZE,TYPE,MOUNTPOINTS 2>/dev/null || echo "(lsblk unavailable)"
    echo
    echo "## NVMe"
    echo "${NVME:-No NVMe devices detected via lsblk}"
    echo
    echo "Run 'sudo nvme list' and 'sudo smartctl -a /dev/nvme0n1' (or equivalent) for detailed health."
  } > "$LATEST_DIR/tier1-storage.md"

  echo "[INFO] 60-optimize-storage.sh complete."
}

main "$@"
