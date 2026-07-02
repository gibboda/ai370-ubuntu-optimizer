#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M3: Offline RAG validator script.
# Ingests a local text document, performs sentence embedding indexing,
# and verifies offline semantic retrieval queries.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
VENV_DIR="$AI_ROOT/venv"
MODEL_DIR="$AI_ROOT/models/embedding/local-embedding-model"
STATUS_JSON="$LATEST_DIR/rag-validation.json"
SUMMARY_MD="$LATEST_DIR/rag-validation.md"

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

main() {
  mkdir -p "$LATEST_DIR"

  local state="missing" status="WARN" detail="" validation_smoke="skipped" query_result="" score=""

  if [[ ! -d "$MODEL_DIR" || ! -f "$MODEL_DIR/config.json" ]]; then
    detail="Validation failed: Local embedding model is missing from $MODEL_DIR. Run 310-install-embedding-models.sh first."
  elif [[ ! -x "$VENV_DIR/bin/python" ]]; then
    detail="Validation failed: Python virtualenv at $VENV_DIR is missing or not configured."
  else
    # Check if necessary python packages are present
    if ! "$VENV_DIR/bin/python" -c 'import transformers, torch, safetensors' >/dev/null 2>&1; then
      if [[ "$OFFLINE" == "true" ]]; then
        detail="Validation failed: Required packages (transformers, torch, safetensors) are not installed in $VENV_DIR and cannot be fetched offline."
      else
        echo "[INFO] Installing required packages in venv..."
        "$VENV_DIR/bin/python" -m pip install torch transformers safetensors >/dev/null 2>&1 || true
      fi
    fi

    if "$VENV_DIR/bin/python" -c 'import transformers, torch, safetensors' >/dev/null 2>&1; then
      state="available"
      echo "[INFO] Running offline semantic indexing and query test..."
      
      local py_err=""
      py_err="$(mktemp)"
      export MODEL_DIR
      if py_status="$("$VENV_DIR/bin/python" - <<'PY' 2>"$py_err"
import os
import sys
import json
import torch
import numpy as np
from transformers import AutoTokenizer, AutoModel

# 1. Ingest a local test document
documents = [
    "The Minisforum AI370 is an AMD Ryzen AI powered mini PC.",
    "It features a Radeon 890M iGPU with gfx1150 architecture.",
    "The XDNA2 NPU delivers up to 50 NPU TOPS for local AI acceleration."
]

query = "How many TOPS does the NPU deliver?"

try:
    # 2. Load model locally (offline-safe)
    model_dir = os.environ.get("MODEL_DIR", "")
    tokenizer = AutoTokenizer.from_pretrained(model_dir, local_files_only=True)
    model = AutoModel.from_pretrained(model_dir, local_files_only=True)
    
    def get_embedding(text):
        inputs = tokenizer(text, padding=True, truncation=True, return_tensors="pt")
        with torch.no_grad():
            outputs = model(**inputs)
        # Mean pooling to extract sentence representation
        embeddings = outputs.last_hidden_state.mean(dim=1)
        # Normalize
        emb = embeddings[0].numpy()
        norm = np.linalg.norm(emb)
        return emb / norm if norm > 0 else emb

    # 3. Index/embed documents
    doc_embeddings = [get_embedding(doc) for doc in documents]
    query_embedding = get_embedding(query)
    
    # 4. Search and retrieve top chunk via cosine similarity
    similarities = [float(np.dot(query_embedding, doc_emb)) for doc_emb in doc_embeddings]
    best_idx = int(np.argmax(similarities))
    
    # Verify the most similar document is the NPU/TOPS one (index 2)
    success = (best_idx == 2)
    
    print(json.dumps({
        "success": success,
        "retrieved_chunk": documents[best_idx],
        "score": similarities[best_idx],
        "all_scores": similarities
    }))
    sys.exit(0)
except Exception as e:
    print(json.dumps({"error": str(e)}))
    sys.exit(1)
PY
)"; then
        local_detail_err=""
      else
        local_detail_err="$(cat "$py_err")"
      fi
      rm -f "$py_err"

      if [[ -n "$py_status" ]] && echo "$py_status" | grep -q "retrieved_chunk"; then
        local success
        success="$(echo "$py_status" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("success", False))')"
        query_result="$(echo "$py_status" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("retrieved_chunk", ""))')"
        score="$(echo "$py_status" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("score", 0.0))')"
        
        if [[ "$success" == "True" ]]; then
          status="PASS"
          validation_smoke="pass"
          detail="Offline RAG validation successful. Semantic query returned correct context chunk with cosine similarity score: $score"
        else
          status="WARN"
          validation_smoke="warn"
          detail="RAG pipeline functioned, but semantic retrieval returned incorrect chunk. Best score: $score"
        fi
      else
        status="FAIL"
        validation_smoke="fail"
        if [[ -n "$py_status" ]] && echo "$py_status" | grep -q "error"; then
          detail="RAG pipeline execution failed. Model error: $(echo "$py_status" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("error", "unknown"))')"
        else
          detail="RAG pipeline execution failed. Error output: ${local_detail_err:-$py_status}"
        fi
      fi
    else
      detail="Validation failed: Missing PyTorch or Transformers in the local virtual environment."
    fi
  fi

  local detail_json query_result_json
  detail_json="$(printf '%s' "$detail" | json_escape)"
  query_result_json="$(printf '%s' "$query_result" | json_escape)"
  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 4,
  "phase": "validate-rag",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $([[ "$OFFLINE" == "true" ]] && echo true || echo false),
  "state": "$state",
  "validation_smoke": "$validation_smoke",
  "retrieved_chunk": $query_result_json,
  "similarity_score": "$score",
  "detail": $detail_json
}
EOF_JSON

  {
    echo "# Tier 4 RAG Ingestion & Query Validation"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- State: $state"
    echo "- Validation smoke: $validation_smoke"
    echo "- Retrieved context chunk: $query_result"
    echo "- Cosine similarity score: $score"
    echo
    printf '%s\n' "$detail"
  } > "$SUMMARY_MD"

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
}

main "$@"
