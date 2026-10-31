#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

main() {
  local title="${1:-}"
  local allowed_types allowed_scopes milestone_scope pattern

  if [[ -z "$title" ]]; then
    echo "[ERROR] Usage: $0 'type(optional-scope): Subject'" >&2
    return 2
  fi

  allowed_types='feat|fix|chore|refactor|docs|test|ci|perf'
  allowed_scopes='audit|baseline|amd|ai-stack|rocm|npu|acceleration|comfyui|config|architecture|agents|governance|mcp|contract|workflows|lint|vscode|workspace|settings|release|changelog|deps|stage|stage1|stage2|stage3|stage4|stage5|tier|tier1|tier2'
  milestone_scope='s[1-5]-m[1-9][0-9]*'
  dependabot_pattern='^(chore|ci)\(deps\): bump .+$'
  pattern="^(${allowed_types})(\\((${allowed_scopes}|${milestone_scope})\\))?!?: [A-Z].+$"

  if [[ "$title" =~ $dependabot_pattern ]]; then
    echo "[INFO] PR title is Conventional Commit compliant (Dependabot deps): $title"
    return 0
  fi

  if [[ ! "$title" =~ $pattern ]]; then
    echo "[ERROR] PR title does not follow Conventional Commits: $title" >&2
    echo "[ERROR] Expected: type(optional-scope): Subject" >&2
    echo "[ERROR] Allowed types: feat, fix, chore, refactor, docs, test, ci, perf" >&2
    echo "[ERROR] Allowed scopes: audit, baseline, amd, ai-stack, rocm, npu, acceleration, comfyui, config, architecture, agents, governance, mcp, contract, workflows, lint, vscode, workspace, settings, release, changelog, deps, stage, stage1, stage2, stage3, stage4, stage5, tier (deprecated), tier1 (deprecated), tier2 (deprecated), or canonical milestone scopes like s5-m6" >&2
    echo "[ERROR] Subject must start with an uppercase letter (Dependabot chore(deps)/ci(deps) bump titles are accepted separately)" >&2
    return 1
  fi

  echo "[INFO] PR title is Conventional Commit compliant: $title"
}

main "$@"
