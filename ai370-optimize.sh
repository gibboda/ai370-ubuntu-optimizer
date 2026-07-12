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
Usage (Roadmap stages - recommended):
  ./ai370-optimize.sh stage1 [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh stage1-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh stage2 [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh stage2-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh stage2-runtime [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh stage2-runtime-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh stage2-npu [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh stage2-npu-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh stage2-rag [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh stage3-image [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh full-stack [--profile=ai370] [--mode=safe] [--persistence=runtime] --accept-amd-acceleration-risk

Legacy tier aliases (still supported):
  ./ai370-optimize.sh tier1 | tier1-validate
  ./ai370-optimize.sh tier2 | tier2-validate
  ./ai370-optimize.sh tier3 | tier3-validate
  ./ai370-optimize.sh tier4
  ./ai370-optimize.sh tier5

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

Stage 1 scripts (S1 deliverables):
  scripts/10-detect-hardware.sh
  scripts/20-check-bios.sh
  scripts/25-check-firmware.sh
  scripts/30-validate-kernel.sh
  scripts/40-optimize-cpu.sh
  scripts/50-optimize-memory.sh
  scripts/60-optimize-storage.sh
  scripts/70-validate-gpu-stack.sh
  scripts/75-detect-npu.sh
  scripts/80-benchmark-local-ai.sh
  scripts/90-validate.sh

Stage 2 scripts (S2 deliverables across runtime + NPU):
  scripts/100-install-pytorch-rocm.sh
  scripts/110-install-llama-cpp.sh
  scripts/120-install-ollama.sh
  scripts/130-install-open-webui.sh
  scripts/140-benchmark-llm.sh
  scripts/150-validate-offline-model-storage.sh
  scripts/200-install-onnxruntime.sh
  scripts/205-install-xrt-ryzen-ai.sh
  scripts/210-check-ryzen-ai-software.sh
  scripts/220-check-vitis-ai-ep.sh
  scripts/230-benchmark-npu.sh
  scripts/240-write-tier3-validation.sh
  scripts/245-compare-cpu-gpu-npu.sh

Backward-compatible aliases:
  inventory, audit        -> hardware (Stage 1 / legacy Tier 1)
  baseline-plan, plan     -> legacy baseline planning
  baseline-apply          -> legacy baseline apply
  baseline-validate       -> legacy baseline validation
  ai-runtime              -> ai-bench
  gpu                     -> GPU half of accel-validate
  npu                     -> NPU half of accel-validate
  guide                   -> guided acceleration readiness plan
  execute                 -> generated acceleration checklists
  comfyui                 -> comfyui-install (Stage 3 image / legacy Tier 5, gated)
  validate                -> final-validate
  install                 -> kernel-amd + ai-bench
  full-ai-install         -> multi-tier (requires --accept-amd-acceleration-risk)

Defaults:
  profile     ai370
  mode        safe
  persistence runtime

Notes:
  Use --profile=generic-ryzen-ai only when intentionally broadening beyond strict AI370 validation.
  --offline affects Stage 1 (parts), Stage 2 runtime/NPU, and amd-accel-install.
  --accept-amd-acceleration-risk is required for amd-accel-install, full-ai-install, full-stack,
    and for stage2-npu / stage2 to install staged XRT/Ryzen AI packages via scripts/205-*.sh.
  Stage 3 image generation (stage3-image / tier5 / comfyui) is blocked until Stage 1 + Stage 2 runtime + Stage 2 NPU validation passes.
  system persistence is reserved for future persistent tuning and is blocked by current scripts.
  Stage 2 validators exit non-zero on status=FAIL (PASS/WARN remain exit 0).
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

PROFILE_FILE="$PROJECT_ROOT/configs/profiles/${PROFILE}.env"
MODE_FILE="$PROJECT_ROOT/configs/tuning/${MODE}.env"
PERSISTENCE_FILE="$PROJECT_ROOT/configs/persistence/${PERSISTENCE}.env"

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

# Stage gate: Stage 3 image generation (and full generative flows) must not proceed until
# Stage 1 + Stage 2 runtime + Stage 2 NPU have produced acceptable validation artifacts.
# Prefers dedicated tierN-validation.json (M2/M3). Falls back to legacy for transition.
#
# Gate policy (experimental default; see docs/ROADMAP.md "Stage gate policy"):
#   Stage 1 (tier1-validation): PASS only
#   Stage 2 runtime (tier2-validation): PASS or WARN
#   Offline model storage: PASS or WARN (required file; optional models may WARN)
#   Stage 2 NPU (tier3-validation): PASS, WARN, or EXPERIMENTAL-PASS
# WARN / EXPERIMENTAL-PASS intentionally allow Stage 3 while hardware/models are still
# incomplete; FAIL or missing required artifacts block the gate.
require_tier123_pass() {
  local LATEST_DIR="$PROJECT_ROOT/reports/latest"
  local tier1_status="$LATEST_DIR/tier1-validation.json"
  local tier2_status="$LATEST_DIR/tier2-validation.json"
  local offline_model_status="$LATEST_DIR/offline-model-storage.json"
  local tier3_status="$LATEST_DIR/tier3-validation.json"
  local legacy_final="$LATEST_DIR/final-validation.txt"
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

  # Stage 2 runtime: require both runtime validation and S2-M5 offline model storage validation.
  # WARN is accepted so optional staged models / partial stacks do not block Stage 3.
  if [[ -f "$tier2_status" ]]; then
    if ! python3 - "$tier2_status" <<'PY' >/dev/null 2>&1
import json, sys
data=json.load(open(sys.argv[1]))
status = data.get("status") or "UNKNOWN"
if status.upper() not in ("PASS", "WARN"):
    sys.exit(1)
PY
then
      pass="false"
    fi
  elif [[ ! -f "$llm_status" && ! -f "$ai_status" ]]; then
    pass="false"
  fi

  if [[ -f "$offline_model_status" ]]; then
    if ! python3 - "$offline_model_status" <<'PY' >/dev/null 2>&1
import json, sys
data=json.load(open(sys.argv[1]))
status = data.get("status") or "UNKNOWN"
if status.upper() not in ("PASS", "WARN"):
    sys.exit(1)
PY
then
      pass="false"
    fi
  else
    pass="false"
  fi

  # Stage 2 NPU: prefer dedicated validation, else legacy npu evidence.
  # EXPERIMENTAL-PASS means hardware/XRT visible without a full AMD EP benchmark PASS.
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
    echo "[ERROR] Stage 1 + Stage 2 runtime + Stage 2 NPU validation has not passed."
    echo "[ERROR] Preferred: ./ai370-optimize.sh stage1 && ./ai370-optimize.sh stage2 && ./ai370-optimize.sh stage2-validate"
    echo "[ERROR] Or: stage1 + stage2-runtime + stage2-runtime-validate + stage2-npu-validate"
    echo "[ERROR] Gate policy: Stage1=PASS; Stage2 runtime/models=PASS|WARN; Stage2 NPU=PASS|WARN|EXPERIMENTAL-PASS."
    echo "[ERROR] See docs/ROADMAP.md (Stage gate policy). Then re-run this command."
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
  # === Roadmap stage commands (primary recommended interface) ===
  stage1|tier1)
    echo "[INFO] Running Stage 1 – Hardware Detection & System Optimization (formerly Tier 1)"
    run_script "scripts/10-detect-hardware.sh"
    run_script "scripts/20-check-bios.sh"
    run_script "scripts/25-check-firmware.sh"
    run_script "scripts/30-validate-kernel.sh" "$DRY_RUN"
    run_script "scripts/40-optimize-cpu.sh"
    run_script "scripts/50-optimize-memory.sh"
    run_script "scripts/60-optimize-storage.sh"
    run_script "scripts/70-validate-gpu-stack.sh" "$OFFLINE"
    run_script "scripts/75-detect-npu.sh" "$OFFLINE"
    run_script "scripts/80-benchmark-local-ai.sh" "$OFFLINE"
    run_script "scripts/90-validate.sh"
    ;;

  stage1-validate|tier1-validate)
    run_script "scripts/90-validate.sh"
    ;;


  stage2)
    echo "[INFO] Running Stage 2 – Local AI Runtime & AI Optimization Software"
    echo "[INFO] Stage 2 includes runtime, model storage, NPU checks, and writes tier3-validation.json."
    run_script "scripts/100-install-pytorch-rocm.sh" "$OFFLINE"
    run_script "scripts/110-install-llama-cpp.sh" "$OFFLINE"
    run_script "scripts/120-install-ollama.sh" "$OFFLINE"
    run_script "scripts/130-install-open-webui.sh" "$OFFLINE"
    run_script "scripts/140-benchmark-llm.sh" "$OFFLINE"
    run_script "scripts/150-validate-offline-model-storage.sh" "$OFFLINE"
    run_script "scripts/205-install-xrt-ryzen-ai.sh" "$OFFLINE" "$ACCEPT_AMD_ACCELERATION_RISK"
    run_script "scripts/200-install-onnxruntime.sh" "$OFFLINE"
    run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
    run_script "scripts/220-check-vitis-ai-ep.sh" "$OFFLINE"
    run_script "scripts/230-benchmark-npu.sh" "$OFFLINE"
    run_script "scripts/245-compare-cpu-gpu-npu.sh" "$OFFLINE"
    # Always finalize the Stage 2 NPU gate artifact so stage2 alone refreshes require_tier123_pass inputs.
    run_script "scripts/240-write-tier3-validation.sh" "$OFFLINE"
    echo "[INFO] Stage 2 RAG is optional and not part of the Stage 3 gate; run stage2-rag when needed."
    ;;

  stage2-validate)
    echo "[INFO] Validating Stage 2 – runtime/model storage plus NPU checks"
    run_script "scripts/140-benchmark-llm.sh" "$OFFLINE"
    run_script "scripts/150-validate-offline-model-storage.sh" "$OFFLINE"
    run_script "scripts/205-install-xrt-ryzen-ai.sh" "$OFFLINE" "$ACCEPT_AMD_ACCELERATION_RISK"
    run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
    run_script "scripts/220-check-vitis-ai-ep.sh" "$OFFLINE"
    run_script "scripts/230-benchmark-npu.sh" "$OFFLINE"
    run_script "scripts/245-compare-cpu-gpu-npu.sh" "$OFFLINE"
    run_script "scripts/240-write-tier3-validation.sh" "$OFFLINE"
    ;;

  stage2-runtime|tier2)
    echo "[INFO] Running Stage 2 Runtime – Local AI Runtime & Model Storage (formerly Tier 2)"
    run_script "scripts/100-install-pytorch-rocm.sh" "$OFFLINE"
    run_script "scripts/110-install-llama-cpp.sh" "$OFFLINE"
    run_script "scripts/120-install-ollama.sh" "$OFFLINE"
    run_script "scripts/130-install-open-webui.sh" "$OFFLINE"
    run_script "scripts/140-benchmark-llm.sh" "$OFFLINE"
    run_script "scripts/150-validate-offline-model-storage.sh" "$OFFLINE"
    ;;

  stage2-runtime-validate|tier2-validate)
    echo "[INFO] Stage 2 runtime validation (writes/validates tier2-validation.json)"
    run_script "scripts/140-benchmark-llm.sh" "$OFFLINE"
    run_script "scripts/150-validate-offline-model-storage.sh" "$OFFLINE"
    ;;

  stage2-npu|tier3)
    echo "[INFO] Running Stage 2 NPU – AMD AI Stack Enablement (formerly Tier 3)"
    run_script "scripts/205-install-xrt-ryzen-ai.sh" "$OFFLINE" "$ACCEPT_AMD_ACCELERATION_RISK"
    run_script "scripts/200-install-onnxruntime.sh" "$OFFLINE"
    run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
    run_script "scripts/220-check-vitis-ai-ep.sh" "$OFFLINE"
    run_script "scripts/230-benchmark-npu.sh" "$OFFLINE"
    run_script "scripts/245-compare-cpu-gpu-npu.sh" "$OFFLINE"
    run_script "scripts/240-write-tier3-validation.sh" "$OFFLINE"
    ;;

  stage2-npu-validate|tier3-validate)
    echo "[INFO] Stage 2 NPU validation (experimental; writes/validates tier3-validation.json)"
    run_script "scripts/205-install-xrt-ryzen-ai.sh" "$OFFLINE" "$ACCEPT_AMD_ACCELERATION_RISK"
    run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
    run_script "scripts/220-check-vitis-ai-ep.sh" "$OFFLINE"
    run_script "scripts/230-benchmark-npu.sh" "$OFFLINE"
    run_script "scripts/245-compare-cpu-gpu-npu.sh" "$OFFLINE"
    run_script "scripts/240-write-tier3-validation.sh" "$OFFLINE"
    ;;

  stage2-rag|tier4)
    echo "[INFO] Running Stage 2 RAG (S2-M3) – AnythingLLM, embeddings, offline retrieval"
    echo "[INFO] Offline staging: .ai370-ai/offline-artifacts/{anythingllm,embedding}/ and wheelhouse"
    run_script "scripts/300-install-anythingllm.sh" "$OFFLINE"
    run_script "scripts/310-install-embedding-models.sh" "$OFFLINE"
    run_script "scripts/320-validate-rag.sh" "$OFFLINE"
    ;;

  stage3-image|tier5)
    require_tier123_pass
    echo "[INFO] Stage 3 gate passed. Proceeding with Offline Image Generation (ComfyUI + workflows)."
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
    # Stage 1 (core)
    run_script "scripts/10-detect-hardware.sh"
    run_script "scripts/20-check-bios.sh"
    run_script "scripts/25-check-firmware.sh"
    run_script "scripts/30-validate-kernel.sh" "$DRY_RUN"
    run_script "scripts/40-optimize-cpu.sh"
    run_script "scripts/50-optimize-memory.sh"
    run_script "scripts/60-optimize-storage.sh"
    run_script "scripts/70-validate-gpu-stack.sh" "$OFFLINE"
    run_script "scripts/75-detect-npu.sh" "$OFFLINE"
    run_script "scripts/80-benchmark-local-ai.sh" "$OFFLINE"
    run_script "scripts/90-validate.sh"
    # Stage 2 runtime
    run_script "scripts/100-install-pytorch-rocm.sh" "$OFFLINE"
    run_script "scripts/110-install-llama-cpp.sh" "$OFFLINE"
    run_script "scripts/120-install-ollama.sh" "$OFFLINE"
    run_script "scripts/130-install-open-webui.sh" "$OFFLINE"
    run_script "scripts/140-benchmark-llm.sh" "$OFFLINE"
    run_script "scripts/150-validate-offline-model-storage.sh" "$OFFLINE"
    # Stage 2 NPU (XRT/Ryzen staging install + visibility)
    run_script "scripts/205-install-xrt-ryzen-ai.sh" "$OFFLINE" "$ACCEPT_AMD_ACCELERATION_RISK"
    run_script "scripts/200-install-onnxruntime.sh" "$OFFLINE"
    run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
    run_script "scripts/220-check-vitis-ai-ep.sh" "$OFFLINE"
    run_script "scripts/230-benchmark-npu.sh" "$OFFLINE"
    run_script "scripts/245-compare-cpu-gpu-npu.sh" "$OFFLINE"
    run_script "scripts/240-write-tier3-validation.sh" "$OFFLINE"
    # Explicit full AMD accel (ROCm repos + XRT; risk already accepted)
    if [[ -f "$PROJECT_ROOT/scripts/65-amd-acceleration-install.sh" ]]; then
      run_script "scripts/65-amd-acceleration-install.sh" "$OFFLINE" "$ACCEPT_AMD_ACCELERATION_RISK"
    fi
    # Re-validate GPU/NPU after accel
    run_script "scripts/70-validate-gpu-stack.sh" "$OFFLINE"
    run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
    run_script "scripts/245-compare-cpu-gpu-npu.sh" "$OFFLINE"
    # Stage 3 image generation (gate will be satisfied by above)
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
    run_script "scripts/80-benchmark-local-ai.sh" "$OFFLINE"
    ;;

  llm-validate)
    run_script "scripts/140-benchmark-llm.sh" "$OFFLINE"
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
    # Legacy install = core baseline + AI runtime (Stage 1 + Stage 2 runtime overlap). No Stage 3 image generation.
    run_script "scripts/02-generate-report.sh"
    run_script "scripts/10-amd-baseline.sh" "$DRY_RUN"
    run_script "scripts/03-baseline-validate.sh"
    run_script "scripts/20-ai-stack.sh" "$OFFLINE"
    ;;

  gpu)
    run_script "scripts/30-rocm-igpu.sh" "$OFFLINE"
    ;;

  npu)
    run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
    run_script "scripts/220-check-vitis-ai-ep.sh" "$OFFLINE"
    run_script "scripts/230-benchmark-npu.sh" "$OFFLINE"
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
    # Delegate to the roadmap-stage full-stack implementation for consistency with gates
    # (kept for backward compat; prefer ./ai370-optimize.sh full-stack)
    "$0" full-stack --profile="$PROFILE" --mode="$MODE" --persistence="$PERSISTENCE" --accept-amd-acceleration-risk
    ;;

  all)
    if [[ "$OFFLINE" == "true" ]]; then
      echo "[ERROR] Command 'all' does not support --offline. Run phases 5-7 individually with --offline."
      exit 2
    fi
    # Run a safe subset (Stage 1 + Stage 2 runtime + ComfyUI without forcing the risky AMD accel stack)
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
