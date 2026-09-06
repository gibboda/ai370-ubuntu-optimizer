# Authoritative Technical Sources

This document defines the external technical-source hierarchy used by every AI
agent and human contributor working in this repository.

The repository remains the source of truth for project-controlled architecture,
code, configuration, tests, documentation, Issues, and implementation state.
External sources are authoritative only for the technologies they document.

## General rules

1. Prefer current first-party vendor documentation over model knowledge.
2. Use compatibility matrices, API references, release notes, and official
   installation documentation for support claims.
3. Distinguish official support from community success, experimental behavior,
   and technically possible but unsupported configurations.
4. Do not generalize a vendor-specific implementation detail into a
   project-wide architectural requirement.
5. Do not assume support on one GPU, CPU, NPU, OS, or runtime implies support on
   another.
6. If a current vendor fact materially affects a recommendation or change,
   verify it against the applicable source before relying on it.

## Evidence classes

Use these labels when the distinction matters:

- **Project-verified** — reproduced by this project on a recorded test platform.
- **Officially supported** — explicitly supported by the vendor.
- **Officially documented** — described by first-party documentation, which may
  not necessarily imply support for every configuration.
- **Vendor-tested/validated** — demonstrated or validated by the vendor.
- **Technically possible but unsupported** — works or may work without vendor
  support guarantees.
- **Experimental** — pre-release, provisional, or explicitly experimental.
- **Community-reported** — reported outside official vendor documentation.
- **Unknown/unverified** — insufficient evidence exists.

Community reports may aid troubleshooting or discovery but must not be
represented as official support.

## AMD authoritative source set

AMD sources govern AMD-specific implementation and the current AMD reference
platform. They do not define the hardware-independent project architecture.

### 1. AMD ROCm Documentation — technical authority

<https://rocm.docs.amd.com/en/latest/>

Primary AMD authority for:

- ROCm and HIP
- GPU compute
- supported hardware and operating systems
- compatibility matrices
- drivers and runtimes
- compilers, libraries, and APIs
- installation requirements
- framework support
- profiling and debugging

When ROCm behavior, compatibility, or support materially affects a decision,
verify the current ROCm documentation. Support for one AMD GPU does not imply
support for Radeon 890M / `gfx1150` or another AMD device.

### 2. AMD ROCm AI Developer Hub — AI platform guidance

<https://rocm.docs.amd.com/projects/ai-developer-hub/en/latest/>

First-party ROCm AI tutorials and notebooks for training, fine-tuning,
inference, and GPU development. Use this documentation hub rather than
marketing or cloud-landing pages when a current AMD AI workflow, framework,
or notebook materially affects a decision.

For Ryzen AI NPU and iGPU inference software, also consult
<https://ryzenai.docs.amd.com/en/latest/>. That source does not redefine
project architecture.

### 3. AMD AI Playbooks — implementation guidance

<https://developer.amd.com/playbooks/>

Preferred first-party AMD implementation reference for reproducible workflows,
environment setup, model execution, local AI workloads, and AMD-tested or
AMD-recommended procedures.

Playbooks are implementation guidance, not project architecture. Verify their
hardware, OS, driver, runtime, memory, and accelerator prerequisites before
applying them.

### 4. AMD Zen Software Studio — CPU/toolchain authority

<https://www.amd.com/en/developer/zen-software-studio.html>

Use for applicable Zen CPU development, compilers, libraries, profiling,
performance analysis, and CPU optimization.

CPU-specific optimization must remain separable from hardware-independent core
behavior.

### 5. AMD AI Developer Program — ecosystem reference

<https://developer.amd.com/ai-developer-program/>

Use for applicable AMD developer resources, training, developer-cloud
resources, programs, support opportunities, and ecosystem information.

Program or promotional material does not override technical specifications,
compatibility matrices, or API documentation.

## Future vendors and platforms

When support expands, add the applicable first-party technical authorities for
NVIDIA, Intel, Apple, ARM, operating systems, accelerator vendors, AI runtimes,
or framework maintainers.

Vendor authority is scoped to that vendor or technology. AMD documentation does
not govern non-AMD implementations, and future vendor documentation must not
silently redefine the hardware-independent project architecture.
