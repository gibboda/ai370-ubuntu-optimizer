#!/usr/bin/env bash
# Best-effort removal of passwordless sudo for the workflow user before portable tests.
# Primary isolation is ci-as-test-user.sh; this reduces accidental sudo use while preparing the job.
set -euo pipefail

run_user="$(whoami)"

if ! sudo -n true 2>/dev/null; then
  echo 'Passwordless sudo already unavailable for job user'
  exit 0
fi

removed=0

while IFS= read -r sudoers_file; do
  [[ -n "$sudoers_file" && -f "$sudoers_file" ]] || continue
  if sudo grep -qE "(^|[[:space:]])${run_user}[[:space:]].*NOPASSWD" "$sudoers_file" 2>/dev/null; then
    backup="$(mktemp)"
    sudo cp "$sudoers_file" "$backup"
    sudo sed -i "/^${run_user}[[:space:]].*NOPASSWD/d" "$sudoers_file"
    if sudo visudo -cf "$sudoers_file" >/dev/null 2>&1 || [[ "$sudoers_file" == /etc/sudoers ]]; then
      if [[ "$sudoers_file" == /etc/sudoers ]] && ! sudo visudo -c >/dev/null 2>&1; then
        sudo cp "$backup" "$sudoers_file"
      else
        echo "Removed NOPASSWD rule for ${run_user} from ${sudoers_file}"
        removed=1
      fi
    else
      sudo cp "$backup" "$sudoers_file"
    fi
    rm -f "$backup"
  fi
done < <(sudo grep -lE "(^|[[:space:]])${run_user}[[:space:]].*NOPASSWD" /etc/sudoers /etc/sudoers.d/* 2>/dev/null || true)

if id -nG "$run_user" | tr ' ' '\n' | grep -qx sudo; then
  if sudo deluser "$run_user" sudo >/dev/null 2>&1 || sudo gpasswd -d "$run_user" sudo >/dev/null 2>&1; then
    echo "Removed ${run_user} from sudo group"
    removed=1
  fi
fi

if (( removed == 0 )); then
  echo '::notice::Could not revoke job-user sudo; portable tests run as unprivileged ai370ci'
fi

if sudo -n true 2>/dev/null; then
  echo '::notice::Job user retains passwordless sudo; test steps use unprivileged ai370ci'
else
  echo "Passwordless sudo revoked for ${run_user}"
fi
