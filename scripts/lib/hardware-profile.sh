# SPDX-License-Identifier: GPL-3.0-only
# shellcheck shell=bash
#
# Shell adapter for configs/profiles/hardware-profiles.json.
# Requires PROJECT_ROOT. Does not probe hardware or apply tuning.
#
# Usage:
#   # shellcheck source=lib/hardware-profile.sh
#   source "$PROJECT_ROOT/scripts/lib/hardware-profile.sh"
#   hardware_profile_gpu_target "$PROFILE"

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  echo "[ERROR] hardware-profile.sh requires PROJECT_ROOT to be set" >&2
  return 1 2>/dev/null || exit 1
fi

hardware_profile_gpu_target() {
  local profile_id="${1:-}"
  if [[ -z "$profile_id" || "$profile_id" == */* || "$profile_id" == *\\* ]]; then
    return 0
  fi
  python3 - "$PROJECT_ROOT" "$profile_id" <<'PY'
import sys
from pathlib import Path

root, profile_id = sys.argv[1], sys.argv[2]
sys.path.insert(0, str(Path(root) / "scripts" / "lib"))
import hardware_profile

sys.stdout.write(hardware_profile.gpu_target(profile_id))
PY
}
