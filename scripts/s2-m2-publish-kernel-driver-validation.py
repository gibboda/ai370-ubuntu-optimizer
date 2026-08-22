#!/usr/bin/env python3
"""S2-M2: validate and atomically publish kernel/driver validation."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import firmware_policy  # noqa: E402
import kernel_validation  # noqa: E402


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
        description="S2-M2 publish s2-m2-kernel-driver-validation.json from collected facts"
    )
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--facts", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--compat-output", type=Path)
    parser.add_argument("--cli-profile", default="ai370")
    parser.add_argument("--mode", default="safe")
    parser.add_argument("--persistence", default="runtime")
    parser.add_argument("--dry-run", choices=("true", "false"), default="false")
    args = parser.parse_args()

    profile = _load_required_profile(args.profile)
    facts = json.loads(args.facts.read_text(encoding="utf-8"))
    if not isinstance(facts, dict):
        print(f"[ERROR] Facts file is not a JSON object: {args.facts}", file=sys.stderr)
        raise SystemExit(2)

    report = kernel_validation.build_s2_m2_kernel_driver_validation(
        profile,
        facts=facts,
        cli_profile=args.cli_profile,
        mode=args.mode,
        persistence=args.persistence,
        dry_run=args.dry_run == "true",
    )
    kernel_validation.publish_s2_m2_kernel_driver_validation(
        args.output,
        report,
        compat_output=args.compat_output,
    )
    print(f"[INFO] S2-M2 kernel driver validation written to {args.output}")
    if args.compat_output:
        print(f"[INFO] Compatibility tier1-kernel-plan.json written to {args.compat_output}")
    print(f"[INFO] S2-M2 status: {report['status']}")
    if report["status"] == "FAIL":
        raise SystemExit(3)


if __name__ == "__main__":
    main()
