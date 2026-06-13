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
  MISSING_TOOLS_CSV="$(echo "$MISSING_TOOLS" | tr '\n' ',' | sed 's/,$//')"
  export PROFILE MODE PERSISTENCE SYSTEM_VENDOR SYSTEM_PRODUCT BIOS_VERSION OS_DESCRIPTION KERNEL CPU_MODEL CPU_VENDOR CPU_CORES GPU_TEXT GPU_ARCH AMDGPU_MODULE NPU_PRESENT NPU_MODULE NPU_DEVICE MEMORY_TOTAL STORAGE_TEXT NVME_TEXT MISSING_TOOLS_CSV
  python3 - <<'PY' > "$LATEST_DIR/tier1-hardware.json"
import json
import os
from datetime import datetime, UTC


def as_int(value: str, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


data = {
    "tier": 1,
    "phase": "detect-hardware",
    "timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
    "profile": os.environ.get("PROFILE", "unknown"),
    "mode": os.environ.get("MODE", "unknown"),
    "persistence": os.environ.get("PERSISTENCE", "unknown"),
    "system": {
        "vendor": os.environ.get("SYSTEM_VENDOR") or "unknown",
        "product": os.environ.get("SYSTEM_PRODUCT") or "unknown",
        "bios_version": os.environ.get("BIOS_VERSION") or "unknown",
        "os": os.environ.get("OS_DESCRIPTION", ""),
        "kernel": os.environ.get("KERNEL", ""),
    },
    "cpu": {
        "model": os.environ.get("CPU_MODEL", ""),
        "vendor": os.environ.get("CPU_VENDOR", ""),
        "logical_cores": as_int(os.environ.get("CPU_CORES", "0")),
    },
    "gpu": {
        "text": os.environ.get("GPU_TEXT", ""),
        "arch": os.environ.get("GPU_ARCH", ""),
        "amdgpu_module": "loaded" if os.environ.get("AMDGPU_MODULE", "") else "",
    },
    "npu": {
        "present": os.environ.get("NPU_PRESENT", "false").lower() == "true",
        "module_text": os.environ.get("NPU_MODULE", ""),
        "device_text": os.environ.get("NPU_DEVICE", ""),
    },
    "memory": {"total": os.environ.get("MEMORY_TOTAL", "")},
    "storage": {
        "summary": os.environ.get("STORAGE_TEXT", ""),
        "nvme": os.environ.get("NVME_TEXT", ""),
    },
    "tools": {"missing": os.environ.get("MISSING_TOOLS_CSV", "")},
}

print(json.dumps(data, indent=2))
PY

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
