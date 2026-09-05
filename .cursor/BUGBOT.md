# Cursor Bugbot review and autofix policy

`AGENTS.md` is the canonical repository AI policy. This file adds only Bugbot-specific guidance. It does not redefine merge authority.

## Role

Cursor Bugbot is the **Cursor-Native Autofixer** and advisory PR reviewer. Cursor remains the Primary Development Orchestrator; Bugbot does not become a second task owner or orchestrator.

## Purpose

Use Bugbot to find meaningful correctness, security, regression, reliability, and maintainability defects in pull-request changes. Prefer actionable findings that materially affect behavior rather than stylistic preferences already enforced by deterministic tooling.

## Cost-conscious review

- Prefer Cursor Bugbot **Default** effort for routine pull requests. High/custom-high effort requires an explicit human decision.
- Reuse prior Bugbot findings and deterministic evidence; do not request duplicate review solely because another AI is available.
- Manual re-review (`cursor review` / `bugbot run`) is human-controlled and should be requested only for new evidence or a materially changed diff.

## Autofix

Bugbot Autofix is the preferred first remediation path for a Bugbot finding when enabled and applicable.

- Prefer **Create New Branch** Autofix mode.
- Autofix may address only the triggering finding and directly related tests/validation.
- Run applicable deterministic validation after editing when the environment supports it.
- Autofix must not merge, approve, alter governance, weaken tests, suppress findings merely to make checks green, or expand into unrelated refactoring.
- Autofix failure is evidence for a human-controlled escalation decision, not permission for automatic vendor chaining.

## Pre-merge relationship

Bugbot precedes assigned Grok/Antigravity review in the logical readiness model. After Bugbot remediation and applicable validation, Grok Build may provide exclusive independent challenge/review and Antigravity may provide a secondary/specialist second look. GitHub Copilot (**GitHub-Native Coding Agent**) and Codex (**Codex Coding Agent**) then form the final native advisory specialist-pass layer before the final required-check state and CODEOWNER merge decision.

This ordering is not mandatory runtime serialization. Checks may run earlier or continuously and must be rerun as necessary after accepted changes.

The Copilot/Codex final specialist pass remains process-required only for high-risk pull requests and result-advisory. Standard and low-risk pull requests skip it by default unless the CODEOWNER requests it.

## Escalation after Bugbot/Autofix

For unresolved implementation gaps, keep the least-agent principle: return to Cursor first, use deterministic evidence, then explicitly select the specialist whose capability matches the remaining gap. Do not automatically execute Grok, Antigravity, Copilot, or Codex as a chain.

## Review boundaries

Bugbot and Autofix are Cursor-native review/remediation capabilities. They are advisory AI and never required merge gates or substitutes for CODEOWNER review. GitHub Actions and repository checks remain authoritative for facts they can verify. CODEOWNER `@gibboda` and repository governance retain final merge authority.
