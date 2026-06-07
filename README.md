# ai370-ubuntu-optimizer

Ubuntu 26.04 LTS optimization toolkit for the Minisforum EliteMini AI370 and future Ryzen AI systems.

## Primary Target

Default profile:

- Minisforum EliteMini AI370
- AMD Ryzen AI 9 HX 370 / Strix Point
- Radeon 890M integrated GPU
- AMD XDNA2 NPU

## Design Model

Profile-based + hardware-aware optimization.

The early Ubuntu baseline flow is intentionally split into three auditable steps:

1. **Inventory** gathers the hardware and OS facts needed to configure Ubuntu.
2. **Baseline plan** validates those facts against the selected profile and writes an explicit machine-readable Ubuntu baseline plan.
3. **Baseline apply** implements only the validated baseline plan, then writes structured post-check results.

This keeps fragile acceleration stacks separate from conservative Ubuntu baseline setup. ROCm, XRT, Ryzen AI runtime packages, and vendor binary installers are detected or guided later; they are not installed by the baseline phase.

## Execution Order

```text
1. Inventory              ./ai370-optimize.sh inventory
2. Baseline Plan          ./ai370-optimize.sh baseline-plan
3. Baseline Apply         ./ai370-optimize.sh baseline-apply --dry-run
                          ./ai370-optimize.sh baseline-apply
4. Baseline Validate      ./ai370-optimize.sh baseline-validate
5. AI Runtime             ./ai370-optimize.sh ai-runtime
6. Acceleration Detection ./ai370-optimize.sh gpu && ./ai370-optimize.sh npu
7. Guided Enablement      ./ai370-optimize.sh guide && ./ai370-optimize.sh execute
8. ComfyUI Workflows      ./ai370-optimize.sh comfyui
9. Final Validate         ./ai370-optimize.sh validate
```

Backward-compatible aliases remain available:

```text
audit   -> inventory
plan    -> baseline-plan
install -> baseline-apply + ai-runtime
```

## Baseline Artifacts

The first phases communicate through `reports/latest/`:

- `hardware-inventory.json` records structured hardware, OS, firmware, power, GPU, NPU, storage, and missing-tool facts.
- `hardware.json` records validation rules and normalized detected hardware.
- `baseline-plan.json` records package groups, runtime settings, post-checks, blocked actions, and recommendations.
- `baseline-postcheck.json` records machine-readable results after baseline apply.
- `baseline-validation.txt` and `baseline-validation.md` summarize whether the applied baseline is ready for AI runtime and acceleration detection.

## New: Local AI Workflows (ComfyUI)

This repository includes:

- Prebuilt ComfyUI workflow templates
- Local AI model directory structure
- Safe CPU-first execution model

### Run ComfyUI

```bash
./ai370-optimize.sh comfyui
./run-comfyui.sh
```

### Import workflows

Drag files from:

```text
workflows/comfyui/
```

Into the ComfyUI interface.

### Models location

```text
.ai370-ai/models/checkpoints/
.ai370-ai/models/loras/
.ai370-ai/models/controlnet/
```

## License

GPLv3
