#!/usr/bin/env bash
# Remove broad passwordless sudo; keep only the constrained portable-test launcher.
set -euo pipefail

run_user="$(whoami)"
launcher='/opt/ai370-ci/bin/ci-test-user-launcher'
sudoers_launcher='/etc/sudoers.d/ai370-portable-ci-launcher'

if ! sudo -n true 2>/dev/null; then
  echo 'Passwordless sudo already unavailable for job user'
  exit 0
fi

if [[ ! -x "$launcher" ]]; then
  echo '::error::Protected CI launcher missing; run ci-install-protected-helpers.sh first'
  exit 1
fi

test_user="$(grep -E '^AI370_CI_TEST_USER=' /opt/ai370-ci/config 2>/dev/null | head -n1 | cut -d= -f2- | tr -d "'\" ")"
test_user="${test_user:-ai370ci}"

sudo -n bash -s -- "$run_user" "$test_user" "$launcher" "$sudoers_launcher" <<'SUDO_DROP'
set -euo pipefail
run_user="$1"
test_user="$2"
launcher="$3"
sudoers_launcher="$4"

restore_if_invalid() {
  local file="$1"
  local backup="$2"
  if [[ "$file" == /etc/sudoers ]]; then
    if ! visudo -c >/dev/null 2>&1; then
      cp "$backup" "$file"
      return 1
    fi
    return 0
  fi
  if ! visudo -cf "$file" >/dev/null 2>&1; then
    cp "$backup" "$file"
    return 1
  fi
  return 0
}

while IFS= read -r sudoers_file; do
  [[ -n "$sudoers_file" && -f "$sudoers_file" ]] || continue
  [[ "$sudoers_file" == "$sudoers_launcher" ]] && continue
  if ! grep -qE "^${run_user}[[:space:]].*ALL=\\(ALL\\).*NOPASSWD" "$sudoers_file" 2>/dev/null \
    && ! grep -qE "^${run_user}[[:space:]]ALL=\\(ALL\\).*NOPASSWD" "$sudoers_file" 2>/dev/null; then
    continue
  fi
  backup="$(mktemp)"
  cp "$sudoers_file" "$backup"
  sed -i "/^${run_user}[[:space:]].*ALL=(ALL).*NOPASSWD/d" "$sudoers_file"
  if ! restore_if_invalid "$sudoers_file" "$backup"; then
    echo "::error::Refusing to keep invalid sudoers file ${sudoers_file}"
    exit 1
  fi
  rm -f "$backup"
  echo "Removed broad NOPASSWD rule for ${run_user} from ${sudoers_file}"
done < <(find /etc/sudoers /etc/sudoers.d -maxdepth 1 -type f 2>/dev/null || true)

cat >"$sudoers_launcher" <<EOF
# Managed by portable CI; allow only the test-user launcher.
Defaults!${launcher} env_keep += "AI370_CI_NO_HOST_MUTATION"
Defaults!${launcher} env_keep += "RUNNER_TEMP"
${run_user} ALL=(${test_user}) NOPASSWD: ${launcher}
EOF
chmod 0440 "$sudoers_launcher"
chown root:root "$sudoers_launcher"
if ! visudo -cf "$sudoers_launcher" >/dev/null 2>&1; then
  echo "::error::Failed to refresh portable CI launcher sudoers fragment"
  exit 1
fi
echo "Refreshed portable CI launcher sudoers for ${run_user}"
SUDO_DROP

if sudo -n true 2>/dev/null; then
  echo '::notice::Broad passwordless sudo remains on this image; tests still run only via the protected launcher'
else
  echo "Broad passwordless sudo revoked for ${run_user}"
fi

if ! sudo -n "$launcher" id -un >/dev/null 2>&1; then
  echo '::error::Constrained portable-test launcher is not usable after sudo drop'
  exit 1
fi

if [[ "$(sudo -n "$launcher" id -un)" != "$test_user" ]]; then
  echo "::error::Portable-test launcher did not execute as ${test_user}"
  exit 1
fi

echo "Constrained portable-test launcher verified for ${run_user}"