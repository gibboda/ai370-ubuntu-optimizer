# Antigravity secondary / specialist

Owner: **S5-M6**. Antigravity is the repository's **secondary / specialist**
resource. Antigravity IDE / workspace agents under [`.agents/agents/`](../../.agents/agents/)
provide architecture analysis, difficult debugging, security analysis,
specialized research, complex test investigation, and a specialist second
implementation perspective when escalation is justified.

Antigravity CLI (`agy`) is an invocation surface for that same secondary /
specialist role. It is the repository's **Backup independent review** path
when Grok Build is unavailable, and otherwise remains a specialist second-look
or specialist-advice resource. A CODEOWNER may assign Antigravity for bounded
specialist work; findings remain advisory.

Neither Antigravity surface uses GitHub Actions or `GEMINI_API_KEY`. Follow the
Agent hierarchy in `AGENTS.md`. Grok's independent-review policy remains under
[`.github/grok/`](../grok/).

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
with a token. Keep it separate from the Antigravity CLI settings file
above. Default Project authorization is `read:project`. See
[`.github/github-mcp.md`](../github-mcp.md).

## Vendor-neutral local invocation

For explicit human-controlled local execution, use the repository wrapper:

```bash
scripts/external-agent agy
```

Arguments after the agent name are passed through unchanged, for example:

```bash
scripts/external-agent agy -- models
scripts/external-agent agy -- -p "Perform a specialist analysis of the current branch"
```

The wrapper only normalizes invocation from the repository root. It does
not select an agent, escalate automatically, chain vendors, grant GitHub
permissions, or change the advisory policy.

## Specialist advice record

Assigned `agy` specialist advice should be recorded as a GitHub pull-request
comment or COMMENT-only review when it is part of PR review. Do not APPROVE,
REQUEST_CHANGES, or merge. If `agy` cannot post the record, Cursor or the
CODEOWNER can post the attributed local output.

## Files

| Path | Role |
| --- | --- |
| `settings.json` | Canonical Antigravity CLI settings (no `modelProvider`; merge into `$HOME` from the repository root) |
| `../../.agents/agents/` | Workspace specialist agents |
| `../../scripts/external-agent` | Explicit vendor-neutral local execution wrapper |

`agy` must not merge pull requests, approve as a maintainer, or change
repository settings, labels, issues, milestones, or GitHub Project state
unless Project write is explicitly required.
