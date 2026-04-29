#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
GPU_STATUS="$LATEST_DIR/gpu-acceleration-status.txt"
NPU_STATUS="$LATEST_DIR/npu-acceleration-status.txt"
PLAN_FILE="$LATEST_DIR/guided-acceleration-plan.md"
COMMANDS_FILE="$LATEST_DIR/guided-acceleration-commands.sh"

require_runtime_persistence() {
  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent acceleration enablement is not implemented yet. Use --persistence=runtime."
    exit 2
  fi
}

read_value() {
  local file="$1"
  local key="$2"
  if [[ -f "$file" ]]; then
    awk -F': ' -v k="$key" '$1 == k {print $2; exit}' "$file"
  fi
}

generate_plan() {
  mkdir -p "$LATEST_DIR"

  local gpu_arch amdgpu vulkan opencl rocm npu_module npu_device npu_runtime
  gpu_arch="$(read_value "$GPU_STATUS" "gpu_arch")"
  amdgpu="$(read_value "$GPU_STATUS" "amdgpu")"
  vulkan="$(read_value "$GPU_STATUS" "vulkan")"
  opencl="$(read_value "$GPU_STATUS" "opencl")"
  rocm="$(read_value "$GPU_STATUS" "rocm")"
  npu_module="$(read_value "$NPU_STATUS" "kernel_module")"
  npu_device="$(read_value "$NPU_STATUS" "device_node")"
  npu_runtime="$(read_value "$NPU_STATUS" "runtime_tools")"

  : "${gpu_arch:=unknown}"
  : "${amdgpu:=unknown}"
  : "${vulkan:=unknown}"
  : "${opencl:=unknown}"
  : "${rocm:=unknown}"
  : "${npu_module:=unknown}"
  : "${npu_device:=unknown}"
  : "${npu_runtime:=unknown}"

  cat > "$PLAN_FILE" <<EOF
# Guided Acceleration Enablement Plan

Profile: $PROFILE  
Mode: $MODE  
Persistence: $PERSISTENCE  
Generated: $(date -Is)

## Current GPU State

- amdgpu: $amdgpu
- GPU architecture: $gpu_arch
- Vulkan: $vulkan
- OpenCL: $opencl
- ROCm/HIP: $rocm

## Current NPU State

- kernel module: $npu_module
- device node: $npu_device
- runtime tools: $npu_runtime

## Policy

This phase is approval-gated. It generates suggested commands but does not execute fragile GPU/NPU acceleration installs automatically.

## GPU Track Recommendation

EOF

  if [[ "$gpu_arch" == "gfx1150" ]]; then
    cat >> "$PLAN_FILE" <<'EOF'
- gfx1150 detected. This aligns with Ryzen AI / Radeon 890M-class hardware.
- ROCm-on-Radeon/Ryzen should be considered only after matching the active AMD compatibility matrix for the operating system and kernel.
- On Ubuntu 26.04, treat ROCm enablement as experimental until AMD explicitly lists support for the exact OS/kernel combination.
EOF
  else
    cat >> "$PLAN_FILE" <<'EOF'
- gfx1150 was not detected. Do not attempt ROCm/iGPU enablement until GPU architecture is confirmed.
EOF
  fi

  cat >> "$PLAN_FILE" <<'EOF'

## NPU Track Recommendation

EOF

  if [[ "$npu_module" == "loaded" || "$npu_device" == "present" ]]; then
    cat >> "$PLAN_FILE" <<'EOF'
- XDNA/NPU presence is visible at the kernel/device layer.
- Install Ryzen AI runtime tooling only from AMD-provided sources and only after confirming compatibility with the current Ubuntu release.
- Use `xrt-smi examine` and `xrt-smi validate` after runtime installation.
EOF
  else
    cat >> "$PLAN_FILE" <<'EOF'
- XDNA/NPU is not visible yet. Focus on kernel, firmware, and BIOS validation before installing runtime tools.
EOF
  fi

  cat > "$COMMANDS_FILE" <<'EOF'
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Generated guided acceleration commands.
# Review every command before running. This file is intentionally not executed by the optimizer.

set -euo pipefail

printf '%s\n' '[INFO] GPU visibility checks'
lspci -nnk | grep -Ei -A4 'vga|display|3d|amd|radeon' || true
lsmod | grep amdgpu || true
vulkaninfo --summary || true
clinfo || true
rocminfo || true

printf '%s\n' '[INFO] NPU visibility checks'
lsmod | grep -Ei 'amdxdna|xrt|xdna' || true
find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null || true
command -v xrt-smi >/dev/null 2>&1 && xrt-smi examine || true
command -v xrt-smi >/dev/null 2>&1 && xrt-smi validate || true

printf '%s\n' '[INFO] Suggested next step: compare this system against AMD ROCm-on-Radeon/Ryzen and Ryzen AI Linux documentation before installing vendor runtimes.'
EOF

  chmod +x "$COMMANDS_FILE"

  echo "[INFO] Wrote $PLAN_FILE"
  echo "[INFO] Wrote $COMMANDS_FILE"
}

main() {
  echo "[INFO] Phase 6: Guided acceleration enablement"
  require_runtime_persistence

  if [[ ! -f "$GPU_STATUS" ]]; then
    echo "[WARN] Missing GPU status. Run: ./scripts/30-rocm-igpu.sh $PROFILE $MODE $PERSISTENCE"
  fi

  if [[ ! -f "$NPU_STATUS" ]]; then
    echo "[WARN] Missing NPU status. Run: ./scripts/40-ryzen-ai-npu.sh $PROFILE $MODE $PERSISTENCE"
  fi

  generate_plan
  echo "[INFO] Phase 6 complete. Review the generated plan before installing acceleration runtimes."
}

main "$@"
