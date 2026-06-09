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
OFFLINE="false"

usage() {
  cat <<'USAGE'
Usage:
  ./ai370-optimize.sh hardware [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh firmware [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh kernel-amd [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--dry-run]
  ./ai370-optimize.sh tune [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh accel-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh ai-bench [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh llm-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh comfyui-install [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh comfyui-bench [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh final-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh all [--profile=ai370] [--mode=safe] [--persistence=runtime]

Requested nine-phase structure:
  Phase 1  hardware          Hardware detection
  Phase 2  firmware          BIOS / firmware baseline
  Phase 3  kernel-amd        Kernel + AMD driver baseline
  Phase 4  tune              CPU / RAM / storage tuning plan
  Phase 5  accel-validate    ROCm / Vulkan / OpenCL / XDNA validation
  Phase 6  ai-bench          Local AI benchmark suite
  Phase 7  llm-validate      Ollama / llama.cpp validation
  Phase 8  comfyui-install   ComfyUI installation
  Phase 9  comfyui-bench     ComfyUI workflow benchmarking

Backward-compatible aliases remain available:
  inventory, audit        -> hardware
  baseline-plan, plan     -> legacy baseline planning only
  baseline-apply          -> legacy baseline apply only
  baseline-validate       -> legacy baseline validation only
  ai-runtime              -> ai-bench
  gpu                     -> GPU half of accel-validate
  npu                     -> NPU half of accel-validate
  guide                   -> guided acceleration readiness plan
  execute                 -> generated acceleration checklists
  comfyui                 -> comfyui-install
  validate                -> final-validate
  install                 -> kernel-amd + ai-bench

Defaults:
  profile     ai370
  mode        safe
  persistence runtime

Notes:
  Use --profile=generic-ryzen-ai only when intentionally broadening beyond strict AI370 validation.
  baseline-apply --dry-run and kernel-amd --dry-run print the approved plan without installing packages.
  --offline makes phases 5-7 use only local wheelhouse/artifact/tool/model inputs where applicable.
  system persistence is reserved for future persistent tuning and is blocked by current scripts.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --profile=*) PROFILE="${arg#*=}" ;;
    --mode=*) MODE="${arg#*=}" ;;
    --persistence=*) PERSISTENCE="${arg#*=}" ;;
    --dry-run) DRY_RUN="true" ;;
    --offline) OFFLINE="true" ;;
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
  if [[ "$OFFLINE" == "true" ]]; then
    echo "[INFO] Offline mode: true"
  fi
}

load_runtime_config
print_context

case "$CMD" in
  hardware|inventory|audit)
    run_script "scripts/01-hardware-audit.sh"
    ;;

  firmware)
    run_script "scripts/05-firmware-baseline.sh"
    ;;

  kernel-amd)
    run_script "scripts/02-generate-report.sh"
    run_script "scripts/10-amd-baseline.sh" "$DRY_RUN"
    run_script "scripts/03-baseline-validate.sh"
    ;;

  tune)
    run_script "scripts/25-system-tuning.sh"
    ;;

  accel-validate)
    run_script "scripts/30-rocm-igpu.sh" "$OFFLINE"
    run_script "scripts/40-ryzen-ai-npu.sh" "$OFFLINE"
    ;;

  ai-bench|ai-runtime)
    run_script "scripts/20-ai-stack.sh" "$OFFLINE"
    ;;

  llm-validate)
    run_script "scripts/80-llm-validation.sh" "$OFFLINE"
    ;;

  comfyui-install|comfyui)
    run_script "scripts/70-comfyui-workflows.sh"
    ;;

  comfyui-bench)
    run_script "scripts/comfyui-benchmark.sh"
    ;;

  final-validate|validate)
    run_script "scripts/90-validate.sh"
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

  install)
    run_script "scripts/02-generate-report.sh"
    run_script "scripts/10-amd-baseline.sh" "$DRY_RUN"
    run_script "scripts/03-baseline-validate.sh"
    run_script "scripts/20-ai-stack.sh" "$OFFLINE"
    ;;

  gpu)
    run_script "scripts/30-rocm-igpu.sh" "$OFFLINE"
    ;;

  npu)
    run_script "scripts/40-ryzen-ai-npu.sh" "$OFFLINE"
    ;;

  guide)
    run_script "scripts/50-guided-acceleration.sh" "$OFFLINE"
    ;;

  execute)
    run_script "scripts/60-acceleration-execution.sh" "$OFFLINE"
    ;;

  all)
    if [[ "$OFFLINE" == "true" ]]; then
      echo "[ERROR] Command 'all' does not support --offline. Run phases 5-7 individually with --offline."
      exit 2
    fi
    run_script "scripts/01-hardware-audit.sh"
    run_script "scripts/05-firmware-baseline.sh"
    run_script "scripts/02-generate-report.sh"
    run_script "scripts/10-amd-baseline.sh" "$DRY_RUN"
    run_script "scripts/03-baseline-validate.sh"
    run_script "scripts/25-system-tuning.sh"
    run_script "scripts/30-rocm-igpu.sh" "$OFFLINE"
    run_script "scripts/40-ryzen-ai-npu.sh" "$OFFLINE"
    run_script "scripts/20-ai-stack.sh" "$OFFLINE"
    run_script "scripts/80-llm-validation.sh" "$OFFLINE"
    run_script "scripts/70-comfyui-workflows.sh"
    run_script "scripts/comfyui-benchmark.sh"
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
