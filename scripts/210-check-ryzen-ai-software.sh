#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/npu-venv.sh
source "$PROJECT_ROOT/scripts/lib/npu-venv.sh"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
STATUS_FILE="$LATEST_DIR/npu-acceleration-status.txt"
STATUS_JSON="$LATEST_DIR/npu-acceleration-status.json"
RECOMMENDATIONS_FILE="$LATEST_DIR/npu-acceleration-recommendations.md"
CAPABILITIES_JSON="$LATEST_DIR/npu-capabilities.json"
SMOKE_FILE="$LATEST_DIR/npu-smoke-benchmark.md"
XRT_STATUS="$LATEST_DIR/xrt-status.txt"
# Prefer Ryzen AI venv (VitisAI EP) over stock CPU onnxruntime venv.
prepare_npu_runtime_env "$PROJECT_ROOT"
VENV_PYTHON="$(resolve_npu_python "$PROJECT_ROOT" || true)"
VENV_SOURCE="$(npu_python_source_label "${VENV_PYTHON:-}")"

require_runtime_persistence() {
  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent NPU configuration not implemented yet. Use --persistence=runtime."
    exit 2
  fi
}

npu_kernel_module_loaded() {
  # Prefer /proc/modules: lsmod | grep -Eiq is unreliable on some hosts (grep -qi + pipe).
  if [[ -r /proc/modules ]] && grep -Eq '^(amdxdna|xrt|xdna)[[:space:]]' /proc/modules 2>/dev/null; then
    return 0
  fi
  if lsmod 2>/dev/null | grep -Eq '^(amdxdna|xrt|xdna)[[:space:]]'; then
    return 0
  fi
  return 1
}

detect_npu_stack() {
  mkdir -p "$LATEST_DIR"

  local module_state="missing"
  local device_state="missing"
  local runtime_state="not-installed"
  local xrt_examine="not-run"
  local xrt_validate="not-run"
  local device_nodes=""
  local ort_providers="unknown"

  if npu_kernel_module_loaded; then
    module_state="loaded"
  fi

  device_nodes="$(find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null || true)"
  if [[ -n "$device_nodes" ]]; then
    device_state="present"
  fi

  if command -v xrt-smi >/dev/null 2>&1 || [[ -x /opt/xilinx/xrt/bin/xrt-smi ]]; then
    runtime_state="available"
    local xrt_smi_bin
    xrt_smi_bin="$(command -v xrt-smi 2>/dev/null || true)"
    [[ -z "$xrt_smi_bin" && -x /opt/xilinx/xrt/bin/xrt-smi ]] && xrt_smi_bin="/opt/xilinx/xrt/bin/xrt-smi"
    xrt_examine="$("$xrt_smi_bin" examine 2>&1 || true)"
    xrt_validate="$("$xrt_smi_bin" validate 2>&1 || true)"
  fi

  # Package C: ORT provider listing is owned by 220-check-vitis-ai-ep.sh.
  # Set AI370_210_LIST_ORT=true to restore the historical dual list here.
  if [[ "${AI370_210_LIST_ORT:-false}" == "true" ]]; then
    if [[ -n "${VENV_PYTHON:-}" && -x "$VENV_PYTHON" ]]; then
      if ! ort_providers="$("$VENV_PYTHON" - <<'PY'
try:
    import onnxruntime as ort
except ModuleNotFoundError:
    print("missing: onnxruntime")
else:
    print(",".join(ort.get_available_providers()))
PY
)"; then
        ort_providers="error: onnxruntime provider check failed"
      fi
    else
      ort_providers="missing: no NPU/stock venv python"
    fi
  else
    ort_providers="deferred-to-220-check-vitis-ai-ep"
  fi

  {
    echo "NPU Acceleration Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo
    echo "kernel_module: $module_state"
    echo "device_node: $device_state"
    echo "runtime_tools: $runtime_state"
    echo "onnxruntime_venv: ${VENV_PYTHON:-none} (${VENV_SOURCE:-unknown})"
    echo "onnxruntime_providers: $ort_providers"
  } > "$STATUS_FILE"

  {
    echo "# XRT Status"
    echo
    echo "Runtime tools: $runtime_state"
    echo
    echo "## xrt-smi examine"
    echo
    printf '%s\n' "$xrt_examine"
    echo
    echo "## xrt-smi validate"
    echo
    printf '%s\n' "$xrt_validate"
  } > "$XRT_STATUS"

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" \
  MODULE_STATE="$module_state" DEVICE_STATE="$device_state" RUNTIME_STATE="$runtime_state" \
  DEVICE_NODES="$device_nodes" ORT_PROVIDERS="$ort_providers" XRT_EXAMINE="$xrt_examine" XRT_VALIDATE="$xrt_validate" \
  VENV_PYTHON="${VENV_PYTHON:-}" VENV_SOURCE="${VENV_SOURCE:-unknown}" \
  python3 - "$STATUS_JSON" "$CAPABILITIES_JSON" <<'PY'
import json
import os
import sys
from pathlib import Path
status_path, capabilities_path = sys.argv[1:]
status = {
    "profile": os.environ["PROFILE"],
    "mode": os.environ["MODE"],
    "persistence": os.environ["PERSISTENCE"],
    "offline": os.environ["OFFLINE"] == "true",
    "kernel_module": os.environ["MODULE_STATE"],
    "device_node": os.environ["DEVICE_STATE"],
    "runtime_tools": os.environ["RUNTIME_STATE"],
    "onnxruntime_venv": os.environ.get("VENV_PYTHON", ""),
    "onnxruntime_venv_source": os.environ.get("VENV_SOURCE", "unknown"),
    "onnxruntime_providers": os.environ["ORT_PROVIDERS"],
}
capabilities = dict(status)
capabilities.update({
    "device_nodes": os.environ.get("DEVICE_NODES", ""),
    "xrt_smi_examine": os.environ.get("XRT_EXAMINE", ""),
    "xrt_smi_validate": os.environ.get("XRT_VALIDATE", ""),
})
Path(status_path).write_text(json.dumps(status, indent=2) + "\n")
Path(capabilities_path).write_text(json.dumps(capabilities, indent=2) + "\n")
PY

  {
    echo "# NPU Offline Smoke Benchmark"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
    echo
    echo "## Results"
    echo
    echo "- kernel module: $module_state"
    echo "- device node: $device_state"
    echo "- XRT tools: $runtime_state"
    echo "- ONNX Runtime venv: ${VENV_PYTHON:-none} (${VENV_SOURCE:-unknown})"
    echo "- ONNX Runtime providers: $ort_providers"
    echo
    echo "No downloads or installs were attempted. NPU inference should only be attempted when a local NPU execution provider is visible."
  } > "$SMOKE_FILE"

  {
    echo "# NPU Acceleration Track"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
    echo
    echo "## Detected state"
    echo
    echo "- kernel module: $module_state"
    echo "- device node: $device_state"
    echo "- runtime tools: $runtime_state"
    echo "- ONNX Runtime venv: ${VENV_PYTHON:-none} (${VENV_SOURCE:-unknown})"
    echo "- ONNX Runtime providers: $ort_providers"
    echo
    echo "## Policy"
    echo
    echo "This track detects AMD XDNA2 NPU presence and locally installed runtime/provider visibility without fetching proprietary runtimes."
    echo "Provider checks prefer \`.ai370-ai/ryzen-ai/venv\` (AMD install) over stock \`.ai370-ai/venv\` (CPU onnxruntime)."
    echo
    echo "## Recommendations"
    echo
    if [[ "$module_state" != "loaded" ]]; then
      echo "- Kernel module not loaded; ensure your kernel supports AMD XDNA."
    fi
    if [[ "$device_state" != "present" ]]; then
      echo "- No NPU device nodes detected; firmware or kernel support may be missing."
    fi
    if [[ "$runtime_state" != "available" ]]; then
      echo "- Stage AMD Ryzen AI runtime tools in your approved offline artifacts before attempting NPU workloads."
    fi
    if [[ "${VENV_SOURCE:-}" != "ryzen-ai" ]]; then
      echo "- Ryzen AI venv not selected; run scripts/205-install-xrt-ryzen-ai.sh with --accept-amd-acceleration-risk so NPU EP checks use .ai370-ai/ryzen-ai/venv."
    fi
    echo "- Keep SAFE mode until NPU inference is validated."
  } > "$RECOMMENDATIONS_FILE"

  echo "[INFO] Wrote $STATUS_FILE"
  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $CAPABILITIES_JSON"
  echo "[INFO] Wrote $SMOKE_FILE"
  echo "[INFO] Wrote $XRT_STATUS"
  echo "[INFO] Wrote $RECOMMENDATIONS_FILE"
}

main() {
  echo "[INFO] Phase 5: XDNA NPU validation track"
  echo "[INFO] Offline: $OFFLINE"
  require_runtime_persistence
  detect_npu_stack
  echo "[INFO] NPU acceleration track complete."
}

main "$@"
