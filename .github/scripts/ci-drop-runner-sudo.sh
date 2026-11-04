#!/usr/bin/env bash
# Remove passwordless sudo for the current user before portable tests run.
# GitHub-hosted ubuntu-latest images grant the job user NOPASSWD via sudoers.d
# and/or membership in the sudo group.
set -euo pipefail

run_user="$(whoami)"

if ! sudo -n true 2>/dev/null; then
  echo '::error::Expected passwordless sudo before dropping privileges'
  exit 1
fi

removed=0

shopt -s nullglob
for sudoers_file in /etc/sudoers.d/*; do
  [[ -f "$sudoers_file" ]] || continue
  if sudo grep -qE "(^|[[:space:]])${run_user}[[:space:]]" "$sudoers_file" 2>/dev/null \
    && sudo grep -q 'NOPASSWD' "$sudoers_file" 2>/dev/null; then
    sudo rm -f "$sudoers_file"
    echo "Removed NOPASSWD sudoers drop-in: $sudoers_file"
    removed=1
  fi
done

# Image builds may grant passwordless sudo to %sudo instead of a per-user file.
for sudoers_file in /etc/sudoers /etc/sudoers.d/*; do
  [[ -f "$sudoers_file" ]] || continue
  if sudo grep -qE '^%sudo[[:space:]].*NOPASSWD' "$sudoers_file" 2>/dev/null; then
    if id -nG "$run_user" | tr ' ' '\n' | grep -qx sudo; then
      if sudo deluser "$run_user" sudo >/dev/null 2>&1 || sudo gpasswd -d "$run_user" sudo >/dev/null 2>&1; then
        echo "Removed ${run_user} from sudo group (${sudoers_file} grants %sudo NOPASSWD)"
        removed=1
      fi
    fi
  fi
done

if id -nG "$run_user" | tr ' ' '\n' | grep -qx sudo; then
  if sudo deluser "$run_user" sudo >/dev/null 2>&1 || sudo gpasswd -d "$run_user" sudo >/dev/null 2>&1; then
    echo "Removed ${run_user} from sudo group"
    removed=1
  fi
fi

if (( removed == 0 )); then
  echo '::warning::No sudoers drop-in or sudo group membership removed'
fi

if sudo -n true 2>/dev/null; then
  echo '::error::Passwordless sudo is still available after hardening'
  echo '::group::sudo -l'
  sudo -l || true
  echo '::endgroup::'
  echo '::group::/etc/sudoers.d'
  ls -la /etc/sudoers.d || true
  sudo cat /etc/sudoers.d/README 2>/dev/null || true
  echo '::endgroup::'
  exit 1
fi

echo "Passwordless sudo revoked for ${run_user}"
