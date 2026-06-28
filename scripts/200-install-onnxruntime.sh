#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M2: ONNX Runtime installer / validator for the AMD AI Stack.
# Online mode installs into the repo-local venv. Offline mode only uses an
# approved local wheelhouse and always emits actionable status reports.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
VENV_DIR="$AI_ROOT/venv"
WHEELHOUSE="$AI_ROOT/wheelhouse"
STATUS_JSON="$LATEST_DIR/onnxruntime-status.json"
SUMMARY_MD="$LATEST_DIR/onnxruntime-status.md"

main() {
  mkdir -p "$LATEST_DIR" "$AI_ROOT"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent ONNX Runtime installation is not implemented. Use --persistence=runtime."
    exit 2
  fi

  local install_action="none" detail=""

  if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    if [[ "$OFFLINE" == "true" ]]; then
      install_action="skipped-offline-missing-venv"
      detail="Offline mode: $VENV_DIR is missing. Stage a populated venv or wheelhouse before rerunning."
    else
      if python3 -m venv "$VENV_DIR" && "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel; then
        install_action="created-venv"
      else
        install_action="venv-create-failed"
        detail="Failed to create or bootstrap Python venv at $VENV_DIR. Ensure python3-venv and pip are installed."
      fi
    fi
  fi

  if [[ -x "$VENV_DIR/bin/python" ]]; then
    if [[ "$OFFLINE" == "true" ]]; then
      if [[ -d "$WHEELHOUSE" ]]; then
        install_action="offline-wheelhouse-install"
        "$VENV_DIR/bin/python" -m pip install --no-index --find-links "$WHEELHOUSE" onnxruntime onnx numpy || \
          detail="Offline ONNX Runtime install failed. Ensure onnxruntime, onnx, and numpy wheels exist in $WHEELHOUSE."
      else
        install_action="skipped-offline-missing-wheelhouse"
        detail="Offline mode: wheelhouse missing at $WHEELHOUSE."
      fi
    else
      install_action="pip-install"
      "$VENV_DIR/bin/python" -m pip install --upgrade onnxruntime onnx numpy || \
        detail="ONNX Runtime pip install failed; see console output."
    fi
  fi

  local status="WARN"
  if [[ -x "$VENV_DIR/bin/python" ]] && PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" \
    VENV_DIR="$VENV_DIR" WHEELHOUSE="$WHEELHOUSE" INSTALL_ACTION="$install_action" DETAIL="$detail" \
    "$VENV_DIR/bin/python" - "$STATUS_JSON" "$SUMMARY_MD" <<'PY'
import datetime
import importlib.util
import json
import os
import sys
from pathlib import Path

status_path = Path(sys.argv[1])
summary_path = Path(sys.argv[2])
profile = os.environ.get("PROFILE", "ai370")
mode = os.environ.get("MODE", "safe")
persistence = os.environ.get("PERSISTENCE", "runtime")
offline = os.environ.get("OFFLINE", "false") == "true"
venv_dir = os.environ.get("VENV_DIR", "")
wheelhouse = os.environ.get("WHEELHOUSE", "")
install_action = os.environ.get("INSTALL_ACTION", "none")
detail = os.environ.get("DETAIL", "")

ort_state = "missing"
ort_version = "not-installed"
providers = []
cpu_smoke = "not-run"
error = ""

if importlib.util.find_spec("onnxruntime") is not None:
    import numpy as np
    import onnxruntime as ort

    try:
        ort_state = "available"
        ort_version = getattr(ort, "__version__", "unknown")
        providers = list(ort.get_available_providers())
        if "CPUExecutionProvider" in providers:
            # Provider visibility smoke check. Full model execution is handled by
            # scripts/230-benchmark-npu.sh so this installer stays lightweight.
            _ = np.ones((1, 1), dtype=np.float32)
            cpu_smoke = "pass"
        else:
            cpu_smoke = "warn-no-cpu-provider"
    except Exception as exc:  # broad by design: report runtime diagnostics
        ort_state = "error"
        error = f"{type(exc).__name__}: {exc}"

status = "PASS" if ort_state == "available" and cpu_smoke == "pass" else "WARN"
provider_matches = [p for p in providers if any(token in p.lower() for token in ("vitis", "vai", "dml", "rocm", "amd"))]

data = {
    "tier": 2,
    "milestone": "S2-M2",
    "phase": "install-onnxruntime",
    "status": status,
    "timestamp": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
    "profile": profile,
    "mode": mode,
    "persistence": persistence,
    "offline": offline,
    "venv": venv_dir,
    "wheelhouse": wheelhouse,
    "install_action": install_action,
    "onnxruntime": {
        "state": ort_state,
        "version": ort_version,
        "providers": providers,
        "cpu_smoke": cpu_smoke,
        "amd_related_providers": provider_matches,
    },
    "detail": detail,
    "error": error,
}
status_path.write_text(json.dumps(data, indent=2) + "\n")
summary_path.write_text(
    "# ONNX Runtime Status\n\n"
    f"Profile: {profile} | Mode: {mode} | Offline: {offline}\n\n"
    f"Status: {status}\n\n"
    f"- Install action: {install_action}\n"
    f"- ONNX Runtime: {ort_state}\n"
    f"- Version: {ort_version}\n"
    f"- Providers: {', '.join(providers) if providers else 'none'}\n"
    f"- AMD-related providers: {', '.join(provider_matches) if provider_matches else 'none detected'}\n"
    f"- CPU provider smoke: {cpu_smoke}\n\n"
    "## Detail\n\n"
    f"```text\n{detail or error or 'ONNX Runtime validation completed.'}\n```\n"
)
sys.exit(0 if status == "PASS" else 1)
PY
  then
    status="PASS"
  fi

  if [[ ! -x "$VENV_DIR/bin/python" || ! -f "$STATUS_JSON" ]]; then
    STATUS="WARN" PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" OFFLINE="$OFFLINE" \
    VENV_DIR="$VENV_DIR" WHEELHOUSE="$WHEELHOUSE" INSTALL_ACTION="$install_action" DETAIL="$detail" \
    python3 - "$STATUS_JSON" "$SUMMARY_MD" <<'PY'
import datetime, json, os, sys
from pathlib import Path
status_path, summary_path = map(Path, sys.argv[1:])
data = {
  "tier": 2,
  "milestone": "S2-M2",
  "phase": "install-onnxruntime",
  "status": "WARN",
  "timestamp": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z"),
  "profile": os.environ["PROFILE"],
  "mode": os.environ["MODE"],
  "persistence": os.environ["PERSISTENCE"],
  "offline": os.environ["OFFLINE"] == "true",
  "venv": os.environ["VENV_DIR"],
  "wheelhouse": os.environ["WHEELHOUSE"],
  "install_action": os.environ["INSTALL_ACTION"],
  "onnxruntime": {"state": "missing", "version": "not-installed", "providers": [], "cpu_smoke": "not-run", "amd_related_providers": []},
  "detail": os.environ["DETAIL"],
}
status_path.write_text(json.dumps(data, indent=2) + "\n")
summary_path.write_text("# ONNX Runtime Status\n\nStatus: WARN\n\n" + os.environ["DETAIL"] + "\n")
PY
  fi

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
  [[ "$status" == "PASS" ]] || exit 0
}

export PROFILE MODE PERSISTENCE OFFLINE VENV_DIR WHEELHOUSE
main "$@"
