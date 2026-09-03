#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

main() {
  local subject="${1:-}"
  local allowed_types allowed_scopes pattern

  if [[ -z "$subject" ]]; then
    echo "[ERROR] Usage: $0 'type(optional-scope): Subject'" >&2
    return 2
  fi

  allowed_types='feat|fix|chore|refactor|docs|test|ci|perf'
  allowed_scopes='audit|baseline|amd|ai-stack|rocm|npu|acceleration|comfyui|config|architecture|agents|governance|mcp|workflows|vscode|settings|release|deps|stage|stage1|stage2|stage3|stage4|stage5|tier|tier1|tier2'
  pattern="^(${allowed_types})(\\((${allowed_scopes})\\))?!?: [A-Za-z].+$"

  if [[ ! "$subject" =~ $pattern ]]; then
    echo "[ERROR] Commit subject does not follow Conventional Commits: $subject" >&2
    echo "[ERROR] Expected: type(optional-scope): Subject" >&2
    echo "[ERROR] Allowed types: feat, fix, chore, refactor, docs, test, ci, perf" >&2
    echo "[ERROR] Allowed scopes: audit, baseline, amd, ai-stack, rocm, npu, acceleration, comfyui, config, architecture, agents, governance, mcp, workflows, vscode, settings, release, deps, stage, stage1, stage2, stage3, stage4, stage5, tier (deprecated), tier1 (deprecated), tier2 (deprecated)" >&2
    echo "[ERROR] Subject must start with a letter" >&2
    return 1
  fi

  echo "[INFO] Commit subject is Conventional Commit compliant: $subject"
}

main "$@"
