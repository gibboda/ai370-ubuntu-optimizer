#!/bin/bash
# .vscode/scripts/grok-commit-push-pr.sh
# Grok-powered Commit + Push + Create PR workflow
# Respects protected branches and works with required status checks

set -euo pipefail

echo "=== Grok Agent: Commit + Push + Create PR ==="

# 1. Ensure we are not on a protected branch
protected_branches=("main" "master" "develop")
current_branch=$(git rev-parse --abbrev-ref HEAD)

for branch in "${protected_branches[@]}"; do
    if [[ "$current_branch" == "$branch" ]]; then
        echo "ERROR: You are on protected branch '$current_branch'."
        echo "Please run the 'Grok Agent: Create Feature Branch' task first."
        exit 1
    fi
done

# 2. Stage all changes
echo "Staging all changes..."
git add -A

# 3. Commit (prompt for message if none provided)
if [ -z "${COMMIT_MSG:-}" ]; then
    read -p "Enter commit message (Conventional Commits recommended): " COMMIT_MSG
fi
git commit -m "$COMMIT_MSG"

# 4. Push with upstream tracking
echo "Pushing branch..."
git push -u origin "$current_branch"

# 5. Create Pull Request using GitHub CLI
echo "Creating Pull Request..."
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
    --draft=false || echo "PR may already exist or gh command needs attention."

echo "=== Done ==="
echo "Check the Pull Requests sidebar or run: gh pr view --web"