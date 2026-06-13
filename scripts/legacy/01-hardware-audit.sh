#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$PROJECT_ROOT/reports/${TIMESTAMP}"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
main() {
  mkdir -p "$OUT_DIR" "$LATEST_DIR"

  local JSON_FILE TXT_FILE SUMMARY_FILE LATEST_JSON LATEST_TXT LATEST_SUMMARY
  JSON_FILE="$OUT_DIR/hardware-inventory.json"
  TXT_FILE="$OUT_DIR/hardware-audit.txt"
  SUMMARY_FILE="$OUT_DIR/hardware-summary.md"
  LATEST_JSON="$LATEST_DIR/hardware-inventory.json"
  LATEST_TXT="$LATEST_DIR/hardware-audit.txt"
  LATEST_SUMMARY="$LATEST_DIR/hardware-summary.md"

  CPU_MODEL="$(detect_cpu_model)"
  CPU_VENDOR="$(detect_cpu_vendor)"
  CPU_CORES="$(detect_cpu_logical)"
  CPU_GOVERNORS="$(detect_cpu_governors)"
  CPU_GOVERNOR="$(detect_cpu_current_governor)"
  KERNEL="$(detect_kernel)"
  OS_DESCRIPTION="$(detect_os_description)"
  OS_ID="$(detect_os_id)"
  OS_VERSION_ID="$(detect_os_version_id)"
  OS_CODENAME="$(detect_os_codename)"
  PCI_TEXT="$(detect_pci_text)"
  GPU_TEXT="$(printf '%s\n' "$PCI_TEXT" | grep -Ei 'vga|display|3d|radeon|amd/ati' || true)"
  GPU_ARCH_DETECTED="$(detect_gpu_arch "$GPU_TEXT")"
  AMDGPU_MODULE="$(detect_amdgpu_module)"
  VULKAN_SUMMARY="$(detect_vulkan_summary)"
  OPENCL_SUMMARY="$(detect_opencl_summary)"
  NPU_TEXT="$(detect_npu_module_text)"
  NPU_DEVICE_TEXT="$(detect_npu_device_text)"
  NPU_PRESENT="$(detect_npu_present "$NPU_TEXT" "$NPU_DEVICE_TEXT")"
  MEMORY_TOTAL="$(detect_memory_total)"
  MEMORY_TOTAL_KIB="$(detect_memory_total_kib)"
  STORAGE_TEXT="$(detect_storage_text)"
  NVME_TEXT="$(detect_nvme_text)"
  BIOS_VERSION="$(detect_bios_version)"
  SYSTEM_PRODUCT="$(detect_system_product)"
  SYSTEM_VENDOR="$(detect_system_vendor)"
  FWUPD_DEVICES="$(detect_fwupd_devices)"
  POWER_PROFILES="$(detect_powerprofiles)"
  MISSING_TOOLS="$(collect_missing_tools)"

  {
    echo "=== SYSTEM ==="
    uname -a || true
    lsb_release -a 2>/dev/null || true
    printf '\nSystem vendor: %s\n' "${SYSTEM_VENDOR:-unknown}"
    printf 'System product: %s\n' "${SYSTEM_PRODUCT:-unknown}"
    printf 'BIOS version: %s\n' "${BIOS_VERSION:-unknown}"

    printf '\n=== CPU ===\n'
    lscpu || true
    printf '\nAvailable governors: %s\n' "${CPU_GOVERNORS:-unknown}"
    printf 'Current governor: %s\n' "${CPU_GOVERNOR:-unknown}"

    printf '\n=== MEMORY ===\n'
    free -h || true

    printf '\n=== PCI ===\n'
    printf '%s\n' "$PCI_TEXT"

    printf '\n=== STORAGE ===\n'
    lsblk -o NAME,MODEL,SIZE,TYPE || true

    printf '\n=== GPU MODULE ===\n'
    printf '%s\n' "${AMDGPU_MODULE:-[WARN] amdgpu module not visible}"

    printf '\n=== VULKAN ===\n'
    printf '%s\n' "${VULKAN_SUMMARY:-[WARN] vulkaninfo unavailable or no Vulkan device visible}"

    printf '\n=== OPENCL ===\n'
    printf '%s\n' "${OPENCL_SUMMARY:-[WARN] clinfo unavailable or no OpenCL platform visible}"

    printf '\n=== NPU (XDNA) ===\n'
    printf '%s\n' "${NPU_TEXT:-[WARN] XDNA/NPU module not visible}"
    printf '%s\n' "${NPU_DEVICE_TEXT:-[WARN] XDNA/NPU device node not visible}"

    printf '\n=== POWER PROFILES ===\n'
    printf '%s\n' "${POWER_PROFILES:-[WARN] powerprofilesctl unavailable}"

    printf '\n=== FIRMWARE ===\n'
    printf '%s\n' "${FWUPD_DEVICES:-[WARN] fwupdmgr unavailable or returned no devices}"

    printf '\n=== MISSING DETECTION TOOLS ===\n'
    printf '%s\n' "${MISSING_TOOLS:-none}"
  } | tee "$TXT_FILE"

  export PROFILE MODE PERSISTENCE TIMESTAMP TARGET_UBUNTU_VERSION TARGET_UBUNTU_CODENAME TARGET_UBUNTU_DESCRIPTION SYSTEM_VENDOR SYSTEM_PRODUCT BIOS_VERSION \
    OS_DESCRIPTION OS_ID OS_VERSION_ID OS_CODENAME KERNEL CPU_VENDOR CPU_MODEL CPU_CORES \
    CPU_GOVERNORS CPU_GOVERNOR GPU_TEXT GPU_ARCH_DETECTED AMDGPU_MODULE VULKAN_SUMMARY \
    OPENCL_SUMMARY NPU_PRESENT NPU_TEXT NPU_DEVICE_TEXT MEMORY_TOTAL MEMORY_TOTAL_KIB \
    STORAGE_TEXT NVME_TEXT FWUPD_DEVICES POWER_PROFILES MISSING_TOOLS
  python3 - <<'PY' > "$JSON_FILE"
import json
import os


def env(name, default=""):
    return os.environ.get(name, default)


def lines(value):
    return [line for line in value.splitlines() if line.strip()]


def int_or_zero(value):
    value = (value or "").strip()
    return int(value) if value.isdigit() else 0


data = {
  "profile": {"id": env("PROFILE"), "mode": env("MODE"), "persistence": env("PERSISTENCE")},
  "timestamp": env("TIMESTAMP"),
  "system": {
    "vendor": env("SYSTEM_VENDOR"),
    "product": env("SYSTEM_PRODUCT"),
    "bios_version": env("BIOS_VERSION"),
    "os": {"description": env("OS_DESCRIPTION"), "id": env("OS_ID"), "version_id": env("OS_VERSION_ID"), "codename": env("OS_CODENAME"), "target": env("TARGET_UBUNTU_DESCRIPTION")},
    "kernel": env("KERNEL"),
  },
  "cpu": {
    "vendor": env("CPU_VENDOR"),
    "model": env("CPU_MODEL"),
    "logical_cpus": int_or_zero(env("CPU_CORES")),
    "available_governors": env("CPU_GOVERNORS"),
    "current_governor": env("CPU_GOVERNOR"),
  },
  "gpu": {
    "pci_text": env("GPU_TEXT"),
    "arch": env("GPU_ARCH_DETECTED"),
    "amdgpu_module_loaded": bool(env("AMDGPU_MODULE")),
    "amdgpu_module_text": env("AMDGPU_MODULE"),
    "vulkan_visible": bool(env("VULKAN_SUMMARY")),
    "opencl_visible": bool(env("OPENCL_SUMMARY")),
  },
  "npu": {"present": env("NPU_PRESENT") == "true", "module_text": env("NPU_TEXT"), "device_text": env("NPU_DEVICE_TEXT")},
  "memory": {"total": env("MEMORY_TOTAL"), "total_kib": int_or_zero(env("MEMORY_TOTAL_KIB"))},
  "storage": {"devices_text": env("STORAGE_TEXT"), "nvme_text": env("NVME_TEXT"), "nvme_detected": bool(env("NVME_TEXT"))},
  "firmware": {"fwupd_available": bool(env("FWUPD_DEVICES")), "devices_text": env("FWUPD_DEVICES")},
  "power": {"powerprofilesctl_available": bool(env("POWER_PROFILES")), "profiles_text": env("POWER_PROFILES")},
  "tools": {"missing": lines(env("MISSING_TOOLS"))},
}
print(json.dumps(data, indent=2))
PY
  {
    echo "# Hardware Inventory Summary"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Timestamp: $TIMESTAMP"
    echo
    echo "## Key facts"
    echo "- System: ${SYSTEM_VENDOR:-unknown} ${SYSTEM_PRODUCT:-unknown}"
    echo "- OS: ${OS_DESCRIPTION:-unknown} (${OS_CODENAME:-unknown})"
    echo "- Ubuntu target: $TARGET_UBUNTU_DESCRIPTION"
    echo "- Kernel: ${KERNEL:-unknown}"
    echo "- CPU: ${CPU_MODEL:-unknown}"
    echo "- GPU architecture: $GPU_ARCH_DETECTED"
    echo "- NPU present: $NPU_PRESENT"
    echo "- Memory: ${MEMORY_TOTAL:-unknown}"
    echo "- NVMe detected: $([[ -n "$NVME_TEXT" ]] && echo true || echo false)"
    echo "- Missing detection tools: ${MISSING_TOOLS//$'\n'/, }"
  } > "$SUMMARY_FILE"

  cp "$JSON_FILE" "$LATEST_JSON"
  cp "$TXT_FILE" "$LATEST_TXT"
  cp "$SUMMARY_FILE" "$LATEST_SUMMARY"

  # Backward-compatible alias for older phase consumers.
  cp "$JSON_FILE" "$LATEST_DIR/hardware.json"

  echo "[INFO] Audit complete: $OUT_DIR"
  echo "[INFO] Wrote $LATEST_JSON"
  echo "[INFO] Wrote $LATEST_SUMMARY"
}

main "$@"
