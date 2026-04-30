# ComfyUI Performance Benchmarking (Production Workflows)

This benchmark pack is meant for **real operational workflows**, not toy templates.

## Workloads

- `sdxl-base-production.json`: single-image 1024x1024 baseline.
- `sdxl-lora-production.json`: batch-size 2 style workflow.
- `img2img-production.json`: controlled denoise iteration from input asset.

## Method

1. Warm up each workflow once.
2. Run 5 measured trials per workflow.
3. Capture wall clock seconds and compute throughput (images/min).
4. Use fixed seeds and fixed prompts for reproducibility.

## Run Command

```bash
bash scripts/comfyui-benchmark.sh
```

## Output

- `reports/latest/comfyui-benchmark.csv`
- `reports/latest/comfyui-benchmark-summary.md`
