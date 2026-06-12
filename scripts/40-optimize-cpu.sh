#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Tier 1: CPU optimization (runtime power + governor visibility). Generates reviewable commands.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/hardware-detect.sh
source "$PROJECT_ROOT/scripts/lib/hardware-detect.sh"

LATEST_DIR="$PROJECT_ROOT/reports/latest"
mkdir -p "$LATEST_DIR"

main() {
  echo "[INFO] Tier 1 / 40-optimize-cpu.sh"
  echo "[INFO] Profile: $PROFILE  Mode: $MODE  Persistence: $PERSISTENCE"

  if [[ "$PERSISTENCE" == "system" ]]; then
    echo "[ERROR] Persistent CPU tuning not implemented. Use --persistence=runtime."
    exit 2
  fi

  CPU_MODEL="$(detect_cpu_model)"
  GOVERNOR="$(detect_cpu_current_governor)"
  GOVERNORS="$(detect_cpu_governors)"

  target_power="balanced"
  [[ "$MODE" == "aggressive" ]] && target_power="performance"

  cat > "$LATEST_DIR/tier1-cpu-plan.md" <<EOF
# Tier 1 CPU Optimization Plan

- Target power profile: $target_power (runtime only via powerprofilesctl)
- Current governor: ${GOVERNOR:-unknown}
- Available governors: ${GOVERNORS:-unknown}
- CPU: $CPU_MODEL

Review and run the generated commands in:
  reports/latest/tier1-cpu-runtime-commands.sh
EOF

  cat > "$LATEST_DIR/tier1-cpu-runtime-commands.sh" <<'CMDS'
#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Generated Tier 1 CPU runtime tuning commands. Review before execution.
set -euo pipefail

echo "[TUNE] Setting power profile (runtime)..."
if command -v powerprofilesctl >/dev/null 2>&1; then
  powerprofilesctl set TARGET_POWER || true
else
  echo "[WARN] powerprofilesctl not available."
fi

echo "[TUNE] CPU frequency info (if cpupower present)..."
if command -v cpupower >/dev/null 2>&1; then
  cpupower frequency-info || true
fi
CMDS

  # Substitute the chosen profile
  sed -i "s/TARGET_POWER/$target_power/" "$LATEST_DIR/tier1-cpu-runtime-commands.sh"
  chmod +x "$LATEST_DIR/tier1-cpu-runtime-commands.sh"

  echo "[INFO] CPU tuning plan + runnable commands written."
  echo "[INFO] 40-optimize-cpu.sh complete."
}

main "$@"
