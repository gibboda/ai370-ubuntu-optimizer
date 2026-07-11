#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M3: AnythingLLM installer / validator.
# Validates Docker container presence or guides manual offline setup.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
STATUS_JSON="$LATEST_DIR/anythingllm-status.json"
SUMMARY_MD="$LATEST_DIR/anythingllm-status.md"

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

main() {
  mkdir -p "$LATEST_DIR"

  local state="missing" action="none" status="WARN" detail="" docker_visible="false" image_pulled="false"

  if command -v docker >/dev/null 2>&1; then
    docker_visible="true"
    if docker image ls 2>/dev/null | grep -qi 'anythingllm'; then
      state="available"
      action="validated-existing-container"
      image_pulled="true"
    elif [[ "$OFFLINE" == "true" ]]; then
      action="skipped-offline"
      detail="Offline mode: Docker is installed, but the AnythingLLM image is missing. Run online or load a staged image."
    else
      action="pull-attempted"
      echo "[INFO] Pulling AnythingLLM Docker image..."
      if docker pull mintplexlabs/anythingllm:latest >/dev/null 2>&1; then
        state="available"
        image_pulled="true"
      else
        detail="Failed to pull AnythingLLM Docker image. Ensure internet connectivity or check Docker daemon."
      fi
    fi
  else
    action="guided-manual-install"
    detail="Docker is not installed. For a local installation, run AnythingLLM via desktop AppImage or setup Docker on Ubuntu."
  fi

  if [[ "$state" == "available" ]]; then
    status="PASS"
  fi
  if [[ -z "$detail" ]]; then
    detail="AnythingLLM container/service validation completed."
  fi

  local detail_json
  detail_json="$(printf '%s' "$detail" | json_escape)"
  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 4,
  "phase": "install-anythingllm",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $([[ "$OFFLINE" == "true" ]] && echo true || echo false),
  "state": "$state",
  "docker_available": $docker_visible,
  "image_pulled": $image_pulled,
  "install_action": "$action",
  "detail": $detail_json
}
EOF_JSON

  {
    echo "# Tier 4 AnythingLLM Status"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- State: $state"
    echo "- Docker available: $docker_visible"
    echo "- Container image pulled: $image_pulled"
    echo "- Action: $action"
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
