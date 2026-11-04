#!/usr/bin/env bash
# Remove passwordless sudo for the current user before portable tests run.
# GitHub-hosted ubuntu-latest images grant the job user NOPASSWD via sudoers.d.
set -euo pipefail

run_user="$(whoami)"

if ! sudo -n true 2>/dev/null; then
  echo '::error::Expected passwordless sudo before dropping privileges'
  exit 1
fi

removed=0
shopt -s nullglob
for sudoers_file in "/etc/sudoers.d/${run_user}" /etc/sudoers.d/*"${run_user}"*; do
  if [[ -f "$sudoers_file" ]]; then
    sudo rm -f "$sudoers_file"
    echo "Removed sudoers drop-in: $sudoers_file"
    removed=1
  fi
done

# Some images grant NOPASSWD in a shared cloud-init drop-in.
for sudoers_file in /etc/sudoers.d/*; do
  [[ -f "$sudoers_file" ]] || continue
  if sudo grep -Eq "^${run_user}[[:space:]]+ALL=\\(ALL[^)]*\\)[[:space:]]+NOPASSWD" "$sudoers_file" 2>/dev/null; then
    sudo rm -f "$sudoers_file"
    echo "Removed NOPASSWD sudoers drop-in: $sudoers_file"
    removed=1
  fi
done

if (( removed == 0 )); then
  echo '::warning::No sudoers drop-in removed; verifying non-interactive sudo still fails'
fi

if sudo -n true 2>/dev/null; then
  echo '::error::Passwordless sudo is still available after hardening'
  exit 1
fi

echo "Passwordless sudo revoked for ${run_user}"
