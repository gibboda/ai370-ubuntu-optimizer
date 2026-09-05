---
applyTo: "**"
---

# Copilot implementation instructions

GitHub Copilot is the **GitHub-Native Coding Agent** in this repository,
not the default implementation agent. "Fallback" is a routing condition,
not Copilot's role identity.
[`../../AGENTS.md`](../../AGENTS.md) is authoritative for shared agent
roles, escalation, cost policy, architecture, testing, naming, and change
discipline. Do not restate or override that policy here.

Follow the reading order in `AGENTS.md` before changing code, including any
nested `AGENTS.md` that applies to the files being changed. Invoke Copilot
only when `AGENTS.md` allows GitHub-native coding/review work or the final
native specialist pass. See the Agent hierarchy in `AGENTS.md` rather than
restating it here. Do not treat Copilot as a parallel default implementer for
routine Cursor work.

When invoking Copilot, name the GitHub-native product surface in scope: coding
agent, Copilot code review, Projects MCP, or a custom specialist agent under
`.github/agents/`. Repository custom agents are **GitHub-Native Specialist
Agents** beneath the Copilot role; they do not become independent reviewers,
required checks, or merge authorities.

For the pre-merge pipeline, Copilot may participate after Grok Build and
Antigravity review/advice and before the final GitHub required-check state and
CODEOWNER merge decision. On high-risk pull requests the Copilot/Codex final
specialist pass is process-required but result-advisory. COMMENT or suggestions
only; do not APPROVE in a way that satisfies branch protection.

Prefer GitHub-native OAuth for the official hosted GitHub MCP endpoint; do not
replace functioning OAuth with a PAT. Setup is
[`.github/github-mcp.md`](../github-mcp.md).
