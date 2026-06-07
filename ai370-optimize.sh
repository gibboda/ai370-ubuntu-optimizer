#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROJECT_NAME="ai370-ubuntu-optimizer"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CMD="${1:-help}"
PROFILE="ai370"
MODE="safe"
PERSISTENCE="runtime"
DRY_RUN="false"

usage() {
  cat <<'USAGE'
Usage:
  ./ai370-optimize.sh inventory [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh baseline-plan [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh baseline-apply [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--dry-run]
  ./ai370-optimize.sh baseline-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh ai-runtime [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh audit [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh plan [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh install [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh gpu [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh npu [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh guide [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh execute [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh comfyui [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh all [--profile=ai370] [--mode=safe] [--persistence=runtime]

Defaults:
  profile     ai370
  mode        safe
  persistence runtime

Notes:
  Use --profile=generic-ryzen-ai only when intentionally broadening beyond strict AI370 validation.
  audit/plan/install remain backward-compatible aliases for inventory/baseline-plan/baseline-apply+baseline-validate+ai-runtime.
  baseline-apply --dry-run prints the approved plan without installing packages.
  system persistence is reserved for a future persistent tuning phase and is blocked by current scripts.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --profile=*) PROFILE="${arg#*=}" ;;
    --mode=*) MODE="${arg#*=}" ;;
    --persistence=*) PERSISTENCE="${arg#*=}" ;;
    --dry-run) DRY_RUN="true" ;;
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

run_script() {
  local script="$1"
  shift || true
  require_file "$PROJECT_ROOT/$script"
  bash "$PROJECT_ROOT/$script" "$PROFILE" "$MODE" "$PERSISTENCE" "$@"
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
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[INFO] Dry run: true"
  fi
}

load_runtime_config
print_context

case "$CMD" in
  inventory|audit)
    run_script "scripts/01-hardware-audit.sh"
    ;;

  baseline-plan|plan)
    run_script "scripts/02-generate-report.sh"
    ;;

  baseline-apply)
    run_script "scripts/10-amd-baseline.sh" "$DRY_RUN"
    ;;

  baseline-validate)
    run_script "scripts/03-baseline-validate.sh"
    ;;

  ai-runtime)
    run_script "scripts/20-ai-stack.sh"
    ;;

  install)
    run_script "scripts/10-amd-baseline.sh" "$DRY_RUN"
    run_script "scripts/03-baseline-validate.sh"
    run_script "scripts/20-ai-stack.sh"
    ;;

  gpu)
    run_script "scripts/30-rocm-igpu.sh"
    ;;

  npu)
    run_script "scripts/40-ryzen-ai-npu.sh"
    ;;

  guide)
    run_script "scripts/50-guided-acceleration.sh"
    ;;

  execute)
    run_script "scripts/60-acceleration-execution.sh"
    ;;

  comfyui)
    run_script "scripts/70-comfyui-workflows.sh"
    ;;

  validate)
    run_script "scripts/90-validate.sh"
    ;;

  all)
    run_script "scripts/01-hardware-audit.sh"
    run_script "scripts/02-generate-report.sh"
    run_script "scripts/10-amd-baseline.sh" "$DRY_RUN"
    run_script "scripts/03-baseline-validate.sh"
    run_script "scripts/20-ai-stack.sh"
    run_script "scripts/30-rocm-igpu.sh"
    run_script "scripts/40-ryzen-ai-npu.sh"
    run_script "scripts/50-guided-acceleration.sh"
    run_script "scripts/60-acceleration-execution.sh"
    run_script "scripts/70-comfyui-workflows.sh"
    run_script "scripts/90-validate.sh"
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
