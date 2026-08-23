#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S3-M4 diagnostics: Digest AI installer / inventory.
# Full Digest AI (onnx/digestai) requires Python >=3.9,<3.11.
# Always ensures an ONNX analysis stack for offline fallback reports.
# Diagnostics only — never claims NPU inference.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/offline-paths.sh
source "$PROJECT_ROOT/scripts/lib/offline-paths.sh"
ai370_load_offline_env

LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$(ai370_resolve_path "${OFFLINE_MODEL_ROOT:-.ai370-ai/models}")"
if [[ "$AI_ROOT" == */models ]]; then
  AI_ROOT="$(dirname "$AI_ROOT")"
else
  AI_ROOT="$PROJECT_ROOT/.ai370-ai"
fi
WHEELHOUSE="$(ai370_resolve_path "${OFFLINE_WHEELHOUSE:-.ai370-ai/wheelhouse}")"
STAGED_DIR="$(ai370_resolve_path "$(ai370_first_nonempty "${DIGEST_STAGED_DIR:-}" "${OFFLINE_DIGEST_DIR:-}" ".ai370-ai/offline-artifacts/digestai")")"
VENV_DIR="$(ai370_resolve_path "$(ai370_first_nonempty "${DIGEST_VENV_DIR:-}" "${OFFLINE_DIGEST_VENV:-}" ".ai370-ai/digest/venv")")"
SRC_DIR="$(ai370_resolve_path "$(ai370_first_nonempty "${DIGEST_SRC_DIR:-}" "${OFFLINE_DIGEST_SRC:-}" ".ai370-ai/tools/digestai")")"
STATUS_JSON="$LATEST_DIR/digest-ai-status.json"
SUMMARY_MD="$LATEST_DIR/digest-ai-status.md"
DIGEST_GIT_URL="${DIGEST_GIT_URL:-https://github.com/onnx/digestai.git}"
OFFLINE_CONFIG="$PROJECT_ROOT/configs/offline/ai-runtime.env"

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }
bool_json() { [[ "$1" == "true" ]] && echo true || echo false; }

python_supports_digest() {
  "$1" - <<'PY'
import sys
v = sys.version_info
# digestai setup.py: python_requires >=3.9, <3.11
sys.exit(0 if (3, 9) <= (v.major, v.minor) < (3, 11) else 1)
PY
}

select_digest_python() {
  local candidates=()
  if [[ -n "${DIGEST_PYTHON:-}" ]]; then
    candidates+=("$DIGEST_PYTHON")
  fi
  candidates+=(python3.10 python3.9 python3)
  local c
  for c in "${candidates[@]}"; do
    if command -v "$c" >/dev/null 2>&1 && python_supports_digest "$(command -v "$c")"; then
      command -v "$c"
      return 0
    fi
  done
  return 1
}

digest_import_ok() {
  local py="${1:-}"
  [[ -x "$py" ]] || return 1
  "$py" -c 'import importlib.util,sys; sys.exit(0 if importlib.util.find_spec("digest") else 1)' 2>/dev/null
}

ensure_fallback_onnx_venv() {
  # Fallback analyzer needs onnx on some python; prefer shared AI venv or digest venv.
  local py=""
  if [[ -x "$AI_ROOT/venv/bin/python" ]]; then
    py="$AI_ROOT/venv/bin/python"
  elif [[ -x "$VENV_DIR/bin/python" ]]; then
    py="$VENV_DIR/bin/python"
  else
    py="$(command -v python3)"
  fi
  if "$py" -c 'import onnx' >/dev/null 2>&1; then
    printf '%s\n' "$py"
    return 0
  fi
  if [[ "$OFFLINE" == "true" ]]; then
    if [[ -d "$WHEELHOUSE" ]] && compgen -G "$WHEELHOUSE/*" >/dev/null 2>&1; then
      "$py" -m pip install --no-index --find-links="$WHEELHOUSE" onnx >/dev/null 2>&1 || true
    fi
  else
    "$py" -m pip install "onnx" >/dev/null 2>&1 || true
  fi
  if "$py" -c 'import onnx' >/dev/null 2>&1; then
    printf '%s\n' "$py"
    return 0
  fi
  return 1
}

install_digest_from_src() {
  local py="$1"
  local src="$2"
  if [[ ! -f "$src/setup.py" && ! -f "$src/pyproject.toml" ]]; then
    return 1
  fi
  echo "[INFO] Installing Digest AI editable from $src ..."
  "$py" -m pip install -e "$src" >/dev/null 2>&1
}

main() {
  mkdir -p "$LATEST_DIR" "$STAGED_DIR" "$(dirname "$VENV_DIR")" "$(dirname "$SRC_DIR")"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent Digest AI system service is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local state="missing" action="none" status="WARN" detail=""
  local digest_native="false" fallback_ok="false" offline_ready="false"
  local python_runtime="not-selected" version="" cli_path="" recommendations=()
  local install_path="none"

  # --- Prefer native Digest AI on Python 3.9–3.10 ---
  local dig_py=""
  if dig_py="$(select_digest_python)"; then
    python_runtime="$dig_py ($("$dig_py" -c 'import sys; print("%d.%d.%d"%sys.version_info[:3])'))"
    if [[ ! -x "$VENV_DIR/bin/python" ]]; then
      echo "[INFO] Creating Digest AI venv at $VENV_DIR with $dig_py ..."
      "$dig_py" -m venv "$VENV_DIR"
      "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
    fi
    local vpy="$VENV_DIR/bin/python"

    if digest_import_ok "$vpy"; then
      state="available"
      digest_native="true"
      action="validated-existing-digest"
      install_path="venv"
    elif [[ -d "$STAGED_DIR" ]] && { [[ -f "$STAGED_DIR/setup.py" ]] || [[ -f "$STAGED_DIR/pyproject.toml" ]]; }; then
      action="install-from-staged-src"
      if install_digest_from_src "$vpy" "$STAGED_DIR" && digest_import_ok "$vpy"; then
        state="available"
        digest_native="true"
        install_path="staged-src"
        action="installed-from-staged-src"
      fi
    elif [[ -d "$SRC_DIR" ]] && { [[ -f "$SRC_DIR/setup.py" ]] || [[ -f "$SRC_DIR/pyproject.toml" ]]; }; then
      action="install-from-local-src"
      if install_digest_from_src "$vpy" "$SRC_DIR" && digest_import_ok "$vpy"; then
        state="available"
        digest_native="true"
        install_path="local-src"
        action="installed-from-local-src"
      fi
    elif [[ "$OFFLINE" == "true" ]]; then
      if [[ -d "$WHEELHOUSE" ]] && compgen -G "$WHEELHOUSE/*" >/dev/null 2>&1; then
        action="offline-wheelhouse-attempt"
        "$vpy" -m pip install --no-index --find-links="$WHEELHOUSE" digestai >/dev/null 2>&1 || true
        if digest_import_ok "$vpy"; then
          state="available"
          digest_native="true"
          install_path="wheelhouse"
          action="installed-from-wheelhouse"
        fi
      else
        action="skipped-offline-missing-digest"
      fi
    else
      action="online-git-install-attempt"
      echo "[INFO] Cloning/installing Digest AI from $DIGEST_GIT_URL ..."
      if [[ ! -d "$SRC_DIR/.git" ]]; then
        if command -v git >/dev/null 2>&1; then
          git clone --depth 1 "$DIGEST_GIT_URL" "$SRC_DIR" >/dev/null 2>&1 || true
        fi
      fi
      if [[ -d "$SRC_DIR" ]] && install_digest_from_src "$vpy" "$SRC_DIR" && digest_import_ok "$vpy"; then
        state="available"
        digest_native="true"
        install_path="git-src"
        action="installed-from-git"
      else
        # Try direct pip git URL
        "$vpy" -m pip install "git+${DIGEST_GIT_URL}" >/dev/null 2>&1 || true
        if digest_import_ok "$vpy"; then
          state="available"
          digest_native="true"
          install_path="pip-git"
          action="installed-from-pip-git"
        fi
      fi
    fi

    if digest_import_ok "$vpy"; then
      version="$("$vpy" - <<'PY' 2>/dev/null || true
import importlib.metadata as m
for name in ("digestai", "digest"):
    try:
        print(f"{name}=={m.version(name)}")
        break
    except Exception:
        pass
PY
)"
      if [[ -x "$VENV_DIR/bin/digest" ]]; then
        cli_path="$VENV_DIR/bin/digest"
      fi
    fi
  else
    action="skipped-python-version"
    python_runtime="no-python-3.9-or-3.10"
    detail="Digest AI requires Python >=3.9,<3.11 (typically 3.10). No compatible interpreter found. ONNX fallback analysis will still be available."
    recommendations+=("Install python3.10 and set DIGEST_PYTHON=python3.10, then rerun scripts/250-install-digest-ai.sh")
  fi

  # --- Always ensure ONNX fallback capability ---
  local fallback_py=""
  if fallback_py="$(ensure_fallback_onnx_venv)"; then
    fallback_ok="true"
  fi

  if [[ "$digest_native" == "true" ]]; then
    offline_ready="true"
    status="PASS"
    if [[ -z "$detail" ]]; then
      detail="Digest AI is available ($install_path). Analysis is diagnostics-only and is not NPU inference proof."
    fi
  elif [[ "$fallback_ok" == "true" ]]; then
    offline_ready="true"
    status="WARN"
    state="fallback"
    if [[ -z "$detail" ]]; then
      detail="Digest AI native package not installed; ONNX fallback analyzer is ready via scripts/255-analyze-model-digest.sh. Not NPU inference proof."
    fi
    recommendations+=(
      "For full Digest AI (FLOPs/GUI): use Python 3.10 venv and stage https://github.com/onnx/digestai under $STAGED_DIR or $SRC_DIR"
    )
  else
    status="WARN"
    if [[ -z "$detail" ]]; then
      detail="Neither Digest AI nor ONNX fallback is ready. Install onnx into the AI venv or stage Digest AI sources."
    fi
    recommendations+=("pip install onnx into .ai370-ai/venv or provide Python 3.10 + digestai sources")
  fi

  local rec_json="[]"
  if ((${#recommendations[@]} > 0)); then
    rec_json="$(printf '%s\n' "${recommendations[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
  fi

  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 2,
  "phase": "install-digest-ai",
  "milestone": "S3-M4",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $(bool_json "$OFFLINE"),
  "state": "$state",
  "offline_ready": $(bool_json "$offline_ready"),
  "digest_native": $(bool_json "$digest_native"),
  "onnx_fallback_ready": $(bool_json "$fallback_ok"),
  "install_path": "$install_path",
  "install_action": "$action",
  "python_runtime": $(printf '%s' "$python_runtime" | json_escape),
  "venv": $(printf '%s' "$VENV_DIR" | json_escape),
  "src_dir": $(printf '%s' "$SRC_DIR" | json_escape),
  "staged_dir": $(printf '%s' "$STAGED_DIR" | json_escape),
  "wheelhouse": $(printf '%s' "$WHEELHOUSE" | json_escape),
  "cli": $(printf '%s' "$cli_path" | json_escape),
  "version": $(printf '%s' "$version" | json_escape),
  "fallback_python": $(printf '%s' "$fallback_py" | json_escape),
  "npu_execution_claimed": false,
  "policy": "Diagnostics only. Digest/ONNX stats are never NPU inference proof.",
  "offline_config": $(printf '%s' "$OFFLINE_CONFIG" | json_escape),
  "recommendations": $rec_json,
  "detail": $(printf '%s' "$detail" | json_escape)
}
EOF_JSON

  {
    echo "# Stage 3 — Digest AI Status (S3-M4)"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- State: $state"
    echo "- Digest native: $digest_native"
    echo "- ONNX fallback ready: $fallback_ok"
    echo "- Offline-ready: $offline_ready"
    echo "- Python: $python_runtime"
    echo "- Venv: $VENV_DIR"
    echo "- Staged/src: $STAGED_DIR / $SRC_DIR"
    echo "- Action: $action"
    echo "- NPU execution claimed: **false** (diagnostics only)"
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
    echo "# Stage Digest AI sources (for Python 3.10 hosts):"
    echo "git clone --depth 1 https://github.com/onnx/digestai.git $STAGED_DIR"
    echo "DIGEST_PYTHON=python3.10 ./scripts/250-install-digest-ai.sh ai370 safe runtime true"
    echo '```'
  } > "$SUMMARY_MD"

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
