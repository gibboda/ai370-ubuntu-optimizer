#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S3-M6: lightweight local AI visibility smoke (no network pip by default).
# Does not install onnxruntime unless AI370_STAGE1_INSTALL_ORT=true.
# Full model benchmarks belong in S3-M6 (140 / 230 / 245).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$PROJECT_ROOT/scripts/lib/common.sh"

ai370_parse_standard_args "$@"
ai370_init_latest_dir
ai370_require_runtime_persistence "Stage 1 AI smoke"

AI_DIR="$PROJECT_ROOT/.ai370-ai"
VENV_DIR="$AI_DIR/venv"
INSTALL_ORT="${AI370_STAGE1_INSTALL_ORT:-false}"

main() {
  echo "[INFO] Stage 1 / 80-benchmark-local-ai.sh"
  echo "[INFO] Offline: $OFFLINE  Install ORT: $INSTALL_ORT"

  local providers="not-checked"
  local venv_note="none"

  if [[ -x "$VENV_DIR/bin/python" ]]; then
    venv_note="$VENV_DIR"
    if [[ "$INSTALL_ORT" == "true" && "$OFFLINE" != "true" ]]; then
      echo "[INFO] AI370_STAGE1_INSTALL_ORT=true – installing numpy/onnxruntime into existing venv (optional)"
      "$VENV_DIR/bin/python" -m pip install --upgrade numpy onnxruntime 2>/dev/null || true
    fi
    providers="$("$VENV_DIR/bin/python" -c '
try:
    import onnxruntime as ort
    print(",".join(ort.get_available_providers()))
except Exception as e:
    print("not-importable:" + str(e)[:80])
' 2>/dev/null || echo "onnxruntime-not-importable")"
  else
    venv_note="missing (Stage 1 does not create venv by default; Stage 2 owns AI runtime install)"
    providers="skipped-no-venv"
    # Optional legacy behavior: create venv + install only when explicitly requested
    if [[ "$INSTALL_ORT" == "true" ]]; then
      echo "[INFO] AI370_STAGE1_INSTALL_ORT=true – creating venv for optional ORT smoke"
      mkdir -p "$AI_DIR"
      python3 -m venv "$VENV_DIR"
      if [[ "$OFFLINE" != "true" ]]; then
        "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel numpy onnxruntime 2>/dev/null || true
      fi
      venv_note="$VENV_DIR"
      providers="$("$VENV_DIR/bin/python" -c '
try:
    import onnxruntime as ort
    print(",".join(ort.get_available_providers()))
except Exception as e:
    print("not-importable:" + str(e)[:80])
' 2>/dev/null || echo "onnxruntime-not-importable")"
    fi
  fi

  {
    echo "# Tier 1 Local AI Benchmark Smoke"
    echo "Offline: $OFFLINE"
    echo "Install ORT requested: $INSTALL_ORT"
    echo "Venv: $venv_note"
    echo "ONNX Runtime providers: $providers"
    echo
    echo "Package C: Stage 1 does not pip-install packages by default."
    echo "Set AI370_STAGE1_INSTALL_ORT=true for optional ORT import smoke."
    echo "Full runtime install and model benchmarks belong in Stage 2."
  } > "$LATEST_DIR/tier1-local-ai-benchmark.md"

  export providers OFFLINE VENV_DIR INSTALL_ORT
  python3 - <<'PY' > "$LATEST_DIR/tier1-local-ai-benchmark.json"
import json, os
print(json.dumps({
  "tier": 1,
  "phase": "benchmark-local-ai",
  "offline": os.environ.get("OFFLINE", "false").lower() == "true",
  "install_ort_requested": os.environ.get("INSTALL_ORT", "false").lower() == "true",
  "onnxruntime_providers": os.environ.get("providers", "unknown"),
  "venv": os.environ.get("VENV_DIR", ""),
  "policy": "no network pip by default; Stage 2 owns runtime install",
}, indent=2))
PY

  echo "[INFO] 80-benchmark-local-ai.sh complete."
}

main "$@"
