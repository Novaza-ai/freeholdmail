# Security Policy

<!-- Last-touched: 2026-08-13 — pin currency is no longer a manual duty: records
     scripts/check_pins.py and the three things it refuses to do (fail-open, range-matching,
     non-expiring acknowledgements). Same-day earlier edit added the controls-not-claimed
     section (release signing, fuzzing, two plan-gated secret-scanning features). -->

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
We do not run a paid bug-bounty programme.

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

## Known security properties, and how each was measured

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

## What static analysis actually covers

CodeQL runs on every push and pull request via GitHub's default setup. **It does not cover
most of this repository**, and the difference matters more than the badge does:

| Language | Bytes | Analysed by |
|----------|-------|-------------|
| **Shell** — `install.sh`, `tests/test_config.sh`, `tests/test_e2e.sh`, `scripts/make_gif.sh` | **53,536** | **`shellcheck` only. CodeQL has no Shell support.** |
| Python — `tests/e2e_mail.py`, `scripts/seed_demo.py` | 10,725 | CodeQL + `pycodestyle` |
| JavaScript — `scripts/capture_tour.mjs` | 4,157 | CodeQL |
| GitHub Actions workflows | — | CodeQL (`actions` pack) |

So the largest single file in this project, and the one that generates your secrets and
writes your `.env` — `install.sh` — is **not** reachable by CodeQL. `shellcheck` runs on it in
CI and is enforced there, but shellcheck is a linter, not a taint-tracking analyser. If you
are relying on "this repo runs CodeQL" as assurance about the installer, do not.

**One consequence worth stating, because it makes a clean CodeQL result misleading.**
`scripts/seed_demo.py` writes its generated demo password to `.demo-password` at mode 600,
and CodeQL flags that as `py/clear-text-storage-sensitive-data`. It is right: the password is
stored in the clear. But `install.sh` does **exactly the same thing** — it writes
`STALWART_FALLBACK_ADMIN_SECRET` and `WEBMAIL_SESSION_SECRET` into `.env` in the clear, at
mode 600 — and is never flagged, because CodeQL cannot read Shell. The difference between the
two files is not the risk; it is which language the analyser supports.

The alert on `seed_demo.py` is dismissed as *won't fix*, for a reason that applies to both
files: a credential an operator has to be able to use has to be retrievable, and every
mechanism that makes it retrievable is clear-text storage by this rule's definition. What can
be done — a file at mode 600 rather than a terminal, gitignored, easy to delete — is done.
Do not read the dismissal as "this is fine"; read it as "this is the same trade-off `.env`
already makes, now visible because the language happens to be analysable."

Verify the split yourself:

```bash
gh api repos/Novaza-ai/freeholdmail/code-scanning/analyses \
  --jq '[.[] | select(.tool.name=="CodeQL") | .category] | unique'
gh api repos/Novaza-ai/freeholdmail/languages
```

## Controls this project does not claim, and why

A policy that lists only what is done is half a policy. Each item below is a control a reader
might reasonably expect, each is visible as a gap in an automated audit, and none of them is
done. The reason is stated so you can judge it instead of taking it on trust. Measured
2026-08-13.

### Release artefacts are not signed, because there are none

OpenSSF Scorecard reports `Signed-Releases` as inconclusive (`-1`) for this repository, and it
will stay that way. The latest tag ships zero assets:

```bash
gh api repos/Novaza-ai/freeholdmail/releases --jq '.[] | "\(.tag_name) assets=\(.assets|length)"'
```

The documented install path is a clone, not a download — `git clone … && ./install.sh`. This
repository builds no binary; it is compose files, configuration templates and a shell installer.
Attaching a tarball so that something could be signed would create an artefact nobody installs
from, which can then drift from the commit it claims to represent. A signature over the wrong
thing is worse than no signature. If you want to verify what you cloned, verify the commit.

### There is no fuzzing harness, and adding one would be theatre

`Fuzzing` scores 0/10. We are declining it on the record rather than leaving it to read as an
oversight. Fuzzing finds memory-safety and parser bugs in code that consumes untrusted input.
The code here is shell that runs once, at install time, on the operator's own input, plus two
test helpers. Every process that actually parses untrusted network traffic — SMTP, IMAP, JMAP,
HTTP — lives in an upstream image this project pins and does not build. Fuzzing the installer
would score a point and reduce no real risk. The parsers worth fuzzing are upstream.

### Two secret-scanning features cannot be enabled on this plan

Secret scanning and push protection are on. Two adjacent features are off and **cannot be turned
on here** — worth knowing, because the API accepts the request and then ignores it:

| Feature | State | Why |
|---|---|---|
| `secret_scanning_validity_checks` | off | Needs GitHub Team or Enterprise with Secret Protection; this org is on the **free** plan |
| `secret_scanning_non_provider_patterns` | off | Same gate — and validity checks never apply to non-provider patterns even when both are available |

`PATCH /repos/{owner}/{repo}` with either field returns **200 with the value still `disabled`**,
no error and no warning. Verify the state and the reason for yourself:

```bash
gh api repos/Novaza-ai/freeholdmail --jq .security_and_analysis
gh api orgs/Novaza-ai --jq '{plan: .plan.name, advanced_security: .advanced_security_enabled_for_new_repositories}'
```

The consequence to plan around: a credential leaked into this repository would be caught only if
it matches a **known provider format**, and nothing will tell you whether it is still live.
Rotate on suspicion; do not wait for a validity verdict. If you fork this into a paid org, enable
both — the reason they are absent here is the plan, not a judgement.

### Dependabot cannot see the image pins, because the pins are variables

`.github/dependabot.yml` watches `github-actions` only. Adding `package-ecosystem: docker` would
look like it closed weakness 6 below and would update nothing, because no compose file contains
a literal image reference:

```bash
grep -nE 'image:' docker-compose.yml docker-compose.sso.yml
# stalwartlabs/stalwart:${STALWART_VERSION}${STALWART_DIGEST}   ← no tag for Dependabot to parse
```

Versions and digests live in `.env.example` so an operator can override any of them without
editing compose. That is the right trade for an installable stack, and it costs automated pin
updates: Dependabot parses image tags for SemVer, and there is no literal tag here to parse.
GitHub's dependency graph reports nothing for this repository either — `GET /dependency-graph/sbom`
returns `404`. So we do not ship that config, because a config that produces no pull requests
while appearing to watch your images is the same failure as a workflow that looks like a scanner
and only uploads a file.

**Pin currency was therefore a manual duty on this project**, and weakness 6 records that the duty
was missed twice. Since 2026-08-13 it is automated by `scripts/check_pins.py`, run weekly by
`.github/workflows/pin-currency.yml` — see below. Dependabot still cannot do it; this check reads
the pins out of `.env.example` itself.

### The pin-currency check, and what it refuses to do

```bash
scripts/check_pins.py        # 0 = current, 1 = a pin is behind, 2 = a pin could not be checked
```

`scripts/pin_sources.json` declares, per image, where upstream lives and which version line this
project follows. No component name, URL or policy sits in the script, so changing what is
followed is a change to data. Three design choices are worth stating because each one is a
failure mode this project has already met:

- **An unreachable upstream exits `2`, which fails.** A currency check that goes green when it
  could not reach the registry teaches you to trust a board that measured nothing.
- **Advisories are printed as context and never decide the exit code.** GitHub's
  `vulnerable_version_range` carries no lower bound (weakness 6), so range-matching alone would
  report advisories against releases they never applied to. A human reads the list.
- **A deliberate lag must be declared and must expire.** `acknowledged_lag` carries a reason and
  a `review_by` date; before that date the lag reports and passes, on it the check **fails** so
  the decision is re-argued. An acknowledgement that never expires is a muted alarm. Narrowing a
  component's `line` to the version already pinned would also silence the check — do not.

The suite asserts the check's own coverage: every `*_DIGEST` in `.env.example` must appear in
`pin_sources.json`, so adding an image without declaring it fails CI rather than quietly
shrinking what is watched.

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
4. **TLS material is bind-mounted from the host.** Anyone who can write those
   files can impersonate your mail server.
5. **Containers still run as root inside, and their filesystems are writable.**
   Every service drops **all** Linux capabilities and adds back only what it
   provably needs (`NET_BIND_SERVICE` for the mail server; that plus
   `SETUID`/`SETGID`/`CHOWN`/`DAC_OVERRIDE` for nginx, which starts as root to
   bind 80/443 and then drops its workers), and every service is bounded by
   `mem_limit`, `pids_limit` and log rotation. What is **not** done: a `user:`
   override or `read_only: true`. Both interact with how each upstream image
   initialises its own data directory, and shipping them untested would be worse
   than saying so here.
6. **A digest pin does not receive upstream fixes.** That is the trade-off for a
   reproducible install, and it has now caught this project twice. The webmail shipped
   below the patch floor for five High advisories until 2026-08-05 — CVE-2026-34834
   (authentication bypass), CVE-2026-34833 (password disclosure) and
   CVE-2026-35389/35390/35391. The mail server shipped below the floor for
   GHSA-8jqj-qj5p-v5rr (High, unbounded memory allocation in the IMAP server, exploitable
   without authentication) until 2026-08-07. Both were found by auditing rather than by
   being told. Watch the upstream advisories for every component you pin, and re-pin
   deliberately.

   Two things that made the second one harder to see, worth knowing if you audit your own
   pins. **`vulnerable_version_range` has no lower bound**: `GHSA-xv4r-q6gr-6pfg` publishes
   `< 0.13.3`, which matches every older release, while its text says *"Affected: 0.12.0 to
   0.13.2. CalDAV support was introduced in version 0.12.0"* — it never applied to the pin
   we shipped. Read the advisory body, not just the range. And **advisories are not the
   whole picture**: upstream also fixes security bugs without filing one — loopback SMTP
   delivery has been refused since 0.12.0, for instance — and those fixes are not
   backported to older lines.

## Supported versions

Pre-1.0. Only the latest tag receives fixes.
