#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M6: TurnkeyML toolchain installer / inventory.
# Prefer lemonade-sdk venv (shared with 160). turnkeyml may be absent on modern
# PyPI — lemonade-sdk is the supported successor for LLM serving tooling.

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
STATUS_JSON="$LATEST_DIR/turnkeyml-status.json"
SUMMARY_MD="$LATEST_DIR/turnkeyml-status.md"
VENV_DIR="$AI370_LEMONADE_VENV"
WHEELHOUSE="$AI370_WHEELHOUSE"
STAGED_DIR="$AI370_TURNKEY_STAGED"
OFFLINE_CONFIG="$PROJECT_ROOT/configs/offline/ai-runtime.env"

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
  echo "[INFO] Creating Lemonade/Turnkey venv at $VENV_DIR with $py ..."
  mkdir -p "$(dirname "$VENV_DIR")"
  "$py" -m venv "$VENV_DIR"
  "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
}

pip_install_turnkey() {
  local py="$VENV_DIR/bin/python"
  local pkgs=(turnkeyml)
  # lemonade-sdk provides the modern serving CLI; install as toolchain companion.
  if [[ "$OFFLINE" == "true" ]]; then
    if [[ -d "$WHEELHOUSE" ]] && compgen -G "$WHEELHOUSE/*" >/dev/null 2>&1; then
      echo "[INFO] Offline: installing turnkeyml/lemonade-sdk from wheelhouse $WHEELHOUSE ..."
      "$py" -m pip install --no-index --find-links="$WHEELHOUSE" turnkeyml lemonade-sdk >/dev/null 2>&1 || true
      # staged dirs may contain wheels
      if [[ -d "$STAGED_DIR" ]] && compgen -G "$STAGED_DIR/*" >/dev/null 2>&1; then
        "$py" -m pip install --no-index --find-links="$STAGED_DIR" turnkeyml lemonade-sdk >/dev/null 2>&1 || true
      fi
      return 0
    fi
    echo "[INFO] Offline: no wheelhouse; inventory existing packages only."
    return 0
  fi
  echo "[INFO] Installing turnkeyml (if published) and lemonade-sdk into venv..."
  # turnkeyml may 404 on modern indices; do not fail the whole stage.
  "$py" -m pip install "turnkeyml" >/dev/null 2>&1 || true
  "$py" -m pip install "lemonade-sdk" >/dev/null 2>&1 || true
}

main() {
  mkdir -p "$LATEST_DIR" "$STAGED_DIR" "$(dirname "$VENV_DIR")"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent TurnkeyML system service is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local state="missing" action="none" status="WARN" detail="" version=""
  local package_present="false" lemonade_sdk_present="false" cli_path=""
  local recommendations=() offline_ready="false"

  if ensure_venv; then
    action="venv-ready"
    pip_install_turnkey
  else
    action="skipped-python-version"
    detail="No Python 3.10–3.13 interpreter found for lemonade-sdk/turnkeyml (requires >=3.10,<3.14). Install python3.12 or set LEMONADE_PYTHON."
    recommendations+=("Install python3.12 and rerun, or stage wheels under $WHEELHOUSE / $STAGED_DIR")
  fi

  if ai370_turnkey_import_ok; then
    package_present="true"
    state="available"
    action="validated-turnkeyml-import"
  fi
  if ai370_lemonade_import_ok || ai370_lemonade_cli >/dev/null 2>&1; then
    lemonade_sdk_present="true"
    if [[ "$state" != "available" ]]; then
      state="available"
      action="validated-lemonade-sdk-successor"
    fi
  fi

  if cli_path="$(ai370_turnkey_cli)"; then
    version="$("$cli_path" --version 2>&1 || "$cli_path" version 2>&1 || true)"
    state="available"
  elif [[ -x "$VENV_DIR/bin/python" ]]; then
    version="$("$VENV_DIR/bin/python" - <<'PY' 2>/dev/null || true
import importlib.metadata as m
for name in ("turnkeyml", "lemonade-sdk", "lemonade"):
    try:
        print(f"{name}=={m.version(name)}")
    except Exception:
        pass
PY
)"
  fi

  if [[ "$state" == "available" ]]; then
    offline_ready="true"
    status="PASS"
    if [[ "$package_present" != "true" && "$lemonade_sdk_present" == "true" ]]; then
      detail="turnkeyml package not installed; lemonade-sdk is present as the supported successor for NPU/hybrid LLM tooling. Ollama remains the general-purpose LLM runtime."
    elif [[ -z "$detail" ]]; then
      detail="TurnkeyML / lemonade-sdk toolchain is available in $VENV_DIR."
    fi
  else
    status="WARN"
    if [[ -z "$detail" ]]; then
      if [[ "$OFFLINE" == "true" ]]; then
        detail="Offline: turnkeyml/lemonade-sdk not found. Stage wheels under $WHEELHOUSE or $STAGED_DIR, then rerun."
      else
        detail="TurnkeyML/lemonade-sdk not installed. Online pip install may have failed; check Python version (3.10–3.13) and network."
      fi
    fi
    recommendations+=(
      "Stage lemonade-sdk wheels: pip download lemonade-sdk -d $WHEELHOUSE"
      "Then: ./scripts/170-install-turnkeyml.sh ai370 safe runtime true"
    )
  fi

  local rec_json="[]"
  if ((${#recommendations[@]} > 0)); then
    rec_json="$(printf '%s\n' "${recommendations[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
  fi

  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 2,
  "phase": "install-turnkeyml",
  "milestone": "S2-M6",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $(bool_json "$OFFLINE"),
  "state": "$state",
  "offline_ready": $(bool_json "$offline_ready"),
  "turnkeyml_import": $(bool_json "$package_present"),
  "lemonade_sdk_present": $(bool_json "$lemonade_sdk_present"),
  "install_action": "$action",
  "venv": $(printf '%s' "$VENV_DIR" | json_escape),
  "wheelhouse": $(printf '%s' "$WHEELHOUSE" | json_escape),
  "staged_dir": $(printf '%s' "$STAGED_DIR" | json_escape),
  "cli": $(printf '%s' "$cli_path" | json_escape),
  "version": $(printf '%s' "$version" | json_escape),
  "offline_config": $(printf '%s' "$OFFLINE_CONFIG" | json_escape),
  "note": "lemonade-sdk is the modern successor for LLM serving; turnkeyml may be unavailable on PyPI.",
  "recommendations": $rec_json,
  "detail": $(printf '%s' "$detail" | json_escape)
}
EOF_JSON

  {
    echo "# Stage 2 — TurnkeyML Status (S2-M6)"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- State: $state"
    echo "- turnkeyml import: $package_present"
    echo "- lemonade-sdk present: $lemonade_sdk_present"
    echo "- Venv: $VENV_DIR"
    echo "- Staged dir: $STAGED_DIR"
    echo "- Wheelhouse: $WHEELHOUSE"
    echo "- CLI: ${cli_path:-none}"
    echo "- Action: $action"
    echo
    printf '%s\n' "$detail"
    if [[ -n "$version" ]]; then
      echo
      echo '```text'
      printf '%s\n' "$version"
      echo '```'
    fi
    if ((${#recommendations[@]} > 0)); then
      echo
      echo "## Recommendations"
      local r
      for r in "${recommendations[@]}"; do
        echo "- $r"
      done
    fi
  } > "$SUMMARY_MD"

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
