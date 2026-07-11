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
PYTORCH_CPU_INDEX="${PYTORCH_CPU_INDEX:-https://download.pytorch.org/whl/cpu}"
PYTORCH_NIGHTLY_ROCM_INDEX="${PYTORCH_NIGHTLY_ROCM_INDEX:-https://download.pytorch.org/whl/nightly/rocm6.4}"
PYTORCH_NIGHTLY_CPU_INDEX="${PYTORCH_NIGHTLY_CPU_INDEX:-https://download.pytorch.org/whl/nightly/cpu}"
PYTORCH_ENABLE_PRE="${PYTORCH_ENABLE_PRE:-auto}"
PYTORCH_PURGE_CACHE="${PYTORCH_PURGE_CACHE:-true}"
PYTORCH_CORE_PACKAGE="${PYTORCH_CORE_PACKAGE:-torch}"
PYTORCH_OPTIONAL_PACKAGES=(torchvision torchaudio)

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

python_needs_pre_wheels() {
  "$VENV_DIR/bin/python" - <<'PY'
import sys
raise SystemExit(0 if sys.version_info >= (3, 14) else 1)
PY
}

purge_pytorch_pip_cache() {
  local package_name
  local removed_any="false"

  for package_name in "$PYTORCH_CORE_PACKAGE" "${PYTORCH_OPTIONAL_PACKAGES[@]}"; do
    if "$VENV_DIR/bin/python" -m pip cache remove "$package_name" >/dev/null 2>&1; then
      removed_any="true"
    else
      return 1
    fi
  done

  [[ "$removed_any" == "true" ]]
}

pip_install_pytorch_stack() {
  local index_url="$1" install_label="$2"
  local optional_package detail="" pre_flag="" cache_detail=""
  local selected_index="$index_url"
  local packages=("$PYTORCH_CORE_PACKAGE" "${PYTORCH_OPTIONAL_PACKAGES[@]}")

  if [[ "$PYTORCH_ENABLE_PRE" == "true" ]] || { [[ "$PYTORCH_ENABLE_PRE" == "auto" ]] && python_needs_pre_wheels; }; then
    pre_flag="--pre"
    if [[ "$install_label" == "ROCm" ]]; then
      selected_index="$PYTORCH_NIGHTLY_ROCM_INDEX"
    else
      selected_index="$PYTORCH_NIGHTLY_CPU_INDEX"
    fi
    detail+="Using pre-release PyTorch wheels from $selected_index because PYTORCH_ENABLE_PRE=$PYTORCH_ENABLE_PRE. "
  fi

  if [[ "$PYTORCH_PURGE_CACHE" == "true" ]]; then
    if purge_pytorch_pip_cache; then
      cache_detail="Removed cached PyTorch package wheels before install to avoid stale companion wheels. "
    else
      cache_detail="PyTorch pip cache removal failed or is unsupported; continuing with no-cache install. "
    fi
    detail+="$cache_detail"
  fi

  if "$VENV_DIR/bin/python" -m pip install --upgrade --no-cache-dir $pre_flag "${packages[@]}" --index-url "$selected_index"; then
    printf '%s' "$detail"
    return 0
  fi

  detail+="Combined PyTorch $install_label stack install failed from $selected_index; retrying core package and optional companions separately. "
  if ! "$VENV_DIR/bin/python" -m pip install --upgrade --no-cache-dir $pre_flag "$PYTORCH_CORE_PACKAGE" --index-url "$selected_index"; then
    detail+="PyTorch $install_label pip install failed while installing $PYTORCH_CORE_PACKAGE; see console output."
    printf '%s' "$detail"
    return 1
  fi

  for optional_package in "${PYTORCH_OPTIONAL_PACKAGES[@]}"; do
    if ! "$VENV_DIR/bin/python" -m pip install --upgrade --no-cache-dir $pre_flag "$optional_package" --index-url "$selected_index"; then
      detail+="Optional PyTorch companion package $optional_package could not be installed from $selected_index; continuing because torch installed successfully. "
    fi
  done

  printf '%s' "$detail"
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
    printf '%s\n%s\n%s\n' '```text' "$detail" '```'
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
      detail="$(pip_install_pytorch_stack "$PYTORCH_ROCM_INDEX" ROCm || true)"
    else
      install_action="pip-install-cpu-fallback"
      detail="$(pip_install_pytorch_stack "$PYTORCH_CPU_INDEX" CPU || true)"
    fi
  elif [[ -x "$VENV_DIR/bin/python" && "$OFFLINE" == "true" && -d "$WHEELHOUSE" ]]; then
    install_action="offline-wheelhouse-available"
  fi

  local torch_state="missing" hip_state="false" status="WARN"
  if [[ "$install_action" == "venv-create-failed" ]]; then
    status="FAIL"
  elif [[ -x "$VENV_DIR/bin/python" ]]; then
    if "$VENV_DIR/bin/python" -c 'import importlib.util, sys; sys.exit(0 if importlib.util.find_spec("torch") else 1)' >/dev/null 2>&1; then
      torch_state="available"
      hip_state="$("$VENV_DIR/bin/python" -c 'import torch; print("true" if getattr(torch.version, "hip", None) else "false")' 2>/dev/null || echo false)"
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
  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
