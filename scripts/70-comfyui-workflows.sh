#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
COMFY_ROOT="$AI_ROOT/ComfyUI"
COMFY_VENV="$COMFY_ROOT/venv"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
STATUS_FILE="$LATEST_DIR/comfyui-status.txt"
README_OUT="$LATEST_DIR/comfyui-workflow-guide.md"
LAUNCH_SCRIPT="$PROJECT_ROOT/run-comfyui.sh"
EXTRA_MODELS="$PROJECT_ROOT/config/comfyui/extra_model_paths.yaml"
AMD_ACCEL_CONFIG="$PROJECT_ROOT/config/amd-acceleration.env"
AMD_ACCEL_STATUS="$LATEST_DIR/amd-acceleration-install.json"
GPU_STATUS="$LATEST_DIR/gpu-acceleration-status.txt"
AMD_ACCEL_ENV="$LATEST_DIR/amd-acceleration-env.sh"
COMFYUI_LAUNCH_MODE="cpu"

require_runtime_persistence() {
  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent ComfyUI configuration is not implemented. Use --persistence=runtime."
    exit 2
  fi
}

install_prereqs() {
  sudo -v
  sudo apt-get update
  sudo apt-get install -y git python3 python3-venv python3-pip python3-dev build-essential libgl1 libglib2.0-0
}

install_comfyui() {
  mkdir -p "$AI_ROOT" "$LATEST_DIR" "$PROJECT_ROOT/config/comfyui"

  if [[ ! -d "$COMFY_ROOT/.git" ]]; then
    echo "[INFO] Cloning ComfyUI source..."
    git clone https://github.com/Comfy-Org/ComfyUI.git "$COMFY_ROOT"
  else
    echo "[INFO] Updating ComfyUI source..."
    git -C "$COMFY_ROOT" pull --ff-only || true
  fi

  if [[ ! -d "$COMFY_VENV" ]]; then
    echo "[INFO] Creating ComfyUI virtual environment..."
    python3 -m venv "$COMFY_VENV"
  fi

  # shellcheck source=/dev/null
  source "$COMFY_VENV/bin/activate"
  python -m pip install --upgrade pip setuptools wheel
  python -m pip install --upgrade -r "$COMFY_ROOT/requirements.txt"
}

create_model_layout() {
  mkdir -p \
    "$AI_ROOT/models/checkpoints" \
    "$AI_ROOT/models/vae" \
    "$AI_ROOT/models/loras" \
    "$AI_ROOT/models/controlnet" \
    "$AI_ROOT/models/clip" \
    "$AI_ROOT/models/upscale_models" \
    "$AI_ROOT/workflows/comfyui" \
    "$AI_ROOT/outputs/comfyui"

  cat > "$EXTRA_MODELS" <<EOF
# External model paths for ai370-ubuntu-optimizer
# Copy or symlink this into ComfyUI's extra_model_paths.yaml if needed.

ai370_local_models:
  base_path: $AI_ROOT/models
  checkpoints: checkpoints
  vae: vae
  loras: loras
  controlnet: controlnet
  clip: clip
  upscale_models: upscale_models
EOF
}

read_status_value() {
  local file="$1"
  local key="$2"
  if [[ -f "$file" ]]; then
    awk -F': ' -v k="$key" '$1 == k {print $2; exit}' "$file"
  fi
}

resolve_comfyui_launch_mode() {
  local configured_mode rocm_state vulkan_state
  configured_mode="auto"
  if [[ -f "$AMD_ACCEL_CONFIG" ]]; then
    # shellcheck source=/dev/null
    source "$AMD_ACCEL_CONFIG"
    configured_mode="${COMFYUI_ACCELERATION_MODE:-auto}"
  fi

  case "$configured_mode" in
    cpu)
      COMFYUI_LAUNCH_MODE="cpu"
      ;;
    rocm|gpu)
      rocm_state="$(read_status_value "$GPU_STATUS" "rocm")"
      if [[ -f "$AMD_ACCEL_STATUS" && "$rocm_state" == "visible" ]]; then
        COMFYUI_LAUNCH_MODE="gpu"
      else
        echo "[WARN] COMFYUI_ACCELERATION_MODE=${configured_mode} requires the amd-accel-install phase to have completed and ROCm to be visible; falling back to CPU-safe mode."
        COMFYUI_LAUNCH_MODE="cpu"
      fi
      ;;
    auto)
      rocm_state="$(read_status_value "$GPU_STATUS" "rocm")"
      vulkan_state="$(read_status_value "$GPU_STATUS" "vulkan")"
      if [[ -f "$AMD_ACCEL_STATUS" && "$rocm_state" == "visible" ]]; then
        COMFYUI_LAUNCH_MODE="gpu"
      elif [[ -f "$AMD_ACCEL_STATUS" && "$vulkan_state" == "visible" ]]; then
        COMFYUI_LAUNCH_MODE="vulkan-ready"
      else
        COMFYUI_LAUNCH_MODE="cpu"
      fi
      ;;
    *)
      echo "[WARN] Unknown COMFYUI_ACCELERATION_MODE '$configured_mode'; using CPU-safe mode."
      COMFYUI_LAUNCH_MODE="cpu"
      ;;
  esac
}

is_rocm_torch_available() {
  [[ -d "$COMFY_VENV" ]] || return 1
  "$COMFY_VENV/bin/python" -c "import torch; assert torch.version.hip is not None" 2>/dev/null
}

create_launch_script() {
  local cpu_arg launch_note amd_env_source
  resolve_comfyui_launch_mode

  # Gate GPU mode on ROCm-enabled PyTorch being installed in the ComfyUI venv.
  if [[ "$COMFYUI_LAUNCH_MODE" == "gpu" ]] && ! is_rocm_torch_available; then
    echo "[WARN] GPU mode requested but ROCm-enabled PyTorch is not installed in the ComfyUI venv; keeping CPU-safe mode."
    COMFYUI_LAUNCH_MODE="cpu"
  fi

  cpu_arg="--cpu"
  launch_note="CPU-safe mode"
  if [[ "$COMFYUI_LAUNCH_MODE" == "gpu" ]]; then
    cpu_arg=""
    launch_note="AMD GPU mode; ROCm was visible during validation"
  elif [[ "$COMFYUI_LAUNCH_MODE" == "vulkan-ready" ]]; then
    cpu_arg="--cpu"
    launch_note="Vulkan visible but ROCm not validated for ComfyUI; keeping CPU-safe mode"
  fi

  amd_env_source=""
  if [[ "$COMFYUI_LAUNCH_MODE" == "gpu" ]]; then
    amd_env_source="if [[ -f \"${AMD_ACCEL_ENV}\" ]]; then
  # shellcheck source=/dev/null
  source \"${AMD_ACCEL_ENV}\"
fi"
  fi

  cat > "$LAUNCH_SCRIPT" <<EOF
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

COMFY_ROOT="$COMFY_ROOT"
COMFY_VENV="$COMFY_VENV"
OUTPUT_DIR="$AI_ROOT/outputs/comfyui"
LAUNCH_NOTE="$launch_note"

${amd_env_source}
printf '%s\n' "[INFO] ComfyUI launch mode: \$LAUNCH_NOTE"
cd "\$COMFY_ROOT"
source "\$COMFY_VENV/bin/activate"

# CPU mode is removed only when the opt-in AMD acceleration phase has completed and ROCm is visible.
# shellcheck disable=SC2086
python main.py $cpu_arg --listen 127.0.0.1 --port 8188 --output-directory "\$OUTPUT_DIR"
EOF
  chmod +x "$LAUNCH_SCRIPT"
}

write_reports() {
  {
    echo "ComfyUI Workflow Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Timestamp: $(date -Is)"
    echo
    echo "ComfyUI root: $COMFY_ROOT"
    echo "ComfyUI venv: $COMFY_VENV"
    echo "Model root: $AI_ROOT/models"
    echo "Workflow root: $AI_ROOT/workflows/comfyui"
    echo "Output root: $AI_ROOT/outputs/comfyui"
    echo "Launch script: $LAUNCH_SCRIPT"
    echo "Launch mode: $COMFYUI_LAUNCH_MODE"
  } > "$STATUS_FILE"

  cat > "$README_OUT" <<EOF
# ComfyUI + Local AI Workflow Guide

## Purpose

This workflow layer installs ComfyUI from source into an isolated local AI workspace and keeps execution SAFE by default.

## Paths

- ComfyUI source: \`$COMFY_ROOT\`
- Virtual environment: \`$COMFY_VENV\`
- Model root: \`$AI_ROOT/models\`
- Workflows: \`$AI_ROOT/workflows/comfyui\`
- Outputs: \`$AI_ROOT/outputs/comfyui\`
- Launch script: \`$LAUNCH_SCRIPT\`

## Launch

\`\`\`bash
./run-comfyui.sh
\`\`\`

Then open:

\`\`\`text
http://127.0.0.1:8188
\`\`\`

## Model folders

Place models here:

- Checkpoints: \`.ai370-ai/models/checkpoints\`
- VAE: \`.ai370-ai/models/vae\`
- LoRA: \`.ai370-ai/models/loras\`
- ControlNet: \`.ai370-ai/models/controlnet\`
- CLIP: \`.ai370-ai/models/clip\`
- Upscalers: \`.ai370-ai/models/upscale_models\`

## SAFE default

The generated launcher starts ComfyUI with \`--cpu\` by default. This prevents unstable AMD iGPU/ROCm assumptions.

If \`./ai370-optimize.sh amd-accel-install --accept-amd-acceleration-risk\` completes and ROCm remains visible in Phase 5 validation, the launcher is generated without \`--cpu\` and sources \`reports/latest/amd-acceleration-env.sh\`. Otherwise it stays CPU-safe.

## Recommended local workflow order

1. Run hardware audit and validation.
2. Run AMD baseline.
3. Run AI stack setup.
4. Run GPU/NPU detection tracks.
5. Run guided acceleration plans.
6. Optionally run the explicit AMD acceleration install phase and rerun GPU/NPU validation.
7. Install ComfyUI workflow layer.
8. Add models manually.
9. Launch ComfyUI; it uses GPU mode only when ROCm was explicitly installed and validated.
EOF

  echo "[INFO] Wrote $STATUS_FILE"
  echo "[INFO] Wrote $README_OUT"
}

main() {
  echo "[INFO] Phase 8: ComfyUI + local AI workflows"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"

  require_runtime_persistence
  install_prereqs
  install_comfyui
  create_model_layout
  create_launch_script
  write_reports

  echo "[INFO] ComfyUI workflow layer complete. Launch with ./run-comfyui.sh"
}

main "$@"
