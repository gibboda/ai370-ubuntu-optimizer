#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Milestone 2 / S2-M4: local AI runtime validation and measured smoke benchmarks.
# Records load_time_ms, tokens_generated, tokens_per_sec when a local model runs.
# Does not download models or pull Ollama manifests.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
OPEN_WEBUI_VENV_DIR="${OPEN_WEBUI_VENV_DIR:-$AI_ROOT/open-webui-venv}"
MODEL_ROOT="$AI_ROOT/models"
TOOL_ROOT="$AI_ROOT/tools"
STATUS_TXT="$LATEST_DIR/llm-validation-status.txt"
STATUS_JSON="$LATEST_DIR/llm-validation.json"
SUMMARY_MD="$LATEST_DIR/llm-validation.md"
BENCHMARK_JSON="$LATEST_DIR/tier2-runtime-benchmark.json"
BENCHMARK_MD="$LATEST_DIR/tier2-runtime-benchmark.md"
TIER2_JSON="$LATEST_DIR/tier2-validation.json"
TIER2_MD="$LATEST_DIR/tier2-validation.md"

# Smoke benchmark knobs (override via environment).
SMOKE_N_PREDICT="${SMOKE_N_PREDICT:-16}"
SMOKE_PROMPT="${SMOKE_PROMPT:-Hi}"
SMOKE_LLAMA_TIMEOUT_SEC="${SMOKE_LLAMA_TIMEOUT_SEC:-90}"
SMOKE_OLLAMA_TIMEOUT_SEC="${SMOKE_OLLAMA_TIMEOUT_SEC:-120}"
OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"
# S2-M6 Lemonade OpenAI-compatible defaults (optional smoke when server is up)
LEMONADE_HOST="${LEMONADE_HOST:-127.0.0.1}"
LEMONADE_PORT="${LEMONADE_PORT:-8000}"
LEMONADE_BASE_URL="${LEMONADE_BASE_URL:-http://${LEMONADE_HOST}:${LEMONADE_PORT}/api/v1}"
LEMONADE_API_KEY="${LEMONADE_API_KEY:-lemonade}"
SMOKE_LEMONADE_TIMEOUT_SEC="${SMOKE_LEMONADE_TIMEOUT_SEC:-30}"

capture_command() {
  local command_name="$1"
  shift
  if command -v "$command_name" >/dev/null 2>&1; then
    "$command_name" "$@" 2>&1 || true
  else
    echo "command-not-found: $command_name"
  fi
}

find_llama_binary() {
  local candidate
  for candidate in \
    "$TOOL_ROOT/llama-cli" \
    "$TOOL_ROOT/llama.cpp/llama-cli" \
    "$TOOL_ROOT/llama.cpp/build/bin/llama-cli" \
    "$TOOL_ROOT/main" \
    "$TOOL_ROOT/llama.cpp/main" \
    "$TOOL_ROOT/llama.cpp/build/bin/main"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  if command -v llama-cli >/dev/null 2>&1; then
    command -v llama-cli
  fi
}

# First model name from `ollama list` table (skip header).
first_ollama_model() {
  local list_text="$1"
  printf '%s\n' "$list_text" | awk '
    NR == 1 && $1 ~ /^NAME$/ { next }
    NF >= 1 && $1 != "" && $1 != "NAME" { print $1; exit }
  '
}

# Run llama.cpp smoke; print metrics as KEY=VALUE lines on stdout for the caller.
# Metrics: smoke_backend, smoke_model, smoke_status, load_time_ms, tokens_generated,
# tokens_per_sec, wall_time_ms, detail
run_llama_smoke() {
  local binary="$1"
  local model_path="$2"
  local log
  log="$(mktemp)"
  local start_ns end_ns wall_ms rc=0
  start_ns="$(date +%s%N)"
  # Prefer timings on stderr; keep full log for parsing.
  set +e
  timeout "${SMOKE_LLAMA_TIMEOUT_SEC}s" "$binary" \
    -m "$model_path" \
    -p "$SMOKE_PROMPT" \
    -n "$SMOKE_N_PREDICT" \
    --no-display-prompt \
    </dev/null >"$log" 2>&1
  rc=$?
  set -e
  end_ns="$(date +%s%N)"
  wall_ms="$(python3 -c "print(round(($end_ns - $start_ns) / 1e6, 3))")"

  local parsed
  parsed="$(python3 - "$log" "$wall_ms" "$SMOKE_N_PREDICT" <<'PY'
import re
import sys
from pathlib import Path

log_path, wall_ms_s, n_predict_s = sys.argv[1], sys.argv[2], sys.argv[3]
text = Path(log_path).read_text(errors="replace")
wall_ms = float(wall_ms_s)
n_predict = int(n_predict_s)

load_ms = None
eval_ms = None
eval_tokens = None
tps = None

# llama.cpp classic timings
# load time =  1234.56 ms
m = re.search(r"load time\s*=\s*([0-9.]+)\s*ms", text, re.I)
if m:
    load_ms = float(m.group(1))

# eval time =  123.45 ms / 16 runs ( 7.72 ms per token, 129.61 tokens per second)
m = re.search(
    r"eval time\s*=\s*([0-9.]+)\s*ms\s*/\s*(\d+)\s*runs.*?([0-9.]+)\s*tokens per second",
    text,
    re.I | re.S,
)
if m:
    eval_ms = float(m.group(1))
    eval_tokens = int(m.group(2))
    tps = float(m.group(3))

# Newer perf lines (tokens per second alone)
if tps is None:
    m = re.search(r"([0-9.]+)\s*tokens per second", text, re.I)
    if m:
        tps = float(m.group(1))

if eval_tokens is None:
    m = re.search(r"eval time\s*=\s*[0-9.]+\s*ms\s*/\s*(\d+)", text, re.I)
    if m:
        eval_tokens = int(m.group(1))

if tps is None and eval_tokens and eval_ms and eval_ms > 0:
    tps = eval_tokens / (eval_ms / 1000.0)

if eval_tokens is None and tps is not None:
    eval_tokens = n_predict

print(f"load_time_ms={load_ms if load_ms is not None else ''}")
print(f"tokens_generated={eval_tokens if eval_tokens is not None else ''}")
print(f"tokens_per_sec={tps if tps is not None else ''}")
print(f"wall_time_ms={wall_ms}")
print(f"eval_time_ms={eval_ms if eval_ms is not None else ''}")
# success signal for caller: prefer parsed tps, else wall-only if rc handled outside
if tps is not None or eval_tokens is not None:
    print("parse_ok=true")
else:
    print("parse_ok=false")
PY
)"

  rm -f "$log"

  echo "smoke_backend=llama.cpp"
  echo "smoke_model=$model_path"
  echo "wall_time_ms=$wall_ms"
  # shellcheck disable=SC2001
  printf '%s\n' "$parsed"

  if [[ $rc -eq 0 ]]; then
    echo "smoke_status=pass"
    echo "detail=llama.cpp smoke completed (exit 0)"
    return 0
  elif [[ $rc -eq 124 ]]; then
    echo "smoke_status=warn"
    echo "detail=llama.cpp smoke timed out after ${SMOKE_LLAMA_TIMEOUT_SEC}s"
    return 1
  else
    echo "smoke_status=warn"
    echo "detail=llama.cpp smoke exited with code $rc"
    return 1
  fi
}

# Ollama non-streaming generate API for accurate eval metrics.
run_ollama_smoke() {
  local model="$1"
  local payload tmp start_ns end_ns wall_ms rc=0
  payload="$(
    M="$model" P="$SMOKE_PROMPT" N="$SMOKE_N_PREDICT" python3 -c '
import json, os
print(json.dumps({
  "model": os.environ["M"],
  "prompt": os.environ["P"],
  "stream": False,
  "options": {"num_predict": int(os.environ["N"])},
}))
'
  )"

  tmp="$(mktemp)"
  start_ns="$(date +%s%N)"
  set +e
  if command -v curl >/dev/null 2>&1; then
    timeout "${SMOKE_OLLAMA_TIMEOUT_SEC}s" curl -fsS \
      --max-time "$SMOKE_OLLAMA_TIMEOUT_SEC" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "http://${OLLAMA_HOST}/api/generate" >"$tmp" 2>/dev/null
    rc=$?
  else
    rc=127
  fi
  set -e
  end_ns="$(date +%s%N)"
  wall_ms="$(python3 -c "print(round(($end_ns - $start_ns) / 1e6, 3))")"

  if [[ $rc -ne 0 ]]; then
    rm -f "$tmp"
    # Fallback: CLI run (weaker metrics)
    local cli_log
    cli_log="$(mktemp)"
    start_ns="$(date +%s%N)"
    set +e
    timeout "${SMOKE_OLLAMA_TIMEOUT_SEC}s" ollama run "$model" "$SMOKE_PROMPT" </dev/null >"$cli_log" 2>&1
    rc=$?
    set -e
    end_ns="$(date +%s%N)"
    wall_ms="$(python3 -c "print(round(($end_ns - $start_ns) / 1e6, 3))")"
    rm -f "$cli_log"
    echo "smoke_backend=ollama"
    echo "smoke_model=$model"
    echo "load_time_ms="
    echo "tokens_generated="
    echo "tokens_per_sec="
    echo "wall_time_ms=$wall_ms"
    echo "eval_time_ms="
    if [[ $rc -eq 0 ]]; then
      echo "smoke_status=pass"
      echo "detail=ollama CLI smoke completed; API metrics unavailable (curl failed or daemon API not reachable)"
      return 0
    fi
    echo "smoke_status=warn"
    echo "detail=ollama smoke failed (API/CLI). Is the Ollama service running on $OLLAMA_HOST?"
    return 1
  fi

  python3 - "$tmp" "$wall_ms" "$model" <<'PY'
import json
import sys
from pathlib import Path

path, wall_ms_s, model = sys.argv[1], sys.argv[2], sys.argv[3]
wall_ms = float(wall_ms_s)
raw = Path(path).read_text(errors="replace").strip()
data = json.loads(raw) if raw else {}

load_ns = data.get("load_duration")
eval_ns = data.get("eval_duration")
eval_count = data.get("eval_count")

load_ms = round(load_ns / 1e6, 3) if isinstance(load_ns, (int, float)) else None
eval_ms = round(eval_ns / 1e6, 3) if isinstance(eval_ns, (int, float)) else None
tps = None
if isinstance(eval_count, int) and isinstance(eval_ns, (int, float)) and eval_ns > 0:
    tps = round(eval_count / (eval_ns / 1e9), 3)

print("smoke_backend=ollama")
print(f"smoke_model={model}")
print(f"load_time_ms={load_ms if load_ms is not None else ''}")
print(f"tokens_generated={eval_count if eval_count is not None else ''}")
print(f"tokens_per_sec={tps if tps is not None else ''}")
print(f"wall_time_ms={wall_ms}")
print(f"eval_time_ms={eval_ms if eval_ms is not None else ''}")
if data.get("error"):
    print("smoke_status=warn")
    print(f"detail=ollama API error: {data.get('error')}")
    raise SystemExit(1)
if tps is not None or eval_count is not None:
    print("smoke_status=pass")
    print("detail=ollama /api/generate smoke completed with metrics")
else:
    print("smoke_status=pass")
    print("detail=ollama /api/generate completed but timing fields were missing")
PY
  local py_rc=$?
  rm -f "$tmp"
  return "$py_rc"
}

# Optional Lemonade OpenAI smoke when a local server is already running with models.
run_lemonade_smoke() {
  local start_ns end_ns wall_ms models_raw first_model body resp
  start_ns="$(date +%s%N)"
  models_raw=""
  if command -v curl >/dev/null 2>&1; then
    models_raw="$(curl -fsS --max-time "$SMOKE_LEMONADE_TIMEOUT_SEC" "${LEMONADE_BASE_URL}/models" 2>/dev/null || true)"
  fi
  if [[ -z "$models_raw" ]]; then
    end_ns="$(date +%s%N)"
    wall_ms="$(python3 -c "print(round(($end_ns - $start_ns) / 1e6, 3))")"
    echo "smoke_backend=lemonade"
    echo "smoke_model="
    echo "load_time_ms="
    echo "tokens_generated="
    echo "tokens_per_sec="
    echo "wall_time_ms=$wall_ms"
    echo "eval_time_ms="
    echo "smoke_status=warn"
    echo "detail=lemonade server not reachable at ${LEMONADE_BASE_URL}/models (start server or skip)"
    return 1
  fi
  first_model="$(printf '%s' "$models_raw" | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
  data=d.get("data") or []
  print(data[0]["id"] if data and isinstance(data[0], dict) else "")
except Exception:
  print("")
' 2>/dev/null || true)"
  if [[ -z "$first_model" ]]; then
    end_ns="$(date +%s%N)"
    wall_ms="$(python3 -c "print(round(($end_ns - $start_ns) / 1e6, 3))")"
    echo "smoke_backend=lemonade"
    echo "smoke_model="
    echo "load_time_ms="
    echo "tokens_generated="
    echo "tokens_per_sec="
    echo "wall_time_ms=$wall_ms"
    echo "eval_time_ms="
    echo "smoke_status=warn"
    echo "detail=lemonade /models returned no model ids"
    return 1
  fi
  body="$(python3 -c 'import json,sys; print(json.dumps({"model":sys.argv[1],"messages":[{"role":"user","content":sys.argv[2]}],"max_tokens":int(sys.argv[3]),"temperature":0}))' "$first_model" "$SMOKE_PROMPT" "$SMOKE_N_PREDICT")"
  start_ns="$(date +%s%N)"
  set +e
  resp="$(curl -fsS --max-time "$SMOKE_LEMONADE_TIMEOUT_SEC" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${LEMONADE_API_KEY}" \
    -d "$body" \
    "${LEMONADE_BASE_URL}/chat/completions" 2>/dev/null || true)"
  set -e
  end_ns="$(date +%s%N)"
  wall_ms="$(python3 -c "print(round(($end_ns - $start_ns) / 1e6, 3))")"
  if printf '%s' "$resp" | python3 -c 'import json,sys; d=json.load(sys.stdin); raise SystemExit(0 if d.get("choices") else 1)' 2>/dev/null; then
    local tokens
    tokens="$(printf '%s' "$resp" | python3 -c 'import json,sys
d=json.load(sys.stdin)
u=d.get("usage") or {}
print(u.get("completion_tokens") or u.get("total_tokens") or "")
' 2>/dev/null || true)"
    echo "smoke_backend=lemonade"
    echo "smoke_model=$first_model"
    echo "load_time_ms="
    echo "tokens_generated=${tokens}"
    if [[ -n "$tokens" && "$tokens" != "0" ]]; then
      echo "tokens_per_sec=$(python3 -c "print(round(float('$tokens') / (float('$wall_ms')/1000.0), 3) if float('$wall_ms')>0 else '')" 2>/dev/null || true)"
    else
      echo "tokens_per_sec="
    fi
    echo "wall_time_ms=$wall_ms"
    echo "eval_time_ms="
    echo "smoke_status=pass"
    echo "detail=lemonade OpenAI chat.completions smoke completed"
    return 0
  fi
  echo "smoke_backend=lemonade"
  echo "smoke_model=$first_model"
  echo "load_time_ms="
  echo "tokens_generated="
  echo "tokens_per_sec="
  echo "wall_time_ms=$wall_ms"
  echo "eval_time_ms="
  echo "smoke_status=warn"
  echo "detail=lemonade chat.completions failed or empty"
  return 1
}

run_pytorch_smoke() {
  local start_ns end_ns wall_ms
  local out
  start_ns="$(date +%s%N)"
  set +e
  out="$("$AI_ROOT/venv/bin/python" - <<'PY' 2>&1
import time
import torch

device = "cpu"
if getattr(torch.version, "hip", None) and torch.cuda.is_available():
    device = "cuda"
t0 = time.perf_counter()
x = torch.randn(512, 512, device=device)
for _ in range(20):
    x = x @ x
if device == "cuda":
    torch.cuda.synchronize()
elapsed_ms = (time.perf_counter() - t0) * 1000.0
print(f"device={device}")
print(f"matmul_ms={elapsed_ms:.3f}")
print(f"hip={bool(getattr(torch.version, 'hip', None))}")
PY
)"
  local rc=$?
  set -e
  end_ns="$(date +%s%N)"
  wall_ms="$(python3 -c "print(round(($end_ns - $start_ns) / 1e6, 3))")"

  echo "smoke_backend=pytorch"
  echo "smoke_model=torch.matmul_512"
  echo "load_time_ms="
  echo "tokens_generated="
  echo "tokens_per_sec="
  echo "wall_time_ms=$wall_ms"
  echo "eval_time_ms="
  if [[ $rc -eq 0 ]]; then
    local matmul_ms device
    matmul_ms="$(printf '%s\n' "$out" | awk -F= '/^matmul_ms=/ {print $2; exit}')"
    device="$(printf '%s\n' "$out" | awk -F= '/^device=/ {print $2; exit}')"
    echo "smoke_status=pass"
    echo "detail=PyTorch matmul smoke on ${device:-unknown} (${matmul_ms:-?} ms); not token-generation metrics"
    # Stash matmul latency as wall when useful
    if [[ -n "$matmul_ms" ]]; then
      echo "eval_time_ms=$matmul_ms"
    fi
    return 0
  fi
  echo "smoke_status=warn"
  echo "detail=PyTorch smoke failed: $out"
  return 1
}

# Parse KEY=VALUE lines into shell variables (safe subset).
apply_metric_lines() {
  local line key value
  SMOKE_BACKEND=""
  SMOKE_MODEL=""
  SMOKE_STATUS="skipped"
  LOAD_TIME_MS=""
  TOKENS_GENERATED=""
  TOKENS_PER_SEC=""
  WALL_TIME_MS=""
  EVAL_TIME_MS=""
  SMOKE_DETAIL=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* ]] || continue
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      smoke_backend) SMOKE_BACKEND="$value" ;;
      smoke_model) SMOKE_MODEL="$value" ;;
      smoke_status) SMOKE_STATUS="$value" ;;
      load_time_ms) LOAD_TIME_MS="$value" ;;
      tokens_generated) TOKENS_GENERATED="$value" ;;
      tokens_per_sec) TOKENS_PER_SEC="$value" ;;
      wall_time_ms) WALL_TIME_MS="$value" ;;
      eval_time_ms) EVAL_TIME_MS="$value" ;;
      detail) SMOKE_DETAIL="$value" ;;
    esac
  done
}

main() {
  echo "[INFO] Tier 2: LLM runtime benchmark and validation"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"
  echo "[INFO] Offline: $OFFLINE"
  echo "[INFO] Smoke: n_predict=$SMOKE_N_PREDICT prompt=$(printf '%q' "$SMOKE_PROMPT")"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent LLM runtime configuration is not implemented yet. Use --persistence=runtime."
    exit 2
  fi

  mkdir -p "$LATEST_DIR" "$MODEL_ROOT" "$TOOL_ROOT"

  local ollama_state ollama_version ollama_list llama_binary llama_state llama_version gguf_files status
  local pytorch_state pytorch_rocm open_webui_state open_webui_source local_inference_smoke first_gguf
  local ollama_model=""
  local metric_blob=""

  # Metric fields (empty string means not measured)
  local SMOKE_BACKEND="" SMOKE_MODEL="" SMOKE_STATUS="skipped"
  local LOAD_TIME_MS="" TOKENS_GENERATED="" TOKENS_PER_SEC="" WALL_TIME_MS="" EVAL_TIME_MS=""
  local SMOKE_DETAIL="No local model available for measured smoke."

  ollama_version="$(capture_command ollama --version)"
  ollama_list="$(capture_command ollama list)"
  if [[ "$ollama_version" == command-not-found:* ]]; then
    ollama_state="missing"
  else
    ollama_state="available"
  fi

  llama_binary="$(find_llama_binary || true)"
  if [[ -n "$llama_binary" ]]; then
    llama_state="available"
    llama_version="$($llama_binary --version 2>&1 || true)"
  else
    llama_state="missing"
    llama_version="not-run"
  fi

  gguf_files="$(find "$MODEL_ROOT" -maxdepth 5 -type f -iname '*.gguf' 2>/dev/null || true)"

  pytorch_state="missing"
  pytorch_rocm="false"
  if [[ -x "$AI_ROOT/venv/bin/python" ]]; then
    if "$AI_ROOT/venv/bin/python" -c 'import importlib.util, sys; sys.exit(0 if importlib.util.find_spec("torch") else 1)' >/dev/null 2>&1; then
      pytorch_state="available"
      pytorch_rocm="$("$AI_ROOT/venv/bin/python" -c 'import torch; print("true" if getattr(torch.version, "hip", None) else "false")' 2>/dev/null || echo false)"
    fi
  fi

  open_webui_state="missing"
  open_webui_source="not-found"
  if command -v open-webui >/dev/null 2>&1; then
    open_webui_state="available"
    open_webui_source="cli:$(command -v open-webui)"
  elif [[ -x "$OPEN_WEBUI_VENV_DIR/bin/python" ]] && "$OPEN_WEBUI_VENV_DIR/bin/python" -c 'import importlib.util, sys; sys.exit(0 if importlib.util.find_spec("open_webui") else 1)' >/dev/null 2>&1; then
    open_webui_state="available"
    open_webui_source="venv:$OPEN_WEBUI_VENV_DIR"
  elif [[ -x "$AI_ROOT/venv/bin/python" ]] && "$AI_ROOT/venv/bin/python" -c 'import importlib.util, sys; sys.exit(0 if importlib.util.find_spec("open_webui") else 1)' >/dev/null 2>&1; then
    open_webui_state="available"
    open_webui_source="legacy-venv:$AI_ROOT/venv"
  elif command -v docker >/dev/null 2>&1 && docker image ls 2>/dev/null | grep -qi open-webui; then
    open_webui_state="available"
    open_webui_source="docker-image"
  fi

  # Prefer token-generating backends: llama.cpp GGUF, then Ollama, then Lemonade
  # (S2-M6 OpenAI server if already running), then PyTorch matmul fallback.
  local_inference_smoke="skipped"
  if [[ "$llama_state" == "available" && -n "$gguf_files" ]]; then
    first_gguf="$(printf '%s\n' "$gguf_files" | head -n 1)"
    echo "[INFO] Measured smoke: llama.cpp + $first_gguf"
    metric_blob="$(run_llama_smoke "$llama_binary" "$first_gguf" || true)"
    apply_metric_lines <<<"$metric_blob"
    local_inference_smoke="$SMOKE_STATUS"
  elif [[ "$ollama_state" == "available" && "$ollama_list" == *"NAME"* ]]; then
    ollama_model="$(first_ollama_model "$ollama_list" || true)"
    if [[ -n "$ollama_model" ]]; then
      echo "[INFO] Measured smoke: ollama + $ollama_model"
      metric_blob="$(run_ollama_smoke "$ollama_model" || true)"
      apply_metric_lines <<<"$metric_blob"
      local_inference_smoke="$SMOKE_STATUS"
    else
      local_inference_smoke="skipped"
      SMOKE_DETAIL="Ollama is available but no model name could be parsed from ollama list."
    fi
  else
    # Try Lemonade only when no llama/ollama model path already smoked.
    metric_blob="$(run_lemonade_smoke || true)"
    apply_metric_lines <<<"$metric_blob"
    if [[ "${SMOKE_STATUS:-}" == "pass" ]]; then
      local_inference_smoke="pass"
      echo "[INFO] Measured smoke: lemonade + ${SMOKE_MODEL:-unknown}"
    elif [[ "$pytorch_state" == "available" ]]; then
      echo "[INFO] Measured smoke: PyTorch matmul fallback (no local LLM model)"
      metric_blob="$(run_pytorch_smoke || true)"
      apply_metric_lines <<<"$metric_blob"
      local_inference_smoke="$SMOKE_STATUS"
    elif [[ "${SMOKE_BACKEND:-}" == "lemonade" ]]; then
      local_inference_smoke="${SMOKE_STATUS:-warn}"
    fi
  fi

  status="PASS"
  if [[ "$ollama_state" == "missing" && "$llama_state" == "missing" ]]; then
    status="WARN"
  fi
  if [[ -z "$gguf_files" && "$ollama_list" != *"NAME"* ]]; then
    status="WARN"
  fi
  if [[ "$pytorch_state" == "missing" ]]; then
    status="WARN"
  fi
  if [[ "$local_inference_smoke" == "warn" ]]; then
    status="WARN"
  fi

  {
    echo "LLM Validation Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
    echo "Status: $status"
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo
    echo "ollama: $ollama_state"
    echo "llama_cpp: $llama_state"
    echo "llama_binary: ${llama_binary:-not-found}"
    echo "gguf_models: $([[ -n "$gguf_files" ]] && echo present || echo missing)"
    echo "pytorch: $pytorch_state"
    echo "pytorch_rocm: $pytorch_rocm"
    echo "open_webui: $open_webui_state"
    echo "open_webui_source: $open_webui_source"
    echo "local_inference_smoke: $local_inference_smoke"
    echo "smoke_backend: ${SMOKE_BACKEND:-none}"
    echo "smoke_model: ${SMOKE_MODEL:-none}"
    echo "load_time_ms: ${LOAD_TIME_MS:-n/a}"
    echo "tokens_generated: ${TOKENS_GENERATED:-n/a}"
    echo "tokens_per_sec: ${TOKENS_PER_SEC:-n/a}"
    echo "wall_time_ms: ${WALL_TIME_MS:-n/a}"
    echo "eval_time_ms: ${EVAL_TIME_MS:-n/a}"
    echo "smoke_detail: ${SMOKE_DETAIL:-}"
  } > "$STATUS_TXT"

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" STATUS="$status" \
  OLLAMA_STATE="$ollama_state" OLLAMA_VERSION="$ollama_version" OLLAMA_LIST="$ollama_list" \
  LLAMA_STATE="$llama_state" LLAMA_BINARY="${llama_binary:-}" LLAMA_VERSION="$llama_version" GGUF_FILES="$gguf_files" \
  PYTORCH_STATE="$pytorch_state" PYTORCH_ROCM="$pytorch_rocm" OPEN_WEBUI_STATE="$open_webui_state" OPEN_WEBUI_SOURCE="$open_webui_source" \
  LOCAL_INFERENCE_SMOKE="$local_inference_smoke" \
  SMOKE_BACKEND="${SMOKE_BACKEND:-}" SMOKE_MODEL="${SMOKE_MODEL:-}" SMOKE_DETAIL="${SMOKE_DETAIL:-}" \
  LOAD_TIME_MS="${LOAD_TIME_MS:-}" TOKENS_GENERATED="${TOKENS_GENERATED:-}" TOKENS_PER_SEC="${TOKENS_PER_SEC:-}" \
  WALL_TIME_MS="${WALL_TIME_MS:-}" EVAL_TIME_MS="${EVAL_TIME_MS:-}" \
  SMOKE_N_PREDICT="$SMOKE_N_PREDICT" \
  python3 - "$STATUS_JSON" "$BENCHMARK_JSON" "$TIER2_JSON" <<'PY'
import json
import os
import sys
from pathlib import Path

status_path, benchmark_path, tier2_path = sys.argv[1:]
gguf_models = [line for line in os.environ.get("GGUF_FILES", "").splitlines() if line.strip()]
ollama_has_models = "NAME" in os.environ.get("OLLAMA_LIST", "")

def num_or_none(key):
    raw = os.environ.get(key, "").strip()
    if raw == "":
        return None
    try:
        if "." in raw:
            return float(raw)
        return int(raw)
    except ValueError:
        try:
            return float(raw)
        except ValueError:
            return None

metrics = {
    "backend": os.environ.get("SMOKE_BACKEND") or None,
    "model": os.environ.get("SMOKE_MODEL") or None,
    "status": os.environ.get("LOCAL_INFERENCE_SMOKE") or "skipped",
    "load_time_ms": num_or_none("LOAD_TIME_MS"),
    "tokens_generated": num_or_none("TOKENS_GENERATED"),
    "tokens_per_sec": num_or_none("TOKENS_PER_SEC"),
    "wall_time_ms": num_or_none("WALL_TIME_MS"),
    "eval_time_ms": num_or_none("EVAL_TIME_MS"),
    "n_predict": num_or_none("SMOKE_N_PREDICT"),
    "detail": os.environ.get("SMOKE_DETAIL") or "",
}
measured = metrics["tokens_per_sec"] is not None or (
    metrics["backend"] == "pytorch" and metrics["status"] == "pass"
)

llm_data = {
    "profile": os.environ["PROFILE"],
    "mode": os.environ["MODE"],
    "persistence": os.environ["PERSISTENCE"],
    "offline": os.environ["OFFLINE"] == "true",
    "status": os.environ["STATUS"],
    "ollama": {
        "state": os.environ["OLLAMA_STATE"],
        "version": os.environ.get("OLLAMA_VERSION", ""),
        "list": os.environ.get("OLLAMA_LIST", ""),
    },
    "llama_cpp": {
        "state": os.environ["LLAMA_STATE"],
        "binary": os.environ.get("LLAMA_BINARY", ""),
        "version": os.environ.get("LLAMA_VERSION", ""),
    },
    "pytorch": {
        "state": os.environ["PYTORCH_STATE"],
        "rocm": os.environ["PYTORCH_ROCM"] == "true",
    },
    "open_webui": {"state": os.environ["OPEN_WEBUI_STATE"], "source": os.environ["OPEN_WEBUI_SOURCE"]},
    "gguf_models": gguf_models,
    "local_inference_smoke": os.environ["LOCAL_INFERENCE_SMOKE"],
    "metrics": metrics,
    "policy": (
        "local validation only; model downloads are not attempted by the benchmark phase; "
        "measured smoke records load_time_ms / tokens_per_sec when a local model runs"
    ),
}
Path(status_path).write_text(json.dumps(llm_data, indent=2) + "\n")

benchmark_data = {
    "tier": 2,
    "stage": 2,
    "phase": "benchmark-llm",
    "status": os.environ["STATUS"],
    "offline": os.environ["OFFLINE"] == "true",
    "local_inference_smoke": os.environ["LOCAL_INFERENCE_SMOKE"],
    "measured": measured,
    "metrics": metrics,
    "ollama_state": os.environ["OLLAMA_STATE"],
    "llama_cpp_state": os.environ["LLAMA_STATE"],
    "pytorch_state": os.environ["PYTORCH_STATE"],
    "pytorch_rocm": os.environ["PYTORCH_ROCM"] == "true",
    "gguf_models": gguf_models,
    "open_webui_source": os.environ["OPEN_WEBUI_SOURCE"],
}
Path(benchmark_path).write_text(json.dumps(benchmark_data, indent=2) + "\n")

tier2_data = {
    "tier": 2,
    "stage": 2,
    "status": os.environ["STATUS"],
    "profile": os.environ["PROFILE"],
    "mode": os.environ["MODE"],
    "persistence": os.environ["PERSISTENCE"],
    "offline": os.environ["OFFLINE"] == "true",
    "acceptance": {
        "pytorch_available": os.environ["PYTORCH_STATE"] == "available",
        "pytorch_rocm": os.environ["PYTORCH_ROCM"] == "true",
        "llama_cpp_available": os.environ["LLAMA_STATE"] == "available",
        "ollama_available": os.environ["OLLAMA_STATE"] == "available",
        "open_webui_available": os.environ["OPEN_WEBUI_STATE"] == "available",
        "local_model_available": bool(gguf_models) or ollama_has_models,
        "local_inference_smoke": os.environ["LOCAL_INFERENCE_SMOKE"],
        "measured_smoke": measured,
        "tokens_per_sec": metrics["tokens_per_sec"],
        "load_time_ms": metrics["load_time_ms"],
        "benchmark_report_generated": True,
    },
    "artifacts": {
        "pytorch": "reports/latest/tier2-pytorch-rocm.json",
        "llama_cpp": "reports/latest/tier2-llama-cpp.json",
        "ollama": "reports/latest/tier2-ollama.json",
        "open_webui": "reports/latest/tier2-open-webui.json",
        "benchmark": "reports/latest/tier2-runtime-benchmark.json",
        "llm_validation": "reports/latest/llm-validation.json",
    },
    "notes": (
        "ROCm is accepted when torch.version.hip is visible; otherwise it is cleanly reported "
        "missing or CPU-only. WARN is accepted by the Stage 3 gate (see docs/ROADMAP.md Stage gate policy)."
    ),
}
Path(tier2_path).write_text(json.dumps(tier2_data, indent=2) + "\n")
PY

  {
    echo "# Ollama / llama.cpp Validation"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "## Ollama"
    echo
    echo "- State: $ollama_state"
    echo
    printf '%s\n%s\n%s\n' '```text' "$ollama_version" '```'
    echo
    echo "## Ollama local models"
    echo
    printf '%s\n%s\n%s\n' '```text' "$ollama_list" '```'
    echo
    echo "## llama.cpp"
    echo
    echo "- State: $llama_state"
    echo "- Binary: ${llama_binary:-not-found}"
    echo
    printf '%s\n%s\n%s\n' '```text' "$llama_version" '```'
    echo
    echo "## Local GGUF models"
    echo
    printf '%s\n%s\n%s\n' '```text' "${gguf_files:-none}" '```'
    echo
    echo "## Measured smoke"
    echo
    echo "- Result: $local_inference_smoke"
    echo "- Backend: ${SMOKE_BACKEND:-none}"
    echo "- Model: ${SMOKE_MODEL:-none}"
    echo "- load_time_ms: ${LOAD_TIME_MS:-n/a}"
    echo "- tokens_generated: ${TOKENS_GENERATED:-n/a}"
    echo "- tokens_per_sec: ${TOKENS_PER_SEC:-n/a}"
    echo "- wall_time_ms: ${WALL_TIME_MS:-n/a}"
    echo "- eval_time_ms: ${EVAL_TIME_MS:-n/a}"
    echo "- Detail: ${SMOKE_DETAIL:-}"
    echo
    echo "## Tier 2 Runtime"
    echo
    echo "- PyTorch: $pytorch_state (ROCm: $pytorch_rocm)"
    echo "- Open WebUI: $open_webui_state ($open_webui_source)"
    echo
    echo "## Policy"
    echo
    echo "This phase validates locally available Ollama, llama.cpp, PyTorch, and Open WebUI assets."
    echo "It does not download models. When a local model is present it runs a short measured smoke"
    echo "and records load_time_ms and tokens_per_sec when the backend exposes them."
  } > "$SUMMARY_MD"

  {
    echo "# Tier 2 Runtime Benchmark"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "## Measured smoke"
    echo
    echo "| Field | Value |"
    echo "| --- | --- |"
    echo "| Result | $local_inference_smoke |"
    echo "| Backend | ${SMOKE_BACKEND:-none} |"
    echo "| Model | ${SMOKE_MODEL:-none} |"
    echo "| load_time_ms | ${LOAD_TIME_MS:-n/a} |"
    echo "| tokens_generated | ${TOKENS_GENERATED:-n/a} |"
    echo "| tokens_per_sec | ${TOKENS_PER_SEC:-n/a} |"
    echo "| wall_time_ms | ${WALL_TIME_MS:-n/a} |"
    echo "| eval_time_ms | ${EVAL_TIME_MS:-n/a} |"
    echo
    echo "- Ollama: $ollama_state"
    echo "- llama.cpp: $llama_state"
    echo "- PyTorch: $pytorch_state (ROCm: $pytorch_rocm)"
    echo
    echo "Detail: ${SMOKE_DETAIL:-}"
  } > "$BENCHMARK_MD"

  {
    echo "# Tier 2 Validation"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "## Acceptance"
    echo "- PyTorch detects ROCm when available: $pytorch_rocm"
    echo "- llama.cpp available/build output: $llama_state"
    echo "- Ollama local models: $([[ "$ollama_list" == *"NAME"* ]] && echo present || echo missing)"
    echo "- Measured smoke: $local_inference_smoke"
    echo "- tokens_per_sec: ${TOKENS_PER_SEC:-n/a}"
    echo "- load_time_ms: ${LOAD_TIME_MS:-n/a}"
    echo "- Benchmark report generated: yes"
    echo
    echo "Gate note: PASS and WARN both satisfy the default Stage 3 gate (see docs/ROADMAP.md)."
  } > "$TIER2_MD"

  echo "[INFO] LLM validation status: $status"
  echo "[INFO] Smoke: $local_inference_smoke backend=${SMOKE_BACKEND:-none} tokens_per_sec=${TOKENS_PER_SEC:-n/a} load_time_ms=${LOAD_TIME_MS:-n/a}"
  echo "[INFO] Wrote $STATUS_TXT"
  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
  echo "[INFO] Wrote $BENCHMARK_JSON"
  echo "[INFO] Wrote $BENCHMARK_MD"
  echo "[INFO] Wrote $TIER2_JSON"
  echo "[INFO] Wrote $TIER2_MD"
  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
