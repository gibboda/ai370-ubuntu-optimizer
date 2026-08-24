#!/usr/bin/env python3
"""S5-M6: compute GitHub issue/PR label mutations from a checked-in policy."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_POLICY = ROOT / ".github" / "label-policy.json"

TITLE_RE = re.compile(
    r"^(?P<type>feat|fix|chore|refactor|docs|test|ci|perf)"
    r"(?:\((?P<scope>[^)]+)\))?(?P<breaking>!)?: "
)
AREA_HEADING_RE = re.compile(r"^#{1,6}\s+Area\s*$", re.IGNORECASE | re.MULTILINE)


def load_policy(path: Path | None = None) -> dict[str, Any]:
    policy_path = path or DEFAULT_POLICY
    return json.loads(policy_path.read_text(encoding="utf-8"))


def glob_to_regex(pattern: str) -> re.Pattern[str]:
    """Convert a limited glob (`*`, `**`, `?`) to a full-match regex."""
    out: list[str] = ["^"]
    i = 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
            continue
        if pattern.startswith("**", i):
            out.append(".*")
            i += 2
            continue
        char = pattern[i]
        if char == "*":
            out.append("[^/]*")
        elif char == "?":
            out.append("[^/]")
        else:
            out.append(re.escape(char))
        i += 1
    out.append("$")
    return re.compile("".join(out))


def path_matches(path: str, pattern: str) -> bool:
    normalized = path.replace("\\", "/").lstrip("./")
    return glob_to_regex(pattern).match(normalized) is not None


def parse_conventional_title(title: str) -> dict[str, str] | None:
    match = TITLE_RE.match(title.strip())
    if match is None:
        return None
    return {
        "type": match.group("type"),
        "scope": match.group("scope") or "",
        "breaking": match.group("breaking") or "",
    }


def parse_issue_area(body: str, policy: dict[str, Any]) -> str | None:
    if not body:
        return None
    heading = AREA_HEADING_RE.search(body)
    if heading is None:
        return None
    rest = body[heading.end() :]
    for line in rest.splitlines():
        choice = line.strip()
        if not choice:
            continue
        choices: dict[str, str | None] = policy["issue_area_choices"]
        if choice in choices:
            return choices[choice]
        lowered = {key.casefold(): value for key, value in choices.items()}
        return lowered.get(choice.casefold())
    return None


def labels_for_pr_title(title: str, policy: dict[str, Any]) -> list[str]:
    parsed = parse_conventional_title(title)
    if parsed is None:
        return []
    labels = list(policy["title_type_labels"].get(parsed["type"], []))
    if parsed["breaking"]:
        labels = [label for label in labels if not label.startswith("bump:")]
        labels.append("bump:major")
    scope_labels = policy["title_scope_labels"].get(parsed["scope"], [])
    for label in scope_labels:
        if label not in labels:
            labels.append(label)
    return labels


def labels_for_paths(files: list[str], policy: dict[str, Any]) -> list[str]:
    labels: list[str] = []
    for rule in policy["path_labels"]:
        if any(path_matches(path, glob) for path in files for glob in rule["globs"]):
            if rule["label"] not in labels:
                labels.append(rule["label"])
    return labels


def labels_for_issue_title(title: str, policy: dict[str, Any]) -> list[str]:
    stripped = title.strip()
    labels: list[str] = []
    for prefix, prefix_labels in policy["issue_title_prefixes"].items():
        if stripped.startswith(prefix):
            for label in prefix_labels:
                if label not in labels:
                    labels.append(label)
    return labels


def should_skip(event: dict[str, Any], policy: dict[str, Any]) -> bool:
    title = (event.get("title") or "").strip()
    for prefix in policy["skip_title_prefixes"]:
        if title.startswith(prefix):
            return True
    current = set(event.get("current_labels") or [])
    return bool(current.intersection(policy["skip_labels"]))


def compute_mutations(
    event: dict[str, Any], policy: dict[str, Any] | None = None
) -> dict[str, Any]:
    loaded = policy or load_policy()
    action = event.get("action") or ""
    kind = event.get("kind") or ""
    current = set(event.get("current_labels") or [])
    apply: set[str] = set()
    remove: set[str] = set()

    if should_skip(event, loaded):
        return {"apply": [], "remove": [], "skip": True}

    if kind == "issue" and action in {"opened", "reopened", "edited"}:
        apply.update(labels_for_issue_title(event.get("title") or "", loaded))
        if action in {"opened", "reopened"}:
            apply.add("needs-triage")
        area = parse_issue_area(event.get("body") or "", loaded)
        if area:
            apply.add(area)
        if action == "reopened":
            remove.update({"wontfix", "duplicate"})

    if kind == "pull_request" and action in {
        "opened",
        "reopened",
        "edited",
        "synchronize",
    }:
        desired = set(labels_for_pr_title(event.get("title") or "", loaded))
        desired.update(labels_for_paths(list(event.get("files") or []), loaded))
        apply.update(desired)

        desired_bumps = desired.intersection(loaded["bump_labels"])
        if desired_bumps:
            remove.update(set(loaded["bump_labels"]) - desired_bumps)

        desired_types = desired.intersection(loaded["pr_type_labels"])
        if desired_types:
            remove.update(set(loaded["pr_type_labels"]) - desired_types)
        elif parse_conventional_title(event.get("title") or ""):
            remove.update(loaded["pr_type_labels"])

    if action == "closed":
        remove.update(loaded["queue_labels"])
        if kind == "issue":
            reason = event.get("state_reason")
            if reason == "not_planned":
                apply.add("wontfix")
            elif reason == "duplicate":
                apply.add("duplicate")

    apply -= current
    remove &= current
    remove -= apply
    return {
        "apply": sorted(apply),
        "remove": sorted(remove),
        "skip": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="S5-M6: compute GitHub label apply/remove mutations"
    )
    parser.add_argument(
        "--input",
        default="-",
        help="Event JSON path, or - for stdin",
    )
    parser.add_argument(
        "--policy",
        type=Path,
        default=DEFAULT_POLICY,
        help="Label policy JSON path",
    )
    args = parser.parse_args()
    raw = sys.stdin.read() if args.input == "-" else Path(args.input).read_text(
        encoding="utf-8"
    )
    event = json.loads(raw)
    result = compute_mutations(event, load_policy(args.policy))
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
