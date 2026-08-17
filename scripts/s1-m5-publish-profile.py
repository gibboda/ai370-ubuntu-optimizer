#!/usr/bin/env python3
"""S1-M5: validate and atomically publish the Stage 1 system profile."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import system_profile  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(
        description="S1-M5 publish s1-m5-system-profile.json from milestone artifacts"
    )
    parser.add_argument("--facts", required=True, type=Path, help="S1-M2 normalized facts JSON")
    parser.add_argument("--classification", required=True, type=Path, help="S1-M3 classification JSON")
    parser.add_argument("--capabilities", required=True, type=Path, help="S1-M4 capability candidates JSON")
    parser.add_argument("--output", required=True, type=Path, help="Canonical s1-m5-system-profile.json")
    parser.add_argument("--summary", required=True, type=Path, help="s1-m5-inventory-summary.md")
    parser.add_argument("--compat-output", type=Path, help="Compatibility system-profile.json copy")
    parser.add_argument("--schema", type=Path, default=system_profile.S1_M5_SCHEMA)
    parser.add_argument("--generator-version", default="unknown")
    args = parser.parse_args()
    facts = json.loads(args.facts.read_text(encoding="utf-8"))
    classification = json.loads(args.classification.read_text(encoding="utf-8"))
    capabilities = json.loads(args.capabilities.read_text(encoding="utf-8"))
    profile = system_profile.assemble_profile(
        facts, classification, capabilities, args.generator_version
    )
    system_profile.atomic_write_document(args.output, profile, args.schema, "S1-M5 system profile")
    system_profile.atomic_write_text(args.summary, system_profile.render_inventory_summary(profile))
    if args.compat_output:
        system_profile.atomic_write(args.compat_output, profile, system_profile.DEFAULT_SCHEMA)
    print(f"[INFO] S1-M5 system profile written to {args.output}")
    print(f"[INFO] S1-M5 inventory summary written to {args.summary}")


if __name__ == "__main__":
    main()
