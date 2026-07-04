# Contributing to ai370-ubuntu-optimizer

## Commit message format

This project uses
**[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)**.
Every PR title (which becomes the squash-merge commit message, with GitHub
appending `(#PR)` on merge) **must** follow this format:

```text
type(scope): Subject
```

The subject must begin with a letter and describe the change concisely.
Commit subjects pushed to a PR should follow the same convention so the branch
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
| `audit` | `scripts/01-hardware-audit.sh` |
| `baseline` | Baseline inventory/plan/validate flow |
| `amd` | `scripts/10-amd-baseline.sh` |
| `ai-stack` | `scripts/20-ai-stack.sh` |
| `rocm` | `scripts/30-rocm-igpu.sh` |
| `npu` | `scripts/40-ryzen-ai-npu.sh` |
| `acceleration` | `scripts/50-60-*` |
| `comfyui` | `scripts/70-comfyui-workflows.sh` |
| `configs` | `configs/` |
| `workflows` | `workflows/` |
| `release` | Release tooling and CI |
| `tier` | Tier 1 hardware/firmware detection and validation scripts |
| `tier1` | Tier 1 hardware/firmware detection and validation scripts |
| `tier2` | Tier 2 AI runtime and LLM installation/validation scripts |

### Examples

```text
feat(comfyui): Add SDXL LoRA workflow template
fix(rocm): Correct iGPU device path detection
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

## Workflow

1. Fork and create a feature branch.
2. Make your changes following the shell script standards above.
3. Open a PR with a title that follows the Conventional Commits format.
4. CI will validate the PR title automatically and reject commit subjects that
   do not follow the same convention on multi-commit PRs.
5. Once merged into `main`, the `release-please` workflow automatically updates
   (or creates) a Release PR. This Release PR handles bumping the version in
   `VERSION` and `.release-please-manifest.json`, and updating `CHANGELOG.md`.
6. When the Release PR is merged, the release is finalized, and the new Git
   tag and GitHub Release are created automatically.
