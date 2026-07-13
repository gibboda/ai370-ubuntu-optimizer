#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 1 final validation (90-validate.sh).
# Aggregates previous Tier 1 artifacts, runs explicit acceptance checks, and writes
# tier1-validation.json that is consumed by the cross-tier gate (require_tier123_pass).

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
# full (default) | inventory | smoke
#   inventory — hardware/firmware/kernel/GPU only (no platform-tuning / local-AI smoke)
#   full      — platform Stage 1 (no required script 80 artifact)
#   smoke     — full + require tier1-local-ai-benchmark.json from optional script 80
SCOPE="${4:-full}"
case "$SCOPE" in
  full|inventory|smoke) ;;
  true|false)
    # Back-compat if a 4th offline-style boolean was ever passed; treat as full.
    SCOPE="full"
    ;;
  *)
    echo "[WARN] Unknown Stage 1 validate scope '$SCOPE'; using full"
    SCOPE="full"
    ;;
esac

# Package E: optional strict mode elevates missing gfx1150 / NPU from WARN to FAIL.
# Default remains experimental-friendly (PASS with acceptance WARNs is OK for Stage 3 gate).
STRICT="${AI370_STAGE1_STRICT:-false}"
case "$STRICT" in
  true|1|yes|on) STRICT="true" ;;
  *) STRICT="false" ;;
esac

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
OUT_JSON="$LATEST_DIR/tier1-validation.json"
OUT_MD="$LATEST_DIR/tier1-summary.md"
OUT_TXT="$LATEST_DIR/tier1-validation.txt"

# Pull in detection for live re-checks of key facts
# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh" 2>/dev/null || true

status="PASS"
failures=()
warnings=()

record_fail() { status="FAIL"; failures+=("$1"); }
record_warn() { [[ "$status" == "PASS" ]] && status="WARN"; warnings+=("$1"); }
# WARN by default; FAIL when --strict / AI370_STAGE1_STRICT=true
record_acceptance() {
  local msg="$1"
  if [[ "$STRICT" == "true" ]]; then
    record_fail "$msg (strict)"
  else
    record_warn "$msg"
  fi
}

main() {
  mkdir -p "$LATEST_DIR"

  echo "[INFO] Tier 1 / 90-validate.sh (Tier 1 final gate)"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE  Scope: $SCOPE  Strict: $STRICT"

  # Re-detect key facts (best effort)
  GPU_TEXT="$(detect_gpu_text 2>/dev/null || echo '')"
  GPU_ARCH="$(detect_gpu_arch "$GPU_TEXT" 2>/dev/null || echo 'unknown')"
  NPU_PRESENT="$(detect_npu_present "$(detect_npu_module_text 2>/dev/null || true)" "$(detect_npu_device_text 2>/dev/null || true)" 2>/dev/null || echo false)"

  # 1. Radeon 890M / gfx1150 check
  if [[ "$GPU_ARCH" != "gfx1150" ]]; then
    record_acceptance "Radeon 890M / gfx1150 not detected (saw: $GPU_ARCH). Check amdgpu firmware/kernel."
  fi

  # 2. AMDXDNA / XDNA2 NPU (Tier 3 enablement is experimental)
  if [[ "$NPU_PRESENT" != "true" ]]; then
    record_acceptance "AMDXDNA / XDNA2 NPU not detected. Kernel module or device node missing. (Tier 3 is experimental.)"
  fi

  # 3. Vulkan visible (from previous phase artifact or live)
  vulkan_ok=false
  if [[ -f "$LATEST_DIR/tier1-gpu-stack.json" ]]; then
    if python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
print("true" if d.get("vulkan")=="visible" else "false")
' "$LATEST_DIR/tier1-gpu-stack.json" 2>/dev/null | grep -q true; then
      vulkan_ok=true
    fi
  fi
  if [[ "$vulkan_ok" != true ]]; then
    # fallback live check
    if vulkaninfo --summary 2>/dev/null | grep -qi 'deviceName\|Radeon'; then
      vulkan_ok=true
    fi
  fi
  if [[ "$vulkan_ok" != true ]]; then
    record_warn "Vulkan not clearly validated in Tier 1 GPU stack phase."
  fi

  # 4. ROCm (presence is informational at Tier 1 – full install is later gated)
  rocm_note="ROCm visibility is optional at pure Tier 1; explicit installation happens via amd-accel-install after risk acceptance."
  if ! command -v rocminfo >/dev/null 2>&1; then
    rocm_note+=" (rocminfo not in PATH yet)"
  fi

  EXPECTED_BIOS=""
  PROFILE_ENV="$PROJECT_ROOT/configs/profiles/$PROFILE.env"
  if [[ -f "$PROFILE_ENV" ]]; then
    # shellcheck source=/dev/null
    source "$PROFILE_ENV"
    EXPECTED_BIOS="${EXPECTED_BIOS_VERSION:-}"
  fi

  # 5. BIOS version target (for AI370) – non-fatal, recorded for gate visibility (M1.1)
  BIOS_ACCEPTABLE="unknown"
  if [[ -f "$LATEST_DIR/tier1-firmware.json" ]]; then
    BIOS_ACCEPTABLE="$(python3 - "$LATEST_DIR/tier1-firmware.json" <<'PY' 2>/dev/null || echo unknown
import json,sys
d=json.load(open(sys.argv[1]))
print(d.get("bios_acceptable","unknown"))
PY
)"
  else
    bver="$(detect_bios_version 2>/dev/null || echo '')"
    if [[ -n "$EXPECTED_BIOS" && -n "$bver" && "$bver" != "unknown" ]]; then
      if [[ "$bver" == "$EXPECTED_BIOS" || "$bver" == *"$EXPECTED_BIOS"* ]]; then
        BIOS_ACCEPTABLE="true"
      else
        BIOS_ACCEPTABLE="false"
      fi
    fi
  fi
  if [[ "$BIOS_ACCEPTABLE" == "false" ]]; then
    record_warn "BIOS version not at target $EXPECTED_BIOS for $PROFILE profile (see tier1-firmware.json)."
  fi

  # Require that the main previous Tier 1 steps produced artifacts (loose but useful).
  # inventory: hardware/firmware/kernel/GPU/NPU only
  # full:     + platform-tuning (soft); no script 80 by default (Package E)
  # smoke:    full + local-AI smoke artifact from optional script 80
  expected_artifacts=(
    tier1-hardware.json
    tier1-firmware.json
    tier1-firmware-validation.json
    tier1-kernel-plan.json
    tier1-gpu-stack.json
    tier1-npu.json
  )
  if [[ "$SCOPE" == "full" || "$SCOPE" == "smoke" ]]; then
    expected_artifacts+=(tier1-platform-tuning.json)
  fi
  if [[ "$SCOPE" == "smoke" ]]; then
    expected_artifacts+=(tier1-local-ai-benchmark.json)
  fi
  for f in "${expected_artifacts[@]}"; do
    if [[ ! -f "$LATEST_DIR/$f" ]]; then
      record_warn "Expected Tier 1 artifact missing: $f"
    fi
  done

  # Write machine gate artifact (export locals for the python snippet)
  FAILURES="$(printf '%s\n' ${failures[@]+"${failures[@]}"})"
  WARNINGS="$(printf '%s\n' ${warnings[@]+"${warnings[@]}"})"
  export LATEST_DIR PROFILE status GPU_ARCH NPU_PRESENT FAILURES WARNINGS vulkan_ok BIOS_ACCEPTABLE SCOPE STRICT
  python3 - <<'PY' > "$OUT_JSON"
import json, os, datetime
st = os.environ.get("status", "PASS")
gpu_arch = os.environ.get("GPU_ARCH", "unknown")
npu_present = os.environ.get("NPU_PRESENT", "false")
vulkan_ok = os.environ.get("vulkan_ok", "false")
bios_acc = os.environ.get("BIOS_ACCEPTABLE", "unknown")
scope = os.environ.get("SCOPE", "full")
strict = os.environ.get("STRICT", "false") == "true"
fails = [x for x in os.environ.get("FAILURES", "").splitlines() if x.strip()]
warns = [x for x in os.environ.get("WARNINGS", "").splitlines() if x.strip()]
notes = []
if scope == "inventory":
    notes.append(
        "Inventory-only validation: platform-tuning and local-AI smoke (80) not required. "
        "Run stage1 for platform plans; pass --with-ai-smoke for script 80."
    )
elif scope == "full":
    notes.append(
        "Platform Stage 1 validation: local-AI smoke (80 / tier1-local-ai-benchmark.json) is optional. "
        "Pass --with-ai-smoke (scope=smoke) to require it. "
        "PASS with acceptance WARNs is experimental-friendly; use --strict to fail on missing gfx1150/NPU."
    )
elif scope == "smoke":
    notes.append(
        "Smoke-scope validation: requires tier1-local-ai-benchmark.json from script 80 "
        "(./ai370-optimize.sh stage1 --with-ai-smoke)."
    )
if strict:
    notes.append("Strict mode: missing gfx1150 or NPU is FAIL (AI370_STAGE1_STRICT / --strict).")

data = {
  "tier": 1,
  "status": st,
  "scope": scope,
  "strict": strict,
  "timestamp": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
  "profile": os.environ.get("PROFILE", "ai370"),
  "acceptance": {
    "radeon_890m_gfx1150": gpu_arch == "gfx1150",
    "amdxdna_npu": npu_present == "true",
    "vulkan_validated": vulkan_ok == "true",
    "bios_version_acceptable": bios_acc,
    "rocm_note": "ROCm is validated for visibility only in Tier 1. Full stack install is opt-in.",
    "inventory_only": scope == "inventory",
    "ai_smoke_required": scope == "smoke",
  },
  "artifacts": {
    "hardware": "reports/latest/tier1-hardware.json",
    "kernel": "reports/latest/tier1-kernel-plan.json",
    "gpu_stack": "reports/latest/tier1-gpu-stack.json",
    "npu": "reports/latest/tier1-npu.json",
    "firmware": "reports/latest/tier1-firmware.json",
    "firmware_validation": "reports/latest/tier1-firmware-validation.json",
    "platform_tuning": "reports/latest/tier1-platform-tuning.json" if scope in ("full", "smoke") else None,
    "local_ai": "reports/latest/tier1-local-ai-benchmark.json" if scope == "smoke" else None,
  },
  "failures": fails,
  "warnings": warns,
  "notes": notes,
}
print(json.dumps(data, indent=2))
PY

  # Human summary
  {
    echo "# Tier 1 Validation Summary"
    echo
    echo "**Status:** $status"
    echo "Profile: $PROFILE | Mode: $MODE | Scope: $SCOPE | Strict: $STRICT"
    echo
    echo "## Acceptance Criteria"
    local gfx_label npu_label
    if [[ "$GPU_ARCH" == "gfx1150" ]]; then
      gfx_label="PASS"
    elif [[ "$STRICT" == "true" ]]; then
      gfx_label="FAIL"
    else
      gfx_label="WARN"
    fi
    if [[ "$NPU_PRESENT" == "true" ]]; then
      npu_label="PASS"
    elif [[ "$STRICT" == "true" ]]; then
      npu_label="FAIL"
    else
      npu_label="WARN"
    fi
    echo "- Radeon 890M (gfx1150): $gfx_label (detected: $GPU_ARCH)"
    echo "- AMDXDNA / XDNA2 NPU: $npu_label"
    echo "- Vulkan validated: (see tier1-gpu-stack.json)"
    if [[ -n "$EXPECTED_BIOS" ]]; then
      echo "- BIOS version (target $EXPECTED_BIOS for $PROFILE): $BIOS_ACCEPTABLE (see tier1-firmware.json)"
    else
      echo "- BIOS version target: not configured for profile $PROFILE (see tier1-firmware.json)"
    fi
    echo "- ROCm: visibility-only at this tier. $rocm_note"
    echo
    if (( ${#failures[@]} > 0 )); then
      echo "## Failures"
      for f in "${failures[@]}"; do echo "- $f"; done
      echo
    fi
    if (( ${#warnings[@]} > 0 )); then
      echo "## Warnings"
      for w in "${warnings[@]}"; do echo "- $w"; done
      echo
    fi
    echo "## Scope"
    echo "- Validate scope: $SCOPE"
    echo "- Strict gate: $STRICT"
    case "$SCOPE" in
      inventory)
        echo "- Inventory-only: platform-tuning and local-AI smoke not required."
        echo "- Run \`stage1\` for platform plans; \`stage1 --with-ai-smoke\` for script 80."
        ;;
      full)
        echo "- Platform Stage 1: local-AI smoke (script 80) is optional."
        echo "- PASS with acceptance WARNs is OK for the Stage 3 gate; use --strict for hard AI370 checks."
        ;;
      smoke)
        echo "- Smoke scope: requires tier1-local-ai-benchmark.json from script 80."
        ;;
    esac
    echo
    echo "## Next steps"
    echo "- Run Stage 2 (runtime + NPU) before Stage 3 (ComfyUI / generative)."
    echo "- Re-check: ./ai370-optimize.sh stage1-validate  (add --inventory or --strict as needed)"
  } > "$OUT_MD"

  echo "$status" > "$OUT_TXT"

  echo "[INFO] Tier 1 validation status: $status"
  echo "[INFO] Wrote $OUT_JSON"
  echo "[INFO] Wrote $OUT_MD"

  if [[ "$status" == "FAIL" ]]; then
    exit 3
  fi
}

main "$@"
