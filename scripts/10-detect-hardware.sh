#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Compatibility wrapper. Use the canonical S1-M1 stage1-probe command.
#
# Delegates to s1-m1-probe-system.sh for the raw probe, then publishes the
# legacy artifacts that downstream callers (90-validate.sh, smoke_tier1.sh,
# profile consumers) still expect:
#   tier1-hardware.json, tier1-hardware.md, hardware-inventory.json,
#   hardware-summary.md, system-profile.json, tier1-npu.*
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"

echo "[WARN] 10-detect-hardware.sh is deprecated; use ./ai370-optimize.sh stage1-probe" >&2

# Strip legacy positional args (PROFILE MODE PERSISTENCE) before forwarding.
PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
if (($#)) && [[ "$1" != --* ]]; then
  shift "$(( $# < 3 ? $# : 3 ))"
fi

# --- Run the canonical S1-M1 probe ---
export PROFILE MODE PERSISTENCE
bash "$SCRIPT_DIR/s1-m1-probe-system.sh" "$@"

# --- Publish legacy artifacts from the raw inventory ---
RAW="$LATEST_DIR/s1-m1-raw-inventory.json"

# tier1-hardware.json (copy of the canonical raw inventory)
cp "$RAW" "$LATEST_DIR/tier1-hardware.json"
cp "$RAW" "$LATEST_DIR/hardware-inventory.json"

# tier1-hardware.md – human-readable summary
python3 - "$RAW" > "$LATEST_DIR/tier1-hardware.md" <<'PYSUMMARY'
import json, sys
from pathlib import Path
raw = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
def value(probe):
    return probe.get("value") if isinstance(probe, dict) and probe.get("state") == "observed" else None
system = raw.get("dmi", {}).get("system", {})
board = raw.get("dmi", {}).get("motherboard", raw.get("dmi", {}).get("board", {}))
firmware = raw.get("firmware", {})
cpu = raw.get("cpu", {})
os_info = raw.get("os", {})
kernel = raw.get("kernel", {})
gpu = raw.get("gpu", {})
accel = raw.get("accelerators", {})
memory = raw.get("memory", {})
storage = raw.get("storage", {})
collection = raw.get("collection", {})
inputs = raw.get("inputs", {})
print("# Stage 1 Hardware Detection")
print()
print(f"**Profile:** {inputs.get('profile', 'unknown')} | **Mode:** {inputs.get('mode', 'unknown')} | **Persistence:** {inputs.get('persistence', 'unknown')}")
print()
print("## System facts")
print(f"- System: {value(system.get('vendor')) or 'unknown'} {value(system.get('product')) or 'unknown'} ({value(system.get('version')) or 'unknown version'})")
print(f"- Board: {value(board.get('vendor')) or 'unknown'} {value(board.get('product')) or 'unknown'} ({value(board.get('version')) or 'unknown version'})")
print(f"- BIOS: {value(firmware.get('bios_vendor')) or 'unknown'} {value(firmware.get('bios_version')) or 'unknown'} ({value(firmware.get('bios_date')) or 'unknown date'})")
print(f"- OS: {os_info.get('pretty_name') or 'unknown'} ({os_info.get('version_id') or 'unknown'} / {os_info.get('version_codename') or 'unknown'})")
print(f"- Kernel: {kernel.get('release') or 'unknown'} ({kernel.get('architecture') or 'unknown arch'})")
print(f"- Secure Boot: {firmware.get('secure_boot', {}).get('state', 'unknown')} enabled={firmware.get('secure_boot', {}).get('enabled')}")
print()
print("## CPU")
print(f"- Model string: {cpu.get('model_name') or 'unknown'}")
print(f"- Vendor/family/model/stepping: {cpu.get('vendor_id') or 'unknown'} / {cpu.get('family') or 'unknown'} / {cpu.get('model') or 'unknown'} / {cpu.get('stepping') or 'unknown'}")
print(f"- Topology: {cpu.get('topology', {})}")
print()
print("## PCI / GPU / accelerators")
print(f"- PCI probe state: {raw.get('pci', {}).get('state', 'unknown')} ({len(raw.get('pci', {}).get('devices', []))} devices)")
print(f"- GPU state: {gpu.get('state', 'unknown')} architecture={gpu.get('architecture', {}).get('value') or 'unknown'}")
print(f"- Accelerator state: {accel.get('state', 'unknown')} nodes={[n.get('path') for n in accel.get('device_nodes', [])]}")
print()
print("## Memory / Storage")
print(f"- Memory total bytes: {memory.get('total_bytes')}")
print(f"- Storage probe state: {storage.get('state', 'unknown')} ({len(storage.get('devices', []))} devices)")
print()
print("## Probe health")
print("- Missing tools: " + (", ".join(collection.get("missing_tools", [])) or "none"))
print(f"- Failed probes: {len(collection.get('failed_probes', []))}")
print(f"- Permission errors: {len(collection.get('permission_errors', []))}")
PYSUMMARY

cp "$LATEST_DIR/tier1-hardware.md" "$LATEST_DIR/hardware-summary.md"

# system-profile.json
generator_version="unknown"
if [[ -f "$PROJECT_ROOT/VERSION" ]]; then
  generator_version="$(tr -d '[:space:]' < "$PROJECT_ROOT/VERSION")"
fi
python3 "$PROJECT_ROOT/scripts/lib/system_profile.py" \
  --input "$RAW" \
  --output "$LATEST_DIR/system-profile.json" \
  --generator-version "$generator_version"

# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

# tier1-npu.* artifacts
eval "$(python3 - "$RAW" <<'PYNPUENV'
import json, shlex, sys
from pathlib import Path
raw = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
accel = raw.get("accelerators", {})
nodes = "\n".join(node.get("path", "") for node in accel.get("device_nodes", []))
drivers = sorted({d.get("bound_driver") for d in accel.get("devices", []) if d.get("bound_driver")})
present = accel.get("state") == "observed"
for name, value in {"NPU_PRESENT": "true" if present else "false", "NPU_MODULE": "\n".join(drivers), "NPU_DEVICE": nodes}.items():
    print(f"{name}={shlex.quote(value)}")
PYNPUENV
)"

xrt_smi="$(capture_command xrt-smi examine)"
if [[ "$xrt_smi" == command-not-found:* ]]; then xrt_state="missing"; else xrt_state="available"; fi
npu_status="PASS"
if [[ "$NPU_PRESENT" != "true" ]]; then npu_status="WARN"; fi

export PROFILE MODE PERSISTENCE NPU_MODULE NPU_DEVICE NPU_PRESENT xrt_state xrt_smi npu_status
python3 - <<'PY' > "$LATEST_DIR/tier1-npu.json"
import json, os
from datetime import datetime, UTC
print(json.dumps({
    "tier": 1, "phase": "detect-npu",
    "timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
    "profile": os.environ.get("PROFILE", "ai370"),
    "mode": os.environ.get("MODE", "safe"),
    "persistence": os.environ.get("PERSISTENCE", "runtime"),
    "offline": False, "status": os.environ.get("npu_status", "WARN"),
    "amdxdna": {"present": os.environ.get("NPU_PRESENT", "false").lower() == "true",
                "module_text": os.environ.get("NPU_MODULE", ""),
                "device_text": os.environ.get("NPU_DEVICE", "")},
    "xrt": {"state": os.environ.get("xrt_state", "missing"),
            "examine_output": os.environ.get("xrt_smi", "")},
    "note": "NPU detection is part of 10-detect-hardware.sh (Package C).",
    "source_script": "scripts/10-detect-hardware.sh",
}, indent=2))
PY

{
  echo "# Tier 1 AMDXDNA / NPU Detection"
  echo; echo "**Status:** $npu_status"; echo
  echo "- AMDXDNA/XDNA present: $NPU_PRESENT"
  echo "- XRT tools: $xrt_state"; echo
  echo "## Kernel module evidence"
  printf '%s\n' "${NPU_MODULE:-none detected}"; echo
  echo "## Device node evidence"
  printf '%s\n' "${NPU_DEVICE:-none detected}"; echo
  echo "Emitted by scripts/10-detect-hardware.sh (Package C fold of 75-detect-npu)."
} > "$LATEST_DIR/tier1-npu.md"
echo "$npu_status" > "$LATEST_DIR/tier1-npu.txt"

echo "[INFO] Wrote tier1-hardware.json, tier1-hardware.md, system-profile.json, and tier1-npu.*"
echo "[INFO] 10-detect-hardware.sh complete."
