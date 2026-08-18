#!/usr/bin/env python3
"""S2-M3: validate and atomically publish GPU runtime visibility report."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import capability_ladder  # noqa: E402
import system_profile  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(
        description="S2-M3 publish s2-m3-gpu-runtime-visibility.json from visibility checks"
    )
    parser.add_argument("--checks", required=True, type=Path, help="GPU visibility checks JSON")
    parser.add_argument(
        "--profile",
        type=Path,
        help="Optional consumed s1-m5-system-profile.json (schema version + fingerprint)",
    )
    parser.add_argument(
        "--output",
        required=True,
        type=Path,
        help="Canonical s2-m3-gpu-runtime-visibility.json destination",
    )
    args = parser.parse_args()

    checks = json.loads(args.checks.read_text(encoding="utf-8"))
    profile = None
    if args.profile and args.profile.is_file():
        profile = json.loads(args.profile.read_text(encoding="utf-8"))

    if profile:
        hardware = system_profile.hardware_from_system_profile(profile)
        consumed = capability_ladder.consumed_profile_from_system_profile(profile)
    else:
        hardware = capability_ladder.hardware_from_live_gpu_checks(checks)
        consumed = capability_ladder.consumed_profile_from_system_profile(None)

    report = capability_ladder.build_s2_m3_visibility_report(hardware, checks, consumed)
    system_profile.atomic_write_document(
        args.output,
        report,
        capability_ladder.S2_M3_SCHEMA,
        "S2-M3",
    )
    print(f"[INFO] S2-M3 GPU runtime visibility written to {args.output}")


if __name__ == "__main__":
    main()
