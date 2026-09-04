#!/usr/bin/env python3
"""Portable contract tests for scripts/external-agent."""

from __future__ import annotations

import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WRAPPER = ROOT / "scripts/external-agent"
REPO_ROOT = subprocess.check_output(
    ["git", "rev-parse", "--show-toplevel"],
    cwd=ROOT,
    text=True,
).strip()

_STUB_TEMPLATE = """#!/bin/sh
echo "AGENT={agent}"
echo "ARGS:$*"
echo "CWD:$(pwd)"
"""


class ExternalAgentTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmpdir.cleanup)
        self.stub_bin = Path(self._tmpdir.name) / "bin"
        self.stub_bin.mkdir()
        for agent in ("grok", "agy"):
            stub = self.stub_bin / agent
            stub.write_text(_STUB_TEMPLATE.format(agent=agent), encoding="utf-8")
            stub.chmod(
                stub.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH
            )

    def _run(
        self,
        *args: str,
        cwd: Path | None = None,
        include_stubs: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        path_parts = [str(self.stub_bin)] if include_stubs else []
        env["PATH"] = os.pathsep.join(path_parts + ["/usr/bin", "/bin"])
        return subprocess.run(
            [str(WRAPPER), *args],
            cwd=cwd or ROOT,
            capture_output=True,
            text=True,
            env=env,
        )

    def test_rejects_unsupported_agent(self) -> None:
        for name in ("cursor", "copilot", "grok;agy", "antigravity", "Antigravity"):
            with self.subTest(name=name):
                completed = self._run(name)
                self.assertEqual(completed.returncode, 64)
                self.assertIn("unsupported external agent", completed.stderr)
                self.assertIn("expected grok or agy", completed.stderr)

    def test_missing_cli_fails_closed(self) -> None:
        for agent in ("grok", "agy"):
            with self.subTest(agent=agent):
                completed = self._run(agent, include_stubs=False)
                self.assertEqual(completed.returncode, 127)
                self.assertIn(
                    f"{agent} is not installed or not on PATH",
                    completed.stderr,
                )

    def test_execs_selected_agent_only(self) -> None:
        completed = self._run("grok", "--", "inspect")
        self.assertEqual(completed.returncode, 0)
        self.assertIn("AGENT=grok", completed.stdout)
        self.assertNotIn("AGENT=agy", completed.stdout)

        completed = self._run("agy", "--", "models")
        self.assertEqual(completed.returncode, 0)
        self.assertIn("AGENT=agy", completed.stdout)

    def test_no_vendor_chaining(self) -> None:
        completed = self._run("grok", "agy", "--", "models")
        self.assertEqual(completed.returncode, 0)
        self.assertIn("AGENT=grok", completed.stdout)
        self.assertIn("ARGS:agy -- models", completed.stdout)

    def test_consumes_leading_double_dash_and_preserves_args(self) -> None:
        completed = self._run("grok", "--", "inspect", "--foo", "bar baz")
        self.assertEqual(completed.returncode, 0)
        self.assertIn("ARGS:inspect --foo bar baz", completed.stdout)

    def test_normalizes_cwd_to_repo_root(self) -> None:
        completed = self._run("grok", "--", "cwd-test", cwd=ROOT / "tests")
        self.assertEqual(completed.returncode, 0)
        self.assertIn(f"CWD:{REPO_ROOT}", completed.stdout)


if __name__ == "__main__":
    unittest.main()
