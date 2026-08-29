# AI370 Ubuntu Optimizer Roadmap

## Document authority

This document defines the architecture and naming system that all future
renames and implementations must follow. It intentionally describes the target
before code, commands, reports, schemas, or tests are renamed.

**Last reviewed:** 2026-08-23

The project will retain five stages, but their boundaries are replaced by the
canonical boundaries below. Existing behavior outside its target boundary is
not precedent: it is migration debt. In particular, **Stage 1 is exclusively
read-only and profile-oriented**. It must never install, tune, benchmark, or
apply a system change.

The target Ryzen AI Linux platform architecture is
[`HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md`](HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md).
The current-to-target inventory and file mapping is
[`RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md`](RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md).
This roadmap remains authoritative for Stage/Milestone ownership, canonical
deliverables, implementation status, and Tier compatibility removal. The
architecture document's Stages 0 through 11 are target platform layers, not
public command names. User-facing `README.md` status must match this
document's milestone rows in the same commit. The per-PR documentation
sync contract lives in
[`RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md`](RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md).

## Status vocabulary

The following labels are not interchangeable:

| Label | Meaning |
| --- | --- |
| **Current implementation** | Code or an artifact that exists now. Its present Tier or Stage label may not match its target owner. |
| **Target architecture** | The required five-stage boundary and canonical name defined here. It is authoritative for new work. |
| **Compatibility-only Tier interface** | A deprecated alias, filename, function, script, or test retained temporarily for callers. It may delegate to a canonical implementation but cannot own new behavior. |
| **Planned canonical replacement** | The future Stage/Milestone-owned interface or artifact. “Planned” does not imply implemented. |

A target milestone is **Implemented** only when all of the following exist:

1. every canonical output listed for it;
2. deterministic automated tests for successful and failing inputs; and
3. user and maintainer documentation for its command and output contracts.

An existing Tier output, a compatibility wrapper, an ad hoc smoke run, or a
similarly shaped legacy report does not satisfy that rule. Until all three
conditions are met, the target milestone remains **Planned** or **In progress**.

### Capability ladder semantics

Stage 2 visibility uses structured GPU/NPU **ladder progression** implemented in
`scripts/lib/capability_ladder.py`. These are not interchangeable with other
vocabularies:

| Vocabulary | Owner | Meaning |
| --- | --- | --- |
| **Capability candidate** | S1-M4 | A machine might support a domain; `validation_claim` is always false. |
| **Ladder step** | S2-M3 / S2-M4 visibility | Ordered readiness (`DETECTED` … `APPLICATION_READY`) with per-step status. |
| **Assessment** | S2 visibility reports | Aggregate view: `AVAILABLE`, `READY`, `DEGRADED`, `UNSUPPORTED`, `UNKNOWN`. |
| **Runtime validation** | S3-M3 / S3-M4 | Execution proof on the accelerator that actually ran the workload. |

A PCI device or package inventory satisfies at most early ladder steps. Later
steps remain `unknown` until the owning Stage 2 script performs the visibility
check. `APPLICATION_READY` is never inferred from package presence alone.

### Platform validation aggregate semantics

S2-M7 (`s2-m7-platform-validation.json`) is the Stage 2 platform gate
aggregate. It consumes the Stage 1 profile and milestone reports; it does not
re-probe PCI, sysfs, or modules.

| Input | Owner | How S2-M7 uses it |
| --- | --- | --- |
| Stage 1 profile | S1-M5 `s1-m5-system-profile.json` | Required. Missing or unreadable profile is an error (exit 2); leftover `tier1-*` reports are not published as an unbound PASS |
| GPU architecture, NPU identity | S1-M5 profile, overlaid by fingerprint-matched S2-M3 / S2-M4 reports | Facts for reference-platform acceptance |
| Vulkan / amdgpu visibility | Fingerprint-matched S2-M3 | Vulkan warn; not a generic FAIL |
| BIOS acceptable | S2-M1 `s2-m1-firmware-validation.json` `policy.bios_acceptable`, with compat `tier1-firmware.json` fallback | Warn when `false` |
| S2-M1 status | S2-M1 canonical `s2-m1-firmware-validation.json`, with compat `tier1-firmware-validation.json` fallback | Child `FAIL` fails the aggregate |
| Milestone `consumed_profile.fingerprint` | S2-M3 / S2-M4 and other fingerprint-bearing reports | Mismatch is `MISSING`; do not overlay that report's checks or fall back to possibly-stale GPU/NPU compat facts |
| gfx1150 / XDNA2 missing | S2-M7 policy | Recorded in `warnings` without demoting `PASS` unless `--strict` |

Child visibility `UNSUPPORTED` or `WARN` does not fail S2-M7. Child `FAIL`
does. `--strict` / `AI370_STAGE1_STRICT` is the AI370 reference-platform
opt-in, not generic-host policy. `require_tier123_pass` prefers
`s2-m7-platform-validation.json` and falls back to compatibility
`tier1-validation.json` until R2.

## Canonical naming and ownership system

### Identifiers

* Stages use `S1` through `S5`.
* Milestones use `S<stage>-M<sequence>`, for example `S2-M3`.
* Commands use `stage<N>-<noun>[-<verb>]`; the bare `stage<N>` command may only
  orchestrate milestones owned by that stage.
* Executable scripts use a stage and milestone prefix:
  `s<N>-m<sequence>-<verb>-<noun>.sh` (or `.py`).
* Reports use `s<N>-m<sequence>-<noun>.json` with an optional paired `.md`
  rendering. JSON is the machine-readable authority.
* Schemas use `s<N>-m<sequence>-<noun>.schema.json`.
* Tests use `test_s<N>_m<sequence>_<behavior>.<ext>`.
* Internal functions use `s<N>_m<sequence>_<verb>_<noun>`.

Names containing `tier`, bare numeric script prefixes, or a Stage number that
does not match the owner are noncanonical. New references must use the planned
canonical name. Compatibility names must emit a deprecation notice where that
does not break a machine-readable stream.

### Ownership invariant

Every command, script, function, test, report, and schema has exactly one
owning Stage and Milestone. Ownership is determined by the operation performed,
not by its caller or historical filename. Orchestrators may invoke deliverables
across milestones only through their public command contracts; they do not
acquire ownership of those deliverables. A generated Markdown view has the same
owner as its JSON source.

Every change that adds or renames one of these objects must update the
deliverable registry in this document in the same commit. Transitional aliases
must also add a row to the migration table with a removal target.

### Canonical publication contract

Reports are written below `reports/latest/`. Producers must validate JSON
against the owning schema before publication and must publish with a temporary
file plus atomic rename. A failed probe or validation must leave the previous
complete publication intact and return an actionable failure. Stable ordering,
normalized units, explicit `null`/unavailable values, and removal of volatile
timestamps or paths from test fixtures are required for deterministic tests.

System-profile schema v3 replaces v2 for newly published profiles. It retains
the normalized v2 facts and redefines the hardware fingerprint as algorithm
version 1 over normalized CPU and DMI identity, sorted PCI and accelerator
identities, and storage model/serial identity when a serial is available.
Kernel and OS versions, timestamps, driver/runtime state, transient device
visibility, command formatting, and free-form tool output are excluded. The v2
schema remains available for migration validation, but Stage 2 and later must
consume v3 before relying on the stable fingerprint. Schema v2 replaced the
provisional v1 shape. It separates the
fingerprint algorithm and inputs from generation metadata; normalizes system,
OS, kernel, CPU, memory, storage, GPU, accelerator, and firmware observations;
and records tools, probes, classification, capability candidates, and unknown
facts with explicit states. Stage 2 and later consumers must reject v1 rather
than infer missing v2 facts. Versioned v2 fixtures and atomic-publication tests
are the migration evidence; the compatibility inventory remains an input to the
v2 normalizer while Stage 1 collectors are migrated.

## Target architecture and canonical deliverables

All milestones in this section are **Planned** unless a row explicitly says
otherwise. Current implementation evidence is recorded separately and does not
upgrade these statuses.

### Stage 1 — Hardware Discovery & System Profile

**Boundary:** read-only hardware and operating-system probing, fact
normalization, platform-family classification, capability-candidate derivation,
schema validation, and atomic publication of the system profile and inventory
summary.

Stage 1 may read firmware, kernel, driver, device, and runtime visibility facts
when those facts help describe the machine. It may not judge enablement policy,
install a dependency, change a setting, generate an apply script, run a
performance benchmark, or claim that a candidate capability is validated.

| ID | Canonical deliverable | Canonical outputs | Exit evidence | Status |
| --- | --- | --- | --- | --- |
| S1-M1 | Raw system probe | `stage1-probe`, `s1-m1-probe-system.sh`, `s1-m1-raw-inventory.json` | Fixture tests for present, absent, and unreadable devices; probe documentation | Implemented |
| S1-M2 | Fact normalization | `s1-m2-normalize-profile.py`, `s1-m2-normalized-facts.json` | Deterministic normalization tests and field documentation | Implemented |
| S1-M3 | Platform classification | `s1-m3-classify-platform.py`, `s1-m3-platform-classification.json` | Table-driven family and unknown-platform tests | Implemented |
| S1-M4 | Capability candidates | `s1-m4-derive-capabilities.py`, `s1-m4-capability-candidates.json` | Rules tests proving candidates are not validation claims | Implemented |
| S1-M5 | Profile validation and publication | `stage1-profile`, `s1-m5-publish-profile.py`, `s1-m5-system-profile.schema.json`, `s1-m5-system-profile.json`, `s1-m5-inventory-summary.md` | Schema pass/fail tests, interrupted-write test, command/output documentation | Implemented |

Canonical S1-M5 also writes a compatibility copy at `reports/latest/system-profile.json`. `stage1` / `tier1` now invoke only the read-only S1-M1 through S1-M5 profile pipeline. BIOS, kernel, GPU/NPU visibility, and tuning run from `stage2-platform-*` and `stage2-optimize-*` wrappers. S2-M1/S2-M2 are In progress: publishers write `s2-m1-firmware-validation.json` and `s2-m2-kernel-driver-validation.json`; remaining work is S2-M1 remediation docs and the S2-M2 supported versus unsupported kernel/driver matrix. S2-M5/S2-M6 are In progress: the plan/apply split writes `s2-m5-optimization-plan.json` and `s2-m6-optimization-application.json`; backup/rollback remain Planned. S2-M7 is Implemented: the publisher writes `s2-m7-platform-validation.json`, `require_tier123_pass` prefers that report, and `tier1-validation.json` remains the compatibility fallback.

### Stage 2 — Platform Enablement & Validation

**Boundary:** BIOS and firmware policy checks; kernel and driver validation;
GPU, Vulkan, ROCm, and NPU runtime visibility; and safe system-optimization
planning with separately and explicitly approved application.

Stage 2 consumes the immutable Stage 1 profile. Planning is the default. Apply
commands must show the plan, require an explicit approval flag, back up changed
configuration, and emit an audit report. Visibility is distinct from verified
execution.

| ID | Canonical deliverable | Canonical outputs | Exit evidence | Status |
| --- | --- | --- | --- | --- |
| S2-M1 | Firmware policy validation | `stage2-firmware-validate`, `s2-m1-publish-firmware-validation.py`, `s2-m1-firmware-validation.schema.json`, `s2-m1-firmware-validation.json` | Deterministic policy fixtures and remediation docs | In progress |
| S2-M2 | Kernel and driver validation | `stage2-kernel-validate`, `s2-m2-publish-kernel-driver-validation.py`, `s2-m2-kernel-driver-validation.schema.json`, `s2-m2-kernel-driver-validation.json` | Supported/unsupported matrix tests and docs | In progress |
| S2-M3 | GPU, Vulkan, and ROCm visibility | `stage2-gpu-validate`, `s2-m3-validate-gpu-stack.sh`, `s2-m3-gpu-runtime-visibility.json`, `s2-m3-gpu-runtime-visibility.schema.json` | Fixtures for missing device, driver, Vulkan, and ROCm layers | In progress |
| S2-M4 | NPU visibility and execution validation | `stage2-npu-validate`, `s2-m4-validate-npu-stack.sh`, `s2-m4-npu-runtime-validation.json`, `s2-m4-npu-runtime-validation.schema.json` | Tests distinguishing visibility, provider selection, and executed inference | In progress |
| S2-M5 | Safe optimization plan | `stage2-optimize-plan`, `s2-m5-publish-optimization-plan.py`, `s2-m5-optimization-plan.schema.json`, `s2-m5-optimization-plan.json`, `s2-m5-optimization-plan.md` | Idempotence and no-mutation tests plus plan docs | In progress |
| S2-M6 | Approved optimization application | `stage2-optimize-apply --approve`, `s2-m6-publish-optimization-application.py`, `s2-m6-optimization-application.schema.json`, `s2-m6-optimization-application.json` | Approval, backup, rollback, idempotence, and failure-path tests | In progress |
| S2-M7 | Platform validation aggregate | `stage2-platform-validate`, `s2-m7-publish-platform-validation.py`, `s2-m7-platform-validation.schema.json`, `s2-m7-platform-validation.json` | Schema and gate tests plus status-semantics docs | Implemented |

### Stage 3 — AI Runtime Foundation

**Boundary:** Ollama, llama.cpp, PyTorch/ROCm, ONNX Runtime, XRT/Ryzen AI,
Lemonade, model storage, and runtime benchmarks. Runtime installation and
provider-specific execution evidence belong here; hardware/runtime visibility
alone remains in Stage 2.

| ID | Canonical deliverable | Canonical outputs | Exit evidence | Status |
| --- | --- | --- | --- | --- |
| S3-M1 | Model storage foundation | `stage3-model-storage`, `s3-m1-manage-model-storage.sh`, `s3-m1-model-storage-validation.json` | Offline, checksum, layout, and idempotence tests plus policy docs | Planned |
| S3-M2 | Native LLM runtimes | `stage3-llm-runtime`, installers for Ollama and llama.cpp, `s3-m2-llm-runtime-validation.json` | Offline install and deterministic smoke fixtures plus docs | Planned |
| S3-M3 | PyTorch and ROCm runtime | `stage3-pytorch-runtime`, `s3-m3-install-pytorch-rocm.sh`, `s3-m3-pytorch-rocm-validation.json` | CPU/GPU selection and fallback detection tests | Planned |
| S3-M4 | ONNX, XRT, and Ryzen AI runtime | `stage3-npu-runtime`, canonical ONNX/XRT installers, `s3-m4-npu-runtime-validation.json` | Provider-execution tests and risk/compatibility docs | Planned |
| S3-M5 | Lemonade runtime | `stage3-lemonade-runtime`, canonical TurnkeyML/Lemonade installers, `s3-m5-lemonade-validation.json` | Server lifecycle and offline inference tests | Planned |
| S3-M6 | Runtime benchmarks | `stage3-runtime-benchmark`, `s3-m6-benchmark-runtimes.sh`, `s3-m6-runtime-benchmark.json`, `s3-m6-runtime-benchmark.md` | Fixed-workload tests, fallback detection, and methodology docs | Planned |
| S3-M7 | Runtime foundation aggregate | `stage3-validate`, `s3-m7-publish-runtime-validation.py`, `s3-m7-runtime-validation.schema.json`, `s3-m7-runtime-validation.json` | Deterministic gate tests and consumer documentation | Planned |

### Stage 4 — Offline AI Applications

**Boundary:** ComfyUI, RAG applications, GAIA, LM Studio, Open WebUI, and
application workflows. Applications consume Stage 3 runtimes and must not own
runtime installation.

| ID | Canonical deliverable | Canonical outputs | Exit evidence | Status |
| --- | --- | --- | --- | --- |
| S4-M1 | ComfyUI application | `stage4-comfyui`, canonical installer and lifecycle scripts, `s4-m1-comfyui-validation.json` | Offline install, lifecycle, workflow, and health tests plus docs | Planned |
| S4-M2 | ComfyUI models and workflows | `stage4-comfyui-workflows`, canonical model/workflow manager, `s4-m2-comfyui-workflows.json` | Manifest, checksum, launch, and output tests | Planned |
| S4-M3 | Offline RAG applications | `stage4-rag`, canonical AnythingLLM/RAG scripts, `s4-m3-rag-validation.json` | Ingest/retrieve offline tests and docs | Planned |
| S4-M4 | GAIA | `stage4-gaia`, canonical installer/lifecycle scripts, `s4-m4-gaia-validation.json` | Offline agent workflow tests and docs | Planned |
| S4-M5 | LM Studio | `stage4-lm-studio`, canonical installer/validator, `s4-m5-lm-studio-validation.json` | Installation and local-endpoint tests plus docs | Planned |
| S4-M6 | Open WebUI | `stage4-open-webui`, canonical installer/lifecycle scripts, `s4-m6-open-webui-validation.json` | Offline UI/backend and health tests plus docs | Planned |
| S4-M7 | Application workflows and aggregate | `stage4-validate`, workflow launcher, `s4-m7-application-validation.schema.json`, `s4-m7-application-validation.json` | Cross-application workflow and gate tests plus docs | Planned |

### Stage 5 — Offline Development & Lifecycle

**Boundary:** coding assistants, development tooling, maintenance, backup,
restore, health checks, and regression validation.

| ID | Canonical deliverable | Canonical outputs | Exit evidence | Status |
| --- | --- | --- | --- | --- |
| S5-M1 | Offline coding assistants | `stage5-code-assist`, canonical Continue/Aider configuration, `s5-m1-code-assistant-validation.json` | Offline completion/edit/review tests and docs | Planned |
| S5-M2 | Development toolchain | `stage5-dev-tools`, canonical VS Code/Git/linter setup, `s5-m2-development-tooling.json` | Tool availability and offline workflow tests | Planned |
| S5-M3 | Health and maintenance | `stage5-health`, `stage5-maintain`, canonical maintenance scripts, `s5-m3-health-report.json` | No-op/idempotence, degraded-state, and recovery tests | Planned |
| S5-M4 | Backup and restore | `stage5-backup`, `stage5-restore --approve`, canonical backup/restore scripts, `s5-m4-backup-manifest.json`, `s5-m4-restore-report.json` | Round-trip, checksum, approval, and failure tests | Planned |
| S5-M5 | Regression validation | `stage5-regression`, canonical regression runner, `s5-m5-regression-validation.json` | Hermetic fixtures and documented baselines | Planned |
| S5-M6 | Lifecycle aggregate and release | `stage5-validate`, canonical release validator, `s5-m6-lifecycle-validation.schema.json`, `s5-m6-lifecycle-validation.json` | Full offline lifecycle test and release docs | Planned |

## Current implementation registry

This registry assigns existing deliverables to their **target owner**, despite
their current filenames or orchestration. It is the ownership source for the
migration. Numeric ranges include only tracked scripts that currently exist.

| Target owner | Current implementation | Architectural disposition |
| --- | --- | --- |
| S1-M1 | `scripts/s1-m1-probe-system.sh`, `scripts/lib/hardware-detect.sh` collector, compatibility wrappers `scripts/10-detect-hardware.sh` and `scripts/75-detect-npu.sh` | Retain only read-only probing; split policy and validation out |
| S1-M2 | `scripts/s1-m2-normalize-profile.py`, `configs/schemas/s1-m2-normalized-facts.schema.json`, `configs/profiles/gpu-pci-architectures.json` | Normalize S1-M1 facts; GPU architecture from PCI map only |
| S1-M3 | `scripts/s1-m3-classify-platform.py`, `configs/schemas/s1-m3-platform-classification.schema.json`, `configs/profiles/ai370.env`, `configs/profiles/generic-ryzen-ai.env` | Table-driven family classification; unknown hosts remain valid |
| S1-M4 | `scripts/s1-m4-derive-capabilities.py`, `configs/schemas/s1-m4-capability-candidates.schema.json` | Candidates are not validation claims |
| S1-M5 | `scripts/s1-m5-publish-profile.py`, `configs/schemas/s1-m5-system-profile.schema.json`, `configs/schemas/system-profile.schema.json`, `stage1-profile` | Atomic v3 publication plus inventory summary; compatibility `system-profile.json` copy |
| S1-M2–S1-M5 library | `scripts/lib/system_profile.py` | Shared implementation library used by the canonical CLIs |
| S2-M1 | `scripts/20-check-bios.sh`, `scripts/s2-m1-publish-firmware-validation.py`, `scripts/lib/firmware_policy.py`, `configs/schemas/s2-m1-firmware-validation.schema.json`, `scripts/25-check-firmware.sh` | Canonical S2-M1 JSON and facts-vs-policy split landed; keep In progress until remediation docs exist |
| S2-M2 | `scripts/30-validate-kernel.sh`, `scripts/s2-m2-publish-kernel-driver-validation.py`, `scripts/lib/kernel_validation.py`, `configs/schemas/s2-m2-kernel-driver-validation.schema.json` | Canonical S2-M2 JSON landed; keep In progress until the supported/unsupported kernel/driver matrix exists |
| S2-M3 | `scripts/s2-m3-validate-gpu-stack.sh`, `scripts/s2-m3-publish-gpu-visibility.py`, compatibility wrapper `scripts/70-validate-gpu-stack.sh`, `scripts/lib/capability_ladder.py`, `configs/schemas/s2-m3-gpu-runtime-visibility.schema.json` | GPU publisher landed in `#176`; keep S2-M3 In progress until missing driver/Vulkan/ROCm fixtures exist |
| S2-M4 | `scripts/s2-m4-validate-npu-stack.sh`, `scripts/s2-m4-publish-npu-visibility.py`, visibility portions of `scripts/210-check-ryzen-ai-software.sh` and `scripts/220-check-vitis-ai-ep.sh`, inventory-only `scripts/205-install-xrt-ryzen-ai.sh`, `scripts/lib/capability_ladder.py`, `configs/schemas/s2-m4-npu-runtime-validation.schema.json` | Visibility-only publisher landed in `#180` / `0.21.0`; keep S2-M4 In progress because mixed `stage2-npu` / `--bench` still runs 230 and ROADMAP exit evidence still wants provider-vs-inference tests; move runtime install and performance measurement to Stage 3 |
| S2-M5–S2-M6 | `scripts/40-platform-tuning.sh`, `scripts/lib/optimization_plan.py`, `scripts/s2-m5-publish-optimization-plan.py`, `scripts/s2-m6-publish-optimization-application.py`, `configs/schemas/s2-m5-optimization-plan.schema.json`, `configs/schemas/s2-m6-optimization-application.schema.json`, wrappers `40-optimize-cpu.sh`, `50-optimize-memory.sh`, `60-optimize-storage.sh` | Plan/apply split landed; keep In progress until backup/rollback tests exist |
| S2-M6 | `scripts/65-amd-acceleration-install.sh` | Treat installation as an explicitly approved platform change; retain no Stage 1 caller |
| S2-M7 | `scripts/s2-m7-publish-platform-validation.py`, `configs/schemas/s2-m7-platform-validation.schema.json`, compatibility shim `scripts/90-validate.sh` | Publisher and `require_tier123_pass` prefer the canonical report; `tier1-validation.json` remains until R1 |
| S3-M1 | `scripts/150-validate-offline-model-storage.sh`, `scripts/155-stage-model-layout.sh`, `configs/models/*`, `scripts/lib/offline-paths.sh` | Canonicalize model storage under Stage 3 |
| S3-M2 | `scripts/110-install-llama-cpp.sh`, `scripts/120-install-ollama.sh` | Rename after canonical validation exists |
| S3-M3 | `scripts/100-install-pytorch-rocm.sh` | Rename after canonical validation exists |
| S3-M4 | Runtime/install portions of scripts `200`, `205`, `210`, `220`, and `230`; `scripts/lib/npu-venv.sh`, `scripts/lib/npu_ep_verify.py` | Separate from S2 visibility; execution proof belongs here |
| S3-M5 | `scripts/160-install-lemonade.sh`, `165-validate-lemonade.sh`, `170-install-turnkeyml.sh`, `scripts/lib/lemonade-env.sh` | Canonicalize under S3-M5 |
| S3-M4 | `scripts/250-install-digest-ai.sh`, `255-analyze-model-digest.sh`, `scripts/lib/digest_analyze.py` | Treat Digest as optional runtime/model diagnostics, not NPU execution proof |
| S3-M6 | `scripts/80-benchmark-local-ai.sh`, `140-benchmark-llm.sh`, `245-compare-cpu-gpu-npu.sh` | Remove all benchmarking from Stage 1/2 orchestration |
| S3-M7 | `scripts/145-write-tier2-validation.sh`, `240-write-tier3-validation.sh` | Replace both with one schema-backed Stage 3 aggregate |
| S4-M1–S4-M2 | `scripts/70-comfyui-workflows.sh`, `420-benchmark-comfyui.sh`, `workflows/comfyui/` | Canonicalize as application and workflow deliverables |
| S4-M3 | `scripts/300-install-anythingllm.sh`, `310-install-embedding-models.sh`, `320-validate-rag.sh` | Application belongs here; reusable model storage remains S3-M1 |
| S4-M6 | `scripts/130-install-open-webui.sh` | Move from runtime orchestration to application ownership |
| S5 milestones | No complete canonical implementation | Do not claim implemented from legacy plans |
| S5-M6 | `scripts/validate-commit-subject.sh`, `scripts/validate-pr-title.sh`, `scripts/github_label_policy.py`, `.github/label-policy.json`, `.github/grok/`, `.github/antigravity/` | Release-policy validation, GitHub label automation, and local Grok Build / Antigravity CLI independent-review docs |
| S1–S5 tests | `tests/test_s1_m1_probe.py`, `tests/test_s1_m2_normalize.py`, `tests/test_s1_m3_classify.py`, `tests/test_s1_m4_capabilities.py`, `tests/test_s1_m5_publish.py`, `tests/test_capability_ladder.py`, `tests/test_s2_visibility_schemas.py`, `tests/test_s2_m3_gpu_visibility.py`, `tests/test_s2_m4_npu_visibility.py`, `tests/test_s2_m7_platform_validation.py`, `tests/test_s2_m7_gate.py`, `tests/test_s2_m1_firmware.py`, `tests/test_s2_m2_kernel_driver.py`, `tests/test_s2_optimize_profile.py`, `tests/test_s2_m5_optimization_plan.py`, `tests/test_s2_m6_optimization_apply.py`, `tests/test_system_profile.py`, `tests/test_github_label_policy.py`, `tests/test_agent_role_contract.py`, `tests/test_agent_work_allocation.py`, `tests/smoke_tier1.sh`, `tests/smoke_stage2_platform.sh`, `tests/smoke_tier2.sh` | Owner-specific Stage 1 tests exist; S2-M3 library/GPU publisher, S2-M4 NPU publisher, S2-M1/S2-M2 firmware and kernel publishers, S2-M5/S2-M6 plan/apply publishers, S2-M7 aggregate publisher, and `require_tier123_pass` S2-M7 preference tests exist; `test_s2_m1_firmware.py` covers consumed-profile BIOS policy and facts vs policy; `test_s2_m2_kernel_driver.py` covers canonical S2-M2 JSON; `test_s2_optimize_profile.py` covers optimize-plan profile consumption; `smoke_stage2_platform.sh` is fixture-based platform-wrapper coverage; remaining smokes are compatibility coverage until replaced |
| Compatibility archive | `scripts/legacy/*` | No architectural ownership; frozen compatibility/archive only, then remove at the target below |
| Repository orchestrator | `ai370-optimize.sh` | Routes commands; each branch is owned by the milestone it invokes, not by the file as a whole |

Current command branches in `ai370-optimize.sh` have the following single
owners. A row may contain aliases only when every alias invokes the same owned
behavior.

| Owner | Current commands and aliases |
| --- | --- |
| S1-M1 | `stage1-probe`, probe portion of `hardware`, `inventory`, `audit` |
| S1-M5 | `stage1`, `stage1-profile`, `tier1` |
| S2-M1 | `stage2-firmware-validate`, `firmware` |
| S2-M2 | `stage2-kernel-validate`, `kernel-amd` |
| S2-M3 | `stage2-gpu-validate`, `gpu-validate`, `gpu` |
| S2-M4 | Visibility portion of `stage2-npu`, `stage2-npu-validate`, and `npu` |
| S2-M5 | `stage2-optimize-plan`, `tune` |
| S2-M6 | `stage2-optimize-apply`, `baseline-apply`, `execute`, `amd-accel-install` |
| S2-M7 | `stage2-platform-validate`, `stage2-platform-inventory`, `stage1-validate`, `tier1-validate`, `baseline-validate`, and `final-validate`/`validate` |
| S3-M1 | `stage2-models` |
| S3-M2–S3-M5 | `stage2`, `stage2-runtime`, `stage2-runtime-validate`, `stage2-lemonade`, `stage2-digest`, `ai-runtime`, `llm-validate`, `install`, `full-ai-install` |
| S3-M6 | `ai-bench` and runtime benchmark portions of current NPU commands |
| S3-M7 | Runtime/NPU cheap gate `stage2-validate` until the S3 aggregate exists |
| S4-M1–S4-M2 | `stage3-image`, `comfyui-install`, `comfyui`, `comfyui-bench` |
| S4-M3 | `stage2-rag` |
| S4-M7 | Cross-stage orchestration in `full-stack` and `all` |
| S5-M6 | `help`, `-h`, `--help` (documented command catalog) |

The `stage2`, `full-stack`, `final-validate`/`validate`, `all`,
and `accel-validate` branches currently combine multiple owners. They are
compatibility orchestrators, not standalone deliverables; each invoked
operation retains the owner shown above and must be split at the new
boundaries. `stage1` now orchestrates only S1-M1 through S1-M5.

Configuration ownership follows its consumer: `configs/profiles/gpu-pci-architectures.json`
is S1-M2; other `configs/profiles/*` files are S1-M3,
`configs/tuning/*` and `configs/amd-acceleration.env` are S2-M5/S2-M6,
`configs/ai-runtime/*`, `configs/offline/*`, and `configs/models/*` are Stage 3,
and `configs/persistence/*` is S5-M3. Shared shell utilities in
`scripts/lib/common.sh` are infrastructure; each exported function must be
documented with the milestone of its only behavioral consumer, or split when
consumers span milestones.

## Tier-to-Stage migration and removal plan

**Removal target definition:** `R1` is the first release after all canonical
Stage 1 and Stage 2 gates meet their exit evidence. `R2` is the next major
release after all canonical Stage 3 and Stage 4 consumer migrations are
complete. No date or version is invented here; release planning must bind these
targets to versions before removal. Compatibility items receive bug fixes only.

| Compatibility-only Tier interface | Kind | Target owner and planned canonical replacement | Removal target |
| --- | --- | --- | --- |
| `tier1`, `tier1-validate` | Commands | S1-M5 `stage1-profile` and S2-M7 `stage2-platform-validate` (the old combined behavior is split) | R1 |
| `stage1-inventory` | Command | S2-M7 `stage2-platform-inventory` | R1 |
| `stage1-validate` | Command | S2-M7 `stage2-platform-validate` | R1 |
| `tier2`, `tier2-validate` | Commands | S3-M7 `stage3-validate` | R2 |
| `tier3`, `tier3-validate` | Commands | S2-M4 `stage2-npu-validate` and S3-M4 `stage3-npu-runtime` | R2 |
| `tier4` | Command | S4-M3 `stage4-rag` | R2 |
| `tier5` | Command | S4-M1 `stage4-comfyui` / S4-M2 `stage4-comfyui-workflows` | R2 |
| `require_tier123_pass`, `tier1_status`, `tier2_status`, `tier3_status` | Function and variables | S4-M7 consumer gate reading canonical S2-M7 and S3-M7 reports | R2 |
| `scripts/145-write-tier2-validation.sh` | Script | S3-M7 `s3-m7-publish-runtime-validation.py` | R2 |
| `scripts/240-write-tier3-validation.sh` | Script | S3-M7 aggregate, with S2-M4 visibility supplied through its public report | R2 |
| `scripts/legacy/100-tier2-ai-runtime.sh`, `scripts/legacy/110-tier3-npu-enable.sh`, `scripts/legacy/tier-gate.sh` | Scripts | S3-M2/S3-M4 commands and the S4-M7 consumer gate | R2 |
| `tests/smoke_tier1.sh` | Test | Deterministic `test_s1_*` and `test_s2_*` suites split at the read-only boundary | R1 |
| `tests/smoke_tier2.sh` | Test | Deterministic `test_s3_*` runtime suites | R2 |
| `tier1-hardware.json`, `tier1-hardware.md`, `tier1-npu.json` | Reports | S1-M1 raw inventory and S1-M5 canonical profile/summary | R1 |
| `tier1-firmware.json`, `tier1-firmware.md`, `tier1-firmware-validation.json`, `tier1-firmware-validation.md` | Reports | S2-M1 firmware validation | R1 |
| `tier1-kernel-plan.json`, `tier1-kernel-baseline.md`, `tier1-gpu-stack.json` | Reports | S2-M2 kernel/driver and S2-M3 GPU visibility reports | R1 |
| `tier1-platform-tuning.json`, `tier1-cpu-plan.md`, `tier1-cpu-runtime-commands.sh`, `tier1-memory.md`, `tier1-storage.md` | Reports/apply artifact | S2-M5 optimization plan and S2-M6 approved application; generated apply shell artifact is eliminated | R1 |
| `tier1-local-ai-benchmark.json`, `tier1-local-ai-benchmark.md` | Reports | S3-M6 runtime benchmark | R2 |
| `tier1-validation.json`, `tier1-validation.txt`, `tier1-summary.md` | Reports | S1-M5 profile publication plus S2-M7 platform validation, split by responsibility | R1 |
| `tier2-ollama.json`, `tier2-ollama.md`, `tier2-llama-cpp.json`, `tier2-llama-cpp.md` | Reports | S3-M2 LLM runtime validation | R2 |
| `tier2-open-webui.json`, `tier2-open-webui.md` | Reports | S4-M6 Open WebUI validation | R2 |
| `tier2-runtime-benchmark.json`, `tier2-validation.json` | Reports | S3-M6 benchmark and S3-M7 aggregate | R2 |
| `tier3-validation.json` and all Tier 3 NPU report aliases | Reports | S2-M4 visibility report plus S3-M4 runtime execution report | R2 |
| `tier4-embedding-models.json`, `tier4-embedding-models.md`, `tier4-embedding-models-packages.txt` | Reports | S3-M1 model manifest/storage report and S4-M3 RAG validation | R2 |
| Any `Tier 1`–`Tier 5` display label or `tier1-*`–`tier5-*` undocumented alias | Label/artifact catch-all | The owning canonical Stage/Milestone name under the ownership invariant | Same target as its owner row; R2 if ambiguous |

The catch-all is not permission to add an alias. It ensures every currently
generated Tier filename, including platform-dependent conditional outputs, has
a removal target even if it was omitted from a static repository scan.

## Migration sequence

1. Freeze Tier surfaces and add deprecation documentation; do not rename an
   implementation merely to make the tree look canonical.
2. Complete S1-M1 through S1-M5 in order. Prove read-only behavior and atomic
   profile publication with deterministic tests.
3. Move policy, visibility validation, tuning plans, and approved application
   to S2-M1 through S2-M7. Stop Stage 1 orchestration from invoking them.
4. Establish S3 model storage, runtime installers, execution validation, and
   fixed-workload benchmarks. Only then replace Tier 2/3 aggregates.
5. Move RAG and Open WebUI beside ComfyUI and the other Stage 4 applications;
   keep reusable runtime/model primitives in Stage 3.
6. Implement Stage 5 development and lifecycle contracts.
7. Bind R1/R2 to release versions, run compatibility consumer tests, remove
   aliases at their target, and publish migration notes.

No migration step may mark a target milestone implemented merely because a
legacy implementation was moved or renamed. Canonical outputs, deterministic
tests, and documentation remain mandatory.

## Dependency and gate policy

**Stage gate policy.** Later stages consume earlier canonical reports:

* Stage 1 has no dependency on mutating or performance-oriented stages.
* Stage 2 consumes a schema-valid S1-M5 profile, not Tier 1 aggregate status.
* Stage 3 consumes S2 visibility and policy reports but owns runtime packages,
  models, execution verification, and benchmarks.
* Stage 4 consumes S3 runtime contracts and may accept documented optional
  providers without confusing `WARN` with verified acceleration.
* Stage 5 backs up, restores, monitors, and regression-tests canonical outputs
  from all earlier stages.
* `PASS`, `WARN`, `FAIL`, `NOT_APPLICABLE`, and any experimental state must be
  defined in the owning schema. Missing required reports always block a
  dependent gate.

## Definition of done for roadmap work

Before changing a target milestone to **Implemented**, reviewers must verify:

* the command, scripts, functions, tests, reports, and schemas have exactly one
  registry owner;
* all listed canonical outputs exist and validate;
* deterministic positive, negative, idempotence, and relevant atomicity or
  approval tests pass;
* documentation describes inputs, outputs, status semantics, offline behavior,
  failure recovery, and compatibility aliases;
* Stage 1 paths are demonstrably read-only and profile-oriented;
* compatibility names delegate without owning new behavior; and
* the relevant Tier removal target and release note remain accurate.
