# NPU Acceleration Track

Profile: ai370
Mode: safe
Persistence: runtime
Offline: false

## Detected state

- kernel module: loaded
- device node: present
- runtime tools: not-installed
- ONNX Runtime providers: AzureExecutionProvider,CPUExecutionProvider

## Policy

This track detects AMD XDNA2 NPU presence and locally installed runtime/provider visibility without fetching proprietary runtimes.

## Recommendations

- Stage AMD Ryzen AI runtime tools in your approved offline artifacts before attempting NPU workloads.
- Keep SAFE mode until NPU inference is validated.
