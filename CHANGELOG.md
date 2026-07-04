<!-- markdownlint-disable MD013 MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Optimization Roadmap & Project Tooling**:
  - Comprehensive Roadmap ([ROADMAP.md](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/docs/ROADMAP.md)) outlining project milestones, targets, and goals (#34, #35, #49).
  - ShellCheck workflow (`.github/workflows/shellcheck.yml`) for automated shell script validation (#29).
  - Conventional Commits linter and audit script to enforce project commit standards (#11, #45).
  - Snyk configuration for automated security scans (#37, #38).
  - Recommended VS Code workspace configuration (`.vscode/settings.json`, `.vscode/extensions.json`) (#32).
- **Stage 1 (Hardware & Firmware Validation)**:
  - Stage 1 firmware check script ([25-check-firmware.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/25-check-firmware.sh)) and stage 1 firmware validation status report (#39).
  - BIOS target detection for version 2.01 on AI370, writing status to validation reports (#22, #41).
  - Integrated Tier 1 validation, benchmarking, and detection scripts with the core flow (#26, #27).
  - Test harness ([smoke_tier1.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/tests/smoke_tier1.sh)) and verification suite ([README.md](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/tests/README.md)) (#26).
- **Stage 2 (Local AI Stack)**:
  - Installer/validator scripts for llama.cpp ([110-install-llama-cpp.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/110-install-llama-cpp.sh)), ollama ([120-install-ollama.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/120-install-ollama.sh)), Open WebUI ([130-install-open-webui.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/130-install-open-webui.sh)), and PyTorch ROCm ([100-install-pytorch-rocm.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/100-install-pytorch-rocm.sh)) (#30).
  - Status reports for AnythingLLM ([300-install-anythingllm.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/300-install-anythingllm.sh)), RAG validation ([320-validate-rag.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/320-validate-rag.sh)), and embedding models ([310-install-embedding-models.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/310-install-embedding-models.sh)) (#68).
  - Offline model storage policy validator and model manifest manager ([150-validate-offline-model-storage.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/150-validate-offline-model-storage.sh)) (#52).
- **Stage 3 (NPU & Acceleration)**:
  - AMD Acceleration environment script ([amd-acceleration-env.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/scripts/amd-acceleration-env.sh)) and tracked files backup registry (#74).
  - Vitis AI Execution Provider, XDNA2 NPU detection, ONNX Runtime status integration, and benchmarks (#66).

### Changed

- **Orchestration Reorganization**:
  - Reorganized optimizer orchestrator ([ai370-optimize.sh](file:///home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/ai370-optimize.sh)) into a structured 9-phase audit-first flow (firmware, hardware, CPU, memory, storage, tuning, local AI, NPU, benchmarks) (#15).
  - Deprecated legacy scripts and archived them in `scripts/legacy/`.
  - Introduced `stage` commands in the orchestrator interface while maintaining legacy `tier` aliases for backward compatibility (#54).
- **Reports & Validation Output**:
  - Enhanced firmware and hardware detection scripts to output precise reports with accurate BIOS, system information, storage summaries, and validation statuses (#58, #63, #64, #66, #67, #70, #71, #72, #75).
  - Normalized validation timestamps across reports to use standard ISO 8601 UTC (Z) format.
  - Pinned `venv` packages and included installed package lists in validation status reports (#69).
- **Environments & Compatibility**:
  - Configured Open WebUI to use a dedicated Python virtual environment (`venv`) with a fail-safe bootstrap fallback (#60).
  - Updated PyTorch ROCm installer to purge the pip cache and use nightly wheels for Python 3.14+ compatibility (#56).

### Fixed

- **OS Detection & Platform Fallbacks**:
  - Fixed OS detection fallback logic in hardware reporting scripts (#10).
- **Dependencies & Packages**:
  - Addressed missing optional PyTorch companion wheels (#55).
- **Benchmark & Execution Issues**:
  - Integrated ComfyUI GPU-launch benchmarks, addressing offline bench reuse errors on existing virtual environments (#9, #17, #18).
  - Refined validation and reporting logic to tolerate missing optional onnxruntime packages in NPU validation (#16).

## [0.1.0] — 2026-04-30

### Added

- Initial structure: hardware audit, AMD baseline, AI stack, ROCm/iGPU,
  Ryzen AI NPU, guided acceleration, ComfyUI workflows scripts
- VERSION file and CHANGELOG following Keep a Changelog format

[Unreleased]: https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/gibboda/ai370-ubuntu-optimizer/releases/tag/v0.1.0
