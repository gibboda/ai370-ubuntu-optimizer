#!/usr/bin/env python3
"""S2-M1: validate and atomically publish firmware validation."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import firmware_policy  # noqa: E402


def _load_required_profile(path: Path) -> dict:
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
        description="S2-M1 publish s2-m1-firmware-validation.json from profile facts and live checks"
    )
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--checks", type=Path, help="Live supplemental checks JSON")
    parser.add_argument("--compat-baseline", type=Path)
    parser.add_argument("--compat-validation", type=Path)
    parser.add_argument("--cli-profile", default="ai370")
    args = parser.parse_args()

    profile = _load_required_profile(args.profile)
    checks: dict = {}
    if args.checks is not None:
        checks = json.loads(args.checks.read_text(encoding="utf-8"))
        if not isinstance(checks, dict):
            print(f"[ERROR] Checks file is not a JSON object: {args.checks}", file=sys.stderr)
            raise SystemExit(2)

    report = firmware_policy.build_s2_m1_firmware_validation(
        profile,
        checks=checks,
        cli_profile=args.cli_profile,
    )
    firmware_policy.publish_s2_m1_firmware_validation(
        args.output,
        report,
        profile=profile,
        checks=checks,
        compat_baseline=args.compat_baseline,
        compat_validation=args.compat_validation,
    )
    print(f"[INFO] S2-M1 firmware validation written to {args.output}")
    if args.compat_baseline:
        print(f"[INFO] Compatibility tier1-firmware.json written to {args.compat_baseline}")
    if args.compat_validation:
        print(
            "[INFO] Compatibility tier1-firmware-validation.json written to "
            f"{args.compat_validation}"
        )
    print(f"[INFO] S2-M1 status: {report['status']}")
    if report["status"] == "FAIL":
        raise SystemExit(3)


if __name__ == "__main__":
    main()
