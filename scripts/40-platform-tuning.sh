#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Stage 2: combined CPU / memory / storage runtime tuning (Package C merge of 40/50/60).
# S2-M5 plan is the default. S2-M6 apply requires --approve.
# Consumes s1-m5-system-profile.json for CPU/memory identity and consumed_profile.
# Governor/zram/swap remain live runtime observations.
# Opt-in runtime apply: ./ai370-optimize.sh stage2-optimize-apply --approve

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$PROJECT_ROOT/scripts/lib/common.sh"
# shellcheck source=lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

# Do not pass extra action/--approve tokens as OFFLINE (4th standard arg).
ai370_parse_standard_args "${1:-ai370}" "${2:-safe}" "${3:-runtime}"
ai370_init_latest_dir
ai370_require_runtime_persistence "platform tuning"

parse_action_and_approve() {
  ACTION="plan"
  APPROVED="false"
  local arg
  local rest=()
  if [[ $# -ge 4 ]]; then
    rest=("${@:4}")
  fi
  for arg in "${rest[@]}"; do
    case "$arg" in
      plan|--plan) ACTION="plan" ;;
      apply|--apply) ACTION="apply" ;;
      --approve) APPROVED="true" ;;
      true|false|"") ;;
      *)
        echo "[WARN] Ignoring extra argument: $arg"
        ;;
    esac
  done
  case "${AI370_OPTIMIZE_ACTION:-}" in
    apply) ACTION="apply" ;;
    plan) ACTION="plan" ;;
  esac
  case "${AI370_APPROVE:-}" in
    true|1|yes|on) APPROVED="true" ;;
  esac
}

normalize_dry_run() {
  local dry="${DRY_RUN:-${AI370_DRY_RUN:-false}}"
  case "$dry" in
    true|1|yes|on) DRY_RUN="true" ;;
    *) DRY_RUN="false" ;;
  esac
}

main() {
  parse_action_and_approve "$@"
  normalize_dry_run

  echo "[INFO] Stage 2 / 40-platform-tuning.sh (CPU + memory + storage)"
  echo "[INFO] Selected profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE"
  echo "[INFO] Action: $ACTION  Approve: $APPROVED  Dry-run: $DRY_RUN"

  local PROFILE_FILE="$LATEST_DIR/s1-m5-system-profile.json"
  if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "[ERROR] Stage 2 optimize plan/apply requires the canonical Stage 1 profile:"
    echo "[ERROR]   $PROFILE_FILE"
    echo "[ERROR] Run: ./ai370-optimize.sh stage1"
    exit 2
  fi

  if [[ "$ACTION" == "apply" && "$APPROVED" != "true" ]]; then
    echo "[ERROR] Apply requires --approve. Plan first with ./ai370-optimize.sh stage2-optimize-plan."
    echo "[ERROR] AI370_APPLY_TUNING is not sufficient; pass --approve to mutate runtime settings."
    exit 2
  fi

  local cpu_model governor governors target_power mem_total zram_active swap_show nvme
  local platform_id cpu_source mem_source
  governor="$(detect_cpu_current_governor)"
  governors="$(detect_cpu_governors)"
  target_power="balanced"
  [[ "$MODE" == "aggressive" ]] && target_power="performance"

  # CPU model and memory total come from the consumed Stage 1 profile.
  # Governor/zram/swap stay live: they are current runtime state, not hardware identity.
  local identity_json
  identity_json="$(mktemp "${TMPDIR:-/tmp}/s2-optimize-identity.XXXXXX")"
  PROJECT_ROOT="$PROJECT_ROOT" PROFILE_FILE="$PROFILE_FILE" \
  LIVE_CPU="$(detect_cpu_model)" LIVE_MEM="$(detect_memory_total)" \
  python3 - <<'PY' > "$identity_json"
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(os.environ["PROJECT_ROOT"]) / "scripts/lib"))
import firmware_policy

profile = firmware_policy.load_system_profile(Path(os.environ["PROFILE_FILE"]))
cpu = firmware_policy.observed_text((profile.get("cpu") or {}).get("model_name"))
mem_bytes = (profile.get("memory") or {}).get("total_bytes")
mem = None
if isinstance(mem_bytes, int) and mem_bytes > 0:
    gib = mem_bytes / (1024 ** 3)
    mem = f"{gib:.0f}Gi" if gib >= 1 else f"{mem_bytes}B"
print(json.dumps({
    "classified_platform_id": firmware_policy.classified_platform_id(profile),
    "cpu_model": cpu or os.environ.get("LIVE_CPU") or "",
    "cpu_source": "s1-m5-system-profile" if cpu else "live",
    "mem_total": mem or os.environ.get("LIVE_MEM") or "",
    "mem_source": "s1-m5-system-profile" if mem else "live",
}))
PY
  platform_id="$(jq -r '.classified_platform_id // empty' "$identity_json")"
  cpu_model="$(jq -r '.cpu_model // empty' "$identity_json")"
  cpu_source="$(jq -r '.cpu_source // "live"' "$identity_json")"
  mem_total="$(jq -r '.mem_total // empty' "$identity_json")"
  mem_source="$(jq -r '.mem_source // "live"' "$identity_json")"
  rm -f "$identity_json"
  # systemctl is-active prints inactive/failed and exits non-zero; do not append
  # another "inactive" via || echo (that produced "inactive\ninactive").
  zram_active="$(systemctl is-active systemd-zram-setup@zram0.service 2>/dev/null || true)"
  zram_active="${zram_active:-inactive}"
  zram_active="${zram_active%%$'\n'*}"
  swap_show="$(swapon --show --noheadings 2>/dev/null || true)"
  nvme="$(detect_nvme_text)"

  {
    echo "# Tier 1 Platform Tuning Plan"
    echo
    echo "Selected CLI profile: $PROFILE | Classified platform_id: ${platform_id:-unknown}"
    echo "Mode: $MODE | Persistence: $PERSISTENCE"
    echo "Generated: $(ai370_utc_now)"
    echo "CPU/memory identity from Stage 1 profile (governor/zram/swap are live runtime)."
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
    echo "Review and run the generated commands only after --approve:"
    echo "  reports/latest/tier1-cpu-runtime-commands.sh"
  } > "$LATEST_DIR/tier1-platform-tuning.md"

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
# Generated S2-M5 CPU runtime tuning commands. Review before --approve execution.
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

  local facts_json
  facts_json="$(mktemp "${TMPDIR:-/tmp}/s2-m5-facts.XXXXXX")"
  python3 - "$facts_json" "$cpu_model" "$target_power" "${governor:-}" "$cpu_source" \
    "$mem_total" "$zram_active" "$mem_source" <<'PY'
import json, sys
path = sys.argv[1]
json.dump({
    "cpu_model": sys.argv[2],
    "target_power": sys.argv[3],
    "governor": sys.argv[4],
    "cpu_source": sys.argv[5],
    "mem_total": sys.argv[6],
    "zram_active": sys.argv[7],
    "mem_source": sys.argv[8],
}, open(path, "w"), indent=2)
PY

  python3 "$PROJECT_ROOT/scripts/s2-m5-publish-optimization-plan.py" \
    --profile "$PROFILE_FILE" \
    --facts "$facts_json" \
    --output "$LATEST_DIR/s2-m5-optimization-plan.json" \
    --compat-output "$LATEST_DIR/tier1-platform-tuning.json" \
    --compat-markdown "$LATEST_DIR/s2-m5-optimization-plan.md" \
    --markdown-swap "$swap_show" \
    --markdown-nvme "${nvme:-}" \
    --cli-profile "$PROFILE" \
    --mode "$MODE" \
    --persistence "$PERSISTENCE"
  rm -f "$facts_json"

  echo "[INFO] Wrote s2-m5-optimization-plan.json and compatibility tier1-platform-tuning.*"

  if [[ "$ACTION" != "apply" ]]; then
    if [[ "${AI370_APPLY_TUNING:-false}" == "true" ]]; then
      echo "[INFO] AI370_APPLY_TUNING is ignored without apply --approve."
    fi
    echo "[INFO] Platform tuning is plan-only. Apply with ./ai370-optimize.sh stage2-optimize-apply --approve"
    echo "[INFO] 40-platform-tuning.sh complete."
    return 0
  fi

  local applied="false"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[INFO] Approved apply with dry-run active; not applying runtime tuning."
  else
    echo "[INFO] Applying runtime tuning commands (--approve)..."
    # shellcheck disable=SC1091
    bash "$LATEST_DIR/tier1-cpu-runtime-commands.sh" || {
      echo "[WARN] Runtime tuning commands exited non-zero; review tier1-cpu-runtime-commands.sh"
    }
    applied="true"
  fi

  python3 "$PROJECT_ROOT/scripts/s2-m6-publish-optimization-application.py" \
    --profile "$PROFILE_FILE" \
    --plan "$LATEST_DIR/s2-m5-optimization-plan.json" \
    --output "$LATEST_DIR/s2-m6-optimization-application.json" \
    --compat-output "$LATEST_DIR/tier1-platform-tuning.json" \
    --cli-profile "$PROFILE" \
    --dry-run "$DRY_RUN" \
    --applied "$applied"

  echo "[INFO] Wrote s2-m6-optimization-application.json"
  echo "[INFO] 40-platform-tuning.sh complete."
}

main "$@"
