#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
MODEL_ROOT="$AI_ROOT/models"
TOOL_ROOT="$AI_ROOT/tools"
STATUS_TXT="$LATEST_DIR/llm-validation-status.txt"
STATUS_JSON="$LATEST_DIR/llm-validation.json"
SUMMARY_MD="$LATEST_DIR/llm-validation.md"

capture_command() {
  local command_name="$1"
  shift
  if command -v "$command_name" >/dev/null 2>&1; then
    "$command_name" "$@" 2>&1 || true
  else
    echo "command-not-found: $command_name"
  fi
}

find_llama_binary() {
  local candidate
  for candidate in \
    "$TOOL_ROOT/llama-cli" \
    "$TOOL_ROOT/llama.cpp/llama-cli" \
    "$TOOL_ROOT/llama.cpp/build/bin/llama-cli" \
    "$TOOL_ROOT/main" \
    "$TOOL_ROOT/llama.cpp/main" \
    "$TOOL_ROOT/llama.cpp/build/bin/main"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  if command -v llama-cli >/dev/null 2>&1; then
    command -v llama-cli
  fi
}

main() {
  echo "[INFO] Phase 7: Ollama / llama.cpp validation"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"
  echo "[INFO] Offline: $OFFLINE"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent LLM runtime configuration is not implemented yet. Use --persistence=runtime."
    exit 2
  fi

  mkdir -p "$LATEST_DIR"

  local ollama_state ollama_version ollama_list llama_binary llama_state llama_version gguf_files status
  ollama_version="$(capture_command ollama --version)"
  ollama_list="$(capture_command ollama list)"
  if [[ "$ollama_version" == command-not-found:* ]]; then
    ollama_state="missing"
  else
    ollama_state="available"
  fi

  llama_binary="$(find_llama_binary || true)"
  if [[ -n "$llama_binary" ]]; then
    llama_state="available"
    llama_version="$($llama_binary --version 2>&1 || true)"
  else
    llama_state="missing"
    llama_version="not-run"
  fi

  gguf_files="$(find "$MODEL_ROOT" "$TOOL_ROOT" -maxdepth 5 -type f -iname '*.gguf' 2>/dev/null || true)"

  status="PASS"
  if [[ "$ollama_state" == "missing" && "$llama_state" == "missing" ]]; then
    status="WARN"
  fi
  if [[ -z "$gguf_files" && "$ollama_list" != *"NAME"* ]]; then
    status="WARN"
  fi

  {
    echo "LLM Validation Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
    echo "Status: $status"
    echo "Timestamp: $(date -Is)"
    echo
    echo "ollama: $ollama_state"
    echo "llama_cpp: $llama_state"
    echo "llama_binary: ${llama_binary:-not-found}"
    echo "gguf_models: $([[ -n "$gguf_files" ]] && echo present || echo missing)"
  } > "$STATUS_TXT"

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" STATUS="$status" \
  OLLAMA_STATE="$ollama_state" OLLAMA_VERSION="$ollama_version" OLLAMA_LIST="$ollama_list" \
  LLAMA_STATE="$llama_state" LLAMA_BINARY="${llama_binary:-}" LLAMA_VERSION="$llama_version" GGUF_FILES="$gguf_files" \
  python3 - "$STATUS_JSON" <<'PY'
import json
import os
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(json.dumps({
    "profile": os.environ["PROFILE"],
    "mode": os.environ["MODE"],
    "persistence": os.environ["PERSISTENCE"],
    "offline": os.environ["OFFLINE"] == "true",
    "status": os.environ["STATUS"],
    "ollama": {
        "state": os.environ["OLLAMA_STATE"],
        "version": os.environ.get("OLLAMA_VERSION", ""),
        "list": os.environ.get("OLLAMA_LIST", ""),
    },
    "llama_cpp": {
        "state": os.environ["LLAMA_STATE"],
        "binary": os.environ.get("LLAMA_BINARY", ""),
        "version": os.environ.get("LLAMA_VERSION", ""),
    },
    "gguf_models": [line for line in os.environ.get("GGUF_FILES", "").splitlines() if line.strip()],
    "policy": "local validation only; no model downloads or runtime installs are attempted",
}, indent=2) + "\n")
PY

  {
    echo "# Ollama / llama.cpp Validation"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "## Ollama"
    echo
    echo "- State: $ollama_state"
    echo
    printf '```text\n%s\n```\n' "$ollama_version"
    echo
    echo "## Ollama local models"
    echo
    printf '```text\n%s\n```\n' "$ollama_list"
    echo
    echo "## llama.cpp"
    echo
    echo "- State: $llama_state"
    echo "- Binary: ${llama_binary:-not-found}"
    echo
    printf '```text\n%s\n```\n' "$llama_version"
    echo
    echo "## Local GGUF models"
    echo
    printf '```text\n%s\n```\n' "${gguf_files:-none}"
    echo
    echo "## Policy"
    echo
    echo "This phase validates locally available Ollama and llama.cpp assets only. It does not download models, pull Ollama manifests, clone llama.cpp, or install runtime packages."
  } > "$SUMMARY_MD"

  echo "[INFO] LLM validation status: $status"
  echo "[INFO] Wrote $STATUS_TXT"
  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
}

main "$@"
