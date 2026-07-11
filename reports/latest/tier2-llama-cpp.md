# Tier 2 llama.cpp Status

Profile: ai370 | Mode: safe | Offline: false
Status: WARN

- Binary: /home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/tools/llama.cpp/build/bin/llama-cli
- Install action: validated-existing-binary
- Backend requested: hip
- Backend effective: hip
- Built backends detected: cpu
- AMDGPU targets: gfx1150
- Force rebuild: false

```text
version: 1 (86b9470)
built with GNU 15.2.0 for Linux x86_64
```

Existing llama.cpp binary appears to lack backend 'hip' (detected: cpu). Rebuild with LLAMA_CPP_FORCE_REBUILD=true LLAMA_CPP_BACKEND=hip for GPU acceleration on gfx1150.

Rebuild with GPU (example):
`LLAMA_CPP_FORCE_REBUILD=true LLAMA_CPP_BACKEND=hip ./scripts/110-install-llama-cpp.sh ai370 safe runtime`
