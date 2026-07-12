#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M6: Lemonade validation — inventory, health, optional OpenAI smoke.
# Does not pull models unless LEMONADE_PULL_MODEL is set (online only).
# Server start is opt-in via LEMONADE_START=true.

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
STATUS_JSON="$LATEST_DIR/lemonade-validation.json"
SUMMARY_MD="$LATEST_DIR/lemonade-validation.md"
INSTALL_JSON="$LATEST_DIR/lemonade-status.json"
TURNKEY_JSON="$LATEST_DIR/turnkeyml-status.json"
VENV_DIR="$AI370_LEMONADE_VENV"
BASE_URL="$LEMONADE_BASE_URL"
SMOKE_TIMEOUT="${LEMONADE_SMOKE_TIMEOUT_SEC:-30}"
SMOKE_MAX_TOKENS="${LEMONADE_SMOKE_MAX_TOKENS:-8}"

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }
bool_json() { [[ "$1" == "true" ]] && echo true || echo false; }

read_json_field() {
  local file="$1" field="$2" default="${3:-}"
  if [[ ! -f "$file" ]]; then
    printf '%s' "$default"
    return 0
  fi
  python3 - "$file" "$field" "$default" <<'PY'
import json, sys
path, field, default = sys.argv[1:4]
try:
    data = json.load(open(path, encoding="utf-8"))
    val = data
    for part in field.split("."):
        if isinstance(val, dict) and part in val:
            val = val[part]
        else:
            print(default)
            raise SystemExit(0)
    if isinstance(val, bool):
        print("true" if val else "false")
    elif val is None:
        print(default)
    else:
        print(val)
except Exception:
    print(default)
PY
}

http_get() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time "$SMOKE_TIMEOUT" "$url" 2>/dev/null || true
  else
    python3 - "$url" "$SMOKE_TIMEOUT" <<'PY'
import sys, urllib.request
url, timeout = sys.argv[1], float(sys.argv[2])
try:
    with urllib.request.urlopen(url, timeout=timeout) as r:
        sys.stdout.write(r.read().decode("utf-8", errors="replace"))
except Exception:
    pass
PY
  fi
}

http_post_json() {
  local url="$1" body="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time "$SMOKE_TIMEOUT" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${LEMONADE_API_KEY}" \
      -d "$body" "$url" 2>/dev/null || true
  else
    python3 - "$url" "$body" "$SMOKE_TIMEOUT" "${LEMONADE_API_KEY}" <<'PY'
import json, sys, urllib.request
url, body, timeout, key = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
req = urllib.request.Request(url, data=body.encode(), method="POST",
    headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"})
try:
    with urllib.request.urlopen(req, timeout=timeout) as r:
        sys.stdout.write(r.read().decode("utf-8", errors="replace"))
except Exception:
    pass
PY
  fi
}

server_listening() {
  python3 - <<PY
import socket
s = socket.socket()
s.settimeout(1.0)
try:
    s.connect(("${LEMONADE_HOST}", int("${LEMONADE_PORT}")))
    print("true")
except Exception:
    print("false")
finally:
    s.close()
PY
}

maybe_start_server() {
  local cli="$1"
  if [[ "${LEMONADE_START:-false}" != "true" ]]; then
    return 1
  fi
  if [[ "$(server_listening)" == "true" ]]; then
    return 0
  fi
  echo "[INFO] LEMONADE_START=true: attempting to start Lemonade server on ${LEMONADE_HOST}:${LEMONADE_PORT} ..."
  # Background start; common CLIs differ by version.
  if [[ "$cli" == *lemonade-server* ]]; then
    nohup "$cli" serve --port "${LEMONADE_PORT}" >/tmp/ai370-lemonade-server.log 2>&1 &
  else
    nohup "$cli" serve --port "${LEMONADE_PORT}" >/tmp/ai370-lemonade-server.log 2>&1 \
      || nohup "$cli" --port "${LEMONADE_PORT}" >/tmp/ai370-lemonade-server.log 2>&1 &
  fi
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 1
    if [[ "$(server_listening)" == "true" ]]; then
      return 0
    fi
  done
  return 1
}

main() {
  mkdir -p "$LATEST_DIR"

  local state="missing" status="WARN" detail="" action="inventory"
  local cli_path="" package_ok="false" server_up="false"
  local models_json="[]" models_count=0 smoke="skipped" smoke_detail=""
  local generate_ok="false" first_model="" recommendations=()
  local install_status turnkey_status
  install_status="$(read_json_field "$INSTALL_JSON" "status" "missing")"
  turnkey_status="$(read_json_field "$TURNKEY_JSON" "status" "missing")"

  if ai370_lemonade_import_ok || ai370_lemonade_cli >/dev/null 2>&1; then
    package_ok="true"
    state="available"
  fi
  if cli_path="$(ai370_lemonade_cli)"; then
    state="available"
    package_ok="true"
  fi

  if [[ "$state" != "available" ]]; then
    detail="Lemonade not installed. Run scripts/170-install-turnkeyml.sh and scripts/160-install-lemonade.sh first."
    recommendations+=("LEMONADE_PYTHON=python3.12 ./scripts/160-install-lemonade.sh")
  else
    detail="Lemonade package/CLI is available."
    if [[ "$(server_listening)" == "true" ]]; then
      server_up="true"
      action="server-already-up"
    elif maybe_start_server "${cli_path:-lemonade-server}"; then
      server_up="true"
      action="server-started"
    else
      action="server-not-running"
      recommendations+=("Start Lemonade Server then re-validate, or set LEMONADE_START=true")
      recommendations+=("Example: lemonade-server serve  # or open desktop app")
    fi

    if [[ "$server_up" == "true" ]]; then
      local models_raw
      models_raw="$(http_get "${BASE_URL}/models")"
      if [[ -z "$models_raw" ]]; then
        # try without /api prefix variants
        models_raw="$(http_get "http://${LEMONADE_HOST}:${LEMONADE_PORT}/v1/models")"
      fi
      if [[ -n "$models_raw" ]]; then
        models_json="$(printf '%s' "$models_raw" | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
  ids=[]
  if isinstance(d, dict) and "data" in d:
    for m in d["data"]:
      if isinstance(m, dict) and m.get("id"):
        ids.append(m["id"])
  print(json.dumps(ids))
except Exception:
  print("[]")
' 2>/dev/null || echo '[]')"
        models_count="$(printf '%s' "$models_json" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)"
        first_model="$(printf '%s' "$models_json" | python3 -c 'import json,sys; a=json.load(sys.stdin); print(a[0] if a else "")' 2>/dev/null || true)"
      fi

      if [[ "${LEMONADE_PULL_MODEL:-}" != "" && "$OFFLINE" != "true" && -n "$cli_path" ]]; then
        echo "[INFO] Pulling model ${LEMONADE_PULL_MODEL} (online opt-in)..."
        "$cli_path" pull "${LEMONADE_PULL_MODEL}" >/dev/null 2>&1 || true
        models_raw="$(http_get "${BASE_URL}/models")"
        first_model="${LEMONADE_PULL_MODEL}"
      fi

      if [[ -n "$first_model" ]]; then
        smoke="attempted"
        local body resp
        body="$(python3 -c 'import json,sys; print(json.dumps({"model":sys.argv[1],"messages":[{"role":"user","content":"Say hi in one word."}],"max_tokens":int(sys.argv[2]),"temperature":0}))' "$first_model" "$SMOKE_MAX_TOKENS")"
        resp="$(http_post_json "${BASE_URL}/chat/completions" "$body")"
        if [[ -z "$resp" ]]; then
          resp="$(http_post_json "http://${LEMONADE_HOST}:${LEMONADE_PORT}/v1/chat/completions" "$body")"
        fi
        if printf '%s' "$resp" | python3 -c 'import json,sys
d=json.load(sys.stdin)
ok=bool(d.get("choices"))
sys.exit(0 if ok else 1)' 2>/dev/null; then
          generate_ok="true"
          smoke="pass"
          smoke_detail="chat.completions succeeded for model $first_model"
        else
          smoke="fail"
          smoke_detail="chat.completions failed or empty for model $first_model (server up; model may need load)."
        fi
      else
        smoke="skipped-no-model"
        smoke_detail="Server responded or is up but no models listed. Pull a model online or stage one under $AI370_LEMONADE_MODELS."
        recommendations+=("Online: lemonade-server pull Gemma-3-4b-it-GGUF  # example")
        recommendations+=("Or set LEMONADE_PULL_MODEL=... when not --offline")
      fi
    fi
  fi

  # Status policy (WARN-friendly):
  # PASS: package available AND (generate_ok OR models listed on live server OR package-only inventory OK with no server)
  # For honest NPU/serving claims: generate_ok is the strong signal.
  local serving_ready="false" production_ready="false"
  if [[ "$generate_ok" == "true" ]]; then
    serving_ready="true"
    production_ready="true"
    status="PASS"
    detail="Lemonade OpenAI smoke passed ($smoke_detail). Base URL: $BASE_URL"
  elif [[ "$package_ok" == "true" && "$server_up" == "true" && "$models_count" -gt 0 ]]; then
    serving_ready="true"
    status="PASS"
    detail="Lemonade server is up with $models_count model(s) listed; generate smoke not completed. $smoke_detail"
  elif [[ "$package_ok" == "true" ]]; then
    status="WARN"
    if [[ -z "$detail" || "$detail" == "Lemonade package/CLI is available." ]]; then
      detail="Lemonade installed but server not validated with models/generate. $smoke_detail Package listing alone is not NPU inference proof."
    fi
  else
    status="WARN"
  fi

  local rec_json="[]"
  if ((${#recommendations[@]} > 0)); then
    rec_json="$(printf '%s\n' "${recommendations[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
  fi

  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 2,
  "phase": "validate-lemonade",
  "milestone": "S2-M6",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $(bool_json "$OFFLINE"),
  "state": "$state",
  "package_ok": $(bool_json "$package_ok"),
  "server_up": $(bool_json "$server_up"),
  "serving_ready": $(bool_json "$serving_ready"),
  "production_ready": $(bool_json "$production_ready"),
  "generate_ok": $(bool_json "$generate_ok"),
  "smoke": "$smoke",
  "smoke_detail": $(printf '%s' "$smoke_detail" | json_escape),
  "models_count": $models_count,
  "models": $models_json,
  "first_model": $(printf '%s' "$first_model" | json_escape),
  "base_url": $(printf '%s' "$BASE_URL" | json_escape),
  "cli": $(printf '%s' "$cli_path" | json_escape),
  "venv": $(printf '%s' "$VENV_DIR" | json_escape),
  "install_report_status": $(printf '%s' "$install_status" | json_escape),
  "turnkey_report_status": $(printf '%s' "$turnkey_status" | json_escape),
  "action": "$action",
  "npu_claim_policy": "Do not claim NPU inference from package install alone; require server device reports or profiled EP paths.",
  "recommendations": $rec_json,
  "detail": $(printf '%s' "$detail" | json_escape)
}
EOF_JSON

  {
    echo "# Stage 2 — Lemonade Validation (S2-M6)"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- Package OK: $package_ok"
    echo "- Server up: $server_up"
    echo "- Serving ready: $serving_ready"
    echo "- Generate OK: $generate_ok"
    echo "- Smoke: $smoke"
    echo "- Models: $models_count"
    echo "- First model: ${first_model:-none}"
    echo "- Base URL: $BASE_URL"
    echo "- CLI: ${cli_path:-none}"
    echo "- Install report: $install_status | Turnkey report: $turnkey_status"
    echo
    printf '%s\n' "$detail"
    if [[ -n "$smoke_detail" ]]; then
      echo
      echo "Smoke detail: $smoke_detail"
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
