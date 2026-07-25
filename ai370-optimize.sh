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
WITH_LEMONADE="false"
WITH_DIGEST="false"
WITH_RAG="false"
BENCH="false"
# Package E Stage 1 options
WITH_AI_SMOKE="false"
APPLY_TUNING="false"
STRICT="false"
STAGE1_VALIDATE_SCOPE="full"

usage() {
  cat <<'USAGE'
Usage (Roadmap stages - recommended):
  ./ai370-optimize.sh stage1 [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
       [--with-ai-smoke] [--apply-tuning] [--strict]
  ./ai370-optimize.sh stage1-inventory [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
       [--strict]
  ./ai370-optimize.sh stage1-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
       [--inventory] [--strict]
  ./ai370-optimize.sh stage2 [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
       [--with-lemonade] [--with-digest] [--with-rag]
  ./ai370-optimize.sh stage2-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
       [--bench] [--with-lemonade]
  ./ai370-optimize.sh stage2-runtime [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
       [--with-lemonade]
  ./ai370-optimize.sh stage2-runtime-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
       [--with-lemonade]
  ./ai370-optimize.sh stage2-npu [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
       [--with-lemonade]
  ./ai370-optimize.sh stage2-npu-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
       [--bench] [--with-lemonade]
  ./ai370-optimize.sh stage2-rag [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh stage2-lemonade [--profile=ai370] [--mode=safe] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh stage2-digest [--profile=ai370] [--mode=safe] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh stage2-models [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh stage3-image [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh full-stack [--profile=ai370] [--mode=safe] [--persistence=runtime]
       --accept-amd-acceleration-risk [--with-lemonade] [--with-digest] [--with-rag]

Legacy tier aliases (still supported):
  ./ai370-optimize.sh tier1 | tier1-validate
  ./ai370-optimize.sh tier2 | tier2-validate
  ./ai370-optimize.sh tier3 | tier3-validate
  ./ai370-optimize.sh tier4
  ./ai370-optimize.sh tier5

Legacy / detailed phase commands (compat; prefer stage1/stage2):
  ./ai370-optimize.sh hardware | firmware | kernel-amd | tune | accel-validate
  ./ai370-optimize.sh ai-bench | llm-validate | amd-accel-install
  ./ai370-optimize.sh comfyui-install | comfyui-bench | final-validate | all
  (Broken root script paths retarget scripts/legacy/ or modern Stage 1/2 scripts.)

Stage 1 (Package C + E):
  Canonical: 10 (incl. NPU), 20 (BIOS+firmware; 25 wrapper), 30,
    40-platform-tuning (40/50/60 wrappers; plan-only unless --apply-tuning),
    70, 90 (scope: inventory|full|smoke)
  Default stage1 skips script 80; pass --with-ai-smoke (or AI370_STAGE1_WITH_AI_SMOKE=true)
  --strict (or AI370_STAGE1_STRICT=true): FAIL if gfx1150 or NPU missing
  --apply-tuning (or AI370_APPLY_TUNING=true): compatibility-only migration path; target Stage 1 contract is read-only
  stage1-inventory = detect + firmware + kernel + GPU + inventory-scope validate
  stage1-validate --inventory re-checks inventory scope only

Stage 2 core (default stage2 / Stage 3 gate path):
  Runtime: 100, 110, 120, 130, 140, 145, 150
  NPU:     205, 200, 210, 220, 230, 245, 240
  (145 writes tier2-validation.json; 245 reuses 230 NPU results by default)
Optional packs (not Stage 3 gate inputs):
  --with-lemonade / stage2-lemonade  → 170, 160, 165 (S2-M6)
  --with-digest / stage2-digest      → 250, 255 (S2-M7)
  --with-rag / stage2-rag            → 300, 310, 320 (S2-M3)
  stage2-models                      → 155 layout + 150 validate (S2-M5 polish; no downloads)
  Env: LEMONADE_START=true, ANYTHINGLLM_START=true for full serving/UI smokes

Defaults:
  profile     ai370
  mode        safe
  persistence runtime

Notes:
  Stage 1 PASS may still include acceptance WARNs (missing optional hardware); that
    is intentional and experimental-friendly. Use --strict for hard AI370 checks.
  stage2 is core-only by default (runtime + NPU + gate artifacts). Optional AMD
    product packs require --with-lemonade, --with-digest, and/or --with-rag.
  stage2-validate is a cheap gate refresh by default; pass --bench for LLM smoke
    and NPU MatMul comparison re-runs (140 / 230 / 245).
  --offline affects Stage 1 (parts), Stage 2 runtime/NPU, and amd-accel-install.
  --accept-amd-acceleration-risk is required for amd-accel-install, full-ai-install,
    full-stack, and for stage2-npu / stage2 to install staged XRT/Ryzen AI packages.
  Stage 3 image generation is blocked until Stage 1 + Stage 2 runtime + Stage 2 NPU pass.
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
    --with-lemonade) WITH_LEMONADE="true" ;;
    --with-digest) WITH_DIGEST="true" ;;
    --with-rag) WITH_RAG="true" ;;
    --bench|--full) BENCH="true" ;;
    --with-ai-smoke) WITH_AI_SMOKE="true" ;;
    --apply-tuning) APPLY_TUNING="true" ;;
    --strict) STRICT="true" ;;
    --inventory) STAGE1_VALIDATE_SCOPE="inventory" ;;
  esac
done

# Env overrides (Package E) — CLI flags win when set true above; env can enable too.
if [[ "${AI370_STAGE1_WITH_AI_SMOKE:-false}" == "true" ]]; then
  WITH_AI_SMOKE="true"
fi
if [[ "${AI370_APPLY_TUNING:-false}" == "true" ]]; then
  APPLY_TUNING="true"
fi
if [[ "${AI370_STAGE1_STRICT:-false}" == "true" ]]; then
  STRICT="true"
fi

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

# Prefer modern path; fall back to scripts/legacy/ for retired phase scripts.
run_script_or_legacy() {
  local modern="$1"
  local legacy="$2"
  shift 2 || true
  if [[ -f "$PROJECT_ROOT/$modern" ]]; then
    run_script "$modern" "$@"
  elif [[ -f "$PROJECT_ROOT/$legacy" ]]; then
    echo "[WARN] Using legacy script $legacy (prefer modern stage commands)."
    run_script "$legacy" "$@"
  else
    echo "[ERROR] Missing script: $modern (and legacy fallback $legacy)"
    exit 2
  fi
}

export_stage1_env() {
  # Propagate Package E options into Stage 1 scripts via environment.
  if [[ "$STRICT" == "true" ]]; then
    export AI370_STAGE1_STRICT=true
  else
    export AI370_STAGE1_STRICT=false
  fi
  if [[ "$APPLY_TUNING" == "true" ]]; then
    export AI370_APPLY_TUNING=true
  else
    export AI370_APPLY_TUNING=false
  fi
  if [[ "$WITH_AI_SMOKE" == "true" ]]; then
    export AI370_STAGE1_WITH_AI_SMOKE=true
  else
    export AI370_STAGE1_WITH_AI_SMOKE=false
  fi
  # Honor orchestrator --dry-run for optional apply-tuning (40-platform-tuning).
  export DRY_RUN="${DRY_RUN:-false}"
}

run_stage1_inventory() {
  echo "[INFO] Stage 1 inventory – detect + firmware + kernel + GPU + inventory-scope validate (no tuning/smoke)"
  export_stage1_env
  run_script "scripts/10-detect-hardware.sh"
  # 20 writes both BIOS baseline and firmware validation (25 is a wrapper)
  run_script "scripts/20-check-bios.sh"
  run_script "scripts/30-validate-kernel.sh" "$DRY_RUN"
  run_script "scripts/70-validate-gpu-stack.sh" "$OFFLINE"
  # inventory scope: no platform-tuning / script 80 requirement
  run_script "scripts/90-validate.sh" "inventory"
  write_report_index
}

run_stage1() {
  echo "[INFO] Stage 1 – Hardware Detection & System Optimization (platform plan; optional AI smoke)"
  export_stage1_env
  run_script "scripts/10-detect-hardware.sh"
  # Combined BIOS + firmware (Package C); keep 25 as optional no-op path for compat
  run_script "scripts/20-check-bios.sh"
  run_script "scripts/30-validate-kernel.sh" "$DRY_RUN"
  # Plan-only platform recommendations unless --apply-tuning / AI370_APPLY_TUNING=true
  run_script "scripts/40-platform-tuning.sh"
  run_script "scripts/70-validate-gpu-stack.sh" "$OFFLINE"
  # NPU detect is included in 10; 75 remains a thin wrapper if called directly
  # Package E: script 80 demoted — opt-in via --with-ai-smoke (Stage 2–adjacent readiness)
  local validate_scope="full"
  if [[ "$WITH_AI_SMOKE" == "true" ]]; then
    echo "[INFO] Running optional Stage 1 local-AI smoke (script 80)"
    run_script "scripts/80-benchmark-local-ai.sh" "$OFFLINE"
    validate_scope="smoke"
  else
    echo "[INFO] Skipping script 80 local-AI smoke (pass --with-ai-smoke to include)"
  fi
  run_script "scripts/90-validate.sh" "$validate_scope"
  write_report_index
}

write_report_index() {
  # shellcheck source=scripts/lib/common.sh
  PROJECT_ROOT="$PROJECT_ROOT" source "$PROJECT_ROOT/scripts/lib/common.sh"
  ai370_write_report_index "$PROJECT_ROOT/reports/latest"
}

run_stage2_runtime_core() {
  echo "[INFO] Stage 2 runtime core (S2-M1 / S2-M4 / S2-M5)"
  run_script "scripts/100-install-pytorch-rocm.sh" "$OFFLINE"
  run_script "scripts/110-install-llama-cpp.sh" "$OFFLINE"
  run_script "scripts/120-install-ollama.sh" "$OFFLINE"
  run_script "scripts/130-install-open-webui.sh" "$OFFLINE"
  run_script "scripts/140-benchmark-llm.sh" "$OFFLINE"
  # 140 invokes 145; call again so runtime-only paths still refresh the gate artifact
  run_script "scripts/145-write-tier2-validation.sh" "$OFFLINE"
  # Layout stubs (no downloads) then validate offline model storage
  run_script "scripts/155-stage-model-layout.sh" "$OFFLINE"
  run_script "scripts/150-validate-offline-model-storage.sh" "$OFFLINE"
}

run_stage2_models() {
  echo "[INFO] Stage 2 model layout + offline validation (S2-M5 polish; no downloads)"
  run_script "scripts/155-stage-model-layout.sh" "$OFFLINE"
  run_script "scripts/150-validate-offline-model-storage.sh" "$OFFLINE"
}

run_stage2_npu_core() {
  local include_compare="${1:-true}"
  echo "[INFO] Stage 2 NPU core (S2-M2 / S2-M4)"
  run_script "scripts/205-install-xrt-ryzen-ai.sh" "$OFFLINE" "$ACCEPT_AMD_ACCELERATION_RISK"
  run_script "scripts/200-install-onnxruntime.sh" "$OFFLINE"
  run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
  run_script "scripts/220-check-vitis-ai-ep.sh" "$OFFLINE"
  run_script "scripts/230-benchmark-npu.sh" "$OFFLINE"
  if [[ "$include_compare" == "true" ]]; then
    # Reuses npu-benchmark.json from 230 by default (AI370_REUSE_NPU_BENCH=true)
    run_script "scripts/245-compare-cpu-gpu-npu.sh" "$OFFLINE"
  fi
  run_script "scripts/240-write-tier3-validation.sh" "$OFFLINE"
  write_report_index
}

run_optional_lemonade() {
  echo "[INFO] Optional S2-M6 TurnkeyML + Lemonade"
  run_script "scripts/170-install-turnkeyml.sh" "$OFFLINE"
  run_script "scripts/160-install-lemonade.sh" "$OFFLINE"
  run_script "scripts/165-validate-lemonade.sh" "$OFFLINE"
}

run_optional_digest() {
  echo "[INFO] Optional S2-M7 Digest AI model analysis"
  run_script "scripts/250-install-digest-ai.sh" "$OFFLINE"
  run_script "scripts/255-analyze-model-digest.sh" "$OFFLINE"
}

run_optional_rag() {
  echo "[INFO] Optional S2-M3 Offline RAG"
  run_script "scripts/300-install-anythingllm.sh" "$OFFLINE"
  run_script "scripts/310-install-embedding-models.sh" "$OFFLINE"
  run_script "scripts/320-validate-rag.sh" "$OFFLINE"
}

run_optional_packs() {
  if [[ "$WITH_LEMONADE" == "true" ]]; then
    run_optional_lemonade
  fi
  if [[ "$WITH_DIGEST" == "true" ]]; then
    run_optional_digest
  fi
  if [[ "$WITH_RAG" == "true" ]]; then
    run_optional_rag
  fi
}

json_status() {
  # Prints status from a JSON file, or MISSING / UNREADABLE.
  local path="$1"
  local keys="${2:-status}"
  if [[ ! -f "$path" ]]; then
    echo "MISSING"
    return
  fi
  python3 - "$path" "$keys" <<'PY' 2>/dev/null || echo "UNREADABLE"
import json, sys
path, keys = sys.argv[1], sys.argv[2].split(",")
try:
    data = json.load(open(path))
except Exception:
    print("UNREADABLE")
    raise SystemExit
status = None
for key in keys:
    if key in data and data[key] is not None:
        status = data[key]
        break
print(str(status if status is not None else "UNKNOWN").upper())
PY
}

# Stage gate: Stage 3 image generation must not proceed until Stage 1 + Stage 2
# runtime + Stage 2 NPU have produced acceptable validation artifacts.
#
# Gate policy (experimental default; see docs/ROADMAP.md "Stage gate policy"):
#   Stage 1 (tier1-validation): PASS only
#   Stage 2 runtime (tier2-validation): PASS or WARN
#   Offline model storage: PASS or WARN (required file; optional models may WARN)
#   Stage 2 NPU (tier3-validation): PASS, WARN, or EXPERIMENTAL-PASS
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
  local t1_result t2_result models_result t3_result
  t1_result="unknown"
  t2_result="unknown"
  models_result="unknown"
  t3_result="unknown"

  if [[ -f "$tier1_status" ]]; then
    t1_result="$(json_status "$tier1_status" "status,tier1_status")"
    if [[ "$t1_result" != "PASS" ]]; then
      pass="false"
    fi
  elif [[ -f "$legacy_final" ]]; then
    if grep -q "Final Status: PASS" "$legacy_final" 2>/dev/null; then
      t1_result="PASS (legacy final-validation.txt)"
    else
      t1_result="FAIL (legacy final-validation.txt)"
      pass="false"
    fi
  else
    t1_result="MISSING (tier1-validation.json)"
    pass="false"
  fi

  if [[ -f "$tier2_status" ]]; then
    t2_result="$(json_status "$tier2_status" "status")"
    if [[ "$t2_result" != "PASS" && "$t2_result" != "WARN" ]]; then
      pass="false"
    fi
  elif [[ -f "$llm_status" || -f "$ai_status" ]]; then
    t2_result="LEGACY (llm/ai-stack present; prefer tier2-validation.json)"
  else
    t2_result="MISSING (tier2-validation.json)"
    pass="false"
  fi

  if [[ -f "$offline_model_status" ]]; then
    models_result="$(json_status "$offline_model_status" "status")"
    if [[ "$models_result" != "PASS" && "$models_result" != "WARN" ]]; then
      pass="false"
    fi
  else
    models_result="MISSING (offline-model-storage.json)"
    pass="false"
  fi

  if [[ -f "$tier3_status" ]]; then
    t3_result="$(json_status "$tier3_status" "status")"
    if [[ "$t3_result" != "PASS" && "$t3_result" != "WARN" && "$t3_result" != "EXPERIMENTAL-PASS" ]]; then
      pass="false"
    fi
  elif [[ -f "$npu_status" ]]; then
    t3_result="LEGACY (npu-acceleration-status.txt present; prefer tier3-validation.json)"
  else
    t3_result="MISSING (tier3-validation.json)"
    pass="false"
  fi

  if [[ "$pass" != "true" ]]; then
    echo "[ERROR] Stage 1 + Stage 2 runtime + Stage 2 NPU validation has not passed."
    echo "[ERROR] Gate artifact status:"
    echo "[ERROR]   Stage 1 (tier1-validation):     $t1_result  (need PASS)"
    echo "[ERROR]   Stage 2 runtime (tier2-validation): $t2_result  (need PASS|WARN)"
    echo "[ERROR]   Model storage (offline-model-storage): $models_result  (need PASS|WARN)"
    echo "[ERROR]   Stage 2 NPU (tier3-validation):  $t3_result  (need PASS|WARN|EXPERIMENTAL-PASS)"
    echo "[ERROR] Preferred: ./ai370-optimize.sh stage1 && ./ai370-optimize.sh stage2 && ./ai370-optimize.sh stage2-validate"
    echo "[ERROR] Or: stage1 + stage2-runtime + stage2-runtime-validate + stage2-npu-validate"
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
  if [[ "$WITH_LEMONADE" == "true" ]]; then
    echo "[INFO] Optional pack: lemonade (S2-M6)"
  fi
  if [[ "$WITH_DIGEST" == "true" ]]; then
    echo "[INFO] Optional pack: digest (S2-M7)"
  fi
  if [[ "$WITH_RAG" == "true" ]]; then
    echo "[INFO] Optional pack: rag (S2-M3)"
  fi
  if [[ "$BENCH" == "true" ]]; then
    echo "[INFO] Bench mode: true (full smoke/compare)"
  fi
  if [[ "$WITH_AI_SMOKE" == "true" ]]; then
    echo "[INFO] Stage 1 AI smoke: true (script 80)"
  fi
  if [[ "$APPLY_TUNING" == "true" ]]; then
    echo "[INFO] Apply runtime tuning: true"
  fi
  if [[ "$STRICT" == "true" ]]; then
    echo "[INFO] Stage 1 strict gate: true (gfx1150 + NPU required)"
  fi
  if [[ "$STAGE1_VALIDATE_SCOPE" == "inventory" ]]; then
    echo "[INFO] Stage 1 validate scope: inventory"
  fi
}

load_runtime_config
print_context

case "$CMD" in
  # === Roadmap stage commands (primary recommended interface) ===
  stage1|tier1)
    run_stage1
    ;;

  stage1-inventory)
    run_stage1_inventory
    ;;

  stage1-validate|tier1-validate)
    export_stage1_env
    run_script "scripts/90-validate.sh" "$STAGE1_VALIDATE_SCOPE"
    write_report_index
    ;;

  stage2)
    echo "[INFO] Running Stage 2 core – runtime + model storage + NPU (Stage 3 gate path)"
    echo "[INFO] Optional packs: --with-lemonade --with-digest --with-rag (or stage2-lemonade / stage2-digest / stage2-rag)."
    run_stage2_runtime_core
    run_stage2_npu_core "true"
    run_optional_packs
    if [[ "$WITH_LEMONADE" != "true" && "$WITH_DIGEST" != "true" && "$WITH_RAG" != "true" ]]; then
      echo "[INFO] Skipped optional S2-M3/M6/M7 packs (not required for Stage 3 gate)."
    fi
    ;;

  stage2-validate)
    echo "[INFO] Stage 2 validate – cheap gate refresh (use --bench for 140/230/245; --with-lemonade for 165)"
    run_script "scripts/150-validate-offline-model-storage.sh" "$OFFLINE"
    if [[ "$BENCH" == "true" ]]; then
      run_script "scripts/140-benchmark-llm.sh" "$OFFLINE"
    fi
    # Refresh tier2 gate artifact from existing llm reports (or after --bench)
    run_script "scripts/145-write-tier2-validation.sh" "$OFFLINE"
    # Inventory / visibility (no heavy EP compare unless --bench)
    run_script "scripts/205-install-xrt-ryzen-ai.sh" "$OFFLINE" "$ACCEPT_AMD_ACCELERATION_RISK"
    run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
    run_script "scripts/220-check-vitis-ai-ep.sh" "$OFFLINE"
    if [[ "$BENCH" == "true" ]]; then
      run_script "scripts/230-benchmark-npu.sh" "$OFFLINE"
      run_script "scripts/245-compare-cpu-gpu-npu.sh" "$OFFLINE"
    fi
    if [[ "$WITH_LEMONADE" == "true" ]]; then
      run_script "scripts/165-validate-lemonade.sh" "$OFFLINE"
    fi
    run_script "scripts/240-write-tier3-validation.sh" "$OFFLINE"
    write_report_index
    if [[ "$BENCH" != "true" ]]; then
      echo "[INFO] Skipped heavy benches (140/230/245). Re-run with --bench to refresh smokes."
    fi
    ;;

  stage2-runtime|tier2)
    echo "[INFO] Running Stage 2 Runtime core (formerly Tier 2)"
    run_stage2_runtime_core
    if [[ "$WITH_LEMONADE" == "true" ]]; then
      run_optional_lemonade
    else
      echo "[INFO] Skipped Lemonade (pass --with-lemonade or run stage2-lemonade)."
    fi
    ;;

  stage2-runtime-validate|tier2-validate)
    echo "[INFO] Stage 2 runtime validation (140 smoke + 145 tier2 aggregate)"
    run_script "scripts/140-benchmark-llm.sh" "$OFFLINE"
    run_script "scripts/145-write-tier2-validation.sh" "$OFFLINE"
    run_script "scripts/150-validate-offline-model-storage.sh" "$OFFLINE"
    if [[ "$WITH_LEMONADE" == "true" ]]; then
      run_script "scripts/165-validate-lemonade.sh" "$OFFLINE"
    fi
    write_report_index
    ;;

  stage2-npu|tier3)
    echo "[INFO] Running Stage 2 NPU core (formerly Tier 3)"
    run_stage2_npu_core "true"
    if [[ "$WITH_LEMONADE" == "true" ]]; then
      run_optional_lemonade
    else
      echo "[INFO] Skipped Lemonade (pass --with-lemonade or run stage2-lemonade for NPU/hybrid LLM serving)."
    fi
    ;;

  stage2-npu-validate|tier3-validate)
    echo "[INFO] Stage 2 NPU validation (writes tier3-validation.json)"
    run_script "scripts/205-install-xrt-ryzen-ai.sh" "$OFFLINE" "$ACCEPT_AMD_ACCELERATION_RISK"
    run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
    run_script "scripts/220-check-vitis-ai-ep.sh" "$OFFLINE"
    run_script "scripts/230-benchmark-npu.sh" "$OFFLINE"
    if [[ "$BENCH" == "true" ]]; then
      run_script "scripts/245-compare-cpu-gpu-npu.sh" "$OFFLINE"
    fi
    if [[ "$WITH_LEMONADE" == "true" ]]; then
      run_script "scripts/165-validate-lemonade.sh" "$OFFLINE"
    fi
    run_script "scripts/240-write-tier3-validation.sh" "$OFFLINE"
    ;;

  stage2-lemonade)
    run_optional_lemonade
    ;;

  stage2-digest)
    run_optional_digest
    ;;

  stage2-models)
    run_stage2_models
    write_report_index
    ;;

  stage2-rag|tier4)
    run_optional_rag
    ;;

  stage3-image|tier5)
    require_tier123_pass
    echo "[INFO] Stage 3 gate passed. Proceeding with Offline Image Generation (ComfyUI + workflows)."
    run_script "scripts/70-comfyui-workflows.sh"
    ;;

  full-stack)
    if [[ "$OFFLINE" == "true" ]]; then
      echo "[ERROR] full-stack does not support --offline (ComfyUI and some components fetch upstream)."
      exit 2
    fi
    if [[ "$ACCEPT_AMD_ACCELERATION_RISK" != "true" ]]; then
      echo "[ERROR] full-stack requires --accept-amd-acceleration-risk."
      exit 2
    fi
    echo "[INFO] full-stack: Stage 1 + Stage 2 core + optional packs + AMD accel + Stage 3 workflows"
    run_stage1
    run_stage2_runtime_core
    run_stage2_npu_core "true"
    run_optional_packs
    if [[ -f "$PROJECT_ROOT/scripts/65-amd-acceleration-install.sh" ]]; then
      run_script "scripts/65-amd-acceleration-install.sh" "$OFFLINE" "$ACCEPT_AMD_ACCELERATION_RISK"
    fi
    run_script "scripts/70-validate-gpu-stack.sh" "$OFFLINE"
    run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
    run_script "scripts/245-compare-cpu-gpu-npu.sh" "$OFFLINE"
    run_script "scripts/240-write-tier3-validation.sh" "$OFFLINE"
    # Stage 3 image (workflows + synthetic/bench script; full ComfyUI install is S3-M1)
    run_script "scripts/70-comfyui-workflows.sh"
    run_script_or_legacy "scripts/420-benchmark-comfyui.sh" "scripts/legacy/comfyui-benchmark.sh"
    run_script "scripts/90-validate.sh"
    ;;

  # === Legacy phase commands (compat; prefer stage1 / stage2) ===
  hardware|inventory|audit)
    # Prefer modern hardware detect when present.
    run_script_or_legacy "scripts/10-detect-hardware.sh" "scripts/legacy/01-hardware-audit.sh"
    ;;

  firmware)
    run_script_or_legacy "scripts/20-check-bios.sh" "scripts/legacy/05-firmware-baseline.sh"
    run_script "scripts/25-check-firmware.sh"
    ;;

  kernel-amd)
    echo "[WARN] kernel-amd is legacy; prefer ./ai370-optimize.sh stage1"
    run_script_or_legacy "scripts/30-validate-kernel.sh" "scripts/legacy/10-amd-baseline.sh" "$DRY_RUN"
    ;;

  tune)
    echo "[WARN] tune is legacy; prefer stage1 platform tuning"
    run_script "scripts/40-platform-tuning.sh"
    ;;

  accel-validate)
    echo "[WARN] accel-validate is legacy; prefer stage1 GPU + stage2-npu-validate"
    run_script "scripts/70-validate-gpu-stack.sh" "$OFFLINE"
    run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
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
    run_script_or_legacy "scripts/420-benchmark-comfyui.sh" "scripts/legacy/comfyui-benchmark.sh"
    ;;

  final-validate|validate)
    run_script "scripts/90-validate.sh"
    ;;

  baseline-plan|plan)
    echo "[WARN] baseline-plan is legacy; prefer stage1 hardware detection"
    run_script_or_legacy "scripts/10-detect-hardware.sh" "scripts/legacy/02-generate-report.sh"
    ;;

  baseline-apply)
    echo "[WARN] baseline-apply is legacy; prefer stage1"
    run_script_or_legacy "scripts/30-validate-kernel.sh" "scripts/legacy/10-amd-baseline.sh" "$DRY_RUN"
    ;;

  baseline-validate)
    echo "[WARN] baseline-validate is legacy; prefer stage1-validate"
    run_script_or_legacy "scripts/90-validate.sh" "scripts/legacy/03-baseline-validate.sh"
    ;;

  install)
    echo "[WARN] install is legacy; running stage1 + stage2-runtime core"
    run_stage1
    run_stage2_runtime_core
    ;;

  gpu)
    run_script "scripts/70-validate-gpu-stack.sh" "$OFFLINE"
    ;;

  npu)
    run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
    run_script "scripts/220-check-vitis-ai-ep.sh" "$OFFLINE"
    run_script "scripts/230-benchmark-npu.sh" "$OFFLINE"
    ;;

  guide)
    run_script_or_legacy "scripts/70-validate-gpu-stack.sh" "scripts/legacy/50-guided-acceleration.sh" "$OFFLINE"
    ;;

  execute)
    echo "[WARN] execute is legacy acceleration checklist; prefer stage2-npu"
    run_script_or_legacy "scripts/210-check-ryzen-ai-software.sh" "scripts/legacy/60-acceleration-execution.sh" "$OFFLINE"
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
    # Preserve optional pack flags for the delegated full-stack run.
    local_flags=(--profile="$PROFILE" --mode="$MODE" --persistence="$PERSISTENCE" --accept-amd-acceleration-risk)
    [[ "$WITH_LEMONADE" == "true" ]] && local_flags+=(--with-lemonade)
    [[ "$WITH_DIGEST" == "true" ]] && local_flags+=(--with-digest)
    [[ "$WITH_RAG" == "true" ]] && local_flags+=(--with-rag)
    "$0" full-stack "${local_flags[@]}"
    ;;

  all)
    if [[ "$OFFLINE" == "true" ]]; then
      echo "[ERROR] Command 'all' does not support --offline. Run stage commands individually with --offline."
      exit 2
    fi
    echo "[WARN] 'all' is legacy; running modern Stage 1 + Stage 2 core + Stage 3 workflows (no forced AMD risk install)"
    run_stage1
    run_stage2_runtime_core
    # NPU path without requiring risk flag for inventory-only 205
    run_stage2_npu_core "true"
    run_optional_packs
    run_script "scripts/70-comfyui-workflows.sh"
    run_script_or_legacy "scripts/420-benchmark-comfyui.sh" "scripts/legacy/comfyui-benchmark.sh"
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
