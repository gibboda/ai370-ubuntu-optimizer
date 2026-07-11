#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M2: explicit XRT / Ryzen AI package install or offline staging validation.
# Safe by default: without --accept-amd-acceleration-risk (5th arg true) this script
# only inventories artifacts and records diagnostics (does not apt-install).
# With risk accepted, installs staged XRT .deb packages and optional Ryzen AI tarball
# from AMD_ARTIFACT_ROOT (see configs/amd-acceleration.env).

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"
ACCEPT_AMD_ACCELERATION_RISK="${5:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
CONFIG_FILE="$PROJECT_ROOT/configs/amd-acceleration.env"
STATUS_JSON="$LATEST_DIR/xrt-ryzen-ai-install.json"
SUMMARY_MD="$LATEST_DIR/xrt-ryzen-ai-install.md"
ENV_SNIPPET="$LATEST_DIR/xrt-ryzen-ai-env.sh"

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

  local env_amd_artifact_root="${AMD_ARTIFACT_ROOT:-}"
  local env_ryzen_ai_install_root="${RYZEN_AI_INSTALL_ROOT:-}"
  local env_ryzen_ai_artifact_glob="${RYZEN_AI_ARTIFACT_GLOB:-}"
  local env_xrt_deb_globs="${XRT_DEB_GLOBS:-}"
  local env_xrt_ubuntu_versions="${XRT_UBUNTU_VERSIONS:-}"
  local env_xrt_deb_globs_mode="${XRT_DEB_GLOBS_MODE:-}"

  # shellcheck source=/dev/null
  source "$CONFIG_FILE"

  [[ -n "$env_amd_artifact_root" ]] && AMD_ARTIFACT_ROOT="$env_amd_artifact_root"
  [[ -n "$env_ryzen_ai_install_root" ]] && RYZEN_AI_INSTALL_ROOT="$env_ryzen_ai_install_root"
  [[ -n "$env_ryzen_ai_artifact_glob" ]] && RYZEN_AI_ARTIFACT_GLOB="$env_ryzen_ai_artifact_glob"
  [[ -n "$env_xrt_deb_globs" ]] && XRT_DEB_GLOBS="$env_xrt_deb_globs"
  [[ -n "$env_xrt_ubuntu_versions" ]] && XRT_UBUNTU_VERSIONS="$env_xrt_ubuntu_versions"
  [[ -n "$env_xrt_deb_globs_mode" ]] && XRT_DEB_GLOBS_MODE="$env_xrt_deb_globs_mode"

  AMD_ARTIFACT_ROOT="$(resolve_project_path "${AMD_ARTIFACT_ROOT:-.ai370-ai/amd-artifacts}")"
  RYZEN_AI_INSTALL_ROOT="$(resolve_project_path "${RYZEN_AI_INSTALL_ROOT:-.ai370-ai/ryzen-ai}")"
  : "${RYZEN_AI_ARTIFACT_GLOB:=ryzen_ai-*.tgz}"
  # Empty XRT_UBUNTU_VERSIONS means auto (host + previous LTS + staged-deb discovery).
  : "${XRT_UBUNTU_VERSIONS:=}"
  : "${XRT_DEB_GLOBS_MODE:=auto}"
  # Keep any config/env globs as the post-version override; resolve_xrt_deb_globs
  # picks the active set (version match, then override, else empty).
  XRT_DEB_GLOBS_OVERRIDE="${XRT_DEB_GLOBS:-}"
  XRT_DEB_GLOBS=""
  XRT_DEB_MATCH_SOURCE="none"
  XRT_DEB_MATCH_UBUNTU_VERSION=""
  XRT_UBUNTU_VERSIONS_SOURCE="auto"
  XRT_HOST_UBUNTU_VERSION="$(detect_host_ubuntu_version || true)"
  resolve_xrt_deb_globs || true
}

detect_host_ubuntu_version() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    printf '%s\n' "${VERSION_ID:-}"
  fi
}

# Ubuntu LTS is YY.04 every two years (26.04 -> 24.04 -> 22.04). No fixed list.
previous_ubuntu_lts() {
  local ver="${1:-}"
  local major
  if [[ "$ver" =~ ^([0-9]+)\.04$ ]] && [[ "${BASH_REMATCH[1]}" -ge 4 ]]; then
    major="${BASH_REMATCH[1]}"
    printf '%s.04\n' "$((major - 2))"
  fi
}

# Parse Ubuntu VERSION_ID-style tags from staged XRT/NPU deb basenames.
discover_ubuntu_versions_from_artifacts() {
  local root="${1:-$AMD_ARTIFACT_ROOT}"
  local base
  [[ -d "$root" ]] || return 0
  while IFS= read -r -d '' base; do
    base="$(basename "$base")"
    if [[ "$base" =~ _([0-9]+\.[0-9]+)-amd64 ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
    elif [[ "$base" =~ _ubuntu([0-9]+\.[0-9]+)- ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
    fi
  done < <(find "$root" -maxdepth 5 -type f \( -name 'xrt_*.deb' -o -name 'xrt_plugin*.deb' \) -print0 2>/dev/null) \
    | sort -u
}

# Build try-order: explicit pin, else host -> previous LTS -> discovered newest-first.
build_xrt_ubuntu_version_preference() {
  local host="${XRT_HOST_UBUNTU_VERSION:-}"
  local v prev
  local -a ordered=() seen=()

  append_unique() {
    local candidate="$1" existing
    [[ -n "$candidate" ]] || return 0
    for existing in "${seen[@]+"${seen[@]}"}"; do
      [[ "$existing" == "$candidate" ]] && return 0
    done
    seen+=("$candidate")
    ordered+=("$candidate")
  }

  # Note: this function may run in a command-substitution subshell; the caller
  # owns XRT_UBUNTU_VERSIONS_SOURCE. Branch only on whether a pin is set.
  if [[ -n "${XRT_UBUNTU_VERSIONS// /}" ]]; then
    # shellcheck disable=SC2206
    for v in ${XRT_UBUNTU_VERSIONS}; do
      append_unique "$v"
    done
  else
    append_unique "$host"
    prev="$(previous_ubuntu_lts "$host" || true)"
    append_unique "$prev"
    while IFS= read -r v; do
      append_unique "$v"
    done < <(discover_ubuntu_versions_from_artifacts "$AMD_ARTIFACT_ROOT" | sort -V -r)
  fi

  if [[ ${#ordered[@]} -eq 0 ]]; then
    return 1
  fi
  printf '%s\n' "${ordered[*]}"
  return 0
}

# Canonical AMD XRT/NPU filename patterns for a given Ubuntu VERSION_ID tag.
xrt_globs_for_ubuntu_version() {
  local v="$1"
  printf '%s' \
    "xrt_*_${v}-amd64-base.deb " \
    "xrt_*_${v}-amd64-base-dev.deb " \
    "xrt_*_${v}-amd64-npu.deb " \
    "xrt_*_${v}-amd64-xrt.deb " \
    "xrt_plugin.*_${v}-amd64-amdxdna.deb " \
    "xrt_plugin.*_ubuntu${v}-x86_64-amdxdna.deb"
}

find_first_match() {
  local root="$1"
  local pattern="$2"
  [[ -d "$root" ]] || return 0
  find "$root" -maxdepth 5 -type f -name "$pattern" 2>/dev/null | sort | head -n 1
}

list_matching_debs_for_globs() {
  local globs="$1"
  local glob deb
  local -a found=()
  [[ -n "$globs" ]] || return 0
  for glob in $globs; do
    deb="$(find_first_match "$AMD_ARTIFACT_ROOT" "$glob")"
    if [[ -n "$deb" ]]; then
      found+=("$deb")
    fi
  done
  if [[ ${#found[@]} -gt 0 ]]; then
    printf '%s\n' "${found[@]}"
  fi
}

list_matching_debs() {
  list_matching_debs_for_globs "${XRT_DEB_GLOBS:-}"
}

# Prefer host/auto-discovered Ubuntu tags (or explicit XRT_UBUNTU_VERSIONS), then
# XRT_DEB_GLOBS override. Sets XRT_DEB_GLOBS / XRT_DEB_MATCH_* on success.
resolve_xrt_deb_globs() {
  local mode="${XRT_DEB_GLOBS_MODE:-auto}"
  local override="${XRT_DEB_GLOBS_OVERRIDE:-}"
  local ver globs matches preference
  local -a versions=()

  XRT_DEB_MATCH_SOURCE="none"
  XRT_DEB_MATCH_UBUNTU_VERSION=""
  XRT_DEB_GLOBS=""
  XRT_UBUNTU_VERSIONS_SOURCE="${XRT_UBUNTU_VERSIONS_SOURCE:-auto}"

  if [[ "$mode" == "override" ]]; then
    if [[ -z "$override" ]]; then
      echo "[ERROR] XRT_DEB_GLOBS_MODE=override requires XRT_DEB_GLOBS to be set."
      return 1
    fi
    XRT_DEB_GLOBS="$override"
    matches="$(list_matching_debs_for_globs "$XRT_DEB_GLOBS" || true)"
    if [[ -n "$matches" ]]; then
      XRT_DEB_MATCH_SOURCE="override"
      echo "[INFO] Using XRT_DEB_GLOBS override (mode=override); matched $(printf '%s\n' "$matches" | grep -c . || true) package(s)."
      return 0
    fi
    echo "[ERROR] XRT_DEB_GLOBS override matched no packages under $AMD_ARTIFACT_ROOT."
    return 1
  fi

  if [[ -n "${XRT_UBUNTU_VERSIONS// /}" ]]; then
    XRT_UBUNTU_VERSIONS_SOURCE="explicit"
  else
    XRT_UBUNTU_VERSIONS_SOURCE="auto"
  fi
  preference="$(build_xrt_ubuntu_version_preference || true)"
  # shellcheck disable=SC2206
  versions=(${preference:-})
  # Reflect resolved preference for reports (auto may expand beyond config).
  XRT_UBUNTU_VERSIONS="${versions[*]}"

  if [[ ${#versions[@]} -eq 0 ]]; then
    echo "[INFO] No Ubuntu version preference available (empty host id and no staged version-tagged XRT debs)."
  else
    echo "[INFO] XRT deb version preference (${XRT_UBUNTU_VERSIONS_SOURCE}): ${versions[*]} (host Ubuntu: ${XRT_HOST_UBUNTU_VERSION:-unknown})"
  fi

  for ver in "${versions[@]+"${versions[@]}"}"; do
    [[ -n "$ver" ]] || continue
    globs="$(xrt_globs_for_ubuntu_version "$ver")"
    matches="$(list_matching_debs_for_globs "$globs" || true)"
    if [[ -n "$matches" ]]; then
      XRT_DEB_GLOBS="$globs"
      XRT_DEB_MATCH_SOURCE="ubuntu-${ver}"
      XRT_DEB_MATCH_UBUNTU_VERSION="$ver"
      if [[ -n "${XRT_HOST_UBUNTU_VERSION:-}" && "$ver" != "$XRT_HOST_UBUNTU_VERSION" ]]; then
        echo "[WARN] Host is Ubuntu ${XRT_HOST_UBUNTU_VERSION}; using staged XRT debs tagged for Ubuntu ${ver} (version fallback)."
      else
        echo "[INFO] Matched staged XRT debs for Ubuntu ${ver}."
      fi
      return 0
    fi
    echo "[INFO] No staged XRT debs matched Ubuntu ${ver} filename patterns."
  done

  if [[ -n "$override" ]]; then
    echo "[INFO] No version-tagged XRT debs matched; trying XRT_DEB_GLOBS override."
    XRT_DEB_GLOBS="$override"
    matches="$(list_matching_debs_for_globs "$XRT_DEB_GLOBS" || true)"
    if [[ -n "$matches" ]]; then
      XRT_DEB_MATCH_SOURCE="override"
      echo "[INFO] Matched staged XRT debs via XRT_DEB_GLOBS override."
      return 0
    fi
    echo "[WARN] XRT_DEB_GLOBS override set but matched no files under $AMD_ARTIFACT_ROOT."
  fi

  XRT_DEB_GLOBS=""
  XRT_DEB_MATCH_SOURCE="none"
  return 1
}

# Report staged XRT-like debs that did not match the active resolved globs.
list_unmatched_xrt_debs() {
  local deb matched=false configured_path
  local -a configured=()
  [[ -d "$AMD_ARTIFACT_ROOT" ]] || return 0
  mapfile -t configured < <(list_matching_debs || true)
  while IFS= read -r -d '' deb; do
    matched=false
    for configured_path in "${configured[@]+"${configured[@]}"}"; do
      if [[ "$deb" == "$configured_path" ]]; then
        matched=true
        break
      fi
    done
    if [[ "$matched" == "false" ]]; then
      printf '%s\n' "$deb"
    fi
  done < <(find "$AMD_ARTIFACT_ROOT" -maxdepth 5 -type f \( -name 'xrt_*.deb' -o -name 'xrt_plugin*.deb' \) -print0 2>/dev/null | sort -z)
}

# True when the Ryzen AI venv looks fully installed (not a partial ensurepip failure).
ryzen_ai_venv_usable() {
  local root="${1:-$RYZEN_AI_INSTALL_ROOT/venv}"
  local py="$root/bin/python"
  [[ -x "$py" ]] || return 1
  # Prefer the AMD package; fall back to onnxruntime_vitisai which the installer also drops.
  if "$py" -c 'import ryzen_ai' >/dev/null 2>&1; then
    return 0
  fi
  if "$py" -c 'import onnxruntime_vitisai' >/dev/null 2>&1; then
    return 0
  fi
  # Last resort: site-packages tree present after a successful wheel install.
  if compgen -G "$root/lib/python*/site-packages/ryzen_ai" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# Prefer the real interpreter over uv/pyenv shims so AMD's `venv --copies` works.
resolve_python312_bin_dir() {
  local resolved
  if ! command -v python3.12 >/dev/null 2>&1; then
    return 1
  fi
  resolved="$(python3.12 -c 'import pathlib, sys; print(pathlib.Path(sys.executable).resolve().parent)' 2>/dev/null || true)"
  if [[ -n "$resolved" && -x "$resolved/python3.12" ]]; then
    printf '%s\n' "$resolved"
    return 0
  fi
  printf '%s\n' "$(dirname "$(command -v python3.12)")"
}

detect_runtime_state() {
  XRT_STATE="missing"
  if command -v xrt-smi >/dev/null 2>&1; then
    XRT_STATE="available"
  elif [[ -x /opt/xilinx/xrt/bin/xrt-smi ]]; then
    XRT_STATE="available"
  fi

  RYZEN_AI_STATE="missing"
  if ryzen_ai_venv_usable "$RYZEN_AI_INSTALL_ROOT/venv"; then
    RYZEN_AI_STATE="available"
  fi

  MODULE_STATE="missing"
  if [[ -r /proc/modules ]] && grep -Eq '^(amdxdna|xrt|xdna)[[:space:]]' /proc/modules 2>/dev/null; then
    MODULE_STATE="loaded"
  fi

  DEVICE_STATE="missing"
  if find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null | grep -q .; then
    DEVICE_STATE="present"
  fi
}

write_env_snippet() {
  cat > "$ENV_SNIPPET" <<EOF_ENV
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Generated by scripts/205-install-xrt-ryzen-ai.sh

if [[ -f /opt/xilinx/xrt/setup.sh ]]; then
  # shellcheck source=/dev/null
  source /opt/xilinx/xrt/setup.sh
fi
if [[ -d /opt/xilinx/xrt/bin ]]; then
  export PATH="/opt/xilinx/xrt/bin:\${PATH}"
fi
if [[ -d "$RYZEN_AI_INSTALL_ROOT/venv" ]]; then
  export RYZEN_AI_INSTALLATION_PATH="$RYZEN_AI_INSTALL_ROOT/venv"
fi
EOF_ENV
  chmod +x "$ENV_SNIPPET"
}

install_xrt_debs() {
  local deb count=0
  local -a debs=()
  mapfile -t debs < <(list_matching_debs || true)
  if [[ ${#debs[@]} -eq 0 ]]; then
    return 1
  fi

  if [[ "${EUID}" -ne 0 ]]; then
    echo "[INFO] sudo access is required to install XRT/NPU packages."
    sudo -v
  fi

  for deb in "${debs[@]}"; do
    echo "[INFO] Installing staged XRT/NPU package: $deb"
    if [[ "$OFFLINE" == "true" ]]; then
      sudo apt-get install --fix-broken -y --no-download "$deb"
    else
      sudo apt-get install --fix-broken -y "$deb"
    fi
    count=$((count + 1))
  done
  echo "[INFO] Installed $count XRT/NPU package(s)."
  return 0
}

install_ryzen_ai_package() {
  local archive workdir installer installer_dir venv_path wheel_count rc py312_bin_dir
  archive="$(find_first_match "$AMD_ARTIFACT_ROOT" "$RYZEN_AI_ARTIFACT_GLOB")"
  if [[ -z "$archive" ]]; then
    echo "[WARN] No Ryzen AI archive matched '$RYZEN_AI_ARTIFACT_GLOB' under $AMD_ARTIFACT_ROOT."
    return 1
  fi

  if ! command -v python3.12 >/dev/null 2>&1; then
    echo "[ERROR] Ryzen AI 1.7.x requires python3.12 on PATH (system default may be newer)."
    echo "[ERROR] Install Python 3.12 (e.g. deadsnakes, uv python install 3.12) and re-run."
    return 1
  fi

  # AMD's installer runs `python3.12 -m venv --copies`. uv/pyenv shims often break
  # under --copies; put the resolved real interpreter directory first on PATH.
  py312_bin_dir="$(resolve_python312_bin_dir || true)"
  if [[ -z "$py312_bin_dir" ]]; then
    echo "[ERROR] Could not resolve a usable python3.12 binary."
    return 1
  fi

  mkdir -p "$RYZEN_AI_INSTALL_ROOT"
  workdir="$RYZEN_AI_INSTALL_ROOT/source"
  venv_path="$RYZEN_AI_INSTALL_ROOT/venv"

  # AMD installer refuses to overwrite an existing venv path; also drop partials.
  if [[ -d "$venv_path" ]]; then
    echo "[INFO] Removing previous Ryzen AI venv at $venv_path before reinstall."
    rm -rf "$venv_path"
  fi

  rm -rf "$workdir"
  mkdir -p "$workdir"
  echo "[INFO] Extracting Ryzen AI package: $archive"
  # Flat archives (./install_ryzen_ai.sh) extract without strip; nested vendor
  # trees may need --strip-components=1.
  if ! tar -xzf "$archive" -C "$workdir" 2>/dev/null; then
    rm -rf "$workdir"
    mkdir -p "$workdir"
    tar -xzf "$archive" -C "$workdir" --strip-components=1
  fi
  installer="$(find "$workdir" -maxdepth 3 -type f -name 'install_ryzen_ai.sh' | sort | head -n 1)"
  if [[ -z "$installer" ]]; then
    echo "[WARN] Ryzen AI installer was not found after extraction; leaving files at $workdir."
    return 1
  fi
  chmod +x "$installer"
  installer_dir="$(cd "$(dirname "$installer")" && pwd)"

  # AMD's install_ryzen_ai.sh runs `ls *.whl` in the process CWD, not next to the
  # script. Always invoke it from the directory that contains the wheels.
  wheel_count="$(find "$installer_dir" -maxdepth 1 -type f -name '*.whl' 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${wheel_count:-0}" -eq 0 ]]; then
    echo "[ERROR] No .whl files next to install_ryzen_ai.sh in $installer_dir."
    echo "[ERROR] Re-stage a complete ryzen_ai-*.tgz under $AMD_ARTIFACT_ROOT."
    return 1
  fi
  echo "[INFO] Found $wheel_count wheel(s) beside installer in $installer_dir"
  echo "[INFO] Installing Ryzen AI software into: $venv_path"
  echo "[INFO] Using python3.12: $py312_bin_dir/python3.12 ($("$py312_bin_dir/python3.12" --version 2>&1))"

  rc=0
  (
    export PATH="$py312_bin_dir:$PATH"
    cd "$installer_dir"
    ./install_ryzen_ai.sh -a yes -p "$venv_path"
  ) || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "[ERROR] Ryzen AI installer exited with status $rc."
    # Always remove incomplete venvs so status detection and re-runs stay honest.
    if [[ -d "$venv_path" ]] && ! ryzen_ai_venv_usable "$venv_path"; then
      echo "[INFO] Removing incomplete Ryzen AI venv at $venv_path."
      rm -rf "$venv_path"
    fi
    return 1
  fi
  if ! ryzen_ai_venv_usable "$venv_path"; then
    echo "[ERROR] Ryzen AI installer finished but venv is missing or incomplete at $venv_path."
    if [[ -d "$venv_path" ]]; then
      rm -rf "$venv_path"
    fi
    return 1
  fi
  return 0
}

write_reports() {
  local status="$1"
  local action="$2"
  local detail="$3"
  local staged_debs="$4"
  local staged_ryzen="$5"

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" \
  ACCEPT_RISK="$ACCEPT_AMD_ACCELERATION_RISK" STATUS="$status" ACTION="$action" DETAIL="$detail" \
  AMD_ARTIFACT_ROOT="$AMD_ARTIFACT_ROOT" RYZEN_AI_INSTALL_ROOT="$RYZEN_AI_INSTALL_ROOT" \
  XRT_STATE="$XRT_STATE" RYZEN_AI_STATE="$RYZEN_AI_STATE" MODULE_STATE="$MODULE_STATE" \
  DEVICE_STATE="$DEVICE_STATE" STAGED_DEBS="$staged_debs" STAGED_RYZEN="$staged_ryzen" \
  ENV_SNIPPET="$ENV_SNIPPET" \
  XRT_DEB_MATCH_SOURCE="${XRT_DEB_MATCH_SOURCE:-none}" \
  XRT_DEB_MATCH_UBUNTU_VERSION="${XRT_DEB_MATCH_UBUNTU_VERSION:-}" \
  XRT_HOST_UBUNTU_VERSION="${XRT_HOST_UBUNTU_VERSION:-}" \
  XRT_UBUNTU_VERSIONS="${XRT_UBUNTU_VERSIONS:-}" \
  XRT_UBUNTU_VERSIONS_SOURCE="${XRT_UBUNTU_VERSIONS_SOURCE:-auto}" \
  XRT_DEB_GLOBS_MODE="${XRT_DEB_GLOBS_MODE:-auto}" \
  XRT_DEB_GLOBS="${XRT_DEB_GLOBS:-}" \
  python3 - "$STATUS_JSON" "$SUMMARY_MD" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

status_path, summary_path = map(Path, sys.argv[1:])
staged_debs = [line for line in os.environ.get("STAGED_DEBS", "").splitlines() if line.strip()]
staged_ryzen = os.environ.get("STAGED_RYZEN", "") or None
status = os.environ["STATUS"]
detail = os.environ.get("DETAIL", "")
match_source = os.environ.get("XRT_DEB_MATCH_SOURCE", "none")
match_ubuntu = os.environ.get("XRT_DEB_MATCH_UBUNTU_VERSION") or None
host_ubuntu = os.environ.get("XRT_HOST_UBUNTU_VERSION") or None
ubuntu_versions = [v for v in os.environ.get("XRT_UBUNTU_VERSIONS", "").split() if v]

data = {
    "tier": 2,
    "stage": 2,
    "milestone": "S2-M2",
    "phase": "install-xrt-ryzen-ai",
    "status": status,
    "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "profile": os.environ["PROFILE"],
    "mode": os.environ["MODE"],
    "persistence": os.environ["PERSISTENCE"],
    "offline": os.environ["OFFLINE"] == "true",
    "accept_amd_acceleration_risk": os.environ["ACCEPT_RISK"] == "true",
    "install_action": os.environ["ACTION"],
    "artifact_root": os.environ["AMD_ARTIFACT_ROOT"],
    "ryzen_ai_install_root": os.environ["RYZEN_AI_INSTALL_ROOT"],
    "staged_xrt_debs": staged_debs,
    "staged_ryzen_ai_archive": staged_ryzen,
    "xrt_deb_selection": {
        "mode": os.environ.get("XRT_DEB_GLOBS_MODE", "auto"),
        "host_ubuntu_version": host_ubuntu,
        "ubuntu_versions_source": os.environ.get("XRT_UBUNTU_VERSIONS_SOURCE", "auto"),
        "ubuntu_versions_preference": ubuntu_versions,
        "match_source": match_source,
        "matched_ubuntu_version": match_ubuntu,
        "active_globs": os.environ.get("XRT_DEB_GLOBS", ""),
    },
    "runtime": {
        "xrt": os.environ["XRT_STATE"],
        "ryzen_ai": os.environ["RYZEN_AI_STATE"],
        "kernel_module": os.environ["MODULE_STATE"],
        "device_node": os.environ["DEVICE_STATE"],
    },
    "environment_snippet": os.environ["ENV_SNIPPET"],
    "detail": detail,
    "policy": (
        "Installation requires --accept-amd-acceleration-risk. Without risk acceptance this "
        "script only inventories staged AMD artifacts and existing XRT/Ryzen AI runtime state. "
        "XRT debs are selected by Ubuntu version preference (latest first), then XRT_DEB_GLOBS override."
    ),
}
status_path.write_text(json.dumps(data, indent=2) + "\n")

lines = [
    "# XRT / Ryzen AI Install Status",
    "",
    f"Status: {status}",
    f"Profile: {os.environ['PROFILE']} | Mode: {os.environ['MODE']} | Offline: {os.environ['OFFLINE']}",
    f"Risk accepted: {os.environ['ACCEPT_RISK']}",
    f"Install action: {os.environ['ACTION']}",
    "",
    "## Runtime",
    "",
    f"- XRT tools: {os.environ['XRT_STATE']}",
    f"- Ryzen AI install: {os.environ['RYZEN_AI_STATE']}",
    f"- Kernel module: {os.environ['MODULE_STATE']}",
    f"- Device node: {os.environ['DEVICE_STATE']}",
    "",
    "## XRT deb selection",
    "",
    f"- Mode: {os.environ.get('XRT_DEB_GLOBS_MODE', 'auto')}",
    f"- Host Ubuntu: {host_ubuntu or 'unknown'}",
    f"- Version preference source: {os.environ.get('XRT_UBUNTU_VERSIONS_SOURCE', 'auto')}",
    f"- Version preference: {', '.join(ubuntu_versions) or '(none)'}",
    f"- Match source: {match_source}",
    f"- Matched package Ubuntu tag: {match_ubuntu or 'none'}",
    "",
    "## Artifacts",
    "",
    f"- Root: `{os.environ['AMD_ARTIFACT_ROOT']}`",
    f"- Staged XRT debs: {len(staged_debs)}",
]
for deb in staged_debs:
    lines.append(f"  - `{deb}`")
lines.extend([
    f"- Ryzen AI archive: `{staged_ryzen or 'none'}`",
    "",
    "## Next steps",
    "",
    "- Stage XRT/NPU `.deb` files under the artifact root. Auto mode prefers the "
    "host Ubuntu version, then the previous LTS, then tags discovered in staged "
    f"filenames (resolved order: {', '.join(ubuntu_versions) or 'n/a'}).",
    "- Optionally pin with `XRT_UBUNTU_VERSIONS`, set `XRT_DEB_GLOBS` as a last-resort "
    "override, or use `XRT_DEB_GLOBS_MODE=override` for custom globs only.",
    "- Optionally stage `ryzen_ai-*.tgz` for the Ryzen AI software installer.",
    "- Re-run with `--accept-amd-acceleration-risk` to install staged packages:",
    "  `./ai370-optimize.sh stage2-npu --accept-amd-acceleration-risk`",
    f"- Source `{os.environ['ENV_SNIPPET']}` after install for XRT PATH setup.",
    "- Continue with `scripts/210-check-ryzen-ai-software.sh` and `scripts/230-benchmark-npu.sh`.",
    "",
    "## Detail",
    "",
    detail,
    "",
])
summary_path.write_text("\n".join(lines))
PY
}

main() {
  echo "[INFO] S2-M2: XRT / Ryzen AI install or staging validation"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE"
  echo "[INFO] Offline: $OFFLINE  Risk accepted: $ACCEPT_AMD_ACCELERATION_RISK"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent XRT/Ryzen AI configuration is not implemented. Use --persistence=runtime."
    exit 2
  fi

  mkdir -p "$LATEST_DIR"
  load_config
  detect_runtime_state
  write_env_snippet

  local staged_debs staged_ryzen
  staged_debs="$(list_matching_debs || true)"
  staged_ryzen="$(find_first_match "$AMD_ARTIFACT_ROOT" "$RYZEN_AI_ARTIFACT_GLOB" || true)"

  local status="WARN" action="inventory-only" detail=""
  local deb_count=0
  if [[ -n "$staged_debs" ]]; then
    deb_count="$(printf '%s\n' "$staged_debs" | grep -c . || true)"
  fi

  if [[ "$ACCEPT_AMD_ACCELERATION_RISK" != "true" ]]; then
    action="skipped-no-risk-ack"
    detail="Risk not accepted: no packages were installed. Stage artifacts under $AMD_ARTIFACT_ROOT and re-run with --accept-amd-acceleration-risk."
    if [[ "$XRT_STATE" == "available" ]]; then
      status="PASS"
      detail="XRT tools already available. Risk not accepted so no package install was attempted. Staged debs: $deb_count."
    elif [[ "$deb_count" -gt 0 ]]; then
      status="WARN"
      detail="Found $deb_count staged XRT deb(s) but did not install them (risk not accepted). Re-run stage2-npu with --accept-amd-acceleration-risk."
    else
      status="WARN"
      detail="No staged XRT debs under $AMD_ARTIFACT_ROOT and xrt-smi not in PATH. Stage AMD packages then re-run with --accept-amd-acceleration-risk. See docs/npu-status.md."
    fi
  else
    action="install-attempted"
    local xrt_ok="false" ryzen_ok="false" unmatched_debs=""
    unmatched_debs="$(list_unmatched_xrt_debs || true)"
    if install_xrt_debs; then
      xrt_ok="true"
      echo "[INFO] XRT deb install used match source: ${XRT_DEB_MATCH_SOURCE} (Ubuntu tag: ${XRT_DEB_MATCH_UBUNTU_VERSION:-n/a})"
    else
      echo "[WARN] No matching XRT/NPU debs found under $AMD_ARTIFACT_ROOT"
      echo "[WARN] Tried Ubuntu versions: ${XRT_UBUNTU_VERSIONS} (mode=${XRT_DEB_GLOBS_MODE})"
      if [[ -n "${XRT_DEB_GLOBS_OVERRIDE:-}" ]]; then
        echo "[WARN] XRT_DEB_GLOBS override was also tried and did not match."
      else
        echo "[WARN] Set XRT_DEB_GLOBS to a custom pattern list as a last-resort override, or stage packages for: ${XRT_UBUNTU_VERSIONS}"
      fi
      if [[ -n "$unmatched_debs" ]]; then
        echo "[WARN] Found XRT-like debs that still did not match any preference/override:"
        printf '%s\n' "$unmatched_debs" | while IFS= read -r line; do
          [[ -n "$line" ]] && echo "[WARN]   $line"
        done
      fi
    fi
    # Capture status explicitly: when this function is used in `if`, bash
    # suppresses set -e inside the function body, so we must not rely on a
    # trailing unconditional return 0.
    if install_ryzen_ai_package; then
      ryzen_ok="true"
    else
      ryzen_ok="false"
    fi
    detect_runtime_state
    write_env_snippet
    staged_debs="$(list_matching_debs || true)"
    staged_ryzen="$(find_first_match "$AMD_ARTIFACT_ROOT" "$RYZEN_AI_ARTIFACT_GLOB" || true)"

    if [[ "$xrt_ok" == "true" || "$XRT_STATE" == "available" ]]; then
      if [[ "$RYZEN_AI_STATE" == "available" ]]; then
        status="PASS"
        action="installed-or-validated"
        if [[ "$ryzen_ok" == "true" ]]; then
          detail="XRT available and Ryzen AI software installed into $RYZEN_AI_INSTALL_ROOT/venv."
        else
          detail="XRT available and an existing usable Ryzen AI venv was validated at $RYZEN_AI_INSTALL_ROOT/venv."
        fi
      else
        status="WARN"
        action="xrt-installed-ryzen-missing"
        detail="XRT path succeeded or was already available, but Ryzen AI install did not produce a usable venv at $RYZEN_AI_INSTALL_ROOT/venv. Ensure ryzen_ai-*.tgz is complete, a non-shim python3.12 is available (uv python install 3.12 works if PATH resolves the real binary), and re-run with --accept-amd-acceleration-risk."
      fi
    elif [[ "$deb_count" -eq 0 ]]; then
      status="FAIL"
      action="install-failed-no-artifacts"
      detail="Risk accepted but no XRT/NPU .deb packages matched under $AMD_ARTIFACT_ROOT after trying Ubuntu versions [${XRT_UBUNTU_VERSIONS}] and any XRT_DEB_GLOBS override. Stage packages per configs/amd-acceleration.env and docs/npu-status.md."
    else
      status="FAIL"
      action="install-failed"
      detail="Risk accepted and staged debs were present, but XRT tools remain unavailable after install. Check apt output and reboot if drivers changed."
    fi
  fi

  write_reports "$status" "$action" "$detail" "$staged_debs" "$staged_ryzen"
  echo "[INFO] XRT/Ryzen AI status: $status ($action)"
  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
  echo "[INFO] Wrote $ENV_SNIPPET"

  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
