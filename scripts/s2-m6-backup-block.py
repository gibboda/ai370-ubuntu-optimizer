#!/usr/bin/env python3
"""Write S2-M6 backup block JSON for apply (capture or dry-run skip)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import optimization_backup  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="S2-M6 backup block helper")
    parser.add_argument("--output", required=True, type=Path)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("dry-run-skipped", help="Write skipped backup block for dry-run apply")
    capture = sub.add_parser("capture", help="Capture pre-apply runtime backup")
    capture.add_argument("--latest-dir", type=Path, default=Path("reports/latest"))
    args = parser.parse_args()
    if args.command == "dry-run-skipped":
        block = optimization_backup.dry_run_backup_block()
    else:
        block = optimization_backup.capture_runtime_backup(args.latest_dir.resolve())
    optimization_backup.write_backup_block_json(args.output, block)


if __name__ == "__main__":
    main()
