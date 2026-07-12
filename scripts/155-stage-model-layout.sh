#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Package D (S2-M5 polish): create offline model directory layout and staging
# placeholders from configs/models/manifest.yaml. Never downloads models.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$PROJECT_ROOT/scripts/lib/common.sh"

ai370_parse_standard_args "$@"
ai370_init_latest_dir

MANIFEST="$PROJECT_ROOT/configs/models/manifest.yaml"
MODEL_ROOT="$PROJECT_ROOT/.ai370-ai/models"
OFFLINE_ROOT="$PROJECT_ROOT/.ai370-ai/offline-artifacts"
RAG_ROOT="$PROJECT_ROOT/.ai370-ai/rag"
REPORT_JSON="$LATEST_DIR/model-layout-staging.json"
REPORT_MD="$LATEST_DIR/model-layout-staging.md"

main() {
  echo "[INFO] S2-M5 / 155-stage-model-layout.sh (layout only; no downloads)"
  echo "[INFO] Profile: $PROFILE  Offline: $OFFLINE"

  if [[ ! -f "$MANIFEST" ]]; then
    echo "[ERROR] Missing $MANIFEST"
    exit 2
  fi

  mkdir -p \
    "$MODEL_ROOT/chat" \
    "$MODEL_ROOT/coding" \
    "$MODEL_ROOT/embedding" \
    "$MODEL_ROOT/lemonade" \
    "$MODEL_ROOT/rag" \
    "$MODEL_ROOT/staging" \
    "$OFFLINE_ROOT/embedding" \
    "$OFFLINE_ROOT/anythingllm" \
    "$OFFLINE_ROOT/lemonade" \
    "$OFFLINE_ROOT/digestai" \
    "$RAG_ROOT/documents" \
    "$RAG_ROOT/anythingllm-storage"

  # Per-manifest path parents + README stubs (never create fake model weights)
  python3 - "$PROJECT_ROOT" "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
manifest = json.loads(Path(sys.argv[2]).read_text())
# Prefer manifest format over Path.suffix (names like qwen2.5-coder-7b have a
# non-empty suffix but are directory staging paths for format=ollama/directory).
DIRECTORY_FORMATS = frozenset({"directory", "ollama"})
FILE_FORMATS = frozenset({"gguf", "onnx"})

def is_directory_path(entry: dict, path: Path) -> bool:
    fmt = str(entry.get("format") or "").strip().lower()
    if fmt in DIRECTORY_FORMATS:
        return True
    if fmt in FILE_FORMATS:
        return False
    # Fallback when format is unknown: suffix-less paths are directories.
    return path.suffix == ""

for entry in manifest.get("models") or []:
    path_value = entry.get("path")
    if not path_value:
        continue
    p = Path(path_value)
    if not p.is_absolute():
        p = root / p
    if is_directory_path(entry, p):
        p.mkdir(parents=True, exist_ok=True)
        readme = p / "README.md"
    else:
        # File path (e.g. *.gguf / *.onnx) — ensure parent dir only
        p.parent.mkdir(parents=True, exist_ok=True)
        readme = p.parent / "README.md"
    if readme.exists():
        continue
    mid = entry.get("id", "model")
    notes = entry.get("notes") or "Stage the model artifact here for offline use."
    tag = entry.get("ollama_tag") or ""
    lines = [
        f"# {entry.get('name', mid)}",
        "",
        f"- Manifest id: `{mid}`",
        f"- Category: `{entry.get('category')}`",
        f"- Runtime: `{entry.get('runtime')}`",
        f"- Format: `{entry.get('format')}`",
    ]
    if tag:
        lines.append(
            f"- Ollama tag: `{tag}` (pull when online, then re-run "
            "`scripts/150-validate-offline-model-storage.sh`)"
        )
    lines.extend(
        [
            "",
            notes,
            "",
            "This directory was created by `scripts/155-stage-model-layout.sh`. "
            "It does **not** download weights.",
            "",
        ]
    )
    readme.write_text("\n".join(lines))
print("ok")
PY

  cat > "$OFFLINE_ROOT/anythingllm/README.md" <<'EOF'
# AnythingLLM offline staging

Place one of:

- Docker image tarball (e.g. `anythingllm.tar`) for `docker load`
- AnythingLLM AppImage

Then:

```bash
./ai370-optimize.sh stage2-rag --offline
# Optional container start after image is available:
ANYTHINGLLM_START=true ./scripts/300-install-anythingllm.sh
```

See `configs/models/storage-policy.md`.
EOF

  cat > "$OFFLINE_ROOT/lemonade/README.md" <<'EOF'
# Lemonade offline staging

Stage wheels under `.ai370-ai/wheelhouse` or this directory, then:

```bash
./ai370-optimize.sh stage2-lemonade --offline
# Full serving smoke when a model is available:
LEMONADE_START=true ./scripts/165-validate-lemonade.sh
```

See `docs/npu-status.md` (S2-M6).
EOF

  cat > "$OFFLINE_ROOT/digestai/README.md" <<'EOF'
# Digest AI offline staging

Optional: stage the Digest AI source tree (upstream requires Python 3.9–3.10).
Without it, `scripts/255-analyze-model-digest.sh` uses the ONNX structural fallback.

```bash
./ai370-optimize.sh stage2-digest --offline
```
EOF

  PROFILE="$PROFILE" MODE="$MODE" OFFLINE="$OFFLINE" \
  python3 - "$REPORT_JSON" "$REPORT_MD" <<'PY'
import json
import os
import sys
from datetime import datetime, UTC
from pathlib import Path

out_json, out_md = Path(sys.argv[1]), Path(sys.argv[2])
report = {
    "stage": "S2-M5",
    "phase": "stage-model-layout",
    "status": "PASS",
    "timestamp": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
    "profile": os.environ.get("PROFILE", "ai370"),
    "mode": os.environ.get("MODE", "safe"),
    "offline": os.environ.get("OFFLINE", "false") == "true",
    "policy": "layout and README stubs only; never downloads model weights",
    "layout": [
        ".ai370-ai/models/chat|coding|embedding|lemonade|rag|staging",
        ".ai370-ai/offline-artifacts/embedding|anythingllm|lemonade|digestai",
        ".ai370-ai/rag/documents|anythingllm-storage",
    ],
    "next": [
        "Place GGUF/ONNX/embedding trees under the paths in configs/models/manifest.yaml",
        "Or pull Ollama tags listed in the manifest when online",
        "Re-run scripts/150-validate-offline-model-storage.sh",
        "Optional: LEMONADE_START=true ./scripts/165-validate-lemonade.sh",
        "Optional: ANYTHINGLLM_START=true ./scripts/300-install-anythingllm.sh",
    ],
}
out_json.write_text(json.dumps(report, indent=2) + "\n")
out_md.write_text(
    "# Model layout staging\n\n"
    "**Status:** PASS\n\n"
    "Created directory layout and README stubs for offline model staging.\n"
    "No model weights were downloaded.\n\n"
    "## Next steps\n\n"
    "- Stage artifacts under `.ai370-ai/models/**` per `configs/models/manifest.yaml`\n"
    "- Stage AnythingLLM/Lemonade/Digest offline packs under `.ai370-ai/offline-artifacts/`\n"
    "- `./scripts/150-validate-offline-model-storage.sh`\n"
    "- Optional: `LEMONADE_START=true ./scripts/165-validate-lemonade.sh`\n"
    "- Optional: `ANYTHINGLLM_START=true ./scripts/300-install-anythingllm.sh`\n"
)
print(f"[INFO] Wrote {out_json}")
print(f"[INFO] Wrote {out_md}")
PY

  echo "[INFO] Model layout staged under .ai370-ai/ (no downloads)."
  echo "[INFO] 155-stage-model-layout.sh complete."
}

main "$@"
