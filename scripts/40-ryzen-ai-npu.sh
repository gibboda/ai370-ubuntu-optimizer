#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
STATUS_FILE="$LATEST_DIR/npu-acceleration-status.txt"
RECOMMENDATIONS_FILE="$LATEST_DIR/npu-acceleration-recommendations.md"

require_runtime_persistence() {
  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent NPU configuration not implemented yet. Use --persistence=runtime."
    exit 2
  fi
}

detect_npu_stack() {
  mkdir -p "$LATEST_DIR"

  local module_state="missing"
  local device_state="missing"
  local runtime_state="unknown"

  if lsmod 2>/dev/null | grep -Eiq 'amdxdna|xrt|xdna'; then
    module_state="loaded"
  fi

  if find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null | grep -q .; then
    device_state="present"
  fi

  if command -v xrt-smi >/dev/null 2>&1; then
    runtime_state="available"
  else
    runtime_state="not-installed"
  fi

  {
    echo "NPU Acceleration Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Timestamp: $(date -Is)"
    echo
    echo "kernel_module: $module_state"
    echo "device_node: $device_state"
    echo "runtime_tools: $runtime_state"
  } > "$STATUS_FILE"

  {
    echo "# NPU Acceleration Track"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo
    echo "## Detected state"
    echo
    echo "- kernel module: $module_state"
    echo "- device node: $device_state"
    echo "- runtime tools: $runtime_state"
    echo
    echo "## Policy"
    echo
    echo "This track detects AMD XDNA2 NPU presence without installing proprietary runtimes automatically."
    echo "Ryzen AI NPU enablement depends on AMD-distributed runtime components that may change across releases."
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
      echo "- Install AMD Ryzen AI runtime tools before attempting NPU workloads."
    fi
    echo "- Keep SAFE mode until NPU inference is validated."
  } > "$RECOMMENDATIONS_FILE"

  echo "[INFO] Wrote $STATUS_FILE"
  echo "[INFO] Wrote $RECOMMENDATIONS_FILE"
}

main() {
  echo "[INFO] Phase 5B: NPU acceleration track"
  require_runtime_persistence
  detect_npu_stack
  echo "[INFO] NPU acceleration track complete."
}

main "$@"
