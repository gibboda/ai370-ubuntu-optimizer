# AI370 Ubuntu Optimizer

## Master Implementation Plan

**Document:** `docs/ROADMAP.md`

---

## Roadmap Review Status

**Last reviewed:** 2026-06-27

This repository contains `docs/ROADMAP.md` as the canonical roadmap file. References to `Roadmap.md`, `ROADMAP.md`, or `roadmap.md` should resolve to this document unless a future repository-level roadmap is intentionally added.

### Current Repository Alignment

* Stage 1 is the active foundation stage and must remain the first implementation priority. The implemented Tier 1 command surface in `README.md` and `ai370-optimize.sh` provides `scripts/10-detect-hardware.sh`, `scripts/20-check-bios.sh`, `scripts/25-check-firmware.sh`, `scripts/30-validate-kernel.sh`, `scripts/40-optimize-cpu.sh`, `scripts/50-optimize-memory.sh`, `scripts/60-optimize-storage.sh`, `scripts/70-validate-gpu-stack.sh`, `scripts/75-detect-npu.sh`, `scripts/80-benchmark-local-ai.sh`, and `scripts/90-validate.sh`.
* Stage 1 now includes the dedicated firmware validation script listed below: `scripts/25-check-firmware.sh`.
* Stage 2 runtime work is partially implemented through Tier 2 scripts: `scripts/100-install-pytorch-rocm.sh`, `scripts/110-install-llama-cpp.sh`, `scripts/120-install-ollama.sh`, `scripts/130-install-open-webui.sh`, and `scripts/140-benchmark-llm.sh`. Offline RAG scripts `scripts/300-install-anythingllm.sh`, `scripts/310-install-embedding-models.sh`, and `scripts/320-validate-rag.sh` also exist.
* Milestone 2.2 is not fully aligned with the implemented Tier 3 structure. `scripts/210-check-ryzen-ai-software.sh` exists, but `scripts/200-install-onnxruntime.sh`, `scripts/220-check-vitis-ai-ep.sh`, `scripts/230-benchmark-npu.sh`, and `docs/npu-status.md` are not present.
* Stage 3 has ComfyUI workflow and benchmark artifacts, including `scripts/420-benchmark-comfyui.sh` and workflow JSON files under `workflows/comfyui/`. The listed install/model scripts (`scripts/400-install-comfyui.sh`, `scripts/410-install-comfyui-models.sh`), documentation file (`docs/offline-image-generation.md`), and required workflow subdirectories (`flux/`, `sdxl/`, `controlnet/`) are not currently present.
* Stages 4 and 5 remain forward-looking roadmap sections and should not be started until earlier stage validation gates pass.

### Review Findings

* Stage 1 is aligned with the implemented Tier 1 command surface in `README.md` and `ai370-optimize.sh`; Stage 1 remains the authoritative roadmap language, and Tier 1 remains the primary user-facing command language for the same foundation work.
* Several required files outside Stage 1 are planned rather than implemented. Required-file lists should distinguish between `Implemented` and `Planned / Not present` deliverables so contributors do not mistake roadmap intent for current command availability.
* Stage 4 repository-intelligence, offline-code-generation, and offline-code-review milestones now include planned script/config/report paths so future implementation can stay validation-backed.
* Stage 5 maintenance milestones now define planned command entry points and report artifacts before release-management work starts.

### Stage-to-Tier Mapping

The roadmap uses **Stages** for implementation order. The command-line interface and `README.md` use **Tiers** for the user workflow. For Stage 1 work, these terms are intentionally equivalent:

| Roadmap stage | User-facing tier | Status | Command gate |
| --- | --- | --- | --- |
| Stage 1 — Hardware Detection & System Optimization | Tier 1 — Required Core Platform | Implemented and active | `./ai370-optimize.sh tier1` followed by `./ai370-optimize.sh tier1-validate` |
| Stage 2 — Local AI Runtime & AI Optimization Software | Tier 2 / Tier 3 / Tier 4 | Partially implemented / staged | `tier2`, `tier2-validate`, `tier3`, `tier3-validate`, `tier4` |
| Stage 3 — Offline Image Generation | Tier 5 — Generative AI | Partially implemented / gated | `tier5`, `comfyui-install`, `comfyui-bench` |
| Stage 4 — Offline VS Code & Code Assistant | Future tier or extension | Planned | Not yet available |
| Stage 5 — Maintenance & Release Validation | Future maintenance workflow | Planned | Not yet available |

### Review Guidance

When updating this roadmap, prefer small, validation-backed changes that keep the document synchronized with the implemented command surface in `README.md` and `ai370-optimize.sh`. Any new required file listed in a milestone should either exist in the same change or be clearly marked as planned work.

---

## Purpose

This roadmap is the authoritative implementation guide for the AI370 Ubuntu Optimizer project.

Its goals are to:

* Optimize Ubuntu for the Minisforum EliteMini AI370
* Maximize local AI performance
* Operate completely offline after installation
* Build a reproducible installation
* Support image generation
* Support offline software development
* Produce repeatable benchmark results

Every implementation should follow this roadmap.

---

## Project Goals

The optimizer shall:

* Detect all AI370 hardware automatically.
* Validate BIOS and firmware.
* Configure Ubuntu for maximum AI performance.
* Configure AMD GPU acceleration.
* Configure AMD NPU support when available.
* Install local AI runtimes.
* Install local RAG capability.
* Install offline image generation.
* Install an offline AI coding assistant.
* Produce benchmark reports.
* Be completely reproducible.

Cloud services are optional.

Offline operation is the default.

---

## AI Agent Operating Rules

Every AI assistant working on this repository shall follow these rules.

## Rule 1

Complete work in Stage order.

Never skip ahead.

---

## Rule 2

Do not begin a Milestone until the previous Milestone passes validation.

---

## Rule 3

Every installation script must be idempotent.

Running the script multiple times shall not damage the installation.

---

## Rule 4

Never silently ignore errors.

Produce actionable diagnostics.

---

## Rule 5

Every Milestone must end with validation.

---

## Rule 6

Every completed Milestone must update documentation when necessary.

---

## Rule 7

Offline functionality has priority.

Internet connectivity shall never be required after installation.

---

## Rule 8

All scripts must be modular.

Each script should perform one logical task.

---

## Rule 9

Do not optimize before detection.

Always detect first.

Always validate second.

Optimize third.

Benchmark last.

---

## Rule 10

Never remove user data.

---

## Rule 11

Never overwrite configuration files without creating backups.

---

## Rule 12

Benchmark before declaring success.

---

## Stage 1 — Hardware Detection & System Optimization

## Objective (Stage 1)

Prepare Ubuntu and the AI370 hardware for local AI workloads.

---

## Milestone 1.1 — Hardware Detection

### Hardware Issues

* Detect CPU
* Detect GPU
* Detect NPU
* Detect RAM
* Detect Storage
* Detect Motherboard
* Generate hardware report

### Implemented Files (Hardware)

```text
scripts/10-detect-hardware.sh
```

### Stage 1 / Tier 1 Output

```text
reports/latest/hardware-inventory.json
reports/latest/hardware-summary.md
```

---

## Milestone 1.2 — BIOS & Firmware Validation

### BIOS & Firmware Issues

* Validate BIOS 2.01
* Validate firmware
* Validate Secure Boot
* Validate microcode

### Implemented Files (BIOS & Firmware)

```text
scripts/20-check-bios.sh
scripts/25-check-firmware.sh
```

### Stage 1 / Tier 1 Output

```text
reports/latest/firmware-baseline.json
reports/latest/firmware-baseline.md
```

---

## Milestone 1.3 — Kernel & Driver Validation

### Kernel & Driver Issues

* Validate kernel
* Validate Mesa
* Validate Vulkan
* Validate AMDGPU
* Validate ROCm
* Validate AMDXDNA

### Implemented Files (Kernel & Driver)

```text
scripts/30-validate-kernel.sh
scripts/70-validate-gpu-stack.sh
scripts/75-detect-npu.sh
```

### Stage 1 / Tier 1 Output

```text
reports/latest/baseline-validation.md
reports/latest/gpu-capabilities.json
reports/latest/npu-capabilities.json
```

---

## Milestone 1.4 — System Optimization

### System Optimization Issues

* CPU optimization
* Memory optimization
* zram
* Storage optimization
* Filesystem tuning
* I/O scheduler tuning

### Implemented Files (System Optimization)

```text
scripts/40-optimize-cpu.sh
scripts/50-optimize-memory.sh
scripts/60-optimize-storage.sh
```

### Stage 1 / Tier 1 Output

```text
reports/latest/system-tuning-plan.json
reports/latest/system-tuning-plan.md
reports/latest/runtime-tuning-commands.sh
```

---

## Milestone 1.5 — Validation & Benchmarking

### Validation & Benchmarking Issues

* CPU benchmark
* GPU benchmark
* AI benchmark
* Validation summary
* HTML report

### Implemented Files (Validation & Benchmarking)

```text
scripts/80-benchmark-local-ai.sh
scripts/90-validate.sh
reports/
```

### Stage 1 / Tier 1 Output

```text
reports/latest/ai-runtime-benchmark.json
reports/latest/ai-runtime-benchmark.md
reports/latest/tier1-validation.json
reports/latest/tier1-summary.md
```

### Acceptance Criteria (Stage 1 / Tier 1)

* `./ai370-optimize.sh tier1` completes the full Stage 1 sequence in milestone order.
* `./ai370-optimize.sh tier1-validate` runs `scripts/90-validate.sh` as the final Stage 1 gate.
* BIOS validation is recorded for the EliteMini AI370 target.
* Firmware, Secure Boot, and microcode validation are recorded.
* Radeon 890M is detected, or non-AI370 profile variance is reported clearly.
* AMDGPU kernel driver state is recorded.
* Vulkan is operational, or missing Vulkan support is reported clearly.
* ROCm is detected when present, or missing ROCm is reported clearly without hiding the failure.
* AMDXDNA / XDNA2 NPU is detected, or missing NPU support is reported clearly.
* CPU, memory, and storage optimization plans complete without overwriting user data.
* Local AI benchmark output is generated.
* Validation writes `reports/latest/tier1-validation.json` and `reports/latest/tier1-summary.md`.

---

## Stage 2 — Local AI Runtime & AI Optimization Software

## Objective (Stage 2)

Install all local AI infrastructure.

---

## Milestone 2.1 — AI Runtime

### AI Runtime Issues

* Install PyTorch ROCm
* Install llama.cpp
* Install Ollama
* Install Open WebUI

### Required Files (AI Runtime)

```text
scripts/100-install-pytorch-rocm.sh
scripts/110-install-llama-cpp.sh
scripts/120-install-ollama.sh
scripts/130-install-open-webui.sh
```

---

## Milestone 2.2 — AMD AI Stack

### AMD AI Stack Issues

* Install ONNX Runtime
* Detect Ryzen AI Software
* Detect Vitis AI Execution Provider
* Benchmark NPU

### Required Files (AMD AI Stack)

```text
scripts/200-install-onnxruntime.sh
scripts/210-check-ryzen-ai-software.sh
scripts/220-check-vitis-ai-ep.sh
scripts/230-benchmark-npu.sh
docs/npu-status.md
```

Implemented / Planned:

* Implemented: `scripts/210-check-ryzen-ai-software.sh`
* Planned / Not present: `scripts/200-install-onnxruntime.sh`, `scripts/220-check-vitis-ai-ep.sh`, `scripts/230-benchmark-npu.sh`, `docs/npu-status.md`

---

## Milestone 2.3 — Offline RAG

### Offline RAG Issues

* Install AnythingLLM
* Install embedding models
* Configure local document storage
* Validate offline RAG

### Required Files (Offline RAG)

```text
scripts/300-install-anythingllm.sh
scripts/310-install-embedding-models.sh
scripts/320-validate-rag.sh
```

---

## Milestone 2.4 — AI Runtime Benchmark

### AI Runtime Benchmark Issues

* LLM benchmark
* Embedding benchmark
* Inference benchmark
* Benchmark report

### Required Files (AI Runtime Benchmark)

```text
scripts/140-benchmark-llm.sh
reports/
```

### Acceptance Criteria (Stage 2)

* Ollama operational
* Open WebUI operational
* llama.cpp operational
* PyTorch ROCm operational
* ONNX Runtime operational
* Offline RAG operational
* Benchmark completed

---

## Stage 3 — Offline Image Generation

## Objective (Stage 3)

Install a complete offline image-generation environment.

---

## Milestone 3.1 — ComfyUI

### ComfyUI Issues

* Install ComfyUI
* Validate installation

### Required Files (ComfyUI)

```text
scripts/400-install-comfyui.sh
```

Implemented / Planned:

* Planned / Not present: `scripts/400-install-comfyui.sh`

---

## Milestone 3.2 — Model Installation

### Model Installation Issues

* Install FLUX
* Install SDXL
* Install ControlNet
* Install IPAdapter

### Required Files (Model Installation)

```text
scripts/410-install-comfyui-models.sh
```

Implemented / Planned:

* Planned / Not present: `scripts/410-install-comfyui-models.sh`

---

## Milestone 3.3 — Workflow Library

### Required Directories

```text
workflows/comfyui/flux/
workflows/comfyui/sdxl/
workflows/comfyui/controlnet/
```

Implemented / Planned:

* Planned / Not present: `workflows/comfyui/flux/`, `workflows/comfyui/sdxl/`, `workflows/comfyui/controlnet/`

---

## Milestone 3.4 — Benchmark

### ComfyUI Benchmark Issues

* Benchmark FLUX
* Benchmark SDXL
* Measure VRAM
* Generate report

### Required Files (ComfyUI Benchmark)

```text
scripts/420-benchmark-comfyui.sh
docs/offline-image-generation.md
```

Implemented / Planned:

* Implemented: `scripts/420-benchmark-comfyui.sh`
* Planned / Not present: `docs/offline-image-generation.md`

### Acceptance Criteria (Stage 3)

* ComfyUI operational
* FLUX operational
* SDXL operational
* Benchmark generated

---

## Stage 4 — Offline VS Code & Code Assistant

## Objective (Stage 4)

Build a completely offline software engineering environment.

---

## Milestone 4.1 — VS Code Installation

### VS Code Installation Issues

* Install VS Code
* Configure settings
* Install required extensions

### Required Files (VS Code Installation)

```text
scripts/500-install-vscode.sh
configs/vscode/settings.json
```

---

## Milestone 4.2 — Local AI Extension

### Local AI Extension Issues

* Install Continue
* Configure Ollama
* Configure local inference

### Required Files (Local AI Extension)

```text
scripts/510-install-vscode-ai-tools.sh
configs/continue/config.yaml
```

---

## Milestone 4.3 — Coding Models

### Coding Models Issues

* Install Qwen Coder
* Install DeepSeek Coder
* Install StarCoder2
* Install Code Llama

### Required Files (Coding Models)

```text
scripts/520-install-code-models.sh
```

---

## Milestone 4.4 — Repository Intelligence

### Repository Intelligence Issues

* Repository indexing
* Local embeddings
* Semantic search
* Context optimization

### Required Files (Repository Intelligence)

```text
scripts/540-index-repositories.sh
configs/continue/repository-index.yaml
reports/latest/repository-intelligence.md
```

Implemented / Planned:

* Planned / Not present: `scripts/540-index-repositories.sh`, `configs/continue/repository-index.yaml`, `reports/latest/repository-intelligence.md`

---

## Milestone 4.5 — Offline Code Generation

### Offline Code Generation Issues

* Code completion
* Code generation
* Refactoring
* Documentation
* Unit tests

### Required Files (Offline Code Generation)

```text
scripts/550-validate-code-generation.sh
reports/latest/offline-code-generation.md
```

Implemented / Planned:

* Planned / Not present: `scripts/550-validate-code-generation.sh`, `reports/latest/offline-code-generation.md`

---

## Milestone 4.6 — Offline Code Review

### Offline Code Review Issues

* Shell review
* Python review
* Markdown review
* GitHub workflow review

### Required Files (Offline Code Review)

```text
scripts/560-run-offline-code-review.sh
reports/latest/offline-code-review.md
```

Implemented / Planned:

* Planned / Not present: `scripts/560-run-offline-code-review.sh`, `reports/latest/offline-code-review.md`

---

## Milestone 4.7 — Benchmark

### Code Assistant Benchmark Issues

* Completion speed
* Latency
* Context retrieval
* Benchmark report

### Required Files (Code Assistant Benchmark)

```text
scripts/530-benchmark-code-assistant.sh
docs/vscode-offline-code-assistant.md
```

### Acceptance Criteria (Stage 4)

* Offline coding operational
* Offline code review operational
* Offline code generation operational
* Benchmark completed

---

## Stage 5 — Maintenance & Lifecycle Management

## Objective (Stage 5)

Ensure the optimizer remains maintainable, reproducible, and current over time.

---

## Milestone 5.1 — Software Updates

* Update Ubuntu packages
* Update AI runtimes
* Update dependencies

### Required Files (Software Updates)

```text
scripts/600-update-software.sh
reports/latest/software-update-report.md
```

Implemented / Planned:

* Planned / Not present: `scripts/600-update-software.sh`, `reports/latest/software-update-report.md`

---

## Milestone 5.2 — AI Model Management

* Update LLMs
* Update image models
* Remove obsolete models
* Verify model integrity

### Required Files (AI Model Management)

```text
scripts/610-manage-ai-models.sh
configs/models/manifest.yaml
reports/latest/model-integrity-report.md
```

Implemented / Planned:

* Planned / Not present: `scripts/610-manage-ai-models.sh`, `configs/models/manifest.yaml`, `reports/latest/model-integrity-report.md`

---

## Milestone 5.3 — Regression Testing

* Re-run validation
* Re-run benchmarks
* Compare performance
* Detect regressions

### Required Files (Regression Testing)

```text
scripts/620-run-regression-suite.sh
reports/latest/regression-report.md
```

Implemented / Planned:

* Planned / Not present: `scripts/620-run-regression-suite.sh`, `reports/latest/regression-report.md`

---

## Milestone 5.4 — Backup & Restore

* Backup configurations
* Backup models
* Backup scripts
* Restore validation

### Required Files (Backup & Restore)

```text
scripts/630-backup-ai370.sh
scripts/635-restore-ai370.sh
reports/latest/backup-restore-validation.md
```

Implemented / Planned:

* Planned / Not present: `scripts/630-backup-ai370.sh`, `scripts/635-restore-ai370.sh`, `reports/latest/backup-restore-validation.md`

---

## Milestone 5.5 — Performance Monitoring

* Track CPU performance
* Track GPU performance
* Track NPU performance
* Track memory usage
* Track storage health

### Required Files (Performance Monitoring)

```text
scripts/640-monitor-performance.sh
reports/latest/performance-monitoring.md
```

Implemented / Planned:

* Planned / Not present: `scripts/640-monitor-performance.sh`, `reports/latest/performance-monitoring.md`

---

## Milestone 5.6 — Release Management

* Prepare release
* Update changelog
* Tag release
* Generate release notes
* Publish release artifacts

### Required Files (Release Management)

```text
scripts/650-prepare-release.sh
CHANGELOG.md
reports/latest/release-validation.md
```

Implemented / Planned:

* Planned / Not present: `scripts/650-prepare-release.sh`, `CHANGELOG.md`, `reports/latest/release-validation.md`

---

## Milestone 5.7 — Documentation Maintenance

* Update installation guide
* Update optimization guide
* Update roadmap
* Update architecture documentation

### Required Files (Documentation Maintenance)

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

### Acceptance Criteria (Stage 5)

* System remains reproducible
* Performance remains stable
* Documentation remains current
* Releases are repeatable
* Regression tests pass

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
