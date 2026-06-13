#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 1: AMDXDNA / Ryzen AI NPU detection.
# This script never treats a missing NPU stack as fatal; it cleanly records
# missing module/device/runtime state for later Tier 3 enablement.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

LATEST_DIR="$PROJECT_ROOT/reports/latest"
STATUS_JSON="$LATEST_DIR/tier1-npu.json"
SUMMARY_MD="$LATEST_DIR/tier1-npu.md"
STATUS_TXT="$LATEST_DIR/tier1-npu.txt"
mkdir -p "$LATEST_DIR"

main() {
  echo "[INFO] Tier 1 / 75-detect-npu.sh"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE  Offline: $OFFLINE"

  local module_text device_text npu_present xrt_smi xrt_state status
  module_text="$(detect_npu_module_text)"
  device_text="$(detect_npu_device_text)"
  npu_present="$(detect_npu_present "$module_text" "$device_text")"
  xrt_smi="$(capture_command xrt-smi examine)"

  if [[ "$xrt_smi" == command-not-found:* ]]; then
    xrt_state="missing"
  else
    xrt_state="available"
  fi

  status="PASS"
  if [[ "$npu_present" != "true" ]]; then
    status="WARN"
  fi

  export PROFILE MODE PERSISTENCE OFFLINE module_text device_text npu_present xrt_state xrt_smi status
  python3 - <<'PY' > "$STATUS_JSON"
import json
import os
from datetime import datetime, UTC

print(json.dumps({
    "tier": 1,
    "phase": "detect-npu",
    "timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
    "profile": os.environ.get("PROFILE", "ai370"),
    "mode": os.environ.get("MODE", "safe"),
    "persistence": os.environ.get("PERSISTENCE", "runtime"),
    "offline": os.environ.get("OFFLINE", "false") == "true",
    "status": os.environ.get("status", "WARN"),
    "amdxdna": {
        "present": os.environ.get("npu_present", "false") == "true",
        "module_text": os.environ.get("module_text", ""),
        "device_text": os.environ.get("device_text", ""),
    },
    "xrt": {
        "state": os.environ.get("xrt_state", "missing"),
        "examine_output": os.environ.get("xrt_smi", ""),
    },
    "note": "Missing AMDXDNA/XRT is reported as WARN at Tier 1; Tier 3 owns enablement and benchmarking.",
}, indent=2))
PY

  {
    echo "# Tier 1 AMDXDNA / NPU Detection"
    echo
    echo "**Status:** $status"
    echo
    echo "- AMDXDNA/XDNA present: $npu_present"
    echo "- XRT tools: $xrt_state"
    echo
    echo "## Kernel module evidence"
    printf '%s\n' "${module_text:-none detected}"
    echo
    echo "## Device node evidence"
    printf '%s\n' "${device_text:-none detected}"
    echo
    echo "Missing AMDXDNA or XRT is not fatal in Tier 1. Tier 3 performs software enablement and benchmarking."
  } > "$SUMMARY_MD"

  echo "$status" > "$STATUS_TXT"
  echo "[INFO] Wrote tier1-npu.*"
  echo "[INFO] 75-detect-npu.sh complete."
}

main "$@"
