#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Stage 1: combined CPU / memory / storage runtime tuning plans (Package C merge of 40/50/60).
# Detection + reviewable recommendations by default (no system-persistent changes).
# Opt-in runtime apply: ./ai370-optimize.sh stage2-optimize-apply --approve
# (AI370_APPLY_TUNING=true is the script-level switch used by that command)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$PROJECT_ROOT/scripts/lib/common.sh"
# shellcheck source=lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

ai370_parse_standard_args "$@"
ai370_init_latest_dir
ai370_require_runtime_persistence "platform tuning"

main() {
  echo "[INFO] Stage 1 / 40-platform-tuning.sh (CPU + memory + storage)"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE"

  local cpu_model governor governors target_power mem_total zram_active swap_show storage nvme
  cpu_model="$(detect_cpu_model)"
  governor="$(detect_cpu_current_governor)"
  governors="$(detect_cpu_governors)"
  target_power="balanced"
  [[ "$MODE" == "aggressive" ]] && target_power="performance"

  mem_total="$(detect_memory_total)"
  # systemctl is-active prints inactive/failed and exits non-zero; do not append
  # another "inactive" via || echo (that produced "inactive\ninactive").
  zram_active="$(systemctl is-active systemd-zram-setup@zram0.service 2>/dev/null || true)"
  zram_active="${zram_active:-inactive}"
  # Collapse accidental multi-line noise to a single token for reports/JSON.
  zram_active="${zram_active%%$'\n'*}"
  swap_show="$(swapon --show --noheadings 2>/dev/null || true)"

  storage="$(detect_storage_text)"
  nvme="$(detect_nvme_text)"

  # --- Combined platform report ---
  {
    echo "# Tier 1 Platform Tuning Plan"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Persistence: $PERSISTENCE"
    echo "Generated: $(ai370_utc_now)"
    echo
    echo "## CPU"
    echo
    echo "- Target power profile: $target_power (runtime only via powerprofilesctl)"
    echo "- Current governor: ${governor:-unknown}"
    echo "- Available governors: ${governors:-unknown}"
    echo "- CPU: $cpu_model"
    echo
    echo "## Memory"
    echo
    echo "- Total memory: $mem_total"
    echo "- zram0 active: $zram_active"
    echo "- Current swap:"
    echo "$swap_show"
    echo
    echo "Recommendations (runtime-only):"
    echo "- Consider enabling zram for better interactive behavior on 32/64 GB LPDDR5X systems."
    echo "- Review swappiness if using heavy local LLM inference."
    echo
    echo "## Storage"
    echo
    echo "### Block devices"
    lsblk -o NAME,MODEL,SIZE,TYPE,MOUNTPOINTS 2>/dev/null || echo "(lsblk unavailable)"
    echo
    echo "### NVMe"
    echo "${nvme:-No NVMe devices detected via lsblk}"
    echo
    echo "Run 'sudo nvme list' and 'sudo smartctl -a /dev/nvme0n1' (or equivalent) for detailed health."
    echo
    echo "Review and run the generated commands in:"
    echo "  reports/latest/tier1-cpu-runtime-commands.sh"
  } > "$LATEST_DIR/tier1-platform-tuning.md"

  # Compatibility copies for existing consumers / 90-validate soft checks
  cp "$LATEST_DIR/tier1-platform-tuning.md" "$LATEST_DIR/tier1-cpu-plan.md" 2>/dev/null || true
  {
    echo "# Tier 1 Memory Report"
    echo
    echo "- Total memory: $mem_total"
    echo "- zram0 active: $zram_active"
    echo "- Current swap:"
    echo "$swap_show"
    echo
    echo "Recommendations (runtime-only):"
    echo "- Consider enabling zram for better interactive behavior on 32/64 GB LPDDR5X systems."
    echo "- Review swappiness if using heavy local LLM inference."
    echo
    echo "See also: tier1-platform-tuning.md (combined report)."
  } > "$LATEST_DIR/tier1-memory.md"
  {
    echo "# Tier 1 Storage Health"
    echo
    echo "## Block devices"
    lsblk -o NAME,MODEL,SIZE,TYPE,MOUNTPOINTS 2>/dev/null || echo "(lsblk unavailable)"
    echo
    echo "## NVMe"
    echo "${nvme:-No NVMe devices detected via lsblk}"
    echo
    echo "Run 'sudo nvme list' and 'sudo smartctl -a /dev/nvme0n1' (or equivalent) for detailed health."
    echo
    echo "See also: tier1-platform-tuning.md (combined report)."
  } > "$LATEST_DIR/tier1-storage.md"

  cat > "$LATEST_DIR/tier1-cpu-runtime-commands.sh" <<CMDS
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Generated Tier 1 CPU runtime tuning commands. Review before execution.
set -euo pipefail

echo "[TUNE] Setting power profile (runtime)..."
if command -v powerprofilesctl >/dev/null 2>&1; then
  powerprofilesctl set ${target_power} || true
else
  echo "[WARN] powerprofilesctl not available."
fi

echo "[TUNE] CPU frequency info (if cpupower present)..."
if command -v cpupower >/dev/null 2>&1; then
  cpupower frequency-info || true
fi
CMDS
  chmod +x "$LATEST_DIR/tier1-cpu-runtime-commands.sh"

  PROFILE="$PROFILE" MODE="$MODE" PERSISTENCE="$PERSISTENCE" \
  TARGET_POWER="$target_power" CPU_MODEL="$cpu_model" GOVERNOR="${governor:-}" \
  MEM_TOTAL="$mem_total" ZRAM_ACTIVE="$zram_active" \
  python3 - <<'PY' > "$LATEST_DIR/tier1-platform-tuning.json"
import json, os
from datetime import datetime, UTC
print(json.dumps({
  "tier": 1,
  "phase": "platform-tuning",
  "timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
  "profile": os.environ.get("PROFILE", "ai370"),
  "mode": os.environ.get("MODE", "safe"),
  "persistence": os.environ.get("PERSISTENCE", "runtime"),
  "cpu": {
    "model": os.environ.get("CPU_MODEL", ""),
    "target_power": os.environ.get("TARGET_POWER", "balanced"),
    "governor": os.environ.get("GOVERNOR", ""),
  },
  "memory": {
    "total": os.environ.get("MEM_TOTAL", ""),
    "zram0": os.environ.get("ZRAM_ACTIVE", ""),
  },
  "storage": {"report": "reports/latest/tier1-storage.md"},
  "compatibility_reports": [
    "tier1-cpu-plan.md",
    "tier1-memory.md",
    "tier1-storage.md",
    "tier1-cpu-runtime-commands.sh",
  ],
}, indent=2))
PY

  echo "[INFO] Wrote tier1-platform-tuning.* (+ compatibility cpu/memory/storage reports)"

  # Package E: optional runtime apply (power profile / cpupower info only; still non-persistent).
  # Honor DRY_RUN / AI370_DRY_RUN from orchestrator --dry-run.
  local apply="${AI370_APPLY_TUNING:-false}"
  local dry="${DRY_RUN:-${AI370_DRY_RUN:-false}}"
  case "$dry" in
    true|1|yes|on) dry="true" ;;
    *) dry="false" ;;
  esac
  case "$apply" in
    true|1|yes|on)
      if [[ "$dry" == "true" ]]; then
        echo "[INFO] AI370_APPLY_TUNING set but dry-run active; not applying runtime tuning."
        python3 - "$LATEST_DIR/tier1-platform-tuning.json" <<'PY' || true
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception:
    raise SystemExit(0)
data["runtime_apply"] = {
    "requested": True,
    "applied": False,
    "dry_run": True,
    "commands": "reports/latest/tier1-cpu-runtime-commands.sh",
}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
      else
        echo "[INFO] Applying runtime tuning commands (AI370_APPLY_TUNING=true)..."
        # shellcheck disable=SC1091
        bash "$LATEST_DIR/tier1-cpu-runtime-commands.sh" || {
          echo "[WARN] Runtime tuning commands exited non-zero; review tier1-cpu-runtime-commands.sh"
        }
        # Mark apply attempt in JSON for observability
        python3 - "$LATEST_DIR/tier1-platform-tuning.json" <<'PY' || true
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception:
    raise SystemExit(0)
data["runtime_apply"] = {
    "requested": True,
    "applied": True,
    "dry_run": False,
    "commands": "reports/latest/tier1-cpu-runtime-commands.sh",
}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
      fi
      ;;
    *)
      echo "[INFO] Platform tuning is plan-only. Apply with ./ai370-optimize.sh stage2-optimize-apply --approve"
      ;;
  esac

  echo "[INFO] 40-platform-tuning.sh complete."
}

main "$@"
