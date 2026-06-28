#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M2: validate AMD Ryzen AI / Vitis AI ONNX Runtime execution-provider visibility.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
VENV_PYTHON="$AI_ROOT/venv/bin/python"
STATUS_JSON="$LATEST_DIR/vitis-ai-ep-status.json"
SUMMARY_MD="$LATEST_DIR/vitis-ai-ep-status.md"

main() {
  mkdir -p "$LATEST_DIR"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent Vitis AI EP configuration is not implemented. Use --persistence=runtime."
    exit 2
  fi

  if [[ -x "$VENV_PYTHON" ]]; then
    PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" VENV_PYTHON="$VENV_PYTHON" \
    "$VENV_PYTHON" - "$STATUS_JSON" "$SUMMARY_MD" <<'PY'
import datetime
import importlib.util
import json
import os
import sys
from pathlib import Path

status_path = Path(sys.argv[1])
summary_path = Path(sys.argv[2])
provider_tokens = ("vitis", "vai", "ryzen", "xilinx", "amd", "xdna")

profile = os.environ["PROFILE"]
mode = os.environ["MODE"]
persistence = os.environ["PERSISTENCE"]
offline = os.environ["OFFLINE"] == "true"
venv_python = os.environ["VENV_PYTHON"]

ort_state = "missing"
providers = []
matching = []
provider_smoke = "not-run"
error = ""
recommendations = []

if importlib.util.find_spec("onnxruntime") is None:
    recommendations.append("Run scripts/200-install-onnxruntime.sh or stage ONNX Runtime in .ai370-ai/venv.")
else:
    import onnxruntime as ort

    try:
        ort_state = "available"
        providers = list(ort.get_available_providers())
        matching = [p for p in providers if any(token in p.lower() for token in provider_tokens)]
        if matching:
            provider_smoke = "visible"
            recommendations.append("Run scripts/230-benchmark-npu.sh to prove model execution with the detected provider.")
        else:
            provider_smoke = "missing"
            recommendations.append("Install/stage AMD Ryzen AI Software with the Vitis AI ONNX Runtime Execution Provider.")
            recommendations.append("Confirm XRT/AMDXDNA device visibility with scripts/210-check-ryzen-ai-software.sh.")
    except Exception as exc:  # diagnostics are more useful than aborting here
        ort_state = "error"
        error = f"{type(exc).__name__}: {exc}"
        recommendations.append("Fix the ONNX Runtime Python environment before checking AMD provider support.")

status = "PASS" if matching else "WARN"
data = {
    "tier": 2,
    "milestone": "S2-M2",
    "phase": "check-vitis-ai-ep",
    "status": status,
    "timestamp": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
    "profile": profile,
    "mode": mode,
    "persistence": persistence,
    "offline": offline,
    "venv_python": venv_python,
    "onnxruntime_state": ort_state,
    "providers": providers,
    "amd_provider_candidates": matching,
    "provider_smoke": provider_smoke,
    "error": error,
    "recommendations": recommendations,
}
status_path.write_text(json.dumps(data, indent=2) + "\n")
summary_path.write_text(
    "# Vitis AI Execution Provider Status\n\n"
    f"Profile: {profile} | Mode: {mode} | Offline: {offline}\n\n"
    f"Status: {status}\n\n"
    f"- ONNX Runtime: {ort_state}\n"
    f"- Providers: {', '.join(providers) if providers else 'none'}\n"
    f"- AMD/Vitis candidates: {', '.join(matching) if matching else 'none detected'}\n"
    f"- Provider smoke: {provider_smoke}\n\n"
    "## Recommendations\n\n"
    + "\n".join(f"- {item}" for item in recommendations)
    + (f"\n\n## Error\n\n```text\n{error}\n```\n" if error else "\n")
)
PY
  else
    PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" VENV_PYTHON="$VENV_PYTHON" \
    python3 - "$STATUS_JSON" "$SUMMARY_MD" <<'PY'
import datetime, json, os, sys
from pathlib import Path
status_path, summary_path = map(Path, sys.argv[1:])
data = {
  "tier": 2,
  "milestone": "S2-M2",
  "phase": "check-vitis-ai-ep",
  "status": "WARN",
  "timestamp": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
  "profile": os.environ["PROFILE"],
  "mode": os.environ["MODE"],
  "persistence": os.environ["PERSISTENCE"],
  "offline": os.environ["OFFLINE"] == "true",
  "venv_python": os.environ["VENV_PYTHON"],
  "onnxruntime_state": "missing-venv",
  "providers": [],
  "amd_provider_candidates": [],
  "provider_smoke": "not-run",
  "error": "Virtualenv Python is missing.",
  "recommendations": ["Run scripts/200-install-onnxruntime.sh first or stage .ai370-ai/venv for offline validation."],
}
status_path.write_text(json.dumps(data, indent=2) + "\n")
summary_path.write_text("# Vitis AI Execution Provider Status\n\nStatus: WARN\n\nVirtualenv Python is missing. Run scripts/200-install-onnxruntime.sh first.\n")
PY
  fi

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
}

main "$@"
