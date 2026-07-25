# Stable Diffusion WebUI Forge Codebase Review

**Review date:** 2026-07-25

## Executive summary

The repository does **not** currently install, configure, launch, validate, or
benchmark Stable Diffusion WebUI Forge. Forge is a distinct image-generation
frontend and runtime integration; neither the Open WebUI LLM frontend nor the
repository's partial ComfyUI work constitutes Forge support.

The current image-generation architecture is centered on ComfyUI and remains
partial. The active `scripts/70-comfyui-workflows.sh` implementation creates a
local checkout, virtual environment, model directories, and launcher, while
the numbered Stage 3 installer, image-model manifest, and lifecycle commands
remain planned. Adding Forge before those shared foundations are complete
would duplicate source management, Python environments, model storage,
acceleration gating, and reporting logic.

## Review scope

The review searched tracked product code and documentation for the following
integration surfaces:

- Forge, Stable Diffusion WebUI Forge, and common repository-name spellings;
- installer, launcher, lifecycle, and validation scripts;
- the top-level command dispatcher and Stage 3 gate;
- offline model manifests and storage policy;
- AMD/ROCm acceleration checks and Python environment validation;
- image-generation tests, workflows, reports, README content, and roadmap
  milestones.

Generated reports, dependency lock data, and the tracked-files backup listing
were not treated as implementation evidence.

## Findings

### FORGE-01 — No Forge integration is present (high)

Prior to this review, no tracked product code or documentation identified
Stable Diffusion WebUI Forge. There was no supported install path, top-level
command, generated launcher, health check, status artifact, benchmark, or
update/uninstall policy for Forge.

The repository's Open WebUI integration is an LLM frontend. The existing
ComfyUI script and workflows target a different image-generation application.
Neither can be used as evidence that Forge is installed or compatible.

**Recommendation:** Describe Forge as unsupported until an explicit Stage 3
milestone is approved. Use `forge` or `sd-webui-forge` consistently in command
names, paths, and report keys, and avoid the ambiguous name `webui`.

### FORGE-02 — Forge must not be treated as an AUTOMATIC1111 drop-in (high)

Forge shares concepts and user-facing conventions with AUTOMATIC1111, but it
has its own source tree, dependency set, launch behavior, optimizations, and
compatibility surface. The repository has no AUTOMATIC1111 implementation to
reuse today, and a future implementation must not assume that launch flags,
extensions, environment constraints, or validation results transfer unchanged
between the two applications.

**Recommendation:** Give Forge a separately pinned revision, isolated virtual
environment, launcher contract, compatibility inventory, and status report.
Share only repository-owned helpers whose behavior is application-neutral,
such as model-path resolution and AMD device evidence collection.

### FORGE-03 — Shared Stage 3 model foundations are missing (high)

The roadmap still lists `scripts/400-install-comfyui.sh`,
`scripts/410-install-comfyui-models.sh`, and
`configs/models/comfyui-models.yaml` as planned. The current ComfyUI script
creates image-model directories directly, while the main model manifest only
covers chat, coding, embedding, and Lemonade assets.

A direct Forge installer would create another source of truth for checkpoints,
VAEs, LoRAs, ControlNet assets, text encoders, upscalers, output paths,
checksums, and storage-capacity checks.

**Recommendation:** Implement a UI-neutral image-model manifest and offline
validator first. ComfyUI, Forge, and any future image frontend should reference
the same canonical model directories through explicit configuration or
symlinks rather than copying model trees.

### FORGE-04 — AMD acceleration needs Forge-local proof (high)

The current ComfyUI launcher enables GPU mode only when host artifacts report
visible ROCm and the ComfyUI virtual environment contains a HIP-enabled PyTorch
build. There is no equivalent Forge environment probe, inference smoke, or
silent CPU-fallback detector. Host-level ROCm visibility alone cannot prove
that Forge's Python environment can execute on the GPU.

**Recommendation:** Validate the exact Python and PyTorch versions installed
for the pinned Forge revision, `torch.version.hip`, device visibility, a small
deterministic generation, and the execution device reported during that run.
Default to a CPU-safe or explicitly unsupported state until this evidence
passes; do not infer support from the ComfyUI environment.

### FORGE-05 — Reproducible offline installation is undefined (medium)

The repository defines offline validation and model-storage expectations, but
it has no pinned Forge source revision, wheelhouse, integrity manifest, or
policy for optional extensions. A live clone followed by dependency or
extension auto-installation would not satisfy reproducible offline operation.

**Recommendation:** Separate online acquisition from offline installation,
pin and record the Forge revision and dependency artifacts, verify staged
content before installation, and reject missing artifacts in offline mode.
Treat extensions as individually pinned optional components and keep extension
installation disabled by default.

### FORGE-06 — Security and service lifecycle contracts are absent (medium)

No Forge-specific policy defines bind address, authentication, API exposure,
process ownership, logs, start/stop/status behavior, or generated-file
permissions. Reusing generic WebUI terminology could also route lifecycle
commands to the wrong application as more frontends are added.

**Recommendation:** Bind to loopback by default, make remote exposure an
explicit opt-in with documented authentication requirements, and give Forge
dedicated start, stop, status, and health commands. Record the bind mode and
API state in its status artifact without storing credentials.

### FORGE-07 — No test or reporting contract exists (medium)

Current smoke tests do not syntax-check or exercise a Forge path, and the
report layout defines no Forge artifact. A future installer could regress
without affecting existing Stage 3 checks.

**Recommendation:** Define a machine-local JSON report such as
`reports/latest/forge-status.json` containing install state, pinned revision,
Python and PyTorch versions, HIP/device evidence, launch and bind modes, model
root, API state, and offline readiness. Add non-network smoke coverage for
argument parsing, offline refusal, model-path generation, CPU fallback,
loopback binding, and report shape.

## Proposed implementation boundary

Forge should be an **optional Stage 3 image-generation frontend**, not a Stage
2 runtime, not an alias for AUTOMATIC1111, and not a replacement name for
ComfyUI. A future implementation should be split into reviewable units:

1. Complete a shared image-model manifest, staging flow, and offline integrity
   validator.
2. Extract UI-neutral AMD/PyTorch device validation from the ComfyUI path.
3. Add a pinned, idempotent Forge installer with separate online acquisition
   and offline installation modes.
4. Add loopback-first start, stop, status, and health commands.
5. Add a deterministic API generation smoke and benchmark that detect CPU
   fallback and record the execution device.
6. Add report integration, documentation, and non-network smoke tests.
7. Evaluate extensions individually against the pinned Forge revision; do not
   inherit an AUTOMATIC1111 compatibility claim.

Until these pieces are present, the project should make no Forge compatibility,
offline-readiness, or AMD acceleration claim.

## Conclusion

The codebase has reusable hardware detection, stage gating, offline-policy
concepts, and a conservative ComfyUI acceleration gate, but it has no Forge
implementation. The safest path is to complete and generalize the Stage 3
image-model and device-validation foundations, then add Forge as an isolated,
pinned optional frontend with its own lifecycle and evidence contract.
