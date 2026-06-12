#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# .vscode/scripts/grok-commit-push-pr.sh
# Grok-powered Commit + Push + Create PR workflow
# Respects protected branches and works with required status checks

set -euo pipefail

main() {
    PROFILE="${1:-ai370}"
    MODE="${2:-safe}"
    PERSISTENCE="${3:-runtime}"

    echo "[INFO] Starting Grok Agent: Commit + Push + Create PR"
    echo "[INFO] Profile=${PROFILE} Mode=${MODE} Persistence=${PERSISTENCE}"

    # 1. Ensure we are not on a protected branch
    protected_branches=("main" "master" "develop")
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    for branch in "${protected_branches[@]}"; do
        if [[ "$current_branch" == "$branch" ]]; then
            echo "[ERROR] You are on protected branch '$current_branch'."
            echo "[ERROR] Please run the 'Grok Agent: Create Feature Branch' task first."
            exit 1
        fi
    done

    # 2. Stage all changes
    echo "[INFO] Staging all changes..."
    git add -A

    if git diff --cached --quiet; then
        echo "[ERROR] No staged changes found to commit."
        exit 1
    fi

    # 3. Commit (prompt for message if none provided)
    if [ -z "${COMMIT_MSG:-}" ]; then
        read -r -p "[INFO] Enter commit message (Conventional Commits recommended): " COMMIT_MSG
    fi
    if [ -z "$COMMIT_MSG" ]; then
        echo "[ERROR] Commit message cannot be empty."
        exit 1
    fi
    git commit -m "$COMMIT_MSG"

    # 4. Push with upstream tracking
    echo "[INFO] Pushing branch..."
    git push -u origin "$current_branch"

    # 5. Create Pull Request using GitHub CLI
    echo "[INFO] Creating Pull Request..."
    gh pr create \
        --base main \
        --head "$current_branch" \
        --title "$COMMIT_MSG" \
        --body "$(cat <<EOF
## Summary
Automated PR created via Grok Agent in VS Code.

## Changes
$(git log --oneline -1)

This PR must pass all required status checks before merging.
EOF
)" \
        --draft=false

    echo "[INFO] Done"
    echo "[INFO] Check the Pull Requests sidebar or run: gh pr view --web"
}

main "$@"