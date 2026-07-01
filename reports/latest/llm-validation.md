# Ollama / llama.cpp Validation

Profile: ai370
Mode: safe
Persistence: runtime
Offline: false
Status: WARN

## Ollama

- State: missing

```text
command-not-found: ollama
```

## Ollama local models

```text
command-not-found: ollama
```

## llama.cpp

- State: missing
- Binary: not-found

```text
not-run
```

## Local GGUF models

```text
none
```

## Tier 2 Runtime

- PyTorch: missing (ROCm: false)
- Open WebUI: missing (not-found)
- Local inference smoke: skipped

## Policy

This phase validates locally available Ollama, llama.cpp, PyTorch, and Open WebUI assets. It does not download models or pull Ollama manifests.
