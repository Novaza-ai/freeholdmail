<!-- Last-touched: 2026-11-04 — new: the MCP server, its threat model, and how to run it. -->
# MCP server for agents

An [MCP](https://modelcontextprotocol.io) server that gives an AI agent access to **one
mailbox, scoped by you**: which folders it can see, whether it can draft, organise or send,
and to whom. Every call is written to an audit log, and access is withdrawn by editing one
file, with no restart.

It talks to the mail server over JMAP (RFC 8620/8621) and is an optional overlay. Without
`docker-compose.mcp.yml` nothing in this document runs.

> **Status: new in this release, and measured.** `tests/test_e2e.sh --mcp` stands up the real stack,
> builds this image and drives it with a real MCP client: **43 / 43** assertions, including a
> message delivered to the recipient's mailbox and read back as the recipient. The OAuth
> (`keycloak`) mode is covered by unit tests with real RS256 signatures and by a live check of
> its metadata and `401` answers, **but not yet end to end against a running Keycloak.**
> See [Known limits](#known-limits).

## Quick start

```bash
cp config/mcp/agents.toml.example config/mcp/agents.toml

# 1. A mailbox app password for this agent: revocable on its own, never shown to the agent.
SECRET=$(openssl rand -hex 16)
curl -u "admin:$STALWART_FALLBACK_ADMIN_SECRET" -X PATCH \
  http://127.0.0.1:8080/api/principal/you@example.com \
  -d "[{\"action\":\"addItem\",\"field\":\"secrets\",\"value\":\"\$app\$agent-triage\$$SECRET\"}]"
printf '%s' "$SECRET" > config/mcp/triage.app
sudo chown 10001 config/mcp/triage.app && chmod 600 config/mcp/triage.app

# 2. A token for the agent. Give it the token; put only the hash in agents.toml.
docker compose -f docker-compose.yml -f docker-compose.mcp.yml run --rm mcp new-token

# 3. Edit config/mcp/agents.toml (account, folders, scopes, token_sha256), then:
docker compose -f docker-compose.yml -f docker-compose.mcp.yml up -d
curl -s http://127.0.0.1:8090/healthz    # {"status":"ok","version":"…","agents":1}
```

Connect a client. The server listens on loopback. Agents on other machines reach it through
your TLS reverse proxy (set `FREEHOLD_MCP_ALLOWED_HOSTS` to the public `host:port`), never
over plain HTTP:

```json
{ "mcpServers": { "freehold-mail": {
    "type": "http", "url": "https://mcp.example.com/mcp",
    "headers": { "Authorization": "Bearer <token>" } } } }
```

For a local agent, stdio needs no network and no token. The process boundary is the trust
boundary:

```json
{ "command": "python", "args": ["-m", "freehold_mcp", "serve-stdio"],
  "env": { "FREEHOLD_MCP_AGENT": "triage", "FREEHOLD_MCP_POLICY": "/etc/freehold-mcp/agents.toml",
           "FREEHOLD_MCP_AUDIT_LOG": "/var/log/freehold-mcp/audit.jsonl",
           "FREEHOLD_MCP_JMAP_URL": "https://mail.example.com" } }
```

## Tools

| Tool | Scope | What it does | Annotations |
|------|-------|--------------|-------------|
| `mail_list_folders` | `mail:read` | Folders the agent may see, with counts | read-only |
| `mail_search` | `mail:read` | Text / sender / recipient / subject / date / unread, newest first, ≤ 50 | read-only |
| `mail_read` | `mail:read` | Headers, plain-text body (HTML reduced to text), attachment list | read-only |
| `mail_create_draft` | `mail:draft` | Plain-text draft in Drafts; optional reply threading. Sends nothing | not destructive |
| `mail_send` | `mail:send` | Sends **an existing draft**, only to allow-listed recipients | destructive, open-world |
| `mail_move` | `mail:organize` | Moves a message between permitted folders | idempotent |
| `mail_set_flags` | `mail:organize` | Read / unread, flagged / unflagged | idempotent |

Every tool declares an output schema. **There is no delete tool.** The worst an organising
agent can do is move mail into another folder it is allowed to use, and a person can move it
back.

## Policy

`config/mcp/agents.toml` is the single place access is granted. The example file documents
every field. The rules the server enforces:

- **Scopes are a closed set.** `mail:sned` is a startup error, not a silent no-op.
- **`mail:send` requires `send_to`**, a list of exact addresses or `@domain` suffixes.
  `@partner.example` matches `x@partner.example` but neither `x@sub.partner.example` nor
  `x@evilpartner.example`. There is no "anyone" setting, because send without an allow-list
  turns whoever holds the token into an open relay.
- **Folders are by name or role** (`inbox`, `drafts`, `sent`, `archive`, …); `"*"` means all.
- **Sending is two steps on purpose**: `mail_create_draft`, then `mail_send` with its id. The
  draft must be in Drafts, flagged `$draft`, and from the agent's own address.
- `max_sends_per_hour`, `expires` (timezone required) and `revoked` are optional.
- **Hot reload**: the file is re-read when it changes. If an edit leaves it broken, the server
  refuses every request until it is fixed. Falling back to the previous version would keep a
  just-revoked agent alive.

## Threat model

**What is protected:** the mailbox's contents, the ability to send as its owner, and the
mailbox password.
**Who is assumed hostile:** whoever writes the mail an agent reads; anyone who obtains an
agent's token; and an agent that has been talked into misbehaving. The agent host and the
model are **not** trusted to enforce anything. Every rule below is enforced server-side.

| Threat | Control | Proven by |
|--------|---------|-----------|
| Agent holds the mailbox password | It never does. The server reads a per-agent **app password** from a file the agent cannot see | design; `credential_file` |
| Stolen agent token | Stored only as SHA-256; constant-time compare; scoped; `revoked = true` takes effect on the next request | E2E: revoked agent → `401` with no restart |
| Whole agent compromised | Revoke its app password at the mail server; every agent using it is cut off there | E2E: app password removed → every call refused |
| Prompt injection in an incoming mail | Message text is returned only in `untrusted_*` fields and the server instructions say to treat it as data. **This labels the risk; it does not remove it.** The controls that hold whatever the model does: no delete tool, sending limited to the allow-list, rate limit, two-step send | E2E: the injected text appears only in `untrusted_text` |
| Exfiltration by email | `mail_send` refuses any recipient off the allow-list (To, Cc and Bcc) and leaves the draft unsent | E2E + mutation: disabling the check fails the suite |
| Reading outside the granted folders | Search is filtered to permitted mailboxes. A message in another folder answers **exactly** like a missing one, so its existence cannot be probed | E2E + mutation: removing the check fails the suite |
| Changing folders it cannot see | `mail_move` adds and removes only folders in scope; a message also filed in an unseen folder stays there | E2E + mutation: replacing all folders fails the suite |
| Runaway sending | `max_sends_per_hour`, reserved before submission and returned if the send fails | E2E; unit test + mutation for the refund |
| Spoofing another sender | A draft must be from the agent's own account. The mail server only issues a sending identity for an address that account owns | E2E; Stalwart: `Identity/set` refuses foreign addresses |
| DNS rebinding against a local server | Host header checked against `FREEHOLD_MCP_ALLOWED_HOSTS` | E2E: foreign `Host` → `421` |
| No record of what an agent did | Append-only JSON-lines audit, `fsync`'d before the tool returns, mode `0600`. Covers refusals and errors too. Message bodies are stored as SHA-256 + length only | E2E: one line per call (26/26), no body text in the file |
| Image tampering | Base image pinned by digest, every Python dependency hash-locked, non-root uid 10001, read-only root filesystem, no capabilities | `tests/test_config.sh` MCP guards |

**Not in scope:** a malicious operator (they own the mail server anyway), and a compromised
host.

## Authentication modes

| Mode | Set by | For | How |
|------|--------|-----|-----|
| `static` (default) | `FREEHOLD_MCP_AUTH=static` | Base edition | Per-agent bearer token. **No OAuth metadata is published**: advertising an authorization server that does not exist would be a claim a client could act on |
| `keycloak` | `FREEHOLD_MCP_AUTH=keycloak`, `FREEHOLD_MCP_OIDC_ISSUER`, `FREEHOLD_MCP_RESOURCE_URL` | SSO edition | OAuth 2.1 resource server. JWTs are checked for signature (realm JWKS), issuer, audience (`FREEHOLD_MCP_AUDIENCE`, default the resource URL, RFC 8707) and expiry. Serves Protected Resource Metadata (RFC 9728) and answers `401` with `WWW-Authenticate: … resource_metadata=…`. The token's client id (`azp`) selects the agent via `oauth_client_id`. Effective scopes = **token scopes ∩ policy scopes** |
| stdio | `serve-stdio`, `FREEHOLD_MCP_AGENT` | Local agents | One process, one agent; revocation still applies on every call |

Transport is **stateless Streamable HTTP** with JSON responses, so any number of replicas can
sit behind one proxy without session affinity.

## Configuration

| Variable | Default | Meaning |
|----------|---------|---------|
| `FREEHOLD_MCP_JMAP_URL` | *(required)* | Mail server base URL. The session's `apiUrl` host is ignored: only its path is used |
| `FREEHOLD_MCP_POLICY` | `/etc/freehold-mcp/agents.toml` in the image | Policy file |
| `FREEHOLD_MCP_AUDIT_LOG` | `/var/log/freehold-mcp/audit.jsonl` in the image | Audit log |
| `FREEHOLD_MCP_AUTH` | `static` | `static` or `keycloak` |
| `FREEHOLD_MCP_ALLOWED_HOSTS` | `127.0.0.1:<port>,localhost:<port>` | Accepted `Host` values |
| `FREEHOLD_MCP_JMAP_VERIFY_TLS` | `true` | `false` only on the internal compose network |
| `FREEHOLD_MCP_MAX_BODY_CHARS` | `20000` | Longer bodies are cut and marked `truncated` |
| `FREEHOLD_MCP_HOST` / `_PORT` | `127.0.0.1` / `8090` | Listen address (`0.0.0.0` inside the container) |

## Operations

- **Revoke one agent:** set `revoked = true` in `agents.toml`. Takes effect on the next request.
- **Revoke at the mail server as well:** remove its app password
  (`{"action":"removeItem","field":"secrets","value":"$app$<name>$<secret>"}`).
- **Who sent this?**
  `jq 'select(.tool=="mail_send" and .outcome=="ok")' audit.jsonl` gives the agent, the time
  and the message and submission ids.
- **Rotate a token:** `new-token`, replace `token_sha256`, save. The old token stops working
  at once.

## Known limits

- **The OAuth mode has no end-to-end test against a live Keycloak yet.** The JWT checks are
  unit-tested with real signatures, and the metadata and `401` behaviour were checked on a
  running server. The token-issuing half has not been.
- **Sending needs a real domain.** Stalwart only grants a sending identity for an address
  under a public suffix, which rules out `*.test` and `*.internal`. The server then reports
  exactly that instead of a vague refusal.
- The send rate limit lives in memory: a restart resets it, and replicas do not share it.
- Drafts are plain text. Attachments can be listed but not downloaded or attached.
- A call whose arguments fail schema validation (a wrong type, `limit` above 50) is rejected by
  the protocol layer before the tool runs, and is not in the audit log. Every call that
  reaches a tool is: allowed, refused, or failed.
- One mailbox per agent entry. Give an agent several entries if it needs several mailboxes.
- Anything agentic here works with a model you choose, including a local one. The server
  sends nothing to a model provider. It is the tool, not the model.
