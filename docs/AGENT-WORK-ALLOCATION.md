# AI agent work allocation

`AGENTS.md` is authoritative. This document defines the machine-checkable allocation record used to enforce its least-agent and duplicate-work rules. It does not create automatic agent routing and does not make AI review a merge gate.

The machine-readable shape is `config/agent-work-allocation.schema.json`. Escalation details use `config/agent-escalation-record.schema.json`.

## Rule

Cursor remains the primary implementation resource. Before another AI receives overlapping repository work, record the allocation and reuse existing evidence instead of paying another agent to rediscover it.

Routine duplicate implementation is prohibited. A second implementation resource requires a valid structured escalation record identifying a capability gap and bounded scope. An empty `escalation_record` object is not valid; the nested record must satisfy `config/agent-escalation-record.schema.json`, and `additional_resource` must equal `escalation_record.selected_resource`.

Independent review is not duplicate implementation. It remains intentionally separate because its purpose is to challenge an existing change rather than independently reproduce the implementation. It still requires the escalation record required by repository policy plus a concrete `independent_review_reason`, and it remains advisory.

A CODEOWNER-assigned second look at Cursor's change records Grok Build as `independent_review` by default and Antigravity as `specialist_review`. The CODEOWNER may assign either or both. The CODEOWNER may also assign Grok Build as `specialist_review` and Antigravity CLI (`agy`) as `independent_review` or `specialist_review` when Grok is available. `agy` used as Grok-unavailable fallback remains `independent_review` (independent-reviewer fallback) and is not `specialist_review`. That assignment is policy, not a GitHub CODEOWNERS identity, and findings stay advisory. Assigned `grok` and `agy` advice must be recorded as a COMMENT-only pull-request comment or COMMENT review.

A Copilot and/or Codex final advisory specialist pass is process-required for high-risk pull requests and result-advisory. Standard and low-risk pull requests skip that pass by default; the CODEOWNER may request it. It is COMMENT or suggestions only. It is not `implementation`, not duplicate routine implementation, not an approval that satisfies branch protection, and not a merge gate. When an allocation record is created for that pass, it uses `specialist_review`.

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

Use when an additional AI examines an existing implementation to find correctness, architecture, security, testing, or policy issues. `escalation_record` and `independent_review_reason` are mandatory. Review findings are advisory and do not become a required merge gate. A CODEOWNER-assigned Grok Build second look uses this work kind with `additional_resource` `grok_build`. `agy` used as Grok-unavailable fallback uses this work kind with `additional_resource` `antigravity_cli`. The CODEOWNER may also assign `agy` as independent reviewer when Grok is available. Assigned `grok` and `agy` findings must be recorded as a COMMENT-only pull-request comment or COMMENT review.

### `specialist_review`

Use when an additional AI performs specialist inspection of an existing implementation rather than independent review or a second implementation. `escalation_record` and `specialist_review_reason` are mandatory. Findings are advisory and do not become a required merge gate. This kind is not `implementation` and not `parallel_analysis`.

A CODEOWNER-assigned Antigravity second look uses this work kind with `additional_resource` `antigravity`. The CODEOWNER may also assign Grok Build or `agy` as specialist advisor with `additional_resource` `grok_build` or `antigravity_cli`. Copilot/Codex final advisory specialist passes are not recorded as `implementation`; when an allocation record is created for that pass, it uses this work kind with `additional_resource` `github_copilot` or `codex`.

### `parallel_analysis`

Use only when two AI resources need genuinely simultaneous or independent analysis and there is a concrete reason the work cannot efficiently remain sequential. `escalation_record` and `parallel_reason` are mandatory.

## Enforcement boundary

The contract prevents unrecorded duplicate-agent allocation; it does not invoke agents, select vendors automatically, spend credits, grant repository permissions, or approve merges. Deterministic tooling remains authoritative for machine-verifiable facts, and human PR governance remains final authority.
