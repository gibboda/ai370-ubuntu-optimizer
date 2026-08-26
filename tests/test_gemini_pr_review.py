#!/usr/bin/env python3
"""Deterministic tests for S5-M6 independent Gemini / Antigravity PR review."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import unittest
from io import BytesIO, StringIO
from pathlib import Path
from typing import Any
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import gemini_pr_review as gemini  # noqa: E402
import grok_pr_review as grok  # noqa: E402

FIXTURES = ROOT / "tests" / "fixtures" / "grok-review"


def load_json(name: str) -> Any:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


class AntigravityConfigTests(unittest.TestCase):
    def test_settings_pin_gemini_provider_without_secrets(self) -> None:
        settings_path = ROOT / ".github/antigravity/settings.json"
        self.assertTrue(settings_path.is_file(), settings_path)
        raw = settings_path.read_text(encoding="utf-8")
        self.assertNotRegex(raw, r"AIza[0-9A-Za-z_-]+")
        self.assertNotIn("GEMINI_API_KEY", raw)
        payload = json.loads(raw)
        self.assertEqual(payload, {"modelProvider": "gemini"})

    def test_home_directory_settings_are_not_committed(self) -> None:
        gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
        self.assertIn(".gemini/", gitignore)
        self.assertFalse((ROOT / ".gemini").exists())
        self.assertFalse(
            (ROOT / ".gemini/antigravity-cli/settings.json").exists()
        )

    def test_shared_policy_and_schema_are_reused(self) -> None:
        self.assertEqual(gemini.DEFAULT_POLICY, grok.DEFAULT_POLICY)
        self.assertEqual(gemini.DEFAULT_SCHEMA, grok.DEFAULT_SCHEMA)
        self.assertTrue(gemini.DEFAULT_PROMPT.is_file())
        prompt = gemini.DEFAULT_PROMPT.read_text(encoding="utf-8")
        self.assertIn("calls the Gemini API directly", prompt)
        self.assertNotIn("Antigravity TUI in CI", prompt)
        self.assertIn("not the Antigravity TUI", prompt)

    def test_env_overrides_do_not_require_code_changes(self) -> None:
        config = gemini.load_config(
            env={
                "GEMINI_MODEL": "gemini-2.5-pro",
                "MAX_DIFF_CHARS": "1234",
                "MAX_FINDINGS": "7",
                "MIN_CONFIDENCE": "0.77",
            }
        )
        self.assertEqual(config["gemini_model"], "gemini-2.5-pro")
        self.assertEqual(config["max_diff_chars"], 1234)
        self.assertEqual(config["max_findings"], 7)
        self.assertEqual(config["min_confidence"], 0.77)

    def test_load_config_does_not_copy_api_credentials(self) -> None:
        config = gemini.load_config(
            env={
                "GEMINI_API_KEY": "secret-value",
                "GITHUB_TOKEN": "github-token-value",
                "GEMINI_MODEL": "gemini-2.5-pro",
            }
        )
        dumped = json.dumps(config)
        self.assertNotIn("secret-value", dumped)
        self.assertNotIn("github-token-value", dumped)
        self.assertEqual(config["gemini_model"], "gemini-2.5-pro")

    def test_gemini_endpoint_does_not_embed_the_api_key(self) -> None:
        config = gemini.load_config()
        url = gemini.gemini_endpoint(config)
        self.assertIn("generativelanguage.googleapis.com", url)
        self.assertIn("gemini-3.6-flash", url)
        self.assertNotIn("key=", url)
        self.assertNotIn("{model}", url)


class GeminiCallTests(unittest.TestCase):
    def test_call_gemini_parses_generate_content_json(self) -> None:
        review = load_json("valid-pass.json")
        response = {
            "candidates": [
                {"content": {"parts": [{"text": json.dumps(review)}]}}
            ]
        }
        with mock.patch.object(grok, "_http_json", return_value=response) as http:
            parsed = gemini.call_gemini(
                system="trusted",
                user="untrusted",
                config=gemini.load_config(),
                schema=grok.load_schema(),
                api_key="secret-value",
            )
        self.assertEqual(parsed["verdict"], "pass")
        request = http.call_args
        headers = request.kwargs["headers"]
        self.assertEqual(headers["x-goog-api-key"], "secret-value")
        self.assertNotIn("key=", request.args[0])
        body = request.kwargs["body"]
        self.assertEqual(body["generationConfig"]["responseMimeType"], "application/json")
        self.assertEqual(body["generationConfig"]["responseSchema"]["type"], "OBJECT")

    def test_http_error_does_not_echo_api_key(self) -> None:
        error = grok.urllib.error.HTTPError(
            "https://generativelanguage.googleapis.com/v1beta/models/x:generateContent",
            400,
            "Bad Request",
            {},
            BytesIO(b'{"error":{"message":"API key not valid secret-value"}}'),
        )
        with mock.patch.object(grok.urllib.request, "urlopen", side_effect=error):
            with self.assertRaises(grok.ReviewError) as raised:
                grok._http_json(
                    "https://generativelanguage.googleapis.com/v1beta/models/x:generateContent",
                    method="POST",
                    headers={"x-goog-api-key": "secret-value"},
                    body={"contents": []},
                    secrets=["secret-value"],
                )
        self.assertNotIn("secret-value", str(raised.exception))
        self.assertTrue(grok.is_invalid_api_key(raised.exception))


class PublishAndCliTests(unittest.TestCase):
    def isolated_env(self, **extra: str) -> dict[str, str]:
        env = os.environ.copy()
        for key in (
            "GEMINI_API_KEY",
            "GEMINI_MODEL",
            "GEMINI_API_URL",
            "MAX_DIFF_CHARS",
            "MAX_FINDINGS",
            "MIN_CONFIDENCE",
            "GITHUB_TOKEN",
            "GITHUB_EVENT_PATH",
            "GITHUB_REPOSITORY",
            "GEMINI_REVIEW_ENABLED",
            "GEMINI_REVIEW_SKIP_FORK",
            "XAI_API_KEY",
        ):
            env.pop(key, None)
        env.update(extra)
        return env

    def test_cli_offline_review_skips_publish(self) -> None:
        completed = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts/gemini_pr_review.py"),
                "--pr-meta",
                str(FIXTURES / "pr-meta.json"),
                "--diff-file",
                str(FIXTURES / "sample.diff"),
                "--offline-response",
                str(FIXTURES / "valid-critical.json"),
                "--skip-publish",
            ],
            check=False,
            capture_output=True,
            text=True,
            cwd=ROOT,
            env=self.isolated_env(),
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        payload = json.loads(completed.stdout)
        self.assertEqual(payload["outcome"], "changes_requested")
        self.assertTrue(payload["skipped"])

    def test_cli_disabled_skips(self) -> None:
        completed = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts/gemini_pr_review.py"),
                "--base-sha",
                "a",
                "--head-sha",
                "b",
                "--diff-file",
                str(FIXTURES / "sample.diff"),
            ],
            check=False,
            capture_output=True,
            text=True,
            cwd=ROOT,
            env=self.isolated_env(GEMINI_REVIEW_ENABLED="false"),
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        payload = json.loads(completed.stdout)
        self.assertEqual(payload["reason"], "disabled")

    def test_cli_print_prompt_does_not_dump_untrusted_text(self) -> None:
        completed = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts/gemini_pr_review.py"),
                "--pr-meta",
                str(FIXTURES / "pr-meta.json"),
                "--diff-file",
                str(FIXTURES / "sample.diff"),
                "--print-prompt",
            ],
            check=False,
            capture_output=True,
            text=True,
            cwd=ROOT,
            env=self.isolated_env(),
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertNotIn("Ignore previous instructions", completed.stdout)
        self.assertNotIn("apt-get install", completed.stdout)
        payload = json.loads(completed.stdout)
        self.assertGreater(payload["system_chars"], 0)
        self.assertGreater(payload["user_chars"], 0)
        self.assertTrue(payload["untrusted_wrapped"])

    def test_cli_missing_key_skips_without_calling_network(self) -> None:
        completed = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts/gemini_pr_review.py"),
                "--pr-meta",
                str(FIXTURES / "pr-meta.json"),
                "--diff-file",
                str(FIXTURES / "sample.diff"),
            ],
            check=False,
            capture_output=True,
            text=True,
            cwd=ROOT,
            env=self.isolated_env(),
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        payload = json.loads(completed.stdout)
        self.assertEqual(payload["reason"], "missing_gemini_api_key")

    def test_cli_fork_pr_skips_without_calling_gemini(self) -> None:
        completed = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts/gemini_pr_review.py"),
                "--pr-meta",
                str(FIXTURES / "fork-pr-meta.json"),
                "--diff-file",
                str(FIXTURES / "sample.diff"),
            ],
            check=False,
            capture_output=True,
            text=True,
            cwd=ROOT,
            env=self.isolated_env(
                GITHUB_REPOSITORY="gibboda/ai370-ubuntu-optimizer",
                GEMINI_API_KEY="should-not-be-used",
            ),
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        payload = json.loads(completed.stdout)
        self.assertEqual(payload["reason"], "fork_pull_request")

    def test_cli_invalid_api_key_soft_skips(self) -> None:
        env = self.isolated_env(GEMINI_API_KEY="bad-key")
        buffer = StringIO()
        with mock.patch.dict(os.environ, env, clear=True):
            with mock.patch.object(
                grok,
                "run_review",
                side_effect=grok.ReviewError(
                    "HTTP 400 calling https://generativelanguage.googleapis.com/"
                    'v1beta/models/x:generateContent: {"error":{"message":'
                    '"API key not valid. Please pass a valid API key.",'
                    '"status":"INVALID_ARGUMENT"}}'
                ),
            ):
                with mock.patch("sys.stdout", new=buffer):
                    code = gemini.main(
                        [
                            "--pr-meta",
                            str(FIXTURES / "pr-meta.json"),
                            "--diff-file",
                            str(FIXTURES / "sample.diff"),
                            "--skip-publish",
                        ]
                    )
        self.assertEqual(code, 0)
        payload = json.loads(buffer.getvalue())
        self.assertTrue(payload["skipped"])
        self.assertEqual(payload["reason"], "gemini_api_key_invalid")

    def test_cli_quota_exhausted_soft_skips(self) -> None:
        env = self.isolated_env(GEMINI_API_KEY="ok-key")
        buffer = StringIO()
        with mock.patch.dict(os.environ, env, clear=True):
            with mock.patch.object(
                grok,
                "run_review",
                side_effect=grok.ReviewError(
                    "HTTP 429 calling https://generativelanguage.googleapis.com/"
                    "v1beta/models/x:generateContent: RESOURCE_EXHAUSTED"
                ),
            ):
                with mock.patch("sys.stdout", new=buffer):
                    code = gemini.main(
                        [
                            "--pr-meta",
                            str(FIXTURES / "pr-meta.json"),
                            "--diff-file",
                            str(FIXTURES / "sample.diff"),
                            "--skip-publish",
                        ]
                    )
        self.assertEqual(code, 0)
        payload = json.loads(buffer.getvalue())
        self.assertEqual(payload["reason"], "gemini_quota_exhausted")

    def test_cli_retired_model_soft_skips(self) -> None:
        error = grok.ReviewError(
            "HTTP 404 calling https://generativelanguage.googleapis.com/"
            "v1beta/models/gemini-2.5-flash:generateContent: "
            '{"error":{"code":404,"message":"This model models/gemini-2.5-flash '
            'is no longer available to new users. Please update your code to '
            'use models/gemini-3.6-flash for the latest features and '
            'improvements.","status":"NOT_FOUND"}}'
        )
        self.assertTrue(grok.is_model_unavailable(error))
        env = self.isolated_env(GEMINI_API_KEY="ok-key")
        buffer = StringIO()
        with mock.patch.dict(os.environ, env, clear=True):
            with mock.patch.object(grok, "run_review", side_effect=error):
                with mock.patch("sys.stdout", new=buffer):
                    code = gemini.main(
                        [
                            "--pr-meta",
                            str(FIXTURES / "pr-meta.json"),
                            "--diff-file",
                            str(FIXTURES / "sample.diff"),
                            "--skip-publish",
                        ]
                    )
        self.assertEqual(code, 0)
        payload = json.loads(buffer.getvalue())
        self.assertEqual(payload["reason"], "gemini_model_unavailable")

    def test_permission_denied_key_is_detected(self) -> None:
        denied = grok.ReviewError(
            "HTTP 403 calling https://generativelanguage.googleapis.com/"
            "v1beta/models/gemini-3.6-flash:generateContent: "
            '{"error":{"code":403,"message":"The caller does not have '
            'permission","status":"PERMISSION_DENIED"}}'
        )
        github_forbidden = grok.ReviewError(
            "HTTP 403 calling https://api.github.com/repos/x/pulls/1/reviews: "
            '{"message":"Resource not accessible by integration"}'
        )
        org_policy = grok.ReviewError(
            "HTTP 403 calling https://generativelanguage.googleapis.com/"
            'v1beta/models/x:generateContent: {"error":{"code":403,'
            '"message":"Request blocked by organization policy"}}'
        )
        invalid = grok.ReviewError(
            "HTTP 400 calling https://generativelanguage.googleapis.com/"
            'v1beta/models/x:generateContent: {"error":{"message":'
            '"API key not valid. Please pass a valid API key.",'
            '"status":"INVALID_ARGUMENT"}}'
        )
        self.assertTrue(gemini.is_gemini_permission_denied(denied))
        self.assertFalse(grok.is_invalid_api_key(denied))
        self.assertFalse(grok.is_quota_exhausted(denied))
        self.assertFalse(gemini.is_gemini_permission_denied(github_forbidden))
        self.assertFalse(gemini.is_gemini_permission_denied(org_policy))
        self.assertFalse(gemini.is_gemini_permission_denied(invalid))

    def test_cli_permission_denied_key_soft_skips(self) -> None:
        env = self.isolated_env(GEMINI_API_KEY="restricted-key")
        buffer = StringIO()
        with mock.patch.dict(os.environ, env, clear=True):
            with mock.patch.object(
                grok,
                "run_review",
                side_effect=grok.ReviewError(
                    "HTTP 403 calling https://generativelanguage.googleapis.com/"
                    "v1beta/models/gemini-3.6-flash:generateContent: "
                    '{"error":{"code":403,"message":"The caller does not have '
                    'permission","status":"PERMISSION_DENIED"}}'
                ),
            ):
                with mock.patch("sys.stdout", new=buffer):
                    code = gemini.main(
                        [
                            "--pr-meta",
                            str(FIXTURES / "pr-meta.json"),
                            "--diff-file",
                            str(FIXTURES / "sample.diff"),
                            "--skip-publish",
                        ]
                    )
        self.assertEqual(code, 0)
        payload = json.loads(buffer.getvalue())
        self.assertTrue(payload["skipped"])
        self.assertEqual(payload["reason"], "gemini_api_key_permission_denied")

    def test_cli_unrelated_forbidden_does_not_soft_skip(self) -> None:
        env = self.isolated_env(GEMINI_API_KEY="ok-key")
        buffer = StringIO()
        with mock.patch.dict(os.environ, env, clear=True):
            with mock.patch.object(
                grok,
                "run_review",
                side_effect=grok.ReviewError(
                    "HTTP 403 calling https://generativelanguage.googleapis.com/"
                    'v1beta/models/x:generateContent: {"error":{"message":'
                    '"Request blocked by organization policy"}}'
                ),
            ):
                with mock.patch("sys.stdout", new=buffer):
                    code = gemini.main(
                        [
                            "--pr-meta",
                            str(FIXTURES / "pr-meta.json"),
                            "--diff-file",
                            str(FIXTURES / "sample.diff"),
                            "--skip-publish",
                        ]
                    )
        self.assertEqual(code, 1)
        payload = json.loads(buffer.getvalue())
        self.assertEqual(payload["reason"], "review_failed")


class WorkflowContractTests(unittest.TestCase):
    def test_gemini_workflow_is_repository_owned_and_least_privilege(self) -> None:
        workflow = (ROOT / ".github/workflows/gemini-pr-review.yml").read_text(
            encoding="utf-8"
        )
        self.assertNotRegex(workflow, r"(?m)^[ \t]*pull_request_target:")
        self.assertNotRegex(workflow, r"(?m)^[ \t]*- pull_request_target\s*$")
        self.assertIn("cancel-in-progress: true", workflow)
        self.assertIn("scripts/gemini_pr_review.py", workflow)
        self.assertIn("secrets.GEMINI_API_KEY", workflow)
        self.assertIn("contents: read", workflow)
        self.assertIn("pull-requests: write", workflow)
        self.assertNotIn("contents: write", workflow)
        self.assertNotIn("issues: write", workflow)
        self.assertNotRegex(workflow, r"(?m)^[ \t]*persist-credentials:\s*false\s*$")
        self.assertIn("github.event.pull_request.base.sha", workflow)
        self.assertIn("Check out trusted review machinery", workflow)
        self.assertIn("overlaying from the PR head (bootstrap only)", workflow)
        self.assertNotIn("agy", workflow)
        self.assertNotIn("antigravity.google/cli/install", workflow)
        self.assertNotRegex(workflow, r"uses:\s+(?!actions/checkout@)")

    def test_portable_tests_workflow_does_not_call_gemini(self) -> None:
        workflow = (ROOT / ".github/workflows/portable-tests.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("tests.test_gemini_pr_review", workflow)
        self.assertNotIn("GEMINI_API_KEY", workflow)
        self.assertIn("contents: read", workflow)
        self.assertNotIn("pull-requests: write", workflow)

    def test_policy_and_prompt_live_outside_workflow_yaml(self) -> None:
        self.assertTrue((ROOT / ".github/antigravity/review_prompt.md").is_file())
        self.assertTrue((ROOT / ".github/antigravity/README.md").is_file())
        workflow = (ROOT / ".github/workflows/gemini-pr-review.yml").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("You are an independent pull-request reviewer", workflow)


if __name__ == "__main__":
    unittest.main()
