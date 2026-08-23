#!/usr/bin/env python3
"""require_tier123_pass prefers S2-M7 and falls back to tier1-validation.json."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ORCHESTRATOR = ROOT / "ai370-optimize.sh"


def _extract_function(source: str, name: str) -> str:
    token = f"{name}() {{"
    start = source.index(token)
    depth = 0
    for index, char in enumerate(source[start:], start):
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start : index + 1]
    raise AssertionError(f"unclosed function {name}")


def _write_json(path: Path, status: str) -> None:
    path.write_text(json.dumps({"status": status}) + "\n", encoding="utf-8")


def _run_gate(reports_dir: Path) -> subprocess.CompletedProcess[str]:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    script = "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            f'PROJECT_ROOT="{ROOT}"',
            f'AI370_REPORTS_DIR="{reports_dir}"',
            "export PROJECT_ROOT AI370_REPORTS_DIR",
            _extract_function(source, "json_status"),
            _extract_function(source, "require_tier123_pass"),
            "require_tier123_pass",
        ]
    )
    return subprocess.run(
        ["bash", "-s"],
        input=script,
        text=True,
        cwd=ROOT,
        capture_output=True,
        check=False,
        env={**os.environ, "AI370_REPORTS_DIR": str(reports_dir)},
    )


class RequireTier123PassGateTests(unittest.TestCase):
    def _seed_runtime_reports(self, reports_dir: Path) -> None:
        _write_json(reports_dir / "tier2-validation.json", "PASS")
        _write_json(reports_dir / "offline-model-storage.json", "PASS")
        _write_json(reports_dir / "tier3-validation.json", "PASS")

    def test_prefers_s2_m7_pass_without_compat_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            self._seed_runtime_reports(reports_dir)
            _write_json(reports_dir / "s2-m7-platform-validation.json", "PASS")
            result = _run_gate(reports_dir)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)

    def test_prefers_s2_m7_over_compat_pass(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            self._seed_runtime_reports(reports_dir)
            _write_json(reports_dir / "s2-m7-platform-validation.json", "FAIL")
            _write_json(reports_dir / "tier1-validation.json", "PASS")
            result = _run_gate(reports_dir)
            self.assertEqual(result.returncode, 3, result.stderr + result.stdout)
            self.assertIn("s2-m7", result.stderr)

    def test_falls_back_to_tier1_validation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            self._seed_runtime_reports(reports_dir)
            _write_json(reports_dir / "tier1-validation.json", "PASS")
            result = _run_gate(reports_dir)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)

    def test_missing_platform_report_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            reports_dir = Path(directory)
            self._seed_runtime_reports(reports_dir)
            result = _run_gate(reports_dir)
            self.assertEqual(result.returncode, 3, result.stderr + result.stdout)
            self.assertIn("s2-m7-platform-validation.json", result.stderr)


if __name__ == "__main__":
    unittest.main()
