# SPDX-License-Identifier: GPL-3.0-only
# shellcheck shell=bash
#
# Shared offline path helpers for Stage 2 installers (S2-M3 RAG and others).
# Requires PROJECT_ROOT to be set to the repository root before sourcing.
#
# Usage:
#   PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
#   # shellcheck source=lib/offline-paths.sh
#   source "$PROJECT_ROOT/scripts/lib/offline-paths.sh"
#   ai370_load_offline_env
#   path="$(ai370_resolve_path "${OFFLINE_WHEELHOUSE:-.ai370-ai/wheelhouse}")"

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  echo "[ERROR] offline-paths.sh requires PROJECT_ROOT to be set" >&2
  return 1
fi

# Resolve a path that may be absolute or relative to PROJECT_ROOT.
ai370_resolve_path() {
  local p="${1:-}"
  if [[ -z "$p" ]]; then
    printf '%s\n' ""
    return 0
  fi
  if [[ "$p" = /* ]]; then
    printf '%s\n' "$p"
  else
    printf '%s\n' "$PROJECT_ROOT/${p#./}"
  fi
}

# Load configs/offline/ai-runtime.env defaults without clobbering already-set
# environment variables (caller/CI overrides win).
ai370_load_offline_env() {
  local env_file="${1:-$PROJECT_ROOT/configs/offline/ai-runtime.env}"
  [[ -f "$env_file" ]] || return 0

  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip CR, skip blanks and comments
    line="${line//$'\r'/}"
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" != *=* ]] && continue
    key="${line%%=*}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    # Skip if already set in the environment (including empty explicit overrides)
    if [[ -n "${!key+x}" ]]; then
      continue
    fi
    val="${line#*=}"
    val="${val#"${val%%[![:space:]]*}"}"
    # Strip matching single/double quotes
    if [[ "$val" =~ ^\"(.*)\"$ ]]; then
      val="${BASH_REMATCH[1]}"
    elif [[ "$val" =~ ^\'(.*)\'$ ]]; then
      val="${BASH_REMATCH[1]}"
    fi
    printf -v "$key" '%s' "$val"
  done <"$env_file"
}

# First non-empty argument wins; remaining args are ignored once set.
ai370_first_nonempty() {
  local v
  for v in "$@"; do
    if [[ -n "${v:-}" ]]; then
      printf '%s\n' "$v"
      return 0
    fi
  done
  printf '%s\n' ""
}

# Apply S2-M3 / offline runtime path defaults into caller-visible variables.
# Respects explicit env overrides (ANYTHINGLLM_*, EMBEDDING_*, etc.) over OFFLINE_*.
# Exports AI370_* path variables for installers that source this library.
ai370_apply_offline_rag_paths() {
  ai370_load_offline_env

  local default_ai_root="$PROJECT_ROOT/.ai370-ai"
  # Derive AI root from model root parent when only OFFLINE_MODEL_ROOT is set.
  local model_root_raw
  model_root_raw="$(ai370_first_nonempty "${OFFLINE_MODEL_ROOT:-}" ".ai370-ai/models")"
  local model_root_resolved
  model_root_resolved="$(ai370_resolve_path "$model_root_raw")"

  export AI370_AI_ROOT="${AI370_AI_ROOT:-$default_ai_root}"
  if [[ "$model_root_resolved" == */models ]]; then
    AI370_AI_ROOT="$(dirname "$model_root_resolved")"
    export AI370_AI_ROOT
  fi

  export AI370_WHEELHOUSE
  AI370_WHEELHOUSE="$(ai370_resolve_path "$(ai370_first_nonempty "${OFFLINE_WHEELHOUSE:-}" ".ai370-ai/wheelhouse")")"
  export AI370_MODEL_ROOT
  AI370_MODEL_ROOT="$(ai370_resolve_path "$(ai370_first_nonempty "${OFFLINE_MODEL_ROOT:-}" ".ai370-ai/models")")"
  export AI370_TOOL_ROOT
  AI370_TOOL_ROOT="$(ai370_resolve_path "$(ai370_first_nonempty "${OFFLINE_TOOL_ROOT:-}" ".ai370-ai/tools")")"

  local req_raw
  req_raw="$(ai370_first_nonempty "${OFFLINE_REQUIREMENTS:-}" "configs/ai-runtime/requirements-offline.txt")"
  export AI370_OFFLINE_REQ
  AI370_OFFLINE_REQ="$(ai370_resolve_path "$req_raw")"

  # AnythingLLM / RAG
  export AI370_ANYTHINGLLM_STAGED
  AI370_ANYTHINGLLM_STAGED="$(ai370_resolve_path "$(ai370_first_nonempty \
    "${ANYTHINGLLM_STAGED_DIR:-}" \
    "${OFFLINE_ANYTHINGLLM_DIR:-}" \
    ".ai370-ai/offline-artifacts/anythingllm")")"

  export AI370_ANYTHINGLLM_APPIMAGE_DIR
  AI370_ANYTHINGLLM_APPIMAGE_DIR="$(ai370_resolve_path "$(ai370_first_nonempty \
    "${ANYTHINGLLM_APPIMAGE_DIR:-}" \
    "${AI370_TOOL_ROOT}/anythingllm")")"

  export AI370_RAG_DOC_DIR
  AI370_RAG_DOC_DIR="$(ai370_resolve_path "$(ai370_first_nonempty \
    "${ANYTHINGLLM_DOC_DIR:-}" \
    "${OFFLINE_RAG_DOC_DIR:-}" \
    ".ai370-ai/rag/documents")")"

  export AI370_RAG_STORAGE_DIR
  AI370_RAG_STORAGE_DIR="$(ai370_resolve_path "$(ai370_first_nonempty \
    "${ANYTHINGLLM_STORAGE_DIR:-}" \
    "${OFFLINE_RAG_STORAGE_DIR:-}" \
    ".ai370-ai/rag/anythingllm-storage")")"

  # Embeddings
  export AI370_EMBEDDING_STAGED
  AI370_EMBEDDING_STAGED="$(ai370_resolve_path "$(ai370_first_nonempty \
    "${EMBEDDING_STAGED_DIR:-}" \
    "${OFFLINE_EMBEDDING_DIR:-}" \
    ".ai370-ai/offline-artifacts/embedding")")"

  export AI370_EMBEDDING_MODEL_DIR
  AI370_EMBEDDING_MODEL_DIR="$(ai370_resolve_path "$(ai370_first_nonempty \
    "${EMBEDDING_MODEL_DIR:-}" \
    "${AI370_MODEL_ROOT}/embedding/local-embedding-model")")"
}
