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

- Total: 914.8 GiB
- Free: 704.2 GiB
- Minimum required: 20.0 GiB
- NVMe confirmed: yes

## Model inventory

| ID | Category | Runtime | Required | Present | Status |
| --- | --- | --- | --- | --- | --- |
| chat-gguf-local | chat | llama.cpp | false | false | WARN |
| coding-ollama-local | coding | ollama | false | false | WARN |
| embedding-local | embedding | sentence-transformers | false | true | PASS |

## Diagnostics

- WARN: chat-gguf-local: model artifact is not present locally
- WARN: coding-ollama-local: model artifact is not present locally

## Offline behavior

This validation reads local metadata and files only. It does not download, pull, clone, delete, overwrite, or move model artifacts.
