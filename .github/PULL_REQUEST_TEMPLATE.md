---
## What does this PR do?

<!-- A short description of the change. -->

## Type of change

<!-- Choose the one that applies and delete the rest. Your PR title must start with the matching prefix. -->

- `feat:` — New feature or capability
- `fix:` — Bug fix
- `chore:` — Maintenance, dependency updates, tooling
- `refactor:` — Code restructure with no behaviour change
- `docs:` — Documentation only
- `test:` — Tests only
- `ci:` — CI/CD workflow changes
- `perf:` — Performance improvement

## Scope (optional)

<!-- If the change targets a specific area, add it in parentheses in the title, e.g. `feat(comfyui): ...` -->
<!-- Valid scopes: audit, baseline, amd, ai-stack, rocm, npu, acceleration, comfyui, config, architecture, agents, governance, mcp, workflows, vscode, settings, release, deps, stage, stage1, stage2, stage3, stage4, stage5, tier, tier1, tier2, or canonical milestone scopes like s5-m6 -->

## Version bump label

<!-- Applied automatically from the Conventional Commit PR title:
     feat -> bump:minor; fix/docs/chore/refactor/test/ci/perf -> bump:patch;
     type!: or type(scope)!: -> bump:major. Override after open if needed. -->

## Checklist

- [ ] PR title follows the Conventional Commits format (`type(scope): Subject`)
- [ ] All contributors and co-contributors follow the Conventional Commits
  policy; every commit subject uses `type(scope): Subject`
- [ ] Confirm the auto-applied `bump:patch`, `bump:minor`, or `bump:major`
  label matches the intended release
- [ ] Changes are tested locally where applicable
- [ ] `CHANGELOG.md` `[Unreleased]` section updated if needed
- [ ] CODEOWNER @gibboda requested as reviewer
- [ ] CODEOWNER assigned Grok and/or `agy` for advisory review (or recorded why neither was needed)
- [ ] Assigned `grok`/`agy` advice recorded as a COMMENT-only PR comment or COMMENT review (or N/A if neither was assigned)
- [ ] Copilot and/or Codex completed a final advisory specialist pass (or recorded unavailability)
- [ ] No AI approval is being used as merge authority
