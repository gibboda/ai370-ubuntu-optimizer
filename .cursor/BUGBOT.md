# Cursor Bugbot review policy

`AGENTS.md` is the canonical repository AI policy. This file adds only
Bugbot-specific review guidance. It does not redefine the agent hierarchy or
merge authority.

## Purpose

Use Bugbot to find meaningful correctness, security, regression, reliability,
and maintainability defects in pull-request changes. Prefer findings that are
actionable and materially affect behavior. Do not spend review effort on
purely stylistic preferences already enforced by deterministic tooling.

## Cost-conscious review

- Prefer Cursor Bugbot **Default** effort for routine pull requests. High or
  custom-high effort requires an explicit human decision for unusually risky,
  security-sensitive, architectural, or complex changes.
- Reuse prior Bugbot findings and deterministic evidence. Do not request a
  duplicate review solely because another AI reviewer is available.
- Manual re-review (`cursor review` / `bugbot run`) is human-controlled and
  should be requested only when new evidence or a materially changed diff
  justifies the additional spend.

## Autofix

Bugbot Autofix is the preferred first remediation path for a Bugbot finding
when Autofix is enabled and applicable.

- Prefer **Create New Branch** Autofix mode. Do not require direct commits to
  the existing PR branch.
- Autofix may attempt only the Bugbot finding that triggered it and directly
  related test or validation changes.
- Autofix must run applicable deterministic validation after editing when the
  environment supports it.
- Autofix must not merge, approve, alter branch protection/rulesets, weaken
  tests, suppress findings merely to make checks green, or expand into an
  unrelated refactor.
- An Autofix failure or inability to produce a safe fix is evidence for the
  human-controlled escalation decision; it is not permission to invoke the
  next vendor automatically.

## Escalation after Bugbot/Autofix

This finding-remediation order does not replace the risk-tiered
Copilot and/or Codex final specialist pass required by `AGENTS.md`
for high-risk pull requests.

For a Bugbot finding, use this cost-aware order:

1. Bugbot Autofix, when enabled and applicable.
2. Cursor primary development orchestrator, using the finding and all
   deterministic evidence already available.
3. Antigravity as the secondary/specialist implementation agent only when the
   unresolved gap matches its capabilities.
4. Grok Build for independent diagnosis/review when a second opinion is
   useful; advisory only. Antigravity CLI (`agy`) may provide specialist
   advice, not independent review.
5. GitHub Copilot only as a GitHub-native fallback when the prior capable
   paths cannot safely resolve the implementation gap or Cursor is
   unavailable.
6. Codex only as the final narrowly scoped implementation specialist when the
   prior capable agents cannot safely resolve the gap and the maintainer
   explicitly selects it.

Do not automatically execute this list as a chain. After each attempt,
re-run deterministic checks, evaluate the remaining gap, and stop when the
issue is resolved or a human decision is required.

## Review boundaries

Bugbot and Autofix are Cursor-native review/remediation capabilities. They are
advisory AI and are never required merge gates or substitutes for CODEOWNER
review. GitHub Actions and repository checks remain authoritative for facts
they can verify. CODEOWNER `@gibboda` and repository governance retain final
merge authority.
