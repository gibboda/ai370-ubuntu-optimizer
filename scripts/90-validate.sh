#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
STATUS_FILE="$LATEST_DIR/final-validation.txt"

status="PASS"

check_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    echo "[INFO] Found: $file"
  else
    echo "[ERROR] Missing: $file"
    status="FAIL"
  fi
}

main() {
  mkdir -p "$LATEST_DIR"

  exec > >(tee "$STATUS_FILE") 2>&1

  echo "[INFO] Running final validation (profile=${PROFILE} mode=${MODE} persistence=${PERSISTENCE})..."

  check_file "$LATEST_DIR/hardware-inventory.json"
  check_file "$LATEST_DIR/firmware-baseline.json"
  check_file "$LATEST_DIR/hardware.json"
  check_file "$LATEST_DIR/baseline-plan.json"
  check_file "$LATEST_DIR/baseline-postcheck.json"
  check_file "$LATEST_DIR/baseline-validation.txt"
  check_file "$LATEST_DIR/system-tuning-plan.json"
  check_file "$LATEST_DIR/gpu-acceleration-status.txt"
  check_file "$LATEST_DIR/npu-acceleration-status.txt"
  check_file "$LATEST_DIR/ai-stack-status.txt"
  check_file "$LATEST_DIR/llm-validation.json"
  check_file "$LATEST_DIR/comfyui-status.txt"
  check_file "$LATEST_DIR/comfyui-benchmark.csv"

  printf '\n'
  echo "[INFO] Checking ONNX Runtime..."

  if [[ -x "$PROJECT_ROOT/.ai370-ai/venv/bin/python" ]]; then
    "$PROJECT_ROOT/.ai370-ai/venv/bin/python" -c \
      "import onnxruntime as ort; print('Providers:', ort.get_available_providers())" \
      || { echo "[ERROR] ONNX Runtime check failed"; status="FAIL"; }
  else
    echo "[ERROR] Python AI environment missing: $PROJECT_ROOT/.ai370-ai/venv/bin/python"
    status="FAIL"
  fi

  printf '\n'
  echo "Final Status: $status"

  if [[ "$status" == "FAIL" ]]; then
    exit 3
  fi
}

main "$@"
