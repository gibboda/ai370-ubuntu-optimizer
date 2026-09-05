# Shared GitHub MCP and Projects

This repository uses the official hosted GitHub MCP server for
repositories, Issues, pull requests, and GitHub Projects. GitHub MCP is
capability. It is not an instruction to invoke Cursor, Grok Build,
Antigravity, and Copilot on the same ordinary task.

[`AGENTS.md`](../AGENTS.md) remains authoritative for agent roles,
escalation, cost policy, and human-controlled agent selection.
Architecture overview:
[`docs/AI-AGENT-ARCHITECTURE.md`](../docs/AI-AGENT-ARCHITECTURE.md).
This file is the setup and least-privilege contract for GitHub MCP clients.

## Endpoint and toolsets

```text
https://api.githubcopilot.com/mcp/
```

Enabled toolsets:

```text
default,projects
```

`default` is `context`, `repos`, `issues`, `pull_requests`, and `users`.
`projects` is requested with the `X-MCP-Toolsets` header. Do not enable
`all`. Do not replace this header with the single-toolset path
`/mcp/x/projects` as the only GitHub MCP server.

Expected Project tools:

```text
projects_list
projects_get
projects_write
```

Do not depend on deprecated Project tool names when defining policy.

## Roles

| Client | Role | GitHub Projects authorization | MCP write posture |
| --- | --- | --- | --- |
| Cursor | Primary development orchestrator | `project` (read and write) | Read/write Issues, PRs, and Projects where authorized |
| Grok Build | Independent reviewer and specialist advisor (advisory) | `read:project` | `X-MCP-Readonly: true`; no Project, Issue, PR, or repository mutation by default. Assigned advice is recorded as a COMMENT-only PR comment or COMMENT review out of band or by Cursor/CODEOWNER |
| Antigravity | Secondary / specialist; CLI (`agy`) is a specialist advisor, not an independent-review fallback | `read:project` by default; `project` only when Project mutation is required | No `X-MCP-Readonly` by default so repository writes can work when the token allows them. Assigned `agy` advice is COMMENT-only and must not APPROVE, REQUEST_CHANGES, or merge |
| GitHub Copilot | GitHub-native fallback / specialist | GitHub OAuth / session scopes | Prefer OAuth; do not replace working OAuth with a PAT |

GitHub Projects is the source of truth for planned and workflow state
where Projects are used. GitHub Actions is the source of truth for
deterministic validation. GitHub rulesets and branch protection remain
the final merge authority. MCP credentials must not bypass those
controls and must not carry administrative privileges without a
demonstrated requirement.

## Secrets

Use a separate GitHub authorization for each independent client. Never
commit PAT values. Never put tokens in `AGENTS.md`, `README.md`,
`.cursor/rules`, `.cursor/mcp.json`, `.grok/config.toml`, or this file.
Repository-defined secret names must not start with `GITHUB_` and must not
end with `_API_KEY`.

| Variable | Client | Required GitHub token permissions |
| --- | --- | --- |
| `CURSOR_GH_PAT` | Cursor | repository access as needed, plus `project` |
| `GROK_GH_PAT` | Grok Build | read-only repository access as needed, plus `read:project` |
| `ANTIGRAVITY_GH_PAT` | Antigravity | repository access as required, plus `read:project` by default |

Do not reuse one unrestricted PAT across every AI client. Vendor/model
credentials are separate from GitHub authorization and must not be used as
GitHub MCP bearer tokens.

Set the variables in the user environment only, for example in
`~/.bashrc` or `~/.profile` on Linux:

```bash
export CURSOR_GH_PAT='…'
export GROK_GH_PAT='…'
export ANTIGRAVITY_GH_PAT='…'
```

Do not paste those values into tracked files.

## Cursor

Tracked repository config is [`.cursor/mcp.json`](../.cursor/mcp.json).
It interpolates `CURSOR_GH_PAT` and must stay secret-free.

Desktop Cursor also reads `~/.cursor/mcp.json` when present. Merge the
`github` server into that file; do not overwrite other MCP servers, and
do not create a second GitHub MCP definition.

Cursor Cloud Agents do not take `CURSOR_GH_PAT` from `mcp.json`. Add
the hosted server in the Cloud Agent MCP dropdown or Dashboard →
Integrations & MCP, then enable it for this environment:

- URL: `https://api.githubcopilot.com/mcp/`
- Header: `Authorization: Bearer <CURSOR_GH_PAT>`
- Header: `X-MCP-Toolsets: default,projects`

`mcpServerAllowlist` only permits a server URL. It does not install
headers. Do not commit `.cursor/environment.json` only to add an
allowlist: a committed file would override a dashboard-managed Cloud
Agent environment. If this environment later becomes repository-managed,
allow:

```json
"mcpServerAllowlist": [
  {
    "name": "github",
    "serverUrl": "https://api.githubcopilot.com/mcp/"
  }
]
```

## Grok Build

Tracked project config is [`.grok/config.toml`](../.grok/config.toml).
Grok expands `${GROK_GH_PAT}` in headers. Keep Grok on a different,
lower-privilege credential than Cursor. Do not rely on Grok importing
`.cursor/mcp.json`.

In `~/.grok/config.toml` (user config, not this repository), disable
Cursor MCP import and keep the same `github` server:

```toml
[compat.cursor]
mcps = false

[mcp_servers.github]
url = "https://api.githubcopilot.com/mcp/"
headers = { Authorization = "Bearer ${GROK_GH_PAT}", "X-MCP-Toolsets" = "default,projects", "X-MCP-Readonly" = "true" }
```

Quoted header keys are required in TOML because `X-MCP-Toolsets` and
`X-MCP-Readonly` contain hyphens.

Validate with:

```bash
grok inspect
grok mcp doctor github
```

Assigned Grok advice still requires a durable COMMENT-only pull-request
record. GitHub MCP stays read-only, so do not post that record through MCP
write tools. Post out of band or have Cursor or the CODEOWNER post the
attributed local output. See [`.github/grok/policy.md`](grok/policy.md).

## Antigravity

Official GitHub MCP config for Antigravity is
`~/.gemini/antigravity/mcp_config.json` and uses `serverUrl`, not `url`.
The currently documented Antigravity MCP format does **not** interpolate
environment variables in headers. Do not invent `${env:…}` or `${VAR}`
syntax there. Do not commit that file with a token.

Copy this locally, paste `ANTIGRAVITY_GH_PAT`, and restrict
permissions (`chmod 600`):

```json
{
  "mcpServers": {
    "github": {
      "serverUrl": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer PASTE_ANTIGRAVITY_GH_PAT",
        "X-MCP-Toolsets": "default,projects"
      }
    }
  }
}
```

Leave `X-MCP-Readonly` unset unless Antigravity should be GitHub-read-only.
Keep the token at `read:project` unless Project mutation is explicitly
required. Prefer the hosted GitHub MCP endpoint over a third-party GitHub
MCP implementation.

Keep this MCP file separate from Antigravity CLI settings at
`~/.gemini/antigravity-cli/settings.json`. Antigravity CLI (`agy`)
independent review and specialist advice are separate from this IDE MCP
file. `agy` model execution uses account login and is separate from
GitHub authorization. Validate the model path with:

```bash
agy models
```

Assigned `agy` advice must still be recorded as a COMMENT-only
pull-request comment or COMMENT review. See
[`.github/antigravity/README.md`](antigravity/README.md).

## GitHub Copilot / VS Code

Prefer GitHub-native OAuth. VS Code 1.101+ stores MCP servers in
workspace `.vscode/mcp.json` or the user profile MCP file. This
repository gitignores `.vscode/`, so do not add a tracked Copilot PAT
file.

OAuth configuration (no Authorization header):

```json
{
  "servers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "X-MCP-Toolsets": "default,projects"
      }
    }
  }
}
```

In Copilot Chat, use Agent mode, open the MCP tool picker, and complete
GitHub sign-in from the CodeLens **Auth** action on that server. Do not
replace functioning OAuth with a hardcoded PAT.

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

The wrapper changes to the repository root and invokes exactly the agent
selected by the human/operator. It does not choose an agent, automatically
escalate, chain vendors, alter credentials, post reviews, approve, or
merge.

## Validation

Perform only harmless reads first. Do not modify a Project merely to
prove connectivity.

| Client | Read | Project write |
| --- | --- | --- |
| Cursor | Allowed | Allowed when `CURSOR_GH_PAT` has `project` |
| Grok Build | Allowed | Blocked (`read:project` + `X-MCP-Readonly`) |
| Antigravity | Allowed | Blocked unless `project` is explicitly granted |
| Copilot | Allowed | Depends on the GitHub authorization the user granted |

Do not weaken token permissions, rulesets, or branch protection to make
a test pass. Do not weaken the human-controlled escalation model to make
a connectivity test pass.
