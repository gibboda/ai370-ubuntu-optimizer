#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"
ACCEPT_AMD_ACCELERATION_RISK="${5:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
CONFIG_FILE="$PROJECT_ROOT/configs/amd-acceleration.env"
STATUS_TXT="$LATEST_DIR/amd-acceleration-install-status.txt"
STATUS_JSON="$LATEST_DIR/amd-acceleration-install.json"
ENV_FILE="$LATEST_DIR/amd-acceleration-env.sh"
SUMMARY_MD="$LATEST_DIR/amd-acceleration-install.md"

resolve_project_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s\n' "$PROJECT_ROOT/$path"
  fi
}

load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Missing AMD acceleration config: $CONFIG_FILE"
    exit 2
  fi

  # Preserve caller-provided environment overrides. The checked-in config supplies
  # defaults, but README-documented overrides such as AMD_ARTIFACT_ROOT=/path/to/artifacts
  # must win when users keep AMD packages outside the repository checkout.
  local env_amd_artifact_root="${AMD_ARTIFACT_ROOT:-}"
  local env_ryzen_ai_install_root="${RYZEN_AI_INSTALL_ROOT:-}"
  local env_rocm_version="${ROCM_VERSION:-}"
  local env_rocm_repo_codename="${ROCM_REPO_CODENAME:-}"
  local env_rocm_packages="${ROCM_PACKAGES:-}"
  local env_rocm_install_mode="${ROCM_INSTALL_MODE:-}"
  local env_ryzen_ai_artifact_glob="${RYZEN_AI_ARTIFACT_GLOB:-}"
  local env_xrt_deb_globs="${XRT_DEB_GLOBS:-}"

  # shellcheck source=/dev/null
  source "$CONFIG_FILE"

  [[ -n "$env_amd_artifact_root" ]] && AMD_ARTIFACT_ROOT="$env_amd_artifact_root"
  [[ -n "$env_ryzen_ai_install_root" ]] && RYZEN_AI_INSTALL_ROOT="$env_ryzen_ai_install_root"
  [[ -n "$env_rocm_version" ]] && ROCM_VERSION="$env_rocm_version"
  [[ -n "$env_rocm_repo_codename" ]] && ROCM_REPO_CODENAME="$env_rocm_repo_codename"
  [[ -n "$env_rocm_packages" ]] && ROCM_PACKAGES="$env_rocm_packages"
  [[ -n "$env_rocm_install_mode" ]] && ROCM_INSTALL_MODE="$env_rocm_install_mode"
  [[ -n "$env_ryzen_ai_artifact_glob" ]] && RYZEN_AI_ARTIFACT_GLOB="$env_ryzen_ai_artifact_glob"
  [[ -n "$env_xrt_deb_globs" ]] && XRT_DEB_GLOBS="$env_xrt_deb_globs"

  AMD_ARTIFACT_ROOT="$(resolve_project_path "${AMD_ARTIFACT_ROOT:-.ai370-ai/amd-artifacts}")"
  RYZEN_AI_INSTALL_ROOT="$(resolve_project_path "${RYZEN_AI_INSTALL_ROOT:-.ai370-ai/ryzen-ai}")"
  : "${ROCM_VERSION:=7.2.4}"
  : "${ROCM_REPO_CODENAME:=resolute}"
  : "${ROCM_PACKAGES:=rocm rocm-hip-runtime rocm-hip-sdk rocm-ml-sdk rocm-opencl-sdk amdgpu-lib}"
  : "${ROCM_INSTALL_MODE:=online}"
  : "${RYZEN_AI_ARTIFACT_GLOB:=ryzen_ai-*.tgz}"
  : "${XRT_DEB_GLOBS:=xrt_*_26.04-amd64-base.deb xrt_*_26.04-amd64-base-dev.deb xrt_*_26.04-amd64-npu.deb xrt_*_26.04-amd64-xrt.deb xrt_plugin.*_26.04-amd64-amdxdna.deb xrt_plugin.*_ubuntu26.04-x86_64-amdxdna.deb}"
}

require_acknowledgement() {
  if [[ "$ACCEPT_AMD_ACCELERATION_RISK" != "true" ]]; then
    cat <<EOF_ACK
[ERROR] Full AMD acceleration install is intentionally opt-in.
[ERROR] Re-run with --accept-amd-acceleration-risk after confirming AMD ROCm/Ryzen AI compatibility for this Ubuntu/kernel/hardware combination.
[ERROR] This phase can add AMD package repositories, install ROCm packages, install staged XRT/Ryzen AI artifacts, and change local launcher behavior.
EOF_ACK
    exit 2
  fi
}

require_root_privilege() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "[INFO] sudo access is required for AMD package/runtime installation."
    sudo -v
  fi
}

ubuntu_codename() {
  . /etc/os-release 2>/dev/null || true
  printf '%s\n' "${VERSION_CODENAME:-unknown}"
}

install_rocm_online() {
  local detected_codename="$1"
  echo "[INFO] Installing ROCm package-manager stack from AMD repositories."
  echo "[INFO] Detected Ubuntu codename: $detected_codename"
  echo "[INFO] ROCm repository codename: $ROCM_REPO_CODENAME"
  if [[ "$detected_codename" != "$ROCM_REPO_CODENAME" ]]; then
    echo "[WARN] Detected codename differs from configured ROCm repo codename; continuing because the user accepted the AMD acceleration risk."
  fi

  local missing_tools=()
  command -v wget >/dev/null 2>&1 || missing_tools+=(wget)
  command -v gpg  >/dev/null 2>&1 || missing_tools+=(gnupg)
  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    echo "[INFO] Installing missing prerequisites: ${missing_tools[*]}"
    sudo apt-get install -y "${missing_tools[@]}"
  fi

  sudo install -d -m 0755 /etc/apt/keyrings
  wget -qO- https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg >/dev/null

  sudo tee /etc/apt/sources.list.d/rocm.list >/dev/null <<EOF_ROCM_LIST
# Added by ai370-ubuntu-optimizer full AMD acceleration phase.
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/$ROCM_VERSION $ROCM_REPO_CODENAME main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/graphics/$ROCM_VERSION/ubuntu $ROCM_REPO_CODENAME main
EOF_ROCM_LIST

  sudo tee /etc/apt/preferences.d/rocm-pin-600 >/dev/null <<'EOF_PIN'
Package: *
Pin: release o=repo.radeon.com
Pin-Priority: 600
EOF_PIN

  sudo apt-get update
  # shellcheck disable=SC2086
  sudo apt-get install -y $ROCM_PACKAGES
}

install_rocm_offline() {
  local rocm_debs_dir="$AMD_ARTIFACT_ROOT/rocm-debs"
  if [[ ! -d "$rocm_debs_dir" ]]; then
    echo "[ERROR] Offline ROCm deb directory is missing: $rocm_debs_dir"
    exit 4
  fi
  if ! find "$rocm_debs_dir" -maxdepth 1 -type f -name '*.deb' | grep -q .; then
    echo "[ERROR] Offline ROCm deb directory contains no .deb files: $rocm_debs_dir"
    exit 4
  fi
  echo "[INFO] Installing staged ROCm debs from: $rocm_debs_dir"
  sudo apt-get install --fix-broken -y --no-download "$rocm_debs_dir"/*.deb
}

install_rocm_stack() {
  if [[ "$OFFLINE" == "true" || "$ROCM_INSTALL_MODE" == "offline" ]]; then
    install_rocm_offline
  else
    install_rocm_online "$(ubuntu_codename)"
  fi
}

find_first_match() {
  local root="$1"
  local pattern="$2"
  [[ -d "$root" ]] || return 0
  find "$root" -maxdepth 5 -type f -name "$pattern" 2>/dev/null | sort | head -n 1
}

print_artifact_inventory() {
  echo "[INFO] AMD artifact root: $AMD_ARTIFACT_ROOT"
  if [[ ! -d "$AMD_ARTIFACT_ROOT" ]]; then
    echo "[INFO] Artifact root does not exist yet. Create it or set AMD_ARTIFACT_ROOT=/absolute/path/to/amd-artifacts."
    return
  fi

  local candidates
  candidates="$(find "$AMD_ARTIFACT_ROOT" -maxdepth 5 -type f \( -name '*.deb' -o -name '*.tgz' -o -name '*.tar.gz' -o -name '*.zip' \) 2>/dev/null | sort | head -n 40 || true)"
  if [[ -n "$candidates" ]]; then
    echo "[INFO] Staged AMD artifact candidates found:"
    printf '%s\n' "$candidates" | sed 's/^/[INFO]   /'
  else
    echo "[INFO] No .deb, .tgz, .tar.gz, or .zip artifacts were found within five directory levels."
  fi
}

print_xrt_staging_help() {
  cat <<EOF_XRT_HELP
[ERROR] Stage the Ryzen AI Linux NPU driver .deb files before rerunning this phase.
[ERROR] Expected Ubuntu 26.04 package names resemble:
[ERROR]   xrt_<version>_26.04-amd64-base.deb
[ERROR]   xrt_<version>_26.04-amd64-base-dev.deb
[ERROR]   xrt_<version>_26.04-amd64-npu.deb
[ERROR]   xrt_plugin.<version>_26.04-amd64-amdxdna.deb
[ERROR] Source-built XDNA driver package names such as xrt_<version>_26.04-amd64-xrt.deb
[ERROR] and xrt_plugin.<version>_ubuntu26.04-x86_64-amdxdna.deb are also accepted.
[ERROR] If your files are elsewhere, rerun with AMD_ARTIFACT_ROOT=/absolute/path/to/amd-artifacts.
[ERROR] If AMD supplied a compressed driver bundle, extract it under AMD_ARTIFACT_ROOT first.
EOF_XRT_HELP
}

install_xrt_debs() {
  local glob deb found missing
  found="false"
  missing="false"
  for glob in $XRT_DEB_GLOBS; do
    deb="$(find_first_match "$AMD_ARTIFACT_ROOT" "$glob")"
    if [[ -n "$deb" ]]; then
      found="true"
      echo "[INFO] Installing staged XRT/NPU package: $deb"
      if [[ "$OFFLINE" == "true" ]]; then
        sudo apt-get install --fix-broken -y --no-download "$deb"
      else
        sudo apt-get install --fix-broken -y "$deb"
      fi
    else
      missing="true"
      echo "[WARN] Missing staged XRT/NPU package matching: $glob"
    fi
  done

  if [[ "$found" != "true" ]]; then
    echo "[ERROR] No XRT/NPU deb packages were found under: $AMD_ARTIFACT_ROOT"
    print_artifact_inventory
    print_xrt_staging_help
    exit 4
  fi
  if [[ "$missing" == "true" ]]; then
    echo "[WARN] Some expected XRT/NPU package patterns were missing; validation will determine whether the NPU stack is complete."
  fi
}

install_ryzen_ai_package() {
  local archive workdir installer installer_dir venv_path wheel_count rc py312_bin_dir
  archive="$(find_first_match "$AMD_ARTIFACT_ROOT" "$RYZEN_AI_ARTIFACT_GLOB")"
  if [[ -z "$archive" ]]; then
    echo "[WARN] No Ryzen AI software archive matched '$RYZEN_AI_ARTIFACT_GLOB' under $AMD_ARTIFACT_ROOT."
    echo "[WARN] NPU driver packages may still be installed, but Ryzen AI examples/providers will remain incomplete until staged."
    return 1
  fi

  if ! command -v python3.12 >/dev/null 2>&1; then
    echo "[ERROR] Ryzen AI 1.7.x requires python3.12 on PATH."
    echo "[ERROR] Install Python 3.12 and re-run."
    return 1
  fi

  # Prefer real interpreter over uv/pyenv shims (AMD uses `venv --copies`).
  py312_bin_dir="$(python3.12 -c 'import pathlib, sys; print(pathlib.Path(sys.executable).resolve().parent)' 2>/dev/null || dirname "$(command -v python3.12)")"

  mkdir -p "$RYZEN_AI_INSTALL_ROOT"
  workdir="$RYZEN_AI_INSTALL_ROOT/source"
  venv_path="$RYZEN_AI_INSTALL_ROOT/venv"

  if [[ -d "$venv_path" ]]; then
    echo "[INFO] Removing previous Ryzen AI venv at $venv_path before reinstall."
    rm -rf "$venv_path"
  fi

  rm -rf "$workdir"
  mkdir -p "$workdir"
  echo "[INFO] Extracting Ryzen AI package: $archive"
  if ! tar -xzf "$archive" -C "$workdir" 2>/dev/null; then
    rm -rf "$workdir"
    mkdir -p "$workdir"
    tar -xzf "$archive" -C "$workdir" --strip-components=1
  fi
  installer="$(find "$workdir" -maxdepth 3 -type f -name 'install_ryzen_ai.sh' | sort | head -n 1)"
  if [[ -z "$installer" ]]; then
    echo "[WARN] Ryzen AI installer was not found after extraction; leaving extracted files at $workdir."
    return 1
  fi
  chmod +x "$installer"
  installer_dir="$(cd "$(dirname "$installer")" && pwd)"

  wheel_count="$(find "$installer_dir" -maxdepth 1 -type f -name '*.whl' 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${wheel_count:-0}" -eq 0 ]]; then
    echo "[ERROR] No .whl files next to install_ryzen_ai.sh in $installer_dir."
    return 1
  fi
  echo "[INFO] Found $wheel_count wheel(s) beside installer in $installer_dir"
  echo "[INFO] Installing Ryzen AI software into: $venv_path"

  rc=0
  (
    export PATH="$py312_bin_dir:$PATH"
    cd "$installer_dir"
    ./install_ryzen_ai.sh -a yes -p "$venv_path"
  ) || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "[ERROR] Ryzen AI installer exited with status $rc."
    if [[ -d "$venv_path" ]] && [[ ! -x "$venv_path/bin/pip" ]]; then
      rm -rf "$venv_path"
    fi
    return 1
  fi
  if [[ ! -x "$venv_path/bin/python" ]] || [[ ! -x "$venv_path/bin/pip" ]]; then
    echo "[ERROR] Ryzen AI installer finished but venv is missing or incomplete at $venv_path."
    [[ -d "$venv_path" ]] && rm -rf "$venv_path"
    return 1
  fi
  return 0
}

install_npu_stack() {
  install_xrt_debs
  install_ryzen_ai_package
}

write_environment_file() {
  cat > "$ENV_FILE" <<EOF_ENV
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Generated by ai370-ubuntu-optimizer AMD acceleration install phase.

if [[ -d /opt/rocm/bin ]]; then
  export PATH="/opt/rocm/bin:\$PATH"
fi
if [[ -d /opt/rocm/lib ]]; then
  export LD_LIBRARY_PATH="/opt/rocm/lib:\${LD_LIBRARY_PATH:-}"
fi
if [[ -f /opt/xilinx/xrt/setup.sh ]]; then
  # shellcheck source=/dev/null
  source /opt/xilinx/xrt/setup.sh
fi
if [[ -d "$RYZEN_AI_INSTALL_ROOT/venv" ]]; then
  export RYZEN_AI_INSTALLATION_PATH="$RYZEN_AI_INSTALL_ROOT/venv"
fi
EOF_ENV
  chmod +x "$ENV_FILE"
}

capture_command() {
  local command_name="$1"
  shift || true
  if command -v "$command_name" >/dev/null 2>&1; then
    "$command_name" "$@" 2>&1 || true
  else
    echo "command-not-found: $command_name"
  fi
}

write_status() {
  local amdgpu_state vulkan_state opencl_state rocm_state xrt_state xrt_examine ryzen_ai_state vulkan_output clinfo_output rocminfo_output
  amdgpu_state="missing"
  lsmod 2>/dev/null | grep -q '^amdgpu' && amdgpu_state="loaded"
  vulkan_state="not-visible"
  vulkan_output="$(capture_command vulkaninfo --summary)"
  if [[ "$vulkan_output" != command-not-found:* ]] && ! printf '%s\n' "$vulkan_output" | grep -qi 'error'; then
    vulkan_state="visible"
  fi
  opencl_state="not-visible"
  clinfo_output="$(capture_command clinfo)"
  if [[ "$clinfo_output" != command-not-found:* ]] && printf '%s\n' "$clinfo_output" | grep -Eiq 'Platform|Device'; then
    opencl_state="visible"
  fi
  rocm_state="not-visible"
  rocminfo_output="$(capture_command rocminfo)"
  if [[ "$rocminfo_output" != command-not-found:* ]] && printf '%s\n' "$rocminfo_output" | grep -Eiq 'Agent|Name|gfx'; then
    rocm_state="visible"
  fi
  xrt_state="missing"
  xrt_examine="$(capture_command xrt-smi examine)"
  [[ "$xrt_examine" != command-not-found:* ]] && xrt_state="available"
  ryzen_ai_state="missing"
  [[ -d "$RYZEN_AI_INSTALL_ROOT/venv" ]] && ryzen_ai_state="available"

  {
    echo "AMD Acceleration Install Status"
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Offline: $OFFLINE"
    echo "ROCm version: $ROCM_VERSION"
    echo "ROCm repo codename: $ROCM_REPO_CODENAME"
    echo "Timestamp: $(date -Is)"
    echo
    echo "amdgpu: $amdgpu_state"
    echo "vulkan: $vulkan_state"
    echo "opencl: $opencl_state"
    echo "rocm: $rocm_state"
    echo "xrt: $xrt_state"
    echo "ryzen_ai: $ryzen_ai_state"
    echo "environment: $ENV_FILE"
  } > "$STATUS_TXT"

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" \
  ROCM_VERSION="$ROCM_VERSION" ROCM_REPO_CODENAME="$ROCM_REPO_CODENAME" \
  AMDGPU_STATE="$amdgpu_state" VULKAN_STATE="$vulkan_state" OPENCL_STATE="$opencl_state" \
  ROCM_STATE="$rocm_state" XRT_STATE="$xrt_state" RYZEN_AI_STATE="$ryzen_ai_state" ENV_FILE="$ENV_FILE" \
  python3 - "$STATUS_JSON" <<'PY'
import json
import os
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(json.dumps({
    "profile": os.environ["PROFILE"],
    "mode": os.environ["MODE"],
    "persistence": os.environ["PERSISTENCE"],
    "offline": os.environ["OFFLINE"] == "true",
    "rocm_version": os.environ["ROCM_VERSION"],
    "rocm_repo_codename": os.environ["ROCM_REPO_CODENAME"],
    "status": {
        "amdgpu": os.environ["AMDGPU_STATE"],
        "vulkan": os.environ["VULKAN_STATE"],
        "opencl": os.environ["OPENCL_STATE"],
        "rocm": os.environ["ROCM_STATE"],
        "xrt": os.environ["XRT_STATE"],
        "ryzen_ai": os.environ["RYZEN_AI_STATE"],
    },
    "environment_file": os.environ["ENV_FILE"],
    "policy": "explicitly acknowledged full AMD acceleration install; validate before ComfyUI GPU mode",
}, indent=2) + "\n")
PY

  cat > "$SUMMARY_MD" <<EOF_MD
# AMD Acceleration Install Summary

Profile: $PROFILE  
Mode: $MODE  
Persistence: $PERSISTENCE  
Offline: $OFFLINE  
ROCm version: $ROCM_VERSION  
ROCm repo codename: $ROCM_REPO_CODENAME

## Detected state after install

- amdgpu: $amdgpu_state
- Vulkan: $vulkan_state
- OpenCL: $opencl_state
- ROCm/HIP: $rocm_state
- XRT tools: $xrt_state
- Ryzen AI software: $ryzen_ai_state

## Environment

Source this file in shells that should see ROCm/XRT/Ryzen AI paths:

\`\`\`bash
source reports/latest/amd-acceleration-env.sh
\`\`\`

Run \`./ai370-optimize.sh accel-validate\` after this phase and before ComfyUI installation.
EOF_MD

  echo "[INFO] Wrote $STATUS_TXT"
  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $ENV_FILE"
  echo "[INFO] Wrote $SUMMARY_MD"
}

main() {
  echo "[INFO] Phase 7.5: Full AMD GPU/NPU acceleration install"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"
  echo "[INFO] Offline: $OFFLINE"

  mkdir -p "$LATEST_DIR"
  load_config
  require_acknowledgement
  require_root_privilege
  install_rocm_stack
  install_npu_stack
  write_environment_file
  write_status
  echo "[INFO] AMD acceleration installation complete. Reboot if driver/runtime changes require it, then rerun validation."
}

main "$@"
