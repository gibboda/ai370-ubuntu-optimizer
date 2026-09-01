# Antigravity specialist and backup review

Owner: **S5-M6**. Antigravity has two related roles in this repository:

1. **Secondary / specialist** (Antigravity IDE / workspace agents under
   [`.agents/agents/`](../../.agents/agents/)): architecture analysis,
   difficult debugging, security analysis, specialized research, and complex
   test investigation when Cursor escalates.
2. **Advisory independent review and specialist advice** (Antigravity CLI
   `agy`): the CODEOWNER may assign `agy` as independent reviewer and/or
   specialist advisor, including when Grok Build is available. Use `agy`
   as backup independent review when Grok Build (`grok`) is unavailable.

Neither role uses GitHub Actions or GitHub `GEMINI_API_KEY`. Follow the
Agent hierarchy in `AGENTS.md` and [`.github/grok/policy.md`](../grok/policy.md)
for review severity, categories, and the required COMMENT-only advice
record.

## Local CLI setup (`agy`)

Keep `modelProvider` in the **home-directory** file
`~/.gemini/antigravity-cli/settings.json`. The CLI does not read a
repository-relative `.gemini/` tree. Copy the canonical pin:

```bash
mkdir -p "${HOME}/.gemini/antigravity-cli"
cp .github/antigravity/settings.json "${HOME}/.gemini/antigravity-cli/settings.json"
```

Do not commit `~/.gemini/antigravity-cli/settings.json` or a repo-root
`.gemini/` copy of it. `.gitignore` already ignores `.gemini/`.

Authenticate `agy` with a local Google/Gemini login or a **shell**
`GEMINI_API_KEY` if your CLI build requires one. That local credential is
not a GitHub Actions secret. GitHub Actions does not call Gemini and does
not run `agy`. Do not use `GEMINI_API_KEY` for GitHub MCP.

Antigravity IDE GitHub MCP lives in
`~/.gemini/antigravity/mcp_config.json` and uses `serverUrl`. That format
does not interpolate environment variables in headers. Do not commit it
with a token. Default Project authorization is `read:project`. See
[`.github/github-mcp.md`](../github-mcp.md).

## Advice record

Assigned `agy` advice must be recorded as a GitHub pull-request comment or
COMMENT-only review. Do not APPROVE, REQUEST_CHANGES, or merge. Follow the
shared template in [`.github/grok/policy.md`](../grok/policy.md). If `agy`
cannot post the record, Cursor or the CODEOWNER must post the attributed
local output.

## Files

| Path | Role |
| --- | --- |
| `settings.json` | Canonical Antigravity CLI `modelProvider` pin (copy to `$HOME`) |
| `../grok/policy.md` | Shared local independent-review policy and advice-record template |
| `../../.agents/agents/` | Workspace specialist agents |

`agy` must not merge pull requests, approve as a maintainer, or change
repository settings, labels, issues, milestones, or GitHub Project state
unless Project write is explicitly required.
