#!/usr/bin/env python3
"""S2-M5: validate and atomically publish the optimization plan."""

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


def main() -> None:
    parser = argparse.ArgumentParser(
        description="S2-M5 publish s2-m5-optimization-plan.json from collected facts"
    )
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--facts", required=True, type=Path, help="Plan facts JSON")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--compat-output", type=Path)
    parser.add_argument("--compat-markdown", type=Path)
    parser.add_argument("--markdown-swap", default="", help="Live swapon text for markdown")
    parser.add_argument("--markdown-nvme", default="", help="Live NVMe text for markdown")
    parser.add_argument("--cli-profile", default="ai370")
    parser.add_argument("--mode", default="safe")
    parser.add_argument("--persistence", default="runtime")
    args = parser.parse_args()

    profile = _load_required_profile(args.profile)
    facts = json.loads(args.facts.read_text(encoding="utf-8"))
    if not isinstance(facts, dict):
        print(f"[ERROR] Facts file is not a JSON object: {args.facts}", file=sys.stderr)
        raise SystemExit(2)

    plan = optimization_plan.build_s2_m5_optimization_plan(
        profile,
        facts=facts,
        cli_profile=args.cli_profile,
        mode=args.mode,
        persistence=args.persistence,
    )
    markdown = optimization_plan.plan_markdown(
        plan, swap_show=args.markdown_swap, nvme=args.markdown_nvme
    )
    optimization_plan.publish_s2_m5_optimization_plan(
        args.output,
        plan,
        compat_output=args.compat_output,
        compat_markdown=args.compat_markdown,
        markdown_text=markdown,
    )
    print(f"[INFO] S2-M5 optimization plan written to {args.output}")
    if args.compat_output:
        print(f"[INFO] Compatibility tier1-platform-tuning.json written to {args.compat_output}")
    print(f"[INFO] S2-M5 status: {plan['status']}")
    if plan["status"] == "FAIL":
        raise SystemExit(3)


if __name__ == "__main__":
    main()
