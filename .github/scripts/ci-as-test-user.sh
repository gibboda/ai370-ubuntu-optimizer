#!/usr/bin/env bash
# Run a command as the unprivileged portable-test user (no passwordless sudo).
set -euo pipefail

test_user="${AI370_CI_TEST_USER:-ai370ci}"
workspace="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"

if [[ "$#" -lt 1 ]]; then
  echo 'usage: ci-as-test-user.sh command [args...]' >&2
  exit 2
fi

if ! id "$test_user" >/dev/null 2>&1; then
  echo '::error::Portable test user missing; run ci-prepare-portable-test-user.sh first'
  exit 1
fi

exec sudo -u "$test_user" -H env \
  AI370_CI_NO_HOST_MUTATION="${AI370_CI_NO_HOST_MUTATION:-}" \
  RUNNER_TEMP="${RUNNER_TEMP:-}" \
  HOME="$(eval echo "~$test_user")" \
  bash -lc "cd \"${workspace}\" && exec \"\$@\"" -- "$@"
