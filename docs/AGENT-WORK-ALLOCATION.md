# AI agent work allocation

`AGENTS.md` is authoritative. This document defines the machine-checkable allocation record used to enforce its least-agent and duplicate-work rules. It does not create automatic agent routing and does not make AI review a merge gate.

The machine-readable shape is `config/agent-work-allocation.schema.json`. Escalation details use `config/agent-escalation-record.schema.json`.

## Rule

Cursor remains the primary implementation resource. Before another AI receives overlapping repository work, record the allocation and reuse existing evidence instead of paying another agent to rediscover it.

Routine duplicate implementation is prohibited. A second implementation resource requires a valid structured escalation record identifying a capability gap and bounded scope. An empty `escalation_record` object is not valid; the nested record must satisfy `config/agent-escalation-record.schema.json`, and `additional_resource` must equal `escalation_record.selected_resource`.

Independent review is not duplicate implementation. It remains intentionally separate because its purpose is to challenge an existing change rather than independently reproduce the implementation. It still requires the escalation record required by repository policy plus a concrete `independent_review_reason`, and it remains advisory.

Grok Build exclusively owns independent AI challenge/review and may also provide specialist advice. A CODEOWNER-assigned Grok second look records `grok_build` as `independent_review`. Antigravity remains the secondary/specialist resource; a CODEOWNER-assigned Antigravity second look records `antigravity` or `antigravity_cli` as `specialist_review`, not `independent_review`. Grok unavailability does not transfer the independent-review role to Antigravity or trigger automatic vendor chaining. Assigned advice remains advisory and must be recorded as a COMMENT-only pull-request comment or COMMENT review.

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

Use only for Grok Build when it independently examines an existing implementation to challenge assumptions and find correctness, architecture, security, testing, regression, edge-case, or policy issues. `escalation_record` and `independent_review_reason` are mandatory. Schema version 2 requires `additional_resource` `grok_build` for this work kind. Review findings are advisory and do not become a required merge gate. A CODEOWNER-assigned Grok Build second look uses this work kind with `additional_resource` `grok_build`. Antigravity and Antigravity CLI (`agy`) do not use this work kind.

### `specialist_review`

Use when an additional AI performs specialist inspection of an existing implementation rather than Grok's independent challenge/review or a second implementation. `escalation_record` and `specialist_review_reason` are mandatory. Findings are advisory and do not become a required merge gate. This kind is not `implementation` and not `parallel_analysis`.

A CODEOWNER-assigned Antigravity second look uses this work kind with `additional_resource` `antigravity`; CLI-based Antigravity specialist advice uses `antigravity_cli`. Grok Build may also provide bounded specialist advice with `additional_resource` `grok_build`. Copilot/Codex final advisory specialist passes are not recorded as `implementation`; when an allocation record is created for that pass, it uses this work kind with `additional_resource` `github_copilot` or `codex`.

### `parallel_analysis`

Use only when two AI resources need genuinely simultaneous or independent analysis and there is a concrete reason the work cannot efficiently remain sequential. `escalation_record` and `parallel_reason` are mandatory. This does not create another independent-review provider; Grok remains the exclusive independent AI challenge/review role.

## Enforcement boundary

The contract prevents unrecorded duplicate-agent allocation; it does not invoke agents, select vendors automatically, spend credits, grant repository permissions, or approve merges. Deterministic tooling remains authoritative for machine-verifiable facts, and human PR governance remains final authority.
