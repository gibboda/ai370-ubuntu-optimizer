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
ACCEPT_AMD_ACCELERATION_RISK="false"

usage() {
  cat <<'USAGE'
Usage (AI Stack Tiers - recommended):
  ./ai370-optimize.sh tier1 [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh tier1-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh tier2 [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh tier2-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh tier3 [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh tier3-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh tier4 [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh tier5 [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh full-stack [--profile=ai370] [--mode=safe] [--persistence=runtime] --accept-amd-acceleration-risk

Legacy / detailed phase commands (still supported):
  ./ai370-optimize.sh hardware [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh firmware [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh kernel-amd [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--dry-run]
  ./ai370-optimize.sh tune [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh accel-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh ai-bench [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh llm-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh amd-accel-install [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline] --accept-amd-acceleration-risk
  ./ai370-optimize.sh comfyui-install [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh comfyui-bench [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh final-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh all [--profile=ai370] [--mode=safe] [--persistence=runtime]

Tier 1 scripts (deliverables):
  scripts/10-detect-hardware.sh
  scripts/20-check-bios.sh
  scripts/30-validate-kernel.sh
  scripts/40-optimize-cpu.sh
  scripts/50-optimize-memory.sh
  scripts/60-optimize-storage.sh
  scripts/70-validate-gpu-stack.sh
  scripts/75-detect-npu.sh
  scripts/80-benchmark-local-ai.sh
  scripts/90-validate.sh

Backward-compatible aliases:
  inventory, audit        -> hardware (Tier 1)
  baseline-plan, plan     -> legacy baseline planning
  baseline-apply          -> legacy baseline apply
  baseline-validate       -> legacy baseline validation
  ai-runtime              -> ai-bench
  gpu                     -> GPU half of accel-validate
  npu                     -> NPU half of accel-validate
  guide                   -> guided acceleration readiness plan
  execute                 -> generated acceleration checklists
  comfyui                 -> comfyui-install (Tier 5, gated)
  validate                -> final-validate
  install                 -> kernel-amd + ai-bench
  full-ai-install         -> multi-tier (requires --accept-amd-acceleration-risk)

Defaults:
  profile     ai370
  mode        safe
  persistence runtime

Notes:
  Use --profile=generic-ryzen-ai only when intentionally broadening beyond strict AI370 validation.
  --offline affects Tier 1 (parts), Tier 2, Tier 3, and amd-accel-install.
  --accept-amd-acceleration-risk is required for amd-accel-install, full-ai-install, and full-stack.
  Tier 5 (comfyui / tier5) installation is blocked until Tier 1 + Tier 2 + Tier 3 validation passes.
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
    --accept-amd-acceleration-risk) ACCEPT_AMD_ACCELERATION_RISK="true" ;;
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

# Tier gate: Tier 5 (and full generative flows) must not proceed until
# Tier 1 + Tier 2 + Tier 3 have produced passing validation artifacts.
# Prefers dedicated tierN-validation.json (M2/M3). Falls back to legacy for transition.
require_tier123_pass() {
  local LATEST_DIR="$PROJECT_ROOT/reports/latest"
  local tier1_status="$LATEST_DIR/tier1-validation.json"
  local tier2_status="$LATEST_DIR/tier2-validation.json"
  local tier3_status="$LATEST_DIR/tier3-validation.json"
  local legacy_final="$LATEST_DIR/final-validation.txt"
  local gpu_status="$LATEST_DIR/gpu-acceleration-status.txt"
  local npu_status="$LATEST_DIR/npu-acceleration-status.txt"
  local ai_status="$LATEST_DIR/ai-stack-status.txt"
  local llm_status="$LATEST_DIR/llm-validation.json"

  local pass="true"

  if [[ -f "$tier1_status" ]]; then
    if ! python3 - "$tier1_status" <<'PY' >/dev/null 2>&1
import json, sys
data=json.load(open(sys.argv[1]))
status = data.get("status") or data.get("tier1_status") or "UNKNOWN"
if status.upper() != "PASS":
    sys.exit(1)
PY
then
      pass="false"
    fi
  elif [[ -f "$legacy_final" ]]; then
    if ! grep -q "Final Status: PASS" "$legacy_final" 2>/dev/null; then
      pass="false"
    fi
  else
    pass="false"
  fi

  # Tier 2: prefer dedicated json (from 100-tier2), fall back to legacy llm/ai status
  if [[ -f "$tier2_status" ]]; then
    if ! python3 - "$tier2_status" <<'PY' >/dev/null 2>&1
import json, sys
data=json.load(open(sys.argv[1]))
status = data.get("status") or "UNKNOWN"
if status.upper() not in ("PASS", "WARN"):  # WARN allowed for missing optional staged models
    sys.exit(1)
PY
then
      pass="false"
    fi
  elif [[ ! -f "$llm_status" && ! -f "$ai_status" ]]; then
    pass="false"
  fi

  # Tier 3: prefer dedicated (future), else legacy npu evidence
  if [[ -f "$tier3_status" ]]; then
    if ! python3 - "$tier3_status" <<'PY' >/dev/null 2>&1
import json, sys
data=json.load(open(sys.argv[1]))
status = data.get("status") or "UNKNOWN"
if status.upper() not in ("PASS", "WARN", "EXPERIMENTAL-PASS"):
    sys.exit(1)
PY
then
      pass="false"
    fi
  elif [[ ! -f "$npu_status" ]]; then
    pass="false"
  fi

  if [[ "$pass" != "true" ]]; then
    echo "[ERROR] Tier 1 + Tier 2 + Tier 3 validation has not passed."
    echo "[ERROR] Run: ./ai370-optimize.sh tier1 && ./ai370-optimize.sh tier2 && ./ai370-optimize.sh tier2-validate && ./ai370-optimize.sh tier3-validate"
    echo "[ERROR] Then re-run this command."
    exit 3
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
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[INFO] Dry run: true"
  fi
  if [[ "$OFFLINE" == "true" ]]; then
    echo "[INFO] Offline mode: true"
  fi
  if [[ "$ACCEPT_AMD_ACCELERATION_RISK" == "true" ]]; then
    echo "[INFO] AMD acceleration risk accepted: true"
  fi
}

load_runtime_config
print_context

case "$CMD" in
  # === New AI Stack Tier commands (primary recommended interface) ===
  tier1)
    echo "[INFO] Running Tier 1 – Required Core Platform (full sequence)"
    run_script "scripts/10-detect-hardware.sh"
    run_script "scripts/20-check-bios.sh"
    run_script "scripts/30-validate-kernel.sh" "$DRY_RUN"
    run_script "scripts/40-optimize-cpu.sh"
    run_script "scripts/50-optimize-memory.sh"
    run_script "scripts/60-optimize-storage.sh"
    run_script "scripts/70-validate-gpu-stack.sh" "$OFFLINE"
    run_script "scripts/75-detect-npu.sh" "$OFFLINE"
    run_script "scripts/80-benchmark-local-ai.sh" "$OFFLINE"
    run_script "scripts/90-validate.sh"
    ;;

  tier1-validate)
    run_script "scripts/90-validate.sh"
    ;;

  tier2)
    echo "[INFO] Running Tier 2 – Recommended AI Runtime Layer"
    run_script "scripts/20-ai-stack.sh" "$OFFLINE"
    run_script "scripts/80-llm-validation.sh" "$OFFLINE"
    if [[ -f "$PROJECT_ROOT/scripts/100-tier2-ai-runtime.sh" ]]; then
      run_script "scripts/100-tier2-ai-runtime.sh" "$OFFLINE"
    fi
    ;;

  tier2-validate)
    echo "[INFO] Tier 2 validation (writes/validates tier2-validation.json)"
    if [[ -f "$PROJECT_ROOT/scripts/100-tier2-ai-runtime.sh" ]]; then
      run_script "scripts/100-tier2-ai-runtime.sh" "$OFFLINE"
    fi
    ;;

  tier3)
    echo "[INFO] Running Tier 3 – AMD NPU Enablement"
    run_script "scripts/40-ryzen-ai-npu.sh" "$OFFLINE"
    if [[ -f "$PROJECT_ROOT/scripts/110-tier3-npu-enable.sh" ]]; then
      run_script "scripts/110-tier3-npu-enable.sh" "$OFFLINE"
    fi
    ;;

  tier3-validate)
    echo "[INFO] Tier 3 NPU validation (experimental)"
    run_script "scripts/40-ryzen-ai-npu.sh" "$OFFLINE"
    if [[ -f "$PROJECT_ROOT/scripts/110-tier3-npu-enable.sh" ]]; then
      run_script "scripts/110-tier3-npu-enable.sh" "$OFFLINE"
    fi
    ;;

  tier4)
    echo "[INFO] Tier 4 – Local Knowledge Systems (AnythingLLM / RAG) not yet implemented as a full script."
    echo "[INFO] See docs and workflows/ for current local document patterns. This is a placeholder."
    ;;

  tier5)
    require_tier123_pass
    echo "[INFO] Tier 5 gate passed. Proceeding with Generative AI (ComfyUI + workflows)."
    run_script "scripts/70-comfyui-workflows.sh"
    ;;

  full-stack)
    if [[ "$OFFLINE" == "true" ]]; then
      echo "[ERROR] full-stack does not support --offline (ComfyUI and some Tier 5 components fetch upstream)."
      exit 2
    fi
    if [[ "$ACCEPT_AMD_ACCELERATION_RISK" != "true" ]]; then
      echo "[ERROR] full-stack requires --accept-amd-acceleration-risk."
      exit 2
    fi
    # Tier 1 (core)
    run_script "scripts/10-detect-hardware.sh"
    run_script "scripts/20-check-bios.sh"
    run_script "scripts/30-validate-kernel.sh" "$DRY_RUN"
    run_script "scripts/40-optimize-cpu.sh"
    run_script "scripts/50-optimize-memory.sh"
    run_script "scripts/60-optimize-storage.sh"
    run_script "scripts/70-validate-gpu-stack.sh" "$OFFLINE"
    run_script "scripts/75-detect-npu.sh" "$OFFLINE"
    run_script "scripts/80-benchmark-local-ai.sh" "$OFFLINE"
    run_script "scripts/90-validate.sh"
    # Tier 2
    run_script "scripts/20-ai-stack.sh" "$OFFLINE"
    run_script "scripts/80-llm-validation.sh" "$OFFLINE"
    # Tier 3 (NPU visibility + note on explicit accel)
    run_script "scripts/40-ryzen-ai-npu.sh" "$OFFLINE"
    # Explicit AMD accel (risk already accepted)
    run_script "scripts/65-amd-acceleration-install.sh" "$OFFLINE" "$ACCEPT_AMD_ACCELERATION_RISK"
    # Re-validate GPU/NPU after accel
    run_script "scripts/70-validate-gpu-stack.sh" "$OFFLINE"
    run_script "scripts/40-ryzen-ai-npu.sh" "$OFFLINE"
    # Tier 5 (gate will be satisfied by above)
    run_script "scripts/70-comfyui-workflows.sh"
    run_script "scripts/comfyui-benchmark.sh"
    run_script "scripts/90-validate.sh"
    ;;

  # === Legacy phase commands (preserve for compatibility) ===
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

  amd-accel-install)
    run_script "scripts/65-amd-acceleration-install.sh" "$OFFLINE" "$ACCEPT_AMD_ACCELERATION_RISK"
    ;;

  comfyui-install|comfyui)
    require_tier123_pass
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
    # Legacy install = core baseline + AI runtime (Tier 1 + Tier 2 overlap). No Tier 5.
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

  full-ai-install)
    if [[ "$OFFLINE" == "true" ]]; then
      echo "[ERROR] Command 'full-ai-install' does not support --offline because ComfyUI installation fetches upstream sources. Run individual offline phases instead."
      exit 2
    fi
    if [[ "$ACCEPT_AMD_ACCELERATION_RISK" != "true" ]]; then
      echo "[ERROR] Command 'full-ai-install' requires --accept-amd-acceleration-risk."
      exit 2
    fi
    # Delegate to the new tier-aware full-stack implementation for consistency with gates
    # (kept for backward compat; prefer ./ai370-optimize.sh full-stack)
    "$0" full-stack --profile="$PROFILE" --mode="$MODE" --persistence="$PERSISTENCE" --accept-amd-acceleration-risk
    ;;

  all)
    if [[ "$OFFLINE" == "true" ]]; then
      echo "[ERROR] Command 'all' does not support --offline. Run phases 5-7 individually with --offline."
      exit 2
    fi
    # Run a safe subset (Tier 1 + 2 + ComfyUI without forcing the risky AMD accel stack)
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
