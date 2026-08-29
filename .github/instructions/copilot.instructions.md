---
applyTo: "**"
---

# Copilot implementation instructions

GitHub Copilot is the GitHub-native fallback / specialist in this
repository, not the default implementation agent.
[`../../AGENTS.md`](../../AGENTS.md) is authoritative for shared agent
roles, escalation, cost policy, architecture, testing, naming, and change
discipline. Do not restate or override that policy here.

Follow the reading order in `AGENTS.md` before changing code, including any
nested `AGENTS.md` that applies to the files being changed. Escalate Copilot
only when `AGENTS.md` allows specialist use. See the Agent hierarchy in
`AGENTS.md` rather than restating it here. Do not treat Copilot as a parallel
reviewer for routine Cursor work. When invoking Copilot, name the GitHub
product in scope: coding agent, pull-request review, Projects MCP, or a
custom agent under `.github/agents/`. Prefer GitHub-native OAuth for the
official hosted GitHub MCP endpoint; do not replace functioning OAuth with a
PAT. Setup is [`.github/github-mcp.md`](../github-mcp.md).
