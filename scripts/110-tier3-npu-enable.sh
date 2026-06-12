#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 3 skeleton – AMD NPU Enablement (XDNA2 / ONNX Runtime + Vitis EP).
# Future home for explicit Ryzen AI / XRT artifact installation + NPU provider validation.
# Must be run after Tier 1 hardware is solid and before Tier 5.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

echo "[INFO] Tier 3 skeleton (110-tier3-npu-enable.sh)"
echo "[INFO] This phase will handle ONNX Runtime + NPU execution provider installation"
echo "[INFO] (from staged .ai370-ai/amd-artifacts or wheelhouse) and produce tier3-validation.json."
echo "[INFO] OFFLINE=$OFFLINE"

# Real work (to be implemented):
# - Detect / install ONNX Runtime with VitisAIExecutionProvider or AMD NPU EP
# - Run xrt-smi / dedicated NPU smoke
# - Write tier3 status for the Tier 5 gate

echo "[INFO] Tier 3 skeleton complete (no new actions taken in this stub)."
