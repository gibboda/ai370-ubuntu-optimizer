#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Milestone 2: Open WebUI optional installer / validator.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
VENV_DIR="$AI_ROOT/venv"
STATUS_JSON="$LATEST_DIR/tier2-open-webui.json"
SUMMARY_MD="$LATEST_DIR/tier2-open-webui.md"

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

main() {
  mkdir -p "$LATEST_DIR" "$AI_ROOT"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent Open WebUI service configuration is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local action="none" status="WARN" state="missing" detail="" version="not-run"
  if command -v open-webui >/dev/null 2>&1; then
    state="available"
    action="validated-existing-cli"
  elif command -v docker >/dev/null 2>&1 && docker image ls 2>/dev/null | grep -qi 'open-webui'; then
    state="available"
    action="validated-existing-container-image"
  elif [[ "$OFFLINE" == "true" ]]; then
    action="skipped-offline-optional"
    detail="Open WebUI is optional for Milestone 2. Offline mode does not install it; stage a wheel or container image before rerunning."
  else
    action="pip-install-attempted"
    if [[ ! -x "$VENV_DIR/bin/python" ]]; then
      if ! python3 -m venv "$VENV_DIR" || ! "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel; then
        action="venv-create-failed"
        detail="Failed to create or bootstrap Python venv at $VENV_DIR. Ensure python3-venv and pip are installed."
      fi
    fi
    if [[ -x "$VENV_DIR/bin/python" ]]; then
      "$VENV_DIR/bin/python" -m pip install --upgrade open-webui || detail="Open WebUI pip install failed; see console output."
      if "$VENV_DIR/bin/python" -c 'import importlib.util, sys; sys.exit(0 if importlib.util.find_spec("open_webui") else 1)' >/dev/null 2>&1; then
        state="available"
      fi
    fi
  fi

  if [[ "$state" == "available" ]]; then
    status="PASS"
    if command -v open-webui >/dev/null 2>&1; then
      version="$(open-webui --version 2>&1 || true)"
    else
      version="available"
    fi
  fi
  if [[ -z "$detail" ]]; then
    detail="Open WebUI validation completed. This component is optional and is reported cleanly when missing."
  fi

  local version_json detail_json
  version_json="$(printf '%s' "$version" | json_escape)"
  detail_json="$(printf '%s' "$detail" | json_escape)"
  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 2,
  "phase": "install-open-webui",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $([[ "$OFFLINE" == "true" ]] && echo true || echo false),
  "state": "$state",
  "optional": true,
  "install_action": "$action",
  "version": $version_json,
  "detail": $detail_json
}
EOF_JSON
  {
    echo "# Tier 2 Open WebUI Status"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- State: $state"
    echo "- Optional: true"
    echo "- Install action: $action"
    echo
    printf '```text\n%s\n```\n' "$version"
    echo
    printf '%s\n' "$detail"
  } > "$SUMMARY_MD"

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
}

main "$@"
