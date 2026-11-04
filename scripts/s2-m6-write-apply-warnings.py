#!/usr/bin/env python3
"""Write S2-M6 apply warning JSON for 40-platform-tuning.sh.

Internal helper CLI: parent ``40-platform-tuning.sh`` loads the Stage 1 profile.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import optimization_backup  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Write S2-M6 extra apply warnings JSON")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--warning",
        action="append",
        default=[],
        help="Warning string (repeatable)",
    )
    args = parser.parse_args()
    warnings = args.warning or ["power_profile: unsupported"]
    optimization_backup.write_extra_warnings_json(args.output, warnings)


if __name__ == "__main__":
    main()
