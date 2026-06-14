#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Milestone 2: llama.cpp installer / validator.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
TOOL_ROOT="$AI_ROOT/tools"
LLAMA_DIR="$TOOL_ROOT/llama.cpp"
STATUS_JSON="$LATEST_DIR/tier2-llama-cpp.json"
SUMMARY_MD="$LATEST_DIR/tier2-llama-cpp.md"
LLAMA_CPP_REPO="${LLAMA_CPP_REPO:-https://github.com/ggml-org/llama.cpp.git}"

find_llama_binary() {
  local candidate
  for candidate in \
    "$TOOL_ROOT/llama-cli" \
    "$LLAMA_DIR/llama-cli" \
    "$LLAMA_DIR/build/bin/llama-cli" \
    "$TOOL_ROOT/main" \
    "$LLAMA_DIR/main" \
    "$LLAMA_DIR/build/bin/main"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  command -v llama-cli 2>/dev/null || true
}

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

main() {
  mkdir -p "$LATEST_DIR" "$TOOL_ROOT"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent llama.cpp installation is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local action="none" status="WARN" detail="" binary=""
  binary="$(find_llama_binary || true)"

  if [[ -z "$binary" && "$OFFLINE" != "true" ]]; then
    if command -v git >/dev/null 2>&1 && command -v cmake >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
      action="clone-and-build"
      if [[ ! -d "$LLAMA_DIR/.git" ]]; then
        if ! git clone --depth 1 "$LLAMA_CPP_REPO" "$LLAMA_DIR"; then
          action="clone-failed"
          detail="Failed to clone llama.cpp from $LLAMA_CPP_REPO; see console output."
        fi
      fi
      if [[ -z "$detail" ]]; then
        if ! cmake -S "$LLAMA_DIR" -B "$LLAMA_DIR/build" -DLLAMA_CURL=OFF; then
          action="cmake-configure-failed"
          detail="llama.cpp CMake configure failed; see console output."
        elif ! cmake --build "$LLAMA_DIR/build" --config Release -j "$(nproc 2>/dev/null || echo 2)"; then
          action="cmake-build-failed"
          detail="llama.cpp build failed; see console output."
        fi
      fi
      if [[ -z "$detail" ]]; then
        binary="$(find_llama_binary || true)"
      fi
    else
      action="missing-build-tools"
      detail="git, cmake, and make are required for online llama.cpp builds."
    fi
  elif [[ -z "$binary" && "$OFFLINE" == "true" ]]; then
    action="skipped-offline-missing-binary"
    detail="Offline mode: stage llama-cli under $TOOL_ROOT or $LLAMA_DIR/build/bin before rerunning."
  else
    action="validated-existing-binary"
  fi

  local version="not-run"
  if [[ -n "$binary" ]]; then
    status="PASS"
    version="$($binary --version 2>&1 || true)"
  fi
  if [[ -z "$detail" ]]; then
    detail="llama.cpp validation completed."
  fi

  local detail_json version_json
  detail_json="$(printf '%s' "$detail" | json_escape)"
  version_json="$(printf '%s' "$version" | json_escape)"
  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 2,
  "phase": "install-llama-cpp",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $([[ "$OFFLINE" == "true" ]] && echo true || echo false),
  "binary": "${binary:-}",
  "install_action": "$action",
  "version": $version_json,
  "detail": $detail_json
}
EOF_JSON
  {
    echo "# Tier 2 llama.cpp Status"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- Binary: ${binary:-not-found}"
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
