# AI Agent Architecture

This document explains the repository's vendor-neutral multi-agent
development architecture. [`AGENTS.md`](../AGENTS.md) remains the
authoritative policy. Tool-specific overlays must not silently override it.

## Flow

```text
Developer
    |
    v
Cursor
Primary Development Orchestrator
implements, tests, opens/updates PR,
requests CODEOWNER @gibboda
    |
    v
GitHub Pull Request
    |
    +-------------------+-------------------+
    |                   |                   |
    v                   v                   v
GitHub Actions     CODEOWNER           Copilot and/or
Deterministic      @gibboda may        Codex
Validation         assign Grok         Final advisory
(required checks)  and/or              specialist pass
                   Antigravity         COMMENT only
                   for a second look
    |                   |                   |
    +-------------------+-------------------+
                        |
                        v
            Branch Protection /
            CODEOWNER @gibboda
            Human Merge Decision
```

GitHub remains the control plane. Cursor remains the primary development
orchestrator. CODEOWNER `@gibboda` is the required human reviewer and the
only GitHub CODEOWNERS identity. GitHub CODEOWNERS cannot name AI
products; Grok, Antigravity, Copilot, and Codex assignment is policy.

GitHub Copilot is the GitHub-native fallback / specialist. It is available
when work starts on GitHub, Cursor is unavailable, or an explicit
independent GitHub-side implementation is desired. It is not inserted into
every development operation. Copilot and/or Codex also make a
process-required, result-advisory final specialist pass (COMMENT or
suggestions only). That pass must not APPROVE in a way that satisfies
branch protection.

## Roles

| Role | Owner | Mandatory for ordinary work? |
| --- | --- | --- |
| Primary development orchestrator | Cursor | Yes for default local development |
| Required GitHub reviewer | CODEOWNER `@gibboda` | Yes on every pull request |
| Secondary / specialist | Google Antigravity | No; escalate only when justified. CODEOWNER may assign a second look |
| Independent AI reviewer | Grok / Grok Build (`grok`) | No; advisory. Backup: Antigravity CLI (`agy`). CODEOWNER may assign a second look |
| Deterministic validation | GitHub Actions + local scripts | Yes for merge eligibility facts it can verify |
| GitHub-native fallback | GitHub Copilot | No for implementation; process-required COMMENT-only final specialist pass with Codex |
| Narrow specialist | Codex or other maintainer-approved agent | No for implementation; may share the advisory final specialist pass |

## Principles

- Use the least expensive capable agent for the task.
- Do not invoke multiple AI systems for substantially identical work unless
  independent review provides a concrete benefit.
- Deterministic tooling and GitHub Actions take precedence over AI opinions
  for build, test, lint, formatting, type-checking, and other
  machine-verifiable results.
- AI review is advisory and is not a required merge gate unless repository
  governance explicitly changes that.
- Cursor is an external development orchestrator. It is not a GitHub-hosted
  Copilot custom agent.
- CODEOWNER `@gibboda` may assign Grok Build and/or Antigravity for a
  second look. Copilot and/or Codex must make a final advisory specialist
  pass. Neither assignment is a GitHub CODEOWNERS identity, required
  status check, or merge authority.
- AI unavailability must not block merge when required deterministic
  checks pass and the CODEOWNER has reviewed.

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
| `.cursor/mcp.json` | Cursor GitHub MCP (env-var auth; no secrets) |
| `.github/instructions/` | Copilot / Codex instruction overlays |
| `.github/agents/` | GitHub Copilot custom agents |
| `.agents/agents/` | Antigravity workspace specialist agents |
| `.github/grok/` | Local Grok Build independent-review docs |
| `.github/antigravity/` | Antigravity CLI backup-review setup |
| `.grok/config.toml` | Grok GitHub MCP (read-only; env-var auth) |
| `.github/github-mcp.md` | Shared MCP least-privilege setup |
| `.github/workflows/` | Deterministic CI only (no LLM calls) |
| `config/agent-roles.json` | Canonical machine-readable role, overlay-discovery, and architecture invariants derived from `AGENTS.md` |
| `config/agent-escalation-record.schema.json` | Structured escalation evidence schema |
| `config/agent-work-allocation.schema.json` | Duplicate-agent work-allocation evidence schema |
| `config/agent-credential-capabilities.json` | Per-client credential and authorization capability boundaries |
| `config/agent-mcp-contract.json` | GitHub MCP configuration and drift contract |
| `config/pr-governance.json` | Expected PR merge-governance, CODEOWNER review pipeline, and advisory-review boundary |
| `.github/CODEOWNERS` | Human path owners; `@gibboda` only. AI assignment is policy, not a CODEOWNERS identity |
| `config/agent-contract-compatibility.json` | Repository-local architecture-contract compatibility and release-class metadata (validation only; does not override `AGENTS.md` or travel in the portable package) |
| `config/agent-distribution.json` | Portable-versus-local package boundary for controlled cross-repository architecture sync; not policy authority |
| `config/agent-distribution-lock.json` | Immutable source pin and exact managed-file list for the distribution package |

The machine-readable files are validation contracts derived from `AGENTS.md`.
They form one contract graph and must remain mutually consistent, but none of
them becomes an independent policy authority. Portable tests validate each
contract, their cross-contract invariants, and end-to-end architecture
conformance. Cross-repository packaging is documented in
[`AI-AGENT-DISTRIBUTION.md`](AI-AGENT-DISTRIBUTION.md).

## Secrets model

| Domain | Consumers | Notes |
| --- | --- | --- |
| GitHub Actions secrets | Workflows only | Not available to local Cursor/Antigravity/Grok |
| GitHub Agents / Copilot environment secrets | GitHub-hosted Copilot environments | Separate from Actions and local shells |
| Local environment credentials | Cursor, Antigravity, Grok Build, CLIs, MCP | `CURSOR_GH_PAT`, `GROK_GH_PAT`, `ANTIGRAVITY_GH_PAT`, local vendor login/token as required |

Never commit PATs, model tokens, OAuth tokens, or passwords. Never put real
values in `AGENTS.md`, tracked MCP config (`.cursor/mcp.json`,
`.grok/config.toml`), agent Markdown, or docs examples. Repository-defined
secret names must not start with `GITHUB_` or end with `_API_KEY`. Untracked
home-directory MCP files may hold a PAT only when the client cannot
interpolate environment variables; see
[`.github/github-mcp.md`](../.github/github-mcp.md).

This repository's GitHub Actions do not call xAI or Gemini and do not use
vendor model credentials. Independent Grok review uses SuperGrok CLI
authentication, not an Actions-hosted model-token path.

## Manual authentication prerequisites

These steps cannot be completed from repository files alone:

1. **Cursor GitHub MCP**: export `CURSOR_GH_PAT` locally (repository
   access as needed + `project`), or complete Cloud Agent MCP header setup.
2. **Grok Build**: sign in with a SuperGrok account; optionally export
   `GROK_GH_PAT` for read-only GitHub MCP.
3. **Antigravity**: use local Google/Gemini authentication for the CLI as
   required; optionally configure `~/.gemini/antigravity/mcp_config.json`
   with `ANTIGRAVITY_GH_PAT` (that format does not interpolate env vars).
4. **GitHub Copilot**: prefer GitHub-native OAuth for MCP; do not replace
   working OAuth with a hardcoded PAT.

Setup details: [`.github/github-mcp.md`](../.github/github-mcp.md).
