# SPDX-License-Identifier: GPL-3.0-only
# shellcheck shell=bash
#
# Shared Lemonade / TurnkeyML environment helpers (S2-M6).
# Requires PROJECT_ROOT. Prefer sourcing after offline-paths.sh.
#
# Usage:
#   source "$PROJECT_ROOT/scripts/lib/offline-paths.sh"
#   source "$PROJECT_ROOT/scripts/lib/lemonade-env.sh"
#   ai370_apply_lemonade_paths
#   ai370_select_lemonade_python

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  echo "[ERROR] lemonade-env.sh requires PROJECT_ROOT" >&2
  return 1
fi

# Apply Lemonade staging paths (depends on ai370_load_offline_env / resolve helpers).
ai370_apply_lemonade_paths() {
  if declare -F ai370_load_offline_env >/dev/null 2>&1; then
    ai370_load_offline_env
  fi
  if ! declare -F ai370_resolve_path >/dev/null 2>&1; then
    echo "[ERROR] lemonade-env.sh requires offline-paths.sh (ai370_resolve_path)" >&2
    return 1
  fi

  local ai_root
  ai_root="$(ai370_resolve_path "${OFFLINE_MODEL_ROOT:-.ai370-ai/models}")"
  if [[ "$ai_root" == */models ]]; then
    ai_root="$(dirname "$ai_root")"
  else
    ai_root="$PROJECT_ROOT/.ai370-ai"
  fi
  export AI370_AI_ROOT="${AI370_AI_ROOT:-$ai_root}"

  export AI370_WHEELHOUSE
  AI370_WHEELHOUSE="$(ai370_resolve_path "$(ai370_first_nonempty "${OFFLINE_WHEELHOUSE:-}" ".ai370-ai/wheelhouse")")"

  export AI370_LEMONADE_VENV
  AI370_LEMONADE_VENV="$(ai370_resolve_path "$(ai370_first_nonempty \
    "${LEMONADE_VENV_DIR:-}" \
    "${OFFLINE_LEMONADE_VENV:-}" \
    ".ai370-ai/lemonade/venv")")"

  export AI370_LEMONADE_STAGED
  AI370_LEMONADE_STAGED="$(ai370_resolve_path "$(ai370_first_nonempty \
    "${LEMONADE_STAGED_DIR:-}" \
    "${OFFLINE_LEMONADE_DIR:-}" \
    ".ai370-ai/offline-artifacts/lemonade")")"

  export AI370_TURNKEY_STAGED
  AI370_TURNKEY_STAGED="$(ai370_resolve_path "$(ai370_first_nonempty \
    "${TURNKEYML_STAGED_DIR:-}" \
    "${OFFLINE_TURNKEYML_DIR:-}" \
    ".ai370-ai/offline-artifacts/turnkeyml")")"

  export AI370_LEMONADE_MODELS
  AI370_LEMONADE_MODELS="$(ai370_resolve_path "$(ai370_first_nonempty \
    "${LEMONADE_MODEL_DIR:-}" \
    "${OFFLINE_LEMONADE_MODEL_DIR:-}" \
    ".ai370-ai/models/lemonade")")"

  # OpenAI-compatible base (Lemonade default: /api/v1 under port 8000)
  export LEMONADE_HOST="${LEMONADE_HOST:-127.0.0.1}"
  export LEMONADE_PORT="${LEMONADE_PORT:-8000}"
  export LEMONADE_BASE_URL="${LEMONADE_BASE_URL:-http://${LEMONADE_HOST}:${LEMONADE_PORT}/api/v1}"
  export LEMONADE_API_KEY="${LEMONADE_API_KEY:-lemonade}"
}

# lemonade-sdk requires Python >=3.10,<3.14
ai370_python_supports_lemonade() {
  "$1" - <<'PY'
import sys
v = sys.version_info
sys.exit(0 if (3, 10) <= (v.major, v.minor) < (3, 14) else 1)
PY
}

ai370_select_lemonade_python() {
  local candidates=()
  if [[ -n "${LEMONADE_PYTHON:-}" ]]; then
    candidates+=("$LEMONADE_PYTHON")
  fi
  candidates+=(python3.13 python3.12 python3.11 python3.10 python3)
  local c
  for c in "${candidates[@]}"; do
    if command -v "$c" >/dev/null 2>&1 && ai370_python_supports_lemonade "$(command -v "$c")"; then
      command -v "$c"
      return 0
    fi
  done
  return 1
}

ai370_lemonade_python() {
  if [[ -x "${AI370_LEMONADE_VENV:-}/bin/python" ]]; then
    printf '%s\n' "$AI370_LEMONADE_VENV/bin/python"
    return 0
  fi
  return 1
}

ai370_lemonade_cli() {
  # Prefer venv entrypoints, then PATH.
  # Package versions expose lemonade-server, lemonade-server-dev, and/or lemonade.
  local c
  for c in \
    "${AI370_LEMONADE_VENV:-}/bin/lemonade-server" \
    "${AI370_LEMONADE_VENV:-}/bin/lemonade-server-dev" \
    "${AI370_LEMONADE_VENV:-}/bin/lemonade" \
    ""; do
    if [[ -n "$c" && -x "$c" ]]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  for c in lemonade-server lemonade-server-dev lemonade; do
    if command -v "$c" >/dev/null 2>&1; then
      command -v "$c"
      return 0
    fi
  done
  return 1
}

ai370_turnkey_cli() {
  local c
  for c in "${AI370_LEMONADE_VENV:-}/bin/turnkey" "${AI370_LEMONADE_VENV:-}/bin/turnkeyml" ""; do
    if [[ -n "$c" && -x "$c" ]]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  for c in turnkey turnkeyml; do
    if command -v "$c" >/dev/null 2>&1; then
      command -v "$c"
      return 0
    fi
  done
  return 1
}

ai370_lemonade_import_ok() {
  local py
  if ! py="$(ai370_lemonade_python)"; then
    return 1
  fi
  "$py" -c 'import importlib.util,sys; sys.exit(0 if importlib.util.find_spec("lemonade") or importlib.util.find_spec("lemonade_sdk") or importlib.util.find_spec("lemonade_server") else 1)' 2>/dev/null
}

ai370_turnkey_import_ok() {
  local py
  if ! py="$(ai370_lemonade_python)"; then
    # fall back to system python for inventory only
    py="python3"
  fi
  "$py" -c 'import importlib.util,sys; sys.exit(0 if importlib.util.find_spec("turnkeyml") or importlib.util.find_spec("turnkey") else 1)' 2>/dev/null
}
