#!/usr/bin/env python3
"""Write S2-M5 plan facts JSON from shell-collected identity fields.

Internal helper CLI: invoked from ``40-platform-tuning.sh`` after the parent
loads the Stage 1 profile. Exempt from loading the Stage 1 profile itself (see
``scripts/AGENTS.md``).
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="S2-M5 facts JSON writer")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--cpu-model", default="")
    parser.add_argument("--target-power", default="balanced")
    parser.add_argument("--governor", default="")
    parser.add_argument("--cpu-source", default="live")
    parser.add_argument("--mem-total", default="")
    parser.add_argument("--zram-active", default="")
    parser.add_argument("--mem-source", default="live")
    args = parser.parse_args()
    document = {
        "cpu_model": args.cpu_model,
        "target_power": args.target_power,
        "governor": args.governor,
        "cpu_source": args.cpu_source,
        "mem_total": args.mem_total,
        "zram_active": args.zram_active,
        "mem_source": args.mem_source,
    }
    args.output.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
