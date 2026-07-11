# Ollama / llama.cpp Validation

Profile: ai370
Mode: safe
Persistence: runtime
Offline: false
Status: PASS

## Ollama

- State: available

```text
ollama version is 0.31.1
```

## Ollama local models

```text
NAME                       ID              SIZE      MODIFIED    
deepseek-coder:6.7b        ce298d984115    3.8 GB    8 days ago     
llama3.1:8b                46e0c10c039e    4.9 GB    10 days ago    
nomic-embed-text:latest    0a109f422b47    274 MB    10 days ago    
qwen2.5-coder:1.5b-base    02e0f2817a89    986 MB    10 days ago    
qwen2.5-coder:latest       dae161e27b0e    4.7 GB    10 days ago    
qwen2.5-coder:14b          9ec8897f747e    9.0 GB    2 weeks ago    
qwen2.5-coder:7b           dae161e27b0e    4.7 GB    2 weeks ago    
qwen2.5-coder:1.5b         d7372fd82851    986 MB    2 weeks ago    
```

## llama.cpp

- State: available
- Binary: /home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/tools/llama.cpp/build/bin/llama-cli

```text
version: 1 (86b9470)
built with GNU 15.2.0 for Linux x86_64
```

## Local GGUF models

```text
none
```

## Measured smoke

- Result: pass
- Backend: ollama
- Model: deepseek-coder:6.7b
- load_time_ms: 49.365
- tokens_generated: 16
- tokens_per_sec: 21.723
- wall_time_ms: 912.389
- eval_time_ms: 736.534
- Detail: ollama /api/generate smoke completed with metrics

## Tier 2 Runtime

- PyTorch: available (ROCm: true)
- Open WebUI: available (venv:/home/gibboda/Documents/Projects/ai370-ubuntu-optimizer/.ai370-ai/open-webui-venv)

## Policy

This phase validates locally available Ollama, llama.cpp, PyTorch, and Open WebUI assets.
It does not download models. When a local model is present it runs a short measured smoke
and records load_time_ms and tokens_per_sec when the backend exposes them.
