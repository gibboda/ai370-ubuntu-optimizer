#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M2: Ryzen AI NPU Runtime Stack Installer (205-install-xrt-ryzen-ai.sh).
# Automates the installation of AMD XRT driver packages and the Ryzen AI software stack
# from staged local artifacts, ensuring offline readiness.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
CONFIG_FILE="$PROJECT_ROOT/configs/amd-acceleration.env"
STATUS_JSON="$LATEST_DIR/xrt-install-status.json"
SUMMARY_MD="$LATEST_DIR/xrt-install-status.md"

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

  # Source defaults and load paths
  # shellcheck source=configs/amd-acceleration.env
  source "$CONFIG_FILE"

  AMD_ARTIFACT_ROOT="$(resolve_project_path "${AMD_ARTIFACT_ROOT:-.ai370-ai/amd-artifacts}")"
  RYZEN_AI_INSTALL_ROOT="$(resolve_project_path "${RYZEN_AI_INSTALL_ROOT:-.ai370-ai/ryzen-ai}")"
  : "${RYZEN_AI_ARTIFACT_GLOB:=ryzen_ai-*.tgz}"
  : "${XRT_DEB_GLOBS:=xrt_*_26.04-amd64-base.deb xrt_*_26.04-amd64-base-dev.deb xrt_*_26.04-amd64-npu.deb xrt_*_26.04-amd64-xrt.deb xrt_plugin.*_26.04-amd64-amdxdna.deb xrt_plugin.*_ubuntu26.04-x86_64-amdxdna.deb}"
}

require_runtime_persistence() {
  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent NPU configuration is not supported. Use --persistence=runtime."
    exit 2
  fi
}

require_root_privilege() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "[INFO] sudo privilege is required to install driver packages."
    sudo -v
  fi
}

find_first_match() {
  local root="$1"
  local pattern="$2"
  [[ -d "$root" ]] || return 0
  find "$root" -maxdepth 5 -type f -name "$pattern" 2>/dev/null | sort | head -n 1
}

print_staging_instructions() {
  echo "[INFO] === Ryzen AI Staging Instructions ==="
  echo "[INFO] AMD XRT and Ryzen AI packages are proprietary and must be staged manually."
  echo "[INFO] 1. Download driver .deb files and the Ryzen AI software tarball (.tgz) from AMD."
  echo "[INFO] 2. Place them under the artifact root: $AMD_ARTIFACT_ROOT/"
  echo "[INFO] Expected file patterns:"
  echo "[INFO]   - Driver packages: xrt_*_26.04-amd64-base.deb, xrt_plugin.*-amdxdna.deb, etc."
  echo "[INFO]   - Software archive: ryzen_ai-*.tgz"
  echo "[INFO] ====================================="
}

main() {
  mkdir -p "$LATEST_DIR"
  load_config
  require_runtime_persistence

  echo "[INFO] Starting Ryzen AI NPU Runtime Installer..."
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE  Offline: $OFFLINE"

  local xrt_staged="false"
  local ryzen_staged="false"
  local xrt_installed="false"
  local ryzen_installed="false"
  local status="WARN"
  local detail=""

  # 1. Check for staged XRT .debs
  local glob deb found_debs=()
  for glob in $XRT_DEB_GLOBS; do
    deb="$(find_first_match "$AMD_ARTIFACT_ROOT" "$glob")"
    if [[ -n "$deb" ]]; then
      found_debs+=("$deb")
    fi
  done

  if [[ ${#found_debs[@]} -gt 0 ]]; then
    xrt_staged="true"
  fi

  # 2. Check for staged Ryzen AI software archive
  local archive
  archive="$(find_first_match "$AMD_ARTIFACT_ROOT" "$RYZEN_AI_ARTIFACT_GLOB")"
  if [[ -n "$archive" ]]; then
    ryzen_staged="true"
  fi

  # 3. Perform installation if staged
  if [[ "$xrt_staged" == "true" ]]; then
    require_root_privilege
    echo "[INFO] Installing staged XRT driver packages..."
    local install_err=0
    for deb in "${found_debs[@]}"; do
      echo "[INFO] Installing package: $deb"
      if [[ "$OFFLINE" == "true" ]]; then
        sudo apt-get install --fix-broken -y --no-download "$deb" || install_err=1
      else
        sudo apt-get install --fix-broken -y "$deb" || install_err=1
      fi
    done

    if [[ $install_err -eq 0 ]]; then
      xrt_installed="true"
    else
      detail="XRT package installation failed; see console logs."
    fi
  else
    detail="XRT packages not staged under $AMD_ARTIFACT_ROOT. Skipping installation."
  fi

  if [[ "$ryzen_staged" == "true" ]]; then
    echo "[INFO] Installing Ryzen AI Software package..."
    local workdir="$RYZEN_AI_INSTALL_ROOT/source"
    mkdir -p "$RYZEN_AI_INSTALL_ROOT"
    rm -rf "$workdir"
    mkdir -p "$workdir"

    echo "[INFO] Extracting $archive..."
    if tar -xzf "$archive" -C "$workdir" --strip-components=1 2>/dev/null || tar -xzf "$archive" -C "$workdir"; then
      local installer
      installer="$(find "$workdir" -maxdepth 3 -type f -name 'install_ryzen_ai.sh' | sort | head -n 1)"
      if [[ -n "$installer" ]]; then
        chmod +x "$installer"
        echo "[INFO] Running Ryzen AI installer..."
        if "$installer" -a yes -p "$RYZEN_AI_INSTALL_ROOT/venv"; then
          ryzen_installed="true"
        else
          detail="${detail:+$detail; }Ryzen AI installer script failed."
        fi
      else
        detail="${detail:+$detail; }install_ryzen_ai.sh not found in archive."
      fi
    else
      detail="${detail:+$detail; }Failed to extract Ryzen AI archive."
    fi
  else
    detail="${detail:+$detail; }Ryzen AI software archive not staged. Skipping installation."
  fi

  # Define final status
  if [[ "$xrt_installed" == "true" && "$ryzen_installed" == "true" ]]; then
    status="PASS"
    detail="Ryzen AI NPU driver packages and software stack installed successfully."
  elif [[ "$xrt_staged" == "false" && "$ryzen_staged" == "false" ]]; then
    status="WARN"
    detail="Staged installation files are missing. Skipped NPU runtime installation."
    print_staging_instructions
  else
    status="WARN"
    detail="Staged packages partially installed. Details: $detail"
  fi

  # Write JSON Status
  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 2,
  "milestone": "S2-M2",
  "phase": "install-xrt-ryzen-ai",
  "status": "$status",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $([[ "$OFFLINE" == "true" ]] && echo true || echo false),
  "xrt_staged": $xrt_staged,
  "ryzen_staged": $ryzen_staged,
  "xrt_installed": $xrt_installed,
  "ryzen_installed": $ryzen_installed,
  "detail": "$detail"
}
EOF_JSON

  # Write Markdown summary
  {
    echo "# XRT & Ryzen AI Software Install Status"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Persistence: $PERSISTENCE"
    echo "Status: $status"
    echo
    echo "## Staging & Installation Metrics"
    echo "- XRT driver packages staged: $xrt_staged"
    echo "- XRT driver packages installed: $xrt_installed"
    echo "- Ryzen AI software archive staged: $ryzen_staged"
    echo "- Ryzen AI software installed: $ryzen_installed"
    echo
    echo "## Detail"
    echo "$detail"
  } > "$SUMMARY_MD"

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
}

main "$@"
