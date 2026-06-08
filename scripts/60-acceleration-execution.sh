#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
PLAN_FILE="$LATEST_DIR/acceleration-execution-plan.md"
GPU_STEPS="$LATEST_DIR/gpu-enable-approved-steps.sh"
NPU_STEPS="$LATEST_DIR/npu-enable-approved-steps.sh"
CPU_STEPS="$LATEST_DIR/cpu-onnx-smoke.sh"
RESULTS_JSON="$LATEST_DIR/offline-ai-hardware-results.json"
RESULTS_MD="$LATEST_DIR/offline-ai-hardware-results.md"
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

generate_cpu_steps() {
  cat > "$CPU_STEPS" <<'CPU_STEPS_EOF'
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Offline CPU/ONNX Runtime smoke benchmark. This script performs local validation only.

set -euo pipefail

if [[ ! -x .ai370-ai/venv/bin/python ]]; then
  echo '[ERROR] AI virtual environment not found. Run Phase 4 first.'
  exit 3
fi

printf '%s\n' '[CPU] Step 1: Verify ONNX Runtime providers'
.ai370-ai/venv/bin/python - <<'PY'
import onnxruntime as ort
providers = ort.get_available_providers()
print('ONNX Runtime providers:', providers)
if 'CPUExecutionProvider' not in providers:
    raise SystemExit('[ERROR] CPUExecutionProvider is not available')
PY

printf '%s\n' '[CPU] Step 2: Run local matrix and ONNX smoke benchmark'
.ai370-ai/venv/bin/python - <<'PY'
import statistics
import tempfile
import time
from pathlib import Path
import numpy as np
import onnx
import onnx.helper as helper
import onnxruntime as ort
from onnx import TensorProto

a = np.ones((512, 512), dtype=np.float32)
b = np.ones((512, 512), dtype=np.float32)
timings = []
for _ in range(3):
    start = time.perf_counter()
    _ = a @ b
    timings.append(time.perf_counter() - start)
print('numpy matmul median seconds:', statistics.median(timings))

with tempfile.TemporaryDirectory() as tmpdir:
    model_path = Path(tmpdir) / 'identity.onnx'
    graph = helper.make_graph(
        [helper.make_node('Identity', ['input'], ['output'])],
        'ai370_identity_smoke',
        [helper.make_tensor_value_info('input', TensorProto.FLOAT, [1, 4])],
        [helper.make_tensor_value_info('output', TensorProto.FLOAT, [1, 4])],
    )
    model = helper.make_model(graph, producer_name='ai370-ubuntu-optimizer')
    model.ir_version = 10
    for opset in model.opset_import:
        opset.version = 13
    onnx.save(model, model_path)
    session = ort.InferenceSession(str(model_path), providers=['CPUExecutionProvider'])
    sample = np.ones((1, 4), dtype=np.float32)
    timings = []
    for _ in range(10):
        start = time.perf_counter()
        session.run(None, {'input': sample})
        timings.append(time.perf_counter() - start)
    print('onnxruntime identity median seconds:', statistics.median(timings))
PY

printf '%s\n' '[CPU] PASS: CPU/ONNX Runtime smoke benchmark completed.'
CPU_STEPS_EOF
  chmod +x "$CPU_STEPS"
}

generate_gpu_steps() {
  cat > "$GPU_STEPS" <<'GPU_STEPS_EOF'
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
GPU_STEPS_EOF
  chmod +x "$GPU_STEPS"
}

generate_npu_steps() {
  cat > "$NPU_STEPS" <<'NPU_STEPS_EOF'
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
  echo '[INFO] xrt-smi is not installed. Install Ryzen AI/XRT tooling only from approved offline artifacts.'
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
NPU_STEPS_EOF
  chmod +x "$NPU_STEPS"
}

generate_results_stub() {
  cat > "$RESULTS_MD" <<EOF
# Offline AI Hardware Results

Profile: $PROFILE
Mode: $MODE
Persistence: $PERSISTENCE
Offline: $OFFLINE

Generated checklist scripts:

- CPU/ONNX Runtime: \`reports/latest/cpu-onnx-smoke.sh\`
- GPU: \`reports/latest/gpu-enable-approved-steps.sh\`
- NPU: \`reports/latest/npu-enable-approved-steps.sh\`

Run these scripts manually after review. This phase does not install or fetch runtime stacks.
EOF
  cat > "$RESULTS_JSON" <<EOF
{
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $OFFLINE,
  "generated_scripts": {
    "cpu": "reports/latest/cpu-onnx-smoke.sh",
    "gpu": "reports/latest/gpu-enable-approved-steps.sh",
    "npu": "reports/latest/npu-enable-approved-steps.sh"
  },
  "policy": "local validation only; no downloads or runtime installs"
}
EOF
  echo "[INFO] Wrote $RESULTS_MD"
  echo "[INFO] Wrote $RESULTS_JSON"
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
Offline: $OFFLINE
Generated: $(date -Is)

## Execution Policy

Phase 7 is still guided. It creates explicit local validation and benchmark scripts but does not install GPU or NPU runtime stacks automatically.

## CPU/ONNX Runtime Script

Run only after reviewing it:

\`\`\`bash
bash reports/latest/cpu-onnx-smoke.sh
\`\`\`

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

Do not install ROCm, XRT, Ryzen AI runtime, or vendor binary packages from this phase unless you have independently confirmed compatibility with local offline artifacts and the current Ubuntu/kernel/hardware combination.

## Recommended Order

1. Run CPU/ONNX Runtime smoke benchmark.
2. Run GPU checklist.
3. Run NPU checklist.
4. Review structured reports in reports/latest.
5. Only then decide whether to add vendor runtime installation scripts or ComfyUI in a later phase.
EOF

  echo "[INFO] Wrote $PLAN_FILE"
}

main() {
  echo "[INFO] Phase 7: Guided acceleration execution"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"
  echo "[INFO] Offline: $OFFLINE"

  require_runtime_persistence
  generate_cpu_steps
  generate_gpu_steps
  generate_npu_steps
  generate_plan
  generate_results_stub

  echo "[INFO] Phase 7 complete. Review generated scripts before execution."
}

main "$@"
