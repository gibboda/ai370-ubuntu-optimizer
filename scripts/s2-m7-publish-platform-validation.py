#!/usr/bin/env python3
"""S2-M7: validate and atomically publish the platform validation aggregate."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import platform_validation  # noqa: E402


def _load_profile(path: Path | None) -> dict | None:
    if path is None or not path.is_file():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="S2-M7 publish s2-m7-platform-validation.json from milestone reports"
    )
    parser.add_argument(
        "--reports-dir",
        required=True,
        type=Path,
        help="Directory containing Stage 2 milestone and compatibility JSON reports",
    )
    parser.add_argument(
        "--profile",
        type=Path,
        help="Optional consumed s1-m5-system-profile.json (schema version + fingerprint)",
    )
    parser.add_argument(
        "--output",
        required=True,
        type=Path,
        help="Canonical s2-m7-platform-validation.json destination",
    )
    parser.add_argument(
        "--compat-output",
        type=Path,
        help="Optional compatibility tier1-validation.json destination",
    )
    parser.add_argument(
        "--compat-markdown",
        type=Path,
        help="Optional compatibility tier1-summary.md destination",
    )
    parser.add_argument(
        "--compat-status",
        type=Path,
        help="Optional compatibility tier1-validation.txt destination",
    )
    parser.add_argument(
        "--scope",
        choices=("inventory", "full", "smoke"),
        default="full",
        help="Aggregate scope (inventory skips S2-M5; smoke requires local-AI artifact)",
    )
    parser.add_argument(
        "--strict",
        choices=("true", "false"),
        default="false",
        help="Elevate missing gfx1150/NPU from recorded warning to FAIL",
    )
    parser.add_argument(
        "--cli-profile",
        default="ai370",
        help="Selected CLI profile name recorded on the compatibility report",
    )
    args = parser.parse_args()

    profile = _load_profile(args.profile)
    if args.profile and profile is None:
        print(f"[WARN] Stage 1 profile missing; publishing S2-M7 without consumed fingerprint: {args.profile}")
    elif profile:
        print(f"[INFO] Consuming Stage 1 profile: {args.profile}")

    report = platform_validation.publish_s2_m7_platform_validation(
        args.reports_dir,
        args.output,
        profile=profile,
        scope=args.scope,
        strict=args.strict == "true",
        cli_profile=args.cli_profile,
        compat_output=args.compat_output,
        compat_markdown=args.compat_markdown,
        compat_status=args.compat_status,
    )
    print(f"[INFO] S2-M7 platform validation written to {args.output}")
    if args.compat_output:
        print(f"[INFO] Compatibility tier1-validation.json written to {args.compat_output}")
    print(f"[INFO] S2-M7 status: {report['status']}")
    if report["status"] == "FAIL":
        raise SystemExit(3)


if __name__ == "__main__":
    main()
