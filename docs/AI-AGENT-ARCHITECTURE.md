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
    |
    +-------------------+
    |                   |
    v                   v
Antigravity          Specialist tools
Specialist
    |
    v
Implementation
    |
    v
GitHub Pull Request
    |
    +------------------------+
    |                        |
    v                        v
GitHub Actions             Grok
Deterministic             Independent
Validation                 Review
    |                        |
    +-----------+------------+
                |
                v
        Branch Protection /
        Human Merge Decision
```

GitHub Copilot is the GitHub-native fallback / specialist. It is available
when work starts on GitHub, Cursor is unavailable, or an explicit
independent GitHub-side implementation is desired. It is not inserted into
every development operation.

## Roles

| Role | Owner | Mandatory for ordinary work? |
| --- | --- | --- |
| Primary development orchestrator | Cursor | Yes for default local development |
| Secondary / specialist | Google Antigravity | No; escalate only when justified |
| Independent AI reviewer | Grok / Grok Build (`grok`) | No; advisory. Backup: Antigravity CLI (`agy`) |
| Deterministic validation | GitHub Actions + local scripts | Yes for merge eligibility facts it can verify |
| GitHub-native fallback | GitHub Copilot | No; use when GitHub-native path is the gap |
| Narrow specialist | Codex or other maintainer-approved agent | No; capability-driven only |

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
| `config/agent-contract-compatibility.json` | Architecture-contract compatibility and release-class metadata (validation only; does not override `AGENTS.md`) |

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
