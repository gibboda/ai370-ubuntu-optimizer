# ai370-ubuntu-optimizer

Ubuntu 26.04 LTS optimization toolkit for the Minisforum EliteMini AI370 and future Ryzen AI systems.

## Primary Target

Default profile:

- Minisforum EliteMini AI370
- AMD Ryzen AI 9 HX 370 / Strix Point
- Radeon 890M integrated GPU
- AMD XDNA2 NPU

## New: Local AI Workflows (ComfyUI)

This repository now includes:

- Prebuilt ComfyUI workflow templates
- Local AI model directory structure
- Safe CPU-first execution model

### Run ComfyUI

```bash
./scripts/70-comfyui-workflows.sh
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

## Design Model

Profile-based + hardware-aware optimization.

## Execution Order

```text
1. Audit
2. Plan
3. Install
4. Validate
5. AI Runtime
6. Acceleration Detection
7. Guided Enablement
8. ComfyUI Workflows
```

## License

GPLv3
