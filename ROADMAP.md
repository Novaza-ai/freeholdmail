<!-- Last-touched: 2026-11-04 — Agentic Mail's first three items are built and tested (MCP server,
     per-agent scoped credentials, audit trail); the "where we are" table re-measured. -->
# Roadmap

This file separates three things that are easy to blur: **what works today and was
measured**, **what we intend to build**, and **what we would like help with**. Nothing in
the "intend" or "help wanted" columns is a promise, and nothing here is marketing.

## Where we are

Measured on a throwaway stack built from this repo (see `tests/`):

| Capability | Status | Evidence |
|------------|--------|----------|
| Full Mail edition boots and delivers | ✅ works | `tests/test_e2e.sh` — **14/14**, a real message goes SMTP → mailbox → IMAP with a matching `Message-ID` |
| Security defaults | ✅ verified | relay refused `550 5.1.2`, unauthenticated submission refused `503 5.5.1`, password AUTH only after STARTTLS, TLS 1.3 on 465 — re-measured 2026-08-05 |
| SSO edition starts | ⚠️ partial | `tests/test_e2e.sh --sso` — **15/15** on the shipped **Keycloak 26.8.1**; the browser login round-trip is still unmeasured |
| MCP server for agents | ✅ works | `tests/test_e2e.sh --mcp` — **43/43** against the real stack: folder isolation, scopes, allow-listed send delivered to the recipient, revocation without restart, audit trail. 30 unit tests. Four security checks mutation-tested |
| MCP OAuth mode (SSO edition) | ⚠️ partial | JWT checks unit-tested with real signatures; RFC 9728 metadata and `401` verified live; no end-to-end run against Keycloak yet |
| Browser OIDC login | ❌ untested | needs browser automation |
| Deliverability (SPF/DKIM/DMARC scoring) | ❌ unmeasured | needs a real public domain |

## v0.1 — make the boring parts trustworthy

Work that has to land before the rest of the roadmap is worth starting.

- ~~Pin every image by digest, including the webmail.~~ **Done in 0.1.0** — all five
  images ship pinned to a version tag and a `sha256` digest.
- ~~Verify the SSO edition on the Keycloak version we actually ship.~~ **Done** — the suite
  now runs against the shipped 26.7.0, 15/15. The browser login round-trip remains open.
- Move to the current upstream mail-server line. The move to 0.13.4 is done and closed a
  High advisory; 0.16 is the open part, and it is a redesign rather than a bump — typed JSON
  config, and the REST management API this project's first-run steps use is gone. See
  `CHANGELOG.md` "Known gaps". Existing v0.11.x installs also still need a verified
  migration path; `docs/RUNBOOK.md` §6 records why the in-place one does not work.
- Measure deliverability against a real domain and publish the score, good or bad.
- Backup/restore rehearsed and documented end to end, not just written down.

## v0.2 — operability

- A browser-driven login test so the OIDC path stops being a documentation claim.
- First-run experience: today you create your first mailbox with `curl`. That should be a
  command, or a screen.
- Metrics and log guidance: what to alert on, and what normal looks like.
- Multi-domain hosting worked through properly, with tests.

## v0.3 — **Agentic Mail**, deliberately in that order

The direction has a name now: **Agentic Mail** — mail infrastructure a software agent can be
given safely, rather than mail infrastructure an agent has to be handed your password to use.

**The first three items below are built and tested; the fourth is not.** Each is marked, and
each "built" carries the test that proves it. [docs/MCP.md](docs/MCP.md) has the threat model.

We think mail is about to be consumed by software agents as much as by people, and this stack
is unusually well placed for it: the mail server is **JMAP-native**, a JSON API rather than a
protocol from 1986 that agents must be taught to speak. That is an accident of what we
assembled, not foresight — but it is the reason this direction is credible here and would not
be on a Postfix/Dovecot stack.

What Agentic Mail means concretely:

- ✅ **An MCP server for the mailbox**, so an assistant can search, read, draft and file mail
  through a typed interface instead of scraping IMAP. *Built* — `mcp/`, seven tools, no
  delete; `tests/test_e2e.sh --mcp`.
- ✅ **Per-agent credentials with real scope**: an agent gets its own token, restricted to the
  folders and actions you grant, sending only to an allow-list, revocable in one edit, and
  fully audited. It never holds the mailbox password. *Built* — `config/mcp/agents.toml`.
  Handing an agent your primary password is the current state of the art and it is
  indefensible.
- ❌ **Sub-addressing and routing rules** designed for agent traffic, so automated mail is
  separable from human mail at the protocol level rather than by filters. *Not started.*
- ✅ **An audit trail** that answers "which agent sent this, on whose authority, when".
  *Built* — one `fsync`'d JSON line per call, refusals included, message bodies hashed.

**Why the project is still not *named* Agentic Mail.** The milestone carries the name; the
product does not. The agent code that exists is a tool an agent is *given*, with limits you
set; it is not an agent. A name that promises autonomous agents while shipping a mail-server
assembly would be a claim we cannot support, and this project's only real asset is that its claims hold up
when you check them. The name will keep describing what the thing *is* — a mail stack you
own outright — and this file will describe where it is going.

## Help wanted

This is where outside help changes the outcome most. Comment on the matching issue before
starting something large, so two people don't build it twice.

**Good first contributions**

- Run `tests/test_e2e.sh` on a distro we haven't tried and report what broke.
- Deliverability report from a real domain: DNS records used, mail-tester score, what you
  had to change.
- Docs for a provider we don't cover (outbound port 25 policy, PTR setup).

**Bigger pieces, in rough priority order**

1. Verify and fix the SSO edition on the current Keycloak, including the browser login flow.
2. A verified migration path for existing v0.11.x installs. The 0.13.4 upgrade is shipped
   and green for fresh installs; upgrading in place corrupts the database, and the
   export/import route upstream documents is untested here. See `docs/RUNBOOK.md` §6.
3. An end-to-end test of the MCP server's OAuth mode against the SSO edition's Keycloak:
   issue a client-credentials token in the realm and call a tool with it.
4. Agent sub-addressing (`you+agent@`) with routing rules, so agent mail is separable at the
   protocol level. Start with the threat model in `docs/MCP.md`, not the code.

**Ground rule, same as `CONTRIBUTING.md`:** a change to runtime behaviour needs a
measurement, not "works on my machine". If you build any of the agent work above, the
acceptance bar is a test in `tests/` that fails without your change.

## What we will not do

- Vendor third-party source into this repo. It stays MIT because it contains none.
- Ship an agent feature that requires sending your mail to a third-party model provider by
  default. Anything agentic must work against a model endpoint you choose, including a local
  one, or it defeats the purpose of self-hosting.
- Claim a capability here before there is a test for it.
