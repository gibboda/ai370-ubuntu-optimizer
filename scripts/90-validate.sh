#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
STATUS_FILE="$LATEST_DIR/final-validation.txt"

mkdir -p "$LATEST_DIR"

status="PASS"

check_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    echo "[OK] $file"
  else
    echo "[FAIL] Missing: $file"
    status="FAIL"
  fi
}

echo "[INFO] Running final validation..."

check_file "$LATEST_DIR/hardware.json"
check_file "$LATEST_DIR/gpu-acceleration-status.txt"
check_file "$LATEST_DIR/npu-acceleration-status.txt"
check_file "$LATEST_DIR/ai-stack-status.txt"

echo
echo "[INFO] Checking ONNX Runtime..."

if [[ -x "$PROJECT_ROOT/.ai370-ai/venv/bin/python" ]]; then
  "$PROJECT_ROOT/.ai370-ai/venv/bin/python" -c \
    "import onnxruntime as ort; print('Providers:', ort.get_available_providers())" \
    || status="FAIL"
else
  echo "[FAIL] Python AI environment missing"
  status="FAIL"
fi

echo
echo "Final Status: $status" | tee "$STATUS_FILE"

if [[ "$status" == "FAIL" ]]; then
  exit 3
fi
