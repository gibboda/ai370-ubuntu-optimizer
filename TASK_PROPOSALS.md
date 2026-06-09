# Codebase Task Proposals

This document captures concrete follow-up tasks after reorganizing the toolkit around the nine requested phases.

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
