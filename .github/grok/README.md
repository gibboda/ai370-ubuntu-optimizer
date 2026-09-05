# Independent Grok Build review

Owner: **S5-M6**. Independent pull-request review is the local Grok CLI
(`grok`) authenticated by a SuperGrok account login (`grok login`, usually
OAuth). It is not a GitHub Actions workflow and it does not use
`XAI_API_KEY`. Prefer account login; do not put an xAI API key in the local
shell or in GitHub Secrets for this repository.

Grok / Grok Build is the **exclusive independent AI challenge/reviewer** in
the Agent hierarchy in `AGENTS.md`. It also serves as a specialist advisor.
Its independent role is intentionally separated from Cursor's primary
orchestration and Antigravity's secondary/specialist implementation-analysis
role. Grok should challenge assumptions, independently inspect an existing
implementation, identify regressions and overlooked edge cases, criticize
architecture when warranted, and provide bounded specialist advice.

Grok is not the primary development orchestrator and is not part of the
mandatory implementation path. Absence of Grok credentials must not block
ordinary development, testing, or merging unless repository governance
explicitly requires that review. Grok unavailability does not transfer the
independent-review role to another AI automatically.

- Run Grok on the pull-request branch after deterministic checks.
- Prefer the vendor-neutral repository entry point `scripts/external-agent grok`; arguments after `--` are passed directly to `grok`.
- Follow [`policy.md`](policy.md) and the Agent hierarchy in `AGENTS.md`.
- Record assigned advice as a COMMENT-only pull-request comment or COMMENT review. Do not APPROVE, REQUEST_CHANGES, or merge. If Grok cannot post the record, Cursor or the CODEOWNER must post the attributed local output.
- If Grok Build is unavailable, record it as unavailable and continue under repository governance. Do not substitute Antigravity CLI (`agy`) as an independent reviewer and do not chain vendors automatically.

GitHub Actions does not call xAI. Do not configure `XAI_API_KEY` for this
repository. Deterministic CI never calls an LLM. Do not use `XAI_API_KEY`
for GitHub MCP authorization; Grok uses `GROK_GH_PAT`. See
[`.github/github-mcp.md`](../github-mcp.md).

Grok must not merge pull requests, approve as a maintainer, or change
repository settings, labels, issues, milestones, or GitHub Project items,
fields, or status. GitHub MCP for Grok remains read-only.
