---
applyTo: "**"
---

# Codex implementation instructions

Codex is a specialist/escalation agent. [`../../AGENTS.md`](../../AGENTS.md)
is authoritative for shared agent roles, escalation, cost policy,
architecture, testing, naming, and change discipline. Do not restate or
override that policy here.

Invoke Codex only when `AGENTS.md` allows specialist use. Specialist use
must be narrowly scoped and capability-driven. Do not treat Codex as the
default implementation agent or as a parallel reviewer for routine work.

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
