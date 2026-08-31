# Contributing to ai370-ubuntu-optimizer

This document is authoritative for Conventional Commit types, scopes,
examples, release versioning, shell script standards, and the human
contributor workflow.

Shared AI-agent policy lives in [`AGENTS.md`](AGENTS.md). That file is
authoritative for agent hierarchy, agent roles, escalation, cost policy,
deterministic validation, architecture, testing, naming, and change
discipline. Architecture overview:
[`docs/AI-AGENT-ARCHITECTURE.md`](docs/AI-AGENT-ARCHITECTURE.md).

- Cursor environment overlay: [`.cursor/rules/`](.cursor/rules/)
- GitHub Copilot specialist overlay:
  [`.github/instructions/copilot.instructions.md`](.github/instructions/copilot.instructions.md)
- GitHub Copilot custom agents: [`.github/agents/`](.github/agents/)
- Codex specialist overlay:
  [`.github/instructions/codex.instructions.md`](.github/instructions/codex.instructions.md)
- Antigravity workspace agents: [`.agents/agents/`](.agents/agents/)
- Independent review (not implementation overlays):
  [`.github/grok/`](.github/grok/),
  [`.github/antigravity/`](.github/antigravity/)
- Shared GitHub MCP and Projects setup: [`.github/github-mcp.md`](.github/github-mcp.md)

Do not copy shared agent policy into those files.

The human maintainer retains final decision authority. `AGENTS.md` does not
transfer merge, policy, release, architecture, or repository-governance
authority to an AI agent.

## Commit message format

This project uses
**[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)**.
Every PR title (which becomes the squash-merge commit message, with GitHub
appending `(#PR)` on merge) **must** follow this format:

```text
type(scope): Subject
```

The subject must begin with a letter and describe the change concisely. Do not
use leading emoji, and do not use a plain English title without a Conventional
Commit type. All contributors and co-contributors, including humans, AI agents,
and automation, must follow this policy. The person or automation creating a
commit and opening its pull request is responsible for ensuring that the shared
commit subject and PR title comply on behalf of every contributor and
`Co-authored-by` identity credited in the change.

Commit subjects pushed to a PR must follow the same convention so the branch
history and final squash-merge commit stay consistent. CI enforces this for
multi-commit PRs; single-commit PRs rely on title lint.

### Types

| Type | When to use |
| --- | --- |
| `feat` | A new feature or capability |
| `fix` | A bug fix |
| `chore` | Maintenance, dependency updates, tooling |
| `refactor` | Code restructure with no behaviour change |
| `docs` | Documentation only |
| `test` | Tests only |
| `ci` | CI/CD workflow changes |
| `perf` | Performance improvement |

Breaking changes must append `!` after the type/scope, e.g. `feat!: Remove
legacy profile`.

### Scopes (optional)

Scope narrows the area of change:

| Scope | Area |
| --- | --- |
| `audit` | Compatibility hardware audit (`scripts/legacy/01-hardware-audit.sh`); prefer `stage1` |
| `baseline` | Baseline inventory/plan/validate compatibility flow |
| `amd` | Compatibility AMD baseline (`scripts/legacy/10-amd-baseline.sh`); prefer `stage2-*` |
| `ai-stack` | Compatibility AI stack (`scripts/legacy/20-ai-stack.sh`); prefer Stage 3 runtime scripts |
| `rocm` | GPU/ROCm visibility (`scripts/s2-m3-validate-gpu-stack.sh`; legacy `scripts/legacy/30-rocm-igpu.sh`) |
| `npu` | NPU visibility (`scripts/s2-m4-validate-npu-stack.sh`; legacy `scripts/legacy/40-ryzen-ai-npu.sh`) |
| `acceleration` | AMD acceleration install (`scripts/65-amd-acceleration-install.sh`; legacy `scripts/legacy/50-guided-acceleration.sh`) |
| `comfyui` | `scripts/70-comfyui-workflows.sh` |
| `config` | `configs/` |
| `architecture` | Architecture docs / high-level design |
| `agents` | Agent policy and orchestration (`AGENTS.md`, `.cursor/`, `.github/agents/`, `.agents/`, `.github/instructions/`) |
| `governance` | GitHub PR governance, rulesets, required checks, and advisory AI review |
| `workflows` | `workflows/` |
| `vscode` | VS Code workspace settings |
| `settings` | Editor and plugin settings (`.cursor/settings.json`) |
| `release` | Release tooling and CI |
| `deps` | Dependency updates (Dependabot and manual bumps) |
| `stage` | Cross-stage architecture and policy |
| `stage1` | Stage 1 probe and system-profile publication |
| `stage2` | Stage 2 platform visibility, tuning, and validation |
| `stage3` | Stage 3 runtime foundation |
| `stage4` | Stage 4 application workflows |
| `stage5` | Stage 5 lifecycle and development tooling |
| `tier` | Deprecated compatibility scope for Stage 1 hardware/firmware scripts |
| `tier1` | Deprecated compatibility scope for Stage 1 hardware/firmware scripts |
| `tier2` | Deprecated compatibility scope for Stage 2/3 AI runtime scripts |

### Examples

```text
feat(comfyui): Add SDXL LoRA workflow template
fix(rocm): Correct iGPU device path detection
chore(deps): Bump onnx in configs/ai-runtime
chore(agents): Define Cursor hybrid orchestration boundary
test(governance): Verify advisory AI review boundary
feat(settings): Add snyk-secure-development plugin configuration
chore: Bump stefanzweifel/git-auto-commit-action to v5.1
docs: Clarify safe-mode defaults in README
ci(release): Pin checkout action to v4
refactor(ai-stack): Extract acceleration detection into helper function
feat!: Drop Ubuntu 24.04 support in favour of 26.04
```

## Release Versioning

Releases are fully automated based on Conventional Commits:

- **Patch Bump**: Triggered by `fix` commits (e.g.,
  `fix: Correct iGPU device path detection`).
- **Minor Bump**: Triggered by `feat` commits (e.g.,
  `feat(comfyui): Add SDXL LoRA workflow template`).
- **Major Bump**: Triggered by adding a `!` after the type/scope for breaking
  changes (e.g., `feat!: Drop Ubuntu 24.04 support in favour of 26.04`).

Commits with types like `chore`, `docs`, `ci`, `refactor`, or `test` do not
trigger a new release by default but are documented in the release notes.

## Shell script standards

All scripts in this repository follow these conventions:

- Shebang: `#!/usr/bin/env bash`
- License header: `# SPDX-License-Identifier: GPL-3.0-only`
- Safety flags: `set -euo pipefail`
- Log format: `echo "[INFO] ..."` / `echo "[ERROR] ..."` (no bare echo for user
  messages)
- Accept positional arguments: `PROFILE="${1:-ai370}"`, `MODE="${2:-safe}"`,
  `PERSISTENCE="${3:-runtime}"`
- Wrap main logic in a `main()` function and call `main "$@"` at the end

## Labels

Issue forms and `.github/workflows/label-issues-and-prs.yml` apply identity
labels automatically. Do not hand-apply type, area, or bump labels unless you
are correcting automation.

On **open**:

- Issues: `needs-triage`, the form type (`bug`, `enhancement`, `question`, or
  `area:security`), and the selected `area:*` label.
- Pull requests: Conventional Commit type (`enhancement` / `bug` and exactly
  one `bump:*` label) plus `area:*` / `validation` / `compatibility` /
  `dependencies` from title scope and changed paths.

On **close**:

- Remove `needs-triage`, `needs-info`, and `needs-reproduction`.
- Issues closed as not planned get `wontfix`; duplicates get `duplicate`.
- Completed issues and merged or unmerged PRs do not get an extra outcome
  label. Identity labels stay.

On **reopen**, issues get `needs-triage` again and lose `wontfix` / `duplicate`.
Release Please PRs (`autorelease:*` or `chore(release):`) are left untouched.

## Workflow

1. Fork and create a feature branch.
2. Make your changes following the shell script standards above.
3. Open a PR with a title that follows the Conventional Commits format.
4. CI will validate the PR title automatically and reject commit subjects that
   do not follow the same convention on multi-commit PRs.
   Before pushing generated or automated commits, validate their subject locally:

   ```bash
   bash scripts/validate-commit-subject.sh "type(optional-scope): Subject"
   ```

   Deterministic GitHub Actions (ShellCheck, portable tests, PR title lint,
   labels) never call an LLM.

   Independent review (advisory; not a merge gate):
   - **Preferred (SuperGrok)**: Use Grok Build (`grok`, included with
     SuperGrok) for interactive, agentic PR review on the pull-request
     branch. See [`.github/grok/README.md`](.github/grok/README.md).
   - **Backup**: If Grok Build is unavailable, use Antigravity CLI (`agy`).
     See [`.github/antigravity/README.md`](.github/antigravity/README.md).
   Cursor remains the primary development orchestrator; Antigravity is the
   secondary/specialist for escalated implementation analysis. See
   [`docs/AI-AGENT-ARCHITECTURE.md`](docs/AI-AGENT-ARCHITECTURE.md).
   GitHub Actions does not call xAI or Gemini and does not use
   `XAI_API_KEY` or `GEMINI_API_KEY`.

5. Confirm the auto-applied bump and area labels. Override only when the title
   cannot express the intended release or area.
6. Once merged into `main`, the `release-please` workflow automatically updates
   (or creates) a Release PR. This Release PR handles bumping the version in
   `VERSION` and `.release-please-manifest.json`, and updating `CHANGELOG.md`.
7. When the Release PR is merged, the release is finalized, and the new Git
   tag and GitHub Release are created automatically.
