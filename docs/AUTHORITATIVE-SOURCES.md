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
Rank sources by OS and stack. Do not treat a GPU, Windows, or membership
page as NPU or Linux XRT/XDNA authority.

### 1. AMD ROCm Documentation — GPU/ROCm authority

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
support for Radeon 890M / `gfx1150` or another AMD device. ROCm documentation
is not NPU, XDNA, or reference-platform authority.

### 2. Linux XRT / XDNA — Linux NPU runtime authority

<https://github.com/amd/xdna-driver>

<https://github.com/Xilinx/XRT>

<https://xilinx.github.io/XRT/master/html/index.html>

First-party authority for this repository's Linux NPU path: the `amdxdna`
driver, XRT base and plugin packages, `xrt-smi`, and staged `.deb`
inventory. Project consumers include `docs/npu-status.md` and
`scripts/205-install-xrt-ryzen-ai.sh`.

Use these sources for Linux XDNA visibility, XRT installation, and NPU
runtime tool behavior. They do not redefine project architecture and do not
imply Windows Ryzen AI Software support.

### 3. AMD Ryzen AI Software — Windows-primary inference stack

<https://ryzenai.docs.amd.com/en/latest/>

<https://ryzenai.docs.amd.com/en/latest/linux.html>

Official Ryzen AI Software documentation for NPU and iGPU inference
tooling. The current docs are Windows-primary. A Linux installer exists;
confirm the current release notes for what that installer supports. Do not
treat Ryzen AI Software as a substitute for Linux XRT/XDNA driver
authority, and do not assume model-generation or every inference path is
supported on Linux.

### 4. AMD ROCm AI Developer Hub — GPU tutorial guidance

<https://rocm.docs.amd.com/projects/ai-developer-hub/en/latest/>

First-party ROCm AI tutorials and notebooks for training, fine-tuning,
inference, and GPU development. Use this hub for ROCm GPU workflows. It is
not Linux XRT/XDNA or Ryzen AI Software authority.

### 5. AMD AI Playbooks — implementation guidance

<https://developer.amd.com/playbooks/>

Preferred first-party AMD implementation reference for reproducible workflows,
environment setup, model execution, local AI workloads, and AMD-tested or
AMD-recommended procedures.

Playbooks are implementation guidance, not project architecture. Verify their
hardware, OS, driver, runtime, memory, and accelerator prerequisites before
applying them.

### 6. AMD Zen Software Studio — CPU/toolchain authority

<https://www.amd.com/en/developer/zen-software-studio.html>

Use for applicable Zen CPU development, compilers, libraries, profiling,
performance analysis, and CPU optimization.

CPU-specific optimization must remain separable from hardware-independent core
behavior.

## AMD ecosystem references

These pages are membership, program, or promotional material. They are not
technical specifications and must not be ranked as implementation authority.

### AMD AI Developer Program

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
