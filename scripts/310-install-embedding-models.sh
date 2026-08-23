#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S4-M3: Local embedding model installer / validator with offline lifecycle.
# Prefer already-installed model, then staged copy, then online download.
# Offline package installs use .ai370-ai/wheelhouse when present.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/offline-paths.sh
source "$PROJECT_ROOT/scripts/lib/offline-paths.sh"
ai370_apply_offline_rag_paths

LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$AI370_AI_ROOT"
VENV_DIR="${EMBEDDING_VENV_DIR:-$AI_ROOT/venv}"
WHEELHOUSE="$AI370_WHEELHOUSE"
MODEL_DIR="$AI370_EMBEDDING_MODEL_DIR"
STAGED_MODEL_DIRS=(
  "$AI370_EMBEDDING_STAGED"
  "$AI370_MODEL_ROOT/staging/embedding"
  "$AI370_MODEL_ROOT/staging/local-embedding-model"
)
HF_REPO="${EMBEDDING_HF_REPO:-sentence-transformers/all-MiniLM-L6-v2}"
STATUS_JSON="$LATEST_DIR/tier4-embedding-models.json"
SUMMARY_MD="$LATEST_DIR/tier4-embedding-models.md"
PACKAGES_FILE="$LATEST_DIR/tier4-embedding-models-packages.txt"
OFFLINE_REQ="$AI370_OFFLINE_REQ"
OFFLINE_CONFIG="$PROJECT_ROOT/configs/offline/ai-runtime.env"
# torch is required for AutoModel inference in 320-validate-rag.sh
REQUIRED_EMBEDDING_PKGS=(torch transformers safetensors numpy huggingface-hub)

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }
bool_json() { [[ "$1" == "true" ]] && echo true || echo false; }

embedding_packages_ok() {
  [[ -x "$VENV_DIR/bin/python" ]] || return 1
  "$VENV_DIR/bin/python" -c 'import torch, transformers, safetensors, numpy' >/dev/null 2>&1
}

model_files_present() {
  local dir="$1"
  [[ -f "$dir/config.json" ]] && { [[ -f "$dir/model.safetensors" ]] || [[ -f "$dir/pytorch_model.bin" ]]; }
}

find_staged_model() {
  local d
  for d in "${STAGED_MODEL_DIRS[@]}"; do
    if model_files_present "$d"; then
      printf '%s\n' "$d"
      return 0
    fi
    # Nested single-model directory
    if [[ -d "$d" ]]; then
      local child
      shopt -s nullglob
      for child in "$d"/*; do
        if [[ -d "$child" ]] && model_files_present "$child"; then
          printf '%s\n' "$child"
          shopt -u nullglob
          return 0
        fi
      done
      shopt -u nullglob
    fi
  done
  return 1
}

ensure_venv() {
  if [[ -x "$VENV_DIR/bin/python" ]]; then
    return 0
  fi
  echo "[INFO] Creating AI venv for embedding tooling at $VENV_DIR ..."
  python3 -m venv "$VENV_DIR"
  "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
}

pip_install_deps() {
  # Include torch: retrieval smoke and AutoModel.from_pretrained require it.
  local pkgs=("${REQUIRED_EMBEDDING_PKGS[@]}")
  if [[ "$OFFLINE" == "true" ]]; then
    if [[ -d "$WHEELHOUSE" ]] && compgen -G "$WHEELHOUSE/*" >/dev/null 2>&1; then
      echo "[INFO] Installing embedding deps (incl. torch) from wheelhouse $WHEELHOUSE ..."
      if [[ -f "$OFFLINE_REQ" ]]; then
        "$VENV_DIR/bin/python" -m pip install --no-index --find-links="$WHEELHOUSE" -r "$OFFLINE_REQ" >/dev/null 2>&1 || true
      fi
      "$VENV_DIR/bin/python" -m pip install --no-index --find-links="$WHEELHOUSE" "${pkgs[@]}" >/dev/null 2>&1 || true
      return 0
    fi
    echo "[INFO] Offline mode: no wheelhouse packages installed; using existing venv packages if present."
    return 0
  fi
  echo "[INFO] Ensuring embedding Python packages (incl. torch) in venv..."
  "$VENV_DIR/bin/python" -m pip install "${pkgs[@]}" >/dev/null 2>&1 || true
}

copy_staged_model() {
  local src="$1"
  mkdir -p "$(dirname "$MODEL_DIR")"
  if [[ -e "$MODEL_DIR" && "$MODEL_DIR" -ef "$src" ]]; then
    return 0
  fi
  if model_files_present "$MODEL_DIR"; then
    return 0
  fi
  echo "[INFO] Copying staged embedding model from $src -> $MODEL_DIR ..."
  mkdir -p "$MODEL_DIR"
  # Prefer rsync when available for partial trees; fall back to cp.
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$src"/ "$MODEL_DIR"/
  else
    rm -rf "$MODEL_DIR"
    mkdir -p "$MODEL_DIR"
    cp -a "$src"/. "$MODEL_DIR"/
  fi
}

main() {
  mkdir -p "$LATEST_DIR" "$(dirname "$MODEL_DIR")" "$AI370_EMBEDDING_STAGED" \
    "$AI370_MODEL_ROOT/staging/embedding"

  local state="missing" action="none" status="WARN" detail=""
  local model_downloaded="false" model_staged_from="" offline_ready="false"
  local packages_ok="false" recommendations=()

  ensure_venv
  pip_install_deps

  local installed_packages_json="[]" required_packages_json
  required_packages_json="$(printf '%s\n' "${REQUIRED_EMBEDDING_PKGS[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
  if [[ -x "$VENV_DIR/bin/python" ]]; then
    echo "[INFO] Recording installed Python packages (pip freeze)..."
    "$VENV_DIR/bin/python" -m pip freeze 2>/dev/null | tee "$VENV_DIR/requirements.txt" >"$PACKAGES_FILE" || true
    installed_packages_json="$("$VENV_DIR/bin/python" - <<PY
import json
try:
    reqs = [l.strip() for l in open(r"$VENV_DIR/requirements.txt", encoding="utf-8") if l.strip()]
except Exception:
    reqs = []
print(json.dumps(reqs))
PY
)"
    if embedding_packages_ok; then
      packages_ok="true"
    fi
  fi

  if model_files_present "$MODEL_DIR"; then
    state="available"
    action="validated-existing-model"
  else
    local staged=""
    if staged="$(find_staged_model)"; then
      action="copy-staged-model"
      if copy_staged_model "$staged" && model_files_present "$MODEL_DIR"; then
        state="available"
        model_staged_from="$staged"
        action="installed-from-staged"
      else
        detail="Staged embedding model found at $staged but copy/validation into $MODEL_DIR failed."
        action="staged-copy-failed"
      fi
    elif [[ "$OFFLINE" == "true" ]]; then
      action="skipped-offline-missing-model"
      detail="Offline mode: embedding model missing at $MODEL_DIR and no staged model under $AI370_EMBEDDING_STAGED or $AI370_MODEL_ROOT/staging/embedding."
      recommendations+=(
        "Copy a sentence-transformers model directory (with config.json and model.safetensors) to $MODEL_DIR"
        "Or stage under $AI370_EMBEDDING_STAGED then rerun with --offline"
      )
    else
      action="download-attempted"
      echo "[INFO] Downloading $HF_REPO via huggingface-hub into $MODEL_DIR ..."
      if "$VENV_DIR/bin/python" - <<PY
import sys
from huggingface_hub import snapshot_download
try:
    snapshot_download(
        repo_id="$HF_REPO",
        local_dir="$MODEL_DIR",
        local_dir_use_symlinks=False,
    )
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
PY
      then
        if model_files_present "$MODEL_DIR"; then
          state="available"
          model_downloaded="true"
          action="downloaded-model"
        else
          detail="Download completed but critical model files (config.json + weights) are missing from $MODEL_DIR."
        fi
      else
        detail="Failed to download embedding model $HF_REPO. Check network/Hugging Face access, or stage the model offline."
        recommendations+=("Offline fallback: snapshot the model on a connected host into $AI370_EMBEDDING_STAGED then rerun with --offline.")
      fi
    fi
  fi

  if [[ "$state" == "available" ]]; then
    offline_ready="true"
    if [[ "$packages_ok" == "true" ]]; then
      status="PASS"
    else
      status="WARN"
      detail="${detail:+$detail }Model files are present but required packages (torch, transformers, safetensors, numpy) are missing from $VENV_DIR. Stage wheels under $WHEELHOUSE or install online."
      recommendations+=("Populate $WHEELHOUSE (including torch) and rerun with --offline, or install packages online once.")
    fi
  fi

  if [[ -z "$detail" ]]; then
    if [[ "$status" == "PASS" ]]; then
      detail="Local embedding model is available at $MODEL_DIR and required Python packages (torch, transformers, safetensors, numpy) are importable."
    else
      detail="Local embedding model validation completed with limitations."
    fi
  fi

  local rec_json="[]"
  if ((${#recommendations[@]} > 0)); then
    rec_json="$(printf '%s\n' "${recommendations[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
  fi

  local detail_json staged_json model_path_json
  detail_json="$(printf '%s' "$detail" | json_escape)"
  staged_json="$(printf '%s' "$model_staged_from" | json_escape)"
  model_path_json="$(printf '%s' "$MODEL_DIR" | json_escape)"

  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 4,
  "phase": "install-embedding-models",
  "milestone": "S4-M3",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $(bool_json "$OFFLINE"),
  "state": "$state",
  "offline_ready": $(bool_json "$offline_ready"),
  "packages_ok": $(bool_json "$packages_ok"),
  "required_packages": $required_packages_json,
  "model_downloaded": $(bool_json "$model_downloaded"),
  "model_path": $model_path_json,
  "model_staged_from": $staged_json,
  "embedding_staged_dir": $(printf '%s' "$AI370_EMBEDDING_STAGED" | json_escape),
  "hf_repo": $(printf '%s' "$HF_REPO" | json_escape),
  "wheelhouse": $(printf '%s' "$WHEELHOUSE" | json_escape),
  "venv": $(printf '%s' "$VENV_DIR" | json_escape),
  "offline_config": $(printf '%s' "$OFFLINE_CONFIG" | json_escape),
  "offline_requirements": $(printf '%s' "$OFFLINE_REQ" | json_escape),
  "path_sources": {
    "model_path": "EMBEDDING_MODEL_DIR | OFFLINE_MODEL_ROOT/embedding/local-embedding-model",
    "embedding_staged_dir": "EMBEDDING_STAGED_DIR | OFFLINE_EMBEDDING_DIR",
    "wheelhouse": "OFFLINE_WHEELHOUSE"
  },
  "install_action": "$action",
  "detail": $detail_json,
  "recommendations": $rec_json,
  "installed_packages_file": $(printf '%s' "$PACKAGES_FILE" | json_escape),
  "installed_packages": $installed_packages_json
}
EOF_JSON

  {
    echo "# Stage 4 RAG — Embedding Model Status (S4-M3)"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- State: $state"
    echo "- Offline-ready: $offline_ready"
    echo "- Packages OK: $packages_ok (requires: ${REQUIRED_EMBEDDING_PKGS[*]})"
    echo "- Model path: $MODEL_DIR"
    echo "- Staged dir: $AI370_EMBEDDING_STAGED"
    echo "- Staged from: ${model_staged_from:-n/a}"
    echo "- Wheelhouse: $WHEELHOUSE"
    echo "- Offline config: $OFFLINE_CONFIG"
    echo "- Action: $action"
    echo
    printf '%s\n' "$detail"
    if ((${#recommendations[@]} > 0)); then
      echo
      echo "## Recommendations"
      local r
      for r in "${recommendations[@]}"; do
        echo "- $r"
      done
    fi
    echo
    echo "## Offline staging"
    echo
    echo '```bash'
    echo "# Copy a local sentence-transformers tree:"
    echo "mkdir -p $AI370_EMBEDDING_STAGED"
    echo "cp -a /path/to/all-MiniLM-L6-v2/. $AI370_EMBEDDING_STAGED/"
    echo "./scripts/310-install-embedding-models.sh $PROFILE $MODE $PERSISTENCE true"
    echo '```'
  } > "$SUMMARY_MD"

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
