#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 1: Local AI benchmark / runtime smoke (ONNX, CPU/iGPU visibility). Offline friendly.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_DIR="$PROJECT_ROOT/.ai370-ai"
VENV_DIR="$AI_DIR/venv"

mkdir -p "$LATEST_DIR"

OFFLINE_CONFIG="$PROJECT_ROOT/config/offline/ai-runtime.env"
OFFLINE_REQUIREMENTS="$PROJECT_ROOT/config/ai-runtime/requirements-offline.txt"

main() {
  echo "[INFO] Tier 1 / 80-benchmark-local-ai.sh"
  echo "[INFO] Offline: $OFFLINE"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent AI tuning not implemented."
    exit 2
  fi

  # Ensure a basic venv exists for smoke tests (very conservative, CPU-focused by default)
  if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    echo "[INFO] Creating local AI venv at $VENV_DIR (for benchmark smoke)..."
    mkdir -p "$AI_DIR"
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel 2>/dev/null || true
  fi

  # In offline mode we expect the wheelhouse or pre-satisfied venv
  if [[ "$OFFLINE" == "true" ]]; then
    if [[ -f "$OFFLINE_CONFIG" ]]; then
      # shellcheck source=/dev/null
      source "$OFFLINE_CONFIG"
    fi
    echo "[INFO] Offline mode – skipping network pip installs. Using local venv or wheelhouse if present."
  else
    # Minimal safe CPU packages for smoke (real Tier 2 will expand this)
    "$VENV_DIR/bin/python" -m pip install --upgrade numpy onnxruntime 2>/dev/null || true
  fi

  # Run a tiny ONNX provider smoke if possible
  providers="unknown"
  if [[ -x "$VENV_DIR/bin/python" ]]; then
    providers="$("$VENV_DIR/bin/python" -c '
try:
    import onnxruntime as ort
    print(",".join(ort.get_available_providers()))
except Exception as e:
    print("error:" + str(e)[:80])
' 2>/dev/null || echo "onnxruntime-not-importable")"
  fi

  {
    echo "# Tier 1 Local AI Benchmark Smoke"
    echo "Offline: $OFFLINE"
    echo "ONNX Runtime providers: $providers"
    echo
    echo "This is a lightweight visibility + import smoke. Full model benchmarks belong in Tier 2/3."
  } > "$LATEST_DIR/tier1-local-ai-benchmark.md"

  cat > "$LATEST_DIR/tier1-local-ai-benchmark.json" <<EOF
{
  "tier": 1,
  "phase": "benchmark-local-ai",
  "offline": $([[ "$OFFLINE" == "true" ]] && echo true || echo false),
  "onnxruntime_providers": "$providers",
  "venv": "$VENV_DIR"
}
EOF

  echo "[INFO] 80-benchmark-local-ai.sh complete."
}

main "$@"
