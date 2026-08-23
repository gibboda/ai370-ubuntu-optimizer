# ComfyUI Performance Benchmarking (Production Workflows)

This benchmark pack is meant for **real operational workflows**, not toy templates.

## Workloads

- `sdxl-base-production.json`: single-image 1024x1024 baseline.
- `sdxl-lora-production.json`: batch-size 2 style workflow.
- `img2img-production.json`: controlled denoise iteration from input asset.

## Method

1. Warm up each workflow once.
2. Run 5 measured trials per workflow.
3. Compute throughput (images/min) from placeholder timings (see note below).
4. Use fixed seeds and fixed prompts for reproducibility.

> **Note:** `scripts/420-benchmark-comfyui.sh` currently uses synthetic placeholder timings rather than
> live wall-clock measurement. Replace the `run_case` calls with API-driven runtime probes once
> ComfyUI queue API execution is enabled in your environment.

## Run Command

```bash
bash scripts/420-benchmark-comfyui.sh
```

## Output

- `reports/latest/comfyui-benchmark.csv`
- `reports/latest/comfyui-benchmark-summary.md`
