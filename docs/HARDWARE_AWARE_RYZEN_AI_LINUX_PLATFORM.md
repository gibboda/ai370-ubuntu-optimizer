# Hardware-Aware Ryzen AI Linux Platform for Local-run AI

## Project Goal

Build and maintain a **hardware-aware, modular Local-run AI Linux
platform** optimized for AMD Ryzen AI hardware.

The platform must automatically detect available hardware and software
capabilities, determine the supported configuration, safely optimize the
system, and enable local AI workloads across the available **CPU, AMD
GPU, and XDNA/XDNA2 NPU**.

Cloud AI services must remain an **optional fallback**, not the primary
runtime architecture.

**Ubuntu 26.04 LTS with Linux kernel 7.x+** is the initial reference
platform. The architecture must not be permanently tied to one Linux
kernel, one Ryzen AI generation, one Minisforum system, or one Linux
distribution.

The **Minisforum EliteMini AI370 with AMD Ryzen AI 9 HX 370** is the
initial tested reference system.

## Repository Evolution

The platform is being developed by **migrating the existing repository
in place**, not by starting over in a new repository.

Current repository:

``` text
gibboda/ai370-ubuntu-optimizer
```

Canonical future repository name:

``` text
gibboda/ryzen-ai-linux-platform
```

The future rename must occur only after the generalized architecture is
stable, existing AI370 behavior has been preserved and validated, and
the repository genuinely represents the broader platform.

Do **not** use `gibboda/ryzen-ai-linux` or other alternative names as
the planned destination. `gibboda/ryzen-ai-linux-platform` is the
canonical future repository name.

The migration must preserve useful Git history, working implementation,
tests, validation logic, and documentation wherever practical. This is
an architectural evolution of the existing project, not a clean-room
rewrite.

------------------------------------------------------------------------

## Final Objective

The project must become a platform rather than a collection of
installation scripts:

``` text
Ryzen AI Linux Platform
        │
        ▼
Hardware Detection
        │
        ▼
Capability Model
        │
        ├──────── CPU
        ├──────── GPU
        └──────── NPU
        │
        ▼
Distribution / Kernel Assessment
        │
        ▼
Supported Configuration
        │
        ▼
System Optimization
        │
        ▼
Compute Backends
        │
        ▼
AI Runtime Layer
        │
        ├── Local LLM
        ├── Local Coding AI
        └── Local Image Generation
        │
        ▼
Validation + Benchmarking
```

The system should remain useful for software development and AI
workloads when Internet access is unavailable, cloud services are
unavailable, quotas are exhausted, or cloud execution is intentionally
disabled.

------------------------------------------------------------------------

# 1. Core Design Principles

## 1.1 Detect Before Modifying

Never assume the hardware, distribution, kernel, firmware, drivers,
runtimes, or accelerator capabilities.

Detection must occur before configuration.

Detect at minimum:

-   Linux distribution and release
-   kernel version
-   CPU vendor, family, model, architecture, and topology
-   Ryzen AI generation when identifiable
-   integrated and discrete AMD GPUs
-   GPU architecture
-   GPU compute capabilities
-   XDNA/XDNA2 NPU
-   AMDXDNA driver state
-   AMDGPU driver state
-   Mesa version and capabilities
-   Vulkan capabilities
-   ROCm availability and version
-   HIP availability
-   system RAM
-   GPU-accessible/shared memory characteristics
-   storage devices and filesystems
-   firmware information
-   BIOS/UEFI information when safely detectable
-   installed AI runtimes
-   installed AI applications

Detection must not silently modify the machine.

------------------------------------------------------------------------

## 1.2 Use a Capability Model

Do not reduce hardware support to simple present/not-present checks.

Each compute resource should expose progressive capability states.

### GPU Example

``` text
DETECTED
DRIVER_READY
VULKAN_READY
ROCM_READY
HIP_READY
FRAMEWORK_READY
APPLICATION_READY
```

### NPU Example

``` text
DETECTED
DRIVER_READY
FIRMWARE_READY
RUNTIME_READY
BACKEND_READY
MODEL_READY
APPLICATION_READY
```

A component must not receive `PASS` merely because its PCI device
exists.

The platform must distinguish hardware detection from actual workload
execution.

------------------------------------------------------------------------

## 1.3 Separate Detection, Assessment, Configuration, and Validation

Use the following execution model:

``` text
Hardware Detection
        ↓
Capability Assessment
        ↓
Platform Validation
        ↓
Optimization Planning
        ↓
System Optimization
        ↓
Compute Enablement
        ↓
AI Runtime Installation
        ↓
Application Installation
        ↓
Functional Validation
        ↓
Benchmarking
```

Every modification must be justified by detected state and documented
requirements.

------------------------------------------------------------------------

## 1.4 Treat CPU, GPU, and NPU as Independent Compute Resources

Do not treat "AMD AI support" as synonymous with ROCm.

Model Ryzen AI systems as heterogeneous compute platforms:

``` text
Ryzen AI
   │
   ├── CPU
   │    └── Zen architecture
   │
   ├── GPU
   │    └── Radeon
   │         ├── AMDGPU
   │         ├── Vulkan
   │         ├── ROCm
   │         └── HIP
   │
   └── NPU
        └── XDNA / XDNA2
             ├── AMDXDNA
             └── Supported user-space runtime/backend
```

Detect, configure, validate, and benchmark each compute resource
independently.

------------------------------------------------------------------------

# 2. Reference Platform

## Initial Tested Hardware

### Minisforum EliteMini AI370

-   **Processor:** AMD Ryzen AI 9 HX 370
-   **CPU:** 12 cores / 24 threads, Zen 5
-   **GPU:** AMD Radeon 890M, RDNA 3.5 / gfx1150
-   **NPU:** AMD XDNA2, 50 TOPS
-   **Memory:** LPDDR5X-7500
-   **Storage:** PCIe 4.0 NVMe
-   **BIOS:** 2.01

This system is the initial **TESTED reference platform**, not an
architectural requirement.

## Reference Operating System

Initial reference configuration:

``` text
Ubuntu 26.04 LTS
Linux kernel 7.x+
```

Do not hard-code a specific kernel release as a permanent requirement.

Use feature, version, and capability detection so newer supported
kernels can be accepted automatically.

Prefer supported inbox Linux drivers when they provide the required
functionality.

Do not replace kernel drivers unnecessarily.

------------------------------------------------------------------------

# 3. Platform Architecture

``` text
                 OPTIONAL DESKTOP
                macOS-like GNOME
                       │
───────────────────────┼──────────────────────
                  APPLICATIONS
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Coding       Local LLM     ComfyUI
          │            │            │
───────────────────────┼──────────────────────
                  AI RUNTIMES
          │            │            │
       Ollama       llama.cpp     PyTorch
       ONNX         Lemonade      FastFlowLM
          │            │            │
───────────────────────┼──────────────────────
               COMPUTE BACKENDS
          │            │            │
          ▼            ▼            ▼
         CPU          GPU          NPU
          │            │            │
       Zen CPU      ROCm/HIP    Ryzen AI Runtime
                       │            │
                    AMDGPU       AMDXDNA
                       │            │
                    Radeon      XDNA/XDNA2
───────────────────────────────────────────────
              PLATFORM FOUNDATION

              Linux Distribution
                    Kernel
                   Firmware
───────────────────────────────────────────────
              CAPABILITY ENGINE

                   Detect
                     ↓
                   Assess
                     ↓
                    Plan
                     ↓
                 Configure
                     ↓
                  Validate
                     ↓
                 Benchmark
```

------------------------------------------------------------------------

# 4. System Foundation

Validate the operating-system foundation before installing compute
runtimes.

Required checks include:

-   supported Linux distribution
-   distribution version
-   kernel version
-   required kernel configuration
-   firmware packages
-   CPU identification
-   GPU identification
-   NPU identification
-   PCI devices
-   IOMMU state where relevant
-   device nodes
-   kernel modules
-   system memory
-   storage
-   thermal and power information when available

Unsupported configurations should be reported explicitly rather than
silently forced into a reference configuration.

------------------------------------------------------------------------

# 5. Hardware Optimization

Perform system optimization after hardware and platform validation and
before higher-level AI application installation.

## CPU

Evaluate:

-   CPU topology
-   frequency scaling
-   AMD P-State
-   EPP policy
-   scheduler behavior
-   power/performance configuration
-   thermal constraints

Do not blindly force maximum-performance settings.

Optimization must account for workload and thermal stability.

## Memory

Evaluate:

-   total RAM
-   available RAM
-   memory pressure
-   swap
-   zram
-   shared GPU memory behavior
-   AI model memory requirements

Avoid configuration that unnecessarily reduces memory available to local
AI workloads.

## Storage

Evaluate:

-   NVMe devices
-   filesystem
-   free capacity
-   mount options
-   model-storage location
-   AI cache location
-   temporary working storage

Large model files should be separable from the operating-system
filesystem when appropriate.

------------------------------------------------------------------------

# 6. AMD GPU Compute

GPU enablement must be treated independently from NPU enablement.

Validate, where applicable:

``` text
Radeon Hardware
      ↓
AMDGPU
      ↓
Mesa
      ↓
Vulkan
      ↓
ROCm
      ↓
HIP
      ↓
AI Framework
      ↓
Application
```

Validate:

-   AMDGPU loaded
-   GPU device identified
-   Mesa functional
-   Vulkan functional
-   ROCm compatibility
-   ROCm runtime
-   HIP
-   GPU compute
-   PyTorch ROCm
-   supported GPU architecture
-   available/shared GPU memory
-   actual application execution

Do not install unnecessary proprietary or out-of-tree kernel drivers
when the supported Linux kernel provides the required AMDGPU
implementation.

------------------------------------------------------------------------

# 7. XDNA/XDNA2 NPU Compute

NPU support must remain modular because AMD's Linux NPU software
ecosystem can evolve independently of the kernel driver.

Use an abstract architecture:

``` text
Application
     │
     ▼
Framework / Inference Engine
     │
     ▼
Supported NPU Execution Backend
     │
     ▼
Ryzen AI User-Space Runtime
     │
     ▼
AMDXDNA
     │
     ▼
XDNA / XDNA2
```

Possible runtime/backend implementations may include, when supported:

-   AMD Ryzen AI software
-   ONNX Runtime backends
-   Vitis AI components
-   XRT components
-   Lemonade
-   FastFlowLM
-   future AMD-supported XDNA runtimes and execution backends

No individual user-space implementation should become a permanent
architectural dependency unless technically required.

## NPU Validation States

Validate independently:

``` text
Hardware detected
Driver available
Driver loaded
Firmware loaded
Device nodes available
User-space runtime available
Execution backend available
Compatible model available
Inference executes on NPU
Application acceleration available
```

The NPU must not be reported as operational merely because `lspci`
identifies the device.

------------------------------------------------------------------------

# 8. Local AI Runtime Layer

The runtime layer should provide modular support for different workloads
and accelerators.

Potential components include:

-   Ollama
-   llama.cpp
-   ONNX Runtime
-   PyTorch
-   Lemonade
-   FastFlowLM
-   AMD Ryzen AI runtime components
-   future compatible local inference engines

The platform should determine which execution backend is actually
available.

Conceptually:

``` text
AI Workload
     │
     ▼
Runtime Selection
     │
     ├── CPU backend
     ├── GPU backend
     └── NPU backend
```

A safe CPU fallback should remain available where practical.

------------------------------------------------------------------------

# 9. Local LLM Support

Support local language-model inference for:

-   general AI assistance
-   software development
-   repository analysis
-   documentation
-   code generation
-   code explanation
-   local retrieval workflows

Potential runtimes:

-   Ollama
-   llama.cpp
-   Lemonade
-   FastFlowLM
-   other validated local runtimes

Model installation must be modular.

Do not assume that every model supports every accelerator.

Record:

-   model
-   quantization
-   runtime
-   execution backend
-   accelerator
-   memory requirement
-   measured performance

------------------------------------------------------------------------

# 10. Local Coding AI

Provide a development environment capable of useful operation without
mandatory cloud inference.

Primary environment:

-   VS Code
-   local coding models
-   local code completion
-   repository-aware assistance
-   local AI agents where technically supported
-   Git integration
-   GitHub integration when online

The architecture should allow:

``` text
VS Code / Coding Agent
          │
          ▼
    Local AI Runtime
          │
    ┌─────┼─────┐
    ▼     ▼     ▼
   CPU   GPU   NPU
```

Cloud services such as hosted coding agents may be supported as optional
fallback services but must not be required for core local coding
functionality.

------------------------------------------------------------------------

# 11. Local Image Generation

Primary image-generation platform:

-   ComfyUI
-   PyTorch
-   ROCm
-   Radeon GPU acceleration
-   local model storage
-   reusable workflows

Architecture:

``` text
ComfyUI
   │
   ▼
PyTorch
   │
   ▼
ROCm / HIP
   │
   ▼
Radeon GPU
```

Do not assume ComfyUI can use XDNA/XDNA2 simply because an NPU exists.

GPU and NPU acceleration must be detected and reported separately.

Future heterogeneous workflows may use:

``` text
CPU + GPU + NPU
```

only when the relevant applications and runtimes genuinely support such
execution.

Planned heterogeneous acceleration must never be reported as implemented
acceleration.

------------------------------------------------------------------------

# 12. Model and Data Management

Local-run AI requires explicit model-management architecture.

Support configurable locations for:

-   LLM models
-   image-generation checkpoints
-   VAEs
-   LoRAs
-   embeddings
-   ComfyUI models
-   coding models
-   NPU-compiled models
-   model caches
-   temporary inference data

Avoid unnecessary duplication of large models between applications.

Where feasible, provide a shared model-storage strategy.

------------------------------------------------------------------------

# 13. Optional macOS-Like Desktop Module

Desktop customization must remain completely isolated from hardware and
AI configuration.

Preferred stack:

-   Ubuntu GNOME
-   GNOME Tweaks
-   GNOME Extension Manager
-   macOS-style bottom dock
-   WhiteSur GTK theme
-   WhiteSur icon theme
-   WhiteSur cursor theme
-   left-side window controls
-   GNOME Overview
-   GNOME Search
-   dynamic workspaces
-   Wayland gestures where supported

Suggested structure:

``` text
desktop/
└── macos-like/
    ├── install
    ├── configure
    ├── validate
    └── uninstall
```

Prefer per-user configuration:

``` text
~/.themes/
~/.icons/
~/.local/share/
```

Do not unnecessarily replace or modify:

-   GNOME
-   GDM
-   NetworkManager
-   PipeWire
-   Nautilus
-   Mesa
-   AMDGPU
-   AMDXDNA
-   kernel components

The desktop module must be cosmetic, optional, reversible, and
independently removable.

------------------------------------------------------------------------

# 14. Safety and Reliability

Every configuration operation must be:

-   idempotent where practical
-   auditable
-   reversible where practical
-   documented
-   validated after execution
-   safe to rerun

Scripts should follow:

``` text
1. Detect current state
2. Report detected state
3. Assess capability
4. Determine whether modification is necessary
5. Explain the planned modification
6. Back up affected configuration
7. Apply only required changes
8. Validate the result
9. Report final state
```

Use clear result states:

``` text
PASS
WARN
FAIL
UNSUPPORTED
SKIPPED
```

Never silently overwrite user configuration.

Use strict shell behavior where appropriate:

``` bash
set -euo pipefail
```

Do not hide unexpected failures with unnecessary:

``` bash
|| true
```

Explicitly handle commands where a non-zero status is an expected
detection result.

------------------------------------------------------------------------

# 15. Support Classification

Documentation and validation output must distinguish:

``` text
SUPPORTED
TESTED
EXPERIMENTAL
PLANNED
UNSUPPORTED
```

Definitions:

### SUPPORTED

Expected to work and maintained by the project.

### TESTED

Actually validated on specified hardware/software configurations.

### EXPERIMENTAL

Implemented but not considered stable or broadly validated.

### PLANNED

Designed or scheduled but not implemented.

### UNSUPPORTED

Known not to work, outside project scope, or incompatible.

Never describe `PLANNED` functionality as implemented.

------------------------------------------------------------------------

# 16. Implementation Stages

## Stage 0 --- Project Foundation

Establish:

-   repository structure
-   coding standards
-   documentation standards
-   logging
-   common libraries
-   configuration handling
-   status/result conventions
-   test framework

## Stage 1 --- Hardware Detection

Implement read-only detection for:

-   CPU
-   Ryzen AI generation
-   GPU
-   GPU architecture
-   NPU
-   memory
-   storage
-   firmware
-   BIOS/UEFI
-   distribution
-   kernel

**No system optimization should occur during this stage.**

## Stage 2 --- Platform Validation

Validate:

-   Linux distribution
-   kernel
-   firmware
-   kernel modules
-   device nodes
-   AMDGPU
-   AMDXDNA
-   required system capabilities

## Stage 3 --- Hardware Optimization

Optimize where justified:

-   CPU
-   AMD P-State
-   power policy
-   memory
-   zram/swap
-   storage
-   model storage
-   system limits

## Stage 4 --- GPU Compute

Validate and configure:

-   AMDGPU
-   Mesa
-   Vulkan
-   ROCm
-   HIP
-   PyTorch ROCm
-   GPU compute

## Stage 5 --- NPU Compute

Validate and configure supported:

-   AMDXDNA
-   NPU firmware
-   user-space runtime
-   execution backend
-   model compatibility
-   real NPU inference

## Stage 6 --- Local AI Runtime

Install and validate selected:

-   Ollama
-   llama.cpp
-   ONNX Runtime
-   Lemonade
-   FastFlowLM
-   PyTorch
-   other supported local runtimes

## Stage 7 --- Local Coding AI

Install and configure:

-   VS Code
-   local coding models
-   local code completion
-   repository-aware AI
-   local coding agents
-   optional cloud fallback

## Stage 8 --- Local Image Generation

Install and configure:

-   ComfyUI
-   PyTorch ROCm
-   image-generation models
-   model storage
-   workflows
-   GPU acceleration

Track heterogeneous GPU/NPU acceleration separately as experimental or
planned until actually supported and validated.

## Stage 9 --- Validation and Benchmarking

Validate the complete system.

Benchmark:

-   CPU inference
-   GPU inference
-   NPU inference
-   local LLM performance
-   coding-model performance
-   image-generation performance
-   memory consumption
-   power/thermal behavior where measurable

## Stage 10 --- Desktop Experience

Implement optional:

-   macOS-like GNOME configuration
-   installation
-   validation
-   rollback/uninstall

Desktop customization must not be a dependency of the AI platform.

## Stage 11 --- Platform Expansion

Extend the capability model to:

-   Ryzen AI 300 series
-   Ryzen AI 400 series
-   future Ryzen AI generations
-   Minisforum systems
-   systems from other manufacturers
-   additional supported Linux distributions

------------------------------------------------------------------------

# 17. Validation Framework

Provide a master validation command or script.

Example output:

``` text
Ryzen AI Linux Platform Validation

Platform
------------------------------------------------
Distribution             PASS
Kernel                   PASS
Firmware                 PASS

Hardware
------------------------------------------------
CPU                      PASS
Memory                   PASS
Storage                  PASS
Radeon GPU               PASS
XDNA/XDNA2 NPU           PASS

GPU Compute
------------------------------------------------
AMDGPU                   PASS
Mesa                     PASS
Vulkan                   PASS
ROCm                     PASS
HIP                      PASS
PyTorch GPU              PASS

NPU Compute
------------------------------------------------
AMDXDNA                  PASS
NPU Firmware             PASS
NPU Runtime              WARN
Execution Backend        WARN
NPU Inference            WARN

Local AI
------------------------------------------------
Local LLM Runtime        PASS
Local LLM Model          PASS
Coding AI                PASS
ComfyUI                  PASS
Image GPU Acceleration   PASS

Optional
------------------------------------------------
macOS-like Desktop       SKIPPED

Overall                  WARN
```

A higher layer must not receive `PASS` solely because a lower layer
passed.

For example:

``` text
NPU hardware detected != NPU inference operational
ROCm installed          != PyTorch GPU operational
ComfyUI installed       != GPU acceleration operational
Ollama installed        != model inference operational
```

------------------------------------------------------------------------

# 18. Benchmarking

Benchmarking should identify the actual execution path.

Record:

``` text
Hardware
Model
Runtime
Backend
Quantization
Accelerator
Memory usage
Load time
Inference time
Throughput
Power/thermal data when available
Result
```

Comparisons should include where technically applicable:

``` text
CPU vs GPU vs NPU
```

The fastest accelerator must not automatically be considered the best
accelerator.

Consider:

-   latency
-   throughput
-   memory usage
-   power consumption
-   model compatibility
-   workload type
-   stability

------------------------------------------------------------------------

# 19. Repository Architecture

A possible long-term structure:

``` text
ryzen-ai-linux/
├── bin/
├── config/
├── detection/
│   ├── platform/
│   ├── cpu/
│   ├── gpu/
│   ├── npu/
│   ├── memory/
│   └── storage/
├── capabilities/
├── validation/
├── optimization/
│   ├── cpu/
│   ├── memory/
│   └── storage/
├── compute/
│   ├── gpu/
│   └── npu/
├── runtimes/
│   ├── ollama/
│   ├── llama-cpp/
│   ├── onnx/
│   ├── lemonade/
│   └── fastflowlm/
├── applications/
│   ├── coding/
│   └── comfyui/
├── desktop/
│   └── macos-like/
├── benchmarks/
├── tests/
├── docs/
└── scripts/
```

The exact repository layout may evolve, but hardware detection,
capability assessment, configuration, applications, and desktop
customization should remain logically separated.

------------------------------------------------------------------------

# 20. Documentation Requirements

Keep documentation synchronized with implementation.

Document:

-   architecture
-   supported hardware
-   tested hardware
-   supported Linux distributions
-   tested distributions
-   supported kernels
-   firmware requirements
-   AMDGPU status
-   Vulkan status
-   ROCm compatibility
-   HIP compatibility
-   AMDXDNA status
-   XDNA/XDNA2 status
-   NPU runtime support
-   local LLM support
-   coding AI support
-   ComfyUI support
-   known limitations
-   installation
-   configuration
-   validation
-   benchmarking
-   troubleshooting
-   rollback
-   desktop installation/removal

Documentation must clearly distinguish actual implementation from future
plans.

------------------------------------------------------------------------

# 21. Cloud AI Policy

Cloud AI is an optional extension of the platform.

Priority:

``` text
Local execution
      ↓
Local fallback backend
      ↓
Cloud AI only when explicitly available/allowed
```

Core functionality must not depend on:

-   cloud inference
-   cloud coding agents
-   cloud image generation
-   permanent Internet connectivity
-   subscription quotas

Online services may provide additional capability but must not define
the fundamental architecture.

------------------------------------------------------------------------

# 22. Future Hardware and Distribution Support

The architecture must not assume:

``` text
Minisforum == Ryzen AI
Ubuntu == Ryzen AI Linux
HX 370 == permanent target
XDNA2 == final NPU generation
Linux 7.x == permanent kernel
```

Instead:

``` text
Ryzen AI Hardware
        ↓
Hardware Detection
        ↓
Capability Model
        ↓
Distribution Detection
        ↓
Kernel / Driver Assessment
        ↓
Supported Configuration
        ↓
Optimization
        ↓
Compute Enablement
        ↓
AI Runtime
```

This should permit future support for:

-   newer Ryzen AI processors
-   newer Radeon architectures
-   newer XDNA generations
-   systems from other OEMs
-   newer Linux kernels
-   additional Linux distributions
-   new AMD AI runtimes

------------------------------------------------------------------------

# 23. Recommended Repository Migration Tasks

The following tasks define how Codex, Grok Build, or another
implementation agent should migrate the existing repository into the new
architecture.

The migration must be incremental. Do not perform a large-scale
directory rewrite before understanding and testing the current
implementation.

## Task 1 --- Create a Dedicated Migration Branch

Perform the architectural migration on a dedicated branch.

Recommended branch:

``` text
refactor/ryzen-ai-platform
```

Do not perform the migration directly on `main`.

Use incremental commits and pull requests so each architectural change
can be reviewed, tested, and reverted independently.

Recommended commit boundaries include:

``` text
docs(architecture): define Ryzen AI Linux platform
refactor(detection): abstract Ryzen AI hardware discovery
refactor(capabilities): introduce accelerator capability states
refactor(platform): separate distribution and kernel validation
refactor(optimization): separate tuning from detection
refactor(gpu): separate AMDGPU Vulkan ROCm validation
refactor(npu): introduce modular XDNA runtime validation
feat(runtime): add local AI runtime abstraction
feat(coding): add local coding AI integration
feat(comfyui): add local image generation integration
feat(validation): add unified platform validation
feat(benchmark): add heterogeneous compute benchmarks
```

## Task 2 --- Inventory the Existing Repository Before Refactoring

The first implementation task is **analysis only**.

Inspect the complete existing repository and identify:

-   directories
-   scripts
-   shared libraries
-   configuration files
-   tests
-   GitHub workflows
-   documentation
-   installation logic
-   validation logic
-   hardware detection
-   optimization logic
-   AI runtime installation
-   ComfyUI work
-   coding-assistant work
-   incomplete features
-   deprecated code
-   duplicated logic

Classify relevant functionality as:

``` text
IMPLEMENTED
PARTIAL
PLANNED
DEPRECATED
UNKNOWN
```

Do not infer that a documented feature is implemented. Verify the code.

## Task 3 --- Build a Current-to-Target Migration Map

For every relevant existing file or component, record:

``` text
Current path
Current responsibility
Current dependencies
Hardware assumptions
Distribution assumptions
Target architectural component
Recommended action
Required tests
Migration risk
```

Use these recommended actions:

``` text
KEEP
REFACTOR
MOVE
SPLIT
MERGE
DEPRECATE
REMOVE
```

`REMOVE` should be used only when functionality is obsolete, duplicated,
or safely replaced.

## Task 4 --- Identify AI370-Specific Assumptions

Search the codebase for assumptions tied directly to:

-   Minisforum EliteMini AI370
-   AMD Ryzen AI 9 HX 370
-   Radeon 890M
-   gfx1150
-   XDNA2
-   BIOS 2.01
-   Ubuntu
-   Ubuntu 26.04
-   a specific Linux kernel
-   specific PCI IDs
-   specific device paths
-   specific package versions

Classify each assumption as one of:

``` text
REFERENCE_PLATFORM_FACT
CAPABILITY_DETECTION_RULE
TEMPORARY_COMPATIBILITY_RULE
UNNECESSARY_HARDCODE
```

Reference-platform facts may remain in hardware profiles or test
fixtures.

Unnecessary hard-coding should be replaced with capability detection.

## Task 5 --- Establish Shared Result and Capability Models

Create shared representations for platform status and accelerator
capability.

Standard validation results:

``` text
PASS
WARN
FAIL
UNSUPPORTED
SKIPPED
```

Standard documentation support classifications:

``` text
SUPPORTED
TESTED
EXPERIMENTAL
PLANNED
UNSUPPORTED
```

GPU capability progression should support states equivalent to:

``` text
DETECTED
DRIVER_READY
VULKAN_READY
ROCM_READY
HIP_READY
FRAMEWORK_READY
APPLICATION_READY
```

NPU capability progression should support states equivalent to:

``` text
DETECTED
DRIVER_READY
FIRMWARE_READY
RUNTIME_READY
BACKEND_READY
MODEL_READY
APPLICATION_READY
```

The implementation should expose structured facts rather than requiring
later stages to repeatedly parse human-readable command output.

## Task 6 --- Refactor Hardware Detection Into Read-Only Modules

Separate hardware discovery from system modification.

Detection must collect facts about:

-   operating system
-   kernel
-   CPU
-   Ryzen AI generation
-   GPU
-   GPU architecture
-   NPU
-   kernel modules
-   firmware
-   memory
-   storage
-   BIOS/UEFI
-   installed compute runtimes

Detection modules must not:

-   install packages
-   modify configuration
-   alter power policy
-   modify kernel parameters
-   restart services
-   overwrite files

Preserve the existing EliteMini AI370 detection behavior as regression
coverage.

## Task 7 --- Introduce a Capability Assessment Layer

Hardware detection answers:

``` text
What exists?
```

Capability assessment answers:

``` text
What can this system actually support?
```

The capability layer should consume structured detection facts and
determine whether specific GPU, NPU, runtime, framework, and application
features are:

``` text
AVAILABLE
READY
DEGRADED
UNSUPPORTED
UNKNOWN
```

Keep assessment separate from installation.

## Task 8 --- Refactor Platform Validation

Separate platform validation into independently testable components:

-   distribution validation
-   kernel validation
-   firmware validation
-   AMDGPU validation
-   AMDXDNA validation
-   Mesa validation
-   Vulkan validation
-   ROCm validation
-   HIP validation
-   device-node validation

Do not fail merely because the system does not exactly match the
reference kernel version if the required capability is already available
and supported.

Prefer capability checks over exact-version checks whenever technically
sound.

## Task 9 --- Refactor Hardware Optimization

Move CPU, memory, storage, power, and related tuning out of detection.

Optimization should consume detection and capability results.

Before changing a setting:

1.  detect the current value
2.  determine whether a change is justified
3.  report the proposed change
4.  back up affected configuration where applicable
5.  apply the minimum required modification
6.  validate the result
7.  report the final state

Do not blindly force maximum-performance settings.

## Task 10 --- Create an Independent GPU Compute Module

Implement the GPU path independently:

``` text
Radeon
  ↓
AMDGPU
  ↓
Mesa
  ↓
Vulkan
  ↓
ROCm
  ↓
HIP
  ↓
Framework
  ↓
Application
```

Preserve Radeon 890M/gfx1150 reference-platform support while avoiding
architecture-wide assumptions that every future Ryzen AI GPU is gfx1150.

Validation must distinguish package presence from actual GPU compute.

## Task 11 --- Create an Independent NPU Compute Module

Implement the NPU path independently:

``` text
XDNA/XDNA2
    ↓
AMDXDNA
    ↓
Firmware
    ↓
Device Interface
    ↓
User-Space Runtime
    ↓
Execution Backend
    ↓
Compatible Model
    ↓
Application
```

Do not make one user-space stack a permanent architectural requirement.

Support modular integration, when technically supported, for
technologies such as:

-   AMD Ryzen AI software
-   ONNX Runtime backends
-   Vitis AI components
-   XRT components
-   Lemonade
-   FastFlowLM
-   future AMD-supported XDNA runtimes

The implementation must distinguish NPU hardware detection from
successful NPU inference.

## Task 12 --- Build the Local AI Runtime Abstraction

Create modular runtime handling for:

-   Ollama
-   llama.cpp
-   ONNX Runtime
-   PyTorch
-   Lemonade
-   FastFlowLM
-   future compatible runtimes

Each runtime module should report:

``` text
Installed
Version
Supported backend
Selected backend
Detected accelerator
Model compatibility
Functional validation
```

Where practical, retain CPU fallback capability.

## Task 13 --- Implement Local Coding AI as an Application Layer

Keep coding applications above the runtime layer.

Support:

-   VS Code
-   local coding models
-   local code completion
-   repository-aware assistance
-   local coding agents where supported
-   Git integration
-   optional GitHub integration
-   optional cloud fallback

Do not couple VS Code configuration directly to ROCm or AMDXDNA
internals.

The runtime/capability layer should determine available acceleration.

## Task 14 --- Implement ComfyUI as an Application Layer

Keep ComfyUI above PyTorch and the GPU runtime.

Primary validated path:

``` text
ComfyUI
   ↓
PyTorch
   ↓
ROCm / HIP
   ↓
Radeon GPU
```

Do not report XDNA/XDNA2 ComfyUI acceleration unless it is genuinely
supported and functionally validated.

Track heterogeneous CPU/GPU/NPU work as `EXPERIMENTAL` or `PLANNED`
until validated.

## Task 15 --- Implement Shared Model and Data Management

Define configurable storage for:

-   LLM models
-   coding models
-   image checkpoints
-   VAEs
-   LoRAs
-   embeddings
-   ComfyUI models
-   NPU-compiled models
-   caches
-   temporary inference data

Avoid unnecessary copies of large models.

Do not make model storage paths specific to one user's machine.

## Task 16 --- Build Unified Validation

Provide one master validation entry point that aggregates lower-level
checks.

It should report at least:

``` text
Distribution
Kernel
Firmware
CPU
Memory
Storage
AMDGPU
Mesa
Vulkan
ROCm
HIP
GPU Compute
AMDXDNA
XDNA/XDNA2
NPU Firmware
NPU Runtime
NPU Backend
NPU Inference
Local LLM Runtime
Local LLM Model
Coding AI
ComfyUI
Image GPU Acceleration
Desktop UI
```

A higher-level component must not inherit `PASS` from a lower-level
component without validating its own functionality.

## Task 17 --- Add Heterogeneous Compute Benchmarking

Benchmark actual execution paths where technically applicable:

``` text
CPU
GPU
NPU
```

Record:

-   hardware
-   model
-   quantization
-   runtime
-   backend
-   accelerator
-   memory usage
-   load time
-   inference latency
-   throughput
-   power/thermal data where available
-   result

Benchmarking must identify which accelerator actually executed the
workload.

## Task 18 --- Isolate the Optional Desktop Module

Implement macOS-like GNOME customization only after the core compute
platform is stable enough that desktop work cannot obscure
hardware/runtime problems.

Keep it isolated under a structure similar to:

``` text
desktop/
└── macos-like/
    ├── install
    ├── configure
    ├── validate
    └── uninstall
```

The module must be optional and reversible.

## Task 19 --- Update Documentation Alongside Implementation

Documentation changes should be part of the same PR as implementation
changes when practical.

Maintain:

-   architecture
-   supported hardware
-   tested hardware
-   distribution support
-   kernel support
-   GPU support
-   NPU support
-   runtime support
-   application support
-   known limitations
-   installation
-   validation
-   benchmarking
-   troubleshooting
-   rollback
-   migration status

Never mark planned functionality as implemented.

## Task 20 --- Preserve Regression Coverage for the AI370

Before removing an old AI370-specific implementation, prove that the
generalized replacement preserves required behavior.

At minimum, preserve validation for:

-   Minisforum EliteMini AI370
-   Ryzen AI 9 HX 370
-   Radeon 890M
-   gfx1150
-   XDNA2
-   BIOS 2.01 handling where relevant
-   Ubuntu 26.04 reference-platform behavior

Use fixtures/mocks for hardware-dependent logic where direct CI hardware
access is unavailable.

## Task 21 --- Expand Hardware Support Only After the Abstraction Exists

Do not add Ryzen AI 400-series or other OEM support by copying
AI370-specific logic.

First establish the generic capability architecture.

Then add new hardware as profiles, detection rules, compatibility data,
or backend support as appropriate.

Future support should include:

-   Ryzen AI 300 series
-   Ryzen AI 400 series
-   future Ryzen AI generations
-   future Radeon architectures
-   future XDNA generations
-   Minisforum systems
-   other manufacturers

## Task 22 --- Expand Distribution Support After Ubuntu Reference Stability

Ubuntu 26.04 remains the initial reference implementation.

Do not prematurely duplicate package/install logic for multiple
distributions.

First isolate distribution-specific behavior behind a platform
abstraction.

Then add other distributions without changing the hardware capability
model.

## Task 23 --- Prepare, But Do Not Perform, the Repository Rename

The current repository remains:

``` text
gibboda/ai370-ubuntu-optimizer
```

The canonical future repository name is:

``` text
gibboda/ryzen-ai-linux-platform
```

Prepare for the rename by removing unnecessary AI370-specific
architectural assumptions and updating documentation to describe the
broader platform.

Do not perform the GitHub rename until explicitly authorized.

The rename should occur only when:

-   the generalized architecture is established
-   AI370 regression validation passes
-   CPU/GPU/NPU separation is implemented
-   capability-based platform detection is established
-   documentation accurately represents the broader scope
-   the repository genuinely functions as the Ryzen AI Linux platform

## Task 24 --- Recommended First PR

The first migration PR should be deliberately low risk.

Recommended scope:

``` text
docs(architecture): establish Ryzen AI Linux platform migration
```

It should:

1.  add/update this architecture document
2.  document the current and future repository identity
3.  add the repository inventory/migration assessment
4.  document capability/status terminology
5.  identify AI370-specific assumptions
6.  propose file-by-file migration mapping
7.  define regression requirements
8.  avoid broad production-code restructuring

After review, subsequent PRs should implement one architectural boundary
at a time.

------------------------------------------------------------------------

# 24. Repository Rename Plan

The project must continue in the existing repository during migration:

``` text
gibboda/ai370-ubuntu-optimizer
```

The migration path is:

``` text
gibboda/ai370-ubuntu-optimizer
            │
            │ In-place migration
            ▼
Repository inventory
            │
            ▼
Hardware detection abstraction
            │
            ▼
Capability model
            │
            ▼
Platform validation abstraction
            │
            ▼
Hardware optimization separation
            │
            ▼
GPU / NPU compute separation
            │
            ▼
Local AI runtime architecture
            │
            ▼
Local coding + image generation
            │
            ▼
Unified validation + benchmarking
            │
            ▼
Generalized Ryzen AI platform stable
            │
            │ Explicit rename authorization
            ▼
gibboda/ryzen-ai-linux-platform
```

`gibboda/ryzen-ai-linux-platform` is the canonical future repository
name.

Do not create a second replacement repository merely to obtain the new
name. Preserve the existing repository and Git history through the
migration and eventual rename.

------------------------------------------------------------------------

# 25. Definition of Success

The platform is successful when it can:

1.  Identify the actual Ryzen AI hardware.
2.  Determine the capabilities of CPU, GPU, and NPU independently.
3.  Determine whether the Linux platform supports those capabilities.
4.  Avoid unnecessary driver or kernel replacement.
5.  Optimize the underlying system safely.
6.  Enable validated GPU compute where supported.
7.  Enable validated NPU compute where supported.
8.  Install appropriate local AI runtimes.
9.  Run local LLM workloads.
10. Provide useful local coding AI.
11. Run local image generation.
12. Verify the actual accelerator used by each workload.
13. Benchmark CPU, GPU, and NPU execution where applicable.
14. Operate without mandatory cloud AI.
15. Clearly report unsupported or experimental functionality.
16. Remain extensible to future Ryzen AI hardware and Linux
    distributions.
17. Keep optional desktop customization isolated from the compute
    platform.

------------------------------------------------------------------------

# 26. Agent Execution Rules

When Codex, Grok Build, or another implementation agent works from this
document, it should follow these rules:

1.  **Inspect before editing.**
2.  **Preserve working behavior before generalizing it.**
3.  **Do not rewrite the repository from scratch.**
4.  **Do not rename the repository without explicit authorization.**
5.  **Prefer small, reviewable PRs over broad rewrites.**
6.  **Add or preserve regression tests before replacing working code.**
7.  **Keep detection read-only.**
8.  **Keep optimization separate from detection.**
9.  **Keep GPU and NPU support independent.**
10. **Validate actual execution rather than package presence.**
11. **Keep cloud services optional.**
12. **Keep documentation synchronized with implementation.**
13. **Never label `PLANNED` functionality as implemented.**
14. **Stop and report when an architectural assumption cannot be
    verified.**
15. **Use `gibboda/ryzen-ai-linux-platform` as the canonical future
    repository name.**

For the initial migration task, the agent should produce the repository
inventory and migration map before undertaking large-scale
restructuring.

------------------------------------------------------------------------

# 27. Project Principle

> **Detect capabilities, configure only what is supported, validate
> actual execution, and keep Local-run AI independent of the cloud.**

The project should evolve into a reusable **Ryzen AI Linux platform**,
with the Minisforum EliteMini AI370 serving as the initial reference
implementation rather than defining the limits of the architecture.
