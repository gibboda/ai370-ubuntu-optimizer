#!/usr/bin/env python3
"""S5-M6: repository-owned Gemini / Antigravity pull-request review orchestrator.

This module collects PR context, calls the Gemini API directly, schema-validates
the response, applies deterministic governance thresholds, and publishes a
GitHub pull-request review. It does not install or execute the Antigravity TUI.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

import grok_pr_review as grok

OWNER = grok.OWNER
ROOT = grok.ROOT
ANTIGRAVITY_DIR = ROOT / ".github" / "antigravity"
DEFAULT_CONFIG = ANTIGRAVITY_DIR / "config.json"
DEFAULT_SCHEMA = grok.DEFAULT_SCHEMA
DEFAULT_POLICY = grok.DEFAULT_POLICY
DEFAULT_PROMPT = ANTIGRAVITY_DIR / "review_prompt.md"
PRODUCT = "Gemini/Antigravity"


def load_config(
    path: Path | None = None, env: dict[str, str] | None = None
) -> dict[str, Any]:
    config = grok._read_json(path or DEFAULT_CONFIG)
    environ = env if env is not None else os.environ
    model = (environ.get("GEMINI_MODEL") or "").strip()
    if model:
        config["gemini_model"] = model
    api_url = (environ.get("GEMINI_API_URL") or "").strip()
    if api_url:
        config["gemini_api_url"] = api_url
    if (environ.get("MAX_DIFF_CHARS") or "").strip():
        config["max_diff_chars"] = int(environ["MAX_DIFF_CHARS"])
    if (environ.get("MAX_CHUNK_CHARS") or "").strip():
        config["max_chunk_chars"] = int(environ["MAX_CHUNK_CHARS"])
    if (environ.get("MAX_FINDINGS") or "").strip():
        config["max_findings"] = int(environ["MAX_FINDINGS"])
    if (environ.get("MIN_CONFIDENCE") or "").strip():
        config["min_confidence"] = float(environ["MIN_CONFIDENCE"])
    return config


def gemini_schema(schema: dict[str, Any]) -> dict[str, Any]:
    """Build a Gemini responseSchema from the shared review JSON schema."""
    finding = schema["properties"]["findings"]["items"]
    return {
        "type": "OBJECT",
        "required": ["verdict", "summary", "findings"],
        "properties": {
            "verdict": {
                "type": "STRING",
                "enum": list(schema["properties"]["verdict"]["enum"]),
            },
            "summary": {"type": "STRING"},
            "findings": {
                "type": "ARRAY",
                "items": {
                    "type": "OBJECT",
                    "required": list(finding["required"]),
                    "properties": {
                        "severity": {
                            "type": "STRING",
                            "enum": list(finding["properties"]["severity"]["enum"]),
                        },
                        "category": {
                            "type": "STRING",
                            "enum": list(finding["properties"]["category"]["enum"]),
                        },
                        "confidence": {"type": "NUMBER"},
                        "file": {"type": "STRING", "nullable": True},
                        "line": {"type": "INTEGER", "nullable": True},
                        "title": {"type": "STRING"},
                        "description": {"type": "STRING"},
                        "recommendation": {"type": "STRING"},
                    },
                },
            },
        },
    }


def gemini_endpoint(config: dict[str, Any]) -> str:
    url = str(config["gemini_api_url"])
    model = str(config["gemini_model"])
    return url.replace("{model}", model)


def _gemini_text(response: Any) -> str:
    if not isinstance(response, dict):
        raise grok.ReviewError("Gemini response is not a JSON object")
    feedback = response.get("promptFeedback")
    if isinstance(feedback, dict) and feedback.get("blockReason"):
        raise grok.ReviewError(
            f"Gemini blocked the prompt: {feedback.get('blockReason')}"
        )
    candidates = response.get("candidates")
    if not isinstance(candidates, list) or not candidates:
        raise grok.ReviewError("Gemini response is missing candidates")
    content = (
        candidates[0].get("content") if isinstance(candidates[0], dict) else None
    )
    if not isinstance(content, dict):
        raise grok.ReviewError("Gemini response is missing candidate content")
    parts = content.get("parts")
    if not isinstance(parts, list) or not parts:
        raise grok.ReviewError("Gemini response is missing content parts")
    text = parts[0].get("text") if isinstance(parts[0], dict) else None
    if not isinstance(text, str) or not text.strip():
        raise grok.ReviewError("Gemini message content is not text")
    return text


def call_gemini(
    *,
    system: str,
    user: str,
    config: dict[str, Any],
    schema: dict[str, Any],
    api_key: str,
) -> dict[str, Any]:
    payload = {
        "systemInstruction": {"parts": [{"text": system}]},
        "contents": [{"role": "user", "parts": [{"text": user}]}],
        "generationConfig": {
            "temperature": config.get("temperature", 0),
            "maxOutputTokens": int(config.get("max_output_tokens") or 4096),
            "responseMimeType": "application/json",
            "responseSchema": gemini_schema(schema),
        },
    }
    retries = int(config.get("max_retries") or 0)
    timeout = int(config.get("request_timeout_seconds") or 120)
    url = gemini_endpoint(config)
    last_error: grok.ReviewError | None = None
    for attempt in range(retries + 1):
        try:
            response = grok._http_json(
                url,
                method="POST",
                headers={
                    "x-goog-api-key": api_key,
                    "Content-Type": "application/json",
                    "User-Agent": "ai370-ubuntu-optimizer-gemini-review/1.0",
                },
                body=payload,
                timeout=timeout,
                secrets=[api_key],
            )
            parsed = grok.parse_model_content(_gemini_text(response))
            return grok.validate_review_payload(parsed, schema)
        except grok.ReviewError as exc:
            last_error = exc
            transient = "HTTP 429" in str(exc) or "HTTP 5" in str(exc)
            if not transient or attempt >= retries:
                raise
            time.sleep(2 ** attempt)
    raise last_error or grok.ReviewError("Gemini request failed")


def is_gemini_permission_denied(error: BaseException) -> bool:
    """True when Gemini rejects a valid key that is not allowed to call the API.

    HTTP 403 PERMISSION_DENIED is distinct from an invalid key (400/401) and
    from quota (429). Unrelated 403s, including GitHub publish failures, must
    still fail the job.
    """
    text = str(error).lower()
    if "http 403" not in text:
        return False
    if "generativelanguage.googleapis.com" not in text:
        return False
    markers = (
        "permission_denied",
        "permission denied",
        "caller does not have permission",
        "generative language api has not been used",
        "generativelanguage.googleapis.com are blocked",
        "service_disabled",
        "access not configured",
        "api has not been enabled",
    )
    return any(marker in text for marker in markers)


def review_is_enabled(env: dict[str, str]) -> bool:
    value = env.get("GEMINI_REVIEW_ENABLED", "true").strip().lower()
    return value not in {"0", "false", "no", "off"}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="S5-M6 independent Gemini / Antigravity pull-request review"
    )
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--policy", type=Path, default=DEFAULT_POLICY)
    parser.add_argument("--prompt", type=Path, default=DEFAULT_PROMPT)
    parser.add_argument("--repo", help="owner/name")
    parser.add_argument("--pr", type=int, help="pull request number")
    parser.add_argument("--base-sha")
    parser.add_argument("--head-sha")
    parser.add_argument("--pr-meta", type=Path, help="JSON with title/body/SHAs")
    parser.add_argument("--diff-file", type=Path)
    parser.add_argument("--cwd", type=Path, default=ROOT)
    parser.add_argument(
        "--offline-response",
        type=Path,
        help="Validated against schema instead of calling Gemini",
    )
    parser.add_argument("--print-prompt", action="store_true")
    parser.add_argument("--skip-publish", action="store_true")
    parser.add_argument("--output", type=Path, help="Write decision JSON")
    args = parser.parse_args(argv)

    if not review_is_enabled(os.environ):
        grok.emit_json(grok.skip_result("disabled"))
        return 0

    config = load_config(args.config)
    schema = grok.load_schema(args.schema)
    token = os.environ.get("GITHUB_TOKEN")
    repo = args.repo or os.environ.get("GITHUB_REPOSITORY")
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    meta: dict[str, Any] = {}
    if args.pr_meta:
        meta = grok._load_pr_meta(args.pr_meta)
    elif event_path and Path(event_path).is_file():
        event = grok._read_json(Path(event_path))
        pull = event.get("pull_request") if isinstance(event, dict) else None
        if isinstance(pull, dict):
            head = pull.get("head") if isinstance(pull.get("head"), dict) else {}
            base = pull.get("base") if isinstance(pull.get("base"), dict) else {}
            head_repo = head.get("repo") if isinstance(head.get("repo"), dict) else {}
            meta = {
                "number": pull.get("number"),
                "title": pull.get("title") or "",
                "body": pull.get("body") or "",
                "base_sha": (base or {}).get("sha") or "",
                "head_sha": (head or {}).get("sha") or "",
                "head_repo": (head_repo or {}).get("full_name") or "",
                "draft": bool(pull.get("draft")),
            }
    number = args.pr if args.pr is not None else meta.get("number")
    if not meta and token and repo and number:
        try:
            meta = grok.fetch_pull_request(str(repo), int(number), token)
        except grok.ReviewError as exc:
            print(
                grok.redact_secrets(f"[ERROR] {exc}", grok.credential_values()),
                file=sys.stderr,
            )
            return 1

    head_repo = str(meta.get("head_repo") or "")
    skip_fork = (os.environ.get("GEMINI_REVIEW_SKIP_FORK") or "").strip().lower()
    if skip_fork in {"1", "true", "yes"}:
        grok.emit_json(grok.skip_result("fork_pull_request"))
        return 0
    if repo and head_repo and head_repo != repo:
        grok.emit_json(grok.skip_result("fork_pull_request", head_repo=head_repo))
        print(
            "[INFO] Skipping Gemini review for fork pull requests. Secrets and "
            "write tokens are not used with untrusted fork workflows.",
            file=sys.stderr,
        )
        return 0

    title = str(meta.get("title") or "")
    body = str(meta.get("body") or "")
    base_sha = args.base_sha or str(meta.get("base_sha") or "")
    head_sha = args.head_sha or str(meta.get("head_sha") or "")
    if not base_sha or not head_sha:
        print("[ERROR] base SHA and head SHA are required", file=sys.stderr)
        return 2

    if args.diff_file:
        diff_text = args.diff_file.read_text(encoding="utf-8")
    else:
        diff_text = grok.git_unified_diff(base_sha, head_sha, args.cwd)

    prepared = grok.prepare_review(
        title=title,
        body=body,
        base_sha=base_sha,
        head_sha=head_sha,
        diff_text=diff_text,
        config=config,
        policy_text=args.policy.read_text(encoding="utf-8"),
        prompt_text=args.prompt.read_text(encoding="utf-8"),
    )
    if args.print_prompt:
        if not prepared.chunks:
            grok.emit_json({"reviewable_chunks": 0})
            return 0
        system, user = grok.build_messages(
            prepared, prepared.chunks[0], 0, len(prepared.chunks)
        )
        grok.emit_json(
            {
                "system_chars": len(system),
                "user_chars": len(user),
                "untrusted_wrapped": grok.UNTRUSTED_BEGIN in user
                and grok.UNTRUSTED_END in user,
                "chunk_count": len(prepared.chunks),
            }
        )
        return 0

    api_key = os.environ.get("GEMINI_API_KEY")
    offline = (
        grok._load_offline_responses(args.offline_response)
        if args.offline_response
        else None
    )
    if offline is None and not api_key:
        grok.emit_json(grok.skip_result("missing_gemini_api_key"))
        print(
            "[INFO] Skipping Gemini review because GEMINI_API_KEY is not configured.",
            file=sys.stderr,
        )
        return 0

    try:
        decision = grok.run_review(
            prepared=prepared,
            config=config,
            schema=schema,
            api_key=api_key,
            response_payloads=offline,
            call_model=None if offline is not None else call_gemini,
        )
    except grok.ReviewError as exc:
        if grok.is_invalid_api_key(exc):
            grok.emit_json(grok.skip_result("gemini_api_key_invalid"))
            print(
                "[INFO] Skipping Gemini review because the Gemini API key is "
                "invalid or unauthorized.",
                file=sys.stderr,
            )
            return 0
        if is_gemini_permission_denied(exc):
            grok.emit_json(grok.skip_result("gemini_api_key_permission_denied"))
            print(
                "[INFO] Skipping Gemini review because the Gemini API key is "
                "not authorized for the Generative Language API.",
                file=sys.stderr,
            )
            return 0
        if grok.is_quota_exhausted(exc):
            grok.emit_json(grok.skip_result("gemini_quota_exhausted"))
            print(
                "[INFO] Skipping Gemini review because the Gemini API quota or "
                "rate limit was exceeded.",
                file=sys.stderr,
            )
            return 0
        if grok.is_model_unavailable(exc):
            grok.emit_json(grok.skip_result("gemini_model_unavailable"))
            print(
                "[INFO] Skipping Gemini review because the configured Gemini "
                "model is retired or not found. Set GEMINI_MODEL or edit "
                ".github/antigravity/config.json.",
                file=sys.stderr,
            )
            return 0
        print(
            grok.redact_secrets(f"[ERROR] {exc}", grok.credential_values()),
            file=sys.stderr,
        )
        grok.emit_json(
            {
                "owner": OWNER,
                "skipped": False,
                "published": False,
                "reason": "review_failed",
                "error": grok.redact_secrets(str(exc), grok.credential_values()),
            }
        )
        return 1

    publish_info: dict[str, Any] = {"published": False, "skipped": True}
    if args.skip_publish:
        publish_info = {"published": False, "skipped": True, "reason": "skip_publish"}
    elif token and repo and number:
        try:
            publish_info = grok.publish_review(
                repo=str(repo),
                number=int(number),
                token=token,
                decision=decision,
                prepared=prepared,
                config=config,
                expected_head_sha=head_sha,
                model=str(config["gemini_model"]),
                product=PRODUCT,
            )
        except grok.ReviewError as exc:
            print(
                grok.redact_secrets(f"[ERROR] {exc}", grok.credential_values()),
                file=sys.stderr,
            )
            grok.emit_json(
                {
                    "owner": OWNER,
                    "published": False,
                    "error": grok.redact_secrets(str(exc), grok.credential_values()),
                }
            )
            return 1
    else:
        publish_info = {
            "published": False,
            "skipped": True,
            "reason": "missing_github_publish_context",
        }

    result = {"owner": OWNER, "skipped": False, **decision, "publish": publish_info}
    if args.output:
        args.output.write_text(
            grok.redact_secrets(
                json.dumps(result, indent=2) + "\n", grok.credential_values()
            ),
            encoding="utf-8",
        )
    grok.emit_json({"owner": OWNER, "outcome": decision["outcome"], **publish_info})
    return 0


if __name__ == "__main__":
    sys.exit(main())
