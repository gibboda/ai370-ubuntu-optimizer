#!/usr/bin/env bash
# Best-effort removal of broad passwordless sudo before portable tests.
# Primary isolation is unprivileged ai370ci via protected /opt/ai370-ci helpers.
set -euo pipefail

run_user="$(whoami)"

if ! sudo -n true 2>/dev/null; then
  echo 'Passwordless sudo already unavailable for job user'
  exit 0
fi

removed=0

sudo -n bash -s -- "$run_user" <<'SUDO_DROP' || true
set -euo pipefail
run_user="$1"
while IFS= read -r sudoers_file; do
  [[ -n "$sudoers_file" && -f "$sudoers_file" ]] || continue
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
SUDO_DROP

if sudo -n true 2>/dev/null; then
  echo '::notice::Broad passwordless sudo may remain; tests run as ai370ci via protected helpers'
else
  echo "Broad passwordless sudo revoked for ${run_user}"
  removed=1
fi

if ! sudo -n -u ai370ci true 2>/dev/null; then
  if ! id ai370ci >/dev/null 2>&1; then
    echo '::notice::ai370ci not created yet; identity switch checked after prepare'
    exit 0
  fi
  echo '::warning::Unable to switch to ai370ci with passwordless sudo on this image'
fi

if (( removed == 0 )); then
  echo '::notice::No broad NOPASSWD rule removed'
fi