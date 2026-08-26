# Independent Gemini / Antigravity pull-request review

Owner: **S5-M6**. This directory is the repository-owned Gemini advisory
review policy for GitHub pull requests. It is not a Cursor integration, not
the Antigravity TUI running in CI, and not a GitHub Marketplace action.

## Preferred Gemini path

- **Local interactive review:** Google Antigravity CLI (`agy`) with a Gemini
  API key. Keep `modelProvider` in the **home-directory** file
  `~/.gemini/antigravity-cli/settings.json` and export `GEMINI_API_KEY` in
  the shell. Do not commit that home-directory file.
- **GitHub Actions advisory fallback:** this workflow. It calls the Gemini
  API directly, schema-validates JSON, and publishes an advisory GitHub
  review. It does not install or execute `agy`.

The canonical `modelProvider` pin for local Antigravity CLI setup is
[`settings.json`](settings.json). Copy it to the home-directory path; the
CLI does not read a repository-relative `.gemini/` tree.

```bash
mkdir -p "${HOME}/.gemini/antigravity-cli"
cp .github/antigravity/settings.json "${HOME}/.gemini/antigravity-cli/settings.json"
export GEMINI_API_KEY="your-api-key"
```

Only setting `GEMINI_API_KEY` without `modelProvider: gemini` has no effect
on `agy`. Setting `modelProvider: gemini` without the environment variable
makes the CLI refuse to start.

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
 └── Gemini review (this subsystem)
        ├── collect PR context
        ├── collect trusted policy from `.github/grok/policy.md`
        ├── collect diff
        ├── chunk if necessary
        ├── call Gemini generateContent directly
        ├── validate JSON against `.github/grok/schema.json`
        ├── apply deterministic thresholds from config.json
        └── publish a GitHub pull-request review
```

Separation of responsibilities:

| Actor | Responsibility |
| --- | --- |
| Cursor / implementation agents | Create the change. Their analysis is not this review. |
| Antigravity CLI | Optional local interactive Gemini-key review. Not invoked by CI. |
| GitHub Actions deterministic workflows | Prove lint, tests, and policy that conventional tooling can verify. They never call an LLM. |
| Gemini API | Independent contextual review of correctness, architecture, security, testing gaps, and repository policy. |
| `scripts/gemini_pr_review.py` | Orchestration, schema validation, and governance thresholds. |
| GitHub | Authoritative PR state. Gemini cannot merge, approve as a maintainer, or change settings, labels, issues, or milestones. |

Gemini output is never treated as authoritative Markdown. The workflow
accepts only schema-valid JSON. The policy engine, not the model, chooses
`COMMENT` or `REQUEST_CHANGES`. The engine never emits `APPROVE`.

Trusted review policy and the JSON contract are shared with the xAI/Grok
reviewer (`.github/grok/policy.md`, `.github/grok/schema.json`) so both
advisory providers enforce the same repository rules.

## Files

| Path | Role |
| --- | --- |
| `settings.json` | Canonical Antigravity CLI `modelProvider` pin (copy to `$HOME`) |
| `review_prompt.md` | Trusted Gemini system prompt |
| `config.json` | Defaults for model, limits, and thresholds |
| `../grok/policy.md` | Shared trusted repository review policy |
| `../grok/schema.json` | Shared required review JSON contract |
| `../workflows/gemini-pr-review.yml` | GitHub Actions orchestrator |
| `../../scripts/gemini_pr_review.py` | Collection, Gemini call, validation, publish |

## Required GitHub secrets and variables

| Name | Kind | Required | Purpose |
| --- | --- | --- | --- |
| `GEMINI_API_KEY` | secret | optional | Required only for the automated GitHub Actions advisory review |
| `GEMINI_MODEL` | variable | no | Override `config.json` `gemini_model` |
| `GEMINI_API_URL` | variable | no | Override the generateContent URL template |
| `MAX_DIFF_CHARS` | variable | no | Total reviewable diff budget |
| `MAX_FINDINGS` | variable | no | Published finding cap |
| `MIN_CONFIDENCE` | variable | no | Findings below this are not published |
| `GEMINI_REVIEW_ENABLED` | variable | no | Set to `false` to disable |

Do not put API keys in workflow YAML, config files, or logs. Do not commit
`~/.gemini/antigravity-cli/settings.json` or a repo-root `.gemini/` copy of
it.

## Configuration

`config.json` defaults:

- Model: `gemini-3.6-flash` (change the variable or this file; do not
  hard-code a key or couple the toolkit to one Gemini SKU in application
  scripts)
- `max_diff_chars`: 80000
- `max_chunk_chars`: 24000
- `max_findings`: 25
- `min_confidence`: 0.6
- `request_changes`: `critical` findings with confidence `>= 0.85`

Environment variables override the same keys without changing code.

Prefer enabling only one GitHub Actions advisory reviewer (`XAI_API_KEY` or
`GEMINI_API_KEY`) unless you are comparing providers. Grok Build remains the
preferred interactive independent review for SuperGrok subscribers.

## Workflow triggers

`.github/workflows/gemini-pr-review.yml` runs on `pull_request` (`opened`,
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

## Security model

- `GITHUB_TOKEN` permissions are `contents: read` and
  `pull-requests: write`.
- Checkout uses `actions/checkout@v5` at the pull-request **base SHA**
  (or the repository default branch for `workflow_dispatch`), then fetches
  the PR head only for diff generation. The merge ref is not the runtime
  tree, so a same-repository branch cannot replace
  `scripts/gemini_pr_review.py` or `scripts/grok_pr_review.py` while this
  job holds `GEMINI_API_KEY`. `persist-credentials: false` is still
  avoided because this repository tracks a llama.cpp gitlink without
  `.gitmodules`, and checkout's credential-stripping path fails
  `git submodule foreach` on that gitlink. The workflow YAML itself still
  comes from the `pull_request` event (not `pull_request_target`); a PR
  that edits this workflow file can still change how checkout runs.
- The Gemini key is read only as `GEMINI_API_KEY` for the API call. It is
  never copied into review JSON, prompts, or logs. API errors redact the
  key. The key is sent as the `x-goog-api-key` header, not a query
  parameter, so failed-request URLs do not include the secret.
- PR title, body, diffs, source, comments, and docs are wrapped as
  untrusted data. The system prompt and `.github/grok/policy.md` are the
  only instruction surfaces.
- The workflow does not execute PR scripts, installers, Antigravity CLI,
  or tests as part of review collection.
- A malicious PR cannot raise its instructions above `review_prompt.md` by
  editing `AGENTS.md`, comments, or the PR description. Changes to this
  directory are themselves untrusted relative to the running workflow file
  until they merge.

## Failure behavior

| Condition | Behavior |
| --- | --- |
| `GEMINI_REVIEW_ENABLED=false` | Skip; job succeeds |
| Missing `GEMINI_API_KEY` | Skip; job succeeds (setup is optional until the secret exists) |
| Invalid or unauthorized `GEMINI_API_KEY` | Soft-skip; job succeeds |
| Retired or missing Gemini model (HTTP 404) | Soft-skip; job succeeds. Set `GEMINI_MODEL` or edit `config.json` |
| Gemini quota / rate limit | Soft-skip; job succeeds |
| Fork PR | Job skipped by workflow `if` |
| Empty or fully excluded diff | Publish an advisory comment; no Gemini call |
| Diff exceeds limits | Review reviewed chunks; list unreviewed paths explicitly |
| Invalid Gemini JSON | Do not publish model findings; job fails |
| PR head SHA moved | Do not publish; stale review cannot overwrite a newer head |
| Blocking critical finding | Publish `REQUEST_CHANGES` (advisory unless a maintainer later requires the check) |

## Local testing

Deterministic tests do not call Gemini:

```bash
python3 -m unittest tests.test_gemini_pr_review
```

Offline review of a saved diff and fixture response:

```bash
python3 scripts/gemini_pr_review.py \
  --pr-meta tests/fixtures/grok-review/pr-meta.json \
  --diff-file tests/fixtures/grok-review/sample.diff \
  --offline-response tests/fixtures/grok-review/valid-critical.json \
  --skip-publish
```

Print prompt metadata without dumping untrusted PR text:

```bash
python3 scripts/gemini_pr_review.py \
  --pr-meta tests/fixtures/grok-review/pr-meta.json \
  --diff-file tests/fixtures/grok-review/sample.diff \
  --print-prompt
```

## Disable or change the model

- Disable: set repository variable `GEMINI_REVIEW_ENABLED` to `false`, or
  remove/rename `GEMINI_API_KEY`.
- Change model: set `GEMINI_MODEL` or edit `gemini_model` in `config.json`.

## Deterministic CI versus AI review

Deterministic CI (`.github/workflows/shellcheck.yml`,
`.github/workflows/portable-tests.yml`,
`.github/workflows/pr-title-lint.yml`,
`.github/workflows/label-issues-and-prs.yml`) never calls Gemini.

Gemini review never replaces those checks. A green Gemini comment is not
proof that tests passed. A `REQUEST_CHANGES` review is not a substitute for
a failed ShellCheck or unit-test job.
