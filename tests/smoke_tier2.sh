#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Package D: Stage 2 smoke (non-mutating where possible).
# Syntax-checks core Stage 2 scripts, runs cheap aggregators offline-friendly,
# and asserts gate artifact shapes. Safe without AI370 hardware / without network.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
SMOKE_PROFILE="ai370"
SMOKE_MODE="safe"

echo "[INFO] Stage 2 smoke test starting (profile=$SMOKE_PROFILE)"

# 1. Syntax check critical Stage 2 scripts + libs
scripts=(
  ai370-optimize.sh
  scripts/100-install-pytorch-rocm.sh
  scripts/110-install-llama-cpp.sh
  scripts/120-install-ollama.sh
  scripts/130-install-open-webui.sh
  scripts/140-benchmark-llm.sh
  scripts/145-write-tier2-validation.sh
  scripts/150-validate-offline-model-storage.sh
  scripts/155-stage-model-layout.sh
  scripts/160-install-lemonade.sh
  scripts/165-validate-lemonade.sh
  scripts/170-install-turnkeyml.sh
  scripts/200-install-onnxruntime.sh
  scripts/205-install-xrt-ryzen-ai.sh
  scripts/210-check-ryzen-ai-software.sh
  scripts/220-check-vitis-ai-ep.sh
  scripts/s2-m4-validate-npu-stack.sh
  scripts/230-benchmark-npu.sh
  scripts/240-write-tier3-validation.sh
  scripts/245-compare-cpu-gpu-npu.sh
  scripts/250-install-digest-ai.sh
  scripts/255-analyze-model-digest.sh
  scripts/300-install-anythingllm.sh
  scripts/310-install-embedding-models.sh
  scripts/320-validate-rag.sh
  scripts/lib/common.sh
  scripts/lib/npu-venv.sh
  scripts/lib/lemonade-env.sh
  scripts/lib/offline-paths.sh
)
for s in "${scripts[@]}"; do
  if [[ -f "$PROJECT_ROOT/$s" ]]; then
    bash -n "$PROJECT_ROOT/$s"
    echo "[OK] syntax: $s"
  else
    echo "[FAIL] missing: $s"
    exit 1
  fi
done

# 2. Manifest is JSON-compatible
python3 - "$PROJECT_ROOT/configs/models/manifest.yaml" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
data = json.loads(p.read_text())
assert "models" in data and isinstance(data["models"], list)
cats = {m.get("category") for m in data["models"]}
for need in ("chat", "coding", "embedding"):
    assert need in cats, f"manifest missing category {need}"
print("[OK] manifest.yaml parses and has chat/coding/embedding")
PY

# 3. Layout staging (no downloads) + offline model storage validate
bash "$PROJECT_ROOT/scripts/155-stage-model-layout.sh" "$SMOKE_PROFILE" "$SMOKE_MODE" runtime true
bash "$PROJECT_ROOT/scripts/150-validate-offline-model-storage.sh" "$SMOKE_PROFILE" "$SMOKE_MODE" runtime true
bash "$PROJECT_ROOT/scripts/145-write-tier2-validation.sh" "$SMOKE_PROFILE" "$SMOKE_MODE" runtime true
bash "$PROJECT_ROOT/scripts/240-write-tier3-validation.sh" "$SMOKE_PROFILE" "$SMOKE_MODE" runtime true

# 4. Required artifacts
required=(
  offline-model-storage.json
  tier2-validation.json
  tier3-validation.json
  model-layout-staging.json
)
for f in "${required[@]}"; do
  if [[ ! -f "$LATEST_DIR/$f" ]]; then
    echo "[FAIL] missing artifact: $LATEST_DIR/$f"
    exit 2
  fi
  echo "[OK] artifact present: $f"
done

# 5. JSON structure checks
python3 - "$LATEST_DIR/offline-model-storage.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("stage") == "S2-M5"
assert data.get("status") in ("PASS", "WARN", "FAIL")
assert isinstance(data.get("models"), list)
print("[OK] offline-model-storage.json structure")
PY

python3 - "$LATEST_DIR/tier2-validation.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("tier") == 2
assert "status" in data
assert isinstance(data.get("acceptance"), dict)
acc = data["acceptance"]
for key in ("pytorch_available", "llama_cpp_available", "ollama_available", "local_model_available"):
    assert key in acc, f"missing acceptance.{key}"
print("[OK] tier2-validation.json structure + acceptance keys")
PY

# Regression: empty `ollama list` header must not imply local models (145 gate field).
python3 - "$PROJECT_ROOT/scripts/145-write-tier2-validation.sh" <<'PY'
import pathlib, re, sys

src = pathlib.Path(sys.argv[1]).read_text()
assert 'ollama_has_models = "NAME" in ollama_list' not in src, (
    "145 still uses NAME-substring false positive for ollama models"
)
assert "def ollama_list_has_models" in src, "145 missing ollama_list_has_models helper"

# Mirror the helper logic for behavioral checks (keep aligned with 145).
def ollama_list_has_models(list_text: str) -> bool:
    lines = [ln.strip() for ln in (list_text or "").splitlines() if ln.strip()]
    if not lines:
        return False
    head = lines[0].lower()
    if "command-not-found" in head or head.startswith("error"):
        return False
    start = 0
    first_tok = lines[0].split()[0].upper() if lines[0].split() else ""
    if first_tok == "NAME":
        start = 1
    for line in lines[start:]:
        name = line.split()[0] if line.split() else ""
        if name and name.upper() != "NAME":
            return True
    return False

assert ollama_list_has_models("NAME    ID    SIZE    MODIFIED\n") is False
assert ollama_list_has_models(
    "NAME    ID    SIZE    MODIFIED\nllama3:8b    abc    4.7 GB    yesterday\n"
) is True
assert ollama_list_has_models("command-not-found: ollama") is False
assert ollama_list_has_models("") is False
print("[OK] ollama list header is not treated as local models present")
PY

python3 - "$LATEST_DIR/tier3-validation.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("status") in ("PASS", "WARN", "FAIL", "EXPERIMENTAL-PASS")
print("[OK] tier3-validation.json has status")
PY

# 5b. S2-M4 visibility-only NPU publisher (no 230 / xrt-smi validate)
# Canonical Stage 1 profile is required before publishing.
"$PROJECT_ROOT/ai370-optimize.sh" stage1-probe
"$PROJECT_ROOT/ai370-optimize.sh" stage1-profile
bash "$PROJECT_ROOT/scripts/s2-m4-validate-npu-stack.sh" "$SMOKE_PROFILE" "$SMOKE_MODE" runtime true
if [[ ! -f "$LATEST_DIR/s2-m4-npu-runtime-validation.json" ]]; then
  echo "[FAIL] missing artifact: s2-m4-npu-runtime-validation.json (S2-M4)"
  exit 2
fi
if [[ ! -f "$LATEST_DIR/npu-acceleration-status.json" ]]; then
  echo "[FAIL] missing compat artifact: npu-acceleration-status.json"
  exit 2
fi
python3 - "$LATEST_DIR/s2-m4-npu-runtime-validation.json" "$PROJECT_ROOT" <<'PY'
import importlib.util, json, sys
from pathlib import Path
root = Path(sys.argv[2])
spec = importlib.util.spec_from_file_location("system_profile", root / "scripts/lib/system_profile.py")
ladder_spec = importlib.util.spec_from_file_location("capability_ladder", root / "scripts/lib/capability_ladder.py")
system_profile = importlib.util.module_from_spec(spec)
capability_ladder = importlib.util.module_from_spec(ladder_spec)
spec.loader.exec_module(system_profile)
ladder_spec.loader.exec_module(capability_ladder)
report = json.load(open(sys.argv[1], encoding="utf-8"))
system_profile.validate_document(report, capability_ladder.S2_M4_SCHEMA, "S2-M4")
assert report.get("milestone") == "S2-M4"
assert report["ladder"]["validation_claim"] is False
assert report["ladder"]["current"] != "APPLICATION_READY"
consumed = report["consumed_profile"]
assert consumed["artifact"] == "s1-m5-system-profile.json"
assert consumed["schema"]["version"] == 3
assert consumed["fingerprint"]["algorithm"] == "sha256"
print("[OK] s2-m4-npu-runtime-validation.json validates against schema")
PY
python3 - "$LATEST_DIR/npu-capabilities.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("visibility_only") is True, "210 visibility-only must skip xrt-smi validate"
assert data.get("xrt_smi_validate") == "skipped-visibility-only"
print("[OK] npu-capabilities.json records skipped-visibility-only validate")
PY

# 6. Orchestrator help exposes Package B/C flags
help_out="$("$PROJECT_ROOT/ai370-optimize.sh" help 2>&1 || true)"
echo "$help_out" | grep -q "with-lemonade" || { echo "[FAIL] help missing --with-lemonade"; exit 3; }
echo "$help_out" | grep -q "stage1-inventory" || { echo "[FAIL] help missing stage1-inventory"; exit 3; }
echo "[OK] orchestrator help mentions stage1-inventory and --with-lemonade"

echo "[PASS] Stage 2 smoke test completed successfully."
echo "[INFO] Install/benchmark status may be WARN without local models/NPU; structure checks passed."
