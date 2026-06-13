#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 2 – Recommended AI Runtime Layer (Ollama, llama.cpp, PyTorch, Open WebUI opt, HF cache).
# Produces tier2-validation.json for the cross-tier gate (M2).
# Respects --offline using .ai370-ai/ (tools, models, wheelhouse via config).
# Delegates to legacy 20-ai-stack + 80-llm-validation for compatibility during transition.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
VENV_DIR="$AI_ROOT/venv"
MODEL_ROOT="$AI_ROOT/models"
TOOL_ROOT="$AI_ROOT/tools"
HF_CACHE="${HF_HOME:-$HOME/.cache/huggingface}"

main() {
  mkdir -p "$LATEST_DIR" "$AI_ROOT" "$MODEL_ROOT" "$TOOL_ROOT" "$HF_CACHE"

  echo "[INFO] Tier 2 (100-tier2-ai-runtime.sh)"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  OFFLINE=$OFFLINE"

  # Delegate for legacy visibility (ollama/llama/gguf + basic ai-stack pip)
  if [[ -f "$PROJECT_ROOT/scripts/20-ai-stack.sh" ]]; then
    bash "$PROJECT_ROOT/scripts/20-ai-stack.sh" "$PROFILE" "$MODE" "$PERSISTENCE" "$OFFLINE" || true
  fi
  if [[ -f "$PROJECT_ROOT/scripts/80-llm-validation.sh" ]]; then
    bash "$PROJECT_ROOT/scripts/80-llm-validation.sh" "$PROFILE" "$MODE" "$PERSISTENCE" "$OFFLINE" || true
  fi

  # Re-detect key runtime facts (reuse patterns from 80-llm-validation)
  ollama_state="missing"
  if command -v ollama >/dev/null 2>&1; then
    ollama_state="available"
  fi

  find_llama_binary() {
    for candidate in \
      "$TOOL_ROOT/llama-cli" \
      "$TOOL_ROOT/llama.cpp/llama-cli" \
      "$TOOL_ROOT/llama.cpp/build/bin/llama-cli" \
      "$TOOL_ROOT/main" \
      "$TOOL_ROOT/llama.cpp/main" \
      "$TOOL_ROOT/llama.cpp/build/bin/main"; do
      if [[ -x "$candidate" ]]; then printf '%s\n' "$candidate"; return; fi
    done
    command -v llama-cli 2>/dev/null || true
  }
  llama_binary="$(find_llama_binary || true)"
  llama_state="missing"
  if [[ -n "$llama_binary" ]]; then llama_state="available"; fi

  gguf_count=$(find "$MODEL_ROOT" "$TOOL_ROOT" -maxdepth 5 -type f -iname '*.gguf' 2>/dev/null | wc -l | tr -d ' ' || echo 0)

  # PyTorch (CPU safe; ROCm only after explicit accel + visibility)
  pytorch_state="missing"
  pytorch_rocm="false"
  if [[ "$OFFLINE" != "true" ]]; then
    if [[ ! -x "$VENV_DIR/bin/python" ]]; then
      python3 -m venv "$VENV_DIR" >/dev/null 2>&1 || true
      "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel 2>/dev/null || true
    fi
    "$VENV_DIR/bin/python" -m pip install --upgrade "torch>=2.4" --index-url https://download.pytorch.org/whl/cpu 2>/dev/null || true
  fi
  if [[ -x "$VENV_DIR/bin/python" ]]; then
    if "$VENV_DIR/bin/python" -c 'import torch; print("torch", getattr(torch, "__version__", ""))' >/dev/null 2>&1; then
      pytorch_state="available"
      if "$VENV_DIR/bin/python" -c 'import torch; print("rocm" if (hasattr(torch.version, "hip") and torch.version.hip) else "cpu")' 2>/dev/null | grep -qi rocm; then
        pytorch_rocm="true"
      fi
    fi
  fi

  # HF cache support (directory + marker for offline use)
  hf_state="missing"
  mkdir -p "$HF_CACHE/hub" "$HF_CACHE/modules"
  if [[ -d "$HF_CACHE" ]]; then
    echo "tier2-hf-cache-ready" > "$HF_CACHE/.tier2-marker"
    hf_state="available"
  fi

  # Open WebUI (optional, best-effort detection; do not auto-install heavy container here)
  webui_state="missing"
  if command -v open-webui >/dev/null 2>&1 || docker image ls 2>/dev/null | grep -qi open-webui; then
    webui_state="available"
  fi

  # Simple local inference smoke (prefer llama.cpp if binary+gguf present; else torch/onnx)
  smoke_status="skipped"
  if [[ "$llama_state" == "available" && "$gguf_count" -gt 0 ]]; then
    # Best effort tiny prompt if a gguf exists (non-blocking)
    first_gguf="$(find "$MODEL_ROOT" "$TOOL_ROOT" -maxdepth 5 -type f -iname '*.gguf' 2>/dev/null | head -1 || true)"
    if [[ -n "$first_gguf" && -x "$llama_binary" ]]; then
      # Run with very low params; capture exit for smoke flag only (timeout friendly)
      if timeout 8s "$llama_binary" -m "$first_gguf" -p "Hi" -n 4 --no-display-prompt >/dev/null 2>&1; then
        smoke_status="pass"
      else
        smoke_status="warn"
      fi
    fi
  elif [[ "$pytorch_state" == "available" ]]; then
    if "$VENV_DIR/bin/python" -c '
import torch
x = torch.randn(2,2)
print((x+x).shape)
' >/dev/null 2>&1; then
      smoke_status="pass"
    else
      smoke_status="warn"
    fi
  fi

  # Compute status
  status="PASS"
  if [[ "$ollama_state" == "missing" && "$llama_state" == "missing" ]]; then
    status="WARN"
  fi
  if [[ "$pytorch_state" == "missing" ]]; then
    status="WARN"
  fi

  # Write tier2-validation.json (modeled on tier1 for gate consumption)
  cat > "$LATEST_DIR/tier2-validation.json" <<EOF
{
  "tier": 2,
  "status": "$status",
  "timestamp": "$(date -Is)",
  "profile": "$PROFILE",
  "acceptance": {
    "ollama_available": $([[ "$ollama_state" == "available" ]] && echo true || echo false),
    "llama_cpp_available": $([[ "$llama_state" == "available" ]] && echo true || echo false),
    "gguf_models_present": $([[ "$gguf_count" -gt 0 ]] && echo true || echo false),
    "pytorch_available": $([[ "$pytorch_state" == "available" ]] && echo true || echo false),
    "pytorch_rocm": $pytorch_rocm,
    "hf_cache_ok": $([[ "$hf_state" == "available" ]] && echo true || echo false),
    "open_webui_available": $([[ "$webui_state" == "available" ]] && echo true || echo false),
    "local_inference_smoke": "$smoke_status"
  },
  "artifacts": {
    "llm_validation": "reports/latest/llm-validation.json",
    "tier2_validation": "reports/latest/tier2-validation.json"
  },
  "notes": "ROCm PyTorch and full acceleration require explicit amd-accel-install --accept-amd-acceleration-risk and re-validation. NPU via Tier 3 (experimental)."
}
EOF

  # Human summary
  {
  echo "# Tier 2 AI Runtime Validation"
  echo
  echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
  echo "Status: $status"
  echo
  echo "## Acceptance"
  echo "- Ollama: $ollama_state"
  echo "- llama.cpp: $llama_state (binary: ${llama_binary:-n/a})"
  echo "- GGUF models staged: $gguf_count"
  echo "- PyTorch: $pytorch_state (ROCm: $pytorch_rocm)"
  echo "- HF cache ready: $hf_state"
  echo "- Open WebUI (opt): $webui_state"
  echo "- Local inference smoke: $smoke_status"
  echo
  echo "Next: Run \`./ai370-optimize.sh tier2-validate\` (when implemented) or ensure this JSON has status PASS/WARN before Tier 5."
  echo "See reports/latest/llm-validation.json for detailed legacy LLM visibility."
  } > "$LATEST_DIR/tier2-validation.md"

  echo "[INFO] Wrote tier2-validation.json (status=$status)"
  echo "[INFO] Tier 2 complete."
}

main "$@"
