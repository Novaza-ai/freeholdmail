<!-- Last-touched: 2026-08-07 — 0.13.4 landed; the mail-server item now points at 0.16 only. -->
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
| SSO edition starts | ⚠️ partial | `tests/test_e2e.sh --sso` — **15/15** on the shipped **Keycloak 26.7.0**; the browser login round-trip is still unmeasured |
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

**This section describes where the project is going, not what it does today.** Nothing in it exists in
the repository today; `grep -ri "mcp\|agent" --include='*.py' --include='*.sh' .` finds no
implementation, and the version that ships it is the version that may claim it.

We think mail is about to be consumed by software agents as much as by people, and this stack
is unusually well placed for it: the mail server is **JMAP-native**, a JSON API rather than a
protocol from 1986 that agents must be taught to speak. That is an accident of what we
assembled, not foresight — but it is the reason this direction is credible here and would not
be on a Postfix/Dovecot stack.

What Agentic Mail means concretely — **none of this is built yet**:

- **An MCP server for the mailbox**, so an assistant can search, read, draft and file mail
  through a typed interface instead of scraping IMAP.
- **Per-agent credentials with real scope**: an agent gets its own address and its own
  token, restricted to one folder, revocable in one action, and fully audited. Handing an
  agent your primary password is the current state of the art and it is indefensible.
- **Sub-addressing and routing rules** designed for agent traffic, so automated mail is
  separable from human mail at the protocol level rather than by filters.
- **An audit trail** that answers "which agent sent this, on whose authority, when".

**Why the project is still not *named* Agentic Mail.** The milestone carries the name; the
product does not, and will not until the code exists. There is no agent code in this repo
today. A name that promises autonomous agents while shipping a mail-server assembly would
be a claim we cannot support, and this project's only real asset is that its claims hold up
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
3. A prototype MCP server over JMAP — even a read-only one that lists and searches mail
   would settle the design questions.
4. Scoped, revocable per-agent credentials. Start with the threat model, not the code.

**Ground rule, same as `CONTRIBUTING.md`:** a change to runtime behaviour needs a
measurement, not "works on my machine". If you build any of the agent work above, the
acceptance bar is a test in `tests/` that fails without your change.

## What we will not do

- Vendor third-party source into this repo. It stays MIT because it contains none.
- Ship an agent feature that requires sending your mail to a third-party model provider by
  default. Anything agentic must work against a model endpoint you choose, including a local
  one, or it defeats the purpose of self-hosting.
- Claim a capability here before there is a test for it.
