#!/usr/bin/env python3
"""S1-M4: derive capability candidates that are not validation claims."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import system_profile  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(
        description="S1-M4 derive capability candidates from s1-m2-normalized-facts.json"
    )
    parser.add_argument("--input", required=True, type=Path, help="S1-M2 normalized facts JSON")
    parser.add_argument("--output", required=True, type=Path, help="S1-M4 capability candidates JSON")
    parser.add_argument("--schema", type=Path, default=system_profile.S1_M4_SCHEMA)
    args = parser.parse_args()
    facts = json.loads(args.input.read_text(encoding="utf-8"))
    document = system_profile.derive_capability_document(facts)
    system_profile.atomic_write_document(
        args.output, document, args.schema, "S1-M4 capability candidates"
    )
    print(f"[INFO] S1-M4 capability candidates written to {args.output}")


if __name__ == "__main__":
    main()
