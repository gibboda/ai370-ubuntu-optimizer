#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Compatibility S3-M7 aggregate: NPU reports into tier3-validation.json until
# s3-m7-runtime-validation.json exists. S2-M4 visibility is a separate report.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
VALIDATION_JSON="$LATEST_DIR/tier3-validation.json"
VALIDATION_MD="$LATEST_DIR/tier3-validation.md"

main() {
  mkdir -p "$LATEST_DIR"

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" \
  LATEST_DIR="$LATEST_DIR" \
  python3 - "$VALIDATION_JSON" "$VALIDATION_MD" <<'PY'
import datetime
import json
import os
import sys
from pathlib import Path

validation_json = Path(sys.argv[1])
validation_md = Path(sys.argv[2])
latest_dir = Path(os.environ["LATEST_DIR"])
profile = os.environ["PROFILE"]
mode = os.environ["MODE"]
offline = os.environ["OFFLINE"] == "true"

def load_json(name: str) -> dict:
    path = latest_dir / name
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return {}


def provider_tokens() -> tuple[str, ...]:
    return ("vitis", "vai", "ryzen", "xilinx", "amd", "xdna", "npu", "acl")


def has_amd_provider(providers: list[str]) -> bool:
    tokens = provider_tokens()
    return any(any(token in provider.lower() for token in tokens) for provider in providers)


npu_status = load_json("npu-acceleration-status.json")
vitis_status = load_json("vitis-ai-ep-status.json")
benchmark_status = load_json("npu-benchmark.json")

kernel_module = npu_status.get("kernel_module", "missing")
device_node = npu_status.get("device_node", "missing")
runtime_tools = npu_status.get("runtime_tools", "not-installed")
ort_providers_raw = npu_status.get("onnxruntime_providers", "unknown")

providers = list(vitis_status.get("providers") or [])
if not providers and isinstance(ort_providers_raw, str) and ort_providers_raw not in ("unknown", ""):
    providers = [item.strip() for item in ort_providers_raw.split(",") if item.strip()]

amd_candidates = list(vitis_status.get("amd_provider_candidates") or [])
if not amd_candidates and providers:
    amd_candidates = [provider for provider in providers if has_amd_provider([provider])]

npu_module_loaded = kernel_module == "loaded"
device_nodes_present = device_node == "present"
xrt_available = runtime_tools == "available"
onnx_runtime_present = vitis_status.get("onnxruntime_state") == "available" or (
    isinstance(ort_providers_raw, str)
    and ort_providers_raw not in ("unknown", "")
    and not ort_providers_raw.startswith("error")
    and not ort_providers_raw.startswith("missing")
)
npu_ep_visible = bool(amd_candidates) or vitis_status.get("provider_smoke") == "visible"
benchmarks = list(benchmark_status.get("benchmarks") or [])

def is_amd_npu_bench(bench: dict) -> bool:
    return has_amd_provider(
        [
            str(bench.get("requested_provider", "")),
            str(bench.get("actual_provider", "")),
        ]
    )

# Smoke "executed on NPU" only when an AMD EP run is verified (or legacy actual==requested).
npu_smoke_executed = any(
    is_amd_npu_bench(bench)
    and (
        (bench.get("ep_verified") and bench.get("ep_executed"))
        or (
            bench.get("ep_verified") is None
            and bench.get("actual_provider") == bench.get("requested_provider")
            and has_amd_provider([str(bench.get("actual_provider", ""))])
        )
    )
    for bench in benchmarks
)

vitis_pass = vitis_status.get("status") == "PASS"
benchmark_pass = benchmark_status.get("status") == "PASS"
# Require actual EP execution evidence, not merely a requested AMD provider name.
# Prefer explicit ep_verified/ep_executed from scripts/230-benchmark-npu.sh; fall back
# to actual_provider == requested_provider for older reports.
amd_benchmark_ran = any(
    (
        (
            bench.get("requested_provider") in amd_candidates
            or has_amd_provider([str(bench.get("requested_provider", ""))])
        )
        and (
            (bench.get("ep_verified") and bench.get("ep_executed"))
            or (
                bench.get("ep_verified") is None
                and bench.get("actual_provider") == bench.get("requested_provider")
                and has_amd_provider([str(bench.get("actual_provider", ""))])
            )
        )
    )
    for bench in benchmarks
)

if vitis_pass and benchmark_pass and amd_benchmark_ran:
    tier3_status = "PASS"
elif npu_module_loaded or device_nodes_present or npu_ep_visible:
    tier3_status = "EXPERIMENTAL-PASS"
else:
    tier3_status = "WARN"

timestamp = datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z")
data = {
    "tier": 3,
    "status": tier3_status,
    "timestamp": timestamp,
    "profile": profile,
    "mode": mode,
    "persistence": os.environ["PERSISTENCE"],
    "offline": offline,
    "acceptance": {
        "npu_module_loaded": npu_module_loaded,
        "device_nodes_present": device_nodes_present,
        "xrt_available": xrt_available,
        "onnx_runtime_present": onnx_runtime_present,
        "npu_ep_visible": npu_ep_visible,
        "npu_smoke_executed": npu_smoke_executed,
    },
    "artifacts": {
        "npu_status": "reports/latest/npu-acceleration-status.json",
        "vitis_ai_ep_status": "reports/latest/vitis-ai-ep-status.json",
        "npu_benchmark": "reports/latest/npu-benchmark.json",
        "xrt_status": "reports/latest/xrt-status.txt",
        "tier3_validation": "reports/latest/tier3-validation.json",
    },
    "source_reports": {
        "vitis_ai_ep_status": vitis_status.get("status", "missing"),
        "npu_benchmark_status": benchmark_status.get("status", "missing"),
    },
    "note": (
        "Stage 2 NPU validation is experimental until Vitis AI / Ryzen AI execution "
        "providers and NPU benchmarks pass. Stage AMD artifacts under "
        ".ai370-ai/amd-artifacts before running amd-accel-install."
    ),
}
validation_json.write_text(json.dumps(data, indent=2) + "\n")

md_lines = [
    "# Tier 3 NPU (Experimental) Validation",
    "",
    f"Status: {tier3_status} | Profile: {profile} | Offline: {offline}",
    f"Timestamp: {timestamp}",
    "",
    f"- NPU module: {'loaded' if npu_module_loaded else 'missing'}",
    f"- Device nodes: {'present' if device_nodes_present else 'missing'}",
    f"- XRT: {'available' if xrt_available else 'not-available'}",
    f"- ONNX providers: {', '.join(providers) if providers else 'none'}",
    f"- NPU EP visible: {str(npu_ep_visible).lower()}",
    f"- Smoke benchmark: {'executed' if npu_smoke_executed else 'skipped'}",
    "",
    "## Source reports",
    "",
    f"- vitis-ai-ep-status: {vitis_status.get('status', 'missing')}",
    f"- npu-benchmark: {benchmark_status.get('status', 'missing')}",
    "",
]
if tier3_status != "PASS":
    md_lines.extend([
        "WARNING: Full NPU enablement may require vendor Ryzen AI packages, "
        "a working XRT runtime, and Vitis AI ONNX Runtime execution providers.",
        "",
    ])
validation_md.write_text("\n".join(md_lines))
print(tier3_status)
PY

  echo "[INFO] Wrote $VALIDATION_JSON"
  echo "[INFO] Wrote $VALIDATION_MD"
  local status="WARN"
  if [[ -f "$VALIDATION_JSON" ]]; then
    status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status","WARN"))' "$VALIDATION_JSON" 2>/dev/null || echo WARN)"
  fi
  # EXPERIMENTAL-PASS / WARN / PASS are acceptable; only explicit FAIL is fatal.
  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"