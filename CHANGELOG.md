# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure
- Tier 1 BIOS target (2.01) detection + bios_acceptable in tier1-firmware.json / tier1-validation.json (M1.1)
- `tests/smoke_tier1.sh` + tests/README.md exercising Tier 1 artifacts, syntax, and acceptance keys including new BIOS field (M1.11)
- Minor NPU "experimental" note in Tier 1 validation warnings (M1.3)
- Profile documentation for EXPECTED_BIOS_VERSION

### Changed
- 20-check-bios.sh, lib/hardware-detect.sh, 90-validate.sh, README Tier 1 acceptance criteria updated for explicit BIOS 2.01 target on ai370 (M1.1 + M1.10/M1.12)
- Tier 2/3: 100-tier2-ai-runtime.sh and 110-tier3-npu-enable.sh expanded from skeletons to produce tierN-validation.json + acceptance (ollama/llama/pytorch/hf for T2; NPU EP/xrt/onnx for T3 experimental). Added tier2-validate + strengthened require_tier123_pass to prefer the new JSONs (M2/M3 + gate).
- Added scripts/lib/tier-gate.sh (initial shared helper placeholder).
- Updated dispatcher USAGE for tier2-validate.

## [0.1.0] — 2026-04-30

### Added
- Initial structure: hardware audit, AMD baseline, AI stack, ROCm/iGPU,
  Ryzen AI NPU, guided acceleration, ComfyUI workflows scripts
- VERSION file and CHANGELOG following Keep a Changelog format

[Unreleased]: https://github.com/gibboda/ai370-ubuntu-optimizer/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/gibboda/ai370-ubuntu-optimizer/releases/tag/v0.1.0
