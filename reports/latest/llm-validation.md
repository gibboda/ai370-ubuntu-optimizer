# Ollama / llama.cpp Validation

Profile: ai370
Mode: safe
Persistence: runtime
Offline: false
Status: PASS

## Ollama

- State: available

```text
ollama version is 0.30.11
Warning: client version is 0.31.1
```

## Ollama local models

```text
NAME                       ID              SIZE      MODIFIED          
deepseek-coder:6.7b        ce298d984115    3.8 GB    About an hour ago    
llama3.1:8b                46e0c10c039e    4.9 GB    2 days ago           
nomic-embed-text:latest    0a109f422b47    274 MB    2 days ago           
qwen2.5-coder:1.5b-base    02e0f2817a89    986 MB    2 days ago           
qwen2.5-coder:latest       dae161e27b0e    4.7 GB    2 days ago           
qwen2.5-coder:14b          9ec8897f747e    9.0 GB    5 days ago           
qwen2.5-coder:7b           dae161e27b0e    4.7 GB    5 days ago           
qwen2.5-coder:1.5b         d7372fd82851    986 MB    5 days ago           
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

## Tier 2 Runtime

- PyTorch: available (ROCm: true)
- Open WebUI: missing (not-found)
- Local inference smoke: available-not-run

## Policy

This phase validates locally available Ollama, llama.cpp, PyTorch, and Open WebUI assets. It does not download models or pull Ollama manifests.
