# Offline Model Storage Validation

Status: WARN
Profile: ai370
Mode: safe
Persistence: runtime
Offline: false
Manifest: `configs/models/manifest.yaml`
Policy: `configs/models/storage-policy.md`
Model root: `.ai370-ai/models`

## Storage

- Total: 62.4 GiB
- Free: 28.4 GiB
- Minimum required: 20.0 GiB
- NVMe confirmed: no

## Model inventory

| ID | Category | Runtime | Required | Present | Status |
| --- | --- | --- | --- | --- | --- |
| chat-gguf-local | chat | llama.cpp | false | false | WARN |
| coding-ollama-local | coding | ollama | false | false | WARN |
| embedding-local | embedding | sentence-transformers | false | false | WARN |

## Diagnostics

- WARN: NVMe backing could not be confirmed for the model root; verify placement before importing large models
- WARN: chat-gguf-local: model artifact is not present locally
- WARN: coding-ollama-local: model artifact is not present locally
- WARN: embedding-local: model artifact is not present locally

## Offline behavior

This validation reads local metadata and files only. It does not download, pull, clone, delete, overwrite, or move model artifacts.
