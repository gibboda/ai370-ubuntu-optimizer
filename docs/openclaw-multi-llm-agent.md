# OpenClaw Multi-LLM Agent Blueprint

This blueprint maps an OpenClaw-based personal agent onto the optimizer's
offline-first runtime architecture. It is an integration plan, not a claim that
OpenClaw is currently installed or supported by an existing command.

OpenClaw releases may change their provider and tool configuration formats.
Pin a tested OpenClaw release and translate the provider roles below into that
release's documented configuration instead of copying unversioned examples.

## What the repository already provides

Build the agent above the existing stage boundaries rather than adding another
model runtime:

| Layer | Existing capability | Agent use |
| --- | --- | --- |
| Stage 1 | Hardware, kernel, GPU, NPU, memory, and storage validation | Establish a trustworthy host before granting an agent tools |
| Stage 2 | Ollama, llama.cpp, optional Lemonade, model storage, benchmarks, and optional RAG | Supply local model endpoints and evidence about available acceleration |
| Stage 3 | Planned agent/RAG applications and application validation | Natural home for OpenClaw install, configuration, and smoke tests |
| Stage 4 | Planned VS Code, Continue, Aider, and developer tooling | Supply an opt-in coding-agent tool profile |
| Stage 5 | Planned lifecycle, backup, health, and update automation | Operate the agent after its application path is validated |

AnythingLLM is already the optional document/RAG application path. Reuse its
document and embedding assets where formats permit, but do not make OpenClaw
depend on the AnythingLLM UI or container.

## Recommended architecture

```text
chat or automation trigger
          |
          v
OpenClaw agent (policy, memory, tools)
          |
          +-- router role ------> small local Ollama model
          +-- reasoning role ---> larger Ollama or Lemonade-served model
          +-- coding role ------> local coding model
          +-- embedding role ---> staged local embedding model
          +-- optional remote --> explicit opt-in provider
          |
          +-- read-only tools by default
          +-- approval boundary for writes, shell, network, and devices
```

Keep orchestration and inference separate. OpenClaw owns conversations, tool
policy, and routing; Ollama and Lemonade remain sibling inference services. A
single provider adapter per service makes model replacement possible without
rewriting agent behavior.

### Provider roles

Configure roles, not hard-coded model names, in agent workflows:

- **router:** a small, fast local model for intent classification and tool
  selection;
- **reasoner:** the highest-quality local model that fits memory, with an
  optional remote fallback only when the user enables it;
- **coder:** a local code-specialized model with repository context;
- **embedder:** the staged embedding model used by the offline RAG path;
- **vision:** optional and disabled until an application-level image workload
  has been validated.

Record the concrete model, runtime, quantization, context limit, and artifact
location in `configs/models/manifest.yaml`. Do not silently route to a cloud
provider when a local role is unavailable.

### Routing policy

Use deterministic rules before model-based routing:

1. Keep secrets, personal documents, shell output, and repository content on
   local providers by default.
2. Send short classification and extraction work to the router.
3. Send code changes to the coder and require tests plus a human-approved diff.
4. Escalate difficult local work to the reasoner only after the router fails or
   reports low confidence.
5. Use a remote model only through a named, opt-in policy with a visible data
   disclosure warning, timeout, and spending limit.
6. Fail closed when no eligible provider is healthy; never choose a provider
   merely because it is reachable.

Retries should stay on the same provider for transient failures. A fallback to
another provider is a new routing decision and must still satisfy privacy,
capability, and cost policy.

## Build sequence

### 1. Validate the host and local runtimes

```bash
./ai370-optimize.sh stage1
./ai370-optimize.sh stage2
./ai370-optimize.sh stage2-validate --bench
```

Review the generated reports before continuing. The agent should not infer GPU
or NPU execution from a provider name alone; use the repository's measured
runtime and execution-provider reports.

### 2. Stage the role models

Add one model per required role to the model manifest, stage artifacts under
the repository's configured offline model root, and run:

```bash
./ai370-optimize.sh stage2-models
./ai370-optimize.sh stage2-runtime-validate --offline
```

Start with router, reasoner, coder, and embedder roles. Adding several similar
chat models increases storage and operational complexity without adding a new
capability.

### 3. Prove one provider before adding routing

Connect a pinned OpenClaw release to one loopback-only local provider. Validate
a conversation, structured output, cancellation, timeout handling, and a
read-only tool call. Then add the second provider and routing policy.

For Ollama, prefer its supported local API. For a runtime exposing an
OpenAI-compatible API, give it a distinct base URL and synthetic local-only
credential if the client requires a key. Do not expose either endpoint on the
LAN until authentication and host firewall policy have been reviewed.

### 4. Add memory and RAG

Keep these stores distinct:

- short-lived conversation state;
- durable user-approved memory;
- indexed documents and embedding metadata;
- tool audit events.

Every durable memory write should have provenance, a retention rule, and a user
deletion path. Treat retrieved text as untrusted data, not instructions, to
limit prompt-injection through local documents.

### 5. Add tools by risk tier

| Tier | Examples | Default policy |
| --- | --- | --- |
| 0 | health, model list, read-only search | Allow within an explicit workspace |
| 1 | create a draft, edit a scratch file | Ask before persistence |
| 2 | repository edits, package operations, external network | Show plan and require approval |
| 3 | credentials, privilege escalation, destructive shell, device control | Deny unless separately designed and sandboxed |

Use allowlisted commands with structured arguments rather than an unrestricted
shell tool. Run the agent as an unprivileged service account, scope filesystem
access, redact secrets from logs, and place time and output limits on every
tool.

## Proposed repository implementation

An implementation should be delivered as a Stage 3 application milestone and
remain optional. A small first slice would add:

```text
scripts/330-install-openclaw.sh
scripts/335-validate-openclaw.sh
configs/openclaw/providers.example.yaml
configs/openclaw/policies.example.yaml
```

The exact filenames and configuration serialization should follow the pinned
OpenClaw release. The installer should follow existing repository conventions:

- accept profile, tuning, persistence, and offline arguments;
- make all downloads opt-in and support staged offline artifacts;
- be idempotent and avoid modifying user configuration without a backup;
- bind local services to loopback by default;
- emit machine-readable JSON and a Markdown summary under `reports/latest/`;
- report `WARN` when optional providers or models are absent;
- never store provider secrets in tracked files or generated reports.

The validator should prove behavior, not just process presence:

1. OpenClaw version and pinned configuration schema are recognized.
2. Each enabled provider passes a bounded health and inference smoke test.
3. Role-to-model mappings reference locally available manifest entries.
4. Local-only mode cannot select a remote provider.
5. Tool allowlists and workspace boundaries reject a negative test.
6. A routed request records the selected role/provider without prompt or secret
   leakage.
7. Shutdown leaves no orphan agent or model-server processes.

## Definition of done for a personal-agent MVP

- One local conversation survives an agent restart without losing approved
  memory.
- Router and reasoner roles can use different local models.
- Local-only mode works with the network unavailable.
- RAG answers include document provenance.
- Read-only tools work inside one allowlisted workspace.
- Mutating tools require explicit approval and produce an audit event.
- Provider failure is visible and fails closed instead of silently using cloud.
- Benchmarks record latency and selected provider for representative tasks.
- Backup and deletion procedures cover configuration, memory, indexes, and
  audit logs.

This MVP deliberately excludes autonomous privilege escalation, unrestricted
shell access, unattended purchases, and silent cloud fallback.
