#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROJECT_NAME="ai370-ubuntu-optimizer"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CMD="${1:-help}"
PROFILE="ai370"
MODE="safe"
PERSISTENCE="runtime"

usage() {
  cat <<'USAGE'
Usage:
  ./ai370-optimize.sh audit [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh plan [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh install [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime|system]
  ./ai370-optimize.sh validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime|system]

Defaults:
  profile     ai370
  mode        safe
  persistence runtime

Safety:
  system persistence is reserved for future persistent tuning and is blocked unless explicitly supported by a script.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --profile=*) PROFILE="${arg#*=}" ;;
    --mode=*) MODE="${arg#*=}" ;;
    --persistence=*) PERSISTENCE="${arg#*=}" ;;
  esac
done

case "$MODE" in
  safe|aggressive) ;;
  *) echo "[ERROR] Invalid mode: $MODE"; exit 2 ;;
esac

case "$PERSISTENCE" in
  runtime|system) ;;
  *) echo "[ERROR] Invalid persistence: $PERSISTENCE"; exit 2 ;;
esac

PROFILE_FILE="$PROJECT_ROOT/config/profiles/${PROFILE}.env"
MODE_FILE="$PROJECT_ROOT/config/tuning/${MODE}.env"
PERSISTENCE_FILE="$PROJECT_ROOT/config/persistence/${PERSISTENCE}.env"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "[ERROR] Missing required file: $path"
    exit 2
  fi
}

load_runtime_config() {
  require_file "$PROFILE_FILE"
  require_file "$MODE_FILE"
  require_file "$PERSISTENCE_FILE"
  # shellcheck source=/dev/null
  source "$PROFILE_FILE"
  # shellcheck source=/dev/null
  source "$MODE_FILE"
  # shellcheck source=/dev/null
  source "$PERSISTENCE_FILE"
}

print_context() {
  echo "[INFO] Project: $PROJECT_NAME"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"
}

load_runtime_config
print_context

case "$CMD" in
  audit)
    bash "$PROJECT_ROOT/scripts/01-hardware-audit.sh" "$PROFILE" "$MODE" "$PERSISTENCE"
    ;;

  plan)
    bash "$PROJECT_ROOT/scripts/02-generate-report.sh" "$PROFILE" "$MODE" "$PERSISTENCE"
    ;;

  install)
    bash "$PROJECT_ROOT/scripts/10-amd-baseline.sh" "$PROFILE" "$MODE" "$PERSISTENCE"
    bash "$PROJECT_ROOT/scripts/20-ai-stack.sh" "$PROFILE" "$MODE" "$PERSISTENCE"
    ;;

  validate)
    bash "$PROJECT_ROOT/scripts/90-validate.sh" "$PROFILE" "$MODE" "$PERSISTENCE"
    ;;

  help|-h|--help)
    usage
    ;;

  *)
    echo "[ERROR] Unknown command: $CMD"
    usage
    exit 1
    ;;
esac
