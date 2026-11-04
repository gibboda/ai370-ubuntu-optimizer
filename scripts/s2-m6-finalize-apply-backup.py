#!/usr/bin/env python3
"""Update S2-M6 backup JSON after apply and optional rollback.

Internal helper CLI: called from ``40-platform-tuning.sh`` after apply/rollback.
Exempt from loading the Stage 1 profile; the parent script already validated it.
"""

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
        "--runtime-apply-skipped",
        choices=("true", "false"),
        default="false",
        help="Runtime commands ran but mutating apply was skipped (unsupported/missing power profile)",
    )
    parser.add_argument(
        "--restore-exit-code",
        type=int,
        help="Omit when rollback was not attempted; 0 means success",
    )
    parser.add_argument(
        "--restore-result-json",
        type=Path,
        help="JSON object printed by s2-m6-restore-runtime-backup.py",
    )
    args = parser.parse_args()
    block = json.loads(args.backup_json.read_text(encoding="utf-8"))
    restore_code = args.restore_exit_code
    if args.apply_succeeded == "true":
        restore_code = None
    restore_result: dict | None = None
    if args.restore_result_json is not None and args.restore_result_json.is_file():
        try:
            loaded = json.loads(args.restore_result_json.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            loaded = None
        if isinstance(loaded, dict):
            restore_result = loaded
    updated = optimization_backup.merge_backup_after_apply(
        block,
        apply_succeeded=args.apply_succeeded == "true",
        restore_exit_code=restore_code,
        restore_result=restore_result,
        runtime_apply_skipped=args.runtime_apply_skipped == "true",
    )
    args.backup_json.write_text(json.dumps(updated, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
