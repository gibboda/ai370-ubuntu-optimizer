#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# GitHub Actions: mount a loop-backed ext4 filesystem on .ai370-ai/models so
# scripts/150-validate-offline-model-storage.sh sees enough free GiB for
# manifest minimum_free_gb (20). The runner workspace filesystem often has
# <20 GiB free after earlier smoke steps, which yields intermittent FAIL
# (not missing models — storage.free_gb below minimum_free_gb).

prepare_portable_model_root() {
  local project_root="${1:?project root required}"
  if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
    return 0
  fi
  if [[ -n "${AI370_PORTABLE_MODEL_ROOT_PREPARED:-}" ]]; then
    return 0
  fi

  local models_dir="$project_root/.ai370-ai/models"
  mkdir -p "$project_root/.ai370-ai"

  if mountpoint -q "$models_dir" 2>/dev/null; then
    export AI370_PORTABLE_MODEL_ROOT_PREPARED=1
    return 0
  fi

  local img="${RUNNER_TEMP:-/tmp}/ai370-portable-models.img"
  local size_mb=32768
  if [[ ! -f "$img" ]]; then
    fallocate -l "${size_mb}M" "$img" 2>/dev/null || dd if=/dev/zero of="$img" bs=1M count="$size_mb" status=none
    mkfs.ext4 -F -q "$img"
  fi

  mkdir -p "$models_dir"
  if ! sudo mount -o loop "$img" "$models_dir"; then
    rm -f "$img"
    fallocate -l "${size_mb}M" "$img" 2>/dev/null || dd if=/dev/zero of="$img" bs=1M count="$size_mb" status=none
    mkfs.ext4 -F -q "$img"
    if ! sudo mount -o loop "$img" "$models_dir"; then
      echo "[FAIL] Could not mount portable model-root loop filesystem on $models_dir" >&2
      return 1
    fi
  fi
  sudo chown -R "$(id -u):$(id -g)" "$models_dir"

  export AI370_PORTABLE_MODEL_ROOT_PREPARED=1
  echo "[INFO] Portable model root mounted (loop ext4) at $models_dir for minimum_free_gb checks"
  df -h "$models_dir" || true
}
