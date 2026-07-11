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
VENV_DIR="${OPEN_WEBUI_VENV_DIR:-$AI_ROOT/open-webui-venv}"
STATUS_JSON="$LATEST_DIR/tier2-open-webui.json"
SUMMARY_MD="$LATEST_DIR/tier2-open-webui.md"
OPEN_WEBUI_MIN_PYTHON="3.11"
OPEN_WEBUI_MAX_PYTHON_EXCLUSIVE="3.13"

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

python_version() {
  "$1" - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")
PY
}

python_supports_open_webui() {
  "$1" - <<'PY'
import sys
version = sys.version_info
sys.exit(0 if (3, 11) <= (version.major, version.minor) < (3, 13) else 1)
PY
}

select_open_webui_python() {
  local candidates=()
  if [[ -n "${OPEN_WEBUI_PYTHON:-}" ]]; then
    candidates+=("$OPEN_WEBUI_PYTHON")
  fi
  candidates+=(python3.12 python3.11 python3)

  local candidate
  for candidate in "${candidates[@]}"; do
    if command -v "$candidate" >/dev/null 2>&1 && python_supports_open_webui "$candidate"; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

main() {
  mkdir -p "$LATEST_DIR" "$AI_ROOT"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent Open WebUI service configuration is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local action="none" status="WARN" state="missing" detail="" version="not-run" python_runtime="not-selected"
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
    local selected_python="" venv_ready="true"
    if [[ ! -x "$VENV_DIR/bin/python" ]]; then
      if selected_python="$(select_open_webui_python)"; then
        python_runtime="$selected_python ($(python_version "$selected_python"))"
      else
        action="skipped-python-version"
        detail="Open WebUI currently publishes wheels for Python >=$OPEN_WEBUI_MIN_PYTHON,<${OPEN_WEBUI_MAX_PYTHON_EXCLUSIVE}. No compatible interpreter was found. Install Python 3.11 or 3.12, set OPEN_WEBUI_PYTHON to that interpreter, or stage an Open WebUI container image."
      fi
      if [[ -n "$selected_python" ]] && { ! "$selected_python" -m venv "$VENV_DIR" || ! "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel; }; then
        action="venv-create-failed"
        venv_ready="false"
        detail="Failed to create or bootstrap Python venv at $VENV_DIR. Ensure python3-venv and pip are installed."
      fi
    fi
    if [[ "$venv_ready" == "true" && -x "$VENV_DIR/bin/python" ]]; then
      python_runtime="$VENV_DIR/bin/python ($(python_version "$VENV_DIR/bin/python"))"
      if python_supports_open_webui "$VENV_DIR/bin/python"; then
        "$VENV_DIR/bin/python" -m pip install --upgrade open-webui || detail="Open WebUI pip install failed; see console output."
        if "$VENV_DIR/bin/python" -c 'import importlib.util, sys; sys.exit(0 if importlib.util.find_spec("open_webui") else 1)' >/dev/null 2>&1; then
          state="available"
        fi
      elif [[ -z "$detail" ]]; then
        action="skipped-python-version"
        detail="Open WebUI currently publishes wheels for Python >=$OPEN_WEBUI_MIN_PYTHON,<${OPEN_WEBUI_MAX_PYTHON_EXCLUSIVE}, but the selected venv uses $(python_version "$VENV_DIR/bin/python"). Remove $VENV_DIR and rerun with Python 3.11 or 3.12, set OPEN_WEBUI_PYTHON to a compatible interpreter, or use a staged container image."
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

  local version_json detail_json python_runtime_json
  version_json="$(printf '%s' "$version" | json_escape)"
  detail_json="$(printf '%s' "$detail" | json_escape)"
  python_runtime_json="$(printf '%s' "$python_runtime" | json_escape)"
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
  "python_runtime": $python_runtime_json,
  "requires_python": ">=$OPEN_WEBUI_MIN_PYTHON,<$OPEN_WEBUI_MAX_PYTHON_EXCLUSIVE",
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
    echo "- Python runtime: $python_runtime"
    echo "- Requires-Python: >=$OPEN_WEBUI_MIN_PYTHON,<$OPEN_WEBUI_MAX_PYTHON_EXCLUSIVE"
    echo
    printf '%s\n%s\n%s\n' '```text' "$version" '```'
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
