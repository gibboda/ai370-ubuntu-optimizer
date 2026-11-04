#!/usr/bin/env python3
"""S2-M6: restore runtime tuning from the apply-session backup pointer or manifest."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import optimization_backup  # noqa: E402


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
    args = parser.parse_args()
    latest = args.latest_dir.resolve()
    manifest = optimization_backup.resolve_restore_manifest(
        latest, args.manifest.resolve() if args.manifest else None
    )
    if manifest is None:
        print("[ERROR] No S2-M6 runtime backup manifest found.", file=sys.stderr)
        raise SystemExit(2)
    result = optimization_backup.restore_runtime_backup(manifest.resolve())
    print(json.dumps(result, indent=2))
    if not result.get("restored"):
        raise SystemExit(1)
    print(f"[INFO] Restored runtime backup from {manifest}")


if __name__ == "__main__":
    main()
