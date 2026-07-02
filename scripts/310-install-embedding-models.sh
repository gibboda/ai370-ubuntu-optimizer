#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M3: Local Embedding Models installer / validator.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
VENV_DIR="$AI_ROOT/venv"
MODEL_DIR="$AI_ROOT/models/embedding/local-embedding-model"
STATUS_JSON="$LATEST_DIR/tier4-embedding-models.json"
SUMMARY_MD="$LATEST_DIR/tier4-embedding-models.md"

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

main() {
  mkdir -p "$LATEST_DIR" "$(dirname "$MODEL_DIR")"

  if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    echo "[INFO] Creating basic AI venv for embedding downloads..."
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
  fi

  local state="missing" action="none" status="WARN" detail="" model_downloaded="false"

  # We need huggingface_hub in order to execute the download
  if [[ "$OFFLINE" != "true" ]]; then
    echo "[INFO] Ensuring huggingface-hub is installed in venv..."
    "$VENV_DIR/bin/python" -m pip install huggingface-hub transformers safetensors >/dev/null 2>&1 || true
  fi

  # Check if model config.json and vocabulary files are present locally
  if [[ -f "$MODEL_DIR/config.json" ]] && { [[ -f "$MODEL_DIR/model.safetensors" ]] || [[ -f "$MODEL_DIR/pytorch_model.bin" ]]; }; then
    state="available"
    action="validated-existing-model"
  elif [[ "$OFFLINE" == "true" ]]; then
    action="skipped-offline"
    detail="Offline mode: Local embedding model is missing from $MODEL_DIR, and cannot be downloaded offline."
  else
    action="download-attempted"
    echo "[INFO] Downloading sentence-transformers/all-MiniLM-L6-v2 via huggingface-hub..."
    if "$VENV_DIR/bin/python" - <<PY
import sys
from huggingface_hub import snapshot_download
try:
    snapshot_download(
        repo_id="sentence-transformers/all-MiniLM-L6-v2",
        local_dir="$MODEL_DIR",
        local_dir_use_symlinks=False
    )
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
PY
    then
      if [[ -f "$MODEL_DIR/config.json" ]] && { [[ -f "$MODEL_DIR/model.safetensors" ]] || [[ -f "$MODEL_DIR/pytorch_model.bin" ]]; }; then
        state="available"
        model_downloaded="true"
      else
        detail="Download completed but critical model files (config.json, model.safetensors) are missing from $MODEL_DIR."
      fi
    else
      detail="Failed to download embedding model. Check your internet connection or Hugging Face access."
    fi
  fi

  if [[ "$state" == "available" ]]; then
    status="PASS"
  fi
  if [[ -z "$detail" ]]; then
    detail="Local embedding model validation completed."
  fi

  local detail_json
  detail_json="$(printf '%s' "$detail" | json_escape)"
  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 4,
  "phase": "install-embedding-models",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $([[ "$OFFLINE" == "true" ]] && echo true || echo false),
  "state": "$state",
  "model_downloaded": $model_downloaded,
  "model_path": "$MODEL_DIR",
  "install_action": "$action",
  "detail": $detail_json
}
EOF_JSON

  {
    echo "# Tier 4 Embedding Model Status"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- State: $state"
    echo "- Model Path: $MODEL_DIR"
    echo "- Action: $action"
    echo
    printf '%s\n' "$detail"
  } > "$SUMMARY_MD"

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
}

main "$@"
