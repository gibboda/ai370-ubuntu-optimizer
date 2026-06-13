# AI Stack Recommendations

Profile: ai370
Mode: safe
Persistence: runtime
Offline: false

## Current acceleration visibility

- amdgpu: missing
- Vulkan: visible
- OpenCL: visible
- NPU/XDNA: visible
- ROCm/HIP: visible
- ONNX Runtime providers: AzureExecutionProvider,CPUExecutionProvider

## Offline policy

Phase 6 prepares a local AI Python environment, validates CPU ONNX Runtime execution, and records acceleration visibility.
When --offline is used, packages come from the configured wheelhouse.
If the wheelhouse is missing, this phase can continue only when the existing venv already satisfies the configured offline requirements.
This phase does not force ROCm installation for the integrated Radeon 890M iGPU and does not install proprietary AMD Ryzen AI binaries.

## Next actions

- Review `/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/reports/latest/ai-runtime-benchmark.md` before GPU/NPU optimization.
- Run Phase 5 acceleration validation to capture local hardware capability reports.
