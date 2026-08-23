#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S3-M2: llama.cpp installer / validator with GPU-aware builds.
#
# Backend selection (LLAMA_CPP_BACKEND):
#   auto (default) — HIP/ROCm when hipcc+ROCm present, else Vulkan when available, else CPU
#   hip | vulkan | cpu — force a backend
#
# Rebuild controls:
#   LLAMA_CPP_FORCE_REBUILD=true — rebuild even if a binary already exists
#   LLAMA_CPP_AMDGPU_TARGETS — override HIP targets (default gfx1150 for AI370 / Strix Point)
#   LLAMA_CPP_REPO — git URL override

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
TOOL_ROOT="$AI_ROOT/tools"
LLAMA_DIR="$TOOL_ROOT/llama.cpp"
STATUS_JSON="$LATEST_DIR/tier2-llama-cpp.json"
SUMMARY_MD="$LATEST_DIR/tier2-llama-cpp.md"
LLAMA_CPP_REPO="${LLAMA_CPP_REPO:-https://github.com/ggml-org/llama.cpp.git}"
LLAMA_CPP_BACKEND="${LLAMA_CPP_BACKEND:-auto}"
LLAMA_CPP_FORCE_REBUILD="${LLAMA_CPP_FORCE_REBUILD:-false}"
LLAMA_CPP_AMDGPU_TARGETS="${LLAMA_CPP_AMDGPU_TARGETS:-gfx1150}"

find_llama_binary() {
  local candidate
  for candidate in \
    "$TOOL_ROOT/llama-cli" \
    "$LLAMA_DIR/llama-cli" \
    "$LLAMA_DIR/build/bin/llama-cli" \
    "$TOOL_ROOT/main" \
    "$LLAMA_DIR/main" \
    "$LLAMA_DIR/build/bin/main"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  command -v llama-cli 2>/dev/null || true
}

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

hip_available() {
  # hipcc on PATH is the practical signal that a ROCm/HIP toolchain can compile GGML_HIP.
  if command -v hipcc >/dev/null 2>&1; then
    return 0
  fi
  if [[ -x /opt/rocm/bin/hipcc ]]; then
    return 0
  fi
  return 1
}

vulkan_available() {
  command -v vulkaninfo >/dev/null 2>&1 || return 1
  # glslc or vulkan shader toolchain often required for build; soft-check vulkaninfo first
  if command -v glslc >/dev/null 2>&1 || pkg-config --exists vulkan 2>/dev/null; then
    return 0
  fi
  # Still try Vulkan if headers/libs may be present via system packages
  [[ -f /usr/include/vulkan/vulkan.h ]] || ldconfig -p 2>/dev/null | grep -q libvulkan
}

detect_built_backends() {
  local backends=()
  if [[ -d "$LLAMA_DIR/build/bin" ]]; then
    [[ -e "$LLAMA_DIR/build/bin/libggml-hip.so" || -e "$LLAMA_DIR/build/bin/libggml-hip.so.0" ]] && backends+=(hip)
    [[ -e "$LLAMA_DIR/build/bin/libggml-vulkan.so" || -e "$LLAMA_DIR/build/bin/libggml-vulkan.so.0" ]] && backends+=(vulkan)
    [[ -e "$LLAMA_DIR/build/bin/libggml-cpu.so" || -e "$LLAMA_DIR/build/bin/libggml-cpu.so.0" ]] && backends+=(cpu)
  fi
  if [[ ${#backends[@]} -eq 0 ]]; then
    printf 'unknown'
  else
    local IFS=,
    printf '%s' "${backends[*]}"
  fi
}

select_backend() {
  case "$LLAMA_CPP_BACKEND" in
    cpu|hip|vulkan)
      printf '%s\n' "$LLAMA_CPP_BACKEND"
      return
      ;;
    auto) ;;
    *)
      echo "[WARN] Unknown LLAMA_CPP_BACKEND=$LLAMA_CPP_BACKEND; using auto."
      ;;
  esac

  if hip_available; then
    printf 'hip\n'
  elif vulkan_available; then
    printf 'vulkan\n'
  else
    printf 'cpu\n'
  fi
}

cmake_args_for_backend() {
  local backend="$1"
  local -a args=(-DLLAMA_CURL=OFF)
  case "$backend" in
    hip)
      args+=(-DGGML_HIP=ON)
      if [[ -n "$LLAMA_CPP_AMDGPU_TARGETS" ]]; then
        args+=(-DAMDGPU_TARGETS="$LLAMA_CPP_AMDGPU_TARGETS")
      fi
      # Prefer ROCm root when present
      if [[ -d /opt/rocm ]]; then
        args+=(-DCMAKE_PREFIX_PATH=/opt/rocm)
      fi
      ;;
    vulkan)
      args+=(-DGGML_VULKAN=ON)
      ;;
    cpu)
      ;;
  esac
  printf '%s\n' "${args[@]}"
}

build_llama() {
  local backend="$1"
  local -a cmake_args=()
  mapfile -t cmake_args < <(cmake_args_for_backend "$backend")

  echo "[INFO] Configuring llama.cpp backend=$backend targets=${LLAMA_CPP_AMDGPU_TARGETS:-n/a}"
  echo "[INFO] cmake args: ${cmake_args[*]}"

  # Fresh configure when switching backends
  if [[ -d "$LLAMA_DIR/build" && "$LLAMA_CPP_FORCE_REBUILD" == "true" ]]; then
    echo "[INFO] Removing previous build directory for forced rebuild."
    rm -rf "$LLAMA_DIR/build"
  fi

  if ! cmake -S "$LLAMA_DIR" -B "$LLAMA_DIR/build" "${cmake_args[@]}"; then
    return 1
  fi
  if ! cmake --build "$LLAMA_DIR/build" --config Release -j "$(nproc 2>/dev/null || echo 2)"; then
    return 2
  fi
  return 0
}

main() {
  mkdir -p "$LATEST_DIR" "$TOOL_ROOT"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent llama.cpp installation is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local action="none" status="WARN" detail="" binary="" backend="cpu" built_backends="unknown"
  local selected_backend version="not-run" build_rc=0

  selected_backend="$(select_backend)"
  backend="$selected_backend"
  binary="$(find_llama_binary || true)"
  if [[ -n "$binary" ]]; then
    built_backends="$(detect_built_backends)"
  fi

  local should_build="false"
  if [[ -z "$binary" && "$OFFLINE" != "true" ]]; then
    should_build="true"
    action="clone-and-build"
  elif [[ -n "$binary" && "$LLAMA_CPP_FORCE_REBUILD" == "true" && "$OFFLINE" != "true" ]]; then
    should_build="true"
    action="force-rebuild"
  elif [[ -z "$binary" && "$OFFLINE" == "true" ]]; then
    action="skipped-offline-missing-binary"
    detail="Offline mode: stage llama-cli under $TOOL_ROOT or $LLAMA_DIR/build/bin before rerunning."
  else
    action="validated-existing-binary"
    # Existing CPU-only build while HIP/Vulkan is available → actionable WARN
    if [[ "$selected_backend" != "cpu" && "$built_backends" != *"$selected_backend"* ]]; then
      status="WARN"
      detail="Existing llama.cpp binary appears to lack backend '$selected_backend' (detected: $built_backends). Rebuild with LLAMA_CPP_FORCE_REBUILD=true LLAMA_CPP_BACKEND=$selected_backend for GPU acceleration on $LLAMA_CPP_AMDGPU_TARGETS."
    fi
  fi

  if [[ "$should_build" == "true" ]]; then
    if ! command -v git >/dev/null 2>&1 || ! command -v cmake >/dev/null 2>&1 || ! command -v make >/dev/null 2>&1; then
      action="missing-build-tools"
      status="FAIL"
      detail="git, cmake, and make are required for online llama.cpp builds."
    else
      if [[ ! -d "$LLAMA_DIR/.git" ]]; then
        if ! git clone --depth 1 "$LLAMA_CPP_REPO" "$LLAMA_DIR"; then
          action="clone-failed"
          status="FAIL"
          detail="Failed to clone llama.cpp from $LLAMA_CPP_REPO; see console output."
        fi
      fi

      if [[ "$status" != "FAIL" ]]; then
        set +e
        build_llama "$selected_backend"
        build_rc=$?
        set -e
        if [[ $build_rc -ne 0 && "$selected_backend" != "cpu" ]]; then
          echo "[WARN] Backend $selected_backend build failed (rc=$build_rc); falling back to CPU."
          detail="Preferred backend $selected_backend failed; fell back to CPU. See cmake/build logs."
          backend="cpu"
          set +e
          build_llama "cpu"
          build_rc=$?
          set -e
          action="fallback-cpu-build"
        fi
        if [[ $build_rc -eq 1 ]]; then
          action="cmake-configure-failed"
          status="FAIL"
          detail="llama.cpp CMake configure failed for backend $backend; see console output."
        elif [[ $build_rc -eq 2 ]]; then
          action="cmake-build-failed"
          status="FAIL"
          detail="llama.cpp build failed for backend $backend; see console output."
        else
          binary="$(find_llama_binary || true)"
          built_backends="$(detect_built_backends)"
          backend="$selected_backend"
          if [[ -n "$detail" && "$action" == "fallback-cpu-build" ]]; then
            backend="cpu"
          fi
        fi
      fi
    fi
  fi

  if [[ -n "$binary" && "$status" != "FAIL" ]]; then
    # PASS if binary works; keep WARN when GPU upgrade is recommended
    if [[ "$status" != "WARN" ]]; then
      status="PASS"
    fi
    version="$($binary --version 2>&1 || true)"
    if [[ -z "$detail" ]]; then
      detail="llama.cpp validation completed (backend preference: $selected_backend, built: $built_backends)."
    fi
  elif [[ "$status" != "FAIL" && -z "$detail" ]]; then
    detail="llama.cpp binary not found."
  fi

  local detail_json version_json backend_json built_json
  detail_json="$(printf '%s' "$detail" | json_escape)"
  version_json="$(printf '%s' "$version" | json_escape)"
  backend_json="$(printf '%s' "$backend" | json_escape)"
  built_json="$(printf '%s' "$built_backends" | json_escape)"
  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 2,
  "stage": 2,
  "phase": "install-llama-cpp",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $([[ "$OFFLINE" == "true" ]] && echo true || echo false),
  "binary": "${binary:-}",
  "install_action": "$action",
  "backend_requested": "$selected_backend",
  "backend_effective": $backend_json,
  "built_backends": $built_json,
  "amdgpu_targets": "$LLAMA_CPP_AMDGPU_TARGETS",
  "force_rebuild": $([[ "$LLAMA_CPP_FORCE_REBUILD" == "true" ]] && echo true || echo false),
  "version": $version_json,
  "detail": $detail_json
}
EOF_JSON
  {
    echo "# Tier 2 llama.cpp Status"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- Binary: ${binary:-not-found}"
    echo "- Install action: $action"
    echo "- Backend requested: $selected_backend"
    echo "- Backend effective: $backend"
    echo "- Built backends detected: $built_backends"
    echo "- AMDGPU targets: $LLAMA_CPP_AMDGPU_TARGETS"
    echo "- Force rebuild: $LLAMA_CPP_FORCE_REBUILD"
    echo
    printf '```text\n%s\n```\n' "$version"
    echo
    printf '%s\n' "$detail"
    echo
    echo "Rebuild with GPU (example):"
    echo "\`LLAMA_CPP_FORCE_REBUILD=true LLAMA_CPP_BACKEND=hip ./scripts/110-install-llama-cpp.sh $PROFILE $MODE $PERSISTENCE\`"
  } > "$SUMMARY_MD"

  echo "[INFO] llama.cpp status: $status action=$action backend=$selected_backend built=$built_backends"
  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"

  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
