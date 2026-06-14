#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Milestone 2: PyTorch ROCm installer / validator.
# Online mode installs into the repo-local venv. Offline mode only validates a
# pre-staged venv/wheelhouse and records clean missing-state reports.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
VENV_DIR="$AI_ROOT/venv"
WHEELHOUSE="$AI_ROOT/wheelhouse"
STATUS_JSON="$LATEST_DIR/tier2-pytorch-rocm.json"
SUMMARY_MD="$LATEST_DIR/tier2-pytorch-rocm.md"
PYTORCH_ROCM_INDEX="${PYTORCH_ROCM_INDEX:-https://download.pytorch.org/whl/rocm6.2}"

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

write_report() {
  local status="$1" torch_state="$2" rocm_state="$3" hip_state="$4" install_action="$5" detail="$6"
  local detail_json
  detail_json="$(printf '%s' "$detail" | json_escape)"
  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 2,
  "phase": "install-pytorch-rocm",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $([[ "$OFFLINE" == "true" ]] && echo true || echo false),
  "venv": "$VENV_DIR",
  "pytorch": {
    "state": "$torch_state",
    "rocm_runtime": "$rocm_state",
    "hip_available": "$hip_state"
  },
  "install_action": "$install_action",
  "detail": $detail_json
}
EOF_JSON
  {
    echo "# Tier 2 PyTorch ROCm Status"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- PyTorch: $torch_state"
    echo "- ROCm runtime: $rocm_state"
    echo "- torch.version.hip: $hip_state"
    echo "- Install action: $install_action"
    echo
    printf '```text\n%s\n```\n' "$detail"
  } > "$SUMMARY_MD"
}

main() {
  mkdir -p "$LATEST_DIR" "$AI_ROOT"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent PyTorch installation is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local install_action="none" detail="" rocm_state="missing"
  if command -v rocminfo >/dev/null 2>&1; then
    rocm_state="visible"
  fi

  if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    if [[ "$OFFLINE" == "true" ]]; then
      install_action="skipped-offline-missing-venv"
      detail="Offline mode: $VENV_DIR is missing. Stage a populated venv or wheelhouse before rerunning."
    else
      if python3 -m venv "$VENV_DIR" && "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel; then
        install_action="created-venv"
      else
        install_action="venv-create-failed"
        detail="Failed to create or bootstrap Python venv at $VENV_DIR. Ensure python3-venv and pip are installed."
      fi
    fi
  fi

  if [[ -x "$VENV_DIR/bin/python" && "$OFFLINE" != "true" ]]; then
    if [[ "$rocm_state" == "visible" ]]; then
      install_action="pip-install-rocm"
      "$VENV_DIR/bin/python" -m pip install --upgrade torch torchvision torchaudio --index-url "$PYTORCH_ROCM_INDEX" || detail="PyTorch ROCm pip install failed; see console output."
    else
      install_action="pip-install-cpu-fallback"
      "$VENV_DIR/bin/python" -m pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu || detail="PyTorch CPU fallback pip install failed; see console output."
    fi
  elif [[ -x "$VENV_DIR/bin/python" && "$OFFLINE" == "true" && -d "$WHEELHOUSE" ]]; then
    install_action="offline-wheelhouse-available"
  fi

  local torch_state="missing" hip_state="false" status="WARN"
  if [[ -x "$VENV_DIR/bin/python" ]]; then
    if "$VENV_DIR/bin/python" -c 'import importlib.util, sys; sys.exit(0 if importlib.util.find_spec("torch") else 1)' >/dev/null 2>&1; then
      torch_state="available"
      hip_state="$($VENV_DIR/bin/python -c 'import torch; print("true" if getattr(torch.version, "hip", None) else "false")' 2>/dev/null || echo false)"
      status="PASS"
      if [[ "$rocm_state" == "visible" && "$hip_state" != "true" ]]; then
        status="WARN"
        detail="ROCm is visible, but installed PyTorch does not expose HIP. Use PYTORCH_ROCM_INDEX to select an approved ROCm wheel index."
      fi
    fi
  fi

  if [[ -z "$detail" ]]; then
    detail="PyTorch validation completed. ROCm is optional and is cleanly reported when unavailable."
  fi

  write_report "$status" "$torch_state" "$rocm_state" "$hip_state" "$install_action" "$detail"
  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
}

main "$@"
