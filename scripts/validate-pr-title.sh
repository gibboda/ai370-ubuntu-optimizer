#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

main() {
  local title="${1:-}"
  local allowed_types allowed_scopes pattern

  if [[ -z "$title" ]]; then
    echo "[ERROR] Usage: $0 'type(optional-scope): Subject'" >&2
    return 2
  fi

  allowed_types='feat|fix|chore|refactor|docs|test|ci|perf'
  allowed_scopes='audit|baseline|amd|ai-stack|rocm|npu|acceleration|comfyui|config|workflows|vscode|release|tier|tier1|tier2'
  pattern="^(${allowed_types})(\\((${allowed_scopes})\\))?!?: [A-Za-z].+$"

  if [[ ! "$title" =~ $pattern ]]; then
    echo "[ERROR] PR title does not follow Conventional Commits: $title" >&2
    echo "[ERROR] Expected: type(optional-scope): Subject" >&2
    echo "[ERROR] Allowed types: feat, fix, chore, refactor, docs, test, ci, perf" >&2
    echo "[ERROR] Allowed scopes: audit, baseline, amd, ai-stack, rocm, npu, acceleration, comfyui, config, workflows, vscode, release, tier, tier1, tier2" >&2
    echo "[ERROR] Subject must start with a letter" >&2
    return 1
  fi

  echo "[INFO] PR title is Conventional Commit compliant: $title"
}

main "$@"
