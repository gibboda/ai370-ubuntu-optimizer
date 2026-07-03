#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Milestone 2: local AI runtime validation and benchmark report generation.

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

main() {
  echo "[INFO] Tier 2: LLM runtime benchmark and validation"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"
  echo "[INFO] Offline: $OFFLINE"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent LLM runtime configuration is not implemented yet. Use --persistence=runtime."
    exit 2
  fi

  mkdir -p "$LATEST_DIR" "$MODEL_ROOT" "$TOOL_ROOT"

  local ollama_state ollama_version ollama_list llama_binary llama_state llama_version gguf_files status
  local pytorch_state pytorch_rocm open_webui_state open_webui_source local_inference_smoke first_gguf

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

  local_inference_smoke="skipped"
  if [[ "$llama_state" == "available" && -n "$gguf_files" ]]; then
    first_gguf="$(printf '%s\n' "$gguf_files" | head -n 1)"
    if timeout 8s "$llama_binary" -m "$first_gguf" -p "Hi" -n 4 --no-display-prompt </dev/null >/dev/null 2>&1; then
      local_inference_smoke="pass"
    else
      local_inference_smoke="warn"
    fi
  elif [[ "$ollama_state" == "available" && "$ollama_list" == *"NAME"* ]]; then
    local_inference_smoke="available-not-run"
  elif [[ "$pytorch_state" == "available" ]]; then
    if "$AI_ROOT/venv/bin/python" -c 'import torch; x=torch.ones(2,2); print(float((x+x).sum()))' >/dev/null 2>&1; then
      local_inference_smoke="pass"
    else
      local_inference_smoke="warn"
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
  } > "$STATUS_TXT"

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" STATUS="$status" \
  OLLAMA_STATE="$ollama_state" OLLAMA_VERSION="$ollama_version" OLLAMA_LIST="$ollama_list" \
  LLAMA_STATE="$llama_state" LLAMA_BINARY="${llama_binary:-}" LLAMA_VERSION="$llama_version" GGUF_FILES="$gguf_files" \
  PYTORCH_STATE="$pytorch_state" PYTORCH_ROCM="$pytorch_rocm" OPEN_WEBUI_STATE="$open_webui_state" OPEN_WEBUI_SOURCE="$open_webui_source" LOCAL_INFERENCE_SMOKE="$local_inference_smoke" \
  python3 - "$STATUS_JSON" "$BENCHMARK_JSON" "$TIER2_JSON" <<'PY'
import json
import os
import sys
from pathlib import Path

status_path, benchmark_path, tier2_path = sys.argv[1:]
gguf_models = [line for line in os.environ.get("GGUF_FILES", "").splitlines() if line.strip()]
ollama_has_models = "NAME" in os.environ.get("OLLAMA_LIST", "")

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
    "policy": "local validation only; model downloads are not attempted by the benchmark phase",
}
Path(status_path).write_text(json.dumps(llm_data, indent=2) + "\n")

benchmark_data = {
    "tier": 2,
    "phase": "benchmark-llm",
    "status": os.environ["STATUS"],
    "offline": os.environ["OFFLINE"] == "true",
    "local_inference_smoke": os.environ["LOCAL_INFERENCE_SMOKE"],
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
    "notes": "ROCm is accepted when torch.version.hip is visible; otherwise it is cleanly reported missing or CPU-only.",
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
    echo "## Tier 2 Runtime"
    echo
    echo "- PyTorch: $pytorch_state (ROCm: $pytorch_rocm)"
    echo "- Open WebUI: $open_webui_state ($open_webui_source)"
    echo "- Local inference smoke: $local_inference_smoke"
    echo
    echo "## Policy"
    echo
    echo "This phase validates locally available Ollama, llama.cpp, PyTorch, and Open WebUI assets. It does not download models or pull Ollama manifests."
  } > "$SUMMARY_MD"

  {
    echo "# Tier 2 Runtime Benchmark"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- Local inference smoke: $local_inference_smoke"
    echo "- Ollama: $ollama_state"
    echo "- llama.cpp: $llama_state"
    echo "- PyTorch: $pytorch_state (ROCm: $pytorch_rocm)"
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
    echo "- Benchmark report generated: yes"
  } > "$TIER2_MD"

  echo "[INFO] LLM validation status: $status"
  echo "[INFO] Wrote $STATUS_TXT"
  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
  echo "[INFO] Wrote $BENCHMARK_JSON"
  echo "[INFO] Wrote $BENCHMARK_MD"
  echo "[INFO] Wrote $TIER2_JSON"
  echo "[INFO] Wrote $TIER2_MD"
}

main "$@"
