# ai370-ubuntu-optimizer

Ubuntu 26.04 LTS optimization toolkit for the Minisforum EliteMini AI370 and future Ryzen AI systems.

## Primary Target

Default profile:

- Minisforum EliteMini AI370
- AMD Ryzen AI 9 HX 370 / Strix Point
- Radeon 890M integrated GPU
- AMD XDNA2 NPU

## Guiding Principles

1. **Offline-first** — Prefer local artifacts, staged wheels, and pre-downloaded models. Network operations are opt-in.
2. **Local inference preferred** — Cloud-only or SaaS dependencies are non-goals.
3. **Hardware validation before application installation** — Establish a validated AI hardware foundation before installing end-user AI runtimes or UIs.
4. **Reproducible automation** — Scripted, profile-driven, with clear reports and dry-run support.
5. **Safe defaults** — Conservative baseline; ROCm / XRT / Ryzen AI stacks require explicit `--accept-amd-acceleration-risk`.
6. **Production-ready benchmarks** — Real measurements, not just presence checks.
7. **Modular architecture** — Tiered design allows adding support for future Ryzen AI systems (new profiles) without rewriting the AI370 implementation.
8. **Future support for additional Ryzen AI systems** — Strict `ai370` profile by default; `generic-ryzen-ai` profile available for broadening.

## AI Stack Tier Architecture

The repository is organized around five AI tiers. Tier 1 is the required foundation. Higher tiers are only installed after lower-tier validation passes (especially: **do not install Tier 5 until Tier 1 + Tier 2 + Tier 3 validation criteria have passed**).

### Tier 1 – Required Core Platform

**Purpose:** Establish a validated AI hardware foundation.

**Key Components:**

- Linux kernel + AMDGPU validation
- AMDXDNA (XDNA2 NPU) detection
- Mesa / Vulkan / ROCm validation
- CPU, memory, and storage optimization
- Benchmark framework

**Stage alignment:** Roadmap Stage 1 maps directly to Tier 1. Complete this tier before starting any Stage 2 / Tier 2+ work. The sequence is detection first, validation second, optimization third, and benchmarking last, matching the roadmap operating rules.

**Canonical commands:**

```bash
./ai370-optimize.sh tier1                  # Run the full Stage 1 / Tier 1 sequence (recommended)
./ai370-optimize.sh tier1-validate         # Final Stage 1 / Tier 1 gate + acceptance checks
```

**Execution order:**

```text
10-detect-hardware -> 20-check-bios -> 25-check-firmware -> 30-validate-kernel
-> 40-optimize-cpu -> 50-optimize-memory -> 60-optimize-storage
-> 70-validate-gpu-stack -> 75-detect-npu -> 80-benchmark-local-ai -> 90-validate
```

## Canonical Roadmap and Status

This repository uses `docs/ROADMAP.md` as the canonical roadmap and implementation status. `README.md` documents usage and tier structure; consult `docs/ROADMAP.md` for the authoritative list of implemented vs planned files, current stage alignment, and contributor guidance.

Current high-level status (see `docs/ROADMAP.md` for details):

- Stage 1 / Tier 1: Implemented and active (hardware detection, BIOS/firmware validation, kernel/driver validation, system optimization, and benchmarking).
- Stage 2 / Tiers 2, 3, and 4: Implemented for the current roadmap scope (Tier 2 runtime scripts, Tier 3 ONNX/Ryzen AI/Vitis AI/NPU validation, and Tier 4 offline RAG/model-storage validation are present).
- Stage 3 / Tier 5: Ongoing (benchmarks and workflows exist; ComfyUI install/model scripts and workflow subdirectories remain planned).

### Implemented / Planned (high level)

Implemented:

- `scripts/10-detect-hardware.sh`, `scripts/20-check-bios.sh`, `scripts/25-check-firmware.sh`, `scripts/30-validate-kernel.sh`
- `scripts/40-optimize-cpu.sh`, `scripts/50-optimize-memory.sh`, `scripts/60-optimize-storage.sh`
- `scripts/70-validate-gpu-stack.sh`, `scripts/75-detect-npu.sh`, `scripts/80-benchmark-local-ai.sh`, `scripts/90-validate.sh`
- `scripts/100-install-pytorch-rocm.sh`, `scripts/110-install-llama-cpp.sh`, `scripts/120-install-ollama.sh`, `scripts/130-install-open-webui.sh`, `scripts/140-benchmark-llm.sh`, `scripts/150-validate-offline-model-storage.sh`
- `scripts/200-install-onnxruntime.sh`, `scripts/210-check-ryzen-ai-software.sh`, `scripts/220-check-vitis-ai-ep.sh`, `scripts/230-benchmark-npu.sh`, `docs/npu-status.md`
- `scripts/300-install-anythingllm.sh`, `scripts/310-install-embedding-models.sh`, `scripts/320-validate-rag.sh`

Planned / Not present in repo:

- `scripts/400-install-comfyui.sh`
- `scripts/410-install-comfyui-models.sh`
- `workflows/comfyui/flux/`, `workflows/comfyui/sdxl/`, `workflows/comfyui/controlnet/`

For the authoritative, up-to-date status and contributor guidance consult `docs/ROADMAP.md`.

**Deliverables (Tier 1 scripts):**

```
scripts/
  10-detect-hardware.sh
  20-check-bios.sh
  25-check-firmware.sh
  30-validate-kernel.sh
  40-optimize-cpu.sh
  50-optimize-memory.sh
  60-optimize-storage.sh
  70-validate-gpu-stack.sh
  75-detect-npu.sh
  80-benchmark-local-ai.sh
  90-validate.sh
```

**Acceptance Criteria:**

- `./ai370-optimize.sh tier1` completes all Stage 1 / Tier 1 scripts in milestone order.
- Radeon 890M detected, or profile variance is clearly reported.
- AMDGPU kernel driver state recorded.
- Vulkan available, or missing support is clearly reported.
- ROCm detected or cleanly reported missing.
- AMDXDNA / XDNA2 NPU detected or cleanly reported missing.
- BIOS 2.01 validation recorded for EliteMini AI370.
- Firmware, Secure Boot, and microcode validation recorded.
- Kernel validation recorded.
- CPU, memory, and storage optimization plans complete without overwriting user data.
- Local AI benchmark output is generated.
- `scripts/90-validate.sh` exits successfully and writes `reports/latest/tier1-validation.json` plus `reports/latest/tier1-summary.md`.

### Tier 2 – Recommended AI Runtime Layer

**Purpose:** Provide local AI execution capability.

**Components:**

- Ollama + llama.cpp
- Open WebUI (optional)
- PyTorch (ROCm where available)
- Hugging Face transformers / tokenizers (local)
- Offline model storage and manifest validation

**Commands:**

```bash
./ai370-optimize.sh tier2 [--offline]
./ai370-optimize.sh tier2-validate [--offline]
```

**Deliverables (Tier 2 scripts):**

```
scripts/
  100-install-pytorch-rocm.sh
  110-install-llama-cpp.sh
  120-install-ollama.sh
  130-install-open-webui.sh
  140-benchmark-llm.sh
  150-validate-offline-model-storage.sh
```

**Acceptance Criteria:**

- PyTorch detects ROCm when available, or records CPU-only / missing ROCm cleanly.
- llama.cpp validates an existing binary or builds from source in online mode when build tools are available.
- Ollama is installed/validated and local models are reported without pulling cloud manifests during validation.
- Open WebUI is installed/validated as an optional local UI and cleanly reported missing when offline.
- Benchmark and Tier 2 gate reports are collected in `reports/latest/` (`tier2-runtime-benchmark.*`, `llm-validation.*`, and `tier2-validation.*`).

### Tier 3 – AMD NPU Enablement

**Purpose:** Enable XDNA2 experimentation and benchmarking.

**Components:**

- ONNX + ONNX Runtime
- Ryzen AI Software (staged artifacts)
- Vitis AI / NPU Execution Provider support
- NPU-specific benchmark suite (ONNX smoke + XRT tools)

**Commands:**

```bash
./ai370-optimize.sh tier3 [--offline]
./ai370-optimize.sh tier3-validate
```

**Acceptance Criteria:**

- ONNX Runtime installed with NPU-capable execution providers visible
- NPU execution path validated (device nodes + XRT or provider check)
- NPU benchmark report generated

**Important:** Tier 3 validation is required before Tier 5 (Generative AI) installation.

### Tier 4 – Local Knowledge Systems

**Components:**

- AnythingLLM (or equivalent local RAG)
- Local embeddings models
- Offline document indexing + retrieval

**Commands (future / staged):**

```bash
./ai370-optimize.sh tier4
```

**Acceptance Criteria:**

- PDF / document ingestion functional
- Offline RAG queries operational against local index

### Tier 5 – Generative AI

**Components:**

- ComfyUI
- Flux, SDXL, ControlNet, IPAdapter, upscaling workflows
- Production benchmarking

**Commands:**

```bash
./ai370-optimize.sh tier5
./ai370-optimize.sh comfyui-install   # alias, gated
```

**Important gate:** Tier 5 installation and benchmarking are blocked (or emit clear error + guidance) until Tier 1, Tier 2, and Tier 3 validation criteria have passed. ComfyUI will default to CPU-safe mode unless acceleration was explicitly installed and re-validated.

**Acceptance Criteria:**

- ComfyUI launches successfully
- Flux (or SDXL) workflow executes
- SDXL / production benchmark report generated (`comfyui-benchmark.csv` + summary)

### Tier Commands (recommended user interface)

```bash
./ai370-optimize.sh tier1                  # Full core platform validation + optimization
./ai370-optimize.sh tier1-validate
./ai370-optimize.sh tier2 [--offline]
./ai370-optimize.sh tier3 [--offline]
./ai370-optimize.sh tier3-validate
./ai370-optimize.sh tier4
./ai370-optimize.sh tier5                  # Requires Tier 1+2+3 validation gate
./ai370-optimize.sh full-stack             # Tier 1 → 2 → 3 → (risk) accel → 4 → 5 with gates
```

Legacy nine-phase commands and aliases remain available for compatibility (see below).

## Legacy Phase Mapping (implementation details)

The tier model is the primary user-facing structure. Under the hood the implementation still uses (and you can invoke) the detailed audit-first phases:

- Tier 1 roughly covers the old Phases 1–6 + final core validation.
- Tier 2 covers old Phase 7 (LLM) + AI runtime.
- Tier 3 covers NPU half of acceleration + ONNX work.
- Tier 5 covers old Phase 8–9 (ComfyUI).

You can still run the classic commands (they continue to work and write the same rich `reports/latest/` artifacts):

```text
hardware | inventory | audit          -> Tier 1 hardware detection
firmware                               -> Tier 1 BIOS check
kernel-amd | baseline-plan | plan      -> Tier 1 kernel + AMD baseline (with --dry-run)
tune                                   -> Tier 1 CPU/RAM/storage optimization
accel-validate | gpu | npu             -> Tier 1 GPU stack + Tier 3 NPU visibility
ai-bench | ai-runtime                  -> Tier 1 local AI benchmark (Tier 2 overlap)
llm-validate                           -> Tier 2
amd-accel-install                      -> Explicit opt-in (used by Tier 3 / Tier 5 paths)
comfyui-install | comfyui              -> Tier 5 (gated)
comfyui-bench                          -> Tier 5
final-validate | validate              -> Tier 1 + overall
install | full-ai-install              -> Multi-tier flows (full-ai-install still requires --accept-amd-acceleration-risk)
```

All phases continue to communicate through `reports/latest/` (JSON + Markdown + text summaries). New tier commands also produce `tierN-*.json` / `tierN-summary.md` artifacts for clear gates.

## Phase Artifacts

- `hardware-inventory.json`, `hardware-audit.txt`, and `hardware-summary.md` record structured Phase 1 hardware, OS, firmware, power, GPU, NPU, storage, and missing-tool facts.
- `firmware-baseline.json` and `firmware-baseline.md` record Phase 2 BIOS, fwupd, and `linux-firmware` baseline state without applying firmware updates.
- `hardware.json`, `baseline-plan.json`, `baseline-postcheck.json`, `baseline-validation.txt`, and `baseline-validation.md` record Phase 3 kernel/AMD baseline validation, approved packages, blocked actions, and post-checks.
- `system-tuning-plan.json`, `system-tuning-plan.md`, and `runtime-tuning-commands.sh` record Phase 4 CPU/RAM/storage recommendations and reviewable runtime-only commands.
- `gpu-capabilities.json`, `gpu-smoke-benchmark.md`, `npu-capabilities.json`, `npu-smoke-benchmark.md`, and `xrt-status.txt` record Phase 5 local ROCm/Vulkan/OpenCL/XDNA visibility.
- `ai-runtime-benchmark.json` and `ai-runtime-benchmark.md` record Phase 6 CPU/ONNX Runtime smoke benchmarks.
- `tier2-pytorch-rocm.json`, `tier2-llama-cpp.json`, `tier2-ollama.json`, `tier2-open-webui.json`, `tier2-runtime-benchmark.json`, `llm-validation.json`, and `tier2-validation.json` record Milestone 2 / Tier 2 runtime installation, local model visibility, and gate status.
- `amd-acceleration-install.json`, `amd-acceleration-install.md`, and `amd-acceleration-env.sh` record the explicit opt-in AMD acceleration installation state when Phase 7.5 is run.
- `comfyui-status.txt` and `comfyui-workflow-guide.md` record Phase 8 installation paths and launch guidance.
- `comfyui-benchmark.csv` and `comfyui-benchmark-summary.md` record Phase 9 workflow benchmark output.

## Offline AI Hardware Optimization Before ComfyUI

Phases 5-7 can be run with `--offline` to focus on local CPU/iGPU/NPU/LLM readiness before any ComfyUI setup. Offline mode does not fetch packages, clone repositories, download models, or install ROCm/XRT/Ryzen AI runtime stacks. It expects local artifacts to already be staged. For Phase 6 specifically, if the configured wheelhouse is missing, the run can continue only when the existing virtual environment already satisfies `configs/ai-runtime/requirements-offline.txt`.

Default offline artifact paths are configured in `configs/offline/ai-runtime.env`:

- `.ai370-ai/wheelhouse/` for Python wheels used by Phase 6.
- `configs/ai-runtime/requirements-offline.txt` for the offline Python package list.
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

- ROCm repository version, repository codename, package list, artifact paths, and ComfyUI acceleration mode are configured in `configs/amd-acceleration.env`.
- The default ROCm repository codename is `resolute`, matching Ubuntu 26.04 LTS (Resolute Raccoon), so the AMD acceleration phase remains aligned with the toolkit target release.
- Ryzen AI / XRT NPU packages are not fetched automatically from AMD account-gated download pages. Stage the required Ubuntu 26.04 `.deb` files and `ryzen_ai-*.tgz` under `.ai370-ai/amd-artifacts/`, or run with `AMD_ARTIFACT_ROOT=/absolute/path/to/amd-artifacts` when the files live outside the checkout.
- For Ubuntu 26.04 Ryzen AI Linux driver bundles, the staged NPU driver files should include names like `xrt_<version>_26.04-amd64-base.deb`, `xrt_<version>_26.04-amd64-base-dev.deb`, `xrt_<version>_26.04-amd64-npu.deb`, and `xrt_plugin.<version>_26.04-amd64-amdxdna.deb`; extract any compressed AMD driver bundle under the artifact root before running `amd-accel-install`. Source-built XDNA packages such as `xrt_<version>_26.04-amd64-xrt.deb` and `xrt_plugin.<version>_ubuntu26.04-x86_64-amdxdna.deb` are also recognized.
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
