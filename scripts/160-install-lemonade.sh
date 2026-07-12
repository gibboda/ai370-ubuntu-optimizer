#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M6: Lemonade SDK / Server installer (OpenAI-compatible local LLM serving).
# Sibling to Ollama — does not remove or require Ollama. Offline-first via
# wheelhouse / staged artifacts. WARN-friendly experimental path on Linux.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/offline-paths.sh
source "$PROJECT_ROOT/scripts/lib/offline-paths.sh"
# shellcheck source=lib/lemonade-env.sh
source "$PROJECT_ROOT/scripts/lib/lemonade-env.sh"
ai370_apply_lemonade_paths

LATEST_DIR="$PROJECT_ROOT/reports/latest"
STATUS_JSON="$LATEST_DIR/lemonade-status.json"
SUMMARY_MD="$LATEST_DIR/lemonade-status.md"
VENV_DIR="$AI370_LEMONADE_VENV"
WHEELHOUSE="$AI370_WHEELHOUSE"
STAGED_DIR="$AI370_LEMONADE_STAGED"
MODEL_DIR="$AI370_LEMONADE_MODELS"
OFFLINE_CONFIG="$PROJECT_ROOT/configs/offline/ai-runtime.env"
PKG_NAME="${LEMONADE_PIP_PACKAGE:-lemonade-sdk}"

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }
bool_json() { [[ "$1" == "true" ]] && echo true || echo false; }

ensure_venv() {
  if [[ -x "$VENV_DIR/bin/python" ]]; then
    return 0
  fi
  local py
  if ! py="$(ai370_select_lemonade_python)"; then
    return 1
  fi
  echo "[INFO] Creating Lemonade venv at $VENV_DIR with $py ..."
  mkdir -p "$(dirname "$VENV_DIR")"
  "$py" -m venv "$VENV_DIR"
  "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
}

pip_install_lemonade() {
  local py="$VENV_DIR/bin/python"
  if [[ "$OFFLINE" == "true" ]]; then
    local found=false
    if [[ -d "$WHEELHOUSE" ]] && compgen -G "$WHEELHOUSE/*" >/dev/null 2>&1; then
      echo "[INFO] Offline: installing $PKG_NAME from wheelhouse $WHEELHOUSE ..."
      if "$py" -m pip install --no-index --find-links="$WHEELHOUSE" "$PKG_NAME" >/dev/null 2>&1; then
        found=true
      fi
    fi
    if [[ -d "$STAGED_DIR" ]] && compgen -G "$STAGED_DIR/*" >/dev/null 2>&1; then
      echo "[INFO] Offline: trying staged artifacts $STAGED_DIR ..."
      if "$py" -m pip install --no-index --find-links="$STAGED_DIR" "$PKG_NAME" >/dev/null 2>&1; then
        found=true
      fi
      # Also accept a prebuilt venv tree under staged
      if [[ -x "$STAGED_DIR/venv/bin/lemonade-server" || -x "$STAGED_DIR/venv/bin/python" ]]; then
        echo "[INFO] Staged venv detected under $STAGED_DIR/venv (inventory only; not auto-copied)."
      fi
    fi
    if [[ "$found" != "true" ]]; then
      echo "[INFO] Offline: no lemonade package installed from staged sources."
    fi
    return 0
  fi
  echo "[INFO] Installing $PKG_NAME into $VENV_DIR ..."
  if ! "$py" -m pip install "$PKG_NAME"; then
    return 1
  fi
  return 0
}

system_lemonade_present() {
  command -v lemonade-server >/dev/null 2>&1 || command -v lemonade >/dev/null 2>&1 \
    || dpkg -l lemonade-server 2>/dev/null | grep -q '^ii' \
    || snap list lemonade-server >/dev/null 2>&1
}

main() {
  mkdir -p "$LATEST_DIR" "$STAGED_DIR" "$MODEL_DIR" "$(dirname "$VENV_DIR")"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent Lemonade system service is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local state="missing" action="none" status="WARN" detail="" version=""
  local install_path="none" cli_path="" python_runtime="not-selected"
  local offline_ready="false" package_ok="false" recommendations=()
  local npu_linux_note="On Linux, Lemonade NPU (OGA) is often Windows-first; CPU/GPU (Vulkan/ROCm) paths are the primary Linux acceleration modes. Report honestly — package presence is not NPU inference."

  if system_lemonade_present; then
    state="available"
    action="validated-system-package"
    install_path="system"
    if command -v lemonade-server >/dev/null 2>&1; then
      cli_path="$(command -v lemonade-server)"
    else
      cli_path="$(command -v lemonade 2>/dev/null || true)"
    fi
  fi

  if [[ "$state" != "available" ]] || [[ "${LEMONADE_FORCE_VENV:-false}" == "true" ]]; then
    if ensure_venv; then
      python_runtime="$VENV_DIR/bin/python ($("$VENV_DIR/bin/python" -c 'import sys; print("%d.%d.%d"%sys.version_info[:3])'))"
      if [[ "$state" == "available" && "$install_path" == "system" && "${LEMONADE_FORCE_VENV:-false}" != "true" ]]; then
        : # keep system path
      else
        action="pip-install-attempted"
        if pip_install_lemonade; then
          if ai370_lemonade_import_ok || ai370_lemonade_cli >/dev/null 2>&1; then
            state="available"
            install_path="venv"
            action="installed-or-validated-venv"
            package_ok="true"
          elif [[ "$OFFLINE" == "true" ]]; then
            action="skipped-offline-missing-wheels"
            detail="Offline mode: $PKG_NAME missing and no staged wheels under $WHEELHOUSE or $STAGED_DIR."
          else
            detail="pip install finished but lemonade package/CLI not importable in $VENV_DIR."
            action="install-incomplete"
          fi
        else
          if [[ "$OFFLINE" == "true" ]]; then
            action="skipped-offline-missing-wheels"
            detail="Offline mode: $PKG_NAME missing and no staged wheels under $WHEELHOUSE or $STAGED_DIR."
          else
            action="pip-install-failed"
            detail="Failed to pip install $PKG_NAME. Check network, Python version (3.10–3.13), or stage wheels offline."
          fi
        fi
      fi
    else
      if [[ "$state" != "available" ]]; then
        action="skipped-python-version"
        detail="No Python 3.10–3.13 interpreter found (lemonade-sdk requires >=3.10,<3.14). Install python3.12 or set LEMONADE_PYTHON."
        recommendations+=("sudo apt install python3.12 python3.12-venv  # example")
      fi
    fi
  fi

  # Re-detect CLI after install
  if cli_path="$(ai370_lemonade_cli)"; then
    state="available"
    if [[ "$install_path" == "none" ]]; then
      install_path="path"
    fi
  fi

  if [[ -x "$VENV_DIR/bin/python" ]]; then
    if ai370_lemonade_import_ok || ai370_lemonade_cli >/dev/null 2>&1; then
      package_ok="true"
    fi
    version="$("$VENV_DIR/bin/python" - <<'PY' 2>/dev/null || true
import importlib.metadata as m
for name in ("lemonade-sdk", "lemonade", "lemonade_server"):
    try:
        print(f"{name}=={m.version(name)}")
        break
    except Exception:
        pass
else:
    print("version-unknown")
PY
)"
  elif [[ -n "$cli_path" ]]; then
    version="$("$cli_path" --version 2>&1 || true)"
  fi

  if [[ "$state" == "available" ]]; then
    offline_ready="true"
    status="PASS"
    if [[ -z "$detail" ]]; then
      detail="Lemonade is available via $install_path. OpenAI-compatible base URL default: $LEMONADE_BASE_URL. $npu_linux_note Ollama is unaffected."
    fi
  else
    status="WARN"
    if [[ -z "$detail" ]]; then
      detail="Lemonade is not installed. Stage wheels or install online with a compatible Python."
    fi
    recommendations+=(
      "Online: LEMONADE_PYTHON=python3.12 ./scripts/160-install-lemonade.sh"
      "Offline: pip download $PKG_NAME -d $WHEELHOUSE && ./scripts/160-install-lemonade.sh ai370 safe runtime true"
    )
  fi

  local rec_json="[]"
  if ((${#recommendations[@]} > 0)); then
    rec_json="$(printf '%s\n' "${recommendations[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
  fi

  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 2,
  "phase": "install-lemonade",
  "milestone": "S2-M6",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $(bool_json "$OFFLINE"),
  "state": "$state",
  "offline_ready": $(bool_json "$offline_ready"),
  "package_ok": $(bool_json "$package_ok"),
  "install_path": "$install_path",
  "install_action": "$action",
  "cli": $(printf '%s' "$cli_path" | json_escape),
  "version": $(printf '%s' "$version" | json_escape),
  "python_runtime": $(printf '%s' "$python_runtime" | json_escape),
  "venv": $(printf '%s' "$VENV_DIR" | json_escape),
  "wheelhouse": $(printf '%s' "$WHEELHOUSE" | json_escape),
  "staged_dir": $(printf '%s' "$STAGED_DIR" | json_escape),
  "model_dir": $(printf '%s' "$MODEL_DIR" | json_escape),
  "base_url": $(printf '%s' "$LEMONADE_BASE_URL" | json_escape),
  "openai_compatible": true,
  "sibling_to_ollama": true,
  "npu_note": $(printf '%s' "$npu_linux_note" | json_escape),
  "offline_config": $(printf '%s' "$OFFLINE_CONFIG" | json_escape),
  "path_sources": {
    "venv": "LEMONADE_VENV_DIR | OFFLINE_LEMONADE_VENV",
    "staged_dir": "LEMONADE_STAGED_DIR | OFFLINE_LEMONADE_DIR",
    "model_dir": "LEMONADE_MODEL_DIR | OFFLINE_LEMONADE_MODEL_DIR",
    "wheelhouse": "OFFLINE_WHEELHOUSE"
  },
  "recommendations": $rec_json,
  "detail": $(printf '%s' "$detail" | json_escape)
}
EOF_JSON

  {
    echo "# Stage 2 — Lemonade Status (S2-M6)"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- State: $state"
    echo "- Offline-ready: $offline_ready"
    echo "- Install path: $install_path"
    echo "- CLI: ${cli_path:-none}"
    echo "- Venv: $VENV_DIR"
    echo "- Model dir: $MODEL_DIR"
    echo "- Base URL: $LEMONADE_BASE_URL"
    echo "- Sibling to Ollama: yes (Ollama is not removed)"
    echo "- Action: $action"
    echo
    printf '%s\n' "$detail"
    echo
    echo "## Linux NPU note"
    echo
    printf '%s\n' "$npu_linux_note"
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
    echo "python3.12 -m pip download $PKG_NAME -d $WHEELHOUSE"
    echo "./scripts/160-install-lemonade.sh ai370 safe runtime true"
    echo '```'
  } > "$SUMMARY_MD"

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
