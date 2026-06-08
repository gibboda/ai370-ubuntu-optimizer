#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
PLAN_MD="$LATEST_DIR/system-tuning-plan.md"
PLAN_JSON="$LATEST_DIR/system-tuning-plan.json"
COMMANDS_SH="$LATEST_DIR/runtime-tuning-commands.sh"

# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

main() {
  echo "[INFO] Phase 4: CPU / RAM / storage tuning"
  echo "[INFO] Profile: $PROFILE"
  echo "[INFO] Mode: $MODE"
  echo "[INFO] Persistence: $PERSISTENCE"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent CPU/RAM/storage tuning is not implemented yet. Use --persistence=runtime."
    exit 2
  fi

  mkdir -p "$LATEST_DIR"

  local cpu_model cpu_governors cpu_governor memory_total storage_text nvme_text power_profiles target_power zram_state swap_state status
  cpu_model="$(detect_cpu_model)"
  cpu_governors="$(detect_cpu_governors)"
  cpu_governor="$(detect_cpu_current_governor)"
  memory_total="$(detect_memory_total)"
  storage_text="$(detect_storage_text)"
  nvme_text="$(detect_nvme_text)"
  power_profiles="$(detect_powerprofiles)"
  target_power="balanced"
  [[ "$MODE" == "aggressive" ]] && target_power="performance"
  zram_state="$(systemctl is-active systemd-zram-setup@zram0.service 2>/dev/null || true)"
  swap_state="$(swapon --show --noheadings 2>/dev/null || true)"

  status="PASS"
  [[ -z "$cpu_governor" || -z "$memory_total" || -z "$storage_text" ]] && status="WARN"

  cat > "$COMMANDS_SH" <<EOF_COMMANDS
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Generated runtime-only tuning commands. Review before running.

set -euo pipefail

printf '%s\n' '[TUNE] Target power profile: $target_power'
if command -v powerprofilesctl >/dev/null 2>&1; then
  powerprofilesctl set '$target_power'
else
  echo '[WARN] powerprofilesctl is unavailable.'
fi

printf '%s\n' '[TUNE] CPU governor visibility'
if command -v cpupower >/dev/null 2>&1; then
  cpupower frequency-info || true
else
  echo '[INFO] cpupower is unavailable; install linux-tools for deeper CPU governor checks.'
fi

printf '%s\n' '[TUNE] Memory and swap visibility'
free -h || true
swapon --show || true

printf '%s\n' '[TUNE] Storage health visibility'
lsblk -o NAME,MODEL,SIZE,TYPE,ROTA,MOUNTPOINTS || true
if command -v nvme >/dev/null 2>&1; then
  nvme list || true
fi
EOF_COMMANDS
  chmod +x "$COMMANDS_SH"

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" STATUS="$status" \
  CPU_MODEL="$cpu_model" CPU_GOVERNORS="$cpu_governors" CPU_GOVERNOR="$cpu_governor" \
  MEMORY_TOTAL="$memory_total" STORAGE_TEXT="$storage_text" NVME_TEXT="$nvme_text" \
  POWER_PROFILES="$power_profiles" TARGET_POWER="$target_power" ZRAM_STATE="$zram_state" SWAP_STATE="$swap_state" \
  COMMANDS_SH="$COMMANDS_SH" python3 - "$PLAN_JSON" <<'PY'
import json
import os
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(json.dumps({
    "profile": os.environ["PROFILE"],
    "mode": os.environ["MODE"],
    "persistence": os.environ["PERSISTENCE"],
    "status": os.environ["STATUS"],
    "cpu": {
        "model": os.environ["CPU_MODEL"],
        "available_governors": os.environ["CPU_GOVERNORS"],
        "current_governor": os.environ["CPU_GOVERNOR"],
        "target_power_profile": os.environ["TARGET_POWER"],
    },
    "memory": {"total": os.environ["MEMORY_TOTAL"], "swap": os.environ["SWAP_STATE"], "zram": os.environ["ZRAM_STATE"]},
    "storage": {"devices_text": os.environ["STORAGE_TEXT"], "nvme_text": os.environ["NVME_TEXT"]},
    "powerprofilesctl": os.environ["POWER_PROFILES"],
    "generated_commands": os.environ["COMMANDS_SH"],
    "policy": "runtime-only recommendations; no persistent sysctl, fstab, governor, or NVMe changes are applied automatically",
}, indent=2) + "\n")
PY

  {
    echo "# CPU / RAM / Storage Tuning Plan"
    echo
    echo "Profile: $PROFILE"
    echo "Mode: $MODE"
    echo "Persistence: $PERSISTENCE"
    echo "Status: $status"
    echo
    echo "## CPU"
    echo
    echo "- Model: ${cpu_model:-unknown}"
    echo "- Available governors: ${cpu_governors:-unknown}"
    echo "- Current governor: ${cpu_governor:-unknown}"
    echo "- Target runtime power profile: $target_power"
    echo
    echo "## RAM"
    echo
    echo "- Total memory: ${memory_total:-unknown}"
    echo "- zram service: ${zram_state:-unknown}"
    echo "- Swap: ${swap_state:-none}"
    echo
    echo "## Storage"
    echo
    printf '```text\n%s\n```\n' "$storage_text"
    echo
    echo "## Runtime-only commands"
    echo
    echo "Review before running:"
    echo
    echo "\`\`\`bash"
    echo "bash reports/latest/runtime-tuning-commands.sh"
    echo "\`\`\`"
    echo
    echo "No persistent CPU governor, sysctl, fstab, zram, or NVMe settings are changed automatically in this phase."
  } > "$PLAN_MD"

  echo "[INFO] Tuning status: $status"
  echo "[INFO] Wrote $PLAN_MD"
  echo "[INFO] Wrote $PLAN_JSON"
  echo "[INFO] Wrote $COMMANDS_SH"
}

main "$@"
