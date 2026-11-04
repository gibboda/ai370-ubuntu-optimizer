"""S2-M6 runtime configuration backup and rollback (power profile state).

Backups live under ``reports/latest/s2-m6-runtime-backups/<id>/``. The apply
pointer ``s2-m6-apply-backup-pointer.json`` records the manifest captured
immediately before the last ``--approve`` apply; ``stage2-optimize-rollback``
restores that manifest, not merely the newest directory by mtime.
"""

from __future__ import annotations

import json
import subprocess
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from uuid import uuid4

BACKUP_SUBDIR = "s2-m6-runtime-backups"
MANIFEST_NAME = "manifest.json"
APPLY_POINTER_NAME = "s2-m6-apply-backup-pointer.json"
POWER_PROFILE_ITEM = "power_profile"
UNSUPPORTED_POWER_PROFILE_EXIT = 3


def _utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def _run_command(
    command: list[str],
    *,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> subprocess.CompletedProcess[str] | None:
    run = runner or subprocess.run
    try:
        return run(command, check=False, capture_output=True, text=True)
    except (FileNotFoundError, OSError):
        return None


def read_power_profile(
    *,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> dict[str, Any]:
    """Return current power profile observation or an error payload."""
    completed = _run_command(["powerprofilesctl", "get"], runner=runner)
    if completed is None:
        return {
            "available": False,
            "value": None,
            "error": "powerprofilesctl not available",
        }
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
) -> tuple[bool, str | None]:
    """Return (success, error_message)."""
    completed = _run_command(["powerprofilesctl", "set", value], runner=runner)
    if completed is None:
        return False, "powerprofilesctl not available"
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "powerprofilesctl set failed").strip()
        return False, detail or "powerprofilesctl set failed"
    return True, None


def list_power_profiles(
    *,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> dict[str, Any]:
    """Return profile names from ``powerprofilesctl list`` when available."""
    completed = _run_command(["powerprofilesctl", "list"], runner=runner)
    if completed is None:
        return {"available": False, "profiles": [], "error": "powerprofilesctl not available"}
    if completed.returncode != 0:
        return {
            "available": False,
            "profiles": [],
            "error": (completed.stderr or completed.stdout or "powerprofilesctl list failed").strip(),
        }
    profiles: list[str] = []
    for line in (completed.stdout or "").splitlines():
        token = line.strip().split()[0] if line.strip() else ""
        if token and token not in profiles:
            profiles.append(token)
    return {"available": True, "profiles": profiles, "error": None}


def target_power_profile_supported(
    target: str,
    *,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> bool:
    listing = list_power_profiles(runner=runner)
    if not listing["available"]:
        return False
    return target in listing["profiles"]


def backup_root(latest_dir: Path) -> Path:
    return latest_dir / BACKUP_SUBDIR


def _unique_backup_id() -> str:
    stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%S")
    return f"{stamp}-{uuid4().hex[:8]}"


def manifest_platform_id(manifest: dict[str, Any]) -> str | None:
    value = manifest.get("platform_id")
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def check_manifest_platform_match(
    manifest: dict[str, Any],
    *,
    profile_platform_id: str | None,
) -> dict[str, Any]:
    """Compare manifest ``platform_id`` to the loaded Stage 1 profile."""
    manifest_id = manifest_platform_id(manifest)
    profile_id = (str(profile_platform_id).strip() if profile_platform_id else None) or None
    if manifest_id is None:
        return {
            "ok": False,
            "platform_mismatch": True,
            "manifest_platform_id": None,
            "profile_platform_id": profile_id,
            "error": "backup manifest missing platform_id (re-capture after upgrade)",
        }
    if profile_id is None:
        return {
            "ok": False,
            "platform_mismatch": True,
            "manifest_platform_id": manifest_id,
            "profile_platform_id": None,
            "error": (
                f"Stage 1 profile has no classified platform_id; "
                f"manifest platform_id is {manifest_id}"
            ),
        }
    if manifest_id != profile_id:
        return {
            "ok": False,
            "platform_mismatch": True,
            "manifest_platform_id": manifest_id,
            "profile_platform_id": profile_id,
            "error": (
                f"platform_id mismatch: manifest has {manifest_id}, "
                f"profile has {profile_id}"
            ),
        }
    return {
        "ok": True,
        "platform_mismatch": False,
        "manifest_platform_id": manifest_id,
        "profile_platform_id": profile_id,
        "error": None,
    }


def capture_runtime_backup(
    latest_dir: Path,
    *,
    backup_id: str | None = None,
    classified_platform_id: str | None = None,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> dict[str, Any]:
    """Capture pre-apply runtime state. Does not mutate system settings."""
    root = backup_root(latest_dir)
    root.mkdir(parents=True, exist_ok=True)
    backup_id = backup_id or _unique_backup_id()
    directory = root / backup_id
    while directory.exists():
        backup_id = _unique_backup_id()
        directory = root / backup_id
    directory.mkdir(parents=False)
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
    manifest: dict[str, Any] = {
        "schema": {"name": "s2-m6-runtime-backup", "version": 1},
        "created_at": _utc_now(),
        "backup_id": backup_id,
        "items": items,
        "power_profile": power,
    }
    if classified_platform_id:
        manifest["platform_id"] = classified_platform_id
    manifest_path = directory / MANIFEST_NAME
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    relative_manifest = f"reports/latest/{BACKUP_SUBDIR}/{backup_id}/{MANIFEST_NAME}"
    status = "captured" if items else "failed"
    note = (
        "Recorded pre-apply power profile for rollback."
        if items
        else (
            "Backup unavailable: powerprofilesctl missing or power profile state unreadable."
        )
    )
    block = {
        "status": status,
        "manifest": relative_manifest,
        "backup_id": backup_id,
        "items": [item["id"] for item in items],
        "rollback_available": bool(items),
        "note": note,
        "manifest_path": manifest_path,
    }
    write_apply_backup_pointer(latest_dir, block)
    return block


def write_apply_backup_pointer(latest_dir: Path, block: dict[str, Any]) -> None:
    """Record the manifest tied to the current apply session."""
    manifest_path = block.get("manifest_path")
    pointer = {
        "manifest": block.get("manifest"),
        "backup_id": block.get("backup_id"),
        "manifest_path": str(manifest_path) if manifest_path else None,
        "captured_at": _utc_now(),
    }
    (latest_dir / APPLY_POINTER_NAME).write_text(
        json.dumps(pointer, indent=2) + "\n", encoding="utf-8"
    )


def manifest_from_apply_pointer(latest_dir: Path) -> Path | None:
    pointer_path = latest_dir / APPLY_POINTER_NAME
    if not pointer_path.is_file():
        return None
    try:
        pointer = json.loads(pointer_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    stored_path = pointer.get("manifest_path")
    if stored_path:
        path = Path(str(stored_path))
        if path.is_file():
            return path
    backup_id = pointer.get("backup_id")
    if backup_id:
        candidate = backup_root(latest_dir) / str(backup_id) / MANIFEST_NAME
        if candidate.is_file():
            return candidate
    return None


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
            if not observed:
                errors.append("failed to restore power_profile: no observed value in manifest")
                continue
            ok, reason = write_power_profile(observed, runner=runner)
            if ok:
                restored.append(item_id)
            elif reason:
                errors.append(f"failed to restore {item_id}: {reason}")
            else:
                errors.append(f"failed to restore {item_id}")
    return {
        "restored": bool(restored) and not errors,
        "restored_items": restored,
        "errors": errors,
    }


def latest_manifest_in(latest_dir: Path) -> Path | None:
    """Newest manifest by backup_id lexicographic order (fallback when no apply pointer)."""
    root = backup_root(latest_dir)
    if not root.is_dir():
        return None
    backup_ids = sorted(
        child.name for child in root.iterdir() if child.is_dir() and child.name
    )
    for backup_id in reversed(backup_ids):
        candidate = root / backup_id / MANIFEST_NAME
        if candidate.is_file():
            return candidate
    return None


def resolve_restore_manifest(latest_dir: Path, explicit: Path | None = None) -> Path | None:
    if explicit is not None:
        return explicit if explicit.is_file() else None
    return manifest_from_apply_pointer(latest_dir) or latest_manifest_in(latest_dir)


def _restore_errors_from_result(restore_result: dict[str, Any] | None) -> list[str]:
    if not restore_result:
        return []
    errors = [str(item) for item in (restore_result.get("errors") or []) if str(item).strip()]
    if restore_result.get("error"):
        errors.append(str(restore_result["error"]))
    return errors


def merge_backup_after_apply(
    block: dict[str, Any],
    *,
    apply_succeeded: bool,
    restore_exit_code: int | None,
    restore_result: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Update backup block status after apply and optional rollback."""
    updated = {key: value for key, value in block.items() if key != "manifest_path"}
    had_rollback = bool(updated.get("rollback_available"))
    if apply_succeeded:
        if updated.get("status") == "failed":
            updated["rollback_available"] = False
            updated["note"] = (
                "Apply completed but pre-apply backup failed; rollback unavailable."
            )
        else:
            updated["status"] = "captured"
            updated["note"] = "Apply succeeded; pre-apply backup retained for rollback."
        return updated
    if restore_exit_code is None:
        updated["status"] = "failed"
        updated["note"] = "Apply failed; rollback was not attempted."
        updated["rollback_available"] = had_rollback
        return updated
    if restore_exit_code == 0:
        updated["status"] = "restored"
        updated["rollback_available"] = had_rollback
        updated["note"] = "Apply failed; rollback restored pre-apply backup."
        return updated
    updated["status"] = "rollback_failed"
    updated["rollback_available"] = False
    updated["note"] = "Apply failed and rollback did not complete."
    restore_errors = _restore_errors_from_result(restore_result)
    if restore_errors:
        updated["restore_errors"] = restore_errors
    return updated


def dry_run_backup_block() -> dict[str, Any]:
    return {
        "status": "skipped",
        "rollback_available": False,
        "note": "Dry-run apply skipped runtime backup capture.",
    }


def backup_block_for_json(block: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in block.items() if key != "manifest_path"}


def write_backup_block_json(path: Path, block: dict[str, Any]) -> None:
    path.write_text(json.dumps(backup_block_for_json(block), indent=2) + "\n", encoding="utf-8")


def write_extra_warnings_json(path: Path, warnings: list[str]) -> None:
    path.write_text(json.dumps(warnings, indent=2) + "\n", encoding="utf-8")


def render_cpu_runtime_commands(target_power: str) -> str:
    """Shell script body for S2-M6 runtime apply (power profile + cpupower info)."""
    return f"""#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Generated S2-M5 CPU runtime tuning commands. Review before --approve execution.
set -euo pipefail

echo "[TUNE] Setting power profile (runtime)..."
if command -v powerprofilesctl >/dev/null 2>&1; then
  target_power="{target_power}"
  profiles="$(powerprofilesctl list 2>/dev/null || true)"
  if printf '%s\\n' "$profiles" | grep -qw "$target_power"; then
    powerprofilesctl set "$target_power"
  else
    echo "[WARN] power_profile: unsupported (target $target_power not in powerprofilesctl list)"
    exit {UNSUPPORTED_POWER_PROFILE_EXIT}
  fi
else
  echo "[WARN] powerprofilesctl not available."
  exit {UNSUPPORTED_POWER_PROFILE_EXIT}
fi

echo "[TUNE] CPU frequency info (if cpupower present)..."
if command -v cpupower >/dev/null 2>&1; then
  cpupower frequency-info || true
fi
"""


def rollback_from_latest(
    latest_dir: Path,
    *,
    runner: Callable[..., subprocess.CompletedProcess[str]] | None = None,
) -> dict[str, Any]:
    manifest_path = resolve_restore_manifest(latest_dir)
    if manifest_path is None:
        return {"restored": False, "error": "no backup manifest under latest dir"}
    result = restore_runtime_backup(manifest_path, runner=runner)
    result["manifest"] = str(manifest_path)
    return result
