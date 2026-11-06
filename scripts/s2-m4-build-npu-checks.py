#!/usr/bin/env python3
"""Build S2-M4 NPU visibility checks JSON from reports/latest inventory artifacts.

Internal helper CLI: ``s2-m4-validate-npu-stack.sh`` loads the Stage 1 profile
before invoking this script. Exempt from loading the Stage 1 profile itself (see
``scripts/AGENTS.md``).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import npu_visibility_checks  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="S2-M4 build npu visibility checks payload")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--latest-dir", type=Path, default=Path("reports/latest"))
    parser.add_argument("--module-present", choices=("true", "false"), default="false")
    parser.add_argument("--device-nodes-present", choices=("true", "false"), default="false")
    parser.add_argument("--module-text", default="")
    parser.add_argument("--device-text", default="")
    args = parser.parse_args()
    payload = npu_visibility_checks.build_checks_payload(
        args.latest_dir.resolve(),
        module_present=args.module_present == "true",
        device_nodes_present=args.device_nodes_present == "true",
        module_text=args.module_text,
        device_text=args.device_text,
    )
    args.output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
