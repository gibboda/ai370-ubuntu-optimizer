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
# Compatibility flags: --with-ai-smoke and --apply-tuning are not Stage 1.
WITH_AI_SMOKE="false"
APPLY_TUNING="false"
APPROVE="false"
STRICT="false"
STAGE1_VALIDATE_SCOPE="full"

usage() {
  cat <<'USAGE'
Usage (Roadmap stages - recommended):
  ./ai370-optimize.sh stage1 [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh stage1-probe
  ./ai370-optimize.sh stage1-profile
  ./ai370-optimize.sh stage2-platform-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
       [--offline] [--strict]
  ./ai370-optimize.sh stage2-platform-inventory [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
       [--offline] [--strict]
  ./ai370-optimize.sh stage2-firmware-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh stage2-kernel-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
       [--dry-run]
  ./ai370-optimize.sh stage2-gpu-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh stage2-npu-validate [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
       [--offline] [--bench] [--with-lemonade]
  ./ai370-optimize.sh stage2-optimize-plan [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh stage2-optimize-apply --approve [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
       [--dry-run]
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
  ./ai370-optimize.sh stage2-rag [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh stage2-lemonade [--profile=ai370] [--mode=safe] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh stage2-digest [--profile=ai370] [--mode=safe] [--persistence=runtime] [--offline]
  ./ai370-optimize.sh stage2-models [--profile=ai370] [--mode=safe] [--persistence=runtime]
  ./ai370-optimize.sh stage3-image [--profile=ai370] [--mode=safe|aggressive] [--persistence=runtime]
  ./ai370-optimize.sh full-stack [--profile=ai370] [--mode=safe] [--persistence=runtime]
       --accept-amd-acceleration-risk [--with-lemonade] [--with-digest] [--with-rag]

Compatibility aliases (deprecated; prefer the Stage 2 platform commands):
  ./ai370-optimize.sh stage1-inventory
  ./ai370-optimize.sh stage1-validate [--inventory] [--strict]

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

Stage 1 (read-only, S1-M1 through S1-M5):
  stage1 / stage1-profile = probe if needed + normalize/classify/candidates/publish
  stage1-probe = S1-M1 read-only raw hardware and OS inventory
  --apply-tuning is not a Stage 1 flag; use stage2-optimize-apply --approve
  --with-ai-smoke is not a Stage 1 flag; use scripts/80-benchmark-local-ai.sh (S3-M6)
  Mixed BIOS/kernel/GPU/tuning/90-validate no longer runs from stage1.

Stage 2 platform (S2-M7 aggregate via 90-validate shim; S2-M1/M2 canonical JSON still Planned):
  stage2-firmware-validate = 20-check-bios (S2-M1 Planned); requires S1-M5 profile
  stage2-kernel-validate = 30-validate-kernel (S2-M2 Planned); requires S1-M5 profile
  stage2-gpu-validate = s2-m3-validate-gpu-stack (S2-M3 In progress)
  stage2-npu-validate is visibility-only (S2-M4) by default; pass --bench for the
    mixed 210-validate / 230 / 245 compatibility path until S3-M6. Script 240
    always refreshes tier3-validation.json on this command.
  stage2-optimize-plan = 40-platform-tuning plan-only (S2-M5 In progress)
  stage2-optimize-apply --approve = 40-platform-tuning apply (S2-M6 In progress)
  stage2-platform-validate = firmware + kernel + GPU + NPU visibility + S2-M7 (90-validate shim)
  --strict (or AI370_STAGE1_STRICT=true): FAIL if gfx1150 or NPU missing (S2-M7)
  stage2-platform-inventory = detect + firmware + kernel + GPU + inventory-scope S2-M7

Stage 2 runtime (default stage2 / Stage 3 gate path; not the platform aggregate):
  Runtime: 100, 110, 120, 130, 140, 145, 150
  NPU mixed path: remaining on stage2-npu and stage2-npu-validate --bench
  stage2-validate is a cheap runtime/NPU gate refresh; it is not the S2-M7
    platform aggregate. Use stage2-platform-validate for firmware/kernel/GPU/NPU
    visibility. Pass --bench for LLM smoke and NPU MatMul comparison (140 / 230 / 245).
Optional packs (not Stage 3 gate inputs):
  --with-lemonade / stage2-lemonade  → 170, 160, 165 (S3-M5 compatibility path)
  --with-digest / stage2-digest      → 250, 255 (S3-M4 diagnostics)
  --with-rag / stage2-rag            → 300, 310, 320 (S4-M3)
  stage2-models                      → 155 layout + 150 validate (S3-M1 polish; no downloads)
  Env: LEMONADE_START=true, ANYTHINGLLM_START=true for full serving/UI smokes

Defaults:
  profile     ai370
  mode        safe
  persistence runtime

Notes:
  Stage 1 is read-only and does not write platform-validation or tuning artifacts.
  Platform PASS may still include acceptance WARNs (missing optional hardware); that
    is intentional and experimental-friendly. Use --strict for hard AI370 checks.
  stage2 is core-only by default (runtime + NPU + gate artifacts). Optional AMD
    product packs require --with-lemonade, --with-digest, and/or --with-rag.
  --offline affects Stage 2 platform/runtime/NPU and amd-accel-install.
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
    --approve) APPROVE="true" ;;
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

export_platform_strict_env() {
  # Strict mode belongs to the Stage 2 S2-M7 aggregate (90-validate shim).
  if [[ "$STRICT" == "true" ]]; then
    export AI370_STAGE1_STRICT=true
  else
    export AI370_STAGE1_STRICT=false
  fi
  export DRY_RUN="${DRY_RUN:-false}"
}

warn_stage1_removed_flags() {
  if [[ "$APPLY_TUNING" == "true" ]]; then
    echo "[WARN] --apply-tuning is not a Stage 1 flag. Use: ./ai370-optimize.sh stage2-optimize-apply --approve"
  fi
  if [[ "$WITH_AI_SMOKE" == "true" ]]; then
    echo "[WARN] --with-ai-smoke is not a Stage 1 flag. Use scripts/80-benchmark-local-ai.sh (S3-M6) until stage3-runtime-benchmark exists."
  fi
}

run_stage1_profile() {
  echo "[INFO] Stage 1 profile – S1-M1 probe if needed, then S1-M2 through S1-M5"
  local latest="$PROJECT_ROOT/reports/latest"
  local raw="$latest/s1-m1-raw-inventory.json"
  mkdir -p "$latest"
  if [[ ! -f "$raw" ]]; then
    if [[ -n "${AI370_S1_M1_FIXTURE:-}" ]]; then
      echo "[INFO] Replaying S1-M1 from fixture: $AI370_S1_M1_FIXTURE"
      bash "$PROJECT_ROOT/scripts/s1-m1-probe-system.sh" --fixture "$AI370_S1_M1_FIXTURE"
    else
      bash "$PROJECT_ROOT/scripts/s1-m1-probe-system.sh"
    fi
  fi
  local generator_version="unknown"
  if [[ -f "$PROJECT_ROOT/VERSION" ]]; then
    generator_version="$(tr -d '[:space:]' < "$PROJECT_ROOT/VERSION")"
  fi
  python3 "$PROJECT_ROOT/scripts/s1-m2-normalize-profile.py" \
    --input "$raw" \
    --output "$latest/s1-m2-normalized-facts.json"
  python3 "$PROJECT_ROOT/scripts/s1-m3-classify-platform.py" \
    --input "$latest/s1-m2-normalized-facts.json" \
    --output "$latest/s1-m3-platform-classification.json"
  python3 "$PROJECT_ROOT/scripts/s1-m4-derive-capabilities.py" \
    --input "$latest/s1-m2-normalized-facts.json" \
    --output "$latest/s1-m4-capability-candidates.json"
  python3 "$PROJECT_ROOT/scripts/s1-m5-publish-profile.py" \
    --facts "$latest/s1-m2-normalized-facts.json" \
    --classification "$latest/s1-m3-platform-classification.json" \
    --capabilities "$latest/s1-m4-capability-candidates.json" \
    --output "$latest/s1-m5-system-profile.json" \
    --summary "$latest/s1-m5-inventory-summary.md" \
    --compat-output "$latest/system-profile.json" \
    --generator-version "$generator_version"
}

ensure_stage1_profile() {
  local profile="$PROJECT_ROOT/reports/latest/s1-m5-system-profile.json"
  if [[ ! -f "$profile" ]]; then
    echo "[INFO] No S1-M5 system profile present; running stage1-profile"
    run_stage1_profile
  fi
}

run_stage2_platform_inventory() {
  echo "[INFO] Stage 2 platform inventory – firmware + kernel + GPU + inventory-scope validate"
  export_platform_strict_env
  ensure_stage1_profile
  # Compatibility collector still publishes tier1-hardware.json / tier1-npu.json for 90-validate.
  run_script "scripts/10-detect-hardware.sh"
  run_script "scripts/20-check-bios.sh"
  run_script "scripts/30-validate-kernel.sh" "$DRY_RUN"
  run_script "scripts/s2-m3-validate-gpu-stack.sh" "$OFFLINE"
  run_script "scripts/90-validate.sh" "inventory"
  write_report_index
}

run_stage2_platform_validate() {
  echo "[INFO] Stage 2 platform validate – firmware, kernel, GPU, NPU visibility, then S2-M7"
  echo "[INFO] 90-validate.sh is the compatibility shim; canonical report is s2-m7-platform-validation.json"
  export_platform_strict_env
  ensure_stage1_profile
  run_script "scripts/10-detect-hardware.sh"
  run_script "scripts/20-check-bios.sh"
  run_script "scripts/30-validate-kernel.sh" "$DRY_RUN"
  run_script "scripts/s2-m3-validate-gpu-stack.sh" "$OFFLINE"
  run_script "scripts/s2-m4-validate-npu-stack.sh" "$OFFLINE"
  # Inventory scope: S2-M5 tuning is a separate command, not required for the platform gate.
  run_script "scripts/90-validate.sh" "inventory"
  write_report_index
}

run_stage2_optimize_plan() {
  echo "[INFO] Stage 2 optimize plan – 40-platform-tuning plan-only (S2-M5 wrapper)"
  export DRY_RUN="${DRY_RUN:-false}"
  export AI370_APPLY_TUNING=false
  export AI370_APPROVE=false
  export AI370_OPTIMIZE_ACTION=plan
  if [[ "$APPLY_TUNING" == "true" ]]; then
    echo "[WARN] --apply-tuning is ignored on stage2-optimize-plan. Use stage2-optimize-apply --approve"
  fi
  ensure_stage1_profile
  run_script "scripts/40-platform-tuning.sh" plan
  write_report_index
}

run_stage2_optimize_apply() {
  if [[ "$APPROVE" != "true" ]]; then
    echo "[ERROR] stage2-optimize-apply requires --approve (plan first with stage2-optimize-plan)."
    echo "[ERROR] --apply-tuning is not sufficient; pass --approve to mutate runtime settings."
    exit 2
  fi
  echo "[INFO] Stage 2 optimize apply – 40-platform-tuning with approval (S2-M6 wrapper)"
  export DRY_RUN="${DRY_RUN:-false}"
  export AI370_APPLY_TUNING=true
  export AI370_APPROVE=true
  export AI370_OPTIMIZE_ACTION=apply
  ensure_stage1_profile
  run_script "scripts/40-platform-tuning.sh" apply --approve
  write_report_index
}

write_report_index() {
  # shellcheck source=scripts/lib/common.sh
  PROJECT_ROOT="$PROJECT_ROOT" source "$PROJECT_ROOT/scripts/lib/common.sh"
  ai370_write_report_index "$PROJECT_ROOT/reports/latest"
}

run_stage2_runtime_core() {
  echo "[INFO] Stage 2 runtime core (PyTorch/llama.cpp/Ollama/WebUI + model storage)"
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
  echo "[INFO] Optional S3-M5 TurnkeyML + Lemonade"
  run_script "scripts/170-install-turnkeyml.sh" "$OFFLINE"
  run_script "scripts/160-install-lemonade.sh" "$OFFLINE"
  run_script "scripts/165-validate-lemonade.sh" "$OFFLINE"
}

run_optional_digest() {
  echo "[INFO] Optional S3-M4 Digest AI model analysis"
  run_script "scripts/250-install-digest-ai.sh" "$OFFLINE"
  run_script "scripts/255-analyze-model-digest.sh" "$OFFLINE"
}

run_optional_rag() {
  echo "[INFO] Optional S4-M3 Offline RAG"
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
    echo "[ERROR] Preferred: ./ai370-optimize.sh stage1 && ./ai370-optimize.sh stage2-platform-validate && ./ai370-optimize.sh stage2 && ./ai370-optimize.sh stage2-validate"
    echo "[ERROR] Or: stage1-profile + stage2-platform-validate + stage2-runtime + stage2-runtime-validate + stage2-npu-validate"
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
    echo "[INFO] Optional pack: lemonade (S3-M5)"
  fi
  if [[ "$WITH_DIGEST" == "true" ]]; then
    echo "[INFO] Optional pack: digest (S3-M4 diagnostics)"
  fi
  if [[ "$WITH_RAG" == "true" ]]; then
    echo "[INFO] Optional pack: rag (S4-M3)"
  fi
  if [[ "$BENCH" == "true" ]]; then
    echo "[INFO] Bench mode: true (full smoke/compare)"
  fi
  if [[ "$WITH_AI_SMOKE" == "true" ]]; then
    echo "[INFO] --with-ai-smoke set (ignored on Stage 1; use scripts/80-benchmark-local-ai.sh)"
  fi
  if [[ "$APPLY_TUNING" == "true" ]]; then
    echo "[INFO] --apply-tuning set (ignored on Stage 1; use stage2-optimize-apply --approve)"
  fi
  if [[ "$APPROVE" == "true" ]]; then
    echo "[INFO] Approve: true"
  fi
  if [[ "$STRICT" == "true" ]]; then
    echo "[INFO] Platform strict gate: true (gfx1150 + NPU required)"
  fi
  if [[ "$STAGE1_VALIDATE_SCOPE" == "inventory" ]]; then
    echo "[INFO] Compatibility validate scope: inventory"
  fi
}

load_runtime_config
print_context

case "$CMD" in
  # === Roadmap stage commands (primary recommended interface) ===
  stage1|tier1)
    echo "[INFO] Stage 1 is read-only probe + profile (S1-M1 through S1-M5)"
    echo "[INFO] BIOS/kernel/GPU/NPU visibility and tuning moved to stage2-platform-* / stage2-optimize-*"
    warn_stage1_removed_flags
    run_stage1_profile
    ;;

  stage1-probe)
    bash "$PROJECT_ROOT/scripts/s1-m1-probe-system.sh"
    ;;

  stage1-profile)
    run_stage1_profile
    ;;

  stage1-inventory)
    echo "[WARN] stage1-inventory is deprecated; use stage2-platform-inventory"
    warn_stage1_removed_flags
    run_stage2_platform_inventory
    ;;

  stage1-validate|tier1-validate)
    echo "[WARN] stage1-validate is deprecated; use stage2-platform-validate"
    warn_stage1_removed_flags
    if [[ "$STAGE1_VALIDATE_SCOPE" == "inventory" ]]; then
      run_stage2_platform_inventory
    else
      run_stage2_platform_validate
    fi
    ;;

  stage2-platform-validate)
    run_stage2_platform_validate
    ;;

  stage2-platform-inventory)
    run_stage2_platform_inventory
    ;;

  stage2-firmware-validate)
    echo "[INFO] Stage 2 firmware validate (S2-M1 wrapper around 20-check-bios.sh)"
    echo "[INFO] Consumes s1-m5-system-profile.json (classified platform_id, not CLI --profile alone)"
    ensure_stage1_profile
    run_script "scripts/20-check-bios.sh"
    write_report_index
    ;;

  stage2-kernel-validate)
    echo "[INFO] Stage 2 kernel validate (S2-M2 wrapper around 30-validate-kernel.sh)"
    ensure_stage1_profile
    run_script "scripts/30-validate-kernel.sh" "$DRY_RUN"
    write_report_index
    ;;

  stage2-optimize-plan)
    run_stage2_optimize_plan
    ;;

  stage2-optimize-apply)
    run_stage2_optimize_apply
    ;;

  stage2)
    echo "[INFO] Running Stage 2 core – runtime + model storage + NPU (Stage 3 gate path)"
    echo "[INFO] Optional packs: --with-lemonade --with-digest --with-rag (or stage2-lemonade / stage2-digest / stage2-rag)."
    run_stage2_runtime_core
    run_stage2_npu_core "true"
    run_optional_packs
    if [[ "$WITH_LEMONADE" != "true" && "$WITH_DIGEST" != "true" && "$WITH_RAG" != "true" ]]; then
      echo "[INFO] Skipped optional Lemonade/Digest/RAG packs (not required for Stage 3 gate)."
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
    echo "[INFO] Stage 2 NPU visibility (S2-M4); writes s2-m4-npu-runtime-validation.json"
    run_script "scripts/s2-m4-validate-npu-stack.sh" "$OFFLINE"
    if [[ "$BENCH" == "true" ]]; then
      echo "[INFO] Compatibility mixed NPU path (210 execution + 230/245) until S3-M6"
      run_script "scripts/210-check-ryzen-ai-software.sh" "$OFFLINE"
      run_script "scripts/220-check-vitis-ai-ep.sh" "$OFFLINE"
      run_script "scripts/230-benchmark-npu.sh" "$OFFLINE"
      run_script "scripts/245-compare-cpu-gpu-npu.sh" "$OFFLINE"
      if [[ "$WITH_LEMONADE" == "true" ]]; then
        run_script "scripts/165-validate-lemonade.sh" "$OFFLINE"
      fi
    else
      if [[ "$WITH_LEMONADE" == "true" ]]; then
        run_script "scripts/165-validate-lemonade.sh" "$OFFLINE"
      fi
      echo "[INFO] Skipped NPU execution benches (230/245). Re-run with --bench for the mixed compatibility path."
    fi
    run_script "scripts/240-write-tier3-validation.sh" "$OFFLINE"
    write_report_index
    ;;

  stage2-gpu-validate|gpu-validate)
    echo "[INFO] Stage 2 GPU visibility (S2-M3)"
    run_script "scripts/s2-m3-validate-gpu-stack.sh" "$OFFLINE"
    write_report_index
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
    echo "[INFO] full-stack: Stage 1 profile + Stage 2 platform validate + runtime/NPU core + optional packs + AMD accel + Stage 3 workflows"
    run_stage1_profile
    run_stage2_platform_validate
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
    echo "[WARN] firmware is legacy; prefer ./ai370-optimize.sh stage2-firmware-validate"
    ensure_stage1_profile
    run_script_or_legacy "scripts/20-check-bios.sh" "scripts/legacy/05-firmware-baseline.sh"
    run_script "scripts/25-check-firmware.sh"
    ;;

  kernel-amd)
    echo "[WARN] kernel-amd is legacy; prefer ./ai370-optimize.sh stage2-kernel-validate"
    ensure_stage1_profile
    run_script_or_legacy "scripts/30-validate-kernel.sh" "scripts/legacy/10-amd-baseline.sh" "$DRY_RUN"
    ;;

  tune)
    echo "[WARN] tune is legacy; prefer stage2-optimize-plan (or stage2-optimize-apply --approve)"
    run_stage2_optimize_plan
    ;;

  accel-validate)
    echo "[WARN] accel-validate is legacy; prefer stage2-gpu-validate + stage2-npu-validate"
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
    echo "[WARN] baseline-plan is legacy; prefer stage1-probe / stage1-profile"
    run_script_or_legacy "scripts/10-detect-hardware.sh" "scripts/legacy/02-generate-report.sh"
    ;;

  baseline-apply)
    echo "[WARN] baseline-apply is legacy; prefer stage2-kernel-validate or stage2-optimize-apply --approve"
    ensure_stage1_profile
    run_script_or_legacy "scripts/30-validate-kernel.sh" "scripts/legacy/10-amd-baseline.sh" "$DRY_RUN"
    ;;

  baseline-validate)
    echo "[WARN] baseline-validate is legacy; prefer stage2-platform-validate"
    run_script_or_legacy "scripts/90-validate.sh" "scripts/legacy/03-baseline-validate.sh"
    ;;

  install)
    echo "[WARN] install is legacy; running stage1-profile + stage2-runtime core"
    run_stage1_profile
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
    echo "[WARN] 'all' is legacy; running Stage 1 profile + Stage 2 platform validate + runtime/NPU + Stage 3 workflows"
    run_stage1_profile
    run_stage2_platform_validate
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
