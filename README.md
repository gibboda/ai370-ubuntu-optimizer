# ai370-ubuntu-optimizer

Ubuntu 26.04 LTS optimization toolkit for the Minisforum EliteMini AI370 and
future Ryzen AI systems.

## Primary Target

Default profile:

- Minisforum EliteMini AI370
- AMD Ryzen AI 9 HX 370 / Strix Point
- Radeon 890M integrated GPU
- AMD XDNA2 NPU

## Guiding Principles

1. **Offline-first** — Prefer local artifacts, staged wheels, and pre-downloaded
   models. Network operations are opt-in.
2. **Local inference preferred** — Cloud-only or SaaS dependencies are
   non-goals.
3. **Hardware validation before application installation** — Establish a
   validated AI hardware foundation before installing end-user AI runtimes or
   UIs.
4. **Reproducible automation** — Scripted, profile-driven, with clear reports
   and dry-run support.
5. **Safe defaults** — Conservative baseline; ROCm / XRT / Ryzen AI stacks
   require explicit `--accept-amd-acceleration-risk`.
6. **Production-ready benchmarks** — Real measurements, not just presence
   checks.
7. **Modular architecture** — Roadmap-aligned stages allow adding support for
   future Ryzen AI systems (new profiles) without rewriting the AI370
   implementation; legacy tier aliases remain available.
8. **Future support for additional Ryzen AI systems** — Strict `ai370` profile
   by default; `generic-ryzen-ai` profile available for broadening.

## Roadmap Stage Architecture

The repository is organized around the five stages in `docs/ROADMAP.md`. Roadmap
stage commands are the preferred interface; existing `tierN` commands remain as
backward-compatible aliases. Stage 1 is the required foundation. Later stages
are only installed after lower-stage validation passes (especially: **do not
install Stage 3 image generation until Stage 1 + Stage 2 runtime + Stage 2 NPU
validation criteria have passed**).

### Stage 1 – Hardware Detection & System Optimization

**Purpose:** Establish a validated AI hardware foundation.

**Key Components:**

- Linux kernel + AMDGPU validation
- AMDXDNA (XDNA2 NPU) detection
- Mesa / Vulkan / ROCm validation
- CPU, memory, and storage optimization
- Benchmark framework

**Legacy tier alignment:** Roadmap Stage 1 maps directly to legacy Tier 1.
Complete this stage before starting any Stage 2 work. The sequence is detection
first, validation second, platform planning third, and optional local-AI smoke
last, matching the roadmap operating rules (Package C + E).

**Canonical commands:**

```bash
./ai370-optimize.sh stage1-probe           # S1-M1 read-only raw system inventory
./ai370-optimize.sh stage1-profile         # S1-M2 through S1-M5 read-only profile pipeline
./ai370-optimize.sh stage1                 # Compatibility orchestrator (still invokes BIOS/kernel/tuning)
./ai370-optimize.sh stage1-inventory       # Faster detect + inventory-scope validate
./ai370-optimize.sh stage1-validate        # Final Stage 1 gate (full scope)
./ai370-optimize.sh stage1-validate --inventory  # Re-check inventory scope only
./ai370-optimize.sh stage1 --with-ai-smoke # Include optional local-AI smoke (script 80)
./ai370-optimize.sh stage1 --apply-tuning  # Compatibility-only migration path; target Stage 1 contract is read-only
./ai370-optimize.sh stage1 --strict        # FAIL if gfx1150 or NPU missing
./ai370-optimize.sh tier1                  # Legacy alias for stage1
./ai370-optimize.sh tier1-validate         # Legacy alias for stage1-validate
```

`stage1-probe` writes `reports/latest/s1-m1-raw-inventory.json`. `stage1-profile`
runs S1-M1 if that inventory is missing, then publishes:

- `reports/latest/s1-m2-normalized-facts.json`
- `reports/latest/s1-m3-platform-classification.json`
- `reports/latest/s1-m4-capability-candidates.json`
- `reports/latest/s1-m5-system-profile.json`
- `reports/latest/s1-m5-inventory-summary.md`
- compatibility `reports/latest/system-profile.json`

S1-M2 derives GPU architecture from PCI vendor:device mappings in
`configs/profiles/gpu-pci-architectures.json`. Marketing names such as `890M`
or `Strix` are not architecture. Probe limitations are facts (`tool_missing`,
`permission_denied`, or `probe_failed`), not failures against reference-machine
expectations. The numbered hardware and NPU detection scripts remain
compatibility wrappers.

**Execution order (default `stage1`):**

```text
10-detect-hardware (incl. NPU; 75 wrapper)
-> 20-check-bios (BIOS + firmware; 25 wrapper)
-> 30-validate-kernel
-> 40-platform-tuning (CPU+memory+storage plan; 40/50/60 wrappers)
-> 70-validate-gpu-stack
-> 90-validate (scope=full; script 80 skipped unless --with-ai-smoke)
```

## Canonical Roadmap and Status

This repository uses `docs/ROADMAP.md` as the canonical roadmap and
implementation status. `README.md` documents usage and roadmap stage structure;
consult `docs/ROADMAP.md` for the authoritative list of implemented vs planned
files, current stage alignment, and contributor guidance. The target Ryzen AI
Linux platform architecture is
`docs/HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md`. The current-to-target
migration inventory is `docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md`.

Current high-level status (see `docs/ROADMAP.md` for details):

- Stage 1 profile pipeline: **Implemented** (S1-M1 through S1-M5). Use
  `stage1-probe` and `stage1-profile`. The mixed `stage1` command still runs
  BIOS, kernel, GPU-visibility, and tuning scripts; that is migration debt,
  not the canonical Stage 1 contract. `--apply-tuning` remains a compatibility
  path; the target Stage 1 contract in `docs/ROADMAP.md` and `AGENTS.md` is
  read-only.
- Stage 2: **Planned** in ROADMAP (S2-M1 through S2-M7). Current scripts exist
  as partial compatibility implementations (`stage2`, `stage2-runtime`,
  `stage2-npu`; legacy `tier2` / `tier3`). NPU PASS requires profiled AMD EP
  execution (`scripts/lib/npu_ep_verify.py`). Optional paths are not Stage 3
  gates. See `docs/ROADMAP.md`.
- Stage 3: **Planned** in ROADMAP. Current runtime/benchmark scripts exist as
  partial implementations. GAIA and LM Studio remain planned applications.

### Implemented / Planned (high level)

**Stage 1 — Implemented profile pipeline (S1-M1 through S1-M5):**

- `scripts/s1-m1-probe-system.sh` (`stage1-probe`) writes `s1-m1-raw-inventory.json`
- `scripts/s1-m2-normalize-profile.py` writes `s1-m2-normalized-facts.json`;
  GPU architecture is derived from PCI IDs in
  `configs/profiles/gpu-pci-architectures.json`
- `scripts/s1-m3-classify-platform.py` writes `s1-m3-platform-classification.json`
- `scripts/s1-m4-derive-capabilities.py` writes `s1-m4-capability-candidates.json`;
  candidates are not validation claims
- `scripts/s1-m5-publish-profile.py` (`stage1-profile`) writes
  `s1-m5-system-profile.json`, `s1-m5-inventory-summary.md`, and a
  compatibility `system-profile.json`
- Compatibility wrappers still present: `scripts/10-detect-hardware.sh`
  (includes NPU detect; `75` is a wrapper), `scripts/20-check-bios.sh`,
  `scripts/30-validate-kernel.sh`, `scripts/40-platform-tuning.sh`,
  `scripts/70-validate-gpu-stack.sh`, `scripts/90-validate.sh`. These are not
  the canonical Stage 1 contract.
- Commands: `stage1-probe`, `stage1-profile`; mixed `stage1`,
  `stage1-inventory`, `stage1-validate` remain compatibility orchestrators

The generated system profile uses schema v3 (`configs/schemas/s1-m5-system-profile.schema.json`,
same contract as `configs/schemas/system-profile.schema.json`). Its
algorithm-versioned hardware fingerprint is based only on normalized, stable
hardware identities, so software upgrades, driver state, probe formatting, and
device enumeration order do not change machine identity. Existing `tier1-*`
artifacts and gates remain available while Stage 2 consumers are migrated. The
profile records normalized hardware facts, classification evidence, derived
capability candidates, unknown fields, and missing collection tools. It does
not assert that a Stage 2 runtime has executed successfully.

**S1-M2 normalized-fact fields:** `system` (DMI manufacturer/product/board),
`cpu` (vendor/family/model/topology), `gpu` (PCI identities plus architecture
derived from the PCI map), `npu` (presence/family/driver/nodes), `pci`,
`firmware`, `operating_system`, `kernel`, `memory`, `storage`, and
`collection.missing_tools`. Unknown values stay explicit; they are not filled
from marketing names.

**Stage 2 — Planned (current scripts are partial compatibility implementations):**

- `scripts/100-install-pytorch-rocm.sh`, `scripts/110-install-llama-cpp.sh`,
  `scripts/120-install-ollama.sh`, `scripts/130-install-open-webui.sh`,
  `scripts/140-benchmark-llm.sh`, `scripts/145-write-tier2-validation.sh`,
  `scripts/150-validate-offline-model-storage.sh`,
  `scripts/155-stage-model-layout.sh` (S2-M1 / S2-M4 / S2-M5; layout polish)
- `scripts/200-install-onnxruntime.sh`,
  `scripts/205-install-xrt-ryzen-ai.sh`,
  `scripts/210-check-ryzen-ai-software.sh`, `scripts/220-check-vitis-ai-ep.sh`,
  `scripts/230-benchmark-npu.sh`, `scripts/240-write-tier3-validation.sh`,
  `scripts/245-compare-cpu-gpu-npu.sh` (reuses 230 NPU results by default),
  `scripts/lib/npu_ep_verify.py`, `scripts/lib/common.sh`, `docs/npu-status.md`
  (S2-M2 / S2-M4)
- `scripts/300-install-anythingllm.sh`,
  `scripts/310-install-embedding-models.sh`, `scripts/320-validate-rag.sh`
  (S2-M3 offline RAG; optional, not Stage 3 gate)
- `scripts/170-install-turnkeyml.sh`, `scripts/160-install-lemonade.sh`,
  `scripts/165-validate-lemonade.sh`, `scripts/lib/lemonade-env.sh`
  (S2-M6 TurnkeyML + Lemonade; optional WARN-friendly path)
- `scripts/250-install-digest-ai.sh`, `scripts/255-analyze-model-digest.sh`,
  `scripts/lib/digest_analyze.py` (S2-M7 Digest AI / ONNX analysis;
  diagnostics only)

**Stage 3+ — Planned / not present (or partial):**

- `scripts/400-install-comfyui.sh` (S3-M1)
- `scripts/410-install-comfyui-models.sh` (S3-M2)
- `workflows/comfyui/flux/`, `workflows/comfyui/sdxl/`,
  `workflows/comfyui/controlnet/`, `workflows/comfyui/upscalers/` (S3-M3)
- ComfyUI start/stop/status/health automation (`430`–`434`, S3-M5)
- Offline text/embed/Whisper app validators (`440`–`444`, S3-M6)
- GAIA and LM Studio installers (optional S3 apps)
- Stage 4 Continue/Aider and Stage 5 lifecycle automation

Partial Stage 3 already present: `scripts/420-benchmark-comfyui.sh` and some
workflows under `workflows/comfyui/`.

For the authoritative, up-to-date status and contributor guidance consult
`docs/ROADMAP.md` (including **Next implementation steps** after Stage 2).

AUTOMATIC1111's Stable Diffusion WebUI is not currently supported. See the
[`AUTOMATIC1111 codebase review`](docs/automatic1111-review.md) for the audited
gaps, risks, and recommended Stage 3 implementation boundary.

Stable Diffusion WebUI Forge is also not currently supported. See the
[`Forge codebase review`](docs/forge-review.md) for the audited integration
gaps, fork-specific risks, and recommended Stage 3 implementation boundary.

For a proposed Stage 3 personal-agent architecture that composes OpenClaw with
multiple local LLM roles, Ollama/Lemonade providers, offline RAG, and tiered
tool permissions, see `docs/openclaw-multi-llm-agent.md`.

**Deliverables (Stage 1 scripts — canonical + wrappers):**

```text
scripts/
  s1-m1-probe-system.sh          # canonical S1-M1 raw inventory probe
  10-detect-hardware.sh          # compatibility wrapper → S1-M1 probe
  20-check-bios.sh               # canonical (BIOS + firmware)
  25-check-firmware.sh           # wrapper → 20
  30-validate-kernel.sh          # canonical
  40-platform-tuning.sh          # canonical (CPU+memory+storage plan)
  40-optimize-cpu.sh             # wrapper → 40-platform-tuning
  50-optimize-memory.sh          # wrapper → 40-platform-tuning
  60-optimize-storage.sh         # wrapper → 40-platform-tuning
  70-validate-gpu-stack.sh       # canonical
  75-detect-npu.sh               # compatibility wrapper → S1-M1 probe
  80-benchmark-local-ai.sh       # optional (--with-ai-smoke)
  90-validate.sh                 # gate (inventory|full|smoke)
```

**Acceptance Criteria:**

- `./ai370-optimize.sh stage1` completes the canonical platform sequence
  (`tier1` remains an alias). Script 80 is optional.
- Radeon 890M detected, or profile variance is clearly reported (WARN by
  default; FAIL with `--strict`).
- AMDGPU kernel driver state recorded.
- Vulkan available, or missing support is clearly reported.
- ROCm detected or cleanly reported missing.
- AMDXDNA / XDNA2 NPU detected or cleanly reported missing (WARN by default;
  FAIL with `--strict`).
- BIOS 2.01 validation recorded for EliteMini AI370.
- Firmware, Secure Boot, and microcode validation recorded.
- Kernel validation recorded.
- CPU, memory, and storage platform plans complete without overwriting user
  data (runtime apply is opt-in via `--apply-tuning`).
- Local AI smoke output is generated when `--with-ai-smoke` is used.
- `scripts/90-validate.sh` exits successfully (or FAIL under strict missing
  hardware) and writes `reports/latest/tier1-validation.json` plus
  `reports/latest/tier1-summary.md`. Stage 1 `PASS` may still list acceptance
  WARNs; that is intentional for experimental iteration.

### Stage 2 – Local AI Runtime & AI Optimization Software

Use `stage2` for the roadmap-aligned **core** aggregate command. Stage 2 planned
scope is **implemented** (S2-M1–S2-M7). Default `stage2` runs runtime/model-storage
plus NPU checks and always writes `reports/latest/tier3-validation.json` for the
Stage 3 gate. Optional packs are **not** run by default (not Stage 3 gate inputs):

```bash
./ai370-optimize.sh stage2 [--offline]
./ai370-optimize.sh stage2 --with-lemonade --with-digest --with-rag   # optional packs
./ai370-optimize.sh stage2-validate [--offline]                       # cheap gate refresh
./ai370-optimize.sh stage2-validate --bench [--with-lemonade]         # full smokes
./ai370-optimize.sh stage2-rag | stage2-lemonade | stage2-digest
./ai370-optimize.sh stage2-models   # S2-M5 layout + validate (no downloads)
# Full-stack optional smokes:
#   LEMONADE_START=true ./scripts/165-validate-lemonade.sh
#   ANYTHINGLLM_START=true ./scripts/300-install-anythingllm.sh
```

**Stage 3 gate policy (default):** Stage 1 must be `PASS`. Stage 2 runtime and
offline model storage accept `PASS` or `WARN`. Stage 2 NPU accepts `PASS`,
`WARN`, or `EXPERIMENTAL-PASS`. See `docs/ROADMAP.md` (Stage gate policy).

### Stage 2 Runtime – Local AI Runtime Layer

**Purpose:** Provide local AI execution capability.

**Components:**

- Ollama + llama.cpp
- Open WebUI (optional)
- PyTorch (ROCm where available)
- Hugging Face transformers / tokenizers (local)
- Offline model storage and manifest validation

**Commands:**

```bash
./ai370-optimize.sh stage2 [--offline] [--with-lemonade] [--with-digest] [--with-rag]
./ai370-optimize.sh stage2-validate [--offline] [--bench] [--with-lemonade]
./ai370-optimize.sh stage2-runtime [--offline] [--with-lemonade]
./ai370-optimize.sh stage2-runtime-validate [--offline] [--with-lemonade]
./ai370-optimize.sh tier2 [--offline]              # Legacy alias → stage2-runtime
./ai370-optimize.sh tier2-validate [--offline]     # Legacy alias
```

**Deliverables (Stage 2 runtime scripts):**

```text
scripts/
  100-install-pytorch-rocm.sh
  110-install-llama-cpp.sh
  120-install-ollama.sh
  130-install-open-webui.sh
  140-benchmark-llm.sh
  150-validate-offline-model-storage.sh
```

**Acceptance Criteria:**

- PyTorch detects ROCm when available, or records CPU-only / missing ROCm
  cleanly.
- llama.cpp validates an existing binary or builds from source in online mode
  when build tools are available.
- Ollama is installed/validated and local models are reported without pulling
  cloud manifests during validation.
- Open WebUI is installed/validated as an optional local UI and cleanly reported
  missing when offline. Its installer uses a dedicated
  `.ai370-ai/open-webui-venv` by default so Python version constraints do not
  conflict with the shared AI runtime venv.
- Benchmark and Stage 2 runtime gate reports are collected in `reports/latest/`
  (`tier2-runtime-benchmark.*`, `llm-validation.*`, and `tier2-validation.*`).
- When a local GGUF or Ollama model is available, `140-benchmark-llm.sh` runs a
  short measured smoke and records `load_time_ms` / `tokens_per_sec` (and wall
  time) in those reports. Override with `SMOKE_N_PREDICT`, `SMOKE_PROMPT`,
  `SMOKE_LLAMA_TIMEOUT_SEC`, `SMOKE_OLLAMA_TIMEOUT_SEC`, or `OLLAMA_HOST`.
- `110-install-llama-cpp.sh` prefers HIP (`GGML_HIP`) when `hipcc` is available,
  else Vulkan, else CPU. Existing CPU-only builds are left in place with a WARN
  and rebuild guidance (`LLAMA_CPP_FORCE_REBUILD=true`).
- Stage 2 scripts exit **non-zero only on `status=FAIL`**. `PASS` and `WARN`
  remain exit 0 so experimental stacks can continue.

### Stage 2 NPU – AMD AI Stack Enablement

**Purpose:** Enable XDNA2 experimentation and benchmarking.

**Components:**

- ONNX + ONNX Runtime
- Ryzen AI Software (staged artifacts)
- Vitis AI / NPU Execution Provider support
- Profiled EP verification (`scripts/lib/npu_ep_verify.py`) — NPU PASS only when
  kernels run on the AMD EP
- NPU-specific benchmark suite (ONNX smoke + XRT tools)
- Implemented (optional WARN path): TurnkeyML + Lemonade Server (S2-M6) for
  NPU/hybrid LLM serving via `stage2-lemonade` / `stage2-npu` wiring
- Implemented (diagnostics only): Digest AI (S2-M7) via `stage2-digest`

**Commands:**

```bash
./ai370-optimize.sh stage2-npu [--offline] [--with-lemonade]
./ai370-optimize.sh stage2-npu --accept-amd-acceleration-risk   # install staged XRT/Ryzen AI
./ai370-optimize.sh stage2-npu-validate [--bench] [--with-lemonade]
./ai370-optimize.sh stage2-lemonade [--offline]    # S2-M6 only
./ai370-optimize.sh stage2-digest [--offline]      # S2-M7 only
./ai370-optimize.sh tier3 [--offline]              # Legacy alias → stage2-npu
./ai370-optimize.sh tier3-validate                 # Legacy alias
```

`stage2-npu` runs `scripts/205-install-xrt-ryzen-ai.sh` first (inventory by default;
install when `--accept-amd-acceleration-risk` is set and packages are staged under
`.ai370-ai/amd-artifacts`).

**Acceptance Criteria:**

- ONNX Runtime installed with NPU-capable execution providers visible
- NPU execution path validated (device nodes + XRT or provider check)
- NPU benchmark report generated

**Important:** Stage 2 NPU validation is required before Stage 3 image
generation installation.

### Stage 2 RAG – Local Knowledge Systems

**Components:**

- AnythingLLM (Docker image or AppImage; offline-staged under
  `.ai370-ai/offline-artifacts/anythingllm/`)
- Local embedding models (existing, staged copy, or download)
- Offline document store (`.ai370-ai/rag/documents/`) + retrieval smoke
- Aggregate report: `reports/latest/stage2-rag-validation.json`

**Commands:**

```bash
./ai370-optimize.sh stage2-rag
./ai370-optimize.sh stage2-rag --offline
./ai370-optimize.sh tier4          # Legacy alias
```

**Current status:** Implemented offline lifecycle (S2-M3). `stage2-rag` /
`tier4` invoke `scripts/300-install-anythingllm.sh`,
`scripts/310-install-embedding-models.sh`, and `scripts/320-validate-rag.sh`.
Online mode may pull/download; offline mode uses staged artifacts and
wheelhouse only. Stage 2 RAG is optional and is not part of the Stage 3 gate.

**Acceptance Criteria:**

- Embedding model installable offline from staged tree or online download
- Offline semantic retrieval smoke passes without network after staging
- AnythingLLM image/AppImage loadable from staged artifacts when Docker/AppImage
  is present
- Aggregate report distinguishes `production_ready` (embedding RAG) from
  `full_stack_ready` (including AnythingLLM)

### Stage 3 Image Generation – Generative AI

**Components:**

- ComfyUI
- Flux, SDXL, ControlNet, IPAdapter, upscaling workflows
- Production benchmarking

**Commands:**

```bash
./ai370-optimize.sh stage3-image
./ai370-optimize.sh tier5             # Legacy alias
./ai370-optimize.sh comfyui-install   # alias, gated
```

**Important gate:** Stage 3 image generation installation and benchmarking are
blocked (or emit clear error + guidance) until Stage 1, Stage 2 runtime, and
Stage 2 NPU validation criteria are acceptable under the default gate policy
(Stage 1 `PASS`; runtime/models `PASS|WARN`; NPU `PASS|WARN|EXPERIMENTAL-PASS`).
Run `./ai370-optimize.sh stage2` (or the split runtime/NPU validate commands) so
`tier2-validation.json`, `offline-model-storage.json`, and
`tier3-validation.json` exist. ComfyUI will default to CPU-safe mode unless
acceleration was explicitly installed and re-validated.

**Acceptance Criteria:**

- ComfyUI launches successfully
- Flux (or SDXL) workflow executes
- SDXL / production benchmark report generated (`comfyui-benchmark.csv` +
  summary)

### Stage Commands (recommended user interface)

```bash
./ai370-optimize.sh stage1                 # Platform Stage 1 (plan-only; optional --with-ai-smoke/--strict/--apply-tuning)
./ai370-optimize.sh stage1-inventory       # Detect-only + inventory-scope validate
./ai370-optimize.sh stage1-validate        # Gate re-check (add --inventory or --strict)
./ai370-optimize.sh stage2 [--offline] [--with-lemonade] [--with-digest] [--with-rag]
./ai370-optimize.sh stage2-validate [--offline] [--bench] [--with-lemonade]
./ai370-optimize.sh stage2-runtime [--offline] [--with-lemonade]
./ai370-optimize.sh stage2-runtime-validate [--offline] [--with-lemonade]
./ai370-optimize.sh stage2-npu [--offline] [--with-lemonade]
./ai370-optimize.sh stage2-npu-validate [--bench] [--with-lemonade]
./ai370-optimize.sh stage2-rag             # Optional RAG (S2-M3; not Stage 3 gate)
./ai370-optimize.sh stage2-lemonade        # Optional Lemonade (S2-M6)
./ai370-optimize.sh stage2-digest          # Optional Digest AI (S2-M7)
./ai370-optimize.sh stage2-models          # S2-M5 layout + storage validate (no downloads)
./ai370-optimize.sh stage3-image           # Requires Stage 1 + Stage 2 runtime/NPU validation gate
./ai370-optimize.sh full-stack --accept-amd-acceleration-risk   # S1 + S2 core + optional packs + accel + S3 workflows
```

Legacy `tierN` commands and legacy nine-phase commands remain available for
compatibility (see below).

## Legacy Phase Mapping (implementation details)

The roadmap stage model is the primary user-facing structure. Under the hood the
implementation still uses (and you can invoke) the detailed audit-first phases:

- Stage 1 / legacy Tier 1 roughly covers the old Phases 1–6 + final core
  validation.
- Stage 2 Runtime / legacy Tier 2 covers old Phase 7 (LLM) + AI runtime.
- Stage 2 NPU / legacy Tier 3 covers NPU half of acceleration + ONNX work.
- Stage 3 Image / legacy Tier 5 covers old Phase 8–9 (ComfyUI).

You can still run the classic commands (they continue to work and write the same
rich `reports/latest/` artifacts):

```text
hardware | inventory | audit          -> Stage 1 / legacy Tier 1 hardware detection
firmware                               -> Stage 1 / legacy Tier 1 BIOS check
kernel-amd | baseline-plan | plan      -> Stage 1 / legacy Tier 1 kernel + AMD baseline (with --dry-run)
tune                                   -> Stage 1 / legacy Tier 1 CPU/RAM/storage optimization
accel-validate | gpu | npu             -> Stage 1 / legacy Tier 1 GPU stack + Stage 2 NPU / legacy Tier 3 NPU visibility
ai-bench | ai-runtime                  -> Stage 1 / legacy Tier 1 local AI benchmark (Stage 2 runtime overlap)
llm-validate                           -> Stage 2 Runtime / legacy Tier 2
amd-accel-install                      -> Explicit opt-in (used by Stage 2 NPU / Stage 3 image paths)
comfyui-install | comfyui              -> Stage 3 Image / legacy Tier 5 (gated)
comfyui-bench                          -> Stage 3 Image / legacy Tier 5
final-validate | validate              -> Stage 1 / legacy Tier 1 + overall
install | full-ai-install              -> Multi-stage flows (full-ai-install still requires --accept-amd-acceleration-risk)
```

All phases continue to communicate through `reports/latest/` (JSON + Markdown +
text summaries). Roadmap stage commands and legacy tier aliases also produce
`tierN-*.json` / `tierN-summary.md` artifacts for clear gates.

## Phase Artifacts

- `hardware-inventory.json`, `hardware-audit.txt`, and `hardware-summary.md`
  record structured Phase 1 hardware, OS, firmware, power, GPU, NPU, storage,
  and missing-tool facts.
- `firmware-baseline.json` and `firmware-baseline.md` record Phase 2 BIOS,
  fwupd, and `linux-firmware` baseline state without applying firmware updates.
- `hardware.json`, `baseline-plan.json`, `baseline-postcheck.json`,
  `baseline-validation.txt`, and `baseline-validation.md` record Phase 3
  kernel/AMD baseline validation, approved packages, blocked actions, and
  post-checks.
- `system-tuning-plan.json`, `system-tuning-plan.md`, and
  `runtime-tuning-commands.sh` record Phase 4 CPU/RAM/storage recommendations
  and reviewable runtime-only commands.
- `gpu-capabilities.json`, `gpu-smoke-benchmark.md`, `npu-capabilities.json`,
  `npu-smoke-benchmark.md`, and `xrt-status.txt` record Phase 5 local
  ROCm/Vulkan/OpenCL/XDNA visibility.
- `ai-runtime-benchmark.json` and `ai-runtime-benchmark.md` record Phase 6
  CPU/ONNX Runtime smoke benchmarks.
- `tier2-pytorch-rocm.json`, `tier2-llama-cpp.json`, `tier2-ollama.json`,
  `tier2-open-webui.json`, `tier2-runtime-benchmark.json`,
  `llm-validation.json`, and `tier2-validation.json` record Milestone 2 / Stage
  2 runtime installation, local model visibility, and gate status.
  Tier 2 PyTorch installation removes stale PyTorch package cache entries,
installs `torch`, `torchvision`, and `torchaudio` together from the selected
PyTorch index, and automatically uses the configured nightly/pre-release index
for Python runtimes that need newer wheels, such as Python 3.14+.
- `amd-acceleration-install.json`, `amd-acceleration-install.md`, and
  `amd-acceleration-env.sh` record the explicit opt-in AMD acceleration
  installation state when Phase 7.5 is run.
- `comfyui-status.txt` and `comfyui-workflow-guide.md` record Phase 8
  installation paths and launch guidance.
- `comfyui-benchmark.csv` and `comfyui-benchmark-summary.md` record Phase 9
  workflow benchmark output.

## Offline AI Hardware Optimization Before ComfyUI

Phases 5-7 can be run with `--offline` to focus on local CPU/iGPU/NPU/LLM
readiness before any ComfyUI setup. Offline mode does not fetch packages, clone
repositories, download models, or install ROCm/XRT/Ryzen AI runtime stacks. It
expects local artifacts to already be staged. For Phase 6 specifically, if the
configured wheelhouse is missing, the run can continue only when the existing
virtual environment already satisfies
`configs/ai-runtime/requirements-offline.txt`.

Default offline artifact paths are configured in
`configs/offline/ai-runtime.env`:

- `.ai370-ai/wheelhouse/` for Python wheels used by Phase 6.
- `configs/ai-runtime/requirements-offline.txt` for the offline Python package
  list.
- `.ai370-ai/models/` for local smoke-test, representative AI, and GGUF models.
- `.ai370-ai/tools/` for local benchmark/helper binaries such as approved
  llama.cpp builds.

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

Run `./ai370-optimize.sh comfyui-install` only after these reports show the
local AI runtime and hardware paths are stable.

## Opt-in Full AMD Acceleration Before ComfyUI

The default flow remains conservative. If you explicitly want the toolkit to
install AMD ROCm GPU packages plus staged XRT/Ryzen AI NPU artifacts before
ComfyUI, use the risk-acknowledged acceleration phase:

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

- ROCm repository version, repository codename, package list, artifact paths,
  and ComfyUI acceleration mode are configured in
  `configs/amd-acceleration.env`.
- The default ROCm repository codename is `resolute`, matching Ubuntu 26.04 LTS
  (Resolute Raccoon), so the AMD acceleration phase remains aligned with the
  toolkit target release.
- Ryzen AI / XRT NPU packages are not fetched automatically from AMD
  account-gated download pages. Stage the required `.deb` files and
  `ryzen_ai-*.tgz` under `.ai370-ai/amd-artifacts/`, or run with
  `AMD_ARTIFACT_ROOT=/absolute/path/to/amd-artifacts` when the files live
  outside the checkout.
- XRT/NPU `.deb` selection does not hard-code Ubuntu releases. Auto mode prefers
  the host `VERSION_ID`, then the previous LTS, then version tags discovered in
  staged deb filenames (newest first), then optional `XRT_DEB_GLOBS`, otherwise
  fail. Pin an order with `XRT_UBUNTU_VERSIONS` if needed, or force custom globs
  only with `XRT_DEB_GLOBS_MODE=override`.
- Staged NPU driver files should include names like
  `xrt_<version>_<ubuntu>-amd64-base.deb`,
  `xrt_<version>_<ubuntu>-amd64-base-dev.deb`,
  `xrt_<version>_<ubuntu>-amd64-npu.deb`, and
  `xrt_plugin.<version>_<ubuntu>-amd64-amdxdna.deb`; extract any compressed AMD
  driver bundle under the artifact root before running `amd-accel-install`.
  Source-built XDNA packages such as `xrt_<version>_<ubuntu>-amd64-xrt.deb` and
  `xrt_plugin.<version>_ubuntu<ubuntu>-x86_64-amdxdna.deb` are also recognized.
- ComfyUI is generated without `--cpu` only after the explicit AMD acceleration
  phase has completed and ROCm remains visible in the Phase 5 GPU validation
  report. Otherwise it stays CPU-safe.

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

The workflow templates are model-agnostic starters. Review
`workflows/comfyui/README.md` and `workflows/comfyui/production/README.md`
before treating any JSON workflow as drop-in runnable for your local model
filenames.

## License

GPLv3
