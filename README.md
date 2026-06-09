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

The toolkit is organized into a nine-phase, audit-first flow. Hardware and firmware facts are captured before conservative kernel/AMD baseline work, tuning is runtime-only by default, and fragile acceleration stacks remain validation-gated. ROCm, XRT, Ryzen AI runtime packages, vendor binary installers, and model downloads are detected or guided; they are not installed automatically by the baseline, tuning, validation, or LLM phases.

## Nine-Phase Execution Order

```text
Phase 1 — Hardware detection                 ./ai370-optimize.sh hardware
Phase 2 — BIOS / firmware baseline           ./ai370-optimize.sh firmware
Phase 3 — Kernel + AMD driver baseline       ./ai370-optimize.sh kernel-amd --dry-run
                                             ./ai370-optimize.sh kernel-amd
Phase 4 — CPU / RAM / storage tuning         ./ai370-optimize.sh tune
Phase 5 — ROCm / Vulkan / OpenCL validation  ./ai370-optimize.sh accel-validate [--offline]
Phase 6 — Local AI benchmark suite           ./ai370-optimize.sh ai-bench [--offline]
Phase 7 — Ollama / llama.cpp validation      ./ai370-optimize.sh llm-validate [--offline]
Phase 7.5 — Explicit AMD acceleration install ./ai370-optimize.sh amd-accel-install --accept-amd-acceleration-risk
Phase 8 — ComfyUI installation                ./ai370-optimize.sh comfyui-install
Phase 9 — ComfyUI workflow benchmarking       ./ai370-optimize.sh comfyui-bench
Final validation                              ./ai370-optimize.sh final-validate
```

Backward-compatible aliases remain available:

```text
inventory, audit    -> hardware
baseline-plan, plan -> legacy baseline planning only
baseline-apply      -> legacy baseline apply only
baseline-validate   -> legacy baseline validation only
ai-runtime          -> ai-bench
gpu && npu          -> accel-validate components
comfyui             -> comfyui-install
validate            -> final-validate
install             -> kernel-amd + ai-bench
full-ai-install     -> safe readiness + opt-in AMD acceleration + ComfyUI + validation
```

## Phase Artifacts

The phases communicate through `reports/latest/`:

- `hardware-inventory.json`, `hardware-audit.txt`, and `hardware-summary.md` record structured Phase 1 hardware, OS, firmware, power, GPU, NPU, storage, and missing-tool facts.
- `firmware-baseline.json` and `firmware-baseline.md` record Phase 2 BIOS, fwupd, and `linux-firmware` baseline state without applying firmware updates.
- `hardware.json`, `baseline-plan.json`, `baseline-postcheck.json`, `baseline-validation.txt`, and `baseline-validation.md` record Phase 3 kernel/AMD baseline validation, approved packages, blocked actions, and post-checks.
- `system-tuning-plan.json`, `system-tuning-plan.md`, and `runtime-tuning-commands.sh` record Phase 4 CPU/RAM/storage recommendations and reviewable runtime-only commands.
- `gpu-capabilities.json`, `gpu-smoke-benchmark.md`, `npu-capabilities.json`, `npu-smoke-benchmark.md`, and `xrt-status.txt` record Phase 5 local ROCm/Vulkan/OpenCL/XDNA visibility.
- `ai-runtime-benchmark.json` and `ai-runtime-benchmark.md` record Phase 6 CPU/ONNX Runtime smoke benchmarks.
- `llm-validation.json` and `llm-validation.md` record Phase 7 local Ollama, llama.cpp, and GGUF model visibility.
- `amd-acceleration-install.json`, `amd-acceleration-install.md`, and `amd-acceleration-env.sh` record the explicit opt-in AMD acceleration installation state when Phase 7.5 is run.
- `comfyui-status.txt` and `comfyui-workflow-guide.md` record Phase 8 installation paths and launch guidance.
- `comfyui-benchmark.csv` and `comfyui-benchmark-summary.md` record Phase 9 workflow benchmark output.

## Offline AI Hardware Optimization Before ComfyUI

Phases 5-7 can be run with `--offline` to focus on local CPU/iGPU/NPU/LLM readiness before any ComfyUI setup. Offline mode does not fetch packages, clone repositories, download models, or install ROCm/XRT/Ryzen AI runtime stacks. It expects local artifacts to already be staged.

Default offline artifact paths are configured in `config/offline/ai-runtime.env`:

- `.ai370-ai/wheelhouse/` for Python wheels used by Phase 6.
- `config/ai-runtime/requirements-offline.txt` for the offline Python package list.
- `.ai370-ai/models/` for local smoke-test, representative AI, and GGUF models.
- `.ai370-ai/tools/` for local benchmark/helper binaries such as approved llama.cpp builds.

Recommended offline-first flow:

```bash
./ai370-optimize.sh accel-validate --offline
./ai370-optimize.sh ai-bench --offline
./ai370-optimize.sh llm-validate --offline
./ai370-optimize.sh guide --offline
./ai370-optimize.sh execute --offline

# Review, then run generated local validation scripts manually:
bash reports/latest/cpu-onnx-smoke.sh
bash reports/latest/gpu-enable-approved-steps.sh
bash reports/latest/npu-enable-approved-steps.sh
```

Run `./ai370-optimize.sh comfyui-install` only after these reports show the local AI runtime and hardware paths are stable.

## Opt-in Full AMD Acceleration Before ComfyUI

The default flow remains conservative. If you explicitly want the toolkit to install AMD ROCm GPU packages plus staged XRT/Ryzen AI NPU artifacts before ComfyUI, use the risk-acknowledged acceleration phase:

```bash
# Online ROCm path; XRT/Ryzen AI artifacts still need to be staged locally.
./ai370-optimize.sh amd-accel-install --accept-amd-acceleration-risk
./ai370-optimize.sh accel-validate
./ai370-optimize.sh comfyui-install
```

For an end-to-end safe-readiness + AMD-acceleration + ComfyUI flow:

```bash
./ai370-optimize.sh full-ai-install --accept-amd-acceleration-risk
```

Important constraints:

- ROCm repository version, repository codename, package list, artifact paths, and ComfyUI acceleration mode are configured in `config/amd-acceleration.env`.
- The default ROCm repository codename is `noble` because AMD's current package-manager examples target Ubuntu 24.04; update the config when AMD publishes a supported Ubuntu 26.04 repository.
- Ryzen AI / XRT NPU packages are not fetched automatically from AMD account-gated download pages. Stage the required `.deb` files and `ryzen_ai-*.tgz` under `.ai370-ai/amd-artifacts/` or override `AMD_ARTIFACT_ROOT`.
- ComfyUI is generated without `--cpu` only after the explicit AMD acceleration phase has completed and ROCm remains visible in the Phase 5 GPU validation report. Otherwise it stays CPU-safe.


## Local AI Workflows (ComfyUI)

This repository includes:

- Starter ComfyUI workflow templates
- Production-oriented workflow examples
- Local AI model directory structure
- Safe CPU-first execution model

### Run ComfyUI

```bash
./ai370-optimize.sh comfyui-install
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

The workflow templates are model-agnostic starters. Review `workflows/comfyui/README.md` and `workflows/comfyui/production/README.md` before treating any JSON workflow as drop-in runnable for your local model filenames.

## License

GPLv3
