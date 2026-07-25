# AUTOMATIC1111 WebUI Codebase Review

**Review date:** 2026-07-25

## Executive summary

The repository does **not** currently install, configure, launch, validate, or
benchmark AUTOMATIC1111's Stable Diffusion WebUI. The similarly named Open
WebUI integration is an LLM user interface and must not be interpreted as
AUTOMATIC1111 support.

Image generation is currently designed around ComfyUI. That work is itself
partial: the active `scripts/70-comfyui-workflows.sh` implementation and the
benchmark/workflow assets exist, while the numbered Stage 3 installer, model
manifest, and lifecycle commands remain planned. Adding a second image UI
before those shared Stage 3 foundations exist would duplicate installation,
model storage, acceleration gating, and reporting logic.

## Review scope

The review searched the tracked codebase for the following integration
surfaces:

- AUTOMATIC1111 and Stable Diffusion WebUI names and common spellings;
- installer, launcher, lifecycle, and validation scripts;
- the top-level command dispatcher;
- offline model manifests and storage policy;
- AMD/ROCm acceleration gates;
- image-generation tests, workflows, reports, README content, and roadmap
  milestones.

Generated files, dependency lock data, and the tracked-files backup listing
were not treated as implementation evidence.

## Findings

### A1111-01 — No AUTOMATIC1111 integration is present (high)

No tracked product code or documentation identifies AUTOMATIC1111 or Stable
Diffusion WebUI. There is consequently no supported install path, top-level
command, generated launcher, health check, version report, or uninstall/update
policy for it.

The existing `scripts/130-install-open-webui.sh` is unrelated. It installs the
Open WebUI LLM frontend and reports `tier2-open-webui.*`; its presence does not
satisfy any AUTOMATIC1111 requirement.

**Recommendation:** Describe AUTOMATIC1111 as unsupported until an explicit
Stage 3 milestone is approved. If support is added, use unambiguous names such
as `automatic1111` in commands and report keys; never shorten it to `webui`.

### A1111-02 — Shared Stage 3 prerequisites are not implemented (high)

The authoritative roadmap still lists `scripts/400-install-comfyui.sh` and
`scripts/410-install-comfyui-models.sh` as planned. The current image-generation
model folders are created by `scripts/70-comfyui-workflows.sh` rather than by a
UI-neutral image-model manager. The main model manifest only covers chat,
coding, embedding, and Lemonade assets.

Implementing AUTOMATIC1111 directly would therefore create a second source of
truth for checkpoints, VAEs, LoRAs, ControlNet models, output paths, checksums,
and capacity checks.

**Recommendation:** First implement a UI-neutral Stage 3 image-model manifest
and validator. Both ComfyUI and AUTOMATIC1111 should consume the same canonical
directories. AUTOMATIC1111's expected model directories should be symlinks or
configuration references, not copied model trees.

### A1111-03 — Acceleration validation cannot be assumed portable (high)

The current ComfyUI launcher enables GPU mode only after the AMD acceleration
artifact reports visible ROCm and the ComfyUI virtual environment confirms a
HIP-enabled PyTorch build. AUTOMATIC1111 has no equivalent environment-specific
probe. Reusing only the host-level ROCm result would permit silent CPU fallback
or a launcher failure caused by a mismatched Python/PyTorch environment.

**Recommendation:** Give AUTOMATIC1111 an isolated virtual environment and
validate `torch.version.hip`, device visibility, a small inference execution,
and the reported execution device inside that environment. Default to the same
CPU-safe behavior as ComfyUI, and require the existing explicit acceleration
risk acknowledgement before removing CPU-safe launch arguments.

### A1111-04 — Offline and supply-chain behavior is undefined (medium)

Repository policy requires offline validation not to fetch model artifacts,
but no AUTOMATIC1111 source revision, wheelhouse, extension inventory, or
offline artifact layout is defined. A live clone plus extension auto-install
would not provide the repository's intended reproducibility or offline
operation.

**Recommendation:** Pin the application revision, record it in the status
report, separate online acquisition from offline installation, and reject
unstaged dependencies in offline mode. Treat extensions as separately pinned
optional components; do not enable extension installation by default.

### A1111-05 — No test or reporting contract exists (medium)

The smoke tests do not syntax-check or exercise an AUTOMATIC1111 path, and the
report index has no AUTOMATIC1111 artifact contract. A future installer could
regress without affecting existing stage gates.

**Recommendation:** Define a JSON report such as
`reports/latest/automatic1111-status.json` containing install state, pinned
revision, Python and PyTorch versions, HIP/device evidence, launch mode, model
path, and offline readiness. Add non-network smoke coverage for argument
parsing, offline refusal, model-path generation, CPU fallback, and report
shape.

## Proposed implementation boundary

AUTOMATIC1111 should be an **optional Stage 3 image-generation frontend**, not
a Stage 2 runtime and not an alias for ComfyUI. A future change should be split
into reviewable units:

1. Complete the shared image-model manifest, staging, and offline integrity
   validation.
2. Extract reusable Stage 3 AMD/PyTorch device validation from the ComfyUI
   path.
3. Add a pinned, idempotent AUTOMATIC1111 installer with online and offline
   acquisition modes.
4. Add start, stop, status, and health commands bound to loopback by default.
5. Add a deterministic API smoke and benchmark that detects CPU fallback.
6. Add report-index integration, documentation, and smoke tests.

Until all six pieces are present, the project should make no compatibility or
acceleration claim for AUTOMATIC1111.

## Conclusion

The codebase has reusable platform detection, offline-policy concepts, and a
conservative ComfyUI acceleration gate, but it has no AUTOMATIC1111
implementation today. The safest path is to finish and generalize the planned
Stage 3 foundations before adding AUTOMATIC1111 as an optional frontend.
