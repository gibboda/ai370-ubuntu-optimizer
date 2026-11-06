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

LATEST_DIR="${LATEST_DIR:-$PROJECT_ROOT/reports/latest}"
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

  if [[ "${AI370_SKIP_NPU_INVENTORY:-false}" != "true" ]]; then
    echo "[INFO] Inventory-only XRT/Ryzen AI check (205; no package install)"
    bash "$PROJECT_ROOT/scripts/205-install-xrt-ryzen-ai.sh" "$PROFILE" "$MODE" "$PERSISTENCE" "$OFFLINE" "false"

    echo "[INFO] Visibility-only Ryzen AI software check (210; skip xrt-smi validate)"
    bash "$PROJECT_ROOT/scripts/210-check-ryzen-ai-software.sh" "$PROFILE" "$MODE" "$PERSISTENCE" "$OFFLINE" "true"

    echo "[INFO] Vitis AI EP provider listing (220; no inference)"
    bash "$PROJECT_ROOT/scripts/220-check-vitis-ai-ep.sh" "$PROFILE" "$MODE" "$PERSISTENCE" "$OFFLINE"
  else
    echo "[INFO] Skipping 205/210/220 inventory (AI370_SKIP_NPU_INVENTORY=true)"
  fi

  python3 "$PROJECT_ROOT/scripts/s2-m4-build-npu-checks.py" \
    --output "$CHECKS_FILE" \
    --latest-dir "$LATEST_DIR" \
    --module-present "$module_present" \
    --device-nodes-present "$device_nodes_present" \
    --module-text "$module_text" \
    --device-text "$device_nodes"

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
