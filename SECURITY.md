# Security Policy

<!-- Last-touched: 2026-08-05 — reporting channels made explicit and machine-readable
     (a policy an automated checker cannot find is one a reporter cannot find either),
     with a coordinated-disclosure timeline stated in days rather than implied. -->

## Reporting a vulnerability

Report privately. **Do not open a public issue, pull request or discussion** for a security
problem — a public report is a public exploit for everyone running this stack.

**Two channels, either is fine:**

1. **GitHub private advisory — preferred.** Open a report at
   https://github.com/Novaza-ai/freeholdmail/security/advisories/new
   It is private between you and the maintainers, it lets us work with you on a fix in a
   private fork, and it produces a CVE when the issue warrants one.
2. **Email: admin@novaza.ai** — put `[SECURITY]` at the front of the subject.
   Use this if you cannot or prefer not to use GitHub. If you want the report encrypted,
   say so in a first message with no details and we will exchange a key.

Please include: what you found, the version or commit, how to reproduce it, and what an
attacker gains. A proof of concept helps enormously. Reports in any language are welcome —
we will translate rather than ask you to.

### What happens next, and when

These are the targets we work to. Be aware of what is behind them: **one person can merge**
(see [`MAINTAINERS.md`](MAINTAINERS.md)), so these are honest intentions, not a contractual
SLA — a single-maintainer project that promises an SLA is lying. If we miss one, you are
entitled to say so publicly, and that is the accountability we offer instead.

| Stage | Target |
|-------|--------|
| We acknowledge your report | within **72 hours** |
| We confirm or dispute it, with reasoning | within **10 days** |
| Fix or documented mitigation shipped, for issues we can reproduce | within **30 days** |
| Public disclosure and advisory published | within **90 days** of your report, or as soon as a fix is released — whichever comes first |

We follow **coordinated disclosure**. We will agree an embargo with you and hold it. If we
cannot fix an issue within 90 days we will say so publicly anyway, describing the risk and
the workaround, because silence is worse for the people running this than an unfixed
disclosed bug. If you disagree with our assessment, tell us — we would rather argue than be
wrong quietly.

**Credit.** We will name you in the advisory and in `CHANGELOG.md` unless you ask us not to.
We do not run a paid bug-bounty programme and will not pretend otherwise.

**Safe harbour.** Test against your own installation. We will not pursue or support legal
action against anyone who reports in good faith, stays within their own systems, avoids
privacy violations and service degradation, and gives us reasonable time before disclosure.

### Scope

This repository is **orchestration**: compose files, nginx configuration, the installer, the
test suites, and documentation. It contains no third-party source code.

**In scope:** anything in this repository, and — importantly — any way our *defaults* make an
upstream weakness worse. An insecure default here is our bug even when the code is theirs.

**Out of scope, report upstream:** vulnerabilities inside the programs this project runs.
Their advisory channels are the correct place, and reporting there protects far more people
than reporting here:

- Stalwart Mail Server — https://github.com/stalwartlabs/stalwart/security
- Bulwark Webmail — https://github.com/bulwarkmail/webmail/security
- Keycloak — https://github.com/keycloak/keycloak/security
- nginx — https://nginx.org/en/security_advisories.html

If you are unsure which side of that line something falls on, report it here and we will
route it.

## Known security properties (measured, not assumed)

Verified on a throwaway stack built from this repo. **First measured 2026-08-04,
independently re-measured 2026-08-05** — every response string below was reproduced
character for character on the second run. What the test suite guards, precisely: rows 1 and 2 are asserted only as **refused with some
5xx** (`tests/test_e2e.sh`), and row 3 is genuinely guarded — `tests/e2e_mail.py` fails the
run if `PLAIN` or `LOGIN` is advertised before STARTTLS. So those three *behaviours* cannot
rot silently. The **exact strings quoted below can**, because nothing asserts them, and row 4
is not exercised at all (the suite never maps port 465). Treat every string here as dated.

| Property | Result | How it was checked |
|----------|--------|--------------------|
| Open relay | **Denied** — `550 5.1.2 Relay not allowed.` | `MAIL FROM` external, `RCPT TO` external on port 25 |
| Unauthenticated submission | **Denied** — `503 5.5.1 You must authenticate first` | `MAIL FROM` without AUTH on port 587 |
| Password auth over cleartext | **Not offered** — EHLO advertises `AUTH OAUTHBEARER` only; `PLAIN`/`LOGIN` appear only after `STARTTLS`, and a cleartext password login is refused | EHLO + `login()` before/after `STARTTLS` on 587 |
| Implicit TLS on 465 | **TLS 1.3**, `TLS_AES_256_GCM_SHA384` | `openssl s_client -connect :465` |
| Secrets in the repo | **None** | `grep -rnE '(SECRET\|PASSWORD\|TOKEN\|API_KEY)=[A-Za-z0-9+/=_-]{8,}'` |
| `.env` permissions | **0600**, created under `umask 077` | `install.sh` |

## Known weaknesses you must plan around

1. **The mail server's admin API returns account passwords in cleartext.**
   `GET /api/principal/<user>` includes the `secrets` value as plaintext. This is
   upstream behaviour, reproduced here on a clean install — it is not caused by
   this repo, and this repo cannot fix it. Consequences: anyone with the admin
   credential, and anything that logs admin API responses, sees user passwords.
   Treat the bootstrap admin secret as a crown jewel, never proxy the admin API
   to the public internet, and rotate it after initial setup.
2. **Bootstrap admin.** `STALWART_FALLBACK_ADMIN_SECRET` is a full-power credential
   in `.env`. Rotate it once your real accounts exist.
3. **No fail2ban / rate limiting is shipped.** Exposing 25/465/587/993 to the
   internet without brute-force protection is not advisable. See `docs/DNS.md`
   for deliverability and add host-level protection yourself.
4. **Digest pins go stale.** Every image ships pinned to a version tag *and* a
   `sha256` digest, so an install is reproducible and a moved tag cannot change
   what runs. The trade-off is that a pin does not receive upstream security
   fixes on its own: watch the upstream releases and re-pin deliberately —
   `docs/RUNBOOK.md` has the upgrade and rollback procedure.
5. **TLS material is bind-mounted from the host.** Anyone who can write those
   files can impersonate your mail server.
6. **Containers still run as root inside, and their filesystems are writable.**
   Every service drops **all** Linux capabilities and adds back only what it
   provably needs (`NET_BIND_SERVICE` for the mail server; that plus
   `SETUID`/`SETGID`/`CHOWN`/`DAC_OVERRIDE` for nginx, which starts as root to
   bind 80/443 and then drops its workers), and every service is bounded by
   `mem_limit`, `pids_limit` and log rotation. What is **not** done: a `user:`
   override or `read_only: true`. Both interact with how each upstream image
   initialises its own data directory, and shipping them untested would be worse
   than saying so here.
7. **A digest pin does not receive upstream fixes.** That is the trade-off for a
   reproducible install, and it is not theoretical: this project shipped a webmail
   pinned below the patch floor for five High advisories until 2026-08-05 —
   CVE-2026-34834 (authentication bypass), CVE-2026-34833 (password disclosure)
   and CVE-2026-35389/35390/35391. Watch the upstream
   advisories for every component you pin, and re-pin deliberately.

## Supported versions

Pre-1.0. Only the latest tag receives fixes.
