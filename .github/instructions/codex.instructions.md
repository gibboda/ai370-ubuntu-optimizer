---
applyTo: "**"
---

# Codex implementation instructions

Codex is the **Codex Coding Agent** in this repository. Cursor remains the
primary development orchestrator. Codex is explicitly routed for bounded
coding/review work; it is not the default task owner.
[`../../AGENTS.md`](../../AGENTS.md) is authoritative for shared agent
roles, escalation, cost policy, architecture, testing, naming, and change
discipline. Do not restate or override that policy here.

Invoke Codex only when `AGENTS.md` allows specialist use or the final native
specialist pass. See the Agent hierarchy in `AGENTS.md` rather than restating
it here. Do not treat Codex as a parallel default implementer or as the
exclusive independent reviewer.

For the pre-merge pipeline, Codex may participate after Grok Build and
Antigravity review/advice, after or alongside the GitHub Copilot native
specialist pass, and before the final GitHub required-check state and CODEOWNER
merge decision. On high-risk pull requests the Copilot/Codex final specialist
pass is process-required but result-advisory. COMMENT or suggestions only; do
not APPROVE in a way that satisfies branch protection.

## PR creation

When Codex creates commits or pull requests in this repository, it must use
this repository's Conventional Commit standard before opening the PR.

[`../../CONTRIBUTING.md`](../../CONTRIBUTING.md) is authoritative for allowed
types, scopes, examples, and release versioning. Commit subjects and PR
titles must use:

```text
type(optional-scope): Subject
```

Rules:

- Scope is optional.
- The subject must start with a letter.
- Do not use leading emoji.
- Do not use a plain English title without a Conventional Commit type.
- Use `!` after the type or scope only for breaking changes.
- Validate the PR title before opening the PR.

Before creating a PR, run:

```bash
bash scripts/validate-pr-title.sh "$PR_TITLE"
```

Do not open the PR unless the title validation command passes.
