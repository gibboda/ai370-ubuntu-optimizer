#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M4 visibility / S3-M4 backend: AMD Ryzen AI / Vitis AI EP listing.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/npu-venv.sh
source "$PROJECT_ROOT/scripts/lib/npu-venv.sh"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
# Prefer Ryzen AI venv (onnxruntime-vitisai / VitisAI EP) over stock CPU ORT.
# Source XRT + VOE/flexml library paths so the EP can load native libs.
prepare_npu_runtime_env "$PROJECT_ROOT"
VENV_PYTHON="$(resolve_npu_python "$PROJECT_ROOT" || true)"
VENV_SOURCE="$(npu_python_source_label "${VENV_PYTHON:-}")"
STATUS_JSON="$LATEST_DIR/vitis-ai-ep-status.json"
SUMMARY_MD="$LATEST_DIR/vitis-ai-ep-status.md"

main() {
  mkdir -p "$LATEST_DIR"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent Vitis AI EP configuration is not implemented. Use --persistence=runtime."
    exit 2
  fi

  if [[ -n "${VENV_PYTHON:-}" && -x "$VENV_PYTHON" ]]; then
    PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" \
    VENV_PYTHON="$VENV_PYTHON" VENV_SOURCE="$VENV_SOURCE" \
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
venv_source = os.environ.get("VENV_SOURCE", "unknown")

ort_state = "missing"
providers = []
matching = []
provider_smoke = "not-run"
error = ""
recommendations = []

if importlib.util.find_spec("onnxruntime") is None:
    recommendations.append(
        "ONNX Runtime not importable in the selected venv. "
        "Install Ryzen AI into .ai370-ai/ryzen-ai/venv (scripts/205-install-xrt-ryzen-ai.sh "
        "with --accept-amd-acceleration-risk) or stock ORT via scripts/200-install-onnxruntime.sh."
    )
else:
    try:
        import onnxruntime as ort

        ort_state = "available"
        providers = list(ort.get_available_providers())
        matching = [p for p in providers if any(token in p.lower() for token in provider_tokens)]
        if matching:
            provider_smoke = "visible"
            recommendations.append("Run scripts/230-benchmark-npu.sh to prove model execution with the detected provider.")
        else:
            provider_smoke = "missing"
            if venv_source != "ryzen-ai":
                recommendations.append(
                    "Using stock .ai370-ai/venv (CPU onnxruntime only). "
                    "Install AMD Ryzen AI Software into .ai370-ai/ryzen-ai/venv so this check can see VitisAIExecutionProvider."
                )
            recommendations.append("Install/stage AMD Ryzen AI Software with the Vitis AI ONNX Runtime Execution Provider.")
            recommendations.append("Confirm XRT/AMDXDNA device visibility with scripts/210-check-ryzen-ai-software.sh.")
    except Exception as exc:  # diagnostics are more useful than aborting here
        ort_state = "error"
        error = f"{type(exc).__name__}: {exc}"
        recommendations.append("Fix the ONNX Runtime Python environment before checking AMD provider support.")

status = "PASS" if matching else "WARN"
data = {
    "tier": 2,
    "milestone": "S2-M4",
    "phase": "check-vitis-ai-ep",
    "status": status,
    "timestamp": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
    "profile": profile,
    "mode": mode,
    "persistence": persistence,
    "offline": offline,
    "venv_python": venv_python,
    "venv_source": venv_source,
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
    f"- Venv: {venv_python} ({venv_source})\n"
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
    PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" \
    VENV_PYTHON="${VENV_PYTHON:-}" VENV_SOURCE="${VENV_SOURCE:-unknown}" \
    python3 - "$STATUS_JSON" "$SUMMARY_MD" <<'PY'
import datetime, json, os, sys
from pathlib import Path
status_path, summary_path = map(Path, sys.argv[1:])
data = {
  "tier": 2,
  "milestone": "S2-M4",
  "phase": "check-vitis-ai-ep",
  "status": "WARN",
  "timestamp": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
  "profile": os.environ["PROFILE"],
  "mode": os.environ["MODE"],
  "persistence": os.environ["PERSISTENCE"],
  "offline": os.environ["OFFLINE"] == "true",
  "venv_python": os.environ.get("VENV_PYTHON", ""),
  "venv_source": os.environ.get("VENV_SOURCE", "unknown"),
  "onnxruntime_state": "missing-venv",
  "providers": [],
  "amd_provider_candidates": [],
  "provider_smoke": "not-run",
  "error": "No Ryzen AI or stock virtualenv Python found.",
  "recommendations": [
    "Run scripts/205-install-xrt-ryzen-ai.sh with --accept-amd-acceleration-risk for NPU EP, "
    "or scripts/200-install-onnxruntime.sh for stock CPU onnxruntime."
  ],
}
status_path.write_text(json.dumps(data, indent=2) + "\n")
summary_path.write_text(
    "# Vitis AI Execution Provider Status\n\nStatus: WARN\n\n"
    "No NPU/stock venv Python found. Install Ryzen AI (205) or stock ORT (200).\n"
)
PY
  fi

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
  local status="WARN"
  if [[ -f "$STATUS_JSON" ]]; then
    status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status","WARN"))' "$STATUS_JSON" 2>/dev/null || echo WARN)"
  fi
  if [[ "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
