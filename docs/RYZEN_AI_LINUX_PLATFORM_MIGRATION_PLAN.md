# Ryzen AI Linux Platform Migration Plan

This document is the current-to-target migration map required by
[`HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md`](HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md)
Tasks 2 through 5 and Task 24. It is analysis and planning only. It does not
authorize a repository rewrite, a GitHub rename, or new public `stageN`
commands.

**Last reviewed:** 2026-08-17

## Document roles

| Document | Role |
| --- | --- |
| [`ROADMAP.md`](ROADMAP.md) | Authoritative for current Stage/Milestone ownership, canonical deliverables, implementation status, and Tier compatibility removal |
| [`HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md`](HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md) | Target Ryzen AI Linux platform architecture |
| This plan | Verified inventory, AI370-assumption classification, file-by-file mapping, and subsequent PR sequence |
| [`README.md`](../README.md) | User-facing installation and command guide |

`docs/ROADMAP.md` remains the implementation authority. The architecture
document describes the destination. This plan records how existing files move
toward that destination without treating destination language as current
behavior.

The architecture document's Stages 0 through 11 are **target platform
layers**. They are not public command names. Canonical public naming remains
`stageN` and `SN-MN` from `docs/ROADMAP.md`. Do not add `stage6` through
`stage11` commands until a later ROADMAP stage-boundary PR exists.

## Repository identity

| State | Repository |
| --- | --- |
| Current | `gibboda/ai370-ubuntu-optimizer` |
| Canonical future | `gibboda/ryzen-ai-linux-platform` |

Do not use `gibboda/ryzen-ai-linux` or other alternative names. Do not rename
the GitHub repository until explicitly authorized. The rename is allowed only
when the generalized architecture is stable, AI370 regression coverage passes,
CPU/GPU/NPU paths are independent, capability-based detection exists,
documentation matches implementation, and the repository functions as the
broader platform.

Current CLI entry point: `./ai370-optimize.sh`.
Current version at plan time: `0.16.0`.

## Terminology

Keep these vocabularies distinct.

### Implementation status (this plan and ROADMAP)

| Label | Meaning |
| --- | --- |
| **IMPLEMENTED** | Code exists and is the current working path, even if filenames or owners are not yet canonical |
| **PARTIAL** | Useful code exists, but it mixes boundaries, lacks canonical outputs, or does not prove actual execution |
| **PLANNED** | Designed in ROADMAP or the architecture document, not implemented |
| **DEPRECATED** | Compatibility or archive surface only |
| **UNKNOWN** | Present but not verified as a supported path |

A ROADMAP milestone is **Implemented** only when canonical outputs,
deterministic tests, and documentation all exist. An existing script does not
upgrade that milestone by itself.

### Runtime result states

Use these for validation output:

```text
PASS
WARN
FAIL
UNSUPPORTED
SKIPPED
```

ROADMAP also documents `NOT_APPLICABLE` as a schema-owned status. Keep it in
schemas where it is already defined. Do not treat it as interchangeable with
`UNSUPPORTED` or `SKIPPED`.

### Documentation support classifications

```text
SUPPORTED
TESTED
EXPERIMENTAL
PLANNED
UNSUPPORTED
```

Never describe `PLANNED` functionality as implemented.

### GPU capability progression

```text
DETECTED
DRIVER_READY
VULKAN_READY
ROCM_READY
HIP_READY
FRAMEWORK_READY
APPLICATION_READY
```

### NPU capability progression

```text
DETECTED
DRIVER_READY
FIRMWARE_READY
RUNTIME_READY
BACKEND_READY
MODEL_READY
APPLICATION_READY
```

A PCI device is not `APPLICATION_READY`. Package presence is not workload
execution. Later stages must consume structured facts from the Stage 1
profile, not re-parse human-readable command output as the source of truth.

### Capability assessment states

```text
AVAILABLE
READY
DEGRADED
UNSUPPORTED
UNKNOWN
```

Detection answers "what exists?". Assessment answers "what can this system
actually support?". Installation remains a later, separate step.

### Migration actions

```text
KEEP
REFACTOR
MOVE
SPLIT
MERGE
DEPRECATE
REMOVE
```

`REMOVE` is only for obsolete, duplicated, or safely replaced functionality.

### AI370 assumption classes

```text
REFERENCE_PLATFORM_FACT
CAPABILITY_DETECTION_RULE
TEMPORARY_COMPATIBILITY_RULE
UNNECESSARY_HARDCODE
```

Reference-platform facts may remain in profiles and fixtures. Unnecessary
hard-coding should become capability detection or declarative profile data.

------------------------------------------------------------------------

## Platform-layer mapping

The architecture document's implementation stages map onto the current
five-stage ROADMAP as follows. Current public commands stay on the ROADMAP
side.

| Platform layer | Target responsibility | Current ROADMAP owner | Current status |
| --- | --- | --- | --- |
| 0 Project foundation | Repo structure, logging, status conventions, tests | Repository infrastructure; not a ROADMAP stage | PARTIAL |
| 1 Hardware detection | Read-only CPU/GPU/NPU/OS/firmware facts | S1-M1 through S1-M5 | PARTIAL; only S1-M1 is canonically Implemented |
| 2 Platform validation | Distro, kernel, firmware, AMDGPU, AMDXDNA, device nodes | S2-M1, S2-M2, S2-M3 visibility, S2-M4 visibility, S2-M7 | PARTIAL |
| 3 Hardware optimization | CPU, memory, storage, power; plan then approved apply | S2-M5, S2-M6 | PARTIAL |
| 4 GPU compute | AMDGPU → Mesa → Vulkan → ROCm → HIP → framework → app | S2-M3 plus S3-M3 | PARTIAL |
| 5 NPU compute | AMDXDNA → firmware → runtime → backend → inference | S2-M4 plus S3-M4 | PARTIAL |
| 6 Local AI runtime | Ollama, llama.cpp, ONNX, PyTorch, Lemonade, FastFlowLM | S3-M1 through S3-M7 | PARTIAL; FastFlowLM is PLANNED |
| 7 Local coding AI | VS Code, local coding models, optional cloud fallback | S5-M1, S5-M2 | PLANNED |
| 8 Local image generation | ComfyUI on PyTorch/ROCm/Radeon | S4-M1, S4-M2 | PARTIAL |
| 9 Validation and benchmarking | Unified validation plus CPU/GPU/NPU benchmarks | S2-M7, S3-M6, S3-M7, S4-M7, S5-M5 | PARTIAL |
| 10 Desktop experience | Optional reversible macOS-like GNOME module | No ROADMAP owner | PLANNED |
| 11 Platform expansion | Newer Ryzen AI generations, OEMs, distributions | S1-M3 profiles plus later consumers | PARTIAL |

Boundary notes that later PRs must preserve:

- Architecture-layer 1 is read-only. Current `stage1` still invokes BIOS,
  kernel, GPU validation, and tuning-plan scripts. That is migration debt, not
  target Stage 1 behavior.
- Architecture-layer 3 belongs in ROADMAP Stage 2, not Stage 1.
- GPU and NPU remain independent. Current `stage2` installs both in one
  orchestrator path.
- Coding AI is ROADMAP Stage 5, not a new public `stage7`.
- Image generation is ROADMAP Stage 4, not a new public `stage8`.
- Desktop customization has no current owner and must stay isolated if added.

------------------------------------------------------------------------

## Current repository inventory

Classifications below were verified against tracked files. A documented
feature is not treated as implemented unless code exists.

### Foundation and orchestration

| Path | Status | Notes |
| --- | --- | --- |
| `ai370-optimize.sh` | PARTIAL | Routes ROADMAP and compatibility commands; mixes owners; default profile `ai370` |
| `scripts/lib/common.sh` | IMPLEMENTED | Shared reporting helpers; `ai370_*` names are compatibility surface |
| `scripts/validate-pr-title.sh` | IMPLEMENTED | Conventional Commit title gate |
| `scripts/validate-commit-subject.sh` | IMPLEMENTED | Commit-subject gate |
| `.github/workflows/*` | IMPLEMENTED | ShellCheck, PR title lint, release-please |
| `AGENTS.md`, `docs/ROADMAP.md`, `README.md` | PARTIAL | Authority exists; README still reports some ROADMAP-Planned work as implemented |
| `TASK_PROPOSALS.md` | DEPRECATED | Still describes Tier 1–5 follow-ups as current work |

### Detection and system profile

| Path | Status | Notes |
| --- | --- | --- |
| `scripts/s1-m1-probe-system.sh` | IMPLEMENTED | Canonical S1-M1 read-only probe; fixture replay supported |
| `scripts/s1-m2-normalize-profile.py` | IMPLEMENTED | Canonical S1-M2 fact normalization; GPU architecture from PCI map |
| `scripts/s1-m3-classify-platform.py` | IMPLEMENTED | Canonical S1-M3 platform classification |
| `scripts/s1-m4-derive-capabilities.py` | IMPLEMENTED | Canonical S1-M4 capability candidates; not validation claims |
| `scripts/s1-m5-publish-profile.py` | IMPLEMENTED | Canonical S1-M5 atomic v3 publication and inventory summary |
| `scripts/lib/hardware-detect.sh` | PARTIAL | Structured probe collector; `detect_gpu_arch()` looks up PCI IDs |
| `scripts/lib/system_profile.py` | IMPLEMENTED | Shared S1-M2–S1-M5 library behind the canonical CLIs |
| `scripts/10-detect-hardware.sh` | DEPRECATED | Compatibility wrapper; also publishes legacy `tier1-*` artifacts and `system-profile.json` |
| `scripts/75-detect-npu.sh` | DEPRECATED | Forwards to S1-M1 probe |
| `configs/schemas/system-profile*.json` | IMPLEMENTED | v1/v2 retained for migration; v3 is current |
| `configs/schemas/s1-m2-normalized-facts.schema.json` | IMPLEMENTED | S1-M2 contract |
| `configs/schemas/s1-m3-platform-classification.schema.json` | IMPLEMENTED | S1-M3 contract |
| `configs/schemas/s1-m4-capability-candidates.schema.json` | IMPLEMENTED | S1-M4 contract |
| `configs/schemas/s1-m5-system-profile.schema.json` | IMPLEMENTED | Canonical S1-M5 name for the v3 profile contract |
| `configs/schemas/s2-m3-gpu-runtime-visibility.schema.json` | IMPLEMENTED | S2-M3 visibility report contract |
| `configs/schemas/s2-m4-npu-runtime-validation.schema.json` | IMPLEMENTED | S2-M4 visibility report contract |
| `configs/profiles/gpu-pci-architectures.json` | IMPLEMENTED | Declarative PCI vendor:device to gfx mapping |
| `configs/profiles/ai370.env` | IMPLEMENTED | Reference-platform profile |
| `configs/profiles/generic-ryzen-ai.env` | IMPLEMENTED | Broader Ryzen AI profile |
| `tests/test_s1_m1_probe.py` | IMPLEMENTED | Fixture replay coverage |
| `tests/test_s1_m2_normalize.py` | IMPLEMENTED | PCI architecture and live artifact-name coverage |
| `tests/test_s1_m3_classify.py` | IMPLEMENTED | Table-driven family and unknown-platform coverage |
| `tests/test_s1_m4_capabilities.py` | IMPLEMENTED | Candidates are not validation claims |
| `tests/test_s1_m5_publish.py` | IMPLEMENTED | Schema pass/fail and interrupted-write coverage |
| `tests/test_system_profile.py` | IMPLEMENTED | Classification, fingerprint, schema tests |
| `tests/fixtures/raw-probes/v1/*` | IMPLEMENTED | AI370, Ryzen AI Pro 360, missing-tool, unsupported, unreadable, non-XDNA |

### Platform validation and optimization

| Path | Status | Notes |
| --- | --- | --- |
| `scripts/20-check-bios.sh` | PARTIAL | BIOS/firmware facts and policy; target S2-M1 |
| `scripts/25-check-firmware.sh` | DEPRECATED | Wrapper around `20-check-bios.sh` |
| `scripts/30-validate-kernel.sh` | PARTIAL | Kernel/module/firmware checks; target S2-M2 |
| `scripts/70-validate-gpu-stack.sh` | PARTIAL | AMDGPU/Vulkan/OpenCL/ROCm visibility; gfx1150 string match; target S2-M3 |
| `scripts/40-platform-tuning.sh` | PARTIAL | Combined CPU/memory/storage plan; `--apply-tuning` mutates; target S2-M5/S2-M6 |
| `scripts/40-optimize-cpu.sh`, `50-optimize-memory.sh`, `60-optimize-storage.sh` | DEPRECATED | Wrappers around platform tuning |
| `scripts/65-amd-acceleration-install.sh` | PARTIAL | Explicit-risk ROCm/XRT install; target S2-M6 |
| `scripts/90-validate.sh` | PARTIAL | Mixed S1/S2 aggregate; writes `tier1-validation.json`; gfx1150/NPU acceptance |
| `scripts/80-benchmark-local-ai.sh` | PARTIAL | Optional visibility smoke; belongs in S3-M6, not Stage 1 |

### GPU, NPU, and local runtimes

| Path | Status | Notes |
| --- | --- | --- |
| `scripts/100-install-pytorch-rocm.sh` | PARTIAL | Install/validate PyTorch ROCm into repo venv; target S3-M3 |
| `scripts/110-install-llama-cpp.sh` | PARTIAL | HIP/Vulkan/CPU backend selection; default HIP target `gfx1150`; target S3-M2 |
| `scripts/120-install-ollama.sh` | PARTIAL | Install or validate Ollama; target S3-M2 |
| `scripts/140-benchmark-llm.sh` | PARTIAL | LLM smoke; target S3-M6 |
| `scripts/145-write-tier2-validation.sh` | DEPRECATED | Compatibility aggregate; target S3-M7 |
| `scripts/150-validate-offline-model-storage.sh` | PARTIAL | Offline model layout checks; target S3-M1 |
| `scripts/155-stage-model-layout.sh` | PARTIAL | Creates layout stubs; no downloads; target S3-M1 |
| `scripts/160-install-lemonade.sh`, `165-validate-lemonade.sh`, `170-install-turnkeyml.sh` | PARTIAL | Optional Lemonade/TurnkeyML; target S3-M5 |
| `scripts/lib/lemonade-env.sh` | PARTIAL | Lemonade environment helper |
| `scripts/200-install-onnxruntime.sh` | PARTIAL | ONNX Runtime install/validate; target S3-M4 |
| `scripts/205-install-xrt-ryzen-ai.sh` | PARTIAL | XRT/Ryzen AI inventory or risk-accepted install |
| `scripts/210-check-ryzen-ai-software.sh` | PARTIAL | Mixes NPU visibility and runtime checks |
| `scripts/220-check-vitis-ai-ep.sh` | PARTIAL | Vitis AI EP visibility |
| `scripts/230-benchmark-npu.sh` | PARTIAL | NPU MatMul/diagnostic; must not remain a visibility-only PASS |
| `scripts/240-write-tier3-validation.sh` | DEPRECATED | Compatibility aggregate |
| `scripts/245-compare-cpu-gpu-npu.sh` | PARTIAL | Heterogeneous comparison; gfx1150 guidance strings |
| `scripts/250-install-digest-ai.sh`, `255-analyze-model-digest.sh` | PARTIAL | Optional diagnostics; not NPU execution proof |
| `scripts/lib/npu_ep_verify.py`, `scripts/lib/npu-venv.sh` | PARTIAL | Provider/execution helpers; split visibility vs execution |
| `.ai370-ai/ryzen-ai/source/install_ryzen_ai.sh` | PARTIAL | Tracked AMD Ryzen AI 1.7.x installer consumed by `scripts/205-install-xrt-ryzen-ai.sh`; requires exact `python3.12`; pins `ryzen-ai>=1.7.0.dev0,<1.8.0.dev0` and `device-essentials-strx`/`device-essentials-phx` ranges; installs into the caller `-p` venv (205 uses `.ai370-ai/ryzen-ai/venv`); wheels must be in the process CWD |
| `configs/ai-runtime/requirements-offline.txt` | IMPLEMENTED | Pinned offline CPU Python stack (`onnxruntime==1.22.0`, transformers 4.52.4, and related wheels); consumed via `configs/offline/ai-runtime.env` and `scripts/lib/offline-paths.sh`; distinct from Ryzen AI `onnxruntime-vitisai` |
| `.ai370-ai/tools/llama.cpp` | PARTIAL | Tracked gitlink (mode `160000`, commit `86b94708f22478f900b76ca02e316f4f3418faff`); no `.gitmodules`; canonical checkout path for `scripts/110-install-llama-cpp.sh` |
| FastFlowLM | PLANNED | Named in the architecture document only |

### Applications, models, and desktop

| Path | Status | Notes |
| --- | --- | --- |
| `scripts/70-comfyui-workflows.sh` | PARTIAL | Clones/installs ComfyUI; not the canonical S4-M1 contract |
| `scripts/420-benchmark-comfyui.sh` | PARTIAL | Synthetic timings; not live execution proof |
| `workflows/comfyui/*` | PARTIAL | SDXL workflow templates |
| `scripts/130-install-open-webui.sh` | PARTIAL | Target S4-M6 |
| `scripts/300-install-anythingllm.sh`, `310-install-embedding-models.sh`, `320-validate-rag.sh` | PARTIAL | Target S4-M3; `320` sample text mentions Radeon 890M |
| GAIA, LM Studio | PLANNED | ROADMAP S4-M4/S4-M5 |
| VS Code / Continue / Aider local coding AI | PLANNED | ROADMAP S5-M1/S5-M2; workspace file is editor config only |
| `desktop/macos-like/` | PLANNED | No desktop module exists |
| `configs/models/*`, `scripts/lib/offline-paths.sh` | PARTIAL | Shared model layout under `.ai370-ai/models`; offline-paths default requirements file is `configs/ai-runtime/requirements-offline.txt` |

### Tests and legacy archive

| Path | Status | Notes |
| --- | --- | --- |
| `tests/smoke_tier1.sh` | PARTIAL | Portable CLI smoke; still asserts `tier1-*` artifacts and gfx1150 keys |
| `tests/smoke_tier2.sh` | PARTIAL | Portable runtime/layout smoke |
| `tests/test_repository_instructions.py` | IMPLEMENTED | Instruction-file contract |
| `scripts/legacy/*` | DEPRECATED | Frozen archive; no new behavior |

------------------------------------------------------------------------

## AI370-specific assumptions

Verified in code, profiles, fixtures, tracked vendor installers, pin
files, and docs.

| Location | Assumption | Class | Recommended action |
| --- | --- | --- | --- |
| `configs/profiles/ai370.env` | HX 370, gfx1150, XDNA2, BIOS 2.01, Minisforum EliteMini AI370 | REFERENCE_PLATFORM_FACT | KEEP as declarative profile data |
| `tests/fixtures/raw-probes/v1/observed-ai370.json` and profile fixtures | Same reference identity | REFERENCE_PLATFORM_FACT | KEEP as regression fixtures |
| `scripts/lib/system_profile.py` `PLATFORM_DEFINITIONS` `ai370` | Exact DMI/CPU match for EliteMini AI370 | REFERENCE_PLATFORM_FACT | KEEP; unknown hosts must remain valid |
| `scripts/lib/system_profile.py` `CPU_FAMILY_SIGNATURES` | CPU family 26 / model 36 → `ryzen-ai-300` | CAPABILITY_DETECTION_RULE | KEEP; extend with data, not collector rewrites |
| `scripts/lib/system_profile.py` `GPU_ARCHITECTURE_MAPPINGS` | `gfx1150`/`gfx1151` → RDNA 3.5 | CAPABILITY_DETECTION_RULE | KEEP and extend |
| `configs/profiles/gpu-pci-architectures.json` | `1002:1900` → `gfx1150` | CAPABILITY_DETECTION_RULE | KEEP; extend with PCI data, not marketing names |
| `scripts/lib/system_profile.py` `NPU_FAMILY_MAPPINGS` | PCI `1022:17f0` XDNA2, `1022:1502` XDNA | CAPABILITY_DETECTION_RULE | KEEP; do not treat these IDs as universal PASS |
| `configs/profiles/generic-ryzen-ai.env` | Broad Ryzen AI / XDNA profile | CAPABILITY_DETECTION_RULE | KEEP |
| `scripts/lib/hardware-detect.sh` `detect_gpu_arch()` | PCI `[vvvv:dddd]` lookup via `gpu-pci-architectures.json` | CAPABILITY_DETECTION_RULE | KEEP; do not restore `890M`/`Strix` greps |
| `scripts/70-validate-gpu-stack.sh` | Uses `detect_gpu_arch()` PCI lookup | CAPABILITY_DETECTION_RULE | KEEP; full S2-M3 rewrite remains later |
| `scripts/90-validate.sh` | Missing gfx1150/NPU is acceptance WARN, or FAIL with `--strict` | TEMPORARY_COMPATIBILITY_RULE | SPLIT: facts in S1, policy in S2; `--strict` must not become generic policy |
| `scripts/110-install-llama-cpp.sh` | `LLAMA_CPP_AMDGPU_TARGETS` defaults to `gfx1150` | UNNECESSARY_HARDCODE | REFACTOR to profile/capability input |
| `scripts/245-compare-cpu-gpu-npu.sh` | gfx1150/Radeon 890M guidance strings | REFERENCE_PLATFORM_FACT | KEEP as reference advice; do not gate generic hosts |
| `scripts/lib/hardware-detect.sh` | `TARGET_UBUNTU_VERSION=26.04` | TEMPORARY_COMPATIBILITY_RULE | REFACTOR behind a distribution abstraction after Ubuntu reference stability |
| `scripts/lib/system_profile.py` | Schema name `ai370-system-profile` | TEMPORARY_COMPATIBILITY_RULE | KEEP until a schema-versioned rename |
| `ai370-optimize.sh`, most scripts | Default `PROFILE=ai370` | TEMPORARY_COMPATIBILITY_RULE | KEEP default; do not infer capabilities from the name alone |
| `.ai370-ai/` model and runtime root | AI370-named local artifact tree | TEMPORARY_COMPATIBILITY_RULE | KEEP path until a documented compatibility alias exists |
| `.ai370-ai/ryzen-ai/source/install_ryzen_ai.sh` | Exact `python3.12` interpreter | TEMPORARY_COMPATIBILITY_RULE | KEEP as a Ryzen AI 1.7.x vendor requirement; do not make Python 3.12 a generic platform gate |
| `.ai370-ai/ryzen-ai/source/install_ryzen_ai.sh` | `ryzen-ai>=1.7.0.dev0,<1.8.0.dev0` and `device-essentials-strx`/`device-essentials-phx` ranges | TEMPORARY_COMPATIBILITY_RULE | KEEP as vendor package pins; replace only with a newer vendor installer |
| `.ai370-ai/ryzen-ai/source/install_ryzen_ai.sh` | Installs Strix and Phoenix device-essentials without SoC detection | UNNECESSARY_HARDCODE | KEEP the vendor script; do not copy this into generic collectors |
| `.ai370-ai/ryzen-ai/source/install_ryzen_ai.sh` | Warns below 8 CPUs, 36 GB RAM, or 50 GB disk; leftover Ubuntu 22.04 `/usr/include/asm` note | REFERENCE_PLATFORM_FACT | KEEP as vendor installer warnings, not Stage 1 success requirements |
| `.ai370-ai/ryzen-ai/source/install_ryzen_ai.sh` | Venv/C++ install paths via `-p`/`-c`; `scripts/205` defaults to `.ai370-ai/ryzen-ai` | TEMPORARY_COMPATIBILITY_RULE | KEEP the path until a documented alias exists |
| `configs/ai-runtime/requirements-offline.txt` | Pinned CPU `onnxruntime==1.22.0` and related wheels | TEMPORARY_COMPATIBILITY_RULE | KEEP as the S3 offline CPU pin file; do not treat it as NPU ORT |
| `.ai370-ai/tools/llama.cpp` | Gitlink commit pin at `.ai370-ai/tools/llama.cpp` with no `.gitmodules` | TEMPORARY_COMPATIBILITY_RULE | KEEP the gitlink; `scripts/110-install-llama-cpp.sh` may clone or update the same path |
| `README.md` Stage 1/2 "Implemented" summary | Reports canonical Planned milestones as implemented | UNNECESSARY_HARDCODE | REFACTOR status text to match ROADMAP |
| `TASK_PROPOSALS.md` | Tier 1–5 as current architecture | DEPRECATED | DEPRECATE; do not extend |

BIOS 2.01, Ubuntu 26.04, kernel 7.x, Radeon 890M, and XDNA2 remain reference
facts. They are not generic success requirements. Unknown or future Ryzen AI
hosts must still produce a valid profile with explicit unknown or unsupported
states.

------------------------------------------------------------------------

## File-by-file migration map

Columns follow architecture Task 3. Hardware and distribution assumptions are
abbreviated; see the assumption table for the full class.

### Orchestrator, libraries, and schemas

| Current path | Responsibility | Dependencies | Assumptions | Target | Action | Required tests | Risk |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ai370-optimize.sh` | Command router | Numbered scripts | Default `ai370` profile | Router only; each branch keeps its ROADMAP owner | SPLIT command owners; KEEP file | Help/smoke tests | Medium |
| `scripts/lib/common.sh` | Shared shell helpers | Reports dir | `ai370_*` names | Shared infrastructure | KEEP; document consumer milestone per function | ShellCheck; smoke syntax | Low |
| `scripts/lib/hardware-detect.sh` | Probe helpers and raw collector | `lscpu`, `lspci`, sysfs, DMI | Ubuntu 26.04 defaults; GPU arch from PCI map | Detection modules | KEEP PCI lookup; SPLIT facts from policy | Probe fixtures | High |
| `scripts/lib/system_profile.py` | Normalize, classify, publish profile | Raw inventory, schemas, PCI map | Schema name `ai370-*`; declarative AI370 match | S1-M2 through S1-M5 library | KEEP as shared library behind canonical scripts | `test_system_profile.py` plus owner tests | High |
| `configs/schemas/system-profile.schema.json` | v3 profile contract | None | Schema id still AI370-named | S1-M5 | KEEP; version before rename | Schema fixtures | High |
| `configs/schemas/system-profile-v1.schema.json`, `...-v2.schema.json` | Migration validation | v3 publisher | Historical | S1-M5 migration | KEEP until consumers reject v1 and finish v2 | Existing schema tests | Medium |
| `configs/profiles/ai370.env` | Reference profile | BIOS/GPU/NPU expected values | REFERENCE_PLATFORM_FACT | S1-M3 | KEEP | Classification tests | Low |
| `configs/profiles/generic-ryzen-ai.env` | Broad Ryzen AI profile | Family strings | CAPABILITY_DETECTION_RULE | S1-M3 | KEEP; extend with data | Unknown-host tests | Low |
| `configs/tuning/*.env` | Safe/aggressive tuning modes | Platform tuning | Mode names | S2-M5/S2-M6 | KEEP | Plan idempotence tests | Low |
| `configs/amd-acceleration.env` | ROCm/XRT artifact layout | Ubuntu 26.04 package layout | Distro-specific | S2-M6 / S3-M3/S3-M4 | REFACTOR behind platform abstraction later | Offline missing-artifact tests | Medium |
| `configs/models/*` | Manifest and storage policy | `.ai370-ai/models` | Path name | S3-M1 | KEEP layout; REFACTOR naming later | `smoke_tier2.sh` layout checks | Low |
| `configs/ai-runtime/requirements-offline.txt` | Offline CPU Python pin file | `scripts/lib/offline-paths.sh`, wheelhouse | `onnxruntime==1.22.0` and related pins; not VitisAI ORT | S3 CPU runtime / S3-M2 | KEEP; split NPU pins if added | Offline missing-wheelhouse tests | Medium |
| `configs/offline/ai-runtime.env`, `configs/persistence/runtime.env` | Offline and persistence defaults | Runtime scripts | Runtime-only persistence; `OFFLINE_REQUIREMENTS` points at the pin file | Stage 3 / S5-M3 | KEEP | Persistence-refusal tests | Low |
| `configs/profiles/gpu-pci-architectures.json` | PCI vendor:device to gfx map | None | Fixture identity `1002:1900` | S1-M2 | KEEP; extend with PCI data | `test_s1_m2_normalize.py` | Low |
| `scripts/s1-m1-probe-system.sh` | Canonical raw probe | `hardware-detect.sh` | None beyond collector | S1-M1 | KEEP | `test_s1_m1_probe.py` | Low |
| `scripts/s1-m2-normalize-profile.py` | Normalize raw inventory | S1-M1 JSON, PCI map | None beyond collector | S1-M2 | KEEP | `test_s1_m2_normalize.py` | Low |
| `scripts/s1-m3-classify-platform.py` | Platform classification | S1-M2 facts | Declarative AI370 match | S1-M3 | KEEP | `test_s1_m3_classify.py` | Low |
| `scripts/s1-m4-derive-capabilities.py` | Capability candidates | S1-M2 facts | Candidates are not validation | S1-M4 | KEEP | `test_s1_m4_capabilities.py` | Low |
| `scripts/s1-m5-publish-profile.py` | Profile publication | S1-M2–M4 artifacts | v3 generator name remains `system_profile.py` | S1-M5 | KEEP | `test_s1_m5_publish.py` | Medium |
| `scripts/10-detect-hardware.sh` | Legacy inventory publisher | S1-M1 plus S1-M2–S1-M5 pipeline | `tier1-*` filenames | Compatibility until R1 | DEPRECATE after consumers move to `stage1-profile` | Smoke still expects `tier1-npu.json` | Medium |
| `scripts/75-detect-npu.sh` | NPU wrapper | S1-M1 | None | Compatibility | DEPRECATE/REMOVE at R1 | Probe tests | Low |

### Validation, optimization, GPU, and NPU

| Current path | Responsibility | Dependencies | Assumptions | Target | Action | Required tests | Risk |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `scripts/20-check-bios.sh` | BIOS/firmware observation and policy | DMI, fwupd, profile `EXPECTED_BIOS_VERSION` | BIOS 2.01 is profile target, not generic gate | S2-M1 | SPLIT facts vs policy | Firmware fixtures | Medium |
| `scripts/25-check-firmware.sh` | Wrapper | `20-check-bios.sh` | None | Compatibility | DEPRECATE | Existing BIOS tests | Low |
| `scripts/30-validate-kernel.sh` | Kernel, modules, firmware dirs | `amdgpu` module, linux-firmware | Radeon 890M advice strings | S2-M2 | REFACTOR to capability checks | Supported/unsupported matrix | Medium |
| `scripts/70-validate-gpu-stack.sh` | GPU stack visibility | lspci, vulkaninfo, clinfo, rocminfo | Marketing-name gfx1150 | S2-M3 | REFACTOR; distinguish visibility from compute | Missing device/driver/Vulkan/ROCm fixtures | High |
| `scripts/40-platform-tuning.sh` | CPU/memory/storage plan and optional apply | governors, zram, NVMe | Invoked from current `stage1` | S2-M5/S2-M6 | SPLIT plan vs `--approve` apply; MOVE out of Stage 1 | No-mutation and idempotence | High |
| `scripts/40-optimize-cpu.sh`, `50-optimize-memory.sh`, `60-optimize-storage.sh` | Wrappers | Platform tuning | None | Compatibility | DEPRECATE | Wrapper smoke | Low |
| `scripts/65-amd-acceleration-install.sh` | Risk-accepted stack install | `amd-acceleration.env` | Ubuntu package names | S2-M6 | KEEP explicit approval; no Stage 1 caller | Approval/backup tests | High |
| `scripts/90-validate.sh` | Mixed hardware aggregate | Prior `tier1-*` artifacts | gfx1150/NPU acceptance | S1-M5 facts plus S2-M7 policy | SPLIT | Gate schema tests | High |
| `scripts/80-benchmark-local-ai.sh` | Optional AI visibility smoke | Local venv | Called from Stage 1 flag | S3-M6 | MOVE | Benchmark methodology tests | Medium |
| `scripts/100-install-pytorch-rocm.sh` | PyTorch ROCm runtime | venv, wheel indexes | ROCm indexes | S3-M3 | REFACTOR; prove GPU vs CPU selection | CPU/GPU fallback tests | High |
| `scripts/110-install-llama-cpp.sh` | llama.cpp build/install | HIP/Vulkan/CPU; `.ai370-ai/tools/llama.cpp` gitlink | Default `gfx1150` target; checkout path `.ai370-ai/tools/llama.cpp` | S3-M2 | REFACTOR backend from profile | Backend-selection fixtures | Medium |
| `.ai370-ai/tools/llama.cpp` | Tracked llama.cpp source gitlink | `scripts/110-install-llama-cpp.sh` | Mode `160000` commit `86b94708f22478f900b76ca02e316f4f3418faff`; no `.gitmodules` | S3-M2 | KEEP gitlink as optional source tree | Offline existing-binary tests | Medium |
| `scripts/120-install-ollama.sh` | Ollama install/validate | Network or preinstalled binary | None hardware-specific | S3-M2 | KEEP then rename after canonical validation | Offline missing-binary tests | Low |
| `scripts/200-install-onnxruntime.sh` | ONNX Runtime | venv/wheelhouse | None | S3-M4 | KEEP then canonicalize | Provider tests | Medium |
| `scripts/205-install-xrt-ryzen-ai.sh` | XRT/Ryzen AI inventory or install | Staged debs; tracked `install_ryzen_ai.sh` | Distro packages; python3.12 | S2-M4 visibility / S3-M4 install | SPLIT | Inventory-only vs approved install | High |
| `.ai370-ai/ryzen-ai/source/install_ryzen_ai.sh` | Vendor Ryzen AI 1.7.x installer | python3.12, local `.whl`, voe tarballs | Exact Python 3.12; `ryzen-ai` 1.7.x; strx/phx device-essentials; 8 CPU / 36 GB / 50 GB warnings; CWD wheels | S3-M4 backend installer consumed by `scripts/205` | KEEP as vendor input; not the NPU architecture | Missing python3.12 and missing-wheel tests | High |
| `scripts/210-check-ryzen-ai-software.sh` | Ryzen AI software checks | NPU venv | Presence vs execution mixed | S2-M4 / S3-M4 | SPLIT | Visibility vs inference tests | High |
| `scripts/220-check-vitis-ai-ep.sh` | Vitis AI EP | ONNX Runtime | One backend among several | S3-M4 modular backend | KEEP as a backend, not the architecture | EP selection tests | Medium |
| `scripts/230-benchmark-npu.sh` | NPU diagnostic/benchmark | Vitis AI EP, XRT | Execution can fall back to CPU | S3-M4/S3-M6 | REFACTOR; record actual accelerator | Fallback-detection tests | High |
| `scripts/245-compare-cpu-gpu-npu.sh` | Heterogeneous comparison | 140/230 results | gfx1150 advice | S3-M6 | REFACTOR to consume structured runtime reports | Accelerator-identity tests | Medium |
| `scripts/lib/npu_ep_verify.py` | Provider execution proof | ONNX Runtime | NPU PASS requires profiled EP | S2-M4 visibility vs S3-M4 execution | SPLIT | Provider-execution fixtures | High |
| `scripts/lib/npu-venv.sh` | NPU Python env | Ryzen AI venv | Path conventions | S3-M4 | KEEP | Env-resolution tests | Low |
| `scripts/145-write-tier2-validation.sh`, `scripts/240-write-tier3-validation.sh` | Compatibility aggregates | Runtime/NPU reports | Tier names | S3-M7 | REPLACE after canonical aggregates | Gate JSON structure | Medium |

### Applications, benchmarks, tests, and docs

| Current path | Responsibility | Dependencies | Assumptions | Target | Action | Required tests | Risk |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `scripts/130-install-open-webui.sh` | Open WebUI | Local LLM runtime | None | S4-M6 | MOVE from runtime orchestration | Offline UI/backend tests | Medium |
| `scripts/140-benchmark-llm.sh` | LLM smoke benchmark | Ollama/llama.cpp | Optional `--bench` | S3-M6 | KEEP then canonicalize | Fixed-workload tests | Medium |
| `scripts/150-validate-offline-model-storage.sh`, `scripts/155-stage-model-layout.sh` | Model storage | Manifest | `.ai370-ai` root | S3-M1 | KEEP | Offline checksum/layout | Low |
| `scripts/160-install-lemonade.sh`, `165-validate-lemonade.sh`, `170-install-turnkeyml.sh`, `scripts/lib/lemonade-env.sh` | Lemonade/TurnkeyML | Optional flag | Not a Stage 2 gate | S3-M5 | KEEP; modular runtime | Server/offline inference | Medium |
| `scripts/250-install-digest-ai.sh`, `255-analyze-model-digest.sh`, `scripts/lib/digest_analyze.py` | Model diagnostics | Optional flag | Not NPU proof | S3 optional diagnostics | KEEP | Missing-model tests | Low |
| `scripts/300-install-anythingllm.sh`, `310-install-embedding-models.sh`, `320-validate-rag.sh` | RAG application | Model storage | Sample text mentions 890M | S4-M3 | REFACTOR sample text; KEEP app split from storage | Offline ingest/retrieve | Medium |
| `scripts/70-comfyui-workflows.sh` | ComfyUI install/workflows | PyTorch/ROCm | Network clone | S4-M1/S4-M2 | REFACTOR above GPU runtime; do not report NPU accel | Offline install/lifecycle | High |
| `scripts/420-benchmark-comfyui.sh` | ComfyUI benchmark | Workflows | Synthetic timings | S4-M2 / S3-M6 | REFACTOR to live execution | Live API tests | Medium |
| `workflows/comfyui/*` | SDXL templates | ComfyUI | No NPU assumption | S4-M2 | KEEP | Workflow launch tests | Low |
| `tests/smoke_tier1.sh`, `tests/smoke_tier2.sh` | Portable CLI smokes | Orchestrator | `tier*` artifacts | Owner-specific `test_sN_mN_*` | REPLACE at R1/R2 | Deterministic fixtures | Medium |
| `tests/test_s1_m1_probe.py`, `tests/test_system_profile.py` | Profile/probe contracts | Fixtures | AI370 reference plus non-AI370 | S1-M1/S1-M2/S1-M5 | KEEP and split by milestone | Existing plus unknown-host | Low |
| `tests/fixtures/**` | Sanitized hardware evidence | None | Reference and counterexamples | Detection/classification | KEEP; add newer Ryzen AI as data | Classification matrix | Low |
| `scripts/legacy/*` | Frozen archive | Historical | Tier/phase names | Compatibility archive | KEEP frozen; REMOVE at R1/R2 | No new tests | Low |
| `docs/ROADMAP.md` | Implementation authority | All deliverables | Five stages | Current authority | KEEP; update when boundaries change | Instruction tests | High |
| `docs/HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md` | Target architecture | None | Future 0–11 layers | Target architecture | KEEP | Instruction tests | Low |
| `docs/npu-status.md` | NPU operator notes | Stage 2 NPU scripts | AI370/XDNA | S2-M4/S3-M4 docs | REFACTOR owners as scripts split | Docs-only | Low |
| `docs/automatic1111-review.md`, `docs/forge-review.md`, `docs/openclaw-multi-llm-agent.md` | Application audits | None | Planned/non-goals | Stage 4/5 research | KEEP as non-implementation | None | Low |
| `README.md` | User commands | Orchestrator | Status drift vs ROADMAP | User guide | REFACTOR status claims | Help smoke | Medium |
| `TASK_PROPOSALS.md` | Stale Tier follow-ups | None | Tier architecture | None | DEPRECATE | None | Low |
| VS Code / Continue / Aider / FastFlowLM / desktop module | Target applications | Runtime layer | None implemented | S5-M1/S5-M2, S3 runtime, desktop layer | Do not add until abstractions exist | Owner tests when added | High |

No production files are recommended for `REMOVE` in the first implementation
PRs except frozen `scripts/legacy/*` at the documented R1/R2 targets.

------------------------------------------------------------------------

## Subsequent PR sequence

This PR is the low-risk first migration PR from architecture Task 24. Later
PRs must stay small, keep detection read-only, and add or preserve regression
tests before replacing working code.

Recommended order, using ROADMAP owners rather than new public stage numbers:

1. **Detection facts, not marketing names** — **done.** Canonical S1-M2 through
   S1-M5 exist; GPU architecture comes from PCI mappings, not `890M`/`Strix`.
2. **Capability assessment** — expose GPU/NPU ladders as structured states;
   candidates must not claim validation. S1-M4 candidates exist; Stage 2/3
   ladders remain Planned.
3. **Stop Stage 1 mutation and mixed validation** — move BIOS/kernel/GPU
   policy and tuning plan/apply to S2-M1 through S2-M6; `stage1` becomes
   read-only profile publication.
4. **Independent GPU module** — S2-M3 visibility plus S3-M3 framework
   execution; package presence is not GPU compute.
5. **Independent NPU module** — S2-M4 visibility plus S3-M4 execution;
   Vitis AI/XRT/Lemonade remain backends, not the architecture.
6. **Local runtime abstraction** — S3-M1 through S3-M7; add FastFlowLM only
   as an optional module when supported.
7. **Applications above runtimes** — ComfyUI S4-M1/S4-M2, RAG/Open WebUI,
   then coding AI S5-M1/S5-M2. Do not couple VS Code to ROCm or AMDXDNA
   internals.
8. **Unified validation and heterogeneous benchmarks** — S2-M7, S3-M6/S3-M7,
   S4-M7, S5-M5. Record the accelerator that actually ran.
9. **Optional desktop module** — only after compute validation is stable;
   add a ROADMAP owner first. Cosmetic, reversible, independently removable.
10. **Hardware and distro expansion** — add profiles/fixtures for Ryzen AI
    300/400 and other OEMs after the abstraction exists. Duplicate package
    logic for other distributions only after Ubuntu 26.04 reference behavior
    is isolated.
11. **Repository rename** — prepare docs and names, but do not rename
    `gibboda/ai370-ubuntu-optimizer` until explicitly authorized.

Do not perform a large-scale directory rewrite to the architecture document's
example `detection/` / `compute/` / `runtimes/` tree before the current
scripts have tests at the new boundaries.

------------------------------------------------------------------------

## Regression requirements

Before replacing an AI370-specific path, prove the generalized replacement
preserves reference behavior.

Minimum preserved coverage:

- Minisforum EliteMini AI370 identity
- Ryzen AI 9 HX 370
- Radeon 890M / gfx1150
- XDNA2
- BIOS 2.01 handling in the `ai370` profile
- Ubuntu 26.04 reference-platform behavior
- Tracked AMD `install_ryzen_ai.sh` Python 3.12 and Ryzen AI 1.7.x package contract
- Offline CPU pin file `configs/ai-runtime/requirements-offline.txt`
- llama.cpp gitlink path `.ai370-ai/tools/llama.cpp`

Portable CI must keep using versioned fixtures. Physical EliteMini tests stay
opt-in. Required fixture classes for hardware-classification changes:

- reference AI370
- newer Ryzen AI (existing `observed-ryzen-ai-pro-360.json` is the start)
- missing tool
- degraded or unbound driver
- unsupported host
- non-XDNA accelerator

Current automated coverage to retain until replaced by owner-specific tests:

- `python3 -m unittest tests.test_system_profile tests.test_s1_m1_probe tests.test_s1_m2_normalize tests.test_s1_m3_classify tests.test_s1_m4_capabilities tests.test_s1_m5_publish tests.test_repository_instructions`
- `bash tests/smoke_tier1.sh`
- `bash tests/smoke_tier2.sh`
- `shellcheck --severity=error $(git ls-files '*.sh')`

Do not hide unexpected failures with unconditional `|| true`.

------------------------------------------------------------------------

## Documentation and status drift

`README.md` currently describes the mixed `stage1` orchestrator (BIOS, kernel,
GPU visibility, and tuning) as if it were the canonical Stage 1 contract.
ROADMAP is authoritative: S1-M1 through S1-M5 are Implemented as the read-only
profile pipeline (`stage1-probe` and `stage1-profile`). Canonical S2 through S5
milestones remain Planned until their outputs, tests, and docs exist. Later
documentation PRs must keep README status language aligned with ROADMAP rather
than with historical Tier/Package summaries.

The architecture document is target design. Features listed there as local
coding AI, FastFlowLM, unified master validation, heterogeneous live
benchmarks, and macOS-like desktop remain `PLANNED` unless a ROADMAP
milestone later records them as Implemented.

------------------------------------------------------------------------

## Out of scope for this PR

This plan does not:

- rewrite production scripts
- rename the GitHub repository
- add public `stage6`–`stage11` commands
- add a desktop module
- add FastFlowLM, VS Code coding-agent, GAIA, or LM Studio implementations
- change system-profile schema version
- mark any ROADMAP milestone Implemented

Success for this PR is a reviewed inventory and mapping that later PRs can
implement one architectural boundary at a time.
