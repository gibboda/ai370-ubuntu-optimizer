# Tier 1 Validation Summary

**Status:** WARN
Profile: ai370 | Mode: safe

## Acceptance Criteria
- Radeon 890M (gfx1150): WARN (detected: unknown)
- AMDXDNA / XDNA2 NPU: WARN
- Vulkan validated: (see tier1-gpu-stack.json)
- BIOS version (target 2.01 for ai370): unknown (see tier1-firmware.json)
- ROCm: visibility-only at this tier. ROCm visibility is optional at pure Tier 1; explicit installation happens via amd-accel-install after risk acceptance. (rocminfo not in PATH yet)

## Warnings
- Radeon 890M / gfx1150 not detected (saw: unknown). Check amdgpu firmware/kernel.
- AMDXDNA / XDNA2 NPU not detected. Kernel module or device node missing. (Tier 3 is experimental.)

## Next steps
- Run Tier 2 (ai runtime + LLM) and Tier 3 (NPU) before attempting Tier 5 (ComfyUI / generative).
- Use ./ai370-optimize.sh tier1-validate to re-check this gate.
