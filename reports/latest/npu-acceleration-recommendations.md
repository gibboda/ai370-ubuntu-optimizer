# NPU Acceleration Track

Profile: ai370
Mode: safe
Persistence: runtime
Offline: false

## Detected state

- kernel module: missing
- device node: missing
- runtime tools: not-installed
- ONNX Runtime providers: CoreMLExecutionProvider,AzureExecutionProvider,CPUExecutionProvider

## Policy

This track detects AMD XDNA2 NPU presence and locally installed runtime/provider visibility without fetching proprietary runtimes.

## Recommendations

- Kernel module not loaded; ensure your kernel supports AMD XDNA.
- No NPU device nodes detected; firmware or kernel support may be missing.
- Stage AMD Ryzen AI runtime tools in your approved offline artifacts before attempting NPU workloads.
- Keep SAFE mode until NPU inference is validated.
