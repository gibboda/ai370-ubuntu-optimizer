# AI agent credential capabilities

`AGENTS.md` remains authoritative for security, agent roles, escalation, and governance. `config/agent-credential-capabilities.json` is the machine-readable capability contract derived from that policy and `.github/github-mcp.md`. It describes expected authorization boundaries; it does not grant permissions and contains no credential values.

## Design rules

Credentials are separated by client and authentication domain. GitHub credentials authorize GitHub capabilities only. Vendor/model credentials are a separate domain and must not be substituted for GitHub authorization.

Portable secret names must not start with the GitHub-reserved `GITHUB_` prefix and repository-defined credentials must not use the ambiguous `_API_KEY` suffix. Use purpose-specific token names instead.

A declared `read_write` or `read_write_when_authorized` capability is an upper bound, not an instruction to mutate. Repository rulesets, branch protection, task scope, escalation policy, and human governance still apply.

## Client contract

| Client | GitHub auth | Default posture | Projects |
| --- | --- | --- | --- |
| Cursor | `CURSOR_GH_PAT` or hosted integration | Read/write within granted scope | Read/write when `project` is authorized |
| Grok Build | `GROK_GH_PAT` | Read-only | Read-only (`read:project`) |
| Antigravity | `ANTIGRAVITY_GH_PAT` | Read by default; repository writes only when explicitly needed and authorized | Read-only by default; write only with explicit `project` permission |
| GitHub Copilot | GitHub OAuth/session | Authorization-dependent | Authorization-dependent |

Each independent client uses its own GitHub authorization. Do not reuse one unrestricted PAT across clients.

## Capability meanings

- `read_only` — mutation is outside the declared default capability.
- `read_write` — mutation may be performed when the task and repository governance permit it.
- `read_write_when_authorized` — mutation requires an explicit task need plus sufficient GitHub authorization.
- `read_only_by_default` — read is the baseline; write requires an explicit capability elevation described by policy.
- `authorization_dependent` — GitHub OAuth/session authorization determines the available capability.

## Security boundary

The contract stores variable names and authorization modes, never values. Tracked files must not contain PATs, OAuth tokens, model tokens, passwords, or bearer-token values. GitHub authorization must not be weakened merely to satisfy a connectivity test.

GitHub Actions secrets, hosted-agent environment secrets, and local client credentials remain separate credential domains as defined by `AGENTS.md`. This capability contract does not move credentials between those domains.

## Consumer behavior

Deterministic validation may consume this contract to verify MCP configuration, documentation, or future client overlays. Consumers must fail closed when a client configuration exceeds its declared capability. They must reject repository-defined credential names beginning with `GITHUB_` or ending with `_API_KEY`. They must not infer that a declared capability authorizes an otherwise prohibited operation.

The next validation layer should compare tracked MCP configuration and documented untracked-client expectations against this contract without performing write operations merely to test connectivity.
