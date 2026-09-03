# Shared GitHub MCP and Projects

This repository uses the official hosted GitHub MCP server for repositories, Issues, pull requests, and GitHub Projects. GitHub MCP is capability, not an instruction to invoke multiple agents on one ordinary task.

[`AGENTS.md`](../AGENTS.md) remains authoritative for agent roles, escalation, cost policy, and human-controlled agent selection. Architecture overview: [`docs/AI-AGENT-ARCHITECTURE.md`](../docs/AI-AGENT-ARCHITECTURE.md).

## Endpoint and toolsets

```text
https://api.githubcopilot.com/mcp/
```

Enabled toolsets: `default,projects`. Do not enable `all`. GitHub Actions remains the deterministic validation authority; rulesets, branch protection, CODEOWNER review, and the human maintainer remain the merge authority.

## Credentials and roles

Use separate GitHub authorization for each client. Never commit PAT values and never use vendor/model credentials as GitHub MCP bearer tokens.

| Variable | Client | Default posture |
| --- | --- | --- |
| `CURSOR_GH_PAT` | Cursor | Repository access as needed plus `project` |
| `GROK_GH_PAT` | Grok Build | Read-only repository access plus `read:project` |
| `ANTIGRAVITY_GH_PAT` | Antigravity | Repository access as required plus `read:project` by default |

Repository-defined secret names must not start with `GITHUB_` and must not end with `_API_KEY`.

## Cursor

Tracked repository config is [`.cursor/mcp.json`](../.cursor/mcp.json). Desktop Cursor may also read user configuration. Cursor Cloud Agents require the hosted MCP server and its authorization to be configured in the cloud environment; a local PAT must not be assumed to exist in cloud execution.

## Grok Build

Tracked project config is [`.grok/config.toml`](../.grok/config.toml). Grok expands `${GROK_GH_PAT}` in headers and is deliberately GitHub-read-only through `X-MCP-Readonly: true`.

Keep Cursor MCP import disabled in user Grok configuration so Grok does not inherit Cursor's higher-privilege credential. Validate harmlessly with:

```bash
grok inspect
grok mcp doctor github
```

## Antigravity

Antigravity's current user-level MCP configuration is:

```text
~/.gemini/config/mcp_config.json
```

Keep it separate from Antigravity CLI settings at `~/.gemini/antigravity-cli/settings.json`. Do not commit either user-level file or a PAT.

Configure the hosted GitHub MCP server using the format supported by the installed Antigravity runtime. The GitHub bearer credential is `ANTIGRAVITY_GH_PAT`; default Project authorization is `read:project`. Do not grant Project write merely to prove connectivity.

Antigravity CLI (`agy`) model execution uses account login and is separate from GitHub authorization. Validate the model path with:

```bash
agy models
```

## Vendor-neutral local execution

The repository provides one explicit local entry point:

```bash
scripts/external-agent <grok|agy> [--] [agent arguments...]
```

Examples:

```bash
scripts/external-agent grok -- inspect
scripts/external-agent agy -- models
scripts/external-agent agy -- -p "Review the current branch"
```

The wrapper changes to the repository root and invokes exactly the agent selected by the human/operator. It does not choose an agent, automatically escalate, chain vendors, alter credentials, post reviews, approve, or merge.

## Validation posture

Perform harmless reads first. Grok remains read-only. Antigravity remains least-privilege and gets Project write only for an explicitly authorized task. Do not weaken token permissions, rulesets, branch protection, or the human-controlled escalation model to make a connectivity test pass.
