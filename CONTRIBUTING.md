# Contributing to ai370-ubuntu-optimizer

## Commit message format

This project uses **[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)**.
Every PR title (which becomes the squash-merge commit message) **must** follow this format:

```
type(scope): Subject
```

The subject must begin with an upper-case letter and describe the change concisely.

### Types

| Type | When to use |
|---|---|
| `feat` | A new feature or capability |
| `fix` | A bug fix |
| `chore` | Maintenance, dependency updates, tooling |
| `refactor` | Code restructure with no behaviour change |
| `docs` | Documentation only |
| `test` | Tests only |
| `ci` | CI/CD workflow changes |
| `perf` | Performance improvement |

Breaking changes must append `!` after the type/scope, e.g. `feat!: Remove legacy profile`.

### Scopes (optional)

Scope narrows the area of change:

| Scope | Area |
|---|---|
| `audit` | `scripts/01-hardware-audit.sh` |
| `amd` | `scripts/10-amd-baseline.sh` |
| `ai-stack` | `scripts/20-ai-stack.sh` |
| `rocm` | `scripts/30-rocm-igpu.sh` |
| `npu` | `scripts/40-ryzen-ai-npu.sh` |
| `acceleration` | `scripts/50-60-*` |
| `comfyui` | `scripts/70-comfyui-workflows.sh` |
| `config` | `config/` |
| `workflows` | `workflows/` |
| `release` | Release tooling and CI |

### Examples

```
feat(comfyui): Add SDXL LoRA workflow template
fix(rocm): Correct iGPU device path detection
chore: Bump stefanzweifel/git-auto-commit-action to v5.1
docs: Clarify safe-mode defaults in README
ci(release): Pin checkout action to v4
refactor(ai-stack): Extract acceleration detection into helper function
feat!: Drop Ubuntu 24.04 support in favour of 26.04
```

## PR labels

Apply exactly **one** bump label to every PR so the release workflow knows which
part of the version number to increment:

| Label | Meaning | Example |
|---|---|---|
| `bump:patch` | Backwards-compatible fix (default) | Bug fix, doc update |
| `bump:minor` | New backwards-compatible feature | New script or workflow |
| `bump:major` | Breaking change | Removed flag, incompatible profile change |

If no bump label is applied the release defaults to `patch`.

Add `skip-changelog` to exclude a PR from the changelog entirely (e.g. internal
CI noise).

## Shell script standards

All scripts in this repository follow these conventions:

- Shebang: `#!/usr/bin/env bash`
- License header: `# SPDX-License-Identifier: GPL-3.0-only`
- Safety flags: `set -euo pipefail`
- Log format: `echo "[INFO] ..."` / `echo "[ERROR] ..."` (no bare echo for user messages)
- Accept positional arguments: `PROFILE="${1:-ai370}"`, `MODE="${2:-safe}"`, `PERSISTENCE="${3:-runtime}"`
- Wrap main logic in a `main()` function and call `main "$@"` at the end

## Workflow

1. Fork and create a feature branch.
2. Make your changes following the shell script standards above.
3. Open a PR with a title that follows the Conventional Commits format.
4. Apply the appropriate `bump:*` label.
5. CI will validate the PR title automatically.
6. Once merged, release-drafter updates the draft release notes.
7. When a GitHub Release is published, the `release.yml` workflow bumps `VERSION`
   and finalises `CHANGELOG.md` automatically.
