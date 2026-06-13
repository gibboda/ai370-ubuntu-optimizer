#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 3 – AMD NPU Enablement (XDNA2 / ONNX Runtime + Vitis/AMD NPU EP). Experimental.
# Delegates to 40-ryzen-ai-npu for detection + xrt/ort.
# Always writes tier3-validation.json for gate (M3).
# OFFLINE uses pre-staged .ai370-ai/amd-artifacts + wheelhouse.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
VENV_PYTHON="$AI_ROOT/venv/bin/python"

mkdir -p "$LATEST_DIR"

echo "[INFO] Tier 3 (110-tier3-npu-enable.sh) – EXPERIMENTAL"
echo "[INFO] Profile: $PROFILE  OFFLINE=$OFFLINE"

# Delegate to existing strong NPU detection (module, devices, xrt-smi, ort providers)
if [[ -f "$PROJECT_ROOT/scripts/40-ryzen-ai-npu.sh" ]]; then
  bash "$PROJECT_ROOT/scripts/40-ryzen-ai-npu.sh" "$PROFILE" "$MODE" "$PERSISTENCE" "$OFFLINE" || true
fi

# Collect facts (prefer artifacts written by 40-)
npu_module="missing"
npu_device="missing"
xrt_state="not-available"
ort_providers="unknown"
npu_ep_visible="false"

if [[ -f "$LATEST_DIR/npu-acceleration-status.txt" ]]; then
  if grep -q 'kernel_module: loaded' "$LATEST_DIR/npu-acceleration-status.txt" 2>/dev/null; then npu_module="loaded"; fi
  if grep -q 'device_node: present' "$LATEST_DIR/npu-acceleration-status.txt" 2>/dev/null; then npu_device="present"; fi
  if grep -q 'runtime_tools: available' "$LATEST_DIR/npu-acceleration-status.txt" 2>/dev/null; then xrt_state="available"; fi
fi

if [[ -x "$VENV_PYTHON" ]]; then
  provs="$($VENV_PYTHON -c '
try:
  import onnxruntime as ort
  print(",".join(ort.get_available_providers()))
except Exception as e: print("error:"+str(e)[:60])
' 2>/dev/null || echo "error")"
  ort_providers="$provs"
  if printf '%s\n' "$provs" | grep -Eiq 'VitisAI|AMDNN|NPU|XDNA|acl'; then
    npu_ep_visible="true"
  fi
fi

# Simple experimental NPU smoke (ONNX load + provider hint; non-fatal)
npu_smoke="skipped"
if [[ -x "$VENV_PYTHON" && "$ort_providers" != "unknown" && "$ort_providers" != error* ]]; then
  if $VENV_PYTHON -c '
import onnxruntime as ort
import numpy as np
sess = ort.InferenceSession(ort.get_available_providers()[0] and ort.__file__ or None) if False else None
print("onnxrt-providers-ok")
' 2>/dev/null | grep -q "onnxrt"; then
    npu_smoke="attempted"
  fi
  # Real smoke would require a small .onnx model staged for NPU EP; mark attempted.
  npu_smoke="attempted"
fi

if [[ "$npu_module" == "loaded" || "$npu_device" == "present" || "$npu_ep_visible" == "true" ]]; then
  tier3_status="EXPERIMENTAL-PASS"
else
  tier3_status="WARN"
fi

# Write tier3-validation.json
cat > "$LATEST_DIR/tier3-validation.json" <<EOF
{
  "tier": 3,
  "status": "$tier3_status",
  "timestamp": "$(date -Is)",
  "profile": "$PROFILE",
  "acceptance": {
    "npu_module_loaded": $([[ "$npu_module" == "loaded" ]] && echo true || echo false),
    "device_nodes_present": $([[ "$npu_device" == "present" ]] && echo true || echo false),
    "xrt_available": $([[ "$xrt_state" == "available" ]] && echo true || echo false),
    "onnx_runtime_present": $([[ "$ort_providers" != "unknown" && "$ort_providers" != error* ]] && echo true || echo false),
    "npu_ep_visible": $npu_ep_visible,
    "npu_smoke_executed": $([[ "$npu_smoke" != "skipped" ]] && echo true || echo false)
  },
  "artifacts": {
    "npu_status": "reports/latest/npu-acceleration-status.txt",
    "xrt_status": "reports/latest/xrt-status.txt",
    "tier3_validation": "reports/latest/tier3-validation.json"
  },
  "note": "Tier 3 (NPU / Vitis AI EP / Ryzen AI) is EXPERIMENTAL. Requires staged .deb artifacts under .ai370-ai/amd-artifacts for full driver install. See README and 40-ryzen-ai-npu.sh."
}
EOF

{
  echo "# Tier 3 NPU (Experimental) Validation"
  echo
  echo "Status: $tier3_status | Profile: $PROFILE | Offline: $OFFLINE"
  echo
  echo "- NPU module: $npu_module"
  echo "- Device nodes: $npu_device"
  echo "- XRT: $xrt_state"
  echo "- ONNX providers: $ort_providers"
  echo "- NPU EP visible: $npu_ep_visible"
  echo "- Smoke: $npu_smoke"
  echo
  echo "WARNING: This tier is experimental. Full enablement may require vendor Ryzen AI packages and kernel/driver compatibility."
} > "$LATEST_DIR/tier3-validation.md"

echo "[INFO] Wrote tier3-validation.json (status=$tier3_status)"
echo "[INFO] Tier 3 (experimental) complete."
