# Changelog

<!-- Last-touched: 2026-08-04 — created during pre-public QA. -->

All notable changes to this repo. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security
- **The pinned webmail carried five High advisories.** `v1.4.8` predates the fixes for
  CVE-2026-34834 (authentication bypass in `verifyIdentity()`, missing cookie validation),
  CVE-2026-34833 (password returned by `/api/auth/session`), and CVE-2026-35389/35390/35391.
  Patch floor is **1.4.11**; this now pins **v1.7.8**. A digest pin is what makes an install
  reproducible, and it is equally what would have frozen every install on the vulnerable
  build — so the pin is only as good as the advisory-watching behind it.
- **`/` on port 80 answered "Welcome to nginx!"** for any unmatched Host, with none of the
  security headers, because the image's stock `default.conf` sorts before `mail.conf` and
  won as the default server. It is now masked with `/dev/null` in both editions; measured:
  unmatched Host `200` + nginx welcome page → `301` to HTTPS.

### Fixed
- **The admin API was unreachable, so nobody could complete the first step.** Every
  document tells the operator to `curl http://127.0.0.1:8080/api/principal` to create their
  domain and first mailbox, but port 8080 was never published and nginx routes only `/jmap`.
  Now published on **`127.0.0.1:8080` only** — never on a public interface, because that API
  returns account passwords in cleartext.
- **Two e2e guards could not fail.** The obsolete-TLS check ended in an `else` that returned
  PASS for any unrecognised probe output, so a dead proxy scored two unearned passes; it now
  fails and prints the output. And `bad "proxy TLS handshake failed"` was unreachable —
  under `set -euo pipefail` a non-matching `grep` killed the script before that line, so a
  broken proxy produced no FAIL and no result line at all.
- **A skipped check exited 0.** Both suites counted and printed skips but still
  `exit $(( FAIL > 0 ))`, so CI on a runner without `yamllint` or `shellcheck` reported a
  green board over checks that never ran. Skips now exit non-zero unless
  `FREEHOLDMAIL_ALLOW_SKIPS=1` says otherwise. Measured: 3 tools hidden → `124 passed,
  0 failed, 3 SKIPPED`, exit **1**.
- **The webmail-reachability check asserted the wrong thing.** Bulwark 1.7 routes `/`
  through a 307 to a locale prefix, so a healthy stack failed a bare `== 200`. It now
  follows the chain and requires the final status to be 200 (measured: first hop 307,
  final 200).

### Changed
- **Stalwart's licence was overstated** as `AGPL-3.0-or-later`. Upstream states AGPL-3.0 as
  published by the FSF, dual-licensed with SELv1, and offers no "or later" — restating it
  more broadly grants a permission the copyright holder did not.
- **PostgreSQL and nginx were missing from the licence documents** although both ship.
- CI no longer claims `-S style` is stricter than the default; it is the default, and the
  comment said otherwise.

## [0.1.0] — 2026-08-05

First public release.

### Fixed
- **The webmail image was the only one not pinned.** `BULWARK_VERSION` shipped as
  `latest` with an empty `BULWARK_DIGEST`, so two installs a week apart could run
  different webmail builds and whoever can push that tag could change every install.
  Now pinned to `v1.4.8` and `@sha256:022b1900…`, verified to resolve anonymously from
  `ghcr.io` (manifest **HTTP 200**). Keycloak is pinned the same way
  (`26.0` / `@sha256:09a381c7…`), so **5/5 images** are now digest-pinned.
- **The supply-chain guard could not see the problem above.** It grepped the raw compose
  files for `image:.*:latest`, but those contain `${BULWARK_VERSION}` — so the check
  inspected a placeholder, matched nothing, and reported green while the image that
  actually ran was mutable. It now asserts against `docker compose config` output,
  requires **all** images pinned rather than at least one, and fails loudly when the
  config cannot be resolved instead of silently passing.

### Added
- `GOVERNANCE.md` and `MAINTAINERS.md` — who decides, how a decision is made, and what
  happens to the project if the maintainer's priorities change.
- `.github/CODEOWNERS` — review routing for the paths where a mistake is expensive.

### Changed
- `SECURITY.md` "Known limitations" item 4 rewritten: digest pinning is no longer partial,
  so the honest residual risk is that a pin does not receive upstream fixes by itself.

### Fixed (earlier, pre-release)
- **The SSO edition could not start at all.** `KC_DB_URL` pointed at a PostgreSQL host
  named `db` that no service defined. Added a `db` service (PostgreSQL, digest-pinned,
  not exposed to the host) with a `pg_isready` healthcheck, and made Keycloak wait for
  `service_healthy`. Verified: Keycloak created **92 tables** and **1 realm row** in that
  database, `/realms/master/.well-known/openid-configuration` returns **200**, and mail
  still flows end to end on the same stack (2/2 send→receive).
- **Keycloak used deprecated bootstrap variables.** `KEYCLOAK_ADMIN` /
  `KEYCLOAK_ADMIN_PASSWORD` replaced with `KC_BOOTSTRAP_ADMIN_USERNAME` /
  `KC_BOOTSTRAP_ADMIN_PASSWORD`, which is the Keycloak 26 form.
- **`KC_HOSTNAME` is version-dependent and was hardcoded.** It now comes from
  `KC_HOSTNAME_VALUE` in `.env`: Keycloak 25+ takes a full URL, Keycloak 24 and earlier
  take a bare hostname. Passing a full URL to Keycloak 24 was measured to produce a
  doubled scheme — `issuer: https://https//id.qa.test/realms/master`.
- **The hardcoded JDBC string is gone.** `KC_DB_URL_HOST` / `KC_DB_URL_PORT` /
  `KC_DB_URL_DATABASE` replace it, so the database name is not written in two places.
- **The default edition could not start at all.** `config/stalwart/config.toml.example`
  had no `[store]`/`[storage]`/`[directory]` blocks, so the mail server exited with
  `Store not configured` and restart-looped (measured: `RestartCount=9` and climbing,
  JMAP port refusing connections). Added a RocksDB store and the storage/directory
  mapping; a real send→receive now completes end to end.
- **Port 587 was published but nothing listened on it** — the config defined listeners
  for 25/465/993/8080 only. Added the `submission` listener.
- **`CHANGEME` image coordinates** replaced with verified ones:
  `stalwartlabs/mail-server:v0.11.8` and `ghcr.io/bulwarkmail/webmail` (the project's
  official GitHub Container Registry publisher).
- **Webmail settings were lost on every container replacement** — no volume was
  mounted. Added `webmail_data` + `SETTINGS_DATA_DIR`.
- **Let's Encrypt `live/` symlinks dangled inside containers.** `install.sh` now
  resolves them with `readlink -f`, and `.env.example` documents why.
- **`.env` existed world-readable between creation and `chmod`.** `install.sh` now
  sets `umask 077` before writing any secret.
- **The mail domain was interpolated into `sed` unvalidated.** Now validated against
  a hostname pattern before use.

### Code quality
- **Senior-standard audit before the first public commit.** Every script now passes
  `shellcheck -S style` (the strictest level) with zero findings, and `install.sh` was
  restructured to the Google Shell Style Guide: a `main` function, `readonly` constants,
  and errors on STDERR via an `err` helper so redirecting stdout can never swallow them.
  Seven `A && B || C` constructs in the E2E script became real `if`/`else` — that idiom is
  not if-then-else and runs `C` when `B` fails.
- **The test suite was reporting a false green.** `shellcheck` was not installed on the
  machine, so two checks printed `SKIP` and were counted as if they had passed. Skips are
  now counted separately and the result line says
  `N passed, M failed, K SKIPPED — install the missing tools before trusting this`.
  Installing shellcheck immediately turned up real findings, including an `SC1087` where
  `"^$k[...]"` parses as an array expansion.
- **The installer had no end-to-end test** — the first thing every user runs was covered
  only by a unit test of `valid_domain`. It is now driven non-interactively in a throwaway
  copy, asserting `.env` mode 600, every expected key present, generated secrets of real
  length, the nginx template materialised with the domain substituted and no placeholder
  left, and that a second run refuses to clobber an existing `.env`.
- `yamllint` added to the suite; two over-length YAML lines wrapped. Markdown link check:
  38 internal links, 0 broken. No `TODO`/`FIXME`/`XXX`/`HACK` anywhere in the tree.

### Security
- **Pre-publication scan before the first public commit.** Clean on: internal
  infrastructure references (host IPs, internal hostnames, the live deployment's project
  and container names, operator credentials), private keys and PEM blocks, provider tokens
  (GitHub/AWS/OpenAI/Slack/Google/JWT), hardcoded secret assignments, world-writable files
  and symlinks. No `.git` existed, so the first commit starts from a clean history with
  nothing to scrub.
- **Fixed: the runbook told operators to write backups inside the repository.**
  `RUNBOOK.md` §4 created `./backup/` holding a mail-store archive, a Keycloak dump and a
  copy of `.env` — one `git add -A` away from publishing an entire mailbox. Backups now
  default to `/var/backups/freeholdmail` (mode 700), `.gitignore` covers
  `backup/`/`backups/`/`*.bak`/`*.tar.gz`/`*.sql*`/`*.dump`/`certs/`/`*.crt`/`.env.*` as a
  safety net, the static suite asserts all 16 patterns, and CI fails if any secret or
  operator-data file is ever tracked.
- **Fixed a live supply-chain hole in CI:** the ShellCheck step used
  `ludeeus/action-shellcheck@master` — a mutable branch of a third-party action, meaning
  whoever controls that repository could change what runs in our pipeline at any time. The
  action was removed entirely (shellcheck is installed from the distro instead) and every
  remaining action is now pinned to a commit SHA, with `.github/dependabot.yml` keeping the
  pins current. The static suite enforces it, verified by unpinning one action and watching
  the check fail.
- Added `.github/workflows/scorecard.yml` (**OpenSSF Scorecard**) and
  `docs/PUBLISHING.md`, a checklist of the GitHub settings and OpenSSF programs that can
  only be enabled after the repo is public — push protection, private vulnerability
  reporting, branch protection, and the difference between Scorecard (automated, external)
  and the Best Practices Badge (self-certified).
- Test recipient for the open-relay assertion changed from a real domain to
  `example.net` (RFC 2606, reserved for documentation).

### Changed
- **Renamed from OwnMail to Freehold Mail.** "OwnMail" failed name clearance: npm `ownmail`
  belongs to Nylas and pitches nearly this product, `ownmail.ai` is a live encrypted-email
  service, PyPI `ownmail` uses the old tagline, the GitHub org has been taken since 2021,
  and every common TLD is registered. `freeholdmail` is clear on npm, PyPI, GitHub org and
  repo search, and `.com`/`.ai`/`.io` are unregistered. *Freehold* is property owned
  outright with no landlord — the opposite of renting a mailbox.
- Copyright holder set to the legal entity **Novaza Solution JSC** in `LICENSE` and
  `NOTICE`; added a maintainer block to `NOTICE` and a "Maintained by" section to the
  README. Freehold Mail is published as a Novaza Solution JSC open-source project.

### Added
- **A test suite in the repo** (`tests/`). `test_config.sh` runs 59 static checks in
  seconds; `test_e2e.sh` stands a throwaway stack up on loopback-only ports, sends a real
  message, reads it back over IMAP and compares the `Message-ID`, asserts the security
  defaults, then tears everything down. `--sso` additionally proves Keycloak owns its
  database. Both run in CI.
- **`TRANSLATIONS.md`** and a first translation, **`README.vi.md`**. English is the source
  of truth; translations follow the de-facto OSS convention (root `README.<tag>.md`) with
  **BCP 47 / RFC 5646** language tags, a language selector on every version, and an explicit
  rule that `LICENSE`, `NOTICE`, `SECURITY.md` and `CHANGELOG.md` are never translated —
  a mistranslated security instruction is a vulnerability and a translated licence has no
  legal standing. The static suite enforces it: canonical files must be English-only
  (verified by deliberately injecting non-English text and watching the check fail), every
  language declared in `TRANSLATIONS.md` must have a file, and each translation must link
  back to the English source and state that English wins.
- **`ROADMAP.md`** — separates what is measured today from what is intended, states the
  agent-ready direction (MCP over JMAP, scoped per-agent credentials) as future work rather
  than as a claim, and lists concrete "help wanted" items for contributors.
- **`docs/RUNBOOK.md`** — day-2 operations: health checks, mailbox management, secret
  rotation, backup/restore, certificate renewal, upgrades with rollback, deliverability
  checks, incident playbooks, decommissioning.
- **`docs/REQUIREMENTS.md`** — host, network, DNS and TLS prerequisites, including the two
  that usually block self-hosted mail (outbound port 25 blocked by cloud providers, and
  the need for a static IP with a matching PTR record).
- Image **digest pinning** (`*_DIGEST`) for supply-chain reproducibility.
- Container hardening: `no-new-privileges` on all services.
- A real **healthcheck** on the mail server; the proxy now waits for `service_healthy`.
- Post-install instructions covering the admin API, including the `"roles":["user"]`
  requirement — without it SMTP AUTH fails with `550 5.7.1`.
- `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`, issue/PR
  templates, and a CI workflow (shellcheck + compose validation + secret scan).
- Secret generation widened from 32 to 40 characters of `openssl rand -base64 32`.

## Known gaps (do not publish without deciding these)

1. **The SSO edition was verified on Keycloak 24, not on the shipped default 26.0.**
   Only Keycloak 24 could be pulled in the environment where this was tested, so what is
   proven is the database wiring, the startup ordering, the health probe and OIDC
   discovery. The Keycloak 26 specifics — `KC_BOOTSTRAP_ADMIN_*`, the full-URL
   `KC_HOSTNAME_VALUE`, and health on management port 9000 instead of 8080 — come from
   the official Keycloak documentation and are **not** measured here. Re-run the SSO
   stack against 26.0 on a host with registry access before relying on it.
   The OIDC login round-trip through the webmail (browser flow) is also untested.
2. **The mail server is pinned to a version line upstream has moved past.** Upstream
   renamed the image to `stalwartlabs/stalwart` and, from v0.16, moved config to
   `/etc/stalwart` and data to `/var/lib/stalwart`. This repo targets the v0.11.x
   layout because that is what was actually tested here. Upgrading requires changing
   the image name **and** both volume paths, then re-running the E2E test.
3. **Pins do not self-update.** Every image ships pinned to a version tag *and* a digest,
   which is what makes an install reproducible — and also what stops it drifting onto an
   upstream security fix. Watch the upstream advisories and re-pin deliberately;
   `docs/RUNBOOK.md` has the upgrade and rollback procedure. (Until 2026-08-05 this entry
   said `BULWARK_DIGEST` was empty; that was left behind by the release that pinned it.)
4. **No SPF/DKIM/DMARC or deliverability score has been measured** against a real
   public domain; `docs/DNS.md` is guidance, not a verified result.
5. **`SEARCH HEADER Message-ID` returns no hits** on the tested mail server version
   (`SEARCH SUBJECT`/`FROM` work). Clients relying on header search will come up empty.
