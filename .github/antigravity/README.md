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

Neither role uses GitHub Actions or `GEMINI_API_KEY`. Follow the
Agent hierarchy in `AGENTS.md` and [`.github/grok/policy.md`](../grok/policy.md)
for review severity, categories, and the required COMMENT-only advice
record.

## Local CLI setup (`agy`)

Use **account login**, the same way `grok` uses SuperGrok login. Do not use
a shell `GEMINI_API_KEY`, a GitHub Actions `GEMINI_API_KEY`, or any other
vendor API key. Sign in with the Antigravity IDE or Google/Gemini login on
this machine, then confirm:

```bash
agy models
```

Do not pin `modelProvider` in Antigravity CLI settings. A `"gemini"` pin
requires `GEMINI_API_KEY` and switches the CLI off the login backend.
The tracked [settings.json](settings.json) is intentionally empty of vendor
pins so `agy` uses the default account-login backend.

Keep local CLI settings in the **home-directory** file
`~/.gemini/antigravity-cli/settings.json`. The CLI does not read a
repository-relative `.gemini/` tree. From the **repository root**, merge
the canonical file into the home-directory object (preserve any existing
`trustedWorkspaces`) and drop `modelProvider` if an older home file still
has it:

```bash
mkdir -p "${HOME}/.gemini/antigravity-cli"
python3 - <<'PY'
import json
from pathlib import Path
canonical = Path(".github/antigravity/settings.json")
p = Path.home() / ".gemini" / "antigravity-cli" / "settings.json"
data = json.loads(p.read_text()) if p.exists() else {}
data.update(json.loads(canonical.read_text()))
data.pop("modelProvider", None)
p.write_text(json.dumps(data, indent=2) + "\n")
p.chmod(0o600)
PY
```

Do not commit `~/.gemini/antigravity-cli/settings.json` or a repo-root
`.gemini/` copy of it. `.gitignore` already ignores `.gemini/`.

There is no emergency `GEMINI_API_KEY` fallback. If login fails, fix the
Antigravity/Google login on this machine; do not export a vendor API key.
GitHub Actions does not call Gemini and does not run `agy`. Do not use
`GEMINI_API_KEY` for GitHub MCP.

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
| `settings.json` | Canonical Antigravity CLI settings (no `modelProvider`; merge into `$HOME` from the repository root) |
| `../grok/policy.md` | Shared local independent-review policy and advice-record template |
| `../../.agents/agents/` | Workspace specialist agents |

`agy` must not merge pull requests, approve as a maintainer, or change
repository settings, labels, issues, milestones, or GitHub Project state
unless Project write is explicitly required.
