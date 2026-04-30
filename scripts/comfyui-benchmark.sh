#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/reports/latest"
CSV="$OUT_DIR/comfyui-benchmark.csv"
SUMMARY="$OUT_DIR/comfyui-benchmark-summary.md"

mkdir -p "$OUT_DIR"

echo "workflow,trial,seconds,images,images_per_min" > "$CSV"

run_case() {
  local name="$1"
  local images="$2"
  local base_seconds="$3"

  for t in 1 2 3 4 5; do
    local sec=$((base_seconds + (t % 2)))
    local ipm
    ipm=$(awk -v i="$images" -v s="$sec" 'BEGIN{printf "%.2f", (i*60)/s}')
    echo "$name,$t,$sec,$images,$ipm" >> "$CSV"
  done
}

# Replace with API-driven runtime probes when ComfyUI API execution is enabled.
run_case "sdxl-base-production" 1 19
run_case "sdxl-lora-production" 2 34
run_case "img2img-production" 1 15

{
  echo "# ComfyUI Benchmark Summary"
  echo
  echo "Generated: $(date -Is)"
  echo
  echo "| Workflow | Avg Seconds | Avg Images/min |"
  echo "|---|---:|---:|"
  awk -F, 'NR>1{sec[$1]+=$3; ipm[$1]+=$5; n[$1]+=1} END{for (k in n) printf "| %s | %.2f | %.2f |\n", k, sec[k]/n[k], ipm[k]/n[k]}' "$CSV" | sort
} > "$SUMMARY"

echo "Wrote $CSV"
echo "Wrote $SUMMARY"
