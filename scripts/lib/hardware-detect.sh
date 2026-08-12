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

detect_bios_version() {
  if [[ -r /sys/class/dmi/id/bios_version ]]; then
    cat /sys/class/dmi/id/bios_version
  else
    run_sudo_or_empty dmidecode -s bios-version
  fi
}
detect_bios_release_date() {
  if [[ -r /sys/class/dmi/id/bios_date ]]; then
    cat /sys/class/dmi/id/bios_date
  else
    run_sudo_or_empty dmidecode -s bios-release-date
  fi
}
detect_bios_vendor() {
  if [[ -r /sys/class/dmi/id/bios_vendor ]]; then
    cat /sys/class/dmi/id/bios_vendor
  else
    run_sudo_or_empty dmidecode -s bios-vendor
  fi
}
detect_system_product() {
  if [[ -r /sys/class/dmi/id/product_name ]]; then
    cat /sys/class/dmi/id/product_name
  else
    run_sudo_or_empty dmidecode -s system-product-name
  fi
}
detect_system_vendor() {
  if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
    cat /sys/class/dmi/id/sys_vendor
  else
    run_sudo_or_empty dmidecode -s system-manufacturer
  fi
}
detect_fwupd_devices() { run_or_empty fwupdmgr get-devices; }

detect_powerprofiles() {
  if command_exists powerprofilesctl; then
    powerprofilesctl 2>/dev/null || true
  fi
}

collect_stage1_raw_probes() {
  python3 - "$@" <<'PYRAW'
import glob
import json
import os
import platform
import shutil
import subprocess
from datetime import UTC, datetime
from pathlib import Path


def read_file(path):
    probe = {"source": path, "state": "unknown", "value": None, "error": None}
    candidate = Path(path)
    if not candidate.exists():
        probe["state"] = "not_present"
        probe["error"] = {"code": "not_found", "message": f"{path} does not exist"}
        return probe
    if not os.access(candidate, os.R_OK):
        probe["state"] = "permission_denied"
        probe["error"] = {"code": "permission_denied", "message": f"{path} is not readable"}
        return probe
    try:
        value = candidate.read_text(encoding="utf-8", errors="replace").strip()
        probe["state"] = "observed" if value else "unknown"
        probe["value"] = value
    except OSError as exc:
        probe["state"] = "probe_failed"
        probe["error"] = {"code": exc.__class__.__name__, "message": str(exc)}
    return probe


def run_probe(probe_id, argv):
    tool = argv[0]
    path = shutil.which(tool)
    probe = {"id": probe_id, "source": "command", "argv": argv, "tool": tool,
             "tool_path": path, "state": "unknown", "stdout": "", "stderr": "", "returncode": None,
             "error": None}
    if path is None:
        probe["state"] = "tool_missing"
        probe["error"] = {"code": "not_found", "message": f"{tool} was not found in PATH"}
        return probe
    completed = subprocess.run(argv, text=True, capture_output=True, check=False)
    probe["stdout"] = completed.stdout
    probe["stderr"] = completed.stderr
    probe["returncode"] = completed.returncode
    probe["state"] = "observed" if completed.returncode == 0 else "probe_failed"
    if completed.returncode != 0:
        probe["error"] = {"code": "nonzero_exit", "message": f"{tool} exited with {completed.returncode}"}
    return probe


def int_value(value):
    return int(value) if str(value or "").isdigit() else None


def parse_lscpu(text):
    facts = {}
    for line in text.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            facts[key.strip()] = value.strip()
    return {"vendor_id": facts.get("Vendor ID"), "family": facts.get("CPU family"),
            "model": facts.get("Model"), "stepping": facts.get("Stepping"),
            "model_name": facts.get("Model name"), "architecture": facts.get("Architecture"),
            "topology": {"logical_processors": int_value(facts.get("CPU(s)")),
                         "sockets": int_value(facts.get("Socket(s)")),
                         "cores_per_socket": int_value(facts.get("Core(s) per socket")),
                         "threads_per_core": int_value(facts.get("Thread(s) per core"))}}


def bracket_id(value):
    if not value:
        return None
    if "[" in value and "]" in value:
        return value.rsplit("[", 1)[1].split("]", 1)[0]
    return None


def parse_lspci_mm(text):
    devices, current = [], {}
    for line in text.splitlines() + [""]:
        if not line.strip():
            if current:
                devices.append(current)
                current = {}
            continue
        key, _, value = line.partition("\t")
        current[key.rstrip(":")] = value.strip()
    return [{"slot": d.get("Slot"), "class": d.get("Class"), "vendor_id": bracket_id(d.get("Vendor")),
             "device_id": bracket_id(d.get("Device")), "subsystem_vendor_id": bracket_id(d.get("SVendor")),
             "subsystem_device_id": bracket_id(d.get("SDevice")), "vendor_name": d.get("Vendor"),
             "device_name": d.get("Device"), "bound_driver": d.get("Driver"),
             "modules": d.get("Module", "").split() if d.get("Module") else []} for d in devices]


def os_release():
    values, probe = {}, read_file("/etc/os-release")
    if probe["state"] == "observed":
        for line in probe["value"].splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                values[key] = value.strip().strip('"')
    return values, probe


def meminfo_total():
    probe = read_file("/proc/meminfo")
    total = None
    if probe["state"] == "observed":
        for line in probe["value"].splitlines():
            if line.startswith("MemTotal:"):
                total = int(line.split()[1]) * 1024
                break
    return total, probe


lscpu = run_probe("cpu.lscpu", ["lscpu"])
lspci = run_probe("pci.lspci", ["lspci", "-D", "-nn", "-vmm", "-k"])
lsblk = run_probe("storage.lsblk", ["lsblk", "-J", "-b", "-O"])
lsmod = run_probe("kernel_modules.lsmod", ["lsmod"])
os_values, os_probe = os_release()
mem_total, mem_probe = meminfo_total()
dmi_paths = {"system_vendor": "/sys/class/dmi/id/sys_vendor", "system_product": "/sys/class/dmi/id/product_name", "system_version": "/sys/class/dmi/id/product_version", "board_vendor": "/sys/class/dmi/id/board_vendor", "board_product": "/sys/class/dmi/id/board_name", "board_version": "/sys/class/dmi/id/board_version", "bios_vendor": "/sys/class/dmi/id/bios_vendor", "bios_version": "/sys/class/dmi/id/bios_version", "bios_date": "/sys/class/dmi/id/bios_date"}
dmi = {name: read_file(path) for name, path in dmi_paths.items()}
dev_nodes = sorted(glob.glob("/dev/accel/*") + glob.glob("/dev/*xdna*") + glob.glob("/dev/*xrt*"))
missing_tools = [name for name in ("lsb_release", "lscpu", "free", "lspci", "lsblk", "lsmod", "fwupdmgr", "dmidecode", "mokutil", "powerprofilesctl", "sensors", "vulkaninfo", "clinfo", "nvme", "smartctl", "jq", "python3") if shutil.which(name) is None]
pci_devices = parse_lspci_mm(lspci["stdout"]) if lspci["state"] == "observed" else []
gpus = [d for d in pci_devices if d.get("class") and any(token in d["class"].lower() for token in ("vga", "display", "3d"))]
accelerators = [d for d in pci_devices if d.get("class") and "processing accelerators" in d["class"].lower()]
secure_boot_probe = run_probe("secure_boot.mokutil", ["mokutil", "--sb-state"])
secure_boot_enabled = None
if secure_boot_probe["state"] == "observed":
    secure_boot_enabled = "enabled" in secure_boot_probe["stdout"].lower()
raw = {"schema_version": 1, "stage": 1, "milestone": "S1-M1", "artifact": "s1-m1-raw-inventory", "timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"), "inputs": {"profile": os.environ.get("PROFILE", "unknown"), "mode": os.environ.get("MODE", "unknown"), "persistence": os.environ.get("PERSISTENCE", "unknown")}, "cpu": {"state": lscpu["state"], "evidence_source": "lscpu", **parse_lscpu(lscpu["stdout"])}, "dmi": {"system": {"vendor": dmi["system_vendor"], "product": dmi["system_product"], "version": dmi["system_version"]}, "motherboard": {"vendor": dmi["board_vendor"], "product": dmi["board_product"], "version": dmi["board_version"]}}, "pci": {"state": lspci["state"], "evidence_source": "lspci -Dnnmmk", "devices": pci_devices}, "gpu": {"state": "observed" if gpus else ("tool_missing" if lspci["state"] == "tool_missing" else "not_present"), "devices": gpus, "architecture": {"state": "unknown", "value": None, "evidence_source": None, "error": {"code": "not_authoritative", "message": "No authoritative GPU architecture probe was available in Stage 1"}}}, "accelerators": {"state": "observed" if accelerators else ("unknown" if dev_nodes else "not_present"), "devices": accelerators, "device_nodes": [{"path": n, "state": "observed" if accelerators else "unrecognized", "evidence_source": "filesystem glob"} for n in dev_nodes]}, "memory": {"state": "observed" if mem_total is not None else mem_probe["state"], "total_bytes": mem_total, "evidence_source": "/proc/meminfo"}, "storage": {"state": lsblk["state"], "evidence_source": "lsblk -J -b -O", "devices": json.loads(lsblk["stdout"]).get("blockdevices", []) if lsblk["state"] == "observed" else []}, "os": {"state": os_probe["state"], "id": os_values.get("ID"), "name": os_values.get("NAME"), "pretty_name": os_values.get("PRETTY_NAME"), "version_id": os_values.get("VERSION_ID"), "version_codename": os_values.get("VERSION_CODENAME"), "evidence_source": "/etc/os-release"}, "kernel": {"state": "observed", "release": platform.release(), "architecture": platform.machine(), "evidence_source": "uname"}, "firmware": {"bios_vendor": dmi["bios_vendor"], "bios_version": dmi["bios_version"], "bios_date": dmi["bios_date"], "uefi": {"state": "observed" if Path("/sys/firmware/efi").exists() else "not_present", "evidence_source": "/sys/firmware/efi"}, "secure_boot": {"state": secure_boot_probe["state"], "enabled": secure_boot_enabled, "evidence_source": "mokutil --sb-state", "probe": secure_boot_probe}}, "collection": {"missing_tools": missing_tools, "permission_errors": [], "failed_probes": [], "probes": [lscpu, lspci, lsblk, lsmod, os_probe, mem_probe, secure_boot_probe, *dmi.values()]}}
for probe in raw["collection"]["probes"]:
    if probe.get("state") == "permission_denied": raw["collection"]["permission_errors"].append(probe)
    if probe.get("state") == "probe_failed": raw["collection"]["failed_probes"].append(probe)
print(json.dumps(raw, indent=2))
PYRAW
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
