# Offline Model Storage Policy

## Purpose

S2-M5 defines the local model inventory and validation rules for offline AI
operation. The policy keeps model metadata in `configs/models/manifest.yaml` and
expects validation to run without network access.

## Canonical storage layout

The canonical model root is `.ai370-ai/models`, matching the runtime artifact
layout used by the local AI scripts. Model artifacts should be grouped by use
case:

- `.ai370-ai/models/chat/` for general chat/instruction models.
- `.ai370-ai/models/coding/` for code-assistant models.
- `.ai370-ai/models/embedding/` for embedding and RAG models.
- `.ai370-ai/models/lemonade/` for Lemonade Server GGUF/ONNX-compatible artifacts.
- `.ai370-ai/models/rag/` for document-specific model artifacts when needed.
- `.ai370-ai/models/staging/` for temporary imports before checksum validation.
- `.ai370-ai/offline-artifacts/embedding/` for offline-staged embedding model
  trees consumed by `scripts/310-install-embedding-models.sh`.
- `.ai370-ai/offline-artifacts/anythingllm/` for Docker image tarballs or
  AppImages consumed by `scripts/300-install-anythingllm.sh`.
- `.ai370-ai/offline-artifacts/lemonade/` for Lemonade wheel/staging packs.
- `.ai370-ai/offline-artifacts/digestai/` for optional Digest AI source (Python 3.9–3.10).
- `.ai370-ai/rag/documents/` for local documents to ingest offline.
- `.ai370-ai/rag/anythingllm-storage/` for AnythingLLM container volume data.

## Staging workflow (Package D)

```bash
# Create layout + README stubs only (never downloads weights):
./ai370-optimize.sh stage2-models
# or:
./scripts/155-stage-model-layout.sh

# Copy GGUF/ONNX/embedding trees into the paths listed in manifest.yaml,
# or pull Ollama tags when online, then re-validate:
./scripts/150-validate-offline-model-storage.sh

# Optional full-stack smokes (not Stage 3 gate):
LEMONADE_START=true ./scripts/165-validate-lemonade.sh
ANYTHINGLLM_START=true ./scripts/300-install-anythingllm.sh
```

## Manifest requirements

Each manifest entry must include:

- `id`: stable unique identifier.
- `name`: human-readable model name.
- `category`: one of `chat`, `coding`, or `embedding`.
- `runtime`: expected runtime, such as `llama.cpp`, `ollama`, `lemonade`,
  `onnxruntime`, or `sentence-transformers`.
- `format`: artifact format, such as `gguf`, `ollama`, `directory`, or `onnx`.
- `path`: local storage path under the canonical model root, unless the runtime
  explicitly manages storage elsewhere and the exception is documented.
- `required`: whether validation must fail when the artifact is missing.
- `checksum`: local integrity metadata with `algorithm` and `value` fields.
- `min_free_gb`: free-space requirement to check before staging or importing the
  model.

## Offline and integrity rules

- Validation must not download, pull, clone, or otherwise fetch model artifacts.
- Missing optional models should produce `WARN` with actionable instructions.
- Missing required models must produce `FAIL`.
- `sha256` checksums must be verified locally when a checksum value is provided.
- Checksum values may be `null` while a model is only planned; that state should
  produce `WARN` for existing file artifacts and remain actionable.
- The validator must never delete, overwrite, or move user model files.

## Storage rules

- The model root must exist or be created by validation.
- Free capacity must satisfy the manifest-level `minimum_free_gb` and each
  model's `min_free_gb` requirement.
- NVMe-backed storage is preferred. Non-NVMe storage should warn rather than
  fail, because removable or bind-mounted model stores may be intentional.
