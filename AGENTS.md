# AGENTS.md

## Codex PR creation policy

When Codex creates commits or pull requests in this repository, it must use this
repository's Conventional Commit standard before opening the PR.

Commit subjects and PR titles must use this format:

```text
type(optional-scope): Subject
```

Allowed types:

- `feat`
- `fix`
- `chore`
- `refactor`
- `docs`
- `test`
- `ci`
- `perf`

Allowed scopes:

- `audit`
- `baseline`
- `amd`
- `ai-stack`
- `rocm`
- `npu`
- `acceleration`
- `comfyui`
- `config`
- `workflows`
- `vscode`
- `release`
- `tier`
- `tier1`
- `tier2`

Rules:

- Scope is optional.
- The subject must start with a letter.
- Do not use leading emoji.
- Do not use a plain English title without a Conventional Commit type.
- Use `!` after the type or scope only for breaking changes.
- Validate the PR title before opening the PR.

Examples:

```text
fix: Relax S3-M7 NPU execution gate
docs: Add ComfyUI heterogeneous acceleration roadmap
chore(release): release 0.12.3
feat(tier2): Add model validation report
ci(workflows): Update PR title lint workflow
```

Before creating a PR, run:

```bash
bash scripts/validate-pr-title.sh "$PR_TITLE"
```

Do not open the PR unless the title validation command passes.
