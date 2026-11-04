<!-- Last-touched: 2026-11-04 — MCP layer: unit tests in mcp/tests and `test_e2e.sh --mcp`. Created 2026-08-04. -->
# Tests

Two layers, both runnable by anyone who clones this repo.

| Script | What it proves | Needs | Time |
|--------|----------------|-------|------|
| `test_config.sh` | Everything provable without starting anything: both editions validate, required services exist, the mail server's storage mapping is complete, a listener exists for every published port, no secrets or placeholders, images are digest-pinned, hardening flags set, `valid_domain()` accepts and rejects the right inputs, docs present | `docker compose`, `python3` | seconds |
| `test_e2e.sh` | The stack actually works: it starts, becomes healthy without restart-looping, provisions a domain and mailboxes, **a real message travels SMTP → mailbox → IMAP and comes back with the same `Message-ID`**, relaying is refused, unauthenticated submission is refused, TLS negotiates, and the webmail is served | Docker, ability to pull the images | ~2 min |
| `test_e2e.sh --mcp` + `e2e_mcp.py` | The MCP overlay: the image builds and becomes healthy; a real MCP client gets `401` without a valid token, sees only permitted folders, cannot tell an out-of-scope message from a missing one, is refused every scope it lacks, drafts and organises, **sends to an allow-listed address and the message is read back from the recipient's mailbox**, is refused off-list recipients and a second send in the hour, loses access on revocation with no restart, and leaves exactly one audit line per call with no message body in it | the above, plus `mcp/requirements-dev.txt` | ~3 min |
| `mcp/tests/` (pytest) | Policy validation, auth modes (static, stdio, OAuth JWT with real signatures), rate limit and its refund, folder scoping, address validation, JMAP client host pinning | `mcp/requirements-dev.txt` | seconds |

```bash
tests/test_config.sh          # run before every commit
tests/test_e2e.sh             # base edition (Full Mail)
tests/test_e2e.sh --sso       # base + Keycloak + PostgreSQL
tests/test_e2e.sh --mcp       # base + MCP server, driven by a real MCP client
```

## Safety

`test_e2e.sh` never touches an existing deployment. It builds a throwaway compose project
(`freeholdmail-e2e-$$`) in a temporary directory, with its own volumes, its own self-signed
certificate, and **loopback-only** ports well away from 25/465/587/993/80/443. It tears
everything down on exit, including on failure.

If the default port range collides with something on your host:

```bash
FREEHOLDMAIL_TEST_PORT_BASE=13000 tests/test_e2e.sh
```

## Testing against different images

Any image coordinate can be overridden, which is how you test a locally built image or work
on a host that cannot reach a registry:

```bash
FREEHOLDMAIL_TEST_BULWARK_IMAGE=my-bulwark \
FREEHOLDMAIL_TEST_BULWARK_VERSION=dev \
FREEHOLDMAIL_TEST_KEYCLOAK_VERSION=24.0 \
FREEHOLDMAIL_TEST_KC_HOSTNAME_VALUE=id.qa.test \
tests/test_e2e.sh --sso
```

`FREEHOLDMAIL_TEST_KC_HOSTNAME_VALUE` matters because `KC_HOSTNAME` is version-dependent:
Keycloak 25+ wants a full URL, 24 and earlier want a bare hostname and will otherwise
produce a doubled scheme in the issuer.

## What these tests deliberately do not cover

- **The webmail UI.** Freehold Mail contains no application source; every button, screen, and
  client-side behaviour belongs to [Bulwark](https://github.com/bulwarkmail/webmail) and is
  tested there. Adding fake UI tests here would create the impression of coverage this repo
  cannot honestly provide. What is tested is that the webmail is reachable and correctly
  wired to the mail server.
- **The browser OIDC login round-trip.** Driving a real login needs a browser automation
  stack; it is not yet wired up. `--sso` proves the identity server starts, owns its
  database, and serves OIDC discovery — not that a human can complete a login.
- **Deliverability.** SPF/DKIM/DMARC alignment and inbox placement need a real public
  domain and a third-party scoring service. See `docs/RUNBOOK.md` for how to check it on a
  live deployment.

## Why the E2E test looks the way it does

An earlier version polled for "any message in the inbox" and passed while measuring a
message from a previous run. It now records the IMAP UID set *before* sending and waits for
a UID that is genuinely new, then compares the `Message-ID` exactly. A test that can pass
without the thing under test happening is worse than no test.
