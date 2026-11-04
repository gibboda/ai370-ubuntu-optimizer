#!/usr/bin/env python3
"""S2-M6: restore runtime tuning from the apply-session backup pointer or manifest."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import optimization_backup  # noqa: E402
import optimization_plan  # noqa: E402


def _load_application(path: Path) -> dict | None:
    if not path.is_file():
        return None
    try:
        loaded = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return loaded if isinstance(loaded, dict) else None


def _publish_rollback_report(latest: Path, *, dry_run: bool, result: dict) -> None:
    application_path = latest / "s2-m6-optimization-application.json"
    application = _load_application(application_path)
    if application is None:
        return
    merged = optimization_plan.merge_manual_runtime_rollback(
        application, dry_run=dry_run, result=result
    )
    optimization_plan.publish_s2_m6_optimization_application(
        application_path, merged, plan=None
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="S2-M6 restore runtime backup from reports/latest")
    parser.add_argument(
        "--latest-dir",
        type=Path,
        default=Path("reports/latest"),
        help="Reports directory (defaults to reports/latest)",
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
    args = parser.parse_args()
    latest = args.latest_dir.resolve()
    dry_run = args.dry_run == "true"
    manifest = optimization_backup.resolve_restore_manifest(
        latest, args.manifest.resolve() if args.manifest else None
    )
    if manifest is None:
        print("[ERROR] No S2-M6 runtime backup manifest found.", file=sys.stderr)
        raise SystemExit(2)
    if dry_run:
        result: dict = {
            "restored": False,
            "dry_run": True,
            "manifest": str(manifest),
            "restored_items": [],
            "errors": [],
            "note": "Dry-run: rollback was not executed.",
        }
        print(json.dumps(result, indent=2))
        _publish_rollback_report(latest, dry_run=True, result=result)
        return

    result = optimization_backup.restore_runtime_backup(manifest.resolve())
    result["manifest"] = str(manifest)
    print(json.dumps(result, indent=2))
    _publish_rollback_report(latest, dry_run=False, result=result)
    if not result.get("restored"):
        raise SystemExit(1)
    print(f"[INFO] Restored runtime backup from {manifest}")


if __name__ == "__main__":
    main()
