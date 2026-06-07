#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_FILE="$PROJECT_ROOT/config/profiles/${PROFILE}.env"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
INVENTORY_JSON="$LATEST_DIR/hardware-inventory.json"
HARDWARE_JSON="$LATEST_DIR/hardware.json"
RECOMMENDATIONS_MD="$LATEST_DIR/recommendations.md"
VALIDATION_STATUS="$LATEST_DIR/validation-status.txt"
BASELINE_PLAN_JSON="$LATEST_DIR/baseline-plan.json"
BASELINE_PLAN_MD="$LATEST_DIR/baseline-plan.md"

if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "[ERROR] Unknown profile: $PROFILE"
  echo "[ERROR] Missing profile file: $PROFILE_FILE"
  exit 2
fi

# shellcheck source=/dev/null
source "$PROFILE_FILE"
# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

mkdir -p "$LATEST_DIR"

status="PASS"
failures=()
warnings=()
opportunities=()
skips=()
recommendations=()
rule_ids=()
rule_statuses=()
rule_categories=()
rule_messages=()

add_rule() {
  rule_ids+=("$1")
  rule_statuses+=("$2")
  rule_categories+=("$3")
  rule_messages+=("$4")
}

mark_warn() {
  if [[ "$status" == "PASS" ]]; then
    status="WARN"
  fi
  warnings+=("$1")
}

mark_fail() {
  status="FAIL"
  failures+=("$1")
}

CPU_MODEL="$(detect_cpu_model)"
CPU_VENDOR="$(detect_cpu_vendor)"
CPU_CORES="$(detect_cpu_logical)"
KERNEL="$(detect_kernel)"
OS_DESCRIPTION="$(detect_os_description)"
OS_ID="$(detect_os_id)"
OS_VERSION_ID="$(detect_os_version_id)"
OS_CODENAME="$(detect_os_codename)"
GPU_TEXT="$(detect_gpu_text)"
GPU_ARCH_DETECTED="$(detect_gpu_arch "$GPU_TEXT")"
AMDGPU_MODULE="$(detect_amdgpu_module)"
VULKAN_SUMMARY="$(detect_vulkan_summary)"
OPENCL_SUMMARY="$(detect_opencl_summary)"
NPU_TEXT="$(detect_npu_module_text)"
NPU_DEVICE_TEXT="$(detect_npu_device_text)"
NPU_PRESENT="$(detect_npu_present "$NPU_TEXT" "$NPU_DEVICE_TEXT")"
MEMORY_TOTAL="$(detect_memory_total)"
STORAGE_TEXT="$(detect_storage_text)"
BIOS_VERSION="$(detect_bios_version)"
SYSTEM_PRODUCT="$(detect_system_product)"
SYSTEM_VENDOR="$(detect_system_vendor)"
POWER_PROFILES="$(detect_powerprofiles)"
MISSING_TOOLS="$(collect_missing_tools)"

if [[ "${PROFILE_VALIDATION:-strict}" == "strict" ]]; then
  if [[ -n "${EXPECTED_CPU:-}" && "$CPU_MODEL" != *"$EXPECTED_CPU"* ]]; then
    msg="CPU mismatch: expected '$EXPECTED_CPU', detected '${CPU_MODEL:-unknown}'"
    mark_fail "$msg"
    add_rule "cpu.expected_model" "FAIL" "FAIL" "$msg"
  else
    add_rule "cpu.expected_model" "PASS" "PASS" "CPU matches expected profile model."
  fi

  if [[ -n "${EXPECTED_GPU_ARCH:-}" && "$GPU_ARCH_DETECTED" != "$EXPECTED_GPU_ARCH" ]]; then
    msg="GPU architecture mismatch: expected '$EXPECTED_GPU_ARCH', detected '$GPU_ARCH_DETECTED'"
    mark_fail "$msg"
    add_rule "gpu.expected_arch" "FAIL" "FAIL" "$msg"
  else
    add_rule "gpu.expected_arch" "PASS" "PASS" "GPU architecture matches expected profile."
  fi

  if [[ -n "${EXPECTED_NPU_FAMILY:-}" && "$NPU_PRESENT" != "true" ]]; then
    msg="NPU not detected: expected '${EXPECTED_NPU_FAMILY}'"
    mark_fail "$msg"
    add_rule "npu.expected_family" "FAIL" "FAIL" "$msg"
  else
    add_rule "npu.expected_family" "PASS" "PASS" "NPU module or device visibility matches strict profile expectations."
  fi

  if [[ "${PROFILE_ID:-}" == "ai370" && -n "$SYSTEM_PRODUCT" && "$SYSTEM_PRODUCT" != *"AI370"* && "$SYSTEM_PRODUCT" != *"EliteMini"* ]]; then
    msg="System product does not clearly identify as EliteMini AI370: '${SYSTEM_PRODUCT}'"
    mark_warn "$msg"
    add_rule "system.product_identity" "WARN" "WARN" "$msg"
  else
    add_rule "system.product_identity" "PASS" "PASS" "System product identity is compatible with the selected profile or unavailable."
  fi
else
  if [[ "$CPU_MODEL" != *"Ryzen AI"* ]]; then
    msg="CPU does not clearly identify as Ryzen AI: '${CPU_MODEL:-unknown}'"
    mark_warn "$msg"
    add_rule "cpu.ryzen_ai_family" "WARN" "WARN" "$msg"
  else
    add_rule "cpu.ryzen_ai_family" "PASS" "PASS" "CPU identifies as Ryzen AI."
  fi

  if [[ "$CPU_VENDOR" != *"AuthenticAMD"* ]]; then
    msg="CPU vendor is not clearly AMD: '${CPU_VENDOR:-unknown}'"
    mark_warn "$msg"
    add_rule "cpu.amd_vendor" "WARN" "WARN" "$msg"
  else
    add_rule "cpu.amd_vendor" "PASS" "PASS" "CPU vendor identifies as AMD."
  fi

  if [[ "$NPU_PRESENT" != "true" ]]; then
    msg="NPU device/module not detected; Ryzen AI NPU tooling may be unavailable"
    mark_warn "$msg"
    add_rule "npu.visibility" "WARN" "WARN" "$msg"
  else
    add_rule "npu.visibility" "PASS" "PASS" "NPU module or device is visible."
  fi
fi

if [[ "$OS_ID" != "ubuntu" ]]; then
  msg="Operating system is not clearly Ubuntu: ${OS_DESCRIPTION:-unknown}"
  mark_warn "$msg"
  add_rule "ubuntu.distribution" "WARN" "WARN" "$msg"
else
  add_rule "ubuntu.distribution" "PASS" "PASS" "Ubuntu distribution detected."
fi

if [[ -z "$POWER_PROFILES" ]]; then
  msg="powerprofilesctl is missing or unavailable; install baseline packages before applying power profile defaults."
  opportunities+=("$msg")
  add_rule "power.profiles_control" "OPPORTUNITY" "OPPORTUNITY" "$msg"
else
  add_rule "power.profiles_control" "PASS" "PASS" "Power profile control is available."
fi

if [[ -z "$AMDGPU_MODULE" ]]; then
  msg="amdgpu module is not currently visible; baseline may still install diagnostics but GPU acceleration remains unvalidated."
  mark_warn "$msg"
  add_rule "gpu.amdgpu_module" "WARN" "WARN" "$msg"
else
  add_rule "gpu.amdgpu_module" "PASS" "PASS" "amdgpu kernel module is visible."
fi

if [[ -z "$VULKAN_SUMMARY" ]]; then
  msg="Vulkan visibility is missing before baseline install; mesa/vulkan tools are planned for diagnostics."
  opportunities+=("$msg")
  add_rule "gpu.vulkan_visibility" "OPPORTUNITY" "OPPORTUNITY" "$msg"
else
  add_rule "gpu.vulkan_visibility" "PASS" "PASS" "Vulkan reports at least one visible device or loader summary."
fi

if [[ -z "$OPENCL_SUMMARY" ]]; then
  msg="OpenCL visibility is missing before baseline install; clinfo is planned for diagnostics."
  opportunities+=("$msg")
  add_rule "gpu.opencl_visibility" "OPPORTUNITY" "OPPORTUNITY" "$msg"
else
  add_rule "gpu.opencl_visibility" "PASS" "PASS" "OpenCL reports a visible platform."
fi

skips+=("ROCm, XRT, Ryzen AI runtime, and vendor binary package installation are skipped in the Ubuntu baseline phase.")
add_rule "acceleration.vendor_runtimes" "SKIP" "SKIP" "GPU/NPU vendor runtime installation is intentionally outside baseline apply."

if [[ "$status" == "PASS" ]]; then
  recommendations+=("Proceed to baseline-apply for the validated Ubuntu baseline setup.")
elif [[ "$status" == "WARN" ]]; then
  recommendations+=("Review warnings before baseline-apply; safe runtime-only baseline may continue.")
else
  recommendations+=("Do not apply the baseline until hardware/profile mismatches are resolved.")
fi
recommendations+=("Run ai-runtime separately after baseline validation if local AI packages are needed.")

export PROFILE MODE PERSISTENCE PROFILE_ID PROFILE_NAME PROFILE_VALIDATION EXPECTED_CPU EXPECTED_GPU_ARCH EXPECTED_NPU_FAMILY
export status CPU_MODEL CPU_VENDOR CPU_CORES KERNEL OS_DESCRIPTION OS_ID OS_VERSION_ID OS_CODENAME GPU_TEXT GPU_ARCH_DETECTED AMDGPU_MODULE VULKAN_SUMMARY OPENCL_SUMMARY NPU_TEXT NPU_DEVICE_TEXT NPU_PRESENT MEMORY_TOTAL STORAGE_TEXT BIOS_VERSION SYSTEM_PRODUCT SYSTEM_VENDOR POWER_PROFILES MISSING_TOOLS INVENTORY_JSON
export RULE_IDS="$(printf '%s\n' "${rule_ids[@]}")"
export RULE_STATUSES="$(printf '%s\n' "${rule_statuses[@]}")"
export RULE_CATEGORIES="$(printf '%s\n' "${rule_categories[@]}")"
export RULE_MESSAGES="$(printf '%s\n' "${rule_messages[@]}")"
export FAILURES="$(printf '%s\n' "${failures[@]}")"
export WARNINGS="$(printf '%s\n' "${warnings[@]}")"
export OPPORTUNITIES="$(printf '%s\n' "${opportunities[@]}")"
export SKIPS="$(printf '%s\n' "${skips[@]}")"
export RECOMMENDATIONS="$(printf '%s\n' "${recommendations[@]}")"

python3 - <<'PY' > "$HARDWARE_JSON"
import json, os

def env(name): return os.environ.get(name, "")
def lines(name): return [x for x in env(name).splitlines() if x.strip()]
def int0(value):
    value=(value or "").strip()
    return int(value) if value.isdigit() else 0
rules=[]
ids=lines("RULE_IDS"); statuses=lines("RULE_STATUSES"); cats=lines("RULE_CATEGORIES"); msgs=lines("RULE_MESSAGES")
for i, rid in enumerate(ids):
    rules.append({"id": rid, "status": statuses[i] if i < len(statuses) else "UNKNOWN", "category": cats[i] if i < len(cats) else "UNKNOWN", "message": msgs[i] if i < len(msgs) else ""})
data={
  "profile": {"id": env("PROFILE_ID") or env("PROFILE"), "name": env("PROFILE_NAME") or "unknown", "validation": env("PROFILE_VALIDATION") or "strict", "mode": env("MODE"), "persistence": env("PERSISTENCE")},
  "validation": {"status": env("status"), "rules": rules, "failures": lines("FAILURES"), "warnings": lines("WARNINGS"), "opportunities": lines("OPPORTUNITIES"), "skips": lines("SKIPS")},
  "system": {"vendor": env("SYSTEM_VENDOR"), "product": env("SYSTEM_PRODUCT"), "bios_version": env("BIOS_VERSION"), "os": env("OS_DESCRIPTION"), "os_id": env("OS_ID"), "os_version_id": env("OS_VERSION_ID"), "os_codename": env("OS_CODENAME"), "kernel": env("KERNEL")},
  "cpu": {"vendor": env("CPU_VENDOR"), "model": env("CPU_MODEL"), "logical_cpus": int0(env("CPU_CORES"))},
  "gpu": {"detected_text": env("GPU_TEXT"), "arch": env("GPU_ARCH_DETECTED"), "amdgpu_module_loaded": bool(env("AMDGPU_MODULE")), "vulkan_visible": bool(env("VULKAN_SUMMARY")), "opencl_visible": bool(env("OPENCL_SUMMARY"))},
  "npu": {"present": env("NPU_PRESENT") == "true", "module_text": env("NPU_TEXT"), "device_text": env("NPU_DEVICE_TEXT")},
  "memory": {"total": env("MEMORY_TOTAL")},
  "storage": {"devices": env("STORAGE_TEXT")},
  "tools": {"missing": lines("MISSING_TOOLS")},
  "inventory": {"source": env("INVENTORY_JSON") if os.path.exists(env("INVENTORY_JSON")) else "not-generated"},
}
print(json.dumps(data, indent=2))
PY

python3 - <<'PY' > "$BASELINE_PLAN_JSON"
import json, os

def env(name): return os.environ.get(name, "")
def lines(name): return [x for x in env(name).splitlines() if x.strip()]
status = env("status")
plan_status = "blocked" if status == "FAIL" else ("warn-only" if status == "WARN" else "safe")
runtime_settings = {"power_profile": "balanced" if env("MODE") == "safe" else "performance", "cpu_boost": "auto", "gpu_power": "auto", "persistence": env("PERSISTENCE")}
package_groups = {
  "diagnostics": ["pciutils", "usbutils", "dmidecode", "lshw", "inxi", "jq", "lm-sensors"],
  "firmware": ["linux-firmware", "fwupd"],
  "graphics_visibility": ["mesa-utils", "vulkan-tools", "clinfo"],
  "storage_health": ["nvme-cli", "smartmontools"],
  "python_runtime": ["python3", "python3-venv", "python3-pip"],
  "build_tools": ["curl", "wget", "git", "build-essential", "ca-certificates", "gnupg", "software-properties-common", "apt-transport-https"],
}
all_packages=[]
for packages in package_groups.values():
    all_packages.extend(packages)
rules=[]
ids=lines("RULE_IDS"); statuses=lines("RULE_STATUSES"); cats=lines("RULE_CATEGORIES"); msgs=lines("RULE_MESSAGES")
for i, rid in enumerate(ids):
    rules.append({"id": rid, "status": statuses[i] if i < len(statuses) else "UNKNOWN", "category": cats[i] if i < len(cats) else "UNKNOWN", "message": msgs[i] if i < len(msgs) else ""})
plan={
  "schema_version": 1,
  "profile": env("PROFILE_ID") or env("PROFILE"),
  "mode": env("MODE"),
  "persistence": env("PERSISTENCE"),
  "plan_status": plan_status,
  "validation": {"status": status, "rules": rules, "failures": lines("FAILURES"), "warnings": lines("WARNINGS"), "opportunities": lines("OPPORTUNITIES"), "skips": lines("SKIPS")},
  "hardware": {"cpu": env("CPU_MODEL"), "gpu_arch": env("GPU_ARCH_DETECTED"), "npu_present": env("NPU_PRESENT") == "true", "kernel": env("KERNEL"), "ubuntu": env("OS_DESCRIPTION")},
  "baseline": {"package_groups": package_groups, "packages": all_packages, "runtime_settings": runtime_settings, "post_checks": ["kernel", "amd_gpu_pci", "amdgpu_module", "vulkan", "opencl", "npu_xdna"]},
  "blocked_actions": ["install_rocm", "install_xrt", "install_ryzen_ai_runtime", "install_vendor_binaries"],
  "recommendations": lines("RECOMMENDATIONS"),
}
print(json.dumps(plan, indent=2))
PY

{
  echo "$status"
  printf '%s\n' "${failures[@]:-}" | sed '/^$/d'
  printf '%s\n' "${warnings[@]:-}" | sed '/^$/d'
} > "$VALIDATION_STATUS"

{
  echo "# Hardware Validation Report"
  echo
  echo "Profile: ${PROFILE_NAME:-$PROFILE}"
  echo "Mode: $MODE"
  echo "Persistence: $PERSISTENCE"
  echo "Status: $status"
  echo
  echo "## Detected Hardware"
  echo
  echo "- System vendor: ${SYSTEM_VENDOR:-unknown}"
  echo "- System product: ${SYSTEM_PRODUCT:-unknown}"
  echo "- BIOS: ${BIOS_VERSION:-unknown}"
  echo "- OS: ${OS_DESCRIPTION:-unknown}"
  echo "- Kernel: ${KERNEL:-unknown}"
  echo "- CPU: ${CPU_MODEL:-unknown}"
  echo "- Logical CPUs: ${CPU_CORES:-unknown}"
  echo "- GPU architecture: $GPU_ARCH_DETECTED"
  echo "- NPU present: $NPU_PRESENT"
  echo "- Memory total: ${MEMORY_TOTAL:-unknown}"
  echo
  echo "## Validation Rules"
  for i in "${!rule_ids[@]}"; do
    echo "- ${rule_statuses[$i]} ${rule_ids[$i]}: ${rule_messages[$i]}"
  done
  echo
  if (( ${#failures[@]} > 0 )); then
    echo "## Failures"
    for reason in "${failures[@]}"; do echo "- $reason"; done
    echo
  fi
  if (( ${#warnings[@]} > 0 )); then
    echo "## Warnings"
    for warning in "${warnings[@]}"; do echo "- $warning"; done
    echo
  fi
  if (( ${#opportunities[@]} > 0 )); then
    echo "## Optimization Opportunities"
    for opportunity in "${opportunities[@]}"; do echo "- $opportunity"; done
    echo
  fi
  echo "## Recommendations"
  for rec in "${recommendations[@]}"; do echo "- $rec"; done
} > "$RECOMMENDATIONS_MD"

{
  echo "# Ubuntu Baseline Plan"
  echo
  echo "Plan status: $([[ "$status" == "FAIL" ]] && echo blocked || ([[ "$status" == "WARN" ]] && echo warn-only || echo safe))"
  echo "Validation status: $status"
  echo
  echo "## Package groups"
  echo "- diagnostics: pciutils usbutils dmidecode lshw inxi jq lm-sensors"
  echo "- firmware: linux-firmware fwupd"
  echo "- graphics_visibility: mesa-utils vulkan-tools clinfo"
  echo "- storage_health: nvme-cli smartmontools"
  echo "- python_runtime: python3 python3-venv python3-pip"
  echo "- build_tools: curl wget git build-essential ca-certificates gnupg software-properties-common apt-transport-https"
  echo
  echo "## Runtime settings"
  echo "- power_profile: $([[ "$MODE" == "safe" ]] && echo balanced || echo performance)"
  echo "- persistence: $PERSISTENCE"
  echo
  echo "## Post checks"
  echo "- kernel"
  echo "- AMD GPU PCI visibility"
  echo "- amdgpu module"
  echo "- Vulkan visibility"
  echo "- OpenCL visibility"
  echo "- NPU/XDNA visibility"
  echo
  echo "## Blocked baseline actions"
  echo "- ROCm installation"
  echo "- XRT installation"
  echo "- Ryzen AI runtime installation"
  echo "- Vendor binary package installation"
} > "$BASELINE_PLAN_MD"

echo "[INFO] Validation status: $status"
echo "[INFO] Wrote $HARDWARE_JSON"
echo "[INFO] Wrote $RECOMMENDATIONS_MD"
echo "[INFO] Wrote $VALIDATION_STATUS"
echo "[INFO] Wrote $BASELINE_PLAN_JSON"
echo "[INFO] Wrote $BASELINE_PLAN_MD"

if [[ "$status" == "FAIL" ]]; then
  exit 3
fi
