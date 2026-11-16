#!/usr/bin/env bash
# Snapshot and verify stable host tuning state on GitHub Actions runners.
# Used by the Portable tests workflow to detect accidental host mutation.
set -euo pipefail

usage() {
  echo "usage: $0 snapshot|verify CANARY_PATH" >&2
  exit 2
}

mode="${1:-}"
canary_path="${2:-}"
if [[ -z "$mode" || -z "$canary_path" ]]; then
  usage
fi

# Keys that should remain stable for the duration of portable tests.
# Exclude counters, randomness, and time-driven kernel state.
readonly -a STABLE_SYSCTL_KEYS=(
  kernel.yama.ptrace_scope
  kernel.kptr_restrict
  kernel.dmesg_restrict
  vm.swappiness
  vm.max_map_count
  vm.overcommit_memory
  net.ipv4.ip_forward
  net.ipv4.conf.all.rp_filter
  net.ipv4.conf.default.rp_filter
  net.ipv4.tcp_syncookies
)

collect_canary() {
  local key value
  echo '=== sysctl-stable ==='
  for key in "${STABLE_SYSCTL_KEYS[@]}"; do
    if value="$(sysctl -n "$key" 2>/dev/null)"; then
      printf '%s=%s\n' "$key" "$value"
    else
      printf '%s=unavailable\n' "$key"
    fi
  done

  echo '=== power-profile ==='
  if command -v powerprofilesctl >/dev/null 2>&1; then
    powerprofilesctl get 2>/dev/null || echo 'powerprofilesctl-get-unavailable'
  else
    echo 'powerprofilesctl-missing'
  fi

  echo '=== cpufreq-governor ==='
  if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
  else
    echo 'cpufreq-governor-missing'
  fi
}

case "$mode" in
  snapshot)
    collect_canary >"$canary_path"
    echo "Wrote host drift canary to $canary_path"
    ;;
  verify)
    if [[ ! -f "$canary_path" ]]; then
      echo "::error::Missing drift canary snapshot at $canary_path"
      exit 1
    fi
    current="$(mktemp)"
    trap 'rm -f "$current"' EXIT
    collect_canary >"$current"
    if ! diff -u "$canary_path" "$current"; then
      echo '::error::CI host drift canary detected changes to stable host tuning state'
      exit 1
    fi
    echo 'CI host drift canary unchanged'
    ;;
  *)
    usage
    ;;
esac
