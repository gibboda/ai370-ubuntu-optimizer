# Independent Grok Build review

Owner: **S5-M6**. Independent pull-request review is the local Grok CLI
(`grok`) authenticated by a SuperGrok account. It is not a GitHub Actions
workflow and it does not use `XAI_API_KEY`.

- Run `grok` on the pull-request branch after deterministic checks.
- Follow [`policy.md`](policy.md) and the Agent hierarchy in `AGENTS.md`.
- If Grok Build is unavailable, use Antigravity CLI (`agy`). See
  [`.github/antigravity/README.md`](../antigravity/README.md).

GitHub Actions does not call xAI. Do not configure `XAI_API_KEY` for this
repository. Deterministic CI (ShellCheck, portable tests, PR title lint,
labels) never calls an LLM.

Grok must not merge pull requests, approve as a maintainer, or change
repository settings, labels, issues, or milestones.
