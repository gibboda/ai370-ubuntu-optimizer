#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M3: AnythingLLM installer / validator with offline lifecycle support.
# Prefer staged Docker images or AppImage under .ai370-ai/; never requires
# network when OFFLINE=true. Creates local RAG document/storage directories.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
STAGED_DIR="${ANYTHINGLLM_STAGED_DIR:-$AI_ROOT/offline-artifacts/anythingllm}"
APPIMAGE_DIR="${ANYTHINGLLM_APPIMAGE_DIR:-$AI_ROOT/tools/anythingllm}"
DOC_DIR="${ANYTHINGLLM_DOC_DIR:-$AI_ROOT/rag/documents}"
STORAGE_DIR="${ANYTHINGLLM_STORAGE_DIR:-$AI_ROOT/rag/anythingllm-storage}"
IMAGE_NAME="${ANYTHINGLLM_IMAGE:-mintplexlabs/anythingllm:latest}"
CONTAINER_NAME="${ANYTHINGLLM_CONTAINER_NAME:-ai370-anythingllm}"
STATUS_JSON="$LATEST_DIR/anythingllm-status.json"
SUMMARY_MD="$LATEST_DIR/anythingllm-status.md"

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

bool_json() {
  [[ "$1" == "true" ]] && echo true || echo false
}

find_staged_image() {
  local f
  shopt -s nullglob
  for f in "$STAGED_DIR"/*.{tar,tar.gz,tgz}; do
    if [[ -f "$f" ]]; then
      printf '%s\n' "$f"
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

find_appimage() {
  local f
  shopt -s nullglob
  for f in "$APPIMAGE_DIR"/*.AppImage "$STAGED_DIR"/*.AppImage; do
    if [[ -f "$f" ]]; then
      printf '%s\n' "$f"
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

docker_has_image() {
  docker image ls --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -qi 'anythingllm' \
    || docker images 2>/dev/null | grep -qi 'anythingllm'
}

container_running() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER_NAME"
}

main() {
  mkdir -p "$LATEST_DIR" "$STAGED_DIR" "$APPIMAGE_DIR" "$DOC_DIR" "$STORAGE_DIR"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent AnythingLLM system service is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local state="missing" action="none" status="WARN" detail=""
  local docker_visible="false" image_present="false" image_loaded="false"
  local container_present="false" container_is_running="false"
  local appimage_path="" staged_image_path="" install_path="none"
  local offline_ready="false" recommendations=()

  # Seed document store with a tiny offline sample if empty (idempotent).
  if [[ ! -f "$DOC_DIR/README-offline-rag.txt" ]]; then
    cat > "$DOC_DIR/README-offline-rag.txt" <<'EOF'
AI370 offline RAG document store
================================
Place PDF/text documents here for local ingestion. After staging models and
AnythingLLM (Docker image tarball or AppImage), run:

  ./ai370-optimize.sh stage2-rag --offline

This sample file is created by scripts/300-install-anythingllm.sh.
EOF
  fi

  if command -v docker >/dev/null 2>&1; then
    docker_visible="true"
  fi

  if appimage_path="$(find_appimage)"; then
    install_path="appimage"
    state="available"
    action="validated-staged-appimage"
    if [[ ! -x "$appimage_path" ]]; then
      chmod +x "$appimage_path" 2>/dev/null || true
    fi
  fi

  if [[ "$docker_visible" == "true" ]]; then
    if docker_has_image; then
      image_present="true"
      if [[ "$state" != "available" ]]; then
        state="available"
        action="validated-existing-image"
        install_path="docker"
      fi
    fi

    if container_running; then
      container_present="true"
      container_is_running="true"
      state="available"
      install_path="docker"
      action="validated-running-container"
    elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER_NAME"; then
      container_present="true"
      if [[ "$state" != "available" && "$image_present" == "true" ]]; then
        state="available"
        install_path="docker"
        action="validated-existing-container"
      fi
    fi

    # Offline / staged Docker load when image missing.
    if [[ "$image_present" != "true" ]]; then
      if staged_image_path="$(find_staged_image)"; then
        action="load-staged-image"
        echo "[INFO] Loading staged AnythingLLM image from $staged_image_path ..."
        if docker load -i "$staged_image_path" >/dev/null 2>&1; then
          image_loaded="true"
          if docker_has_image; then
            image_present="true"
            state="available"
            install_path="docker"
            action="loaded-staged-image"
          else
            detail="docker load succeeded but no anythingllm image tag was found. Tag the loaded image as $IMAGE_NAME."
          fi
        else
          detail="Failed to docker load staged image: $staged_image_path"
          action="load-staged-image-failed"
        fi
      elif [[ "$OFFLINE" == "true" ]]; then
        if [[ "$state" != "available" ]]; then
          action="skipped-offline-missing-image"
          recommendations+=(
            "Stage a Docker image tarball under $STAGED_DIR (docker save -o anythingllm.tar mintplexlabs/anythingllm:latest)."
            "Or place an AnythingLLM AppImage under $APPIMAGE_DIR."
          )
          detail="Offline mode: Docker is available but no AnythingLLM image or staged tarball was found under $STAGED_DIR."
        fi
      else
        action="pull-attempted"
        echo "[INFO] Pulling AnythingLLM Docker image ($IMAGE_NAME)..."
        if docker pull "$IMAGE_NAME" >/dev/null 2>&1; then
          image_present="true"
          state="available"
          install_path="docker"
          action="pulled-image"
        else
          if [[ "$state" != "available" ]]; then
            detail="Failed to pull $IMAGE_NAME. Ensure Docker can reach the registry, or stage a tarball under $STAGED_DIR."
            recommendations+=("Offline fallback: docker save -o $STAGED_DIR/anythingllm.tar $IMAGE_NAME on a connected host, then rerun with --offline.")
          fi
        fi
      fi
    fi
  else
    if [[ "$state" != "available" ]]; then
      action="guided-manual-install"
      recommendations+=(
        "Install Docker Engine, or stage AnythingLLM AppImage under $APPIMAGE_DIR."
        "For offline Docker: place image tarball in $STAGED_DIR and rerun."
      )
      detail="Docker is not installed and no staged AppImage was found. AnythingLLM can still be prepared offline by staging an image tarball or AppImage."
    fi
  fi

  if [[ "$state" == "available" ]]; then
    status="PASS"
    offline_ready="true"
    if [[ -z "$detail" ]]; then
      detail="AnythingLLM runtime asset is available via $install_path. Document store: $DOC_DIR. Storage volume: $STORAGE_DIR."
    fi
  else
    status="WARN"
    if [[ -z "$detail" ]]; then
      detail="AnythingLLM is not installed. Stage offline artifacts and rerun, or install Docker and pull online."
    fi
  fi

  # Optional runtime container start (docker only, non-fatal).
  local start_action="none"
  if [[ "$install_path" == "docker" && "$image_present" == "true" && "$container_is_running" != "true" && "${ANYTHINGLLM_START:-false}" == "true" ]]; then
    start_action="start-attempted"
    if docker run -d --name "$CONTAINER_NAME" \
      -p "${ANYTHINGLLM_PORT:-3001}:3001" \
      -v "$STORAGE_DIR:/app/server/storage" \
      -v "$DOC_DIR:/app/collector/hotdir" \
      -e STORAGE_DIR=/app/server/storage \
      "$IMAGE_NAME" >/dev/null 2>&1 \
      || docker start "$CONTAINER_NAME" >/dev/null 2>&1; then
      if container_running; then
        container_is_running="true"
        container_present="true"
        start_action="started"
      fi
    else
      start_action="start-failed"
      recommendations+=("Image is present but container failed to start. Check docker logs for $CONTAINER_NAME.")
    fi
  fi

  local rec_json="[]"
  if ((${#recommendations[@]} > 0)); then
    rec_json="$(printf '%s\n' "${recommendations[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
  fi

  local detail_json appimage_json staged_json
  detail_json="$(printf '%s' "$detail" | json_escape)"
  appimage_json="$(printf '%s' "$appimage_path" | json_escape)"
  staged_json="$(printf '%s' "$staged_image_path" | json_escape)"

  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 4,
  "phase": "install-anythingllm",
  "milestone": "S2-M3",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $(bool_json "$OFFLINE"),
  "state": "$state",
  "offline_ready": $(bool_json "$offline_ready"),
  "docker_available": $(bool_json "$docker_visible"),
  "image_present": $(bool_json "$image_present"),
  "image_loaded": $(bool_json "$image_loaded"),
  "image_name": $(printf '%s' "$IMAGE_NAME" | json_escape),
  "container_name": $(printf '%s' "$CONTAINER_NAME" | json_escape),
  "container_present": $(bool_json "$container_present"),
  "container_running": $(bool_json "$container_is_running"),
  "install_path": "$install_path",
  "install_action": "$action",
  "start_action": "$start_action",
  "staged_dir": $(printf '%s' "$STAGED_DIR" | json_escape),
  "staged_image": $staged_json,
  "appimage_path": $appimage_json,
  "document_dir": $(printf '%s' "$DOC_DIR" | json_escape),
  "storage_dir": $(printf '%s' "$STORAGE_DIR" | json_escape),
  "recommendations": $rec_json,
  "detail": $detail_json
}
EOF_JSON

  {
    echo "# Stage 2 RAG — AnythingLLM Status (S2-M3)"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- State: $state"
    echo "- Offline-ready: $offline_ready"
    echo "- Install path: $install_path"
    echo "- Docker available: $docker_visible"
    echo "- Image present: $image_present (loaded this run: $image_loaded)"
    echo "- Container present/running: $container_present / $container_is_running"
    echo "- Staged image dir: $STAGED_DIR"
    echo "- AppImage: ${appimage_path:-none}"
    echo "- Document store: $DOC_DIR"
    echo "- Storage volume: $STORAGE_DIR"
    echo "- Action: $action (start: $start_action)"
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
    echo "# On a connected host:"
    echo "docker pull $IMAGE_NAME"
    echo "docker save -o anythingllm.tar $IMAGE_NAME"
    echo "# Copy tar to: $STAGED_DIR/"
    echo "./ai370-optimize.sh stage2-rag --offline"
    echo '```'
  } > "$SUMMARY_MD"

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
