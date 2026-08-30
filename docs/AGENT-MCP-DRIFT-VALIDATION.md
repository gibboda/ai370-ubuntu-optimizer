# MCP configuration drift validation

`AGENTS.md` remains authoritative. `config/agent-credential-capabilities.json` defines the expected GitHub authorization boundary for each AI client. `config/agent-mcp-contract.json` defines the deterministic configuration expectations used to detect drift between that capability contract and GitHub MCP configuration.

## Scope

The drift layer validates configuration; it does not validate secret values, invoke an AI, grant permissions, or perform repository/Project mutations.

Tracked configuration is validated directly for:

- Cursor: `.cursor/mcp.json`
- Grok Build: `.grok/config.toml`

Clients whose effective configuration is intentionally untracked are validated against the repository-owned setup contract in `.github/github-mcp.md`:

- Antigravity: `~/.gemini/antigravity/mcp_config.json`
- GitHub Copilot / VS Code: OAuth/session MCP configuration

## Invariants

All clients use the official hosted endpoint and the `default,projects` toolsets. `all` is prohibited. The Projects-only endpoint must not replace the shared MCP endpoint.

Cursor uses `CURSOR_GH_PAT` and may write only within the capability and governance boundary declared by the credential capability contract.

Grok Build uses `GROK_GH_PAT` and must retain `X-MCP-Readonly: true`. Its GitHub capabilities remain read-only and its review remains advisory.

Antigravity uses its own `ANTIGRAVITY_GH_PAT` in local untracked configuration. Its Projects capability is read-only by default; Project mutation requires explicit authorization and sufficient token permission.

GitHub Copilot uses GitHub-native OAuth/session authorization by default. The repository does not introduce a Copilot PAT merely to make MCP work.

Tracked MCP files must contain no credential values. Client credential variables must remain separate, must not start with `GITHUB_`, and must not end with `_API_KEY`.

## Validation boundary

The deterministic test suite parses tracked JSON/TOML configuration and compares it to both machine-readable contracts. It checks the documented expectations for untracked clients because repository CI cannot safely inspect a maintainer's home-directory credential configuration.

The test suite must not make a live MCP write call. Connectivity testing starts with harmless reads, and a Project must never be modified merely to prove access. A failing validation must not be fixed by broadening a PAT, enabling `all`, weakening rulesets, or weakening branch protection.

This layer detects repository configuration drift. It does not prove that a locally stored credential exists, is valid, or currently has the documented GitHub permissions; those are runtime/operator facts rather than repository contract facts.
