#!/usr/bin/env python3
"""Write S2-M6 backup block JSON for apply (capture or dry-run skip).

Internal helper CLI: invoked only from ``40-platform-tuning.sh`` after that
script has loaded the canonical Stage 1 profile. Exempt from loading the Stage 1
profile itself (see ``scripts/AGENTS.md``).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import firmware_policy  # noqa: E402
import optimization_backup  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="S2-M6 backup block helper")
    parser.add_argument("--output", required=True, type=Path)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("dry-run-skipped", help="Write skipped backup block for dry-run apply")
    capture = sub.add_parser("capture", help="Capture pre-apply runtime backup")
    capture.add_argument("--latest-dir", type=Path, default=Path("reports/latest"))
    capture.add_argument(
        "--profile",
        type=Path,
        required=True,
        help="Canonical Stage 1 profile used to record platform_id on the manifest",
    )
    args = parser.parse_args()
    if args.command == "dry-run-skipped":
        block = optimization_backup.dry_run_backup_block()
    else:
        profile = firmware_policy.load_system_profile(args.profile.resolve())
        platform_id = firmware_policy.classified_platform_id(profile)
        block = optimization_backup.capture_runtime_backup(
            args.latest_dir.resolve(),
            classified_platform_id=platform_id,
        )
    optimization_backup.write_backup_block_json(args.output, block)


if __name__ == "__main__":
    main()
