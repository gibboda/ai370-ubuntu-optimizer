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
# full (default) | inventory — inventory skips requiring Stage 1 local-AI smoke artifacts
SCOPE="${4:-full}"
case "$SCOPE" in
  full|inventory) ;;
  true|false)
    # Back-compat if a 4th offline-style boolean was ever passed; treat as full.
    SCOPE="full"
    ;;
  *)
    echo "[WARN] Unknown Stage 1 validate scope '$SCOPE'; using full"
    SCOPE="full"
    ;;
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

main() {
  mkdir -p "$LATEST_DIR"

  echo "[INFO] Tier 1 / 90-validate.sh (Tier 1 final gate)"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE  Scope: $SCOPE"

  # Re-detect key facts (best effort)
  GPU_TEXT="$(detect_gpu_text 2>/dev/null || echo '')"
  GPU_ARCH="$(detect_gpu_arch "$GPU_TEXT" 2>/dev/null || echo 'unknown')"
  NPU_PRESENT="$(detect_npu_present "$(detect_npu_module_text 2>/dev/null || true)" "$(detect_npu_device_text 2>/dev/null || true)" 2>/dev/null || echo false)"

  # 1. Radeon 890M / gfx1150 check
  if [[ "$GPU_ARCH" != "gfx1150" ]]; then
    record_warn "Radeon 890M / gfx1150 not detected (saw: $GPU_ARCH). Check amdgpu firmware/kernel."
  fi

  # 2. AMDXDNA / XDNA2 NPU (Tier 3 enablement is experimental)
  if [[ "$NPU_PRESENT" != "true" ]]; then
    record_warn "AMDXDNA / XDNA2 NPU not detected. Kernel module or device node missing. (Tier 3 is experimental.)"
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
  # inventory scope: hardware/firmware/kernel/GPU/NPU only (no local-AI smoke).
  expected_artifacts=(
    tier1-hardware.json
    tier1-firmware.json
    tier1-firmware-validation.json
    tier1-kernel-plan.json
    tier1-gpu-stack.json
    tier1-npu.json
  )
  if [[ "$SCOPE" == "full" ]]; then
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
  export LATEST_DIR PROFILE status GPU_ARCH NPU_PRESENT FAILURES WARNINGS vulkan_ok BIOS_ACCEPTABLE SCOPE
  python3 - <<'PY' > "$OUT_JSON"
import json, os, datetime
st = os.environ.get("status", "PASS")
gpu_arch = os.environ.get("GPU_ARCH", "unknown")
npu_present = os.environ.get("NPU_PRESENT", "false")
vulkan_ok = os.environ.get("vulkan_ok", "false")
bios_acc = os.environ.get("BIOS_ACCEPTABLE", "unknown")
scope = os.environ.get("SCOPE", "full")
fails = [x for x in os.environ.get("FAILURES", "").splitlines() if x.strip()]
warns = [x for x in os.environ.get("WARNINGS", "").splitlines() if x.strip()]
notes = []
if scope == "inventory":
    notes.append(
        "Inventory-only validation: local-AI smoke (80 / tier1-local-ai-benchmark.json) not required. "
        "Run full stage1 for complete Stage 1 exit criteria including script 80."
    )

data = {
  "tier": 1,
  "status": st,
  "scope": scope,
  "timestamp": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
  "profile": os.environ.get("PROFILE", "ai370"),
  "acceptance": {
    "radeon_890m_gfx1150": gpu_arch == "gfx1150",
    "amdxdna_npu": npu_present == "true",
    "vulkan_validated": vulkan_ok == "true",
    "bios_version_acceptable": bios_acc,
    "rocm_note": "ROCm is validated for visibility only in Tier 1. Full stack install is opt-in.",
    "inventory_only": scope == "inventory",
  },
  "artifacts": {
    "hardware": "reports/latest/tier1-hardware.json",
    "kernel": "reports/latest/tier1-kernel-plan.json",
    "gpu_stack": "reports/latest/tier1-gpu-stack.json",
    "npu": "reports/latest/tier1-npu.json",
    "firmware": "reports/latest/tier1-firmware.json",
    "firmware_validation": "reports/latest/tier1-firmware-validation.json",
    "local_ai": "reports/latest/tier1-local-ai-benchmark.json" if scope == "full" else None,
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
    echo "Profile: $PROFILE | Mode: $MODE"
    echo
    echo "## Acceptance Criteria"
    echo "- Radeon 890M (gfx1150): $([[ "$GPU_ARCH" == "gfx1150" ]] && echo "PASS" || echo "WARN") (detected: $GPU_ARCH)"
    echo "- AMDXDNA / XDNA2 NPU: $([[ "$NPU_PRESENT" == "true" ]] && echo "PASS" || echo "WARN")"
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
    if [[ "$SCOPE" == "inventory" ]]; then
      echo "- Inventory-only: local-AI smoke artifact not required. Run full \`stage1\` for complete Stage 1 exit criteria."
    fi
    echo
    echo "## Next steps"
    echo "- Run Tier 2 (ai runtime + LLM) and Tier 3 (NPU) before attempting Tier 5 (ComfyUI / generative)."
    echo "- Use ./ai370-optimize.sh tier1-validate to re-check this gate."
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
