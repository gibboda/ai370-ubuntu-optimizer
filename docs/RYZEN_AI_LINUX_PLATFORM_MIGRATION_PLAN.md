# Ryzen AI Linux Platform Migration Plan

This document is the current-to-target migration map required by
[`HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md`](HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md)
Tasks 2 through 5 and Task 24. It is analysis and planning only. It does not
authorize a repository rewrite, a GitHub rename, or new public `stageN`
commands.

**Last reviewed:** 2026-08-23

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
Current version at last review: `0.25.0`. NPU publisher landing remains `0.21.0`.

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
| 1 Hardware detection | Read-only CPU/GPU/NPU/OS/firmware facts | S1-M1 through S1-M5 | PARTIAL; S1-M1 through S1-M5 are Implemented; `stage1` is read-only profile publication |
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

- Architecture-layer 1 is read-only. `stage1` now publishes the S1-M1 through
  S1-M5 profile only. BIOS, kernel, GPU validation, and tuning-plan scripts
  run from `stage2-platform-*` / `stage2-optimize-*`. Canonical S2-M7 JSON is
  Implemented. Canonical S2-M1/S2-M2/S2-M5/S2-M6 JSON is In progress.
  Remaining S2-M1/S2-M2 work is remediation docs and the kernel/driver matrix.
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
| `scripts/external-agent` | IMPLEMENTED | S5-M6 vendor-neutral local wrapper for explicit `grok` / `agy` invocation |
| `.github/workflows/*` | IMPLEMENTED | ShellCheck, PR title lint, release-please |
| `AGENTS.md`, `docs/ROADMAP.md`, `README.md` | PARTIAL | Authority exists; README Stage 2 tracks ROADMAP (S2-M1–S2-M6 In progress; S2-M7 Implemented) |
| `TASK_PROPOSALS.md` | DEPRECATED | Stage/Milestone compatibility backlog; do not add new Tier-named tasks |
| `.github/issues/pr2-capability-ladders.md`, `.github/issues/pr3-read-only-stage1.md` | IMPLEMENTED | Tracking templates for GitHub issues #168 and #169 |

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
| `scripts/lib/capability_ladder.py` | IMPLEMENTED | GPU/NPU ladder library plus S2-M3/S2-M4 report builders |
| `scripts/lib/platform_validation.py` | IMPLEMENTED | S2-M7 aggregate builder, policy, and compatibility shim JSON |
| `scripts/lib/optimization_plan.py` | IMPLEMENTED | S2-M5 plan and S2-M6 apply builders; does not run governors or zram |
| `scripts/s2-m3-validate-gpu-stack.sh` | IMPLEMENTED | Canonical S2-M3 GPU visibility collector; consumes S1-M5 profile when present |
| `scripts/s2-m3-publish-gpu-visibility.py` | IMPLEMENTED | Canonical S2-M3 atomic publisher and schema validation |
| `scripts/s2-m4-validate-npu-stack.sh` | IMPLEMENTED | Canonical S2-M4 NPU visibility collector; no `230-benchmark-npu.sh`; requires S1-M5 profile |
| `scripts/s2-m4-publish-npu-visibility.py` | IMPLEMENTED | Canonical S2-M4 atomic publisher and schema validation |
| `scripts/s2-m7-publish-platform-validation.py` | IMPLEMENTED | Canonical S2-M7 aggregate publisher; requires S1-M5 profile; rejects fingerprint-mismatched S2 reports |
| `scripts/s2-m5-publish-optimization-plan.py` | IMPLEMENTED | Canonical S2-M5 plan publisher; plan-only; requires S1-M5 profile |
| `scripts/s2-m6-publish-optimization-application.py` | IMPLEMENTED | Canonical S2-M6 apply publisher; records `--approve`; backup status is `not-implemented` |
| `scripts/10-detect-hardware.sh` | DEPRECATED | Compatibility wrapper; also publishes legacy `tier1-*` artifacts and `system-profile.json` |
| `scripts/75-detect-npu.sh` | DEPRECATED | Forwards to S1-M1 probe |
| `configs/schemas/system-profile*.json` | IMPLEMENTED | v1/v2 retained for migration; v3 is current |
| `configs/schemas/s1-m2-normalized-facts.schema.json` | IMPLEMENTED | S1-M2 contract |
| `configs/schemas/s1-m3-platform-classification.schema.json` | IMPLEMENTED | S1-M3 contract |
| `configs/schemas/s1-m4-capability-candidates.schema.json` | IMPLEMENTED | S1-M4 contract |
| `configs/schemas/s1-m5-system-profile.schema.json` | IMPLEMENTED | Canonical S1-M5 name for the v3 profile contract |
| `configs/schemas/s2-m3-gpu-runtime-visibility.schema.json` | IMPLEMENTED | S2-M3 visibility report contract |
| `configs/schemas/s2-m4-npu-runtime-validation.schema.json` | IMPLEMENTED | S2-M4 visibility report contract |
| `configs/schemas/s2-m7-platform-validation.schema.json` | IMPLEMENTED | S2-M7 platform aggregate contract |
| `configs/schemas/s2-m5-optimization-plan.schema.json` | IMPLEMENTED | S2-M5 plan-only contract |
| `configs/schemas/s2-m6-optimization-application.schema.json` | IMPLEMENTED | S2-M6 approved-apply contract; `backup.status` is `not-implemented` |
| `configs/schemas/s2-m1-firmware-validation.schema.json` | IMPLEMENTED | S2-M1 firmware validation contract; facts vs policy |
| `configs/schemas/s2-m2-kernel-driver-validation.schema.json` | IMPLEMENTED | S2-M2 kernel/driver validation contract |
| `configs/profiles/gpu-pci-architectures.json` | IMPLEMENTED | Declarative PCI vendor:device to gfx mapping |
| `configs/profiles/ai370.env` | IMPLEMENTED | Reference-platform profile |
| `configs/profiles/generic-ryzen-ai.env` | IMPLEMENTED | Broader Ryzen AI profile |
| `tests/test_s1_m1_probe.py` | IMPLEMENTED | Fixture replay coverage |
| `tests/test_s1_m2_normalize.py` | IMPLEMENTED | PCI architecture and live artifact-name coverage |
| `tests/test_s1_m3_classify.py` | IMPLEMENTED | Table-driven family and unknown-platform coverage |
| `tests/test_s1_m4_capabilities.py` | IMPLEMENTED | Candidates are not validation claims |
| `tests/test_s1_m5_publish.py` | IMPLEMENTED | Schema pass/fail and interrupted-write coverage |
| `tests/test_capability_ladder.py` | IMPLEMENTED | Ladder transitions from probe fixtures; no validation claims |
| `tests/test_s2_visibility_schemas.py` | IMPLEMENTED | S2-M3/S2-M4 report builders validate against schemas |
| `tests/test_s2_m3_gpu_visibility.py` | IMPLEMENTED | GPU publisher CLI, schema, atomic write, and missing-device fixture |
| `tests/test_s2_m4_npu_visibility.py` | IMPLEMENTED | NPU publisher CLI, schema, atomic write; visibility does not claim inference |
| `tests/test_s2_m7_platform_validation.py` | IMPLEMENTED | S2-M7 aggregate from fixture milestone JSONs; required profile, stale fingerprint, and firmware-validation status coverage |
| `tests/test_s2_m7_gate.py` | IMPLEMENTED | `require_tier123_pass` prefers `s2-m7-platform-validation.json` and falls back to `tier1-validation.json` |
| `tests/test_s2_m1_firmware.py` | IMPLEMENTED | Firmware policy from classified `platform_id`, facts vs policy, and canonical publisher |
| `tests/test_s2_m2_kernel_driver.py` | IMPLEMENTED | Canonical S2-M2 JSON plus compatibility `tier1-kernel-plan.json` |
| `tests/test_s2_optimize_profile.py` | IMPLEMENTED | Optimize plan wrapper records classified identity and consumed fingerprint |
| `tests/test_s2_m5_optimization_plan.py` | IMPLEMENTED | Plan-only publisher; no mutation; `AI370_APPLY_TUNING` is not sufficient |
| `tests/test_s2_m6_optimization_apply.py` | IMPLEMENTED | Apply requires `--approve`; dry-run does not execute commands |
| `tests/test_system_profile.py` | IMPLEMENTED | Classification, fingerprint, schema tests |
| `tests/fixtures/raw-probes/v1/*` | IMPLEMENTED | AI370, Ryzen AI Pro 360, missing-tool, unsupported, unreadable, non-XDNA |

### Platform validation and optimization

| Path | Status | Notes |
| --- | --- | --- |
| `scripts/lib/firmware_policy.py` | PARTIAL | BIOS facts vs classified-platform policy; publishes canonical S2-M1 JSON |
| `scripts/s2-m1-publish-firmware-validation.py` | PARTIAL | Canonical S2-M1 publisher; remaining S2-M1 work is remediation docs |
| `scripts/20-check-bios.sh` | PARTIAL | BIOS/firmware collector; writes `s2-m1-firmware-validation.json` and compat `tier1-firmware.json` |
| `scripts/25-check-firmware.sh` | DEPRECATED | Wrapper around `20-check-bios.sh` |
| `scripts/30-validate-kernel.sh` | PARTIAL | Kernel/module/firmware collector; writes `s2-m2-kernel-driver-validation.json` and compat `tier1-kernel-plan.json` |
| `scripts/s2-m2-publish-kernel-driver-validation.py` | PARTIAL | Canonical S2-M2 publisher; remaining S2-M2 work is the supported/unsupported matrix |
| `scripts/lib/kernel_validation.py` | PARTIAL | S2-M2 kernel/driver report builder |
| `scripts/70-validate-gpu-stack.sh` | DEPRECATED | Compatibility wrapper that execs `s2-m3-validate-gpu-stack.sh` |
| `scripts/40-platform-tuning.sh` | PARTIAL | Combined CPU/memory/storage plan/apply; consumes S1-M5 identity + fingerprint; writes canonical S2-M5/S2-M6 JSON; apply requires `--approve`; backup/rollback remain Planned |
| `scripts/40-optimize-cpu.sh`, `50-optimize-memory.sh`, `60-optimize-storage.sh` | DEPRECATED | Wrappers around platform tuning |
| `scripts/65-amd-acceleration-install.sh` | PARTIAL | Explicit-risk ROCm/XRT install; target S2-M6 |
| `scripts/90-validate.sh` | PARTIAL | Compatibility shim writing `tier1-validation.json`; canonical S2-M7 is `s2-m7-platform-validation.json` |
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
| `scripts/205-install-xrt-ryzen-ai.sh` | PARTIAL | XRT/Ryzen AI inventory or risk-accepted install; inventory-only mode feeds S2-M4 |
| `scripts/210-check-ryzen-ai-software.sh` | PARTIAL | Visibility vs `xrt-smi validate` split; 5th arg `true` skips validate |
| `scripts/220-check-vitis-ai-ep.sh` | PARTIAL | Vitis AI EP visibility; consumed by S2-M4 |
| `scripts/230-benchmark-npu.sh` | PARTIAL | NPU MatMul/diagnostic; must not remain a visibility-only PASS |
| `scripts/240-write-tier3-validation.sh` | DEPRECATED | Compatibility aggregate |
| `scripts/245-compare-cpu-gpu-npu.sh` | PARTIAL | Heterogeneous comparison; gfx1150 guidance strings |
| `scripts/250-install-digest-ai.sh`, `255-analyze-model-digest.sh` | PARTIAL | Optional diagnostics; not NPU execution proof |
| `scripts/lib/npu_ep_verify.py`, `scripts/lib/npu-venv.sh` | PARTIAL | Provider/execution helpers; split visibility vs execution |
| `.ai370-ai/ryzen-ai/source/install_ryzen_ai.sh` | PARTIAL | Tracked AMD Ryzen AI 1.7.x installer consumed by `scripts/205-install-xrt-ryzen-ai.sh`; requires exact `python3.12`; pins `ryzen-ai>=1.7.0.dev0,<1.8.0.dev0` and `device-essentials-strx`/`device-essentials-phx` ranges; installs into the caller `-p` venv (205 uses `.ai370-ai/ryzen-ai/venv`); wheels must be in the process CWD |
| `configs/ai-runtime/requirements-offline.txt` | IMPLEMENTED | Pinned offline CPU Python stack (`onnxruntime==1.22.0`, `transformers==5.5.0`, `huggingface-hub==1.29.0`, and related wheels); consumed via `configs/offline/ai-runtime.env` and `scripts/lib/offline-paths.sh`; distinct from Ryzen AI `onnxruntime-vitisai` |
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
| `tests/smoke_tier1.sh` | PARTIAL | Portable CLI smoke; asserts read-only `stage1` plus `tier1-*` artifacts from Stage 2 inventory |
| `tests/smoke_stage2_platform.sh` | PARTIAL | Fixture-based firmware/kernel/optimize-wrapper smoke; no live `stage1` / `stage2-platform-validate` |
| `tests/smoke_tier2.sh` | PARTIAL | Portable runtime/layout smoke |
| `tests/test_repository_instructions.py` | IMPLEMENTED | Instruction-file contract |
| `tests/test_agent_role_contract.py` | IMPLEMENTED | Machine-readable multi-agent architecture contract |
| `tests/test_agent_work_allocation.py` | IMPLEMENTED | Duplicate-agent work-allocation contract |
| `tests/test_agent_credential_capabilities.py` | IMPLEMENTED | Client credential capability contract |
| `tests/test_agent_mcp_contract.py` | IMPLEMENTED | GitHub MCP configuration drift contract |
| `tests/test_pr_governance_contract.py` | IMPLEMENTED | PR governance and advisory AI review contract |
| `tests/test_agent_cross_contract_consistency.py` | IMPLEMENTED | Cross-contract consistency among existing agent contracts |
| `tests/test_agent_contract_compatibility.py` | IMPLEMENTED | Architecture contract-version and repository-release compatibility |
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
| `scripts/s2-m3-validate-gpu-stack.sh` observed `gpu_arch` | Uses `detect_gpu_arch()` PCI lookup | CAPABILITY_DETECTION_RULE | KEEP |
| `scripts/s2-m3-validate-gpu-stack.sh` JSON `target_gpu_arch` | Reads from consumed S1-M5 profile (`#176`) | CAPABILITY_DETECTION_RULE | KEEP |
| `scripts/legacy/70-validate-gpu-stack.sh` JSON `target_gpu_arch` | Frozen hardcoded `"gfx1150"` | UNNECESSARY_HARDCODE | KEEP frozen; REMOVE at R1 |
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
| `README.md` Stage 1/2 status summary | User-facing snapshot of ROADMAP milestone rows | TEMPORARY_COMPATIBILITY_RULE | KEEP; update in the same commit as ROADMAP status changes |
| `TASK_PROPOSALS.md` | Stage/Milestone compatibility backlog | DEPRECATED | KEEP as backlog; do not extend with new Tier tasks |

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
| `scripts/lib/capability_ladder.py` | GPU/NPU ladder states and visibility report builders | S1-M5 profile; Stage 2 visibility checks | Candidates are not validation | S2-M3 / S2-M4 library | KEEP; GPU publisher landed in `#176` / `0.20.0`; NPU publisher landed in `#180` / `0.21.0` | `test_capability_ladder.py`, `test_s2_visibility_schemas.py`, `test_s2_m3_gpu_visibility.py`, `test_s2_m4_npu_visibility.py` | Medium |
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
| `configs/schemas/s2-m3-gpu-runtime-visibility.schema.json` | S2-M3 visibility JSON contract | Consumed S1-M5 profile | Visibility is not compute | S2-M3 | KEEP | `test_s2_visibility_schemas.py` | Low |
| `configs/schemas/s2-m4-npu-runtime-validation.schema.json` | S2-M4 visibility JSON contract | Consumed S1-M5 profile | Visibility is not inference | S2-M4 | KEEP; execution proof stays S3-M4 | `test_s2_visibility_schemas.py` | Low |
| `configs/schemas/s2-m1-firmware-validation.schema.json` | S2-M1 firmware validation contract | Consumed S1-M5 profile | Facts are not flash/update claims | S2-M1 | KEEP | `test_s2_m1_firmware.py` | Low |
| `configs/schemas/s2-m2-kernel-driver-validation.schema.json` | S2-M2 kernel/driver validation contract | Consumed S1-M5 profile | Observations are not package changes | S2-M2 | KEEP | `test_s2_m2_kernel_driver.py` | Low |
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
| `scripts/20-check-bios.sh` | BIOS/firmware collector; publishes canonical S2-M1 JSON | `s1-m5-system-profile.json`, classified `platform_id` `.env`, supplemental fwupd | BIOS 2.01 is classified-platform target, not CLI `--profile` or a generic gate | S2-M1 | KEEP facts vs policy split; remaining work is remediation docs | `test_s2_m1_firmware.py` | Medium |
| `scripts/lib/firmware_policy.py` | Classified-platform BIOS policy, facts object, and S2-M1 publisher helpers | S1-M5 profile, `configs/profiles/*.env` | Policy is not a flash/update claim | S2-M1 | KEEP | `test_s2_m1_firmware.py` | Low |
| `scripts/s2-m1-publish-firmware-validation.py` | Atomic S2-M1 publisher | Required S1-M5 profile | Never flashes firmware | S2-M1 | KEEP | `test_s2_m1_firmware.py` | Low |
| `scripts/25-check-firmware.sh` | Wrapper | `20-check-bios.sh` | None | Compatibility | DEPRECATE | Existing BIOS tests | Low |
| `scripts/30-validate-kernel.sh` | Kernel, modules, firmware dirs; publishes canonical S2-M2 JSON | `amdgpu` module, linux-firmware, S1-M5 profile | Radeon 890M advice strings | S2-M2 | KEEP collector; remaining work is the supported/unsupported matrix | `test_s2_m2_kernel_driver.py` | Medium |
| `scripts/s2-m2-publish-kernel-driver-validation.py` | Atomic S2-M2 publisher | Required S1-M5 profile | Validation-only | S2-M2 | KEEP | `test_s2_m2_kernel_driver.py` | Low |
| `scripts/lib/kernel_validation.py` | S2-M2 kernel/driver report builder | S1-M5 profile | Does not change kernel parameters | S2-M2 | KEEP | `test_s2_m2_kernel_driver.py` | Low |
| `scripts/70-validate-gpu-stack.sh` | Compatibility GPU visibility wrapper | `s2-m3-validate-gpu-stack.sh` | None beyond canonical owner | Compatibility until R1 | DEPRECATE; KEEP wrapper | Smoke still invokes this path from `stage2-platform-inventory` | Low |
| `scripts/s2-m3-validate-gpu-stack.sh` | GPU stack visibility collector | lspci, vulkaninfo, clinfo, rocminfo, S1-M5 profile | Target arch from consumed profile | S2-M3 | KEEP; remaining exit evidence is missing driver/Vulkan/ROCm layer fixtures | `test_s2_m3_gpu_visibility.py` | Medium |
| `scripts/s2-m3-publish-gpu-visibility.py` | Atomic S2-M3 visibility publisher | capability_ladder, S2-M3 schema | Visibility is not compute | S2-M3 | KEEP | `test_s2_m3_gpu_visibility.py` | Low |
| `scripts/s2-m4-validate-npu-stack.sh` | NPU stack visibility collector | 205 inventory-only, 210 visibility-only, 220, S1-M5 profile | Visibility is not inference | S2-M4 | KEEP | `test_s2_m4_npu_visibility.py` | Medium |
| `scripts/s2-m4-publish-npu-visibility.py` | Atomic S2-M4 visibility publisher | capability_ladder, S2-M4 schema | Visibility is not inference | S2-M4 | KEEP | `test_s2_m4_npu_visibility.py` | Low |
| `scripts/s2-m7-publish-platform-validation.py` | Atomic S2-M7 platform aggregate | Required S1-M5 profile, fingerprint-matched S2-M3/S2-M4 reports, compat `tier1-*` | gfx1150/NPU `--strict` is reference-platform policy | S2-M7 | KEEP | `test_s2_m7_platform_validation.py` | Medium |
| `scripts/lib/optimization_plan.py` | S2-M5 plan and S2-M6 apply builders | S1-M5 profile | Plan does not mutate; apply records `--approve` | S2-M5/S2-M6 | KEEP | `test_s2_m5_optimization_plan.py`, `test_s2_m6_optimization_apply.py` | Low |
| `scripts/s2-m5-publish-optimization-plan.py` | Atomic S2-M5 plan publisher | Required S1-M5 profile | Plan-only | S2-M5 | KEEP | `test_s2_m5_optimization_plan.py` | Low |
| `scripts/s2-m6-publish-optimization-application.py` | Atomic S2-M6 apply publisher | Required S1-M5 profile, optional S2-M5 plan | `--approve` required by caller | S2-M6 | KEEP; backup/rollback still Planned | `test_s2_m6_optimization_apply.py` | Medium |
| `scripts/40-platform-tuning.sh` | CPU/memory/storage plan and optional apply | governors, zram, NVMe | Invoked from `stage2-optimize-plan` / `stage2-optimize-apply --approve` | S2-M5/S2-M6 | KEEP plan vs `--approve` apply; canonical JSON In progress; backup/rollback Planned | No-mutation and `--approve` tests | High |
| `scripts/40-optimize-cpu.sh`, `50-optimize-memory.sh`, `60-optimize-storage.sh` | Wrappers | Platform tuning | None | Compatibility | DEPRECATE | Wrapper smoke | Low |
| `scripts/65-amd-acceleration-install.sh` | Risk-accepted stack install | `amd-acceleration.env` | Ubuntu package names | S2-M6 | KEEP explicit approval; no Stage 1 caller | Approval/backup tests | High |
| `scripts/90-validate.sh` | Platform aggregate compatibility shim | Prior `tier1-*` artifacts and S2-M3/S2-M4 reports | gfx1150/NPU acceptance from consumed facts | S1-M5 facts plus S2-M7 policy | SPLIT | Gate schema tests | High |
| `scripts/80-benchmark-local-ai.sh` | Optional AI visibility smoke | Local venv | No longer called from Stage 1 | S3-M6 | MOVE | Benchmark methodology tests | Medium |
| `scripts/100-install-pytorch-rocm.sh` | PyTorch ROCm runtime | venv, wheel indexes | ROCm indexes | S3-M3 | REFACTOR; prove GPU vs CPU selection | CPU/GPU fallback tests | High |
| `scripts/110-install-llama-cpp.sh` | llama.cpp build/install | HIP/Vulkan/CPU; `.ai370-ai/tools/llama.cpp` gitlink | Default `gfx1150` target; checkout path `.ai370-ai/tools/llama.cpp` | S3-M2 | REFACTOR backend from profile | Backend-selection fixtures | Medium |
| `.ai370-ai/tools/llama.cpp` | Tracked llama.cpp source gitlink | `scripts/110-install-llama-cpp.sh` | Mode `160000` commit `86b94708f22478f900b76ca02e316f4f3418faff`; no `.gitmodules` | S3-M2 | KEEP gitlink as optional source tree | Offline existing-binary tests | Medium |
| `scripts/120-install-ollama.sh` | Ollama install/validate | Network or preinstalled binary | None hardware-specific | S3-M2 | KEEP then rename after canonical validation | Offline missing-binary tests | Low |
| `scripts/200-install-onnxruntime.sh` | ONNX Runtime | venv/wheelhouse | None | S3-M4 | KEEP then canonicalize | Provider tests | Medium |
| `scripts/205-install-xrt-ryzen-ai.sh` | XRT/Ryzen AI inventory or install | Staged debs; tracked `install_ryzen_ai.sh` | Distro packages; python3.12 | S2-M4 visibility / S3-M4 install | SPLIT | Inventory-only vs approved install | High |
| `.ai370-ai/ryzen-ai/source/install_ryzen_ai.sh` | Vendor Ryzen AI 1.7.x installer | python3.12, local `.whl`, voe tarballs | Exact Python 3.12; `ryzen-ai` 1.7.x; strx/phx device-essentials; 8 CPU / 36 GB / 50 GB warnings; CWD wheels | S3-M4 backend installer consumed by `scripts/205` | KEEP as vendor input; not the NPU architecture | Missing python3.12 and missing-wheel tests | High |
| `scripts/210-check-ryzen-ai-software.sh` | Ryzen AI software checks | NPU venv | Presence vs execution mixed | S2-M4 / S3-M4 | SPLIT; 5th arg skips `xrt-smi validate` | Visibility vs inference tests | High |
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
| `tests/smoke_tier1.sh`, `tests/smoke_stage2_platform.sh`, `tests/smoke_tier2.sh` | Portable CLI smokes | Orchestrator | `tier*` artifacts | Owner-specific `test_sN_mN_*` | REPLACE at R1/R2 | Deterministic fixtures | Medium |
| `tests/test_s1_m1_probe.py`, `tests/test_system_profile.py` | Profile/probe contracts | Fixtures | AI370 reference plus non-AI370 | S1-M1/S1-M2/S1-M5 | KEEP and split by milestone | Existing plus unknown-host | Low |
| `tests/test_capability_ladder.py`, `tests/test_s2_visibility_schemas.py`, `tests/test_s2_m3_gpu_visibility.py`, `tests/test_s2_m4_npu_visibility.py`, `tests/test_s2_m7_platform_validation.py`, `tests/test_s2_m7_gate.py`, `tests/test_s2_m1_firmware.py`, `tests/test_s2_m2_kernel_driver.py`, `tests/test_s2_m5_optimization_plan.py`, `tests/test_s2_m6_optimization_apply.py` | Ladder, unpublished report builders, GPU/NPU publisher CLI, S2-M7 aggregate, firmware/kernel publishers, S2-M5/S2-M6 plan/apply, and S2-M7 gate preference | Probe/profile fixtures | No validation claims | S2-M1 / S2-M2 / S2-M3 / S2-M4 / S2-M5 / S2-M6 / S2-M7 | KEEP | Existing plus missing-device and classified-platform fixtures | Low |
| `tests/fixtures/**` | Sanitized hardware evidence | None | Reference and counterexamples | Detection/classification | KEEP; add newer Ryzen AI as data | Classification matrix | Low |
| `scripts/legacy/*` | Frozen archive | Historical | Tier/phase names | Compatibility archive | KEEP frozen; REMOVE at R1/R2 | No new tests | Low |
| `docs/ROADMAP.md` | Implementation authority | All deliverables | Five stages | Current authority | KEEP; update when boundaries change | Instruction tests | High |
| `docs/HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md` | Target architecture | None | Future 0–11 layers | Target architecture | KEEP | Instruction tests | Low |
| `docs/npu-status.md` | NPU operator notes | Stage 2 NPU scripts | AI370/XDNA | S2-M4/S3-M4 docs | REFACTOR owners as scripts split | Docs-only | Low |
| `docs/automatic1111-review.md`, `docs/forge-review.md`, `docs/openclaw-multi-llm-agent.md` | Application audits | None | Planned/non-goals | Stage 4/5 research | KEEP as non-implementation | None | Low |
| `README.md` | User commands | Orchestrator | Status must match ROADMAP | User guide | KEEP; same-commit status sync | Help smoke; instruction tests | Medium |
| `TASK_PROPOSALS.md` | Stale Tier follow-ups | None | Tier architecture | None | DEPRECATE | None | Low |
| VS Code / Continue / Aider / FastFlowLM / desktop module | Target applications | Runtime layer | None implemented | S5-M1/S5-M2, S3 runtime, desktop layer | Do not add until abstractions exist | Owner tests when added | High |

No production files are recommended for `REMOVE` in the first implementation
PRs except frozen `scripts/legacy/*` at the documented R1/R2 targets.

------------------------------------------------------------------------

## Subsequent PR sequence

The first migration PR from architecture Task 24 landed as
[`docs(architecture): Add Ryzen AI Linux platform migration plan`](https://github.com/gibboda/ai370-ubuntu-optimizer/pull/165).
Later PRs must stay small, keep detection read-only, and add or preserve
regression tests before replacing working code.

Tracked GitHub issues: #168 remaining work is none after `#180` / `0.21.0`;
#169 PR 3 (read-only Stage 1 + Stage 2 platform validation) is done through
Workstream F. Remaining S2-M1/S2-M2 remediations and S2-M5/S2-M6
backup/rollback stay on ROADMAP, not as a new mutation-boundary issue.
Do not file issues 4–11 until the prior boundary has tests.

| Sequence | Status | Tracked issue |
| --- | --- | --- |
| 1 Detection facts | **done** (`#166`, `0.17.0`) | None remaining |
| 2 Capability assessment | **done** (library `#170`, schemas `#173`, GPU publisher `#176` / `0.20.0`, NPU publisher `#180` / `0.21.0`) | None remaining; [#168](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/168) is complete |
| 3 Stop Stage 1 mutation | **done**; `stage1` is read-only; `stage2-platform-validate` invokes existing GPU/NPU commands and the S2-M7 publisher; `require_tier123_pass` prefers `s2-m7-platform-validation.json`; remaining S2-M1/S2-M2 remediations and S2-M5/S2-M6 backup/rollback are ROADMAP follow-ups | [#169](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/169) |
| 3-docs Documentation sync | **done** (this change) | Not a sequence 4–11 issue |
| 4–11 later boundaries | **planned** | Not filed |

Recommended order, using ROADMAP owners rather than new public stage numbers:

1. **Detection facts, not marketing names** — **done.** Canonical S1-M2 through
   S1-M5 exist; GPU architecture comes from PCI mappings, not `890M`/`Strix`.
2. **Capability assessment** — **done for publishers.** S1-M4 candidates exist.
   `capability_ladder.py`, S2-M3/S2-M4 schemas, the S2-M3 GPU publisher
   (`s2-m3-validate-gpu-stack.sh`, `stage2-gpu-validate`, `#176` / `0.20.0`),
   and the S2-M4 NPU visibility-only publisher (`s2-m4-validate-npu-stack.sh`,
   visibility-only `stage2-npu-validate`, `#180` / `0.21.0`) exist; ROADMAP
   marks S2-M3/S2-M4 In progress until remaining exit evidence exists. The
   `90-validate.sh` split is S2-M7 / #169 PR 3b.
3. **Stop Stage 1 mutation and mixed validation** — **done** (issue #169).
   `stage1` is read-only profile publication. `stage2-platform-validate`
   invokes existing `stage2-gpu-validate` and visibility-only
   `stage2-npu-validate`, plus firmware/kernel wrappers and the S2-M7
   publisher. `stage2-validate` remains the runtime/NPU cheap gate.
   `90-validate.sh` is a compatibility shim. `require_tier123_pass` prefers
   `s2-m7-platform-validation.json` and falls back to `tier1-validation.json`.
   Orchestrator callers use `stage1-probe` + `stage1-profile` instead of
   `10-detect-hardware.sh`.
3-docs. **Documentation sync** — **done in this change.** Encode the per-PR
    README/ROADMAP sync contract. Later boundary PRs carry the contract;
    they do not wait on a second docs issue. Do not file this as GitHub
    issues 4–11.
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

- `python3 -m unittest tests.test_system_profile tests.test_s1_m1_probe tests.test_s1_m2_normalize tests.test_s1_m3_classify tests.test_s1_m4_capabilities tests.test_s1_m5_publish tests.test_capability_ladder tests.test_s2_visibility_schemas tests.test_s2_m3_gpu_visibility tests.test_s2_m4_npu_visibility tests.test_s2_m7_platform_validation tests.test_s2_m7_gate tests.test_s2_m1_firmware tests.test_s2_m2_kernel_driver tests.test_s2_optimize_profile tests.test_s2_m5_optimization_plan tests.test_s2_m6_optimization_apply tests.test_repository_instructions tests.test_external_agent tests.test_github_label_policy tests.test_agent_role_contract tests.test_agent_work_allocation tests.test_agent_credential_capabilities tests.test_agent_mcp_contract tests.test_pr_governance_contract tests.test_agent_cross_contract_consistency tests.test_agent_contract_compatibility tests.test_agent_distribution_contract`
- `python3 -m unittest tests.test_agent_architecture_conformance`
- `python3 -m unittest tests.test_agent_architecture_coverage`
- `bash tests/smoke_tier1.sh`
- `bash tests/smoke_stage2_platform.sh`
- `bash tests/smoke_tier2.sh`
- `shellcheck --severity=error $(git ls-files '*.sh')`

Do not hide unexpected failures with unconditional `|| true`.

------------------------------------------------------------------------

## Documentation sync

README and ROADMAP stay **current-behavior** documents. They are not rewritten
to look like the architecture document's destination layers 0–11.

| Document | Sync rule |
| --- | --- |
| [`HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md`](HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md) | Destination architecture. Do not copy layer 0–11 language into README command lists until a ROADMAP stage-boundary PR exists. |
| [`ROADMAP.md`](ROADMAP.md) | Implementation authority. Update the deliverable registry and milestone status in the **same commit** as the code, tests, or command that changes them. |
| [`README.md`](../README.md) | User-facing commands and a high-level status snapshot. Follow ROADMAP milestone rows, not destination architecture language. |
| This plan | Inventory and PR sequence. Update status rows when a boundary lands. |

Per-PR contract for sequence 4–10 and remaining Stage 2 follow-ups:

1. Same commit as the code: ROADMAP registry/status, README usage/status, and
   orchestrator `usage()` when a public command changes.
2. README follows ROADMAP. ROADMAP follows exit evidence. Architecture stays
   destination.
3. Status vocabulary stays split. This plan uses `IMPLEMENTED` / `PARTIAL` /
   `PLANNED`. ROADMAP and README use `Implemented` / `In progress` / `Planned`.
4. A dedicated ROADMAP stage-boundary PR is the only change that may add
   public `stage6`–`stage11` commands, add a desktop ROADMAP owner, or change
   the five-stage model. That PR must update ROADMAP, README, and help together.
5. R1/R2 bind compatibility removal to versions in ROADMAP and README together.
6. Sequence 11 rename prep updates identity wording without treating architecture
   layers as current commands.

This contract is **not** migration sequence 4–11. Do not file GitHub issues
4–11 for documentation sync. Instruction tests in
`tests/test_repository_instructions.py` enforce the contract.

The high-level README Stage 1 and Stage 2 summaries match ROADMAP: S1-M1
through S1-M5 are Implemented as `stage1-probe` / `stage1-profile`, and
`stage1` is read-only profile publication. S2-M7 is **Implemented**. S2-M1
through S2-M6 are **In progress**. S3 through S5 remain Planned until
outputs, tests, and docs exist.

Current command facts that later PRs must keep accurate:

- Canonical S2-M7 (`s2-m7-platform-validation.json`) is **Implemented**. The
  publisher and schema exist; `90-validate.sh` is a compatibility shim.
  `require_tier123_pass` prefers the canonical report and falls back to
  `tier1-validation.json`.
- `stage2-gpu-validate` exists and writes `s2-m3-gpu-runtime-visibility.json`
  (`#176` / `0.20.0`). Do not treat the GPU command as missing.
- `stage2-npu-validate` is visibility-only by default and writes
  `s2-m4-npu-runtime-validation.json` (`#180` / `0.21.0`). Script 240 always
  refreshes `tier3-validation.json` on this command. Pass `--bench` for the
  mixed 210/220/230/245 compatibility path until S3-M6. Do not treat the
  command name as missing.
- Canonical S2-M3/S2-M4/S2-M5/S2-M6 remain **In progress**, not Implemented.
  S2-M3 still lacks separate missing-driver/Vulkan/ROCm layer fixtures. S2-M4
  still shares a mixed `stage2-npu` bench path. S2-M5/S2-M6 have canonical
  plan/apply JSON; backup/rollback remain Planned. S2-M1 and S2-M2 are **In
  progress** (canonical JSON exists; remaining work is remediation docs and
  the kernel/driver matrix).

Remaining work is future same-commit updates as sequence 4–10 and those
Stage 2 follow-ups land. Do not pre-write README or ROADMAP as if
architecture layers 0–11 were public commands.

The architecture document is target design. Features listed there as local
coding AI, FastFlowLM, unified master validation, heterogeneous live
benchmarks, and macOS-like desktop remain `PLANNED` unless a ROADMAP
milestone later records them as Implemented.

------------------------------------------------------------------------

## Out of scope for later implementation PRs

This plan does not authorize later PRs to:

- rewrite production scripts in bulk
- rename the GitHub repository
- add public `stage6`–`stage11` commands
- add a desktop module
- add FastFlowLM, VS Code coding-agent, GAIA, or LM Studio implementations
- change system-profile schema version
- mark any ROADMAP milestone Implemented without canonical outputs, tests, and
  docs

Issue #168 publishers (S2-M3 GPU in `#176` / `0.20.0` and S2-M4 NPU
visibility in `#180` / `0.21.0`) have landed; remaining #168 work is none.
Issue #169 PR 3 rewires `stage1` to the read-only profile pipeline, invokes
the existing `stage2-gpu-validate` and visibility-only `stage2-npu-validate`
commands from `stage2-platform-validate`, publishes S2-M7, and prefers that
report in `require_tier123_pass`. Remaining ROADMAP work is S2-M1 remediation
docs, the S2-M2 kernel/driver matrix, and S2-M5/S2-M6 backup/rollback. Do
not mark those rows Implemented until the exit evidence exists.
