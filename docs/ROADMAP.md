# AI370 Ubuntu Optimizer

## Master Implementation Plan

**Document:** `docs/ROADMAP.md`

---

## Roadmap Review Status

**Last reviewed:** 2026-07-04

This repository contains `docs/ROADMAP.md` as the canonical roadmap file. References to `Roadmap.md`, `ROADMAP.md`, or `roadmap.md` should resolve to this document unless a future repository-level roadmap is intentionally added.

### Current Repository Alignment

* Stage 1 is the active foundation stage and must remain the first implementation priority. The implemented Tier 1 command surface in `README.md` and `ai370-optimize.sh` provides `scripts/10-detect-hardware.sh`, `scripts/20-check-bios.sh`, `scripts/25-check-firmware.sh`, `scripts/30-validate-kernel.sh`, `scripts/40-optimize-cpu.sh`, `scripts/50-optimize-memory.sh`, `scripts/60-optimize-storage.sh`, `scripts/70-validate-gpu-stack.sh`, `scripts/75-detect-npu.sh`, `scripts/80-benchmark-local-ai.sh`, and `scripts/90-validate.sh`.
* Stage 2 runtime work is implemented through Tier 2 scripts: `scripts/100-install-pytorch-rocm.sh`, `scripts/110-install-llama-cpp.sh`, `scripts/120-install-ollama.sh`, `scripts/130-install-open-webui.sh`, `scripts/140-benchmark-llm.sh`, and `scripts/150-validate-offline-model-storage.sh`. Offline RAG placeholder scripts `scripts/300-install-anythingllm.sh`, `scripts/310-install-embedding-models.sh`, and `scripts/320-validate-rag.sh` also exist, but Tier 4 is not yet a full implementation.
* Milestone 2.2 is implemented. `scripts/200-install-onnxruntime.sh`, `scripts/210-check-ryzen-ai-software.sh`, `scripts/220-check-vitis-ai-ep.sh`, `scripts/230-benchmark-npu.sh`, and `docs/npu-status.md` are present; benchmark scripts emit either local timing results or actionable diagnostics when NPU providers are unavailable.
* Stage 3 is ongoing. ComfyUI workflow and benchmark artifacts exist, including `scripts/420-benchmark-comfyui.sh` and workflow JSON files under `workflows/comfyui/`. Install/model scripts, documentation, and required workflow subdirectories remain planned.
* Stages 4 and 5 remain planning sections and should not be started until earlier stage validation gates pass.

### Roadmap-Aligned Command Mapping

Roadmap stages are the preferred user-facing names. Legacy `tierN` commands remain supported as aliases so existing automation does not break.

| Roadmap stage | Preferred command group | Legacy tier alias | Status | Command gate |
| --- | --- | --- | --- | --- |
| S1 — Hardware Detection & System Optimization | Stage 1 — Core Platform | Tier 1 | Implemented | `./ai370-optimize.sh stage1` followed by `./ai370-optimize.sh stage1-validate` |
| S2 — AI Runtime Foundation | Stage 2 Runtime / Stage 2 NPU / Stage 2 RAG | Tier 2 / Tier 3 / Tier 4 staged | Ongoing | `stage2`, `stage2-validate`, `stage2-runtime`, `stage2-runtime-validate`, `stage2-npu`, `stage2-npu-validate`; `stage2-rag` placeholder |
| S3 — Offline AI Frameworks & Applications | Stage 3 Offline Applications / Image Generation | Tier 5 plus future app workflows | Ongoing | `stage3-image`, `comfyui-install`, `comfyui-bench`; future `stage3-whisper`, `stage3-code`, and `stage3-apps-validate` |
| S4 — Offline Development Environment | Stage 4 Development Assistant | Future extension | Planning | Not yet available |
| S5 — Maintenance & Lifecycle Management | Stage 5 Lifecycle Operations | Future maintenance workflow | Planning | Not yet available |

---

## Alignment Report

The roadmap aligns with the target offline AI workstation architecture after this review and now preserves a four-layer implementation boundary: Stage 1 for hardware optimization, Stage 2 for AI runtime enablement, Stage 3 for offline AI applications/frameworks, and Stage 4 for the offline development environment. Ubuntu 26.04 LTS, hardware detection, hardware optimization, CPU, memory, storage, AMD GPU, ROCm, Vulkan, AMDXDNA/NPU, and driver validation are represented in Stage 1. Ollama, local LLM management, offline model storage, coding/chat/embedding models, and RAG are represented in Stage 2 and Stage 4. VS Code, Continue, Aider, Git, GitHub CLI, ShellCheck, Ruff, Black, and Pyright are represented in Stage 4. ComfyUI, FLUX, SDXL, VAEs, LoRAs, ControlNet, and upscalers are represented in Stage 3. Installation, validation, startup, shutdown, status, benchmarking, health checks, backup, restore, updating, and workflow launching are represented across Stages 1 through 5.

### Rename Table

| ID | Previous name | Updated name | Reason |
| --- | --- | --- | --- |
| S3-M4 | Benchmark | Image Generation Benchmark | Avoids duplicate Milestone name while preserving execution order. |
| S4-M7 | Benchmark | Code Assistant Benchmark | Avoids duplicate Milestone name while preserving execution order. |

### Dependency Review

* Stage order is correct: hardware foundation first, AI runtime foundation second, offline AI applications/frameworks third, offline development environment fourth, lifecycle management fifth.
* S2 depends on S1 validation because ROCm, Vulkan, AMDXDNA/NPU, Python, Git, and storage readiness must be known before installing AI runtimes, XRT/Ryzen AI packages, ONNX Runtime, and provider diagnostics.
* S3 depends on S2 because Ollama application workloads, embeddings/RAG, Whisper, ComfyUI, and local model workflows require the runtime baseline, provider diagnostics, and model storage conventions.
* S4 depends on S2 because Continue, Aider, and local coding models require Ollama, Git, Python, and offline model storage.
* S5 depends on S1 through S4 because backup, restore, update, regression, and release workflows must cover all installed components.
* Missing dependencies corrected in-place: VS Code tooling now depends on Git/GitHub CLI/Python validation; image-generation models now depend on ComfyUI installation and offline model storage; backup/restore now depends on model manifests and configuration inventories.

### Gap Analysis

* Missing S2 work: explicit XRT/Ryzen AI package installer and CPU/GPU/NPU comparison benchmark automation remain planned; S2-M5 provides offline model manifest/storage validation and chat/coding/embedding model classification.
* Missing S3 work: ComfyUI installer, model installer, VAEs, LoRAs, ControlNet, upscalers, workflow subdirectories, startup/shutdown/status/health automation, Whisper installation/validation, local text-generation validation, embedding validation, and model-management validation.
* Missing S4 work: VS Code installer, Continue config, Aider installation, Git/GitHub CLI validation, ShellCheck/Ruff/Black/Pyright setup, offline code-generation and code-review validation.
* Missing S5 work: update, health-check, backup, restore, regression, release, status, startup/shutdown, workflow-launching, and documentation-maintenance automation.

### New GitHub Issues To Create

1. Implement S2-M2 explicit XRT/Ryzen AI package installation automation.
2. Keep S2-M5 model manifest entries current as required offline models are selected.
3. Implement S3-M1 ComfyUI installer with validation.
4. Implement S3-M2 ComfyUI model installer for FLUX, SDXL, VAEs, LoRAs, ControlNet, and upscalers.
5. Add S3-M3 workflow library subdirectories and launchable workflow definitions.
6. Add S3-M5 ComfyUI startup, shutdown, status, and health-check automation.
7. Implement S3-M6 offline text-generation, embedding, RAG, Whisper, and model-management validators.
8. Implement S4-M1 VS Code, Git, GitHub CLI, and Python development tool validation.
9. Implement S4-M2 Continue and Aider offline configuration.
10. Implement S4-M3 offline coding model installation and manifest entries.
11. Implement S4-M6 ShellCheck, Ruff, Black, Pyright, and offline review reports.
12. Implement S5 maintenance commands for update, health, backup, restore, regression, status, workflow launch, and release validation.

### Additional Milestones Added

* S2-M5 — Offline Model Storage & Model Management
* S3-M5 — Image Generation Automation
* S3-M6 — Offline Text, Embedding, RAG, and Whisper Workloads
* S4-M8 — Offline Development Toolchain Validation
* S5-M8 — Runtime Operations Automation

### Obsolete or Duplicate Items

No obsolete or duplicate Stage or Milestone items were found. Existing roadmap items are retained.

---

## Purpose

This roadmap is the authoritative implementation guide for the AI370 Ubuntu Optimizer project. Its goals are to optimize Ubuntu 26.04 LTS for the Minisforum EliteMini AI370, maximize local AI performance, operate completely offline after installation, build a reproducible installation, support image generation, support offline software development, and produce repeatable benchmark results.

---

## Project Goals

The optimizer shall detect all AI370 hardware automatically, validate BIOS and firmware, configure Ubuntu for maximum AI performance, configure AMD GPU acceleration, configure AMD NPU support when available, install local AI runtimes, install local RAG capability, install offline image generation, install an offline AI coding assistant, produce benchmark reports, and be completely reproducible. Cloud services are optional. Offline operation is the default.

---

## AI Agent Operating Rules

1. Complete work in Stage order. Never skip ahead.
2. Do not begin a Milestone until the previous Milestone passes validation.
3. Every installation script must be idempotent.
4. Never silently ignore errors. Produce actionable diagnostics.
5. Every Milestone must end with validation.
6. Every completed Milestone must update documentation when necessary.
7. Offline functionality has priority. Internet connectivity shall never be required after installation.
8. All scripts must be modular. Each script should perform one logical task.
9. Do not optimize before detection. Always detect first. Always validate second. Optimize third. Benchmark last.
10. Never remove user data.
11. Never overwrite configuration files without creating backups.
12. Benchmark before declaring success.

---

## S1 — Hardware Detection & System Optimization

**Status:** Implemented

### Objective

Prepare Ubuntu 26.04 LTS and the AI370 hardware for local AI workloads.

### Deliverables

* Hardware, BIOS, firmware, kernel, driver, Vulkan, ROCm, AMDXDNA/NPU, CPU, memory, storage, and AI benchmark reports.
* Stage 1 command orchestration through `ai370-optimize.sh` (`stage1`; legacy alias `tier1`).

### Dependencies

* Ubuntu 26.04 LTS target system.
* Shell, coreutils, PCI/USB/storage inventory tools, and report output directory.

### Validation

* Run Stage 1 installation/planning sequence.
* Run Stage 1 validation sequence.
* Confirm CPU, RAM, NVMe, GPU, Vulkan, ROCm, AMDXDNA/NPU, Python, and Git baseline status is captured before later stages.

### Exit Criteria

* `./ai370-optimize.sh stage1` and `./ai370-optimize.sh stage1-validate` complete or report actionable diagnostics.
* No user data is overwritten.
* Reports are written under `reports/latest/`.

### S1-M1 — Hardware Detection

**Status:** Implemented

#### Description

Detect CPU, GPU, NPU, RAM, storage, motherboard, and Ubuntu release baseline.

#### Deliverables

```text
scripts/10-detect-hardware.sh
reports/latest/hardware-inventory.json
reports/latest/hardware-summary.md
```

#### Acceptance Criteria

* CPU, RAM, NVMe/storage, AMD GPU, AMDXDNA/NPU, and motherboard information is detected or explicitly reported unavailable.
* Ubuntu 26.04 LTS compatibility is recorded.

#### Validation Steps

```text
./scripts/10-detect-hardware.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [x] Deliverables implemented.
* [x] Validation report generated.

### S1-M2 — BIOS & Firmware Validation

**Status:** Implemented

#### Description

Validate BIOS 2.01 target, firmware, Secure Boot, and microcode.

#### Deliverables

```text
scripts/20-check-bios.sh
scripts/25-check-firmware.sh
reports/latest/tier1-firmware.json
reports/latest/tier1-firmware.md
reports/latest/tier1-firmware-validation.json
reports/latest/tier1-firmware-validation.md
```

#### Acceptance Criteria

* BIOS, firmware, Secure Boot, and microcode status are recorded.
* Non-target firmware states produce actionable warnings.

#### Validation Steps

```text
./scripts/20-check-bios.sh
./scripts/25-check-firmware.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [x] Deliverables implemented.
* [x] Validation report generated.

### S1-M3 — Kernel & Driver Validation

**Status:** Implemented

#### Description

Validate kernel, Mesa, Vulkan, AMDGPU, ROCm, and AMDXDNA/NPU driver visibility.

#### Deliverables

```text
scripts/30-validate-kernel.sh
scripts/70-validate-gpu-stack.sh
scripts/75-detect-npu.sh
reports/latest/baseline-validation.md
reports/latest/gpu-capabilities.json
reports/latest/npu-capabilities.json
```

#### Acceptance Criteria

* Kernel, AMDGPU, Vulkan, ROCm, and AMDXDNA/NPU status are reported.
* Missing driver support is not hidden and includes remediation guidance.

#### Validation Steps

```text
./scripts/30-validate-kernel.sh
./scripts/70-validate-gpu-stack.sh
./scripts/75-detect-npu.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [x] Deliverables implemented.
* [x] Validation report generated.

### S1-M4 — System Optimization

**Status:** Implemented

#### Description

Plan CPU, memory, zram, storage, filesystem, and I/O scheduler optimizations without removing user data.

#### Deliverables

```text
scripts/40-optimize-cpu.sh
scripts/50-optimize-memory.sh
scripts/60-optimize-storage.sh
reports/latest/tier1-cpu-plan.md
reports/latest/tier1-cpu-runtime-commands.sh
reports/latest/tier1-memory.md
reports/latest/tier1-storage.md
```

#### Acceptance Criteria

* CPU, memory, and storage optimization plans are generated.
* Configuration changes are idempotent and backup-aware.

#### Validation Steps

```text
./scripts/40-optimize-cpu.sh
./scripts/50-optimize-memory.sh
./scripts/60-optimize-storage.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [x] Deliverables implemented.
* [x] Validation report generated.

### S1-M5 — Validation & Benchmarking

**Status:** Implemented

#### Description

Benchmark CPU/GPU/local AI readiness and produce Stage 1 validation summaries.

#### Deliverables

```text
scripts/80-benchmark-local-ai.sh
scripts/90-validate.sh
reports/latest/tier1-local-ai-benchmark.json
reports/latest/tier1-local-ai-benchmark.md
reports/latest/tier1-validation.json
reports/latest/tier1-summary.md
```

#### Acceptance Criteria

* CPU, GPU, Vulkan, ROCm, AMDXDNA/NPU, Python, Git, and local AI benchmark outputs are captured.
* HTML or Markdown summary report is produced.

#### Validation Steps

```text
./scripts/80-benchmark-local-ai.sh
./scripts/90-validate.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [x] Deliverables implemented.
* [x] Validation report generated.

---

## S2 — AI Runtime Foundation

**Status:** Ongoing

### Objective

Prepare and validate the Ryzen AI software stack and local acceleration runtimes before application-level offline AI workloads are installed. This stage is limited to runtime enablement, diagnostics, provider validation, and hardware-backed inference benchmarks so CPU, GPU, and NPU paths can be validated independently from applications.

### Deliverables

* PyTorch ROCm, llama.cpp, Ollama service runtime, Open WebUI runtime dependency checks, XRT, Ryzen AI Software package validation, ONNX Runtime, Vitis AI Execution Provider, XDNA2 runtime validation, CPU/GPU/NPU benchmark comparisons, diagnostics, runtime verification scripts, offline model storage policy, and benchmark reports.

### Dependencies

* S1 exit criteria complete.
* CPU, RAM, NVMe/storage, GPU, Vulkan, ROCm, AMDXDNA/NPU, Python, and Git baseline reports available.

### Validation

* Validate Python, Git, ROCm, Vulkan context, Ollama runtime availability, ONNX Runtime providers, Vitis AI Execution Provider, XRT/Ryzen AI package state, XDNA2/NPU visibility, local model storage, and CPU/GPU/NPU benchmark paths before application workloads depend on them.

### Exit Criteria

* PyTorch ROCm, llama.cpp, Ollama runtime service, ONNX Runtime, Vitis AI EP detection, XRT/Ryzen AI package checks, XDNA2/NPU diagnostics, offline model storage, runtime documentation, and CPU/GPU/NPU comparison benchmarks complete or produce actionable diagnostics.

### S2-M1 — Base AI Runtime

**Status:** Implemented

#### Description

Install PyTorch ROCm, llama.cpp, Ollama, and Open WebUI runtime prerequisites. Application-specific chat, coding, RAG, and image workflows are validated in Stage 3 and Stage 4; this milestone only establishes reusable local inference services and GPU-capable Python/runtime foundations.

#### Deliverables

```text
scripts/100-install-pytorch-rocm.sh
scripts/110-install-llama-cpp.sh
scripts/120-install-ollama.sh
scripts/130-install-open-webui.sh
```

#### Acceptance Criteria

* PyTorch ROCm, llama.cpp, Ollama, and Open WebUI are installable through idempotent scripts.
* Ollama service status is validated after installation.

#### Validation Steps

```text
./scripts/100-install-pytorch-rocm.sh
./scripts/110-install-llama-cpp.sh
./scripts/120-install-ollama.sh
./scripts/130-install-open-webui.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [x] Deliverables implemented.
* [x] Acceptance criteria documented.

### S2-M2 — Ryzen AI NPU Runtime Stack

**Status:** Implemented

#### Description

Install or validate XRT, Ryzen AI Software packages, ONNX Runtime, Vitis AI Execution Provider availability, XDNA2 runtime visibility, NPU diagnostics, NPU benchmark testing, and runtime documentation.

#### Deliverables

```text
scripts/200-install-onnxruntime.sh
scripts/205-install-xrt-ryzen-ai.sh
scripts/210-check-ryzen-ai-software.sh
scripts/220-check-vitis-ai-ep.sh
scripts/230-benchmark-npu.sh
docs/npu-status.md
```

Implemented / Planned:

* Implemented: `scripts/200-install-onnxruntime.sh`, `scripts/205-install-xrt-ryzen-ai.sh`, `scripts/210-check-ryzen-ai-software.sh`, `scripts/220-check-vitis-ai-ep.sh`, `scripts/230-benchmark-npu.sh`, `docs/npu-status.md`
* Planned / Not present: none

#### Acceptance Criteria

* XRT, Ryzen AI Software package state, ONNX Runtime, and Vitis AI EP status are validated.
* XDNA2/AMDXDNA NPU benchmark report is generated or hardware/software limitations are documented.
* Runtime diagnostics explain whether failures are caused by firmware, kernel driver, XRT/Ryzen AI packages, ONNX Runtime providers, or model compatibility.

#### Validation Steps

```text
./scripts/205-install-xrt-ryzen-ai.sh
./scripts/210-check-ryzen-ai-software.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [x] Explicit XRT/Ryzen AI package installer implemented.
* [x] NPU benchmark generated or actionable diagnostics documented.

### S2-M3 — Offline RAG

**Status:** Staged / Placeholder

#### Description

Install AnythingLLM, install embedding models, configure local document storage, and validate offline RAG.

#### Deliverables

```text
scripts/300-install-anythingllm.sh
scripts/310-install-embedding-models.sh
scripts/320-validate-rag.sh
```

#### Acceptance Criteria

* Offline embedding model installation is supported by a complete installer.
* RAG validation does not require internet access after installation.
* `./ai370-optimize.sh stage2-rag` invokes the Stage 2 RAG installer/model/validation sequence instead of printing placeholder guidance (`tier4` remains a legacy alias).

#### Validation Steps

```text
./scripts/300-install-anythingllm.sh
./scripts/310-install-embedding-models.sh
./scripts/320-validate-rag.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented beyond placeholder echo scripts.
* [ ] Validation documented with actionable pass/fail results.

### S2-M4 — AI Runtime Benchmark & Diagnostics

**Status:** Ongoing

#### Description

Benchmark LLM, embedding, ONNX Runtime, ROCm/GPU, CPU, and NPU inference paths where available, then generate runtime diagnostics and comparison reports.

#### Deliverables

```text
scripts/140-benchmark-llm.sh
scripts/240-compare-cpu-gpu-npu.sh
reports/latest/llm-validation.json
reports/latest/llm-validation.md
```

#### Acceptance Criteria

* Ollama and local LLM benchmark paths are validated.
* CPU vs GPU vs NPU comparison benchmarks are captured when providers are available.
* Benchmark report is generated with actionable diagnostics for unavailable providers.

#### Validation Steps

```text
./scripts/140-benchmark-llm.sh
./scripts/240-compare-cpu-gpu-npu.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] All benchmark deliverables implemented.
* [ ] CPU/GPU/NPU comparison script implemented.
* [x] Existing LLM benchmark report generated.

### S2-M5 — Offline Model Storage & Model Management

**Status:** Implemented

#### Description

Define offline model storage, local LLM management, integrity verification, and model categories for chat, coding, and embedding models.

#### Deliverables

```text
configs/models/manifest.yaml
configs/models/storage-policy.md
scripts/150-validate-offline-model-storage.sh
reports/latest/offline-model-storage.md
reports/latest/offline-model-storage.json
```

#### Acceptance Criteria

* Chat, coding, and embedding models have manifest entries and local storage paths.
* Model integrity checks work without internet access.
* Storage capacity and NVMe placement are validated before model download/import.

Implemented / Planned:

* Implemented: `configs/models/manifest.yaml`, `configs/models/storage-policy.md`, `scripts/150-validate-offline-model-storage.sh`, `reports/latest/offline-model-storage.md`, `reports/latest/offline-model-storage.json`
* Planned / Not present: none

#### Validation Steps

```text
./scripts/150-validate-offline-model-storage.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [x] Deliverables implemented.
* [x] Offline model storage validated.

---

## S3 — Offline AI Frameworks & Applications

**Status:** Ongoing

### Objective

Install and validate complete offline AI applications and frameworks without cloud dependency, including local chat/text generation, embeddings, RAG, Whisper transcription, image generation, code models used by applications, model management, and workflow validation.

### Deliverables

* Ollama application workloads, local text-generation inference, local embedding models, model management, Whisper, ComfyUI, FLUX, Stable Diffusion XL, VAEs, LoRAs, ControlNet, upscalers, offline code models, workflow library, benchmark reports, and service automation.

### Dependencies

* S2 runtime foundation exit criteria complete, including Python/GPU/NPU provider diagnostics.
* S2-M5 offline model storage conventions available before large model installation.

### Validation

* Validate Ollama application workloads, local text-generation inference, embeddings, RAG, Whisper, GPU, Vulkan, ROCm, Python, ComfyUI, image/code model paths, workflows, and benchmark output before and after installation.

### Exit Criteria

* Offline chat/text-generation, embeddings/RAG, Whisper, image generation, code model application workflows, and model-management validation complete with no cloud dependency.

### S3-M1 — ComfyUI

**Status:** Planning

#### Description

Install ComfyUI and validate the installation.

#### Deliverables

```text
scripts/400-install-comfyui.sh
```

#### Acceptance Criteria

* ComfyUI installs idempotently.
* Python and GPU acceleration are validated before and after installation.

#### Validation Steps

```text
./scripts/400-install-comfyui.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] ComfyUI validation report generated.

### S3-M2 — Model Installation

**Status:** Planning

#### Description

Install FLUX, Stable Diffusion XL, VAEs, LoRAs, ControlNet, IPAdapter, and upscaler models into offline storage.

#### Deliverables

```text
scripts/410-install-comfyui-models.sh
configs/models/comfyui-models.yaml
```

#### Acceptance Criteria

* FLUX, SDXL, VAEs, LoRAs, ControlNet, and upscalers have manifest entries and local paths.
* Model integrity is validated offline.

#### Validation Steps

```text
./scripts/410-install-comfyui-models.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Offline model integrity validated.

### S3-M3 — Workflow Library

**Status:** Ongoing

#### Description

Provide offline ComfyUI workflow definitions for FLUX, SDXL, ControlNet, LoRA, and upscaling workflows.

#### Deliverables

```text
workflows/comfyui/flux/
workflows/comfyui/sdxl/
workflows/comfyui/controlnet/
workflows/comfyui/upscalers/
```

Implemented / Planned:

* Implemented: `workflows/comfyui/README.md`, `workflows/comfyui/sdxl-basic-text-to-image.json`, `workflows/comfyui/sdxl-lora-text-to-image.json`
* Planned / Not present: `workflows/comfyui/flux/`, `workflows/comfyui/sdxl/`, `workflows/comfyui/controlnet/`, `workflows/comfyui/upscalers/`

#### Acceptance Criteria

* Workflow files are grouped by model family and use local model paths.
* Workflows can be launched without internet access.

#### Validation Steps

```text
find workflows/comfyui -maxdepth 3 -type f | sort
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] All workflow directories implemented.
* [ ] Workflow launch validation implemented.

### S3-M4 — Image Generation Benchmark

**Status:** Ongoing

#### Description

Benchmark FLUX and SDXL, measure VRAM, and generate image-generation benchmark reports.

#### Deliverables

```text
scripts/420-benchmark-comfyui.sh
docs/offline-image-generation.md
reports/latest/comfyui-benchmark.csv
reports/latest/comfyui-benchmark-summary.md
```

Implemented / Planned:

* Implemented: `scripts/420-benchmark-comfyui.sh`, `reports/latest/comfyui-benchmark.csv`, `reports/latest/comfyui-benchmark-summary.md`
* Planned / Not present: `docs/offline-image-generation.md`

#### Acceptance Criteria

* Benchmark report includes model, workflow, latency, VRAM, GPU/ROCm/Vulkan context, and failure diagnostics.

#### Validation Steps

```text
./scripts/420-benchmark-comfyui.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Documentation implemented.
* [x] Benchmark script implemented.

### S3-M5 — Image Generation Automation

**Status:** Missing

#### Description

Add ComfyUI startup, shutdown, status, health-check, and workflow-launching automation.

#### Deliverables

```text
scripts/430-start-comfyui.sh
scripts/431-stop-comfyui.sh
scripts/432-status-comfyui.sh
scripts/433-health-check-comfyui.sh
scripts/434-launch-comfyui-workflow.sh
reports/latest/comfyui-health.md
```

#### Acceptance Criteria

* ComfyUI can be started, stopped, inspected, health-checked, and used to launch a workflow offline.
* Commands are idempotent and produce actionable diagnostics.

#### Validation Steps

```text
./scripts/432-status-comfyui.sh
./scripts/433-health-check-comfyui.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Automation validated.

### S3-M6 — Offline Text, Embedding, RAG, and Whisper Workloads

**Status:** Planned

#### Description

Validate application-level offline AI workloads that sit above the Stage 2 runtime foundation, including Ollama chat/text generation, local text-generation inference, local embedding models, document/RAG workflows, Whisper speech transcription, and model-management behavior.

#### Deliverables

```text
scripts/440-validate-offline-text-generation.sh
scripts/441-validate-offline-embeddings.sh
scripts/442-install-whisper.sh
scripts/443-validate-whisper.sh
scripts/444-validate-model-management.sh
reports/latest/offline-ai-applications.md
```

#### Acceptance Criteria

* Local text-generation inference runs without cloud services.
* Local embedding and RAG workflows use offline model storage only.
* Whisper installs and validates with local models.
* Model-management checks cover chat, embedding, image, audio, and code model categories.
* Performance benchmarking and workflow validation produce actionable reports.

#### Validation Steps

```text
./scripts/440-validate-offline-text-generation.sh
./scripts/441-validate-offline-embeddings.sh
./scripts/443-validate-whisper.sh
./scripts/444-validate-model-management.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Offline application workflow validation generated.

---

## S4 — Offline Development Environment

**Status:** Planning

### Objective

Build a completely offline software engineering environment, including editor installation, local AI coding assistance, repository automation, testing, linting, formatting, documentation generation, release automation, and developer validation.

### Deliverables

* Visual Studio Code, Continue, Aider, local code completion, local code chat, local documentation indexing, Git, GitHub CLI, repository automation, testing tools, ShellCheck, Ruff, Black, Pyright, documentation generation, release automation hooks, offline coding models, repository indexing, code generation, code review, and benchmark reports.

### Dependencies

* S2 local AI runtime and offline model storage available.
* Python and Git baseline validation from S1 complete.

### Validation

* Validate Git, GitHub CLI, Python, VS Code, Continue, Aider, Ollama, coding models, ShellCheck, Ruff, Black, and Pyright before and after installation.

### Exit Criteria

* Offline coding, offline code generation, offline code review, repository indexing, and code assistant benchmarks are complete.

### S4-M1 — VS Code Installation

**Status:** Planning

#### Description

Install VS Code, configure settings, install required extensions, and validate offline extension availability.

#### Deliverables

```text
scripts/500-install-vscode.sh
configs/vscode/settings.json
```

#### Acceptance Criteria

* VS Code launches offline with project settings.
* Required extension artifacts are available locally or documented as installation prerequisites.

#### Validation Steps

```text
./scripts/500-install-vscode.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] VS Code validation generated.

### S4-M2 — Local AI Extension

**Status:** Planning

#### Description

Install Continue, configure Ollama/local inference, and install Aider for terminal-based coding assistance.

#### Deliverables

```text
scripts/510-install-vscode-ai-tools.sh
configs/continue/config.yaml
configs/aider/aider.conf.yml
```

#### Acceptance Criteria

* Continue uses local Ollama models only.
* Aider can run against local coding models without requiring internet access.

#### Validation Steps

```text
./scripts/510-install-vscode-ai-tools.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Continue and Aider validation generated.

### S4-M3 — Coding Models

**Status:** Planning

#### Description

Install Qwen Coder, DeepSeek Coder, StarCoder2, Code Llama, and any selected offline coding embeddings.

#### Deliverables

```text
scripts/520-install-code-models.sh
configs/models/coding-models.yaml
```

#### Acceptance Criteria

* Coding models are stored locally and recorded in the model manifest.
* Ollama or local runtime can list and run each selected coding model offline.

#### Validation Steps

```text
./scripts/520-install-code-models.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Coding model validation generated.

### S4-M4 — Repository Intelligence

**Status:** Planning

#### Description

Index repositories with local embeddings, semantic search, and context optimization.

#### Deliverables

```text
scripts/540-index-repositories.sh
configs/continue/repository-index.yaml
reports/latest/repository-intelligence.md
```

#### Acceptance Criteria

* Repository indexing and local documentation indexing run offline.
* Semantic search uses local embedding models.

#### Validation Steps

```text
./scripts/540-index-repositories.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Repository intelligence report generated.

### S4-M5 — Offline Code Generation

**Status:** Planning

#### Description

Validate local code completion, local code chat, code generation, refactoring, documentation generation, and unit-test generation using local models.

#### Deliverables

```text
scripts/550-validate-code-generation.sh
scripts/551-generate-offline-docs.sh
reports/latest/offline-code-generation.md
```

#### Acceptance Criteria

* Code-completion, code-chat, code-generation, documentation-generation, and unit-test generation tests run offline.
* Results include latency and quality notes for local coding models.

#### Validation Steps

```text
./scripts/550-validate-code-generation.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Code-generation report generated.

### S4-M6 — Offline Code Review

**Status:** Planning

#### Description

Run offline shell, Python, Markdown, and GitHub workflow review using local tools and models.

#### Deliverables

```text
scripts/560-run-offline-code-review.sh
reports/latest/offline-code-review.md
```

#### Acceptance Criteria

* ShellCheck, Ruff, Black, Pyright, Markdown, and workflow checks are integrated where appropriate.
* Reports are generated without requiring cloud AI services.

#### Validation Steps

```text
./scripts/560-run-offline-code-review.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Offline code-review report generated.

### S4-M7 — Code Assistant Benchmark

**Status:** Planning

#### Description

Benchmark completion speed, latency, context retrieval, and code-assistant behavior.

#### Deliverables

```text
scripts/530-benchmark-code-assistant.sh
docs/vscode-offline-code-assistant.md
```

#### Acceptance Criteria

* Benchmark report covers Continue, Aider, Ollama, selected coding models, and repository context retrieval.

#### Validation Steps

```text
./scripts/530-benchmark-code-assistant.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Benchmark report generated.

### S4-M8 — Offline Development Toolchain Validation

**Status:** Missing

#### Description

Install and validate Git, GitHub CLI, testing tools, ShellCheck, Ruff, Black, Pyright, formatting hooks, linting profiles, documentation generation, repository automation, and release automation prerequisites for offline development workflows.

#### Deliverables

```text
scripts/570-install-dev-toolchain.sh
scripts/571-validate-dev-toolchain.sh
configs/dev-tools/toolchain.yaml
reports/latest/dev-toolchain-validation.md
```

#### Acceptance Criteria

* Git, GitHub CLI, testing tools, ShellCheck, Ruff, Black, Pyright, documentation generation tools, and release automation prerequisites are installed or documented as offline prerequisites.
* Tool versions and offline usability are captured in a report.

#### Validation Steps

```text
./scripts/571-validate-dev-toolchain.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Development toolchain validation generated.

---

## S5 — Maintenance & Lifecycle Management

**Status:** Planning

### Objective

Ensure the optimizer remains maintainable, reproducible, healthy, recoverable, and current over time.

### Deliverables

* Update, model management, regression, backup, restore, performance monitoring, release, documentation, startup, shutdown, status, health-check, and workflow-launching automation.

### Dependencies

* S1 through S4 exit criteria complete for full lifecycle coverage.
* Model manifests, configuration inventories, and benchmark baselines available.

### Validation

* Re-run validation and benchmarks after updates, backup/restore, model changes, and release preparation.

### Exit Criteria

* Maintenance commands can update, validate, benchmark, back up, restore, report status, health-check, and prepare releases reproducibly.

### S5-M1 — Software Updates

**Status:** Planning

#### Description

Update Ubuntu packages, AI runtimes, and dependencies with offline-safe controls.

#### Deliverables

```text
scripts/600-update-software.sh
reports/latest/software-update-report.md
```

#### Acceptance Criteria

* Updates are idempotent and report before/after versions.
* Offline constraints and cached package sources are documented.

#### Validation Steps

```text
./scripts/600-update-software.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Update validation report generated.

### S5-M2 — AI Model Management

**Status:** Planning

#### Description

Update LLMs, image models, remove obsolete models, and verify model integrity.

#### Deliverables

```text
scripts/610-manage-ai-models.sh
configs/models/manifest.yaml
reports/latest/model-integrity-report.md
```

#### Acceptance Criteria

* Model add/update/remove operations preserve user data.
* Integrity verification works offline.

#### Validation Steps

```text
./scripts/610-manage-ai-models.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Model integrity report generated.

### S5-M3 — Regression Testing

**Status:** Planning

#### Description

Re-run validation and benchmarks, compare performance, and detect regressions.

#### Deliverables

```text
scripts/620-run-regression-suite.sh
reports/latest/regression-report.md
```

#### Acceptance Criteria

* Stage validation and benchmark deltas are reported.
* Regressions produce actionable diagnostics.

#### Validation Steps

```text
./scripts/620-run-regression-suite.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Regression report generated.

### S5-M4 — Backup & Restore

**Status:** Planning

#### Description

Back up configurations, models, scripts, and validate restoration.

#### Deliverables

```text
scripts/630-backup-ai370.sh
scripts/635-restore-ai370.sh
reports/latest/backup-restore-validation.md
```

#### Acceptance Criteria

* Backup includes configs, manifests, workflow files, and selected model metadata.
* Restore validation verifies services and local model paths.

#### Validation Steps

```text
./scripts/630-backup-ai370.sh
./scripts/635-restore-ai370.sh --validate-only
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Backup/restore validation generated.

### S5-M5 — Performance Monitoring

**Status:** Planning

#### Description

Track CPU, GPU, NPU, memory usage, and storage health.

#### Deliverables

```text
scripts/640-monitor-performance.sh
reports/latest/performance-monitoring.md
```

#### Acceptance Criteria

* Monitoring captures CPU, RAM, NVMe, GPU, Vulkan/ROCm context, NPU, and storage health.
* Reports can be compared to benchmark baselines.

#### Validation Steps

```text
./scripts/640-monitor-performance.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Monitoring report generated.

### S5-M6 — Release Management

**Status:** Planning

#### Description

Prepare releases, update changelog, tag releases, generate release notes, and publish release artifacts.

#### Deliverables

```text
scripts/650-prepare-release.sh
CHANGELOG.md
reports/latest/release-validation.md
```

#### Acceptance Criteria

* Release validation re-runs relevant checks before tagging.
* Changelog and release notes are generated consistently.

#### Validation Steps

```text
./scripts/650-prepare-release.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Release script implemented.
* [x] Changelog file present.

### S5-M7 — Documentation Maintenance

**Status:** Ongoing

#### Description

Update installation guide, optimization guide, roadmap, and architecture documentation.

#### Deliverables

```text
docs/installation.md
docs/optimization.md
docs/ROADMAP.md
docs/architecture.md
reports/latest/documentation-review.md
```

Implemented / Planned:

* Implemented: `docs/ROADMAP.md`
* Planned / Not present: `docs/installation.md`, `docs/optimization.md`, `docs/architecture.md`, `reports/latest/documentation-review.md`

#### Acceptance Criteria

* Documentation remains current with implemented command surfaces.
* Documentation review report identifies stale or missing content.

#### Validation Steps

```text
./scripts/650-prepare-release.sh --docs-only
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] All documentation deliverables implemented.
* [ ] Documentation review report generated.

### S5-M8 — Runtime Operations Automation

**Status:** Missing

#### Description

Provide top-level startup, shutdown, status, health-check, validation, benchmarking, backup, restore, update, and workflow-launching commands across the offline workstation.

#### Deliverables

```text
scripts/660-start-ai370.sh
scripts/661-stop-ai370.sh
scripts/662-status-ai370.sh
scripts/663-health-check-ai370.sh
scripts/664-launch-workflow.sh
reports/latest/ai370-health.md
```

#### Acceptance Criteria

* Top-level operations cover Ollama, Open WebUI, ComfyUI, Continue/Aider dependencies, model storage, GPU/ROCm/Vulkan, and NPU status.
* Commands remain offline-first, idempotent, and diagnostics-driven.

#### Validation Steps

```text
./scripts/662-status-ai370.sh
./scripts/663-health-check-ai370.sh
```

#### Completion Checklist

* [x] Stable ID assigned.
* [x] Unique descriptive name assigned.
* [ ] Deliverables implemented.
* [ ] Runtime operations validation generated.

---

## Status Report

| ID | Name | Status | Reasoning |
| --- | --- | --- | --- |
| S1 | Hardware Detection & System Optimization | Implemented | Current Stage 1 scripts and generated report names are present (`tier1-*` report filenames retained for compatibility). |
| S1-M1 | Hardware Detection | Implemented | Detection script and reports are present. |
| S1-M2 | BIOS & Firmware Validation | Implemented | BIOS and firmware scripts emit current `tier1-firmware*` reports. |
| S1-M3 | Kernel & Driver Validation | Implemented | Kernel, GPU, and NPU validation scripts are present. |
| S1-M4 | System Optimization | Implemented | CPU, memory, and storage scripts emit current `tier1-*` optimization reports. |
| S1-M5 | Validation & Benchmarking | Implemented | Benchmark and validation scripts emit current `tier1-local-ai-benchmark.*` and summary reports. |
| S2 | AI Runtime Foundation | Ongoing | Base runtimes, ONNX Runtime checks, Vitis AI EP detection, NPU benchmark, and model storage exist; explicit XRT/Ryzen AI package installer and CPU/GPU/NPU comparison benchmark remain planned. |
| S2-M1 | Base AI Runtime | Implemented | Required runtime scripts are present. |
| S2-M2 | Ryzen AI NPU Runtime Stack | Ongoing | ONNX Runtime, Ryzen AI checks, Vitis AI EP detection, NPU benchmark, and docs are present; explicit XRT/Ryzen AI package installer remains planned. |
| S2-M3 | Offline RAG | Staged / Placeholder | RAG script filenames are present, but the scripts and `stage2-rag` / `tier4` command are placeholders rather than complete installers/validators. |
| S2-M4 | AI Runtime Benchmark & Diagnostics | Ongoing | LLM benchmark script and reports are present; CPU/GPU/NPU comparison benchmark remains planned. |
| S2-M5 | Offline Model Storage & Model Management | Implemented | Manifest, storage policy, validation script, and reports are present. |
| S3 | Offline AI Frameworks & Applications | Ongoing | Benchmark/workflow artifacts exist; text-generation, embedding/RAG, Whisper, installer, models, docs, and automation remain incomplete. |
| S3-M1 | ComfyUI | Planning | Required installer is represented but not present. |
| S3-M2 | Model Installation | Planning | Required model installer is represented but not present. |
| S3-M3 | Workflow Library | Ongoing | Some workflow files exist; required directories remain missing. |
| S3-M4 | Image Generation Benchmark | Ongoing | Benchmark script exists; documentation remains missing. |
| S3-M5 | Image Generation Automation | Missing | Required startup/shutdown/status/health/workflow automation was not represented before this review. |
| S3-M6 | Offline Text, Embedding, RAG, and Whisper Workloads | Planned | Required offline application workload validators are represented, but implementation files are not present. |
| S4 | Offline Development Environment | Planning | Work is planned; implementation files are not present. |
| S4-M1 | VS Code Installation | Planning | Planned installer/config are not present. |
| S4-M2 | Local AI Extension | Planning | Continue/Aider configs are not present. |
| S4-M3 | Coding Models | Planning | Coding model installer/manifest are not present. |
| S4-M4 | Repository Intelligence | Planning | Planned index/config/report files are not present. |
| S4-M5 | Offline Code Generation | Planning | Planned validation/report files are not present. |
| S4-M6 | Offline Code Review | Planning | Planned review/report files are not present. |
| S4-M7 | Code Assistant Benchmark | Planning | Planned benchmark/doc files are not present. |
| S4-M8 | Offline Development Toolchain Validation | Missing | Required dev tools were not fully represented before this review. |
| S5 | Maintenance & Lifecycle Management | Planning | Lifecycle work is planned; most implementation files are absent. |
| S5-M1 | Software Updates | Planning | Planned update/report files are not present. |
| S5-M2 | AI Model Management | Planning | Planned model-management files are not present. |
| S5-M3 | Regression Testing | Planning | Planned regression files are not present. |
| S5-M4 | Backup & Restore | Planning | Planned backup/restore files are not present. |
| S5-M5 | Performance Monitoring | Planning | Planned monitoring/report files are not present. |
| S5-M6 | Release Management | Planning | Changelog exists; release script/report are not present. |
| S5-M7 | Documentation Maintenance | Ongoing | Roadmap exists; installation, optimization, architecture, and review report are absent. |
| S5-M8 | Runtime Operations Automation | Missing | Required top-level operations automation was not represented before this review. |

---

## Final Verification Checklist

* [x] Every Stage has a unique name.
* [x] Every Milestone has a unique name.
* [x] Stable IDs are assigned consistently.
* [x] Every Stage has an implementation status.
* [x] Every Milestone has an implementation status.
* [x] The roadmap fully supports an offline AI development environment.
* [x] VS Code, Continue, Aider, Ollama, and ComfyUI are represented appropriately.
* [x] Automation is integrated throughout the roadmap.
* [x] Validation exists before and after every major installation or configuration step.

---

## Development Workflow

Every contribution follows this sequence:

1. Read this roadmap.
2. Select the next incomplete Stage.
3. Select the next incomplete Milestone.
4. Complete one Issue at a time.
5. Run validation.
6. Run benchmarks.
7. Update documentation.
8. Commit using Conventional Commits.
9. Open a Pull Request.
10. Merge only after validation succeeds.

This workflow ensures the project evolves in a controlled, reproducible manner while maintaining an offline-first philosophy.
