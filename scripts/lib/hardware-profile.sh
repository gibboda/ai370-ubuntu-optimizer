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
#   hardware_profile_gpu_target_from_system_profile "$PROFILE_FILE"

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

# HIP/GPU target for the platform classified in a published Stage 1 profile.
# Prints nothing when the file is missing, unreadable, or unclassified.
hardware_profile_gpu_target_from_system_profile() {
  local profile_file="${1:-}"
  if [[ -z "$profile_file" || ! -f "$profile_file" ]]; then
    return 0
  fi
  python3 - "$PROJECT_ROOT" "$profile_file" <<'PY'
import json
import sys
from pathlib import Path

root, profile_path = sys.argv[1], sys.argv[2]
sys.path.insert(0, str(Path(root) / "scripts" / "lib"))
import hardware_profile

try:
    profile = json.loads(Path(profile_path).read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    raise SystemExit(0)
classification = profile.get("classification") if isinstance(profile, dict) else None
value = classification.get("platform_id") if isinstance(classification, dict) else None
if not isinstance(value, str):
    raise SystemExit(0)
platform_id = value.strip()
if not platform_id or platform_id.casefold() in {"unknown", "none", "null"}:
    raise SystemExit(0)
sys.stdout.write(hardware_profile.gpu_target(platform_id))
PY
}
