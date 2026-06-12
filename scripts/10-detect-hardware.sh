#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 1 script: Hardware detection (Radeon 890M, XDNA2 NPU, CPU, memory, storage, etc.)
# Writes rich inventory artifacts for downstream Tier 1 phases and the tier gate.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

LATEST_DIR="$PROJECT_ROOT/reports/latest"
mkdir -p "$LATEST_DIR"

main() {
  echo "[INFO] Tier 1 / 10-detect-hardware.sh"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE"

  CPU_MODEL="$(detect_cpu_model)"
  CPU_VENDOR="$(detect_cpu_vendor)"
  CPU_CORES="$(detect_cpu_logical)"
  KERNEL="$(detect_kernel)"
  OS_DESCRIPTION="$(detect_os_description)"
  OS_ID="$(detect_os_id)"
  OS_VERSION_ID="$(detect_os_version_id)"
  OS_CODENAME="$(detect_os_codename)"

  GPU_TEXT="$(detect_gpu_text)"
  GPU_ARCH="$(detect_gpu_arch "$GPU_TEXT")"
  AMDGPU_MODULE="$(detect_amdgpu_module)"

  NPU_MODULE="$(detect_npu_module_text)"
  NPU_DEVICE="$(detect_npu_device_text)"
  NPU_PRESENT="$(detect_npu_present "$NPU_MODULE" "$NPU_DEVICE")"

  MEMORY_TOTAL="$(detect_memory_total)"
  STORAGE_TEXT="$(detect_storage_text)"
  NVME_TEXT="$(detect_nvme_text)"
  BIOS_VERSION="$(detect_bios_version)"
  SYSTEM_PRODUCT="$(detect_system_product)"
  SYSTEM_VENDOR="$(detect_system_vendor)"

  MISSING_TOOLS="$(collect_missing_tools)"

  # Structured JSON inventory (Tier 1 canonical)
  cat > "$LATEST_DIR/tier1-hardware.json" <<EOF
{
  "tier": 1,
  "phase": "detect-hardware",
  "timestamp": "$(date -Is)",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "system": {
    "vendor": "${SYSTEM_VENDOR:-unknown}",
    "product": "${SYSTEM_PRODUCT:-unknown}",
    "bios_version": "${BIOS_VERSION:-unknown}",
    "os": "$OS_DESCRIPTION",
    "kernel": "$KERNEL"
  },
  "cpu": {
    "model": "$CPU_MODEL",
    "vendor": "$CPU_VENDOR",
    "logical_cores": ${CPU_CORES:-0}
  },
  "gpu": {
    "text": "$GPU_TEXT",
    "arch": "$GPU_ARCH",
    "amdgpu_module": "${AMDGPU_MODULE:+loaded}"
  },
  "npu": {
    "present": $NPU_PRESENT,
    "module_text": "$NPU_MODULE",
    "device_text": "$NPU_DEVICE"
  },
  "memory": { "total": "$MEMORY_TOTAL" },
  "storage": { "summary": "$STORAGE_TEXT", "nvme": "$NVME_TEXT" },
  "tools": { "missing": "$(echo "$MISSING_TOOLS" | tr '\n' ',' | sed 's/,$//')" }
}
EOF

  # Human readable summary
  {
    echo "# Tier 1 Hardware Detection"
    echo
    echo "**Profile:** $PROFILE | **Mode:** $MODE | **Persistence:** $PERSISTENCE"
    echo
    echo "## System"
    echo "- Product: ${SYSTEM_VENDOR:-unknown} ${SYSTEM_PRODUCT:-unknown}"
    echo "- BIOS: ${BIOS_VERSION:-unknown}"
    echo "- OS: $OS_DESCRIPTION ($OS_VERSION_ID / $OS_CODENAME)"
    echo "- Kernel: $KERNEL"
    echo
    echo "## CPU"
    echo "- Model: $CPU_MODEL"
    echo "- Vendor: $CPU_VENDOR"
    echo "- Logical cores: ${CPU_CORES:-unknown}"
    echo
    echo "## GPU (iGPU)"
    echo "- Detected: $GPU_TEXT"
    echo "- Architecture: $GPU_ARCH"
    echo "- amdgpu module: ${AMDGPU_MODULE:+loaded (ok)}"
    echo
    echo "## NPU (XDNA2)"
    echo "- Present: $NPU_PRESENT"
    echo "- Module: ${NPU_MODULE:-none detected}"
    echo "- Devices: ${NPU_DEVICE:-none detected}"
    echo
    echo "## Memory / Storage"
    echo "- Memory: $MEMORY_TOTAL"
    echo "- Storage: ${STORAGE_TEXT:-unknown}"
    echo "- NVMe: ${NVME_TEXT:+present}"
    echo
    echo "## Missing tools (best-effort detection)"
    echo "${MISSING_TOOLS:-none}"
  } > "$LATEST_DIR/tier1-hardware.md"

  # Also keep the legacy artifact names for compatibility with existing reports consumers
  cp "$LATEST_DIR/tier1-hardware.json" "$LATEST_DIR/hardware-inventory.json" 2>/dev/null || true
  cp "$LATEST_DIR/tier1-hardware.md" "$LATEST_DIR/hardware-summary.md" 2>/dev/null || true

  echo "[INFO] Wrote tier1-hardware.json and tier1-hardware.md"
  echo "[INFO] 10-detect-hardware.sh complete."
}

main "$@"
