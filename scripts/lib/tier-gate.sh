#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Shared Tier gate + validation helpers (M6.1).
# Source from other scripts: source scripts/lib/tier-gate.sh
# Provides require_tier123_pass (re-export or thin wrapper) and helpers for writing tierN-validation.json.
# Start small; expand in follow-ups.

# Re-export the authoritative implementation from the main dispatcher for now.
# In future, move the full require_* functions here and have ai370-optimize.sh source this.

TIER_GATE_SOURCED=1

# Example future helper (stub):
# write_tier_validation() { ... }

# For immediate use the logic lives in ai370-optimize.sh (require_tier123_pass).
# Callers that need it without full dispatcher can still source the main or copy the check.
echo "[INFO] tier-gate.sh sourced (helpers will consolidate here in follow-on work)" 1>&2 || true
