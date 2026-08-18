#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M4: NPU stack visibility (module, device nodes, firmware, runtime, backend).
# Visibility only: does not run scripts/230-benchmark-npu.sh or xrt-smi validate.
# Inventory-only 205 (no --accept-amd-acceleration-risk) feeds the runtime ladder.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/npu-venv.sh
source "$PROJECT_ROOT/scripts/lib/npu-venv.sh"

LATEST_DIR="$PROJECT_ROOT/reports/latest"
mkdir -p "$LATEST_DIR"

VISIBILITY_FILE="$LATEST_DIR/s2-m4-npu-runtime-validation.json"
PROFILE_FILE="$LATEST_DIR/s1-m5-system-profile.json"
CHECKS_FILE="$(mktemp "${TMPDIR:-/tmp}/s2-m4-npu-checks.XXXXXX")"
trap 'rm -f "$CHECKS_FILE"' EXIT

npu_kernel_module_loaded() {
  if [[ -r /proc/modules ]] && grep -Eq '^(amdxdna|xrt|xdna)[[:space:]]' /proc/modules 2>/dev/null; then
    return 0
  fi
  if lsmod 2>/dev/null | grep -Eq '^(amdxdna|xrt|xdna)[[:space:]]'; then
    return 0
  fi
  return 1
}

main() {
  echo "[INFO] S2-M4 / s2-m4-validate-npu-stack.sh (visibility only)"
  echo "[INFO] Offline: $OFFLINE"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent NPU configuration not implemented. Use --persistence=runtime."
    exit 2
  fi

  if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "[ERROR] Stage 1 profile missing: $PROFILE_FILE"
    echo "[ERROR] Stage 2 NPU visibility requires the canonical Stage 1 profile (schema version + fingerprint)."
    echo "[ERROR] Run: ./ai370-optimize.sh stage1-probe && ./ai370-optimize.sh stage1-profile"
    exit 2
  fi
  echo "[INFO] Consuming Stage 1 profile: $PROFILE_FILE"

  local module_present="false"
  local device_nodes_present="false"
  local device_nodes=""
  local module_text=""

  if npu_kernel_module_loaded; then
    module_present="true"
    module_text="$(grep -E '^(amdxdna|xrt|xdna)[[:space:]]' /proc/modules 2>/dev/null || true)"
  fi

  device_nodes="$(find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null || true)"
  if [[ -n "$device_nodes" ]]; then
    device_nodes_present="true"
  fi

  echo "[INFO] Inventory-only XRT/Ryzen AI check (205; no package install)"
  bash "$PROJECT_ROOT/scripts/205-install-xrt-ryzen-ai.sh" "$PROFILE" "$MODE" "$PERSISTENCE" "$OFFLINE" "false"

  echo "[INFO] Visibility-only Ryzen AI software check (210; skip xrt-smi validate)"
  bash "$PROJECT_ROOT/scripts/210-check-ryzen-ai-software.sh" "$PROFILE" "$MODE" "$PERSISTENCE" "$OFFLINE" "true"

  echo "[INFO] Vitis AI EP provider listing (220; no inference)"
  bash "$PROJECT_ROOT/scripts/220-check-vitis-ai-ep.sh" "$PROFILE" "$MODE" "$PERSISTENCE" "$OFFLINE"

  python3 - "$CHECKS_FILE" "$module_present" "$device_nodes_present" "$module_text" "$device_nodes" "$LATEST_DIR" <<'PY'
import json
import sys
from pathlib import Path

checks_path = Path(sys.argv[1])
module_present = sys.argv[2] == "true"
device_nodes_present = sys.argv[3] == "true"
module_text = sys.argv[4]
device_text = sys.argv[5]
latest = Path(sys.argv[6])

def load_json(name: str) -> dict:
    path = latest / name
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}

inventory = load_json("xrt-ryzen-ai-install.json")
status = load_json("npu-acceleration-status.json")
capabilities = load_json("npu-capabilities.json")
backend = load_json("vitis-ai-ep-status.json")
runtime = inventory.get("runtime") or {}

xrt_examine = str(capabilities.get("xrt_smi_examine") or "")
xrt_validate = str(capabilities.get("xrt_smi_validate") or "")
runtime_tools = str(status.get("runtime_tools") or runtime.get("xrt") or "")
ryzen_ai = str(runtime.get("ryzen_ai") or "")

runtime_ready = runtime_tools in {"available"} or ryzen_ai in {"available"} or runtime.get("xrt") == "available"

examine_lower = xrt_examine.strip().lower()
if not xrt_examine.strip() or examine_lower in {"not-run", "not-visible"} or examine_lower.startswith("command-not-found"):
    firmware_ready = False if not runtime_ready else None
elif "error" in examine_lower and "firmware" not in examine_lower:
    firmware_ready = False
else:
    firmware_ready = True

providers = backend.get("amd_provider_candidates") or []
provider_smoke = str(backend.get("provider_smoke") or "")
backend_ready = bool(providers) or provider_smoke == "visible"

payload = {
    "module_present": module_present,
    "device_nodes_present": device_nodes_present,
    "firmware_ready": firmware_ready,
    "runtime_ready": runtime_ready,
    "backend_ready": backend_ready,
    "module_text": module_text,
    "device_text": device_text,
    "xrt_smi_validate": xrt_validate,
}
checks_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

  python3 "$PROJECT_ROOT/scripts/s2-m4-publish-npu-visibility.py" \
    --checks "$CHECKS_FILE" \
    --output "$VISIBILITY_FILE" \
    --profile "$PROFILE_FILE"

  local exit_status=0
  exit_status="$(python3 - "$VISIBILITY_FILE" <<'PY'
import json, sys
report = json.loads(open(sys.argv[1], encoding="utf-8").read())
status = report.get("status", "WARN")
print(1 if status == "FAIL" else 0)
PY
)"

  echo "[INFO] Wrote npu-acceleration-status.json, npu-capabilities.json (compat), and s2-m4-npu-runtime-validation.json"
  echo "[INFO] Visibility only; NPU inference remains scripts/230-benchmark-npu.sh until S3-M6."
  echo "[INFO] s2-m4-validate-npu-stack.sh complete."
  exit "$exit_status"
}

main "$@"
