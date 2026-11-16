#!/usr/bin/env bash
# Best-effort removal of broad passwordless sudo before portable tests.
# Preserves narrow run-as-ai370ci sudoers managed by ci-install-protected-helpers.sh.
set -euo pipefail

run_user="$(whoami)"
runas_sudoers='/etc/sudoers.d/ai370-portable-ci-runas'
test_user="$(grep -E '^AI370_CI_TEST_USER=' /opt/ai370-ci/config 2>/dev/null | head -n1 | cut -d= -f2- | tr -d "'\" ")"
test_user="${test_user:-ai370ci}"

if ! sudo -n true 2>/dev/null; then
  echo 'Passwordless sudo already unavailable for job user'
  exit 0
fi

sudo -n bash -s -- "$run_user" "$test_user" "$runas_sudoers" <<'SUDO_DROP'
set -euo pipefail
run_user="$1"
test_user="$2"
runas_sudoers="$3"
while IFS= read -r sudoers_file; do
  [[ -n "$sudoers_file" && -f "$sudoers_file" ]] || continue
  [[ "$sudoers_file" == "$runas_sudoers" ]] && continue
  if ! grep -qE "^${run_user}[[:space:]].*ALL=\\(ALL\\).*NOPASSWD" "$sudoers_file" 2>/dev/null; then
    continue
  fi
  backup="$(mktemp)"
  cp "$sudoers_file" "$backup"
  sed -i "/^${run_user}[[:space:]].*ALL=(ALL).*NOPASSWD/d" "$sudoers_file"
  if [[ "$sudoers_file" == /etc/sudoers ]]; then
    visudo -c >/dev/null 2>&1 || cp "$backup" "$sudoers_file"
  else
    visudo -cf "$sudoers_file" >/dev/null 2>&1 || cp "$backup" "$sudoers_file"
  fi
  rm -f "$backup"
  echo "Removed broad NOPASSWD rule for ${run_user} from ${sudoers_file}"
done < <(find /etc/sudoers /etc/sudoers.d -maxdepth 1 -type f 2>/dev/null || true)

cat >"$runas_sudoers" <<EOF
# Managed by portable CI; job user may run only as ${test_user} without a password.
${run_user} ALL=(${test_user}) NOPASSWD: ALL
EOF
chmod 0440 "$runas_sudoers"
chown root:root "$runas_sudoers"
visudo -cf "$runas_sudoers" >/dev/null
SUDO_DROP

if sudo -n true 2>/dev/null; then
  echo '::notice::Broad passwordless sudo may remain alongside run-as sudo'
else
  echo "Broad passwordless sudo revoked for ${run_user}"
fi

if ! sudo -n -u "$test_user" id -un >/dev/null 2>&1; then
  echo "::error::Passwordless run-as ${test_user} is not available for portable tests"
  exit 1
fi

if [[ "$(sudo -n -u "$test_user" id -un)" != "$test_user" ]]; then
  echo "::error::Run-as wrapper did not execute as ${test_user}"
  exit 1
fi

echo "Constrained run-as ${test_user} sudo verified for ${run_user}"