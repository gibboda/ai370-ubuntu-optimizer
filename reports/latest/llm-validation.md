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

## Policy

This phase validates locally available Ollama and llama.cpp assets only. It does not download models, pull Ollama manifests, clone llama.cpp, or install runtime packages.
