# AI agent work allocation

`AGENTS.md` is authoritative. This document defines the machine-checkable allocation record used to enforce its least-agent and duplicate-work rules. It does not create automatic agent routing and does not make AI review a merge gate.

The machine-readable shape is `config/agent-work-allocation.schema.json`. Escalation details use `config/agent-escalation-record.schema.json`.

## Rule

Cursor remains the primary implementation resource. Before another AI receives overlapping repository work, record the allocation and reuse existing evidence instead of paying another agent to rediscover it.

Routine duplicate implementation is prohibited. A second implementation resource requires a valid structured escalation record identifying a capability gap and bounded scope. An empty `escalation_record` object is not valid; the nested record must satisfy `config/agent-escalation-record.schema.json`, and `additional_resource` must equal `escalation_record.selected_resource`.

Independent review is not duplicate implementation. It remains intentionally separate because its purpose is to challenge an existing change rather than independently reproduce the implementation. It still requires the escalation record required by repository policy plus a concrete `independent_review_reason`, and it remains advisory.

A CODEOWNER-assigned second look at Cursor's change is `independent_review` and/or specialist work. The CODEOWNER may assign Grok Build as independent reviewer, Antigravity as secondary specialist, or both. That assignment is policy, not a GitHub CODEOWNERS identity, and findings stay advisory.

A Copilot and/or Codex final advisory specialist pass is process-required and result-advisory. It is COMMENT or suggestions only. It is not duplicate routine implementation, not an approval that satisfies branch protection, and not a merge gate.

Parallel multi-agent analysis is exceptional. It requires both a valid escalation record and a concrete `parallel_reason`. The existence of multiple GitHub MCP connections is not sufficient justification. The CODEOWNER review pipeline is sequential assignment, not parallel multi-agent analysis.

## Evidence reuse

`reuse_evidence` must contain at least one existing artifact supplied to the additional resource:

- `cursor_findings`
- `logs`
- `ci`
- `tests`
- `issue_discussion`
- `pr_discussion`
- `prior_agent_output`

The list records what was reused; it is not permission to invoke another agent. A work-allocation record documents a decision made under `AGENTS.md` and does not confer authorization.

## Work kinds

### `implementation`

Use when another AI is asked to modify, implement, refactor, debug, or otherwise perform implementation work overlapping the primary development task. `escalation_record` is mandatory.

### `independent_review`

Use when an additional AI examines an existing implementation to find correctness, architecture, security, testing, or policy issues. `escalation_record` and `independent_review_reason` are mandatory. Review findings are advisory and do not become a required merge gate. A CODEOWNER-assigned Grok Build second look uses this work kind.

A CODEOWNER-assigned Antigravity second look may use specialist investigation rather than this work kind. Copilot/Codex final advisory specialist passes are not recorded as `implementation` and are not duplicate routine implementation.

### `parallel_analysis`

Use only when two AI resources need genuinely simultaneous or independent analysis and there is a concrete reason the work cannot efficiently remain sequential. `escalation_record` and `parallel_reason` are mandatory.

## Enforcement boundary

The contract prevents unrecorded duplicate-agent allocation; it does not invoke agents, select vendors automatically, spend credits, grant repository permissions, or approve merges. Deterministic tooling remains authoritative for machine-verifiable facts, and human PR governance remains final authority.
