# Independent xAI/Grok pull-request review

Owner: **S5-M6**. This directory is the repository-owned review policy for
GitHub pull requests. It is not a Cursor integration and it is not a GitHub
Marketplace action.

## Preferred independent review path (SuperGrok)

For SuperGrok (and X Premium+) subscribers, the preferred independent review
mechanism is **Grok Build**, not this API-key workflow.

- Grok Build is included with SuperGrok.
- It provides richer, agentic, codebase-aware reviews (plan mode, subagents,
  full `AGENTS.md` + policy awareness, tool use).
- Run it locally on a PR branch for interactive review and proposed fixes.
- This repository’s automated GitHub Actions review remains available as a
  lightweight advisory fallback when `XAI_API_KEY` is configured.

The GitHub Actions workflow display name is `Independent xAI/Grok PR Review`.
That name refers to this API-key advisory job. It is not Grok Build.

See `AGENTS.md` (Agent hierarchy) for the preferred agent order.

## Architecture

```text
PR
 │
 ├── deterministic CI
 │      ├── ShellCheck
 │      ├── portable unit and smoke tests
 │      ├── PR title / commit-subject lint
 │      └── GitHub label policy
 │
 └── Grok review (this subsystem)
        ├── collect PR context
        ├── collect trusted policy from this directory
        ├── collect diff
        ├── chunk if necessary
        ├── call xAI Chat Completions directly
        ├── validate JSON against schema.json
        ├── apply deterministic thresholds from config.json
        └── publish a GitHub pull-request review
```

Separation of responsibilities:

| Actor | Responsibility |
| --- | --- |
| Cursor / implementation agents | Create the change. Their analysis is not this review. |
| GitHub Actions deterministic workflows | Prove lint, tests, and policy that conventional tooling can verify. They never call an LLM. |
| xAI/Grok API | Independent contextual review of correctness, architecture, security, testing gaps, and repository policy. |
| `scripts/grok_pr_review.py` | Orchestration, schema validation, and governance thresholds. |
| GitHub | Authoritative PR state. Grok cannot merge, approve as a maintainer, or change settings, labels, issues, or milestones. |

Grok output is never treated as authoritative Markdown. The workflow accepts
only schema-valid JSON. The policy engine, not the model, chooses
`COMMENT` or `REQUEST_CHANGES`. The engine never emits `APPROVE`.

## Files

| Path | Role |
| --- | --- |
| `policy.md` | Trusted repository review policy sent to Grok |
| `review_prompt.md` | Trusted system prompt |
| `schema.json` | Required Grok JSON contract |
| `config.json` | Defaults for model, limits, and thresholds |
| `../workflows/grok-pr-review.yml` | GitHub Actions orchestrator |
| `../../scripts/grok_pr_review.py` | Collection, xAI call, validation, publish |

## Required GitHub secrets and variables

| Name | Kind | Required | Purpose |
| --- | --- | --- | --- |
| `XAI_API_KEY` | secret | optional | Required only for the automated GitHub Actions advisory review. SuperGrok users should prefer Grok Build instead. |
| `XAI_MODEL` | variable | no | Override `config.json` `xai_model` |
| `XAI_API_URL` | variable | no | Override the Chat Completions URL |
| `MAX_DIFF_CHARS` | variable | no | Total reviewable diff budget |
| `MAX_FINDINGS` | variable | no | Published finding cap |
| `MIN_CONFIDENCE` | variable | no | Findings below this are not published |
| `GROK_REVIEW_ENABLED` | variable | no | Set to `false` to disable |

Do not put API keys in workflow YAML, config files, or logs.

## Configuration

`config.json` defaults:

- Model: `grok-4` (change the variable or this file; do not hard-code a
  key or couple the toolkit to one Grok SKU in application scripts)
- `max_diff_chars`: 80000
- `max_chunk_chars`: 24000
- `max_findings`: 25
- `min_confidence`: 0.6
- `request_changes`: `critical` findings with confidence `>= 0.85`

Environment variables override the same keys without changing code.

## Workflow triggers

`.github/workflows/grok-pr-review.yml` runs on `pull_request` (`opened`,
`reopened`, `synchronize`, `ready_for_review`) for non-draft same-repository
PRs. Maintainers can also run `workflow_dispatch` with a pull-request
number.

Concurrency uses `cancel-in-progress: true` per pull-request number so a
new commit cancels an in-flight review. Before publishing, the orchestrator
re-reads the PR head SHA and refuses to publish if it no longer matches the
SHA that was reviewed.

## Fork pull requests

The workflow uses `pull_request`, not `pull_request_target`.

Fork PRs are skipped:

- GitHub does not expose repository secrets to `pull_request` workflows
  from forks.
- This repository does not use `pull_request_target` to obtain those
  secrets, because that would run privileged automation against untrusted
  fork code.

Safe behavior: fork PRs still receive deterministic CI that does not need
secrets (ShellCheck, portable tests, title lint). Independent Grok review
runs after the contribution is in a branch of this repository, or when a
maintainer starts `workflow_dispatch` from the default branch against a
trusted checkout.

## Security model

- `GITHUB_TOKEN` permissions are `contents: read` and
  `pull-requests: write`.
- Checkout uses the same `actions/checkout@v5` defaults as the other
  workflows. `persist-credentials: false` is avoided because this
  repository tracks a llama.cpp gitlink without `.gitmodules`, and
  checkout's credential-stripping path fails `git submodule foreach` on
  that gitlink.
- The xAI key is read only as `XAI_API_KEY` for the API call. It is never
  copied into review JSON, prompts, or logs. API errors redact the key.
- PR title, body, diffs, source, comments, and docs are wrapped as
  untrusted data. The system prompt and `policy.md` are the only
  instruction surfaces.
- The workflow does not execute PR scripts, installers, or tests as part
  of review collection.
- A malicious PR cannot raise its instructions above `review_prompt.md` by
  editing `AGENTS.md`, comments, or the PR description. Changes to this
  directory are themselves untrusted relative to the running workflow file
  until they merge.

## Failure behavior

| Condition | Behavior |
| --- | --- |
| `GROK_REVIEW_ENABLED=false` | Skip; job succeeds |
| Missing `XAI_API_KEY` | Skip; job succeeds (setup is optional until the secret exists) |
| xAI credits exhausted / spending limit (HTTP 403) | Soft-skip; job succeeds. Prefer Grok Build (SuperGrok) for independent review |
| Invalid or unauthorized `XAI_API_KEY` (HTTP 400/401) | Soft-skip; job succeeds. Replace the secret or use Grok Build |
| Fork PR | Job skipped by workflow `if` |
| Empty or fully excluded diff | Publish an advisory comment; no xAI call |
| Diff exceeds limits | Review reviewed chunks; list unreviewed paths explicitly |
| Invalid Grok JSON | Do not publish model findings; job fails |
| PR head SHA moved | Do not publish; stale review cannot overwrite a newer head |
| Blocking critical finding | Publish `REQUEST_CHANGES` (advisory unless a maintainer later requires the check) |

## Local testing

Deterministic tests do not call xAI:

```bash
python3 -m unittest tests.test_grok_pr_review
```

Offline review of a saved diff and fixture response:

```bash
python3 scripts/grok_pr_review.py \
  --pr-meta tests/fixtures/grok-review/pr-meta.json \
  --diff-file tests/fixtures/grok-review/sample.diff \
  --offline-response tests/fixtures/grok-review/valid-critical.json \
  --skip-publish
```

Print prompt metadata without dumping untrusted PR text:

```bash
python3 scripts/grok_pr_review.py \
  --pr-meta tests/fixtures/grok-review/pr-meta.json \
  --diff-file tests/fixtures/grok-review/sample.diff \
  --print-prompt
```

## Disable or change the model

- Disable: set repository variable `GROK_REVIEW_ENABLED` to `false`, or
  remove/rename `XAI_API_KEY`.
- Change model: set `XAI_MODEL` (for example `grok-4-fast`) or edit
  `xai_model` in `config.json`.

## Deterministic CI versus AI review

Deterministic CI (`.github/workflows/shellcheck.yml`,
`.github/workflows/portable-tests.yml`,
`.github/workflows/pr-title-lint.yml`,
`.github/workflows/label-issues-and-prs.yml`) never calls Grok.

Grok review never replaces those checks. A green Grok comment is not proof
that tests passed. A `REQUEST_CHANGES` review is not a substitute for a
failed ShellCheck or unit-test job.
