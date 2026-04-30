# Production ComfyUI Workflows

These workflows are production-oriented templates for the AI370 local AI stack.

They are intentionally safe and model-name neutral:

- They do not assume ROCm is installed.
- They do not assume XDNA2 NPU runtime is installed.
- They are designed to be imported into ComfyUI after the `70-comfyui-workflows.sh` setup phase.
- Model filenames must be adjusted in the ComfyUI UI to match locally installed files.

## Included Workflows

| Workflow | File | Purpose |
|---|---|---|
| SDXL Base | `sdxl-base-production.json` | Stable text-to-image baseline |
| SDXL Refiner | `sdxl-refiner-production.json` | Base + refiner two-stage workflow |
| SDXL LoRA | `sdxl-lora-production.json` | Style/character LoRA workflow |
| SDXL Upscale | `sdxl-upscale-production.json` | Generate + latent upscale + save |
| ControlNet Canny | `controlnet-canny-production.json` | Edge-guided image generation |
| Image-to-Image | `img2img-production.json` | Controlled variation workflow |

## Recommended Model Layout

```text
.ai370-ai/models/checkpoints/
.ai370-ai/models/vae/
.ai370-ai/models/loras/
.ai370-ai/models/controlnet/
.ai370-ai/models/upscale_models/
```

## AI370 Safety Notes

Start in CPU-safe mode first. After Phase 5/6/7 validation succeeds, test GPU acceleration separately.

The production workflows are structured for repeatability, but model compatibility is controlled by the local model files selected inside ComfyUI.
