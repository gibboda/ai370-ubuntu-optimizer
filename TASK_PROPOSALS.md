# Codebase Task Proposals

This document captures four concrete follow-up tasks identified during a quick audit.

## 1) Typo fix task

- **Issue**: In `scripts/60-acceleration-execution.sh`, the generated warning says `Run Phase 4 first.` when the phase numbering in `README.md` labels AI Runtime as **Phase 5**.
- **Task**: Update the warning message in the generated NPU checklist to reference the correct phase (or avoid hard-coded phase numbers).
- **Why it matters**: Users may run the wrong setup step based on incorrect guidance.

## 2) Bug fix task

- **Issue**: The generated `reports/latest/npu-enable-approved-steps.sh` script checks for `.ai370-ai/venv/bin/python` using a relative path.
- **Task**: Make the generated script resolve and use an absolute path anchored to the repository root (or script directory), similar to other scripts in this repository.
- **Why it matters**: Running the checklist outside the repo root can produce false negatives even when the environment exists.

## 3) Documentation discrepancy task

- **Issue**: The root `README.md` describes this repository as including **"Prebuilt ComfyUI workflow templates"** without linking to `workflows/comfyui/README.md`, which already clarifies these are starter/model-agnostic templates that may require model filename adjustments. The root README wording alone can mislead users into treating them as drop-in production templates.
- **Task**: Clarify wording in `README.md` (e.g., "sample workflows") and add a short compatibility note linking to `workflows/comfyui/README.md`.
- **Why it matters**: Reduces risk that users treat examples as drop-in production templates for all models.

## 4) Test improvement task

- **Issue**: There are no automated checks validating generated scripts and report artifacts.
- **Task**: Add a lightweight shell test (e.g., `tests/smoke_generation.sh`) that runs phase scripts in a temp directory and asserts key files are produced (`reports/latest/*.txt`, plan markdown, generated step scripts) with expected executable bits.
- **Why it matters**: Prevents regressions in script generation paths and catches quoting/path bugs early.
