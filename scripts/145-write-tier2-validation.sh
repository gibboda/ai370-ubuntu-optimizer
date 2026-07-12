#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Package C: aggregate Stage 2 runtime gate artifact (tier2-validation.json)
# from install reports + llm-validation / benchmark outputs.
# Decouples the Stage 3 gate input from the benchmark script body.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$PROJECT_ROOT/scripts/lib/common.sh"

ai370_parse_standard_args "$@"
ai370_init_latest_dir

TIER2_JSON="$LATEST_DIR/tier2-validation.json"
TIER2_MD="$LATEST_DIR/tier2-validation.md"

main() {
  echo "[INFO] Stage 2 / 145-write-tier2-validation.sh"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Offline: $OFFLINE"

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" \
  LATEST_DIR="$LATEST_DIR" \
  python3 - "$TIER2_JSON" "$TIER2_MD" <<'PY'
import json
import os
import sys
from pathlib import Path
from datetime import datetime, UTC

out_json = Path(sys.argv[1])
out_md = Path(sys.argv[2])
latest = Path(os.environ["LATEST_DIR"])
profile = os.environ.get("PROFILE", "ai370")
mode = os.environ.get("MODE", "safe")
persistence = os.environ.get("PERSISTENCE", "runtime")
offline = os.environ.get("OFFLINE", "false") == "true"

def load(name: str) -> dict:
    path = latest / name
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return {}

llm = load("llm-validation.json")
bench = load("tier2-runtime-benchmark.json")
pytorch = load("tier2-pytorch-rocm.json")
llama = load("tier2-llama-cpp.json")
ollama = load("tier2-ollama.json")
webui = load("tier2-open-webui.json")

def state_from(*candidates, default="missing"):
    for c in candidates:
        if not c:
            continue
        if isinstance(c, dict):
            for key in ("state", "status", "install_state"):
                if c.get(key):
                    return str(c[key]).lower()
        elif isinstance(c, str) and c.strip():
            return c.lower()
    return default

pytorch_state = state_from(
    (llm.get("pytorch") or {}).get("state"),
    pytorch.get("state"),
    pytorch.get("status"),
    default="missing",
)
pytorch_rocm = bool(
    (llm.get("pytorch") or {}).get("rocm")
    or pytorch.get("rocm")
    or pytorch.get("pytorch_rocm")
)
llama_state = state_from(
    (llm.get("llama_cpp") or {}).get("state"),
    llama.get("state"),
    llama.get("status"),
)
ollama_state = state_from(
    (llm.get("ollama") or {}).get("state"),
    ollama.get("state"),
    ollama.get("status"),
)
webui_state = state_from(
    (llm.get("open_webui") or {}).get("state"),
    webui.get("state"),
    webui.get("status"),
)

gguf_models = list(llm.get("gguf_models") or [])
ollama_list = str((llm.get("ollama") or {}).get("list") or "")
ollama_has_models = "NAME" in ollama_list
smoke = str(llm.get("local_inference_smoke") or bench.get("local_inference_smoke") or "skipped")
metrics = llm.get("metrics") or bench.get("metrics") or {}
measured = bool(bench.get("measured")) or (
    metrics.get("tokens_per_sec") is not None
    or (metrics.get("backend") == "pytorch" and smoke == "pass")
)

status = str(llm.get("status") or bench.get("status") or "WARN").upper()
if status not in ("PASS", "WARN", "FAIL"):
    status = "WARN"

# Derive WARN if critical pieces missing and llm report absent
if not llm and not bench:
    status = "WARN"
if pytorch_state == "missing" and llama_state == "missing" and ollama_state == "missing":
    status = "WARN" if status == "PASS" else status

data = {
    "tier": 2,
    "stage": 2,
    "phase": "write-tier2-validation",
    "status": status,
    "profile": profile,
    "mode": mode,
    "persistence": persistence,
    "offline": offline,
    "timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
    "acceptance": {
        "pytorch_available": pytorch_state == "available",
        "pytorch_rocm": pytorch_rocm,
        "llama_cpp_available": llama_state == "available",
        "ollama_available": ollama_state == "available",
        "open_webui_available": webui_state == "available",
        "local_model_available": bool(gguf_models) or ollama_has_models,
        "local_inference_smoke": smoke,
        "measured_smoke": measured,
        "tokens_per_sec": metrics.get("tokens_per_sec"),
        "load_time_ms": metrics.get("load_time_ms"),
        "benchmark_report_generated": bool(bench) or bool(llm),
    },
    "artifacts": {
        "pytorch": "reports/latest/tier2-pytorch-rocm.json",
        "llama_cpp": "reports/latest/tier2-llama-cpp.json",
        "ollama": "reports/latest/tier2-ollama.json",
        "open_webui": "reports/latest/tier2-open-webui.json",
        "benchmark": "reports/latest/tier2-runtime-benchmark.json",
        "llm_validation": "reports/latest/llm-validation.json",
    },
    "sources": {
        "llm_validation_present": bool(llm),
        "benchmark_present": bool(bench),
        "pytorch_report_present": bool(pytorch),
        "llama_report_present": bool(llama),
        "ollama_report_present": bool(ollama),
        "open_webui_report_present": bool(webui),
    },
    "notes": (
        "Aggregated by scripts/145-write-tier2-validation.sh (Package C). "
        "Prefer running after 140-benchmark-llm.sh. WARN is accepted by the Stage 3 gate."
    ),
}
out_json.write_text(json.dumps(data, indent=2) + "\n")

md = f"""# Tier 2 Validation

Profile: {profile} | Mode: {mode} | Offline: {offline}
Status: {status}
Generated: {data["timestamp"]}

## Acceptance
- PyTorch: {pytorch_state} (ROCm: {pytorch_rocm})
- llama.cpp: {llama_state}
- Ollama: {ollama_state}
- Open WebUI: {webui_state}
- Local model available: {bool(gguf_models) or ollama_has_models}
- Measured smoke: {smoke}
- tokens_per_sec: {metrics.get("tokens_per_sec", "n/a")}
- load_time_ms: {metrics.get("load_time_ms", "n/a")}
- Benchmark report generated: {bool(bench) or bool(llm)}

Gate note: PASS and WARN both satisfy the default Stage 3 gate (see docs/ROADMAP.md).
Aggregator: scripts/145-write-tier2-validation.sh
"""
out_md.write_text(md)
print(f"[INFO] Wrote {out_json}")
print(f"[INFO] Wrote {out_md}")
print(f"[INFO] tier2-validation status: {status}")
if status == "FAIL":
    raise SystemExit(1)
PY
}

main "$@"
