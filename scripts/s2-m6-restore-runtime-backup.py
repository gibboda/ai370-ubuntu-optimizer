#!/usr/bin/env python3
"""S2-M6: restore runtime tuning from the apply-session backup pointer or manifest."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import firmware_policy  # noqa: E402
import optimization_backup  # noqa: E402
import optimization_plan  # noqa: E402

DEFAULT_PROFILE_NAME = "s1-m5-system-profile.json"


def _load_required_profile(path: Path) -> dict:
    try:
        profile = firmware_policy.load_system_profile(path)
    except FileNotFoundError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"[ERROR] Stage 1 profile unreadable: {path}: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
    if not isinstance(profile, dict):
        print(f"[ERROR] Stage 1 profile is not a JSON object: {path}", file=sys.stderr)
        raise SystemExit(2)
    return profile


def _load_application(path: Path) -> dict | None:
    if not path.is_file():
        return None
    try:
        loaded = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return loaded if isinstance(loaded, dict) else None


def _rollback_publish_failure_summary(result: dict) -> str:
    """Human-readable rollback outcome for publish-failure warnings (not JSON)."""
    if result.get("dry_run"):
        return "Rollback dry-run did not apply runtime changes"
    if result.get("platform_mismatch"):
        return "Rollback did not restore runtime settings (platform mismatch)"
    if not result.get("restored"):
        return "Rollback failed to restore runtime settings"
    return "Rollback restored runtime settings"


def _publish_rollback_report(latest: Path, *, dry_run: bool, result: dict) -> bool:
    """Merge manual rollback into the S2-M6 report. Returns False on publish failure."""
    application_path = latest / "s2-m6-optimization-application.json"
    application = _load_application(application_path)
    if application is None:
        return True
    merged = optimization_plan.merge_manual_runtime_rollback(
        application, dry_run=dry_run, result=result
    )
    try:
        optimization_plan.publish_s2_m6_optimization_application(
            application_path, merged, plan=None
        )
    except (OSError, ValueError, TypeError) as exc:
        summary = _rollback_publish_failure_summary(result)
        print(
            f"[WARN] {summary} but failed to update "
            f"{application_path.name}: {exc}",
            file=sys.stderr,
        )
        return False
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description="S2-M6 restore runtime backup from reports/latest")
    parser.add_argument(
        "--latest-dir",
        type=Path,
        default=Path("reports/latest"),
        help="Reports directory (defaults to reports/latest)",
    )
    parser.add_argument(
        "--profile",
        type=Path,
        help=f"Stage 1 profile (default: <latest-dir>/{DEFAULT_PROFILE_NAME})",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        help="Explicit manifest path; default uses s2-m6-apply-backup-pointer.json",
    )
    parser.add_argument(
        "--dry-run",
        choices=("true", "false"),
        default="false",
        help="Plan rollback without mutating runtime settings",
    )
    parser.add_argument(
        "--no-publish",
        choices=("true", "false"),
        default="false",
        help="Do not merge results into s2-m6-optimization-application.json (apply-time rollback)",
    )
    args = parser.parse_args()
    latest = args.latest_dir.resolve()
    profile_path = (args.profile or (latest / DEFAULT_PROFILE_NAME)).resolve()
    dry_run = args.dry_run == "true"
    no_publish = args.no_publish == "true"

    profile = _load_required_profile(profile_path)
    profile_platform_id = firmware_policy.classified_platform_id(profile)

    manifest = optimization_backup.resolve_restore_manifest(
        latest, args.manifest.resolve() if args.manifest else None
    )
    if manifest is None:
        print("[ERROR] No S2-M6 runtime backup manifest found.", file=sys.stderr)
        raise SystemExit(2)

    manifest_data = json.loads(manifest.read_text(encoding="utf-8"))
    match = optimization_backup.check_manifest_platform_match(
        manifest_data, profile_platform_id=profile_platform_id
    )
    if not match["ok"]:
        result: dict = {
            "restored": False,
            "dry_run": dry_run,
            "manifest": str(manifest),
            "restored_items": [],
            "errors": [str(match["error"])],
            "platform_mismatch": bool(match.get("platform_mismatch")),
            "manifest_platform_id": match.get("manifest_platform_id"),
            "profile_platform_id": match.get("profile_platform_id"),
        }
        print(json.dumps(result, indent=2))
        if not no_publish:
            _publish_rollback_report(latest, dry_run=dry_run, result=result)
        if dry_run:
            return
        raise SystemExit(2)

    if dry_run:
        result = {
            "restored": False,
            "dry_run": True,
            "manifest": str(manifest),
            "restored_items": [],
            "errors": [],
            "platform_mismatch": False,
            "manifest_platform_id": match.get("manifest_platform_id"),
            "profile_platform_id": match.get("profile_platform_id"),
            "note": "Dry-run: rollback was not executed.",
        }
        print(json.dumps(result, indent=2))
        if not no_publish:
            _publish_rollback_report(latest, dry_run=True, result=result)
        return

    result = optimization_backup.restore_runtime_backup(manifest.resolve())
    result["manifest"] = str(manifest)
    result["platform_mismatch"] = False
    result["manifest_platform_id"] = match.get("manifest_platform_id")
    result["profile_platform_id"] = match.get("profile_platform_id")
    print(json.dumps(result, indent=2))
    restored = bool(result.get("restored"))
    if not no_publish and not _publish_rollback_report(latest, dry_run=False, result=result):
        if restored:
            print(
                "[WARN] Rollback succeeded; S2-M6 report was not updated (see warnings above).",
                file=sys.stderr,
            )
    if not restored:
        raise SystemExit(1)
    # Keep stdout JSON-only: apply-time rollback redirects stdout into
    # --restore-result-json for s2-m6-finalize-apply-backup.py.
    print(f"[INFO] Restored runtime backup from {manifest}", file=sys.stderr)


if __name__ == "__main__":
    main()
