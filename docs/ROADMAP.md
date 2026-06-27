# AI370 Ubuntu Optimizer

## Master Implementation Plan

**Document:** `docs/ROADMAP.md`

---

# Purpose

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

# Project Goals

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

# AI Agent Operating Rules

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

# Stage 1 — Hardware Detection & System Optimization

## Objective

Prepare Ubuntu and the AI370 hardware for local AI workloads.

---

## Milestone 1.1 — Hardware Detection

### Issues

* Detect CPU
* Detect GPU
* Detect NPU
* Detect RAM
* Detect Storage
* Detect Motherboard
* Generate hardware report

### Required Files

```text
scripts/10-detect-hardware.sh
```

---

## Milestone 1.2 — BIOS & Firmware Validation

### Issues

* Validate BIOS 2.01
* Validate firmware
* Validate Secure Boot
* Validate microcode

### Required Files

```text
scripts/20-check-bios.sh
scripts/25-check-firmware.sh
```

---

## Milestone 1.3 — Kernel & Driver Validation

### Issues

* Validate kernel
* Validate Mesa
* Validate Vulkan
* Validate AMDGPU
* Validate ROCm
* Validate AMDXDNA

### Required Files

```text
scripts/30-validate-kernel.sh
scripts/70-validate-gpu-stack.sh
scripts/75-detect-npu.sh
```

---

## Milestone 1.4 — System Optimization

### Issues

* CPU optimization
* Memory optimization
* zram
* Storage optimization
* Filesystem tuning
* I/O scheduler tuning

### Required Files

```text
scripts/40-optimize-cpu.sh
scripts/50-optimize-memory.sh
scripts/60-optimize-storage.sh
```

---

## Milestone 1.5 — Validation & Benchmarking

### Issues

* CPU benchmark
* GPU benchmark
* AI benchmark
* Validation summary
* HTML report

### Required Files

```text
scripts/80-benchmark-local-ai.sh
scripts/90-validate.sh
reports/
```

### Acceptance Criteria

* BIOS validated
* Radeon 890M detected
* Vulkan operational
* ROCm validated
* AMDXDNA detected or cleanly reported
* Optimization completed
* Validation successful

---

# Stage 2 — Local AI Runtime & AI Optimization Software

## Objective

Install all local AI infrastructure.

---

## Milestone 2.1 — AI Runtime

### Issues

* Install PyTorch ROCm
* Install llama.cpp
* Install Ollama
* Install Open WebUI

### Required Files

```text
scripts/100-install-pytorch-rocm.sh
scripts/110-install-llama-cpp.sh
scripts/120-install-ollama.sh
scripts/130-install-open-webui.sh
```

---

## Milestone 2.2 — AMD AI Stack

### Issues

* Install ONNX Runtime
* Detect Ryzen AI Software
* Detect Vitis AI Execution Provider
* Benchmark NPU

### Required Files

```text
scripts/200-install-onnxruntime.sh
scripts/210-check-ryzen-ai-software.sh
scripts/220-check-vitis-ai-ep.sh
scripts/230-benchmark-npu.sh
docs/npu-status.md
```

---

## Milestone 2.3 — Offline RAG

### Issues

* Install AnythingLLM
* Install embedding models
* Configure local document storage
* Validate offline RAG

### Required Files

```text
scripts/300-install-anythingllm.sh
scripts/310-install-embedding-models.sh
scripts/320-validate-rag.sh
```

---

## Milestone 2.4 — AI Runtime Benchmark

### Issues

* LLM benchmark
* Embedding benchmark
* Inference benchmark
* Benchmark report

### Required Files

```text
scripts/140-benchmark-llm.sh
reports/
```

### Acceptance Criteria

* Ollama operational
* Open WebUI operational
* llama.cpp operational
* PyTorch ROCm operational
* ONNX Runtime operational
* Offline RAG operational
* Benchmark completed

---

# Stage 3 — Offline Image Generation

## Objective

Install a complete offline image-generation environment.

---

## Milestone 3.1 — ComfyUI

### Issues

* Install ComfyUI
* Validate installation

### Required Files

```text
scripts/400-install-comfyui.sh
```

---

## Milestone 3.2 — Model Installation

### Issues

* Install FLUX
* Install SDXL
* Install ControlNet
* Install IPAdapter

### Required Files

```text
scripts/410-install-comfyui-models.sh
```

---

## Milestone 3.3 — Workflow Library

### Required Directories

```text
workflows/comfyui/flux/
workflows/comfyui/sdxl/
workflows/comfyui/controlnet/
```

---

## Milestone 3.4 — Benchmark

### Issues

* Benchmark FLUX
* Benchmark SDXL
* Measure VRAM
* Generate report

### Required Files

```text
scripts/420-benchmark-comfyui.sh
docs/offline-image-generation.md
```

### Acceptance Criteria

* ComfyUI operational
* FLUX operational
* SDXL operational
* Benchmark generated

---

# Stage 4 — Offline VS Code & Code Assistant

## Objective

Build a completely offline software engineering environment.

---

## Milestone 4.1 — VS Code Installation

### Issues

* Install VS Code
* Configure settings
* Install required extensions

### Required Files

```text
scripts/500-install-vscode.sh
configs/vscode/settings.json
```

---

## Milestone 4.2 — Local AI Extension

### Issues

* Install Continue
* Configure Ollama
* Configure local inference

### Required Files

```text
scripts/510-install-vscode-ai-tools.sh
configs/continue/config.yaml
```

---

## Milestone 4.3 — Coding Models

### Issues

* Install Qwen Coder
* Install DeepSeek Coder
* Install StarCoder2
* Install Code Llama

### Required Files

```text
scripts/520-install-code-models.sh
```

---

## Milestone 4.4 — Repository Intelligence

### Issues

* Repository indexing
* Local embeddings
* Semantic search
* Context optimization

---

## Milestone 4.5 — Offline Code Generation

### Issues

* Code completion
* Code generation
* Refactoring
* Documentation
* Unit tests

---

## Milestone 4.6 — Offline Code Review

### Issues

* Shell review
* Python review
* Markdown review
* GitHub workflow review

---

## Milestone 4.7 — Benchmark

### Issues

* Completion speed
* Latency
* Context retrieval
* Benchmark report

### Required Files

```text
scripts/530-benchmark-code-assistant.sh
docs/vscode-offline-code-assistant.md
```

### Acceptance Criteria

* Offline coding operational
* Offline code review operational
* Offline code generation operational
* Benchmark completed

---

# Stage 5 — Maintenance & Lifecycle Management

## Objective

Ensure the optimizer remains maintainable, reproducible, and current over time.

---

## Milestone 5.1 — Software Updates

* Update Ubuntu packages
* Update AI runtimes
* Update dependencies

---

## Milestone 5.2 — AI Model Management

* Update LLMs
* Update image models
* Remove obsolete models
* Verify model integrity

---

## Milestone 5.3 — Regression Testing

* Re-run validation
* Re-run benchmarks
* Compare performance
* Detect regressions

---

## Milestone 5.4 — Backup & Restore

* Backup configurations
* Backup models
* Backup scripts
* Restore validation

---

## Milestone 5.5 — Performance Monitoring

* Track CPU performance
* Track GPU performance
* Track NPU performance
* Track memory usage
* Track storage health

---

## Milestone 5.6 — Release Management

* Prepare release
* Update changelog
* Tag release
* Generate release notes
* Publish release artifacts

---

## Milestone 5.7 — Documentation Maintenance

* Update installation guide
* Update optimization guide
* Update roadmap
* Update architecture documentation

### Acceptance Criteria

* System remains reproducible
* Performance remains stable
* Documentation remains current
* Releases are repeatable
* Regression tests pass

---

# Development Workflow

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
