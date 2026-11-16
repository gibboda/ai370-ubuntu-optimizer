#!/usr/bin/env bash
# Create a dedicated user without sudo for portable test steps.
set -euo pipefail

test_user="${AI370_CI_TEST_USER:-ai370ci}"
workspace="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
runner_group="$(id -gn)"
report_stage="${RUNNER_TEMP:?RUNNER_TEMP is required}/portable-test-reports"

if ! id "$test_user" >/dev/null 2>&1; then
  sudo useradd --create-home --shell /bin/bash "$test_user"
  echo "Created unprivileged test user: $test_user"
fi

if id -nG "$test_user" | tr ' ' '\n' | grep -qx sudo; then
  sudo deluser "$test_user" sudo >/dev/null 2>&1 || sudo gpasswd -d "$test_user" sudo >/dev/null 2>&1 || true
fi

sudo mkdir -p "$report_stage"
sudo chown "${test_user}:${runner_group}" "$report_stage"
sudo chmod 0775 "$report_stage"

sudo chown -R "$test_user:$test_user" "$workspace"

dir="$workspace"
while [[ "$dir" != / ]]; do
  if [[ -d "$dir" ]]; then
    sudo chmod o+x "$dir" 2>/dev/null || true
  fi
  dir="$(dirname "$dir")"
done

echo "Workspace owned by ${test_user} for portable tests"
echo "Artifact staging directory: ${report_stage} (${test_user}:${runner_group})"