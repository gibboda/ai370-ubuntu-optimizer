#!/usr/bin/env bash
# Remove passwordless sudo for the current user before portable tests run.
# GitHub-hosted ubuntu-latest images grant runner NOPASSWD in /etc/sudoers and/or sudoers.d.
set -euo pipefail

run_user="$(whoami)"

if ! sudo -n true 2>/dev/null; then
  echo '::error::Expected passwordless sudo before dropping privileges'
  exit 1
fi

removed=0

if sudo grep -qE "^${run_user}[[:space:]].*NOPASSWD" /etc/sudoers 2>/dev/null; then
  backup="$(mktemp)"
  sudo cp /etc/sudoers "$backup"
  sudo sed -i "/^${run_user}[[:space:]].*NOPASSWD/d" /etc/sudoers
  if ! sudo visudo -c >/dev/null 2>&1; then
    sudo cp "$backup" /etc/sudoers
    rm -f "$backup"
    echo '::error::visudo rejected /etc/sudoers edit while revoking runner sudo'
    exit 1
  fi
  rm -f "$backup"
  echo "Removed NOPASSWD rule for ${run_user} from /etc/sudoers"
  removed=1
fi

while IFS= read -r -d '' sudoers_file; do
  [[ -f "$sudoers_file" ]] || continue
  if sudo grep -qE "(^|[[:space:]])${run_user}[[:space:]]" "$sudoers_file" 2>/dev/null \
    && sudo grep -q 'NOPASSWD' "$sudoers_file" 2>/dev/null; then
    sudo rm -f "$sudoers_file"
    echo "Removed NOPASSWD sudoers drop-in: $sudoers_file"
    removed=1
  fi
done < <(sudo find /etc/sudoers.d -maxdepth 1 -type f -print0 2>/dev/null || true)

if id -nG "$run_user" | tr ' ' '\n' | grep -qx sudo; then
  if sudo deluser "$run_user" sudo >/dev/null 2>&1 || sudo gpasswd -d "$run_user" sudo >/dev/null 2>&1; then
    echo "Removed ${run_user} from sudo group"
    removed=1
  fi
fi

if (( removed == 0 )); then
  echo '::warning::No sudo rule or sudo group membership removed'
fi

if sudo -n true 2>/dev/null; then
  echo '::error::Passwordless sudo is still available after hardening'
  echo '::group::sudo -l'
  sudo -l || true
  echo '::endgroup::'
  exit 1
fi

echo "Passwordless sudo revoked for ${run_user}"
