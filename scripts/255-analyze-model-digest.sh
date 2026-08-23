#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S3-M4 diagnostics: Analyze staged/local ONNX models via Digest AI or ONNX fallback.
# Produces reports/latest/digest-model-report.md and digest-analysis.json.
# NEVER claims NPU execution from analysis statistics.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/offline-paths.sh
source "$PROJECT_ROOT/scripts/lib/offline-paths.sh"
ai370_load_offline_env

LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$(ai370_resolve_path "${OFFLINE_MODEL_ROOT:-.ai370-ai/models}")"
if [[ "$AI_ROOT" == */models ]]; then
  MODEL_ROOT="$AI_ROOT"
  AI_ROOT="$(dirname "$AI_ROOT")"
else
  MODEL_ROOT="$(ai370_resolve_path ".ai370-ai/models")"
  AI_ROOT="$PROJECT_ROOT/.ai370-ai"
fi

DIGEST_VENV="$(ai370_resolve_path "$(ai370_first_nonempty "${DIGEST_VENV_DIR:-}" "${OFFLINE_DIGEST_VENV:-}" ".ai370-ai/digest/venv")")"
STAGED_MODELS="$(ai370_resolve_path "$(ai370_first_nonempty "${DIGEST_MODEL_PATH:-}" "${OFFLINE_DIGEST_MODEL_DIR:-}" ".ai370-ai/models")")"
OUT_DIR="$LATEST_DIR/digest-analysis"
STATUS_JSON="$LATEST_DIR/digest-analysis.json"
# Roadmap name
REPORT_MD="$LATEST_DIR/digest-model-report.md"
INSTALL_JSON="$LATEST_DIR/digest-ai-status.json"
HELPER="$PROJECT_ROOT/scripts/lib/digest_analyze.py"

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }
bool_json() { [[ "$1" == "true" ]] && echo true || echo false; }

select_python() {
  # Prefer digest venv (native), then shared AI venv, then system python3
  if [[ -x "$DIGEST_VENV/bin/python" ]]; then
    printf '%s\n' "$DIGEST_VENV/bin/python"
    return 0
  fi
  if [[ -x "$AI_ROOT/venv/bin/python" ]]; then
    printf '%s\n' "$AI_ROOT/venv/bin/python"
    return 0
  fi
  command -v python3
}

main() {
  mkdir -p "$LATEST_DIR" "$OUT_DIR"

  if [[ ! -f "$HELPER" ]]; then
    echo "[ERROR] Missing helper $HELPER"
    exit 2
  fi

  local py
  py="$(select_python)"

  # Build model search roots (explicit env first)
  local roots=()
  if [[ -n "${DIGEST_MODEL_PATH:-}" ]]; then
    roots+=("${DIGEST_MODEL_PATH}")
  fi
  roots+=("$STAGED_MODELS")
  roots+=("$MODEL_ROOT")
  # Optional: tiny onnx samples under models only — avoid site-packages

  # Create a tiny synthetic ONNX if none exist and we can write one (for smoke only)
  local model_args=()
  local r
  for r in "${roots[@]}"; do
    model_args+=(--model "$r")
  done

  echo "[INFO] Analyzing models with $py (Digest AI if importable, else ONNX fallback)..."
  local helper_out
  set +e
  helper_out="$("$py" "$HELPER" \
    "${model_args[@]}" \
    --out-dir "$OUT_DIR" \
    --report-json "$STATUS_JSON" \
    --report-md "$REPORT_MD" \
    --limit "${DIGEST_MODEL_LIMIT:-5}" \
    --profile "$PROFILE" \
    --mode "$MODE" \
    --offline "$OFFLINE" 2>&1)"
  local rc=$?
  set -e
  printf '%s\n' "$helper_out"

  # If no models found, try generating a minimal ONNX smoke model offline
  local models_analyzed="0"
  if [[ -f "$STATUS_JSON" ]]; then
    models_analyzed="$(python3 -c 'import json; print(json.load(open("'"$STATUS_JSON"'")).get("models_analyzed",0))' 2>/dev/null || echo 0)"
  fi

  if [[ "$models_analyzed" == "0" ]]; then
    local smoke_dir="$AI_ROOT/models/digest-smoke"
    mkdir -p "$smoke_dir"
    local smoke_model="$smoke_dir/matmul_smoke.onnx"
    if "$py" - "$smoke_model" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
try:
    import numpy as np
    import onnx
    from onnx import TensorProto, helper, numpy_helper

    X = helper.make_tensor_value_info("X", TensorProto.FLOAT, [1, 64])
    Y = helper.make_tensor_value_info("Y", TensorProto.FLOAT, [1, 64])
    W = numpy_helper.from_array(np.eye(64, dtype=np.float32), name="W")
    node = helper.make_node("MatMul", ["X", "W"], ["Y"])
    graph = helper.make_graph([node], "matmul_smoke", [X], [Y], [W])
    model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 13)])
    model.ir_version = 8
    onnx.checker.check_model(model)
    onnx.save(model, str(path))
    print("wrote", path)
except Exception as e:
    print("smoke-model-failed", e)
    sys.exit(1)
PY
    then
      echo "[INFO] Created smoke ONNX model at $smoke_model; re-running analysis..."
      "$py" "$HELPER" \
        --model "$smoke_model" \
        --out-dir "$OUT_DIR" \
        --report-json "$STATUS_JSON" \
        --report-md "$REPORT_MD" \
        --limit 1 \
        --profile "$PROFILE" \
        --mode "$MODE" \
        --offline "$OFFLINE" || true
    fi
  fi

  # Enrich status with install report linkage
  if [[ -f "$STATUS_JSON" ]]; then
    python3 - "$STATUS_JSON" "$INSTALL_JSON" <<'PY'
import json, sys
from pathlib import Path
status_path, install_path = Path(sys.argv[1]), Path(sys.argv[2])
data = json.loads(status_path.read_text(encoding="utf-8"))
install_status = "missing"
if install_path.exists():
    try:
        install_status = json.loads(install_path.read_text(encoding="utf-8")).get("status", "missing")
    except Exception:
        pass
data["install_report_status"] = install_status
data["npu_execution_claimed"] = False
data["policy"] = "Diagnostics only. Digest/ONNX stats are never NPU inference proof."
status_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(data.get("status"), "models=", data.get("models_analyzed"), "detail=", (data.get("detail") or "")[:120])
PY
  fi

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $REPORT_MD"
  echo "[INFO] Analysis artifacts under $OUT_DIR"

  local final_status="WARN"
  if [[ -f "$STATUS_JSON" ]]; then
    final_status="$(python3 -c 'import json; print(json.load(open("'"$STATUS_JSON"'")).get("status","WARN"))' 2>/dev/null || echo WARN)"
  fi
  if [[ "$final_status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
