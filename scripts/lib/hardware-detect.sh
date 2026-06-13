#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

# Shared hardware and Ubuntu detection helpers for the AI370 optimizer phases.
# The functions in this file are intentionally best-effort: missing tools should
# be recorded as facts, not treated as fatal errors during inventory or planning.

set -euo pipefail

: "${TARGET_UBUNTU_VERSION:=26.04}"
: "${TARGET_UBUNTU_CODENAME:=resolute}"
: "${TARGET_UBUNTU_DESCRIPTION:=Ubuntu 26.04 LTS (Resolute Raccoon)}"

command_exists() { command -v "$1" >/dev/null 2>&1; }

run_or_empty() {
  local cmd="$1"
  shift || true
  if command_exists "$cmd"; then
    "$cmd" "$@" 2>/dev/null || true
  fi
}

run_sudo_or_empty() {
  local cmd="$1"
  shift || true
  if [[ "${EUID}" -eq 0 ]]; then
    run_or_empty "$cmd" "$@"
  elif command_exists sudo; then
    sudo -n "$cmd" "$@" 2>/dev/null || true
  fi
}

json_string() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

json_string_trimmed() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))'
}

json_number_or_zero() {
  python3 -c 'import sys; s=sys.stdin.read().strip(); print(s if s.isdigit() else 0)'
}

json_bool_for_command() {
  if command_exists "$1"; then
    printf 'true'
  else
    printf 'false'
  fi
}

collect_missing_tools() {
  local tools=(
    lsb_release lscpu free lspci lsblk lsmod fwupdmgr dmidecode
    powerprofilesctl sensors vulkaninfo clinfo nvme smartctl jq python3
  )
  local tool
  for tool in "${tools[@]}"; do
    if ! command_exists "$tool"; then
      printf '%s\n' "$tool"
    fi
  done
}

detect_cpu_model() { run_or_empty lscpu | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'; }
detect_cpu_vendor() { run_or_empty lscpu | awk -F: '/Vendor ID/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'; }
detect_cpu_logical() { run_or_empty lscpu | awk -F: '/^CPU\(s\)/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'; }
detect_cpu_governors() { if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]]; then cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; fi; }
detect_cpu_current_governor() { if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor; fi; }

detect_kernel() { uname -r 2>/dev/null || true; }
detect_os_description() { lsb_release -ds 2>/dev/null || { . /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}"; }; }
detect_os_id() { . /etc/os-release 2>/dev/null; echo "${ID:-unknown}"; }
detect_os_version_id() { . /etc/os-release 2>/dev/null; echo "${VERSION_ID:-unknown}"; }
detect_os_codename() { lsb_release -cs 2>/dev/null || { . /etc/os-release 2>/dev/null; echo "${VERSION_CODENAME:-unknown}"; }; }

detect_pci_text() { run_or_empty lspci -nnk; }
detect_gpu_text() { detect_pci_text | grep -Ei 'vga|display|3d|radeon|amd/ati' || true; }
detect_gpu_arch() {
  local gpu_text="${1:-$(detect_gpu_text)}"
  if printf '%s\n' "$gpu_text" | grep -Eiq '890M|Strix|gfx1150'; then
    printf 'gfx1150'
  else
    printf 'unknown'
  fi
}
detect_amdgpu_module() { run_or_empty lsmod | grep -E '^amdgpu\b' || true; }
detect_vulkan_summary() { run_or_empty vulkaninfo --summary; }
detect_opencl_summary() { run_or_empty clinfo | head -n 120 || true; }

detect_npu_module_text() { run_or_empty lsmod | grep -Ei 'amdxdna|xrt|xdna' || true; }
detect_npu_device_text() { find /dev -maxdepth 2 \( -name 'accel*' -o -name '*xdna*' -o -name '*xrt*' \) 2>/dev/null || true; }
detect_npu_present() {
  local module_text="${1:-$(detect_npu_module_text)}"
  local device_text="${2:-$(detect_npu_device_text)}"
  if [[ -n "$module_text" || -n "$device_text" ]]; then printf 'true'; else printf 'false'; fi
}

detect_memory_total() { run_or_empty free -h | awk '/^Mem:/ {print $2; exit}'; }
detect_memory_total_kib() { run_or_empty free -k | awk '/^Mem:/ {print $2; exit}'; }
detect_storage_text() { run_or_empty lsblk -dn -o NAME,MODEL,SIZE,TYPE; }
detect_nvme_text() { run_or_empty lsblk -dn -o NAME,MODEL,SIZE,TYPE | awk '$1 ~ /^nvme/ || $0 ~ /nvme|NVMe/ {print}'; }

detect_bios_version() { run_sudo_or_empty dmidecode -s bios-version; }
detect_bios_release_date() { run_sudo_or_empty dmidecode -s bios-release-date; }
detect_bios_vendor() { run_sudo_or_empty dmidecode -s bios-vendor; }
detect_system_product() { run_sudo_or_empty dmidecode -s system-product-name; }
detect_system_vendor() { run_sudo_or_empty dmidecode -s system-manufacturer; }
detect_fwupd_devices() { run_or_empty fwupdmgr get-devices; }

detect_powerprofiles() {
  if command_exists powerprofilesctl; then
    powerprofilesctl 2>/dev/null || true
  fi
}

capture_command() {
  local command_name="$1"
  shift || true
  if command -v "$command_name" >/dev/null 2>&1; then
    "$command_name" "$@" 2>&1 || true
  else
    echo "command-not-found: $command_name"
  fi
}
