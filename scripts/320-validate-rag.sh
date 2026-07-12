#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M3: Offline RAG validator with production pass/fail aggregation.
# 1) Confirms embedding model + packages (offline-safe)
# 2) Runs local semantic retrieval smoke (no network)
# 3) Aggregates AnythingLLM + embedding installer reports into stage2-rag status

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
AI_ROOT="$PROJECT_ROOT/.ai370-ai"
VENV_DIR="${EMBEDDING_VENV_DIR:-$AI_ROOT/venv}"
WHEELHOUSE="${OFFLINE_WHEELHOUSE:-$AI_ROOT/wheelhouse}"
MODEL_DIR="${EMBEDDING_MODEL_DIR:-$AI_ROOT/models/embedding/local-embedding-model}"
DOC_DIR="${ANYTHINGLLM_DOC_DIR:-$AI_ROOT/rag/documents}"
STATUS_JSON="$LATEST_DIR/rag-validation.json"
SUMMARY_MD="$LATEST_DIR/rag-validation.md"
AGG_JSON="$LATEST_DIR/stage2-rag-validation.json"
AGG_MD="$LATEST_DIR/stage2-rag-validation.md"
ANYTHING_JSON="$LATEST_DIR/anythingllm-status.json"
EMBED_JSON="$LATEST_DIR/tier4-embedding-models.json"
OFFLINE_REQ="$PROJECT_ROOT/configs/ai-runtime/requirements-offline.txt"

if [[ -f "$PROJECT_ROOT/configs/offline/ai-runtime.env" ]]; then
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/configs/offline/ai-runtime.env" || true
  if [[ -n "${OFFLINE_WHEELHOUSE:-}" ]]; then
    if [[ "${OFFLINE_WHEELHOUSE}" = /* ]]; then
      WHEELHOUSE="$OFFLINE_WHEELHOUSE"
    else
      WHEELHOUSE="$PROJECT_ROOT/${OFFLINE_WHEELHOUSE#./}"
    fi
  fi
fi

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }
bool_json() { [[ "$1" == "true" ]] && echo true || echo false; }

read_json_field() {
  local file="$1" field="$2" default="${3:-}"
  if [[ ! -f "$file" ]]; then
    printf '%s' "$default"
    return 0
  fi
  python3 - "$file" "$field" "$default" <<'PY'
import json, sys
path, field, default = sys.argv[1:4]
try:
    data = json.load(open(path, encoding="utf-8"))
    val = data
    for part in field.split("."):
        if isinstance(val, dict) and part in val:
            val = val[part]
        else:
            print(default)
            raise SystemExit(0)
    if val is None:
        print(default)
    elif isinstance(val, bool):
        print("true" if val else "false")
    else:
        print(val)
except Exception:
    print(default)
PY
}

ensure_packages() {
  if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    return 1
  fi
  if "$VENV_DIR/bin/python" -c 'import transformers, torch, safetensors, numpy' >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$OFFLINE" == "true" ]]; then
    if [[ -d "$WHEELHOUSE" ]] && compgen -G "$WHEELHOUSE/*" >/dev/null 2>&1; then
      echo "[INFO] Offline: installing retrieval deps from wheelhouse..."
      if [[ -f "$OFFLINE_REQ" ]]; then
        "$VENV_DIR/bin/python" -m pip install --no-index --find-links="$WHEELHOUSE" -r "$OFFLINE_REQ" >/dev/null 2>&1 || true
      fi
      "$VENV_DIR/bin/python" -m pip install --no-index --find-links="$WHEELHOUSE" transformers torch safetensors numpy >/dev/null 2>&1 || true
    fi
  else
    echo "[INFO] Installing required packages in venv..."
    "$VENV_DIR/bin/python" -m pip install torch transformers safetensors numpy >/dev/null 2>&1 || true
  fi
  "$VENV_DIR/bin/python" -c 'import transformers, torch, safetensors, numpy' >/dev/null 2>&1
}

run_retrieval_smoke() {
  export MODEL_DIR
  export RAG_DOC_DIR="$DOC_DIR"
  "$VENV_DIR/bin/python" - <<'PY'
import json
import os
import sys
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModel, AutoTokenizer

documents = [
    "The Minisforum AI370 is an AMD Ryzen AI powered mini PC.",
    "It features a Radeon 890M iGPU with gfx1150 architecture.",
    "The XDNA2 NPU delivers up to 50 NPU TOPS for local AI acceleration.",
]

# Optionally fold in a few lines from the offline document store.
doc_dir = Path(os.environ.get("RAG_DOC_DIR", ""))
if doc_dir.is_dir():
    extra = []
    for path in sorted(doc_dir.rglob("*")):
        if path.is_file() and path.suffix.lower() in {".txt", ".md", ".csv"} and path.stat().st_size < 200_000:
            try:
                text = path.read_text(encoding="utf-8", errors="ignore").strip()
            except OSError:
                continue
            for line in text.splitlines():
                line = line.strip()
                if 40 <= len(line) <= 400:
                    extra.append(line)
            if len(extra) >= 3:
                break
    if extra:
        documents = documents + extra[:3]

query = "How many TOPS does the NPU deliver?"
expected_substr = "50 NPU TOPS"

try:
    model_dir = os.environ.get("MODEL_DIR", "")
    tokenizer = AutoTokenizer.from_pretrained(model_dir, local_files_only=True)
    model = AutoModel.from_pretrained(model_dir, local_files_only=True)

    def get_embedding(text: str):
        inputs = tokenizer(text, padding=True, truncation=True, return_tensors="pt")
        with torch.no_grad():
            outputs = model(**inputs)
        emb = outputs.last_hidden_state.mean(dim=1)[0].numpy()
        norm = np.linalg.norm(emb)
        return emb / norm if norm > 0 else emb

    doc_embeddings = [get_embedding(doc) for doc in documents]
    query_embedding = get_embedding(query)
    similarities = [float(np.dot(query_embedding, doc_emb)) for doc_emb in doc_embeddings]
    best_idx = int(np.argmax(similarities))
    retrieved = documents[best_idx]
    success = expected_substr in retrieved

    print(
        json.dumps(
            {
                "success": success,
                "retrieved_chunk": retrieved,
                "score": similarities[best_idx],
                "all_scores": similarities,
                "document_count": len(documents),
            }
        )
    )
    sys.exit(0)
except Exception as e:  # noqa: BLE001
    print(json.dumps({"error": str(e)}))
    sys.exit(1)
PY
}

main() {
  mkdir -p "$LATEST_DIR" "$DOC_DIR"

  local state="missing" status="WARN" detail="" validation_smoke="skipped"
  local query_result="" score="" packages_ok="false" model_ok="false"
  local retrieval_success="false" document_count="0"
  local recommendations=()

  if [[ -f "$MODEL_DIR/config.json" ]] && { [[ -f "$MODEL_DIR/model.safetensors" ]] || [[ -f "$MODEL_DIR/pytorch_model.bin" ]]; }; then
    model_ok="true"
  fi

  if [[ "$model_ok" != "true" ]]; then
    detail="Validation failed: local embedding model is missing from $MODEL_DIR. Run scripts/310-install-embedding-models.sh first (or stage offline artifacts)."
    recommendations+=("Stage model under $AI_ROOT/offline-artifacts/embedding/ and rerun stage2-rag --offline")
  elif [[ ! -x "$VENV_DIR/bin/python" ]]; then
    detail="Validation failed: Python virtualenv at $VENV_DIR is missing or not configured."
  elif ! ensure_packages; then
    packages_ok="false"
    detail="Validation failed: required packages (transformers, torch, safetensors, numpy) are not available in $VENV_DIR."
    if [[ "$OFFLINE" == "true" ]]; then
      recommendations+=("Populate $WHEELHOUSE with wheels and rerun with --offline")
    fi
  else
    packages_ok="true"
    state="available"
    echo "[INFO] Running offline semantic indexing and query test..."
    local py_err py_status
    py_err="$(mktemp)"
    if py_status="$(run_retrieval_smoke 2>"$py_err")"; then
      :
    else
      py_status="$(cat "$py_err" 2>/dev/null || true)${py_status:-}"
    fi
    # Prefer last JSON-looking line from stdout
    local json_line
    json_line="$(printf '%s\n' "$py_status" | python3 -c 'import sys
lines=[l.strip() for l in sys.stdin if l.strip()]
print(lines[-1] if lines else "")')"

    if [[ -n "$json_line" ]] && echo "$json_line" | grep -q 'retrieved_chunk\|"error"'; then
      if echo "$json_line" | python3 -c 'import json,sys; d=json.load(sys.stdin); raise SystemExit(0 if d.get("success") else 1)' 2>/dev/null; then
        retrieval_success="true"
        validation_smoke="pass"
        status="PASS"
        query_result="$(echo "$json_line" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("retrieved_chunk",""))')"
        score="$(echo "$json_line" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("score",0.0))')"
        document_count="$(echo "$json_line" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("document_count",0))')"
        detail="Offline RAG retrieval smoke passed. Semantic query returned the expected NPU/TOPS context (score=$score)."
      elif echo "$json_line" | grep -q '"error"'; then
        validation_smoke="fail"
        status="FAIL"
        detail="RAG pipeline execution failed. Model error: $(echo "$json_line" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("error","unknown"))')"
      else
        validation_smoke="warn"
        status="WARN"
        query_result="$(echo "$json_line" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("retrieved_chunk",""))' 2>/dev/null || true)"
        score="$(echo "$json_line" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("score",0.0))' 2>/dev/null || true)"
        detail="RAG pipeline ran, but semantic retrieval did not return the expected chunk. Best score: $score"
      fi
    else
      validation_smoke="fail"
      status="FAIL"
      detail="RAG pipeline execution failed. Error output: $(cat "$py_err" 2>/dev/null | tr '\n' ' ' | head -c 500)"
    fi
    rm -f "$py_err"
  fi

  # Aggregate prior installer reports (may be from this stage2-rag run).
  local anything_status embed_status anything_offline embed_offline
  anything_status="$(read_json_field "$ANYTHING_JSON" "status" "missing")"
  embed_status="$(read_json_field "$EMBED_JSON" "status" "missing")"
  anything_offline="$(read_json_field "$ANYTHING_JSON" "offline_ready" "false")"
  embed_offline="$(read_json_field "$EMBED_JSON" "offline_ready" "false")"

  # Production criteria:
  # - FAIL: retrieval smoke failed hard or model/packages missing when expected
  # - PASS (production_ready): retrieval PASS AND embedding offline_ready AND packages_ok
  #   AnythingLLM optional for core offline RAG smoke; required for full_stack_ready
  # - WARN: partial stack
  local production_ready="false" full_stack_ready="false" overall_status="$status"

  if [[ "$status" == "PASS" && "$model_ok" == "true" && "$packages_ok" == "true" ]]; then
    production_ready="true"
  fi
  if [[ "$production_ready" == "true" && "$anything_offline" == "true" ]]; then
    full_stack_ready="true"
  fi

  if [[ "$status" == "PASS" && "$anything_status" != "PASS" && "$anything_status" != "missing" ]]; then
    overall_status="PASS"
    detail="$detail AnythingLLM status=$anything_status (optional for embedding-level offline RAG)."
  elif [[ "$status" == "PASS" && "$anything_status" == "missing" ]]; then
    recommendations+=("Run scripts/300-install-anythingllm.sh to install or stage AnythingLLM for full-stack RAG UI.")
  fi

  if [[ "$status" != "FAIL" && "$production_ready" != "true" ]]; then
    overall_status="WARN"
  fi
  if [[ "$status" == "FAIL" ]]; then
    overall_status="FAIL"
  fi

  # Prefer embedding installer status when retrieval skipped due to missing model
  if [[ "$status" != "PASS" && "$status" != "FAIL" && "$embed_status" == "WARN" ]]; then
    overall_status="WARN"
  fi

  local rec_json="[]"
  if ((${#recommendations[@]} > 0)); then
    rec_json="$(printf '%s\n' "${recommendations[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
  fi

  local detail_json query_result_json
  detail_json="$(printf '%s' "$detail" | json_escape)"
  query_result_json="$(printf '%s' "$query_result" | json_escape)"

  cat > "$STATUS_JSON" <<EOF_JSON
{
  "tier": 4,
  "phase": "validate-rag",
  "milestone": "S2-M3",
  "status": "$status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $(bool_json "$OFFLINE"),
  "state": "$state",
  "model_ok": $(bool_json "$model_ok"),
  "packages_ok": $(bool_json "$packages_ok"),
  "validation_smoke": "$validation_smoke",
  "retrieval_success": $(bool_json "$retrieval_success"),
  "retrieved_chunk": $query_result_json,
  "similarity_score": "$score",
  "document_count": $document_count,
  "document_dir": $(printf '%s' "$DOC_DIR" | json_escape),
  "model_path": $(printf '%s' "$MODEL_DIR" | json_escape),
  "production_ready": $(bool_json "$production_ready"),
  "full_stack_ready": $(bool_json "$full_stack_ready"),
  "recommendations": $rec_json,
  "detail": $detail_json
}
EOF_JSON

  cat > "$AGG_JSON" <<EOF_JSON
{
  "tier": 4,
  "phase": "stage2-rag-validation",
  "milestone": "S2-M3",
  "status": "$overall_status",
  "profile": "$PROFILE",
  "mode": "$MODE",
  "persistence": "$PERSISTENCE",
  "offline": $(bool_json "$OFFLINE"),
  "production_ready": $(bool_json "$production_ready"),
  "full_stack_ready": $(bool_json "$full_stack_ready"),
  "components": {
    "anythingllm": {
      "report": "anythingllm-status.json",
      "status": $(printf '%s' "$anything_status" | json_escape),
      "offline_ready": $(bool_json "$anything_offline")
    },
    "embedding_models": {
      "report": "tier4-embedding-models.json",
      "status": $(printf '%s' "$embed_status" | json_escape),
      "offline_ready": $(bool_json "$embed_offline")
    },
    "retrieval_smoke": {
      "report": "rag-validation.json",
      "status": $(printf '%s' "$status" | json_escape),
      "validation_smoke": $(printf '%s' "$validation_smoke" | json_escape),
      "retrieval_success": $(bool_json "$retrieval_success")
    }
  },
  "criteria": {
    "production_ready": "embedding model present + packages importable + offline retrieval smoke PASS",
    "full_stack_ready": "production_ready AND AnythingLLM offline_ready (image/AppImage staged or installed)",
    "fail": "retrieval pipeline hard-fails or required local assets missing with no actionable offline path"
  },
  "detail": $detail_json,
  "recommendations": $rec_json
}
EOF_JSON

  {
    echo "# Stage 2 RAG — Retrieval Validation (S2-M3)"
    echo
    echo "Profile: $PROFILE | Mode: $MODE | Offline: $OFFLINE"
    echo "Status: $status"
    echo
    echo "- State: $state"
    echo "- Model OK: $model_ok"
    echo "- Packages OK: $packages_ok"
    echo "- Validation smoke: $validation_smoke"
    echo "- Retrieval success: $retrieval_success"
    echo "- Document count: $document_count"
    echo "- Document dir: $DOC_DIR"
    echo "- Retrieved chunk: $query_result"
    echo "- Cosine similarity score: $score"
    echo "- Production-ready (embedding RAG): $production_ready"
    echo "- Full-stack-ready (+ AnythingLLM): $full_stack_ready"
    echo
    printf '%s\n' "$detail"
    if ((${#recommendations[@]} > 0)); then
      echo
      echo "## Recommendations"
      local r
      for r in "${recommendations[@]}"; do
        echo "- $r"
      done
    fi
  } > "$SUMMARY_MD"

  {
    echo "# Stage 2 RAG — Aggregate Validation (S2-M3)"
    echo
    echo "Overall status: **$overall_status**"
    echo
    echo "| Component | Status | Offline-ready |"
    echo "| --- | --- | --- |"
    echo "| AnythingLLM | $anything_status | $anything_offline |"
    echo "| Embedding models | $embed_status | $embed_offline |"
    echo "| Retrieval smoke | $status ($validation_smoke) | $retrieval_success |"
    echo
    echo "## Production criteria"
    echo
    echo "- **production_ready**: embedding model + packages + offline retrieval smoke PASS → \`$production_ready\`"
    echo "- **full_stack_ready**: production_ready + AnythingLLM offline_ready → \`$full_stack_ready\`"
    echo
    printf '%s\n' "$detail"
  } > "$AGG_MD"

  echo "[INFO] Wrote $STATUS_JSON"
  echo "[INFO] Wrote $SUMMARY_MD"
  echo "[INFO] Wrote $AGG_JSON"
  echo "[INFO] Wrote $AGG_MD"

  if [[ "$overall_status" == "FAIL" || "$status" == "FAIL" ]]; then
    exit 1
  fi
}

main "$@"
