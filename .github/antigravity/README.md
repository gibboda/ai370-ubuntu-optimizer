# Independent Antigravity CLI review

Owner: **S5-M6**. Independent backup pull-request review is the local
Antigravity CLI (`agy`). It is not a GitHub Actions workflow and it does
not use GitHub `GEMINI_API_KEY`.

Use `agy` only when Grok Build (`grok`) is unavailable. Follow the Agent
hierarchy in `AGENTS.md` and [`.github/grok/policy.md`](../grok/policy.md).

## Local setup

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

## Files

| Path | Role |
| --- | --- |
| `settings.json` | Canonical Antigravity CLI `modelProvider` pin (copy to `$HOME`) |
| `../grok/policy.md` | Shared local independent-review policy |

`agy` must not merge pull requests, approve as a maintainer, or change
repository settings, labels, issues, milestones, or GitHub Project state
unless Project write is explicitly required.
