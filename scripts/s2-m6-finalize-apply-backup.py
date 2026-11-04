#!/usr/bin/env python3
"""Update S2-M6 backup JSON after apply and optional rollback."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import optimization_backup  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Finalize S2-M6 backup block after apply")
    parser.add_argument("--backup-json", required=True, type=Path)
    parser.add_argument("--apply-succeeded", choices=("true", "false"), required=True)
    parser.add_argument(
        "--restore-exit-code",
        type=int,
        help="Omit when rollback was not attempted; 0 means success",
    )
    args = parser.parse_args()
    block = json.loads(args.backup_json.read_text(encoding="utf-8"))
    restore_code = args.restore_exit_code
    if args.apply_succeeded == "true":
        restore_code = None
    updated = optimization_backup.merge_backup_after_apply(
        block,
        apply_succeeded=args.apply_succeeded == "true",
        restore_exit_code=restore_code,
    )
    args.backup_json.write_text(json.dumps(updated, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
