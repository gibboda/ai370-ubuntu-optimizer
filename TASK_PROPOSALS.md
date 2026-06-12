# Codebase Task Proposals

This document captures concrete follow-up tasks after aligning the toolkit to the **AI Stack Tier Architecture** (Tier 1–5) while preserving the existing high-quality reporting, profile, offline, and gate machinery.

## Tier alignment follow-ups (new)

- Complete Tier 2 and Tier 3 explicit scripts (ollama/llama.cpp installers, ONNX Runtime + NPU EP install + dedicated benchmark) instead of delegating to legacy 20/80/40.
- Add a `tier2-validation.json` and `tier3-validation.json` writer so the `require_tier123_pass` gate becomes stricter and more observable.
- Make the Tier 1 90-validate.sh (and future tierN-validate) the single source of truth for the cross-tier gate.
- Improve 80-benchmark-local-ai.sh and the old comfyui-benchmark.sh to perform real (non-placeholder) execution where a runtime is present.
- Add a small `scripts/lib/tier-gate.sh` helper that can be sourced by any tier5 or full-stack path.

## Legacy items (still relevant)

- **Live ComfyUI benchmark task**: `scripts/comfyui-benchmark.sh` still uses synthetic placeholder timings. Replace with real ComfyUI API submission + measured trials (Tier 5).
- **Persistent tuning**: Phase 4 / Tier 1 CPU+memory+storage scripts intentionally stay runtime-only. Add opt-in system-level persistent path with rollback manifests.
- **LLM smoke benchmark**: Tier 2 (and legacy Phase 7) should add token-generation rate measurements for staged GGUF / Ollama models.
- **Lightweight tests**: Add `tests/smoke_tier1.sh` that exercises `./ai370-optimize.sh tier1 --dry-run` (or non-mutating parts) and asserts key `reports/latest/tier1-*.json` files exist.

## 1) Live ComfyUI benchmark task

- **Issue**: `scripts/comfyui-benchmark.sh` still uses synthetic placeholder timings instead of live ComfyUI queue/API execution.
- **Task**: Replace placeholder `run_case` timings with API-driven workflow submission, warmup runs, measured trials, and failure capture.
- **Why it matters**: Phase 9 should report real wall-clock workflow performance before it is used for hardware comparisons.

## 2) Persistent tuning task

- **Issue**: Phase 4 intentionally generates runtime-only CPU/RAM/storage recommendations and reviewable commands.
- **Task**: Add an explicitly opt-in persistent tuning mode for CPU governor policy, zram/swap settings, NVMe policy, and reversible rollback manifests.
- **Why it matters**: Users who want durable tuning need a safe, auditable path that does not silently mutate system configuration.

## 3) LLM smoke benchmark task

- **Issue**: Phase 7 validates local Ollama/llama.cpp/GGUF visibility but does not run token-generation benchmarks yet.
- **Task**: Add opt-in local-only smoke benchmarks for installed Ollama models and staged llama.cpp GGUF models, recording tokens/sec and load time.
- **Why it matters**: Ollama/llama.cpp validation should eventually prove both runtime visibility and useful local inference behavior.

## 4) Test improvement task

- **Issue**: There are no automated checks validating generated scripts and report artifacts.
- **Task**: Add a lightweight shell test (e.g., `tests/smoke_generation.sh`) that runs non-invasive phases and asserts key files are produced (`reports/latest/*.txt`, plan markdown, generated step scripts) with expected executable bits.
- **Why it matters**: Prevents regressions in script generation paths and catches quoting/path bugs early.
