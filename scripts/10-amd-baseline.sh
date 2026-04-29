#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
VALIDATION_STATUS="$LATEST_DIR/validation-status.txt"
HARDWARE_JSON="$LATEST_DIR/hardware.json"

BASE_PACKAGES=(
  pciutils
  usbutils
  dmidecode
  lshw
  inxi
  jq
  curl
  wget
  git
  build-essential
  ca-certificates
  gnupg
  software-properties-common
  apt-transport-https
  linux-firmware
  fwupd
  lm-sensors
  nvme-cli
  smartmontools
  mesa-utils
  vulkan-tools
  clinfo
  python3
  python3-venv
  python3-pip
)

require_root_privilege() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "[INFO] sudo access is required for package installation."
    sudo -v
  fi
}

require_phase2_pass() {
  if [[ ! -f "$VALIDATION_STATUS" ]]; then
    echo "[ERROR] Missing Phase 2 validation output: $VALIDATION_STATUS"
    echo "[ERROR] Run: ./ai370-optimize.sh audit && ./ai370-optimize.sh plan --profile=$PROFILE"
    exit 3
  fi

  local status
  status="$(head -n 1 "$VALIDATION_STATUS" | tr -d '[:space:]')"

  if [[ "$status" == "FAIL" ]]; then
    echo "[ERROR] Phase 2 validation failed. Refusing baseline installation."
    sed -n '1,80p' "$VALIDATION_STATUS"
    exit 3
  fi

  if [[ "$status" == "WARN" && "$PROFILE" == "ai370" ]]; then
    echo "[WARN] Phase 2 validation produced warnings under strict AI370 profile."
    sed -n '1,80p' "$VALIDATION_STATUS"
    echo "[WARN] Continuing with SAFE baseline only."
  fi
}

install_base_packages() {
  echo "[INFO] Updating apt package index..."
  sudo apt-get update

  echo "[INFO] Installing AMD baseline diagnostic packages..."
  sudo apt-get install -y "${BASE_PACKAGES[@]}"
}

configure_runtime_safe_defaults() {
  echo "[INFO] Applying SAFE runtime defaults only."

  if command -v powerprofilesctl >/dev/null 2>&1; then
    sudo powerprofilesctl set balanced || true
  fi

  if command -v sensors-detect >/dev/null 2>&1; then
    echo "[INFO] lm-sensors installed. Run 'sudo sensors-detect' manually if sensor output is incomplete."
  fi
}

validate_amd_visibility() {
  echo "[INFO] AMD baseline visibility checks"

  echo "\n[CHECK] Kernel"
  uname -r || true

  echo "\n[CHECK] AMD GPU PCI devices"
  lspci -nnk | grep -Ei -A3 'vga|display|3d|amd|radeon' || true

  echo "\n[CHECK] amdgpu module"
  lsmod | grep amdgpu || echo "[WARN] amdgpu module not visible in lsmod"

  echo "\n[CHECK] Vulkan"
  vulkaninfo --summary 2>/dev/null || echo "[WARN] vulkaninfo failed or no Vulkan device visible"

  echo "\n[CHECK] OpenCL"
  clinfo 2>/dev/null | head -n 80 || echo "[WARN] clinfo failed or no OpenCL platform visible"

  echo "\n[CHECK] NPU / XDNA"
  lsmod | grep -Ei 'amdxdna|xrt|xdna' || echo "[WARN] XDNA/NPU kernel module not visible yet"
  find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null || true
}

write_baseline_report() {
  mkdir -p "$LATEST_DIR"
  local report="$LATEST_DIR/amd-baseline-status.txt"

  {
    echo "AMD Baseline Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Timestamp: $(date -Is)"
    echo
    echo "Installed packages:"
    printf '%s\n' "${BASE_PACKAGES[@]}"
    echo
    echo "Hardware JSON: $HARDWARE_JSON"
  } > "$report"

  echo "[INFO] Wrote $report"
}

main() {
  echo "[INFO] Phase 3: AMD baseline installer"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] System persistence is not implemented in Phase 3. Use --persistence=runtime."
    exit 2
  fi

  if [[ "$MODE" == "aggressive" ]]; then
    echo "[WARN] Aggressive mode requested, but Phase 3 applies only reversible baseline setup."
  fi

  require_phase2_pass
  require_root_privilege
  install_base_packages
  configure_runtime_safe_defaults
  validate_amd_visibility
  write_baseline_report

  echo "[INFO] Phase 3 complete. SAFE AMD baseline is installed."
}

main "$@"
