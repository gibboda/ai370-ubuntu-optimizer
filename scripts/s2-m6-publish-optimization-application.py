#!/usr/bin/env python3
"""S2-M6: validate and atomically publish the approved optimization application."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import firmware_policy  # noqa: E402
import optimization_plan  # noqa: E402


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


def _load_optional_plan(path: Path | None) -> dict | None:
    if path is None or not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def main() -> None:
    parser = argparse.ArgumentParser(
        description="S2-M6 publish s2-m6-optimization-application.json after --approve"
    )
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--plan", type=Path, help="Consumed s2-m5-optimization-plan.json")
    parser.add_argument("--compat-output", type=Path)
    parser.add_argument("--cli-profile", default="ai370")
    parser.add_argument("--dry-run", choices=("true", "false"), default="false")
    parser.add_argument("--applied", choices=("true", "false"), default="false")
    parser.add_argument(
        "--commands",
        default=optimization_plan.COMMANDS_RELATIVE,
        help="Relative path of the generated command script",
    )
    args = parser.parse_args()

    profile = _load_required_profile(args.profile)
    plan = _load_optional_plan(args.plan)
    application = optimization_plan.build_s2_m6_optimization_application(
        profile,
        plan=plan,
        cli_profile=args.cli_profile,
        dry_run=args.dry_run == "true",
        applied=args.applied == "true",
        commands=args.commands,
    )
    optimization_plan.publish_s2_m6_optimization_application(
        args.output,
        application,
        plan=plan,
        compat_output=args.compat_output,
    )
    print(f"[INFO] S2-M6 optimization application written to {args.output}")
    print(f"[INFO] S2-M6 status: {application['status']}")
    if application["status"] == "FAIL":
        raise SystemExit(3)


if __name__ == "__main__":
    main()
