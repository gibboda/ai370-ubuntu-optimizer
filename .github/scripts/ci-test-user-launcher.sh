#!/usr/bin/env bash
# Run one command as the unprivileged portable-test user (invoked via sudoers only).
set -euo pipefail

config_path='/opt/ai370-ci/config'
test_user='ai370ci'

if [[ "$(id -un)" != "$test_user" ]]; then
  echo "::error::ci-test-user-launcher must run as ${test_user}, not $(id -un)"
  exit 1
fi

if [[ ! -r "$config_path" ]]; then
  echo "::error::Missing protected CI config at ${config_path}"
  exit 1
fi

# shellcheck source=/dev/null
source "$config_path"

workspace="${GITHUB_WORKSPACE:-}"
if [[ -z "$workspace" || ! -d "$workspace" ]]; then
  echo "::error::Portable test workspace is missing"
  exit 1
fi

if [[ "$#" -lt 1 ]]; then
  echo 'usage: ci-test-user-launcher command [args...]' >&2
  exit 2
fi

export AI370_CI_NO_HOST_MUTATION="${AI370_CI_NO_HOST_MUTATION:-}"
export RUNNER_TEMP="${RUNNER_TEMP:-}"
export HOME
HOME="$(eval echo "~${test_user}")"

cd "$workspace" || exit 1
exec "$@"