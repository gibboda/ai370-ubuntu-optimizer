#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
PLAN_FILE="$LATEST_DIR/acceleration-execution-plan.md"
GPU_STEPS="$LATEST_DIR/gpu-enable-approved-steps.sh"
NPU_STEPS="$LATEST_DIR/npu-enable-approved-steps.sh"
GPU_STATUS="$LATEST_DIR/gpu-acceleration-status.txt"
NPU_STATUS="$LATEST_DIR/npu-acceleration-status.txt"

read_value() {
  local file="$1"
  local key="$2"
  if [[ -f "$file" ]]; then
    awk -F': ' -v k="$key" '$1 == k {print $2; exit}' "$file"
  fi
}

require_runtime_persistence() {
  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent acceleration execution is not implemented yet. Use --persistence=runtime."
    exit 2
  fi
}

generate_gpu_steps() {
  cat > "$GPU_STEPS" <<'EOF'
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Approval-gated GPU enablement checklist.
# This script performs validation only. It does not install ROCm automatically.

set -euo pipefail

printf '%s\n' '[GPU] Step 1: Verify AMDGPU kernel path'
lspci -nnk | grep -Ei -A4 'vga|display|3d|amd|radeon' || true
lsmod | grep amdgpu || { echo '[FAIL] amdgpu kernel module is not loaded'; exit 3; }

printf '%s\n' '[GPU] Step 2: Verify Vulkan visibility'
vulkaninfo --summary || { echo '[FAIL] Vulkan is not visible'; exit 3; }

printf '%s\n' '[GPU] Step 3: Verify OpenCL visibility'
clinfo || echo '[WARN] OpenCL is not visible; some workloads may still use Vulkan/CPU paths.'

printf '%s\n' '[GPU] Step 4: Check ROCm visibility, if installed'
rocminfo || echo '[INFO] ROCm/HIP is not visible. Do not force install unless AMD compatibility is confirmed.'

printf '%s\n' '[GPU] PASS: GPU validation checklist completed.'
EOF
  chmod +x "$GPU_STEPS"
}

generate_npu_steps() {
  cat > "$NPU_STEPS" <<'EOF'
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Approval-gated NPU enablement checklist.
# This script validates XDNA/NPU visibility only. It does not install AMD Ryzen AI runtimes automatically.

set -euo pipefail

printf '%s\n' '[NPU] Step 1: Verify XDNA kernel/module visibility'
lsmod | grep -Ei 'amdxdna|xrt|xdna' || echo '[WARN] No XDNA/XRT module visible yet.'

printf '%s\n' '[NPU] Step 2: Verify NPU device nodes'
find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null || true

printf '%s\n' '[NPU] Step 3: Verify XRT tools, if installed'
if command -v xrt-smi >/dev/null 2>&1; then
  xrt-smi examine || true
  xrt-smi validate || true
else
  echo '[INFO] xrt-smi is not installed. Install Ryzen AI/XRT tooling only from AMD-supported sources.'
fi

printf '%s\n' '[NPU] Step 4: Verify ONNX Runtime provider visibility'
if [[ -x .ai370-ai/venv/bin/python ]]; then
  .ai370-ai/venv/bin/python - <<'PY'
import onnxruntime as ort
print('ONNX Runtime providers:', ort.get_available_providers())
PY
else
  echo '[WARN] AI virtual environment not found. Run Phase 4 first.'
fi

printf '%s\n' '[NPU] PASS: NPU validation checklist completed.'
EOF
  chmod +x "$NPU_STEPS"
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
# Acceleration Execution Plan

Profile: $PROFILE  
Mode: $MODE  
Persistence: $PERSISTENCE  
Generated: $(date -Is)

## Execution Policy

Phase 7 is still guided. It creates explicit validation/enablement step scripts but does not install GPU or NPU runtime stacks automatically.

## GPU Readiness

- amdgpu: $amdgpu
- GPU architecture: $gpu_arch
- Vulkan: $vulkan
- OpenCL: $opencl
- ROCm/HIP: $rocm

### GPU Execution Script

Run only after reviewing it:

\`\`\`bash
bash reports/latest/gpu-enable-approved-steps.sh
\`\`\`

## NPU Readiness

- kernel module: $npu_module
- device node: $npu_device
- runtime tools: $npu_runtime

### NPU Execution Script

Run only after reviewing it:

\`\`\`bash
bash reports/latest/npu-enable-approved-steps.sh
\`\`\`

## Install Boundary

Do not install ROCm, XRT, Ryzen AI runtime, or vendor binary packages from this phase unless you have independently confirmed compatibility with:

- current Ubuntu release
- current kernel
- Radeon 890M / gfx1150 path
- XDNA2 runtime path
- AMD official package source

## Recommended Order

1. Run GPU checklist.
2. Run NPU checklist.
3. Review ONNX Runtime providers.
4. Only then decide whether to add vendor runtime installation scripts in a later phase.
EOF

  echo "[INFO] Wrote $PLAN_FILE"
}

main() {
  echo "[INFO] Phase 7: Guided acceleration execution"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"

  require_runtime_persistence
  generate_gpu_steps
  generate_npu_steps
  generate_plan

  echo "[INFO] Phase 7 complete. Review generated scripts before execution."
}

main "$@"
