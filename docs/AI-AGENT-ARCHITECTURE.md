# AI Agent Architecture

This document explains the repository's vendor-neutral multi-agent development architecture. [`AGENTS.md`](../AGENTS.md) remains the authoritative policy. Tool-specific overlays must not silently override it.

## Flow

```text
Developer
    |
    v
Cursor
Primary Development Orchestrator
implements, tests, opens/updates PR
    |
    v
Cursor Bugbot
Cursor-Native Autofixer
(first remediation for Bugbot findings when applicable)
    |
    v
Grok Build
Exclusive Independent Challenge/Review + Specialist Advice
(COMMENT only when assigned)
    |
    v
Antigravity / agy
Secondary / Specialist Second Look
(when justified)
    |
    v
GitHub Copilot
GitHub-Native Coding / Review Agent
    |
    v
Codex
Codex Coding / Review Agent
    |
    v
GitHub Actions + Repository Checks
Final Deterministic Merge-Validation State
    |
    v
CODEOWNER @gibboda
Final Human Review / Merge
```

This is the **logical readiness order**, not mandatory runtime serialization. Deterministic checks should still run before AI escalation when they can answer a question, and GitHub Actions may run earlier or continuously while a pull request evolves. The check state used for final merge eligibility must reflect every accepted AI-generated modification.

GitHub remains the control plane. Cursor remains the primary development orchestrator and default task owner. Cursor Bugbot is the Cursor-native autofixer for applicable Bugbot findings; it does not become a second orchestrator. Grok Build remains the exclusive independent AI challenge/review provider. Antigravity remains secondary/specialist and does not inherit Grok's independent-review authority.

GitHub Copilot's architectural identity is **GitHub-Native Coding Agent**. "Fallback" describes a routing condition, not the role itself. GitHub Copilot custom agents under `.github/agents/` are **GitHub-Native Specialist Agents** beneath that role. Codex's architectural identity is **Codex Coding Agent**. Both remain explicitly routed rather than default peers to Cursor.

Copilot and/or Codex make the final native advisory specialist pass on high-risk pull requests after assigned Grok/Antigravity review and before the final required-check state and CODEOWNER merge decision. Standard and low-risk pull requests skip that pass by default unless the CODEOWNER requests it. COMMENT or suggestions only; the pass must not satisfy branch protection.

## Roles

| Role | Owner | Mandatory for ordinary work? |
| --- | --- | --- |
| Primary Development Orchestrator | Cursor | Yes for default development |
| Cursor-Native Autofixer | Cursor Bugbot | No; preferred first remediation for applicable Bugbot findings |
| Exclusive Independent Challenge/Review Agent + Specialist Advisor | Grok / Grok Build (`grok`) | No; advisory and exclusive for independent AI challenge/review |
| Secondary / Specialist Agent | Google Antigravity / `agy` | No; use when justified |
| GitHub-Native Coding Agent | GitHub Copilot | No for routine implementation; may participate in high-risk final specialist pass |
| GitHub-Native Specialist Agents | Copilot custom agents under `.github/agents/` | No; bounded GitHub-native specialties |
| Codex Coding Agent | Codex | No for routine implementation; may participate in high-risk final specialist pass |
| Deterministic Merge Validation | GitHub Actions + repository checks | Yes for merge-eligibility facts they can verify |
| Final Human Merge Authority | CODEOWNER `@gibboda` + GitHub PR governance | Yes |

## Principles

- Use the least expensive capable agent for the task; do not turn the logical readiness order into automatic vendor chaining.
- Cursor remains primary. Bugbot autofix, Copilot, Codex, Grok, and Antigravity do not displace Cursor's default task ownership.
- Deterministic tooling runs before escalation when it can answer the unresolved question and remains authoritative for machine-verifiable facts.
- Grok Build is the exclusive independent-review provider. Copilot/Codex final specialist review does not acquire that authority.
- Antigravity remains secondary/specialist and is not a Grok-unavailable independent-review fallback.
- Copilot and Codex are native coding/review agents whose invocation is constrained by repository routing and cost policy.
- AI review is advisory, never a required status check, and never merge authority.
- AI unavailability must not block merge when required deterministic checks pass and the CODEOWNER has reviewed.

## Precedence

1. Security and repository governance
2. `AGENTS.md`
3. Repository developer documentation (this file, `CONTRIBUTING.md`, roadmap)
4. Tool-specific agent configuration
5. Individual AI-agent defaults

## Configuration map

| Path | Purpose |
| --- | --- |
| `AGENTS.md` | Canonical shared policy |
| `.cursor/rules/` | Cursor environment overlay |
| `.cursor/BUGBOT.md` | Cursor-native review/autofix policy |
| `.cursor/mcp.json` | Cursor GitHub MCP (env-var auth; no secrets) |
| `.github/instructions/` | Copilot / Codex instruction overlays |
| `.github/agents/` | GitHub-Native Specialist Agents (Copilot custom agents) |
| `.agents/agents/` | Antigravity workspace specialist agents |
| `.github/grok/` | Grok Build exclusive independent-review and specialist-advisor docs |
| `.github/antigravity/` | Antigravity secondary/specialist setup |
| `.grok/config.toml` | Grok GitHub MCP (read-only; env-var auth) |
| `.github/github-mcp.md` | Shared MCP least-privilege setup |
| `.github/workflows/` | Deterministic CI only (no LLM calls) |
| `config/agent-roles.json` | Machine-readable roles, logical ordering, overlays, and architecture invariants |
| `config/agent-escalation-record.schema.json` | Structured escalation evidence schema |
| `config/agent-work-allocation.schema.json` | Duplicate-agent work-allocation evidence schema |
| `config/agent-credential-capabilities.json` | Per-client credential and authorization boundaries |
| `config/agent-mcp-contract.json` | GitHub MCP configuration and drift contract |
| `config/pr-governance.json` | PR pipeline, risk tiers, advisory-review boundaries, and final-check ordering |
| `.github/CODEOWNERS` | Human path owners; `@gibboda` only |
| `config/agent-contract-compatibility.json` | Repository-local architecture-contract compatibility metadata |
| `config/agent-distribution.json` | Portable-versus-local package boundary |
| `config/agent-distribution-lock.json` | Immutable source pin and exact managed-file list |

The machine-readable files are validation contracts derived from `AGENTS.md`. They form one contract graph and must remain mutually consistent, but none becomes an independent policy authority.

## Secrets model

| Domain | Consumers | Notes |
| --- | --- | --- |
| GitHub Actions secrets | Workflows only | Not available to local Cursor/Antigravity/Grok |
| GitHub Agents / Copilot environment secrets | GitHub-hosted Copilot environments | Separate from Actions and local shells |
| Local environment credentials | Cursor, Antigravity, Grok Build, CLIs, MCP | Per-client credentials and local vendor login/token as required |

Never commit PATs, model tokens, OAuth tokens, or passwords. Repository-defined secret names must not start with `GITHUB_` or end with `_API_KEY`. This repository's GitHub Actions do not call xAI or Gemini and do not use vendor model credentials.

## Manual authentication prerequisites

1. **Cursor GitHub MCP**: export `CURSOR_GH_PAT` locally as needed, or complete Cloud Agent MCP header setup.
2. **Grok Build**: sign in with a SuperGrok account (`grok login`); do not use `XAI_API_KEY`. `GROK_GH_PAT` is optional for read-only GitHub MCP.
3. **Antigravity**: use local Google/Antigravity login; do not use `GEMINI_API_KEY` and do not pin `modelProvider`. `ANTIGRAVITY_GH_PAT` is optional for GitHub MCP.
4. **GitHub Copilot**: prefer GitHub-native OAuth for MCP; do not replace working OAuth with a hardcoded PAT.

Setup details: [`.github/github-mcp.md`](../.github/github-mcp.md).
