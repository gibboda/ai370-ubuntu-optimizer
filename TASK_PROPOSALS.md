# Codebase Task Proposals

This document is a **compatibility backlog**. Canonical Stage/Milestone
ownership, status, and planned work live in [`docs/ROADMAP.md`](docs/ROADMAP.md).
Do not add new Tier-named tasks, scripts, reports, or documentation sections
here. Compatibility names such as `require_tier123_pass` and `smoke_tier1.sh`
remain until their ROADMAP removal targets.

The items below restate still-open follow-ups in Stage/Milestone language.

## Stage alignment follow-ups

- Complete S3-M2 and S3-M4 explicit scripts (Ollama/llama.cpp installers, ONNX
  Runtime + NPU EP install + dedicated benchmark) instead of delegating to
  legacy 20/80/40.
- Add canonical S3-M7 `s3-m7-runtime-validation.json` so
  `require_tier123_pass` can consume Stage 3 reports instead of
  `tier2-validation.json` / `tier3-validation.json`.
- Keep S2-M7 (`s2-m7-platform-validation.json`, with `90-validate.sh` as the
  compatibility shim) as the platform-gate source of truth.
- Improve `80-benchmark-local-ai.sh` and `comfyui-benchmark.sh` to perform
  real (non-placeholder) execution where a runtime is present (S3-M6 / S4-M2).
- Replace `scripts/legacy/tier-gate.sh` with the S4-M7 consumer gate that
  reads canonical S2-M7 and S3-M7 reports.

## Remaining application and tuning work

- **Live ComfyUI benchmark (S4-M2):** `scripts/comfyui-benchmark.sh` still uses
  synthetic placeholder timings. Replace with real ComfyUI API submission +
  measured trials.
- **Persistent tuning (S2-M6):** `40-platform-tuning.sh` apply is approved
  runtime-only. Add opt-in persistent apply with rollback manifests. Keep
  S2-M5/S2-M6 **In progress** until that exit evidence exists.
- **LLM smoke benchmark (S3-M6):** Stage 3 runtime validation should add
  token-generation rate measurements for staged GGUF / Ollama models.
- **S2-M1 remediation docs and S2-M2 kernel/driver matrix:** Canonical JSON
  exists; keep those milestones **In progress** until the ROADMAP exit
  evidence exists.

## Historical notes (compatibility coverage)

- `tests/smoke_tier1.sh` still exercises non-mutating Stage 1 profile
  publication and compatibility `tier1-*.json` artifacts. Owner-specific
  `tests/test_s1_*` and `tests/test_s2_*` suites are the portable authority.
- `tests/smoke_tier2.sh` remains Stage 3 runtime compatibility coverage until
  `test_s3_*` suites exist.
