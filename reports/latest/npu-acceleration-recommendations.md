# NPU Acceleration Track

Profile: ai370
Mode: safe
Persistence: runtime
Offline: false

## Detected state

- kernel module: loaded
- device node: present
- runtime tools: available
- ONNX Runtime venv: /home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/ryzen-ai/venv/bin/python (ryzen-ai)
- ONNX Runtime providers: VitisAIExecutionProvider,CPUExecutionProvider

## Policy

This track detects AMD XDNA2 NPU presence and locally installed runtime/provider visibility without fetching proprietary runtimes.
Provider checks prefer `.ai370-ai/ryzen-ai/venv` (AMD install) over stock `.ai370-ai/venv` (CPU onnxruntime).

## Recommendations

- Keep SAFE mode until NPU inference is validated.
