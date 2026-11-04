"""S2-M6 runtime configuration backup and rollback (power profile state).

Backups are stored under ``reports/latest/s2-m6-runtime-backups/<id>/`` and are
used only for Stage 2 approved runtime tuning. Persistent sysfs/tuned changes are
out of scope until explicitly implemented.
"""

from __future__ import annotations

import json
import subprocess
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

BACKUP_SUBDIR = "s2-m6-runtime-backups"
MANIFEST_NAME = "manifest.json"
POWER_PROFILE_ITEM = "power_profile"


def _utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def _run_command(
    command: list[str],
    *,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> subprocess.CompletedProcess[str]:
    run = runner or subprocess.run
    return run(command, check=False, capture_output=True, text=True)


def read_power_profile(
    *,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> dict[str, Any]:
    """Return current power profile observation or an error payload."""
    completed = _run_command(["powerprofilesctl", "get"], runner=runner)
    if completed.returncode != 0:
        return {
            "available": False,
            "value": None,
            "error": (completed.stderr or completed.stdout or "powerprofilesctl failed").strip(),
        }
    value = (completed.stdout or "").strip()
    return {"available": True, "value": value or None, "error": None}


def write_power_profile(
    value: str,
    *,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> bool:
    completed = _run_command(["powerprofilesctl", "set", value], runner=runner)
    return completed.returncode == 0


def backup_root(latest_dir: Path) -> Path:
    return latest_dir / BACKUP_SUBDIR


def capture_runtime_backup(
    latest_dir: Path,
    *,
    backup_id: str | None = None,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> dict[str, Any]:
    """Capture pre-apply runtime state. Does not mutate system settings."""
    backup_id = backup_id or datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    directory = backup_root(latest_dir) / backup_id
    directory.mkdir(parents=True, exist_ok=True)
    power = read_power_profile(runner=runner)
    items: list[dict[str, Any]] = []
    if power["available"] and power.get("value"):
        items.append(
            {
                "id": POWER_PROFILE_ITEM,
                "tool": "powerprofilesctl",
                "restore_command": ["powerprofilesctl", "set", str(power["value"])],
                "observed": str(power["value"]),
            }
        )
    manifest = {
        "schema": {"name": "s2-m6-runtime-backup", "version": 1},
        "created_at": _utc_now(),
        "backup_id": backup_id,
        "items": items,
        "power_profile": power,
    }
    manifest_path = directory / MANIFEST_NAME
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    relative_manifest = f"reports/latest/{BACKUP_SUBDIR}/{backup_id}/{MANIFEST_NAME}"
    status = "captured" if items else "failed"
    note = (
        "Recorded pre-apply power profile for rollback."
        if items
        else "Backup failed: powerprofilesctl state was unavailable."
    )
    return {
        "status": status,
        "manifest": relative_manifest,
        "backup_id": backup_id,
        "items": [item["id"] for item in items],
        "rollback_available": bool(items),
        "note": note,
        "manifest_path": manifest_path,
    }


def restore_runtime_backup(
    manifest_path: Path,
    *,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> dict[str, Any]:
    """Restore runtime settings from a backup manifest."""
    if not manifest_path.is_file():
        return {"restored": False, "error": f"manifest missing: {manifest_path}"}
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    restored: list[str] = []
    errors: list[str] = []
    for item in manifest.get("items") or []:
        item_id = str(item.get("id") or "")
        if item_id == POWER_PROFILE_ITEM:
            observed = str(item.get("observed") or "")
            if observed and write_power_profile(observed, runner=runner):
                restored.append(item_id)
            else:
                errors.append(f"failed to restore {item_id}")
    return {
        "restored": bool(restored) and not errors,
        "restored_items": restored,
        "errors": errors,
    }


def latest_manifest_in(latest_dir: Path) -> Path | None:
    root = backup_root(latest_dir)
    if not root.is_dir():
        return None
    candidates = sorted(
        (path / MANIFEST_NAME for path in root.iterdir() if path.is_dir()),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return None


def rollback_from_latest(
    latest_dir: Path,
    *,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> dict[str, Any]:
    manifest_path = latest_manifest_in(latest_dir)
    if manifest_path is None:
        return {"restored": False, "error": "no backup manifest under latest dir"}
    result = restore_runtime_backup(manifest_path, runner=runner)
    result["manifest"] = str(manifest_path)
    return result
