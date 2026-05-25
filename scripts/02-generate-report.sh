#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_FILE="$PROJECT_ROOT/config/profiles/${PROFILE}.env"
REPORT_ROOT="$PROJECT_ROOT/reports"
LATEST_DIR="$REPORT_ROOT/latest"

if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "[ERROR] Unknown profile: $PROFILE"
  echo "[ERROR] Missing profile file: $PROFILE_FILE"
  exit 2
fi

# shellcheck source=/dev/null
source "$PROFILE_FILE"

mkdir -p "$LATEST_DIR"

HARDWARE_JSON="$LATEST_DIR/hardware.json"
RECOMMENDATIONS_MD="$LATEST_DIR/recommendations.md"
VALIDATION_STATUS="$LATEST_DIR/validation-status.txt"

status="PASS"
reasons=()
warnings=()
recommendations=()

command_exists() { command -v "$1" >/dev/null 2>&1; }

read_cmd() {
  local cmd="$1"
  if command_exists "$cmd"; then
    "$cmd" 2>/dev/null || true
  fi
}

CPU_MODEL="$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
CPU_VENDOR="$(lscpu 2>/dev/null | awk -F: '/Vendor ID/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
CPU_CORES="$(lscpu 2>/dev/null | awk -F: '/^CPU\(s\)/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
KERNEL="$(uname -r 2>/dev/null || true)"
OS_DESCRIPTION="$(lsb_release -ds 2>/dev/null || { . /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}"; })"

PCI_TEXT="$(lspci -nnk 2>/dev/null || true)"
GPU_TEXT="$(printf '%s\n' "$PCI_TEXT" | grep -Ei 'vga|display|3d|radeon|amd/ati' || true)"
GPU_ARCH_DETECTED="unknown"

if printf '%s\n' "$GPU_TEXT" | grep -Eiq '890M|Strix|gfx1150'; then
  GPU_ARCH_DETECTED="gfx1150"
fi

NPU_TEXT="$(lsmod 2>/dev/null | grep -Ei 'amdxdna|xrt|xdna' || true)"
NPU_DEVICE_TEXT="$(find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null || true)"
NPU_PRESENT="false"
if [[ -n "$NPU_TEXT" || -n "$NPU_DEVICE_TEXT" ]]; then
  NPU_PRESENT="true"
fi

MEMORY_TOTAL="$(free -h 2>/dev/null | awk '/^Mem:/ {print $2; exit}')"
STORAGE_TEXT="$(lsblk -dn -o NAME,MODEL,SIZE,TYPE 2>/dev/null | sed 's/"/\\"/g' || true)"
BIOS_VERSION="$(sudo dmidecode -s bios-version 2>/dev/null || true)"
SYSTEM_PRODUCT="$(sudo dmidecode -s system-product-name 2>/dev/null || true)"
SYSTEM_VENDOR="$(sudo dmidecode -s system-manufacturer 2>/dev/null || true)"

mark_warn() {
  if [[ "$status" == "PASS" ]]; then
    status="WARN"
  fi
  warnings+=("$1")
}

mark_fail() {
  status="FAIL"
  reasons+=("$1")
}

if [[ "${PROFILE_VALIDATION:-strict}" == "strict" ]]; then
  if [[ -n "${EXPECTED_CPU:-}" && "$CPU_MODEL" != *"$EXPECTED_CPU"* ]]; then
    mark_fail "CPU mismatch: expected '$EXPECTED_CPU', detected '${CPU_MODEL:-unknown}'"
  fi

  if [[ -n "${EXPECTED_GPU_ARCH:-}" && "$GPU_ARCH_DETECTED" != "$EXPECTED_GPU_ARCH" ]]; then
    mark_fail "GPU architecture mismatch: expected '$EXPECTED_GPU_ARCH', detected '$GPU_ARCH_DETECTED'"
  fi

  if [[ -n "${EXPECTED_NPU_FAMILY:-}" && "$NPU_PRESENT" != "true" ]]; then
    mark_fail "NPU not detected: expected '${EXPECTED_NPU_FAMILY}'"
  fi

  if [[ "${PROFILE_ID:-}" == "ai370" && -n "$SYSTEM_PRODUCT" && "$SYSTEM_PRODUCT" != *"AI370"* && "$SYSTEM_PRODUCT" != *"EliteMini"* ]]; then
    mark_warn "System product does not clearly identify as EliteMini AI370: '${SYSTEM_PRODUCT}'"
  fi
else
  if [[ "$CPU_MODEL" != *"Ryzen AI"* ]]; then
    mark_warn "CPU does not clearly identify as Ryzen AI: '${CPU_MODEL:-unknown}'"
  fi

  if [[ "$CPU_VENDOR" != *"AuthenticAMD"* ]]; then
    mark_warn "CPU vendor is not clearly AMD: '${CPU_VENDOR:-unknown}'"
  fi

  if [[ "$NPU_PRESENT" != "true" ]]; then
    mark_warn "NPU device/module not detected; Ryzen AI NPU tooling may be unavailable"
  fi
fi

if [[ "$status" == "PASS" ]]; then
  recommendations+=("Proceed to Phase 3: safe AMD baseline installer.")
elif [[ "$status" == "WARN" ]]; then
  recommendations+=("Review warnings before installation. Generic Ryzen AI mode may be appropriate if this is not an AI370.")
else
  recommendations+=("Do not install optimization stack until hardware/profile mismatch is resolved.")
fi

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))' 2>/dev/null || printf '"%s"' "$1"
}

cat > "$HARDWARE_JSON" <<EOF
{
  "profile": {
    "id": "${PROFILE_ID:-$PROFILE}",
    "name": "${PROFILE_NAME:-unknown}",
    "validation": "${PROFILE_VALIDATION:-strict}",
    "mode": "$MODE",
    "persistence": "$PERSISTENCE"
  },
  "validation": {
    "status": "$status"
  },
  "system": {
    "vendor": $(printf '%s' "$SYSTEM_VENDOR" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
    "product": $(printf '%s' "$SYSTEM_PRODUCT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
    "bios_version": $(printf '%s' "$BIOS_VERSION" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
    "os": $(printf '%s' "$OS_DESCRIPTION" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
    "kernel": $(printf '%s' "$KERNEL" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
  },
  "cpu": {
    "vendor": $(printf '%s' "$CPU_VENDOR" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
    "model": $(printf '%s' "$CPU_MODEL" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
    "logical_cpus": $(printf '%s' "${CPU_CORES:-0}" | python3 -c 'import sys; s=sys.stdin.read().strip(); print(s if s.isdigit() else 0)')
  },
  "gpu": {
    "detected_text": $(printf '%s' "$GPU_TEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
    "arch": "$GPU_ARCH_DETECTED"
  },
  "npu": {
    "present": $NPU_PRESENT,
    "module_text": $(printf '%s' "$NPU_TEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
    "device_text": $(printf '%s' "$NPU_DEVICE_TEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
  },
  "memory": {
    "total": $(printf '%s' "$MEMORY_TOTAL" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
  },
  "storage": {
    "devices": $(printf '%s' "$STORAGE_TEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
  }
}
EOF

{
  echo "$status"
  printf '%s\n' "${reasons[@]:-}" | sed '/^$/d'
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
  if (( ${#reasons[@]} > 0 )); then
    echo "## Failures"
    for reason in "${reasons[@]}"; do echo "- $reason"; done
    echo
  fi
  if (( ${#warnings[@]} > 0 )); then
    echo "## Warnings"
    for warning in "${warnings[@]}"; do echo "- $warning"; done
    echo
  fi
  echo "## Recommendations"
  for rec in "${recommendations[@]}"; do echo "- $rec"; done
} > "$RECOMMENDATIONS_MD"

echo "[INFO] Validation status: $status"
echo "[INFO] Wrote $HARDWARE_JSON"
echo "[INFO] Wrote $RECOMMENDATIONS_MD"
echo "[INFO] Wrote $VALIDATION_STATUS"

if [[ "$status" == "FAIL" ]]; then
  exit 3
fi
