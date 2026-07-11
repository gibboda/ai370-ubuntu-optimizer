#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Milestone 2: Ollama installer / validator.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
MODEL_ROOT="$AI_ROOT/models"
STATUS_JSON="$LATEST_DIR/tier2-ollama.json"
SUMMARY_MD="$LATEST_DIR/tier2-ollama.md"
OLLAMA_INSTALL_URL="${OLLAMA_INSTALL_URL:-https://ollama.com/install.sh}"

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

main() {
  mkdir -p "$LATEST_DIR" "$MODEL_ROOT/ollama"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent Ollama service configuration is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local action="none" status="WARN" state="missing" version="command-not-found: ollama" models="not-run" detail=""
  if command -v ollama >/dev/null 2>&1; then
    state="available"
    action="validated-existing"
  elif [[ "$OFFLINE" == "true" ]]; then
    action="skipped-offline-missing-binary"
    detail="Offline mode: install Ollama ahead of time or stage a local runtime; no network install attempted."
  else
    action="online-install-attempted"
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL "$OLLAMA_INSTALL_URL" | sh || detail="Ollama installer failed; see console output."
      if command -v ollama >/dev/null 2>&1; then
        state="available"
      fi
    else
      detail="curl is required for online Ollama installation."
    fi
  fi

  if [[ "$state" == "available" ]]; then
    status="PASS"
    version="$(ollama --version 2>&1 || true)"
    models="$(ollama list 2>&1 || true)"
  fi
  if [[ -z "$detail" ]]; then
    detail="Ollama validation completed. Local model execution is validated by scripts/140-benchmark-llm.sh when a model is present."
  fi

  local version_json models_json detail_json
  version_json="$(printf '%s' "$version" | json_escape)"
  models_json="$(printf '%s' "$models" | json_escape)"
  detail_json="$(printf '%s' "$detail" | json_escape)"
  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 2,
  "phase": "install-ollama",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $([[ "$OFFLINE" == "true" ]] && echo true || echo false),
  "state": "$state",
  "install_action": "$action",
  "version": $version_json,
  "models": $models_json,
  "model_root": "$MODEL_ROOT/ollama",
  "detail": $detail_json
}
EOF_JSON
  {
    echo "# Tier 2 Ollama Status"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- State: $state"
    echo "- Install action: $action"
    echo "- Model root: $MODEL_ROOT/ollama"
    echo
    printf '```text\n%s\n```\n' "$version"
    echo
    printf '```text\n%s\n```\n' "$models"
    echo
    printf '%s\n' "$detail"
  } > "$SUMMARY_MD"

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
