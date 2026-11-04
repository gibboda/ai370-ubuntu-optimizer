#!/usr/bin/env python3
"""Generate tier1-cpu-runtime-commands.sh for S2-M6 apply.

Internal helper CLI: invoked from ``40-platform-tuning.sh`` after the parent
loads the Stage 1 profile.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import optimization_backup  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Write S2-M6 runtime command script")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--target-power", default="balanced")
    args = parser.parse_args()
    args.output.write_text(
        optimization_backup.render_cpu_runtime_commands(args.target_power),
        encoding="utf-8",
    )
    args.output.chmod(args.output.stat().st_mode | 0o111)


if __name__ == "__main__":
    main()
