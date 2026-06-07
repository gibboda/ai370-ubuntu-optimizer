#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
DRY_RUN="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
VALIDATION_STATUS="$LATEST_DIR/validation-status.txt"
HARDWARE_JSON="$LATEST_DIR/hardware.json"
BASELINE_PLAN_JSON="$LATEST_DIR/baseline-plan.json"
BASELINE_APPLY_STATUS="$LATEST_DIR/baseline-apply-status.txt"
BASELINE_APPLY_SUMMARY="$LATEST_DIR/baseline-apply-summary.md"
BASELINE_POSTCHECK_JSON="$LATEST_DIR/baseline-postcheck.json"

# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

BASE_PACKAGES=()
PACKAGE_GROUP_SUMMARY=""
PLAN_STATUS=""
PLAN_VALIDATION_STATUS=""
PLANNED_POWER_PROFILE="balanced"
POST_CHECKS=()
ALREADY_INSTALLED=()
NEWLY_REQUESTED=()
MISSING_BEFORE=()
PLAN_EXPECTS_NPU="false"

require_root_privilege() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[INFO] Dry run requested; sudo/root access is not required."
    return
  fi

  if [[ "${EUID}" -ne 0 ]]; then
    echo "[INFO] sudo access is required for package installation."
    sudo -v
  fi
}

load_baseline_plan() {
  if [[ ! -f "$BASELINE_PLAN_JSON" ]]; then
    echo "[ERROR] Missing baseline plan: $BASELINE_PLAN_JSON"
    echo "[ERROR] Run: ./ai370-optimize.sh baseline-plan --profile=$PROFILE --mode=$MODE"
    exit 3
  fi

  mapfile -t BASE_PACKAGES < <(python3 - "$BASELINE_PLAN_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data=json.load(fh)
for pkg in data.get("baseline", {}).get("packages", []):
    print(pkg)
PY
  )

  PLAN_STATUS="$(python3 - "$BASELINE_PLAN_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    print(json.load(fh).get("plan_status", "unknown"))
PY
  )"

  PLAN_VALIDATION_STATUS="$(python3 - "$BASELINE_PLAN_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    print(json.load(fh).get("validation", {}).get("status", "unknown"))
PY
  )"

  PLAN_EXPECTS_NPU="$(python3 - "$BASELINE_PLAN_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    print("true" if json.load(fh).get("hardware", {}).get("npu_present") else "false")
PY
  )"

  PLANNED_POWER_PROFILE="$(python3 - "$BASELINE_PLAN_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    print(json.load(fh).get("baseline", {}).get("runtime_settings", {}).get("power_profile", "balanced"))
PY
  )"

  PACKAGE_GROUP_SUMMARY="$(python3 - "$BASELINE_PLAN_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    groups=json.load(fh).get("baseline", {}).get("package_groups", {})
for name, packages in groups.items():
    print(f"{name}: {' '.join(packages)}")
PY
  )"

  mapfile -t POST_CHECKS < <(python3 - "$BASELINE_PLAN_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data=json.load(fh)
for check in data.get("baseline", {}).get("post_checks", []):
    print(check)
PY
  )

  if [[ ${#BASE_PACKAGES[@]} -eq 0 ]]; then
    echo "[ERROR] Baseline plan has no packages to apply."
    exit 3
  fi
}

require_phase2_pass() {
  if [[ ! -f "$VALIDATION_STATUS" ]]; then
    echo "[ERROR] Missing Phase 2 validation output: $VALIDATION_STATUS"
    echo "[ERROR] Run: ./ai370-optimize.sh audit && ./ai370-optimize.sh baseline-plan --profile=$PROFILE"
    exit 3
  fi

  local status
  status="$(head -n 1 "$VALIDATION_STATUS" | tr -d '[:space:]')"

  if [[ "$status" == "FAIL" || "$PLAN_STATUS" == "blocked" ]]; then
    echo "[ERROR] Baseline plan is blocked. Refusing baseline installation."
    sed -n '1,80p' "$VALIDATION_STATUS"
    exit 3
  fi

  if [[ "$status" == "WARN" || "$PLAN_STATUS" == "warn-only" ]]; then
    echo "[WARN] Baseline plan contains warnings. Continuing with the approved runtime baseline plan."
    sed -n '1,80p' "$VALIDATION_STATUS"
  fi
}

classify_packages() {
  ALREADY_INSTALLED=()
  NEWLY_REQUESTED=()
  MISSING_BEFORE=()

  local pkg
  for pkg in "${BASE_PACKAGES[@]}"; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
      ALREADY_INSTALLED+=("$pkg")
    else
      MISSING_BEFORE+=("$pkg")
      NEWLY_REQUESTED+=("$pkg")
    fi
  done
}

print_plan_summary() {
  echo "[INFO] Baseline plan status: $PLAN_STATUS"
  echo "[INFO] Validation status: $PLAN_VALIDATION_STATUS"
  echo "[INFO] Planned power profile: $PLANNED_POWER_PROFILE"
  echo "[INFO] Package groups:"
  printf '%s\n' "$PACKAGE_GROUP_SUMMARY" | sed 's/^/[INFO]   /'
  echo "[INFO] Already installed packages: ${#ALREADY_INSTALLED[@]}"
  echo "[INFO] Packages requested for installation: ${#NEWLY_REQUESTED[@]}"
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[DRY-RUN] Would install: %s\n' "${NEWLY_REQUESTED[*]:-none}"
    printf '[DRY-RUN] Would apply runtime power profile: %s\n' "$PLANNED_POWER_PROFILE"
  fi
}

install_base_packages() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Skipping apt-get update/install."
    return
  fi

  echo "[INFO] Updating apt package index..."
  sudo apt-get update

  echo "[INFO] Installing Ubuntu baseline package groups from plan..."
  sudo apt-get install -y "${BASE_PACKAGES[@]}"
}

configure_runtime_defaults() {
  echo "[INFO] Applying runtime defaults from baseline plan."

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Skipping runtime configuration."
    return
  fi

  if command -v powerprofilesctl >/dev/null 2>&1; then
    sudo powerprofilesctl set "$PLANNED_POWER_PROFILE" || true
  fi

  if command -v sensors-detect >/dev/null 2>&1; then
    echo "[INFO] lm-sensors installed. Run 'sudo sensors-detect' manually if sensor output is incomplete."
  fi
}

validate_amd_visibility() {
  echo "[INFO] AMD baseline visibility checks"

  printf '\n[CHECK] Kernel\n'
  uname -r || true

  printf '\n[CHECK] AMD GPU PCI devices\n'
  lspci -nnk 2>/dev/null | grep -Ei -A3 'vga|display|3d|amd|radeon' || true

  printf '\n[CHECK] amdgpu module\n'
  lsmod 2>/dev/null | grep amdgpu || echo "[WARN] amdgpu module not visible in lsmod"

  printf '\n[CHECK] Vulkan\n'
  vulkaninfo --summary 2>/dev/null || echo "[WARN] vulkaninfo failed or no Vulkan device visible"

  printf '\n[CHECK] OpenCL\n'
  clinfo 2>/dev/null | head -n 80 || echo "[WARN] clinfo failed or no OpenCL platform visible"

  printf '\n[CHECK] NPU / XDNA\n'
  lsmod 2>/dev/null | grep -Ei 'amdxdna|xrt|xdna' || echo "[WARN] XDNA/NPU kernel module not visible yet"
  find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null || true
}

write_postcheck_json() {
  local kernel gpu_pci amdgpu vulkan opencl npu_module npu_device post_status
  kernel="$(uname -r 2>/dev/null || true)"
  gpu_pci="$(lspci -nnk 2>/dev/null | grep -Ei -A3 'vga|display|3d|amd|radeon' || true)"
  amdgpu="$(lsmod 2>/dev/null | grep amdgpu || true)"
  vulkan="$(vulkaninfo --summary 2>/dev/null || true)"
  opencl="$(clinfo 2>/dev/null | head -n 80 || true)"
  npu_module="$(lsmod 2>/dev/null | grep -Ei 'amdxdna|xrt|xdna' || true)"
  npu_device="$(find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null || true)"
  post_status="PASS"
  if [[ -z "$amdgpu" || -z "$vulkan" || -z "$opencl" ]]; then
    post_status="WARN"
  fi
  if [[ "$PLAN_EXPECTS_NPU" == "true" && -z "$npu_module$npu_device" ]]; then
    post_status="WARN"
  fi

  export kernel gpu_pci amdgpu vulkan opencl npu_module npu_device post_status DRY_RUN PLAN_EXPECTS_NPU
  export ALREADY_INSTALLED_TEXT="$(printf '%s\n' "${ALREADY_INSTALLED[@]}")"
  export REQUESTED_TEXT="$(printf '%s\n' "${NEWLY_REQUESTED[@]}")"
  python3 - <<'PY' > "$BASELINE_POSTCHECK_JSON"
import json, os

def env(name): return os.environ.get(name, "")
def lines(name): return [x for x in env(name).splitlines() if x.strip()]
npu_visible = bool(env("npu_module") or env("npu_device"))
expects_npu = env("PLAN_EXPECTS_NPU") == "true"
npu_status = "PASS" if npu_visible else ("WARN" if expects_npu else "SKIP")
result={
  "status": env("post_status"),
  "dry_run": env("DRY_RUN") == "true",
  "checks": {
    "kernel": {"status": "PASS" if env("kernel") else "WARN", "value": env("kernel")},
    "amd_gpu_pci": {"status": "PASS" if env("gpu_pci") else "WARN", "text": env("gpu_pci")},
    "amdgpu_module": {"status": "PASS" if env("amdgpu") else "WARN", "text": env("amdgpu")},
    "vulkan": {"status": "PASS" if env("vulkan") else "WARN", "text": env("vulkan")},
    "opencl": {"status": "PASS" if env("opencl") else "WARN", "text": env("opencl")},
    "npu_xdna": {"status": npu_status, "expected": expects_npu, "module_text": env("npu_module"), "device_text": env("npu_device")},
  },
  "packages": {"already_installed_before_apply": lines("ALREADY_INSTALLED_TEXT"), "requested_for_install": lines("REQUESTED_TEXT")},
}
print(json.dumps(result, indent=2))
PY
}

write_baseline_report() {
  mkdir -p "$LATEST_DIR"

  {
    echo "AMD Baseline Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Dry run: $DRY_RUN"
    echo "Plan status: $PLAN_STATUS"
    echo "Timestamp: $(date -Is)"
    echo
    echo "Package groups:"
    printf '%s\n' "$PACKAGE_GROUP_SUMMARY"
    echo
    echo "Already installed before apply:"
    printf '%s\n' "${ALREADY_INSTALLED[@]:-none}"
    echo
    echo "Requested for installation:"
    printf '%s\n' "${NEWLY_REQUESTED[@]:-none}"
    echo
    echo "Hardware JSON: $HARDWARE_JSON"
    echo "Baseline plan: $BASELINE_PLAN_JSON"
    echo "Postcheck JSON: $BASELINE_POSTCHECK_JSON"
  } > "$LATEST_DIR/amd-baseline-status.txt"

  {
    echo "# Baseline Apply Summary"
    echo
    echo "- Status: $([[ "$DRY_RUN" == "true" ]] && echo DRY-RUN || echo APPLIED)"
    echo "- Plan status: $PLAN_STATUS"
    echo "- Validation status: $PLAN_VALIDATION_STATUS"
    echo "- Planned power profile: $PLANNED_POWER_PROFILE"
    echo "- Already installed before apply: ${#ALREADY_INSTALLED[@]}"
    echo "- Requested for installation: ${#NEWLY_REQUESTED[@]}"
    echo
    echo "## Package groups"
    printf '%s\n' "$PACKAGE_GROUP_SUMMARY" | sed 's/^/- /'
  } > "$BASELINE_APPLY_SUMMARY"

  {
    echo "$([[ "$DRY_RUN" == "true" ]] && echo DRY-RUN || echo APPLIED)"
    echo "Plan status: $PLAN_STATUS"
    echo "Validation status: $PLAN_VALIDATION_STATUS"
    echo "Postcheck: $BASELINE_POSTCHECK_JSON"
  } > "$BASELINE_APPLY_STATUS"

  echo "[INFO] Wrote $LATEST_DIR/amd-baseline-status.txt"
  echo "[INFO] Wrote $BASELINE_APPLY_STATUS"
  echo "[INFO] Wrote $BASELINE_APPLY_SUMMARY"
  echo "[INFO] Wrote $BASELINE_POSTCHECK_JSON"
}

main() {
  echo "[INFO] Phase 3: Ubuntu baseline apply"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"
  echo "[INFO] Dry run: $DRY_RUN"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] System persistence is not implemented in Phase 3. Use --persistence=runtime."
    exit 2
  fi

  if [[ "$MODE" == "aggressive" ]]; then
    echo "[WARN] Aggressive mode requested, but Phase 3 applies only reversible baseline setup from the plan."
  fi

  load_baseline_plan
  require_phase2_pass
  classify_packages
  print_plan_summary
  require_root_privilege
  install_base_packages
  configure_runtime_defaults
  validate_amd_visibility
  write_postcheck_json
  write_baseline_report

  echo "[INFO] Phase 3 complete. Ubuntu baseline plan handled."
}

main "$@"
