#!/usr/bin/env python3
"""S2-M7: validate and atomically publish the platform validation aggregate."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import firmware_policy  # noqa: E402
import platform_validation  # noqa: E402


def _load_required_profile(path: Path) -> dict:
    """Load the canonical Stage 1 profile or exit 2 without publishing."""
    try:
        profile = firmware_policy.load_system_profile(path)
    except FileNotFoundError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"[ERROR] Stage 1 profile unreadable: {path}: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
    if not isinstance(profile, dict):
        print(f"[ERROR] Stage 1 profile is not a JSON object: {path}", file=sys.stderr)
        raise SystemExit(2)
    return profile


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
        required=True,
        type=Path,
        help="Required consumed s1-m5-system-profile.json (schema version + fingerprint)",
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

    profile = _load_required_profile(args.profile)
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
