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
5. AI Runtime             ./ai370-optimize.sh ai-runtime [--offline]
6. Acceleration Detection ./ai370-optimize.sh gpu [--offline] && ./ai370-optimize.sh npu [--offline]
7. Guided Enablement      ./ai370-optimize.sh guide [--offline] && ./ai370-optimize.sh execute [--offline]
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

## Offline AI Hardware Optimization Before ComfyUI

Phases 4-7 can be run with `--offline` to focus on local CPU/iGPU/NPU readiness before any ComfyUI setup. Offline mode does not fetch packages, clone repositories, or install ROCm/XRT/Ryzen AI runtime stacks. It expects local artifacts to already be staged.

Default offline artifact paths are configured in `config/offline/ai-runtime.env`:

- `.ai370-ai/wheelhouse/` for Python wheels used by Phase 4.
- `config/ai-runtime/requirements-offline.txt` for the offline Python package list.
- `.ai370-ai/models/` for local smoke-test and representative AI models.
- `.ai370-ai/tools/` for local benchmark/helper binaries.

Recommended offline-first flow:

```bash
./ai370-optimize.sh ai-runtime --offline
./ai370-optimize.sh gpu --offline
./ai370-optimize.sh npu --offline
./ai370-optimize.sh guide --offline
./ai370-optimize.sh execute --offline

# Review, then run generated local validation scripts manually:
bash reports/latest/cpu-onnx-smoke.sh
bash reports/latest/gpu-enable-approved-steps.sh
bash reports/latest/npu-enable-approved-steps.sh
```

Important Phase 4-7 artifacts include:

- `reports/latest/ai-runtime-benchmark.json` and `.md` for CPU/ONNX Runtime smoke benchmarks.
- `reports/latest/gpu-capabilities.json` and `gpu-smoke-benchmark.md` for local iGPU visibility.
- `reports/latest/npu-capabilities.json`, `npu-smoke-benchmark.md`, and `xrt-status.txt` for local NPU/XRT visibility.
- `reports/latest/offline-hardware-readiness.md` and `.json` for the Phase 6 readiness matrix.
- `reports/latest/offline-required-artifacts.md` for the staged artifact checklist.

Run `./ai370-optimize.sh comfyui` only after these reports show the local AI runtime and hardware paths are stable.

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
