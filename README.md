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

### Stage 1 – Hardware Discovery & System Profile

**Purpose:** Read-only hardware and OS probing, fact normalization, platform
classification, capability-candidate derivation, and publication of the system
profile. Stage 1 does not install packages, apply tuning, or run benchmarks.

**Key Components:**

- Raw system probe (CPU, DMI, PCI, GPU, NPU, firmware, kernel, storage)
- Normalized facts and platform-family classification
- Capability candidates (not validation claims)
- Canonical `s1-m5-system-profile.json`

**Legacy tier alignment:** `tier1` remains an alias for `stage1`. BIOS, kernel,
GPU/NPU visibility, and tuning moved to Stage 2 platform commands.

**Canonical commands:**

```bash
./ai370-optimize.sh stage1-probe           # S1-M1 read-only raw system inventory
./ai370-optimize.sh stage1-profile         # S1-M2 through S1-M5 read-only profile pipeline
./ai370-optimize.sh stage1                 # Same as stage1-profile (read-only)
./ai370-optimize.sh tier1                  # Legacy alias for stage1
./ai370-optimize.sh stage2-platform-validate   # Firmware + kernel + GPU + NPU visibility
./ai370-optimize.sh stage2-optimize-plan       # CPU/memory/storage plan (no mutation)
./ai370-optimize.sh stage2-optimize-apply --approve
./ai370-optimize.sh stage1-inventory       # Deprecated alias → stage2-platform-inventory
./ai370-optimize.sh stage1-validate        # Deprecated alias → stage2-platform-validate
./ai370-optimize.sh tier1-validate         # Legacy alias → stage2-platform-validate
```

`--apply-tuning` and `--with-ai-smoke` are not Stage 1 flags. Use
`stage2-optimize-apply --approve` and `scripts/80-benchmark-local-ai.sh`.
`--strict` applies to Stage 2 platform validate (missing gfx1150/NPU → FAIL).

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
s1-m1-probe-system (if s1-m1-raw-inventory.json is missing)
-> s1-m2-normalize-profile
-> s1-m3-classify-platform
-> s1-m4-derive-capabilities
-> s1-m5-publish-profile
```

Platform firmware, kernel, GPU/NPU visibility, and tuning are Stage 2 commands
(`stage2-platform-validate`, `stage2-optimize-plan`).

## Canonical Roadmap and Status

This repository uses `docs/ROADMAP.md` as the canonical roadmap and
implementation status. `README.md` documents usage and roadmap stage structure;
consult `docs/ROADMAP.md` for the authoritative list of implemented vs planned
files, current stage alignment, and contributor guidance. The target Ryzen AI
Linux platform architecture is
`docs/HARDWARE_AWARE_RYZEN_AI_LINUX_PLATFORM.md`. The current-to-target
migration inventory is `docs/RYZEN_AI_LINUX_PLATFORM_MIGRATION_PLAN.md`.

Current high-level status (see `docs/ROADMAP.md` for details):

- Stage 1 profile pipeline: **Implemented** (S1-M1 through S1-M5). `stage1`,
  `stage1-probe`, and `stage1-profile` are read-only. BIOS, kernel, GPU/NPU
  visibility, and tuning run from Stage 2 platform commands.
- Stage 2: **Planned** in ROADMAP except S2-M3/S2-M4, which are **In progress**
  (capability ladder library and visibility schemas; GPU publisher landed in
  [#176](https://github.com/gibboda/ai370-ubuntu-optimizer/issues/176);
  NPU visibility-only publisher is `stage2-npu-validate` / S2-M4).
  Platform wrappers (`stage2-firmware-validate`, `stage2-kernel-validate`,
  `stage2-optimize-plan`, `stage2-optimize-apply --approve`,
  `stage2-platform-validate`) exist; they do not upgrade S2-M1/M2/M5–M7 to
  Implemented. Current runtime scripts remain partial compatibility
  implementations (`stage2`, `stage2-runtime`, `stage2-npu`; legacy `tier2` /
  `tier3`). `stage2-validate` remains the runtime/NPU cheap gate until the
  S3 split; it is not the S2-M7 platform aggregate.
  `stage2-npu-validate` is visibility-only by default (writes
  `s2-m4-npu-runtime-validation.json` and refreshes `tier3-validation.json`);
  pass `--bench` for the mixed 230/245 compatibility path until S3-M6.
  NPU PASS requires profiled AMD EP execution (`scripts/lib/npu_ep_verify.py`).
  Optional paths are not Stage 3 gates. See `docs/ROADMAP.md`.
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
  (includes NPU detect; `75` is a wrapper). BIOS, kernel, tuning, GPU, and
  `90-validate.sh` are Stage 2 platform wrappers, not the Stage 1 contract.
- Commands: `stage1-probe`, `stage1-profile`, and `stage1` (read-only).
  `stage1-inventory` and `stage1-validate` redirect to Stage 2 platform commands.

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

- `scripts/s2-m3-validate-gpu-stack.sh`, `scripts/s2-m3-publish-gpu-visibility.py`,
  `configs/schemas/s2-m3-gpu-runtime-visibility.schema.json` (S2-M3 GPU/Vulkan/ROCm
  visibility; `stage2-gpu-validate`; compat `70-validate-gpu-stack.sh`)
- `scripts/s2-m4-validate-npu-stack.sh`, `scripts/s2-m4-publish-npu-visibility.py`,
  `configs/schemas/s2-m4-npu-runtime-validation.schema.json` (S2-M4 NPU visibility;
  `stage2-npu-validate`; compat `npu-acceleration-status.json` /
  `npu-capabilities.json`; mixed `--bench` path until S3-M6)
- `scripts/100-install-pytorch-rocm.sh`, `scripts/110-install-llama-cpp.sh`,
  `scripts/120-install-ollama.sh`, `scripts/130-install-open-webui.sh`,
  `scripts/140-benchmark-llm.sh`, `scripts/145-write-tier2-validation.sh`,
  `scripts/150-validate-offline-model-storage.sh`,
  `scripts/155-stage-model-layout.sh` (S3-M2 / S3-M3 / S3-M1; layout polish)
- `scripts/200-install-onnxruntime.sh`,
  `scripts/205-install-xrt-ryzen-ai.sh`,
  `scripts/210-check-ryzen-ai-software.sh`, `scripts/220-check-vitis-ai-ep.sh`,
  `scripts/230-benchmark-npu.sh`, `scripts/240-write-tier3-validation.sh`,
  `scripts/245-compare-cpu-gpu-npu.sh` (reuses 230 NPU results by default),
  `scripts/lib/npu_ep_verify.py`, `scripts/lib/common.sh`, `docs/npu-status.md`
  (S3-M4)
- `scripts/300-install-anythingllm.sh`,
  `scripts/310-install-embedding-models.sh`, `scripts/320-validate-rag.sh`
  (S4-M3 offline RAG; optional, not Stage 3 gate)
- `scripts/170-install-turnkeyml.sh`, `scripts/160-install-lemonade.sh`,
  `scripts/165-validate-lemonade.sh`, `scripts/lib/lemonade-env.sh`
  (S3-M5 TurnkeyML + Lemonade; optional WARN-friendly path)
- `scripts/250-install-digest-ai.sh`, `scripts/255-analyze-model-digest.sh`,
  `scripts/lib/digest_analyze.py` (S3-M4 Digest AI / ONNX analysis;
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
  s1-m2-normalize-profile.py
  s1-m3-classify-platform.py
  s1-m4-derive-capabilities.py
  s1-m5-publish-profile.py
  10-detect-hardware.sh          # compatibility wrapper → S1-M1 probe + legacy artifacts
  75-detect-npu.sh               # compatibility wrapper → S1-M1 probe
```

Stage 2 platform wrappers (not Stage 1): `20-check-bios.sh`, `30-validate-kernel.sh`,
`40-platform-tuning.sh`, `s2-m3-validate-gpu-stack.sh`, `s2-m4-validate-npu-stack.sh`,
`90-validate.sh`.

**Acceptance Criteria:**

- `./ai370-optimize.sh stage1` publishes `s1-m5-system-profile.json` and does not
  apply tuning, run BIOS/kernel policy, or invoke `90-validate.sh`.
- Probe limitations are recorded as facts, not reference-machine failures.
- GPU architecture comes from PCI mappings, not marketing names.
- `tier1` remains an alias for read-only `stage1`.

### Stage 2 – Platform Enablement and Local AI Runtime

ROADMAP status: S2-M3/S2-M4 In progress; S2-M1, S2-M2, and S2-M5–S2-M7 remain
**Planned**. Wrappers below do not mark those Planned milestones Implemented.

**Platform commands (S2-M1–M7 wrappers):**

```bash
./ai370-optimize.sh stage2-firmware-validate
# Consumes reports/latest/s1-m5-system-profile.json (run stage1 first).
# BIOS policy uses classified platform_id, not CLI --profile alone.
./ai370-optimize.sh stage2-kernel-validate [--dry-run]
./ai370-optimize.sh stage2-gpu-validate [--offline]   # S2-M3 GPU visibility ladder report
./ai370-optimize.sh stage2-npu-validate [--offline]   # S2-M4 NPU visibility ladder report
./ai370-optimize.sh stage2-optimize-plan              # plan-only; no mutation
./ai370-optimize.sh stage2-optimize-apply --approve [--dry-run]
./ai370-optimize.sh stage2-platform-validate [--strict]
./ai370-optimize.sh stage2-platform-inventory [--strict]
```

`stage2-platform-validate` runs firmware, kernel, GPU visibility, NPU
visibility, and the compatibility `90-validate.sh` aggregate. Canonical
`s2-m7-platform-validation.json` is still Planned. `stage2-validate` remains
the **runtime/NPU cheap gate** until the Stage 3 split; it is not an alias
for platform validate.

Use `stage2` for the runtime/model-storage + NPU aggregate. Default `stage2`
writes `reports/latest/tier3-validation.json` for the Stage 3 gate. Optional
packs are **not** run by default (not Stage 3 gate inputs):

```bash
./ai370-optimize.sh stage2 [--offline]
./ai370-optimize.sh stage2 --with-lemonade --with-digest --with-rag   # optional packs
./ai370-optimize.sh stage2-validate [--offline]                       # cheap gate refresh
./ai370-optimize.sh stage2-validate --bench [--with-lemonade]         # full smokes
./ai370-optimize.sh stage2-rag | stage2-lemonade | stage2-digest
./ai370-optimize.sh stage2-gpu-validate [--offline]   # S2-M3 GPU visibility ladder report
./ai370-optimize.sh stage2-npu-validate [--offline]   # S2-M4 NPU visibility ladder report
./ai370-optimize.sh stage2-models   # S3-M1 layout + validate (no downloads)
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

**Purpose:** Record XDNA2 NPU **visibility** (S2-M4) separately from execution
proof (S3-M4 / `scripts/230-benchmark-npu.sh`).

**Canonical visibility path (S2-M4):**

- Kernel module and device-node probes
- Inventory-only XRT / Ryzen AI staging (`scripts/205-install-xrt-ryzen-ai.sh`
  without `--accept-amd-acceleration-risk`)
- Runtime tool visibility (`xrt-smi examine`; not `xrt-smi validate`)
- Backend provider listing (`scripts/220-check-vitis-ai-ep.sh`)
- Canonical report: `reports/latest/s2-m4-npu-runtime-validation.json`
- Compatibility reports: `npu-acceleration-status.json`, `npu-capabilities.json`

S2-M4 does **not** run `scripts/230-benchmark-npu.sh` and does not claim
executed inference. `validation_claim` in the ladder report is always `false`.

**Compatibility mixed path (until S3-M6):** `stage2-npu` and
`stage2-npu-validate --bench` still run 205/210/220/230/245, including
profiled EP verification (`scripts/lib/npu_ep_verify.py`). Default
`stage2-npu-validate` always runs `scripts/240-write-tier3-validation.sh`
so the Stage 3 gate artifact exists without `--bench`.

**Commands:**

```bash
./ai370-optimize.sh stage2-npu-validate [--offline]            # S2-M4 visibility only
./ai370-optimize.sh stage2-npu-validate --bench [--with-lemonade]
./ai370-optimize.sh stage2-npu [--offline] [--with-lemonade]   # mixed install + bench
./ai370-optimize.sh stage2-npu --accept-amd-acceleration-risk   # install staged XRT/Ryzen AI
./ai370-optimize.sh stage2-lemonade [--offline]    # S3-M5 compatibility path
./ai370-optimize.sh stage2-digest [--offline]      # S3-M4 diagnostics
./ai370-optimize.sh tier3 [--offline]              # Legacy alias → stage2-npu
./ai370-optimize.sh tier3-validate                 # Legacy alias → stage2-npu-validate
```

`stage2-npu` runs `scripts/205-install-xrt-ryzen-ai.sh` first (inventory by default;
install when `--accept-amd-acceleration-risk` is set and packages are staged under
`.ai370-ai/amd-artifacts`).

**Acceptance Criteria:**

- Visibility-only validate writes schema-valid `s2-m4-npu-runtime-validation.json`
- Default `stage2-npu-validate` also refreshes `tier3-validation.json`
- ONNX Runtime NPU-capable providers may be visible without proving inference
- Mixed `--bench` / `stage2-npu` still produces NPU benchmark reports

**Important:** Stage 2 NPU **execution** validation remains part of the Stage 3
image-generation gate via the mixed `stage2-npu` / `--bench` path until S3-M6.

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
./ai370-optimize.sh stage1                 # Read-only S1-M1 through S1-M5 profile
./ai370-optimize.sh stage2-platform-validate [--strict]
./ai370-optimize.sh stage2-platform-inventory [--strict]
./ai370-optimize.sh stage2-optimize-plan
./ai370-optimize.sh stage2-optimize-apply --approve [--dry-run]
./ai370-optimize.sh stage2 [--offline] [--with-lemonade] [--with-digest] [--with-rag]
./ai370-optimize.sh stage2-validate [--offline] [--bench] [--with-lemonade]
./ai370-optimize.sh stage2-runtime [--offline] [--with-lemonade]
./ai370-optimize.sh stage2-runtime-validate [--offline] [--with-lemonade]
./ai370-optimize.sh stage2-npu [--offline] [--with-lemonade]
./ai370-optimize.sh stage2-npu-validate [--offline]   # S2-M4 NPU visibility (no 230)
./ai370-optimize.sh stage2-npu-validate --bench [--with-lemonade]
./ai370-optimize.sh stage2-gpu-validate [--offline]   # S2-M3 GPU/Vulkan/ROCm visibility
./ai370-optimize.sh stage2-rag             # Optional RAG (S4-M3; not Stage 3 gate)
./ai370-optimize.sh stage2-lemonade        # Optional Lemonade (S3-M5)
./ai370-optimize.sh stage2-digest          # Optional Digest AI (S3-M4 diagnostics)
./ai370-optimize.sh stage2-models          # S3-M1 layout + storage validate (no downloads)
./ai370-optimize.sh stage3-image           # Requires Stage 1 + Stage 2 runtime/NPU validation gate
./ai370-optimize.sh full-stack --accept-amd-acceleration-risk   # S1 profile + S2 platform + runtime + optional packs + accel + S3 workflows
```

Legacy `tierN` commands and legacy nine-phase commands remain available for
compatibility (see below).

## Legacy Phase Mapping (implementation details)

The roadmap stage model is the primary user-facing structure. Under the hood the
implementation still uses (and you can invoke) the detailed audit-first phases:

- Stage 1 / legacy Tier 1 is now read-only probe + profile. BIOS, kernel,
  GPU/NPU visibility, tuning, and `90-validate.sh` moved to Stage 2 platform
  commands.
- Stage 2 Runtime / legacy Tier 2 covers old Phase 7 (LLM) + AI runtime.
- Stage 2 NPU / legacy Tier 3 covers NPU half of acceleration + ONNX work.
- Stage 3 Image / legacy Tier 5 covers old Phase 8–9 (ComfyUI).

You can still run the classic commands (they continue to work and write the same
rich `reports/latest/` artifacts):

```text
hardware | inventory | audit          -> Stage 1 probe/profile compatibility (10-detect-hardware)
firmware                               -> Stage 2 platform BIOS check (stage2-firmware-validate)
kernel-amd | baseline-apply            -> Stage 2 kernel validate (stage2-kernel-validate)
baseline-plan | plan                   -> Stage 1 probe/profile compatibility
tune                                   -> Stage 2 optimize plan (stage2-optimize-plan)
accel-validate | gpu | npu             -> Stage 2 GPU/NPU visibility
ai-bench | ai-runtime                  -> Stage 3 runtime benchmark compatibility
llm-validate                           -> Stage 2 Runtime / legacy Tier 2
amd-accel-install                      -> Explicit opt-in (used by Stage 2 NPU / Stage 3 image paths)
comfyui-install | comfyui              -> Stage 3 Image / legacy Tier 5 (gated)
comfyui-bench                          -> Stage 3 Image / legacy Tier 5
final-validate | validate              -> Stage 2 platform compatibility aggregate (90-validate.sh)
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
