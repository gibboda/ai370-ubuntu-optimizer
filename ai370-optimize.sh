#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

CMD=${1:-help}
PROFILE=${3:-ai370}

case "$CMD" in
  audit)
    bash scripts/01-hardware-audit.sh
    ;;

  plan)
    bash scripts/02-generate-report.sh
    ;;

  install)
    echo "[INFO] Installing profile: $PROFILE"
    bash scripts/10-amd-baseline.sh
    bash scripts/20-ai-stack.sh
    ;;

  validate)
    bash scripts/90-validate.sh
    ;;

  *)
    echo "Usage: $0 {audit|plan|install|validate}"
    exit 1
    ;;
esac
