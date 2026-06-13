#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

main() {
  echo "[INFO] Installing AnythingLLM (offline mode)..."
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE"
}

main "$@"
