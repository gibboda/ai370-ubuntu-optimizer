# AI Runtime Benchmark

Profile: ai370  
Mode: safe  
Persistence: runtime  
Offline: false

## ONNX Runtime providers

- AzureExecutionProvider
- CPUExecutionProvider

## Benchmarks

- numpy_matmul_256: median 0.000147 seconds
- numpy_matmul_512: median 0.000736 seconds
- onnxruntime_cpu_identity: median 0.000004 seconds
