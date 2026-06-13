#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 1 script: Kernel + AMD baseline (safe Ubuntu packages for diagnostics + amdgpu visibility).
# Supports --dry-run (passed as 4th arg).

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
DRY_RUN="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

LATEST_DIR="$PROJECT_ROOT/reports/latest"
mkdir -p "$LATEST_DIR"

# Safe baseline packages only (no ROCm/XRT/Ryzen AI here – those are explicit opt-in)
BASE_PACKAGES=(
  pciutils usbutils dmidecode lshw inxi jq lm-sensors
  linux-firmware fwupd
  mesa-utils vulkan-tools clinfo
  nvme-cli smartmontools
  python3 python3-venv python3-pip
  curl wget git build-essential ca-certificates gnupg software-properties-common apt-transport-https
)

main() {
  echo "[INFO] Tier 1 / 30-optimize-kernel.sh (kernel + AMD driver baseline)"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE  Dry-run: $DRY_RUN"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] system persistence not implemented. Use --persistence=runtime."
    exit 2
  fi

  GPU_ARCH="$(detect_gpu_arch "$(detect_gpu_text)")"
  NPU_PRESENT="$(detect_npu_present "$(detect_npu_module_text)" "$(detect_npu_device_text)")"

  echo "[INFO] Detected GPU arch: $GPU_ARCH"
  echo "[INFO] NPU present: $NPU_PRESENT"

  # Very small plan (for transparency)
  cat > "$LATEST_DIR/tier1-kernel-plan.json" <<EOF
{
  "tier": 1,
  "phase": "optimize-kernel",
  "plan_status": "safe",
  "dry_run": $([[ "$DRY_RUN" == "true" ]] && echo true || echo false),
  "packages": [$(printf '"%s",' "${BASE_PACKAGES[@]}" | sed 's/,$//')],
  "blocked": ["rocm", "xrt", "ryzen_ai_runtime"],
  "notes": "Conservative Ubuntu baseline only. AMD acceleration stacks are installed via amd-accel-install or tier3/tier5 paths with explicit risk acknowledgement."
}
EOF

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Would ensure baseline packages are present:"
    printf '  %s\n' "${BASE_PACKAGES[@]}"
    echo "[DRY-RUN] Skipping apt and runtime configuration."
  else
    echo "[INFO] Updating apt and installing Tier 1 baseline packages..."
    sudo apt-get update
    sudo apt-get install -y "${BASE_PACKAGES[@]}"

    # Light runtime defaults (power profile handled in CPU tuning script)
    if command -v powerprofilesctl >/dev/null 2>&1; then
      target="balanced"
      [[ "$MODE" == "aggressive" ]] && target="performance"
      sudo powerprofilesctl set "$target" || true
      echo "[INFO] Power profile set to $target (runtime)"
    fi
  fi

  # Post-apply visibility smoke (same spirit as old baseline postcheck)
  {
    echo "# Tier 1 Kernel + AMD Baseline"
    echo
    echo "Dry run: $DRY_RUN"
    echo "GPU arch seen: $GPU_ARCH"
    echo "NPU present: $NPU_PRESENT"
    echo
    echo "## Quick visibility after baseline"
    echo 'Kernel:'; uname -r || true
    echo
    echo 'amdgpu module:'; lsmod | grep -E '^amdgpu' || echo "(not yet visible or not loaded)"
    echo
    echo 'Vulkan summary:'; vulkaninfo --summary 2>/dev/null | head -8 || echo "(vulkaninfo not present or no device)"
  } > "$LATEST_DIR/tier1-kernel-baseline.md"

  echo "[INFO] Wrote tier1-kernel-plan.json and tier1-kernel-baseline.md"
  echo "[INFO] 30-optimize-kernel.sh complete."
}

main "$@"
