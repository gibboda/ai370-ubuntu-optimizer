#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# S2-M5: offline model manifest, storage, and integrity validation.

set -euo pipefail

PROFILE="${1:-ai370}"
MODE="${2:-safe}"
PERSISTENCE="${3:-runtime}"
OFFLINE="${4:-false}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LATEST_DIR="$PROJECT_ROOT/reports/latest"
MANIFEST="$PROJECT_ROOT/configs/models/manifest.yaml"
POLICY="$PROJECT_ROOT/configs/models/storage-policy.md"
STATUS_JSON="$LATEST_DIR/offline-model-storage.json"
STATUS_MD="$LATEST_DIR/offline-model-storage.md"

mkdir -p "$LATEST_DIR"

python3 - "$PROJECT_ROOT" "$MANIFEST" "$POLICY" "$STATUS_JSON" "$STATUS_MD" "$PROFILE" "$MODE" "$PERSISTENCE" "$OFFLINE" <<'PY'
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

project_root, manifest_path, policy_path, status_json, status_md, profile, mode, persistence, offline = sys.argv[1:]
root = Path(project_root)
manifest_file = Path(manifest_path)
policy_file = Path(policy_path)
messages = []
models_out = []
failures = 0
warnings = 0
allowed_categories = {"chat", "coding", "embedding"}


def add(level, message):
    global failures, warnings
    messages.append({"level": level, "message": message})
    if level == "FAIL":
        failures += 1
    elif level == "WARN":
        warnings += 1


def rel_or_abs(path_value):
    path = Path(path_value)
    return path if path.is_absolute() else root / path


def normalize_path(path):
    # Resolve lexical segments like ".." without requiring the artifact to exist.
    return path.expanduser().resolve(strict=False)


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


if not manifest_file.exists():
    add("FAIL", f"Missing manifest: {manifest_file.relative_to(root)}")
    manifest = {"model_root": ".ai370-ai/models", "models": []}
else:
    try:
        # The repository manifest is JSON-compatible YAML to keep validation
        # dependency-free in offline environments.
        manifest = json.loads(manifest_file.read_text())
    except Exception as exc:  # noqa: BLE001 - actionable diagnostic for users
        add("FAIL", f"Unable to parse manifest as JSON-compatible YAML: {exc}")
        manifest = {"model_root": ".ai370-ai/models", "models": []}

if not policy_file.exists():
    add("FAIL", f"Missing storage policy: {policy_file.relative_to(root)}")

model_root = normalize_path(rel_or_abs(manifest.get("model_root", ".ai370-ai/models")))
try:
    model_root.mkdir(parents=True, exist_ok=True)
except Exception as exc:  # noqa: BLE001
    add("FAIL", f"Unable to create model root {model_root}: {exc}")

try:
    usage = shutil.disk_usage(model_root)
    free_gb = usage.free / (1024 ** 3)
    total_gb = usage.total / (1024 ** 3)
except Exception as exc:  # noqa: BLE001
    free_gb = 0.0
    total_gb = 0.0
    add("FAIL", f"Unable to inspect free space for {model_root}: {exc}")

minimum_free_gb = float(manifest.get("minimum_free_gb", 0) or 0)
if free_gb < minimum_free_gb:
    add("FAIL", f"Model root has {free_gb:.1f} GiB free; manifest requires {minimum_free_gb:.1f} GiB")

# Best-effort NVMe signal: inspect the mount entry that actually backs the
# normalized model root. This remains a warning because bind mounts, LVM,
# encryption, and CI filesystems can obscure the physical backing device.
nvme_signal = False
try:
    best_mount = None
    best_line = ""
    for line in Path("/proc/self/mountinfo").read_text(errors="ignore").splitlines():
        fields = line.split()
        if len(fields) < 5:
            continue
        mount_point = normalize_path(Path(fields[4].replace("\\040", " ")))
        try:
            model_root.relative_to(mount_point)
        except ValueError:
            continue
        if best_mount is None or len(str(mount_point)) > len(str(best_mount)):
            best_mount = mount_point
            best_line = line
    if best_mount is not None:
        mount_source = best_line.split(" - ", 1)[1] if " - " in best_line else best_line
        nvme_signal = "nvme" in mount_source.lower()
except Exception:
    nvme_signal = False
if not nvme_signal:
    add("WARN", "NVMe backing could not be confirmed for the model root; verify placement before importing large models")

models = manifest.get("models", [])
if not isinstance(models, list) or not models:
    add("FAIL", "Manifest must contain at least one model entry")
    models = []

seen_categories = set()
seen_ids = set()

def set_entry_status(current, new):
    if current == "FAIL" or new == "PASS":
        return current
    if new == "FAIL":
        return "FAIL"
    if new == "WARN" and current == "PASS":
        return "WARN"
    return current

for entry in models:
    entry_status = "PASS"
    entry_messages = []
    if not isinstance(entry, dict):
        add("FAIL", "Manifest model entry is not an object")
        continue

    model_id = entry.get("id", "<missing-id>")
    category = entry.get("category")
    required = bool(entry.get("required", False))
    path_value = entry.get("path")
    checksum = entry.get("checksum") or {}
    algorithm = str(checksum.get("algorithm", "none")).lower()
    checksum_value = checksum.get("value")
    min_free_gb = float(entry.get("min_free_gb", 0) or 0)

    for field in ("id", "name", "category", "runtime", "format", "required"):
        if field not in entry:
            entry_status = set_entry_status(entry_status, "FAIL")
            entry_messages.append(f"missing required field: {field}")

    if model_id in seen_ids:
        entry_status = set_entry_status(entry_status, "FAIL")
        entry_messages.append("duplicate model id")
    seen_ids.add(model_id)

    if category in allowed_categories:
        seen_categories.add(category)
    else:
        entry_status = set_entry_status(entry_status, "FAIL")
        entry_messages.append(f"invalid category: {category}")

    if free_gb < min_free_gb:
        entry_status = set_entry_status(entry_status, "FAIL" if required else "WARN")
        entry_messages.append(f"free space {free_gb:.1f} GiB is below model requirement {min_free_gb:.1f} GiB")

    exists = False
    resolved_path = None
    if path_value:
        resolved_path = normalize_path(rel_or_abs(path_value))
        try:
            resolved_path.relative_to(model_root)
        except ValueError:
            entry_status = set_entry_status(entry_status, "FAIL")
            entry_messages.append("path is outside the canonical model root")
        exists = resolved_path.exists()
        if not exists:
            entry_status = set_entry_status(entry_status, "FAIL" if required else "WARN")
            entry_messages.append("model artifact is not present locally")
        elif algorithm == "sha256":
            if not checksum_value:
                entry_status = set_entry_status(entry_status, "WARN")
                entry_messages.append("sha256 checksum value is not set")
            elif resolved_path.is_file():
                actual = sha256_file(resolved_path)
                if actual != checksum_value:
                    entry_status = set_entry_status(entry_status, "FAIL")
                    entry_messages.append("sha256 checksum mismatch")
            else:
                entry_status = set_entry_status(entry_status, "WARN")
                entry_messages.append("sha256 checksum is only applied to files by this validator")
    elif not entry.get("ollama_tag"):
        entry_status = set_entry_status(entry_status, "FAIL")
        entry_messages.append("entry must define path or ollama_tag")

    if algorithm not in {"none", "sha256"}:
        entry_status = set_entry_status(entry_status, "FAIL")
        entry_messages.append(f"unsupported checksum algorithm: {algorithm}")

    if entry_status == "FAIL":
        add("FAIL", f"{model_id}: " + "; ".join(entry_messages))
    elif entry_status == "WARN":
        add("WARN", f"{model_id}: " + "; ".join(entry_messages))

    models_out.append({
        "id": model_id,
        "name": entry.get("name"),
        "category": category,
        "runtime": entry.get("runtime"),
        "format": entry.get("format"),
        "path": path_value,
        "ollama_tag": entry.get("ollama_tag"),
        "required": required,
        "exists": exists,
        "status": entry_status,
        "messages": entry_messages,
    })

missing_categories = sorted(allowed_categories - seen_categories)
if missing_categories:
    add("FAIL", "Manifest missing required categories: " + ", ".join(missing_categories))

status = "FAIL" if failures else ("WARN" if warnings else "PASS")
report = {
    "stage": "S2-M5",
    "status": status,
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "profile": profile,
    "mode": mode,
    "persistence": persistence,
    "offline": offline == "true",
    "manifest": str(manifest_file.relative_to(root)),
    "policy": str(policy_file.relative_to(root)),
    "model_root": str(model_root.relative_to(root) if model_root.is_relative_to(root) else model_root),
    "storage": {
        "total_gb": round(total_gb, 2),
        "free_gb": round(free_gb, 2),
        "minimum_free_gb": minimum_free_gb,
        "nvme_confirmed": nvme_signal,
    },
    "models": models_out,
    "messages": messages,
}
Path(status_json).write_text(json.dumps(report, indent=2) + "\n")

lines = [
    "# Offline Model Storage Validation",
    "",
    f"Status: {status}",
    f"Profile: {profile}",
    f"Mode: {mode}",
    f"Persistence: {persistence}",
    f"Offline: {offline}",
    f"Manifest: `{manifest_file.relative_to(root)}`",
    f"Policy: `{policy_file.relative_to(root)}`",
    f"Model root: `{report['model_root']}`",
    "",
    "## Storage",
    "",
    f"- Total: {total_gb:.1f} GiB",
    f"- Free: {free_gb:.1f} GiB",
    f"- Minimum required: {minimum_free_gb:.1f} GiB",
    f"- NVMe confirmed: {'yes' if nvme_signal else 'no'}",
    "",
    "## Model inventory",
    "",
    "| ID | Category | Runtime | Required | Present | Status |",
    "| --- | --- | --- | --- | --- | --- |",
]
for model in models_out:
    lines.append(
        f"| {model['id']} | {model.get('category') or ''} | {model.get('runtime') or ''} | "
        f"{str(model['required']).lower()} | {str(model['exists']).lower()} | {model['status']} |"
    )
lines.extend(["", "## Diagnostics", ""])
if messages:
    for item in messages:
        lines.append(f"- {item['level']}: {item['message']}")
else:
    lines.append("- PASS: offline model storage is ready")
lines.extend([
    "",
    "## Offline behavior",
    "",
    "This validation reads local metadata and files only. It does not download, pull, clone, delete, overwrite, or move model artifacts.",
])
Path(status_md).write_text("\n".join(lines) + "\n")

print(f"[INFO] Offline model storage status: {status}")
print(f"[INFO] Wrote {status_json}")
print(f"[INFO] Wrote {status_md}")
if status == "FAIL":
    sys.exit(1)
PY
