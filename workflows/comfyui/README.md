# Prebuilt ComfyUI Workflows

This directory contains starter ComfyUI workflow templates for the AI370 local AI stack.

## Safety Model

These workflows are intentionally model-agnostic and hardware-safe:

- No workflow assumes ROCm is installed.
- No workflow assumes NPU acceleration is available.
- Workflows are designed to run after ComfyUI is launched through `run-comfyui.sh`.
- Acceleration should be enabled only after Phase 5, Phase 6, and Phase 7 validation.

## Included Templates

| File | Purpose |
|---|---|
| `sdxl-basic-text-to-image.json` | Basic SDXL text-to-image workflow |
| `sdxl-lora-text-to-image.json` | SDXL workflow with LoRA loader |
| `sdxl-upscale-workflow.json` | SDXL image generation with upscale stage |
| `controlnet-canny-template.json` | ControlNet Canny template workflow |

## Model Placement

Place models in:

```text
.ai370-ai/models/checkpoints/
.ai370-ai/models/vae/
.ai370-ai/models/loras/
.ai370-ai/models/controlnet/
.ai370-ai/models/upscale_models/
```

## Importing

Open ComfyUI at:

```text
http://127.0.0.1:8188
```

Then drag one of the JSON files into the browser window.

## Notes

These are starter templates. Model filenames inside the workflow may need to be changed to match the exact model files installed locally.


## Production Workflows

For real production graphs and benchmarking guidance, use files under `workflows/comfyui/production/`.
These production JSONs may also include hard-coded local filenames or paths, so review and update them as needed for your environment before assuming they are drop-in runnable.
