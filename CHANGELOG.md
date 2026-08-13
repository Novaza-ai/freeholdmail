# Changelog

<!-- Last-touched: 2026-08-13 — record the pin-currency check and the three behind-pins its first
     run found. Same-day earlier edit cut 0.3.0 (advisory fix, CodeQL, governance split,
     controls this project declines to claim). -->

All notable changes to this repo. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **The pin-currency gap is now automated.** `scripts/check_pins.py`, run weekly by
  `.github/workflows/pin-currency.yml`, reads every image pin out of `.env.example` and compares
  it against the upstream line declared in `scripts/pin_sources.json`. It closes the gap
  documented one release earlier: Dependabot cannot watch these images, because compose reaches
  them through `.env` variables and there is no literal tag to parse.
  It is **scheduled, not a required check** — it fails when *upstream* moves, which has nothing
  to do with the change under review, and blocking a PR on that trains people to merge past a red
  board. Three refusals are deliberate, each one a failure mode this project has already met: an
  unreachable upstream **fails** (exit 2) instead of reporting green; advisories are printed as
  context and never decide the exit code, because `vulnerable_version_range` has no lower bound
  (`SECURITY.md` weakness 6); and a deliberate lag must be declared with a `review_by` date, after
  which the check fails so the decision is re-argued rather than muted forever.
  The suite gained a guard asserting the check's own coverage — every `*_DIGEST` in `.env.example`
  must be declared in `pin_sources.json` — so adding an image without declaring it fails CI
  instead of quietly shrinking what is watched. Static suite **191 → 194**.
- **Its first run found three pins behind, one of them a security gap.** `KEYCLOAK_VERSION=26.7.0`
  is below the **26.7.1** patch floor for six advisories published 2026-08-06, four of them High
  (`GHSA-95cx-vmr5-3cmr` DCR role forgery, `GHSA-95rm-h7g9-rhcf` DCR mapper type-swap privilege
  escalation, `GHSA-fgq2-hxm5-8xg2` SAML link-only bypass, `GHSA-f8m4-v488-rmrm` SAML signature
  validation disabled). Also behind: the webmail (`v1.7.8`, upstream `1.8.1` — no advisory affects
  the pinned build; every published one has a patch floor of 1.4.11 or lower) and the
  `postgres:17-alpine` digest, whose floating tag has been re-pointed upstream since it was
  pinned. **This is weakness 6 recurring for the third time**, and the first time a check rather
  than a manual audit caught it.

## [0.3.0] — 2026-08-13

Security-maintenance release, and the first one developed the way this project's own
`GOVERNANCE.md` always said it would be. It closes a High, pre-authentication advisory in the
mail server, puts static analysis and a governed branch behind every change, and writes down the
four controls we are **not** claiming so that no reader has to infer them from a score.

**Existing 0.11.x installs must not upgrade in place** — see the mail server entry below and
`docs/RUNBOOK.md` §6. Fresh installs are unaffected.

### Security
- **The mail server moves to `stalwartlabs/stalwart:v0.13.4`, closing a High,
  pre-authentication advisory.** `v0.11.8` was below the patch floor for
  [GHSA-8jqj-qj5p-v5rr](https://github.com/stalwartlabs/stalwart/security/advisories/GHSA-8jqj-qj5p-v5rr)
  — unbounded memory allocation in the IMAP server, `CVSS AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:H`,
  exploitable by anyone who can open a connection to port 993. Fixed upstream in 0.13.4.
  Measured after the upgrade: static **189/0**, e2e **14/0**, e2e `--sso` **15/0** — a real
  message still travels SMTP → mailbox → IMAP, relay is still refused `550`, unauthenticated
  submission still `503`.
  The upstream image was renamed from `stalwartlabs/mail-server` at the same time and its
  volume moved from `/opt/stalwart-mail` to `/opt/stalwart`, so this is a compose change, not
  a tag bump; `config/stalwart/config.toml.example` had a hardcoded `/opt/stalwart-mail/data`
  store path that moves with it.
  **⚠️ Existing installs must not upgrade in place.** We tested it: starting 0.13.4 against a
  0.11.x database reports `Archive integrity compromised`, serves **zero accounts**, and
  writes a schema marker that then makes the data unreadable by 0.12.5 as well
  (`Unknown database schema version, expected 2 or below, found 3`). Stepping through 0.12.5
  first fails identically. Upstream documents the migration as automatic; in this deployment
  it is not. `docs/RUNBOOK.md` §6 records the measurements and the safe order — back up,
  migrate to a separate volume with upstream's export/import utility, verify, then cut over.
  **Fresh installs are unaffected**, which is what the e2e figures above cover.
- **Two lessons from finding it, recorded in `SECURITY.md` weakness 6 for anyone auditing
  their own pins.** `vulnerable_version_range` carries no lower bound, so
  `GHSA-xv4r-q6gr-6pfg` (`< 0.13.3`) matches a pin it never applied to — its text limits it
  to 0.12.0–0.13.2 because CalDAV did not exist earlier. Read the advisory body. And
  advisories are not the whole picture: upstream also fixes security bugs without filing one,
  and does not backport them.
- **CodeQL now runs on every push and pull request**, via GitHub's default setup, across
  `actions`, `python`, `javascript`, `typescript` and `javascript-typescript`. It found a real
  High finding on its first run, fixed below. **It does not cover most of this repository** —
  Shell, including the installer, has no CodeQL support and is reachable only by `shellcheck`.
  `SECURITY.md` states that split as a table rather than letting the badge imply coverage, and
  `.github/workflows/scorecard.yml` now carries a comment above its `upload-sarif` step so that
  nobody reads an upload as a scan.
- **Dependabot security updates are enabled**, so an advisory against a watched dependency now
  opens a pull request instead of only raising an alert. Two adjacent secret-scanning features —
  validity checks and non-provider patterns — **cannot** be enabled on this account's plan; the
  API accepts the request and silently leaves them off. `SECURITY.md` records which, why, and
  what to rotate on suspicion as a result.

### Fixed
- **The JMAP discovery check asserted one release's status code.** `tests/test_e2e.sh`
  required exactly `401` from `/.well-known/jmap`, which was 0.11's answer to an
  unauthenticated probe. 0.13 answers `307` to `/jmap/session`, which is what RFC 8620
  describes. The check now accepts either and verifies the redirect target, so it tests that
  the route reaches the mail server rather than which version is running.
- **The demo seeder printed a generated password to stdout**, where it landed in terminal
  scrollback and any CI log that captured it — CodeQL's first High finding
  (`py/clear-text-logging-sensitive-data`, `scripts/seed_demo.py`). It now writes
  `.demo-password` at mode 600, gitignored, following the pattern `install.sh` already used for
  every other secret, with a suite guard so the file cannot start being tracked. CodeQL then
  flagged the *storage*; that second alert is dismissed as won't-fix with its reason attached,
  and `SECURITY.md` records the asymmetry that makes the dismissal honest — `install.sh` stores
  secrets identically and escapes the alert only because CodeQL cannot read Shell.

### Added
- **`SECURITY.md` now says what this project does not do.** Four controls a reader could
  reasonably expect are absent, and each now carries its reason: release artefacts are unsigned
  because there are none to sign and the install path is a clone; there is no fuzzing harness
  because every parser that touches untrusted traffic is in an upstream image this repo pins and
  does not build; two secret-scanning features are unavailable on this plan; and Dependabot
  cannot watch the image pins because compose refers to them through `.env` variables, so
  shipping that config would produce no pull requests while appearing to. Pin currency is a
  manual duty here, and the policy now says so instead of implying otherwise.

### Changed
- **`GOVERNANCE.md` no longer describes a process the history contradicts.** It required
  reviewed pull requests while every commit had gone straight to `main`. The rule is now split
  along what a single-maintainer project can actually enforce: pull requests, green CI and no
  direct pushes apply now — `enforce_admins` is on, so a direct push to `main` is refused — while
  required approval waits for a second maintainer, because one person cannot approve their own
  work. The interim paragraph is written to be deleted when `MAINTAINERS.md` gains that person.
- **The first pull requests in this repository's history landed in this release** — #4 and #5.
  To be exact rather than flattering: two of the five commits in 0.3.0 came through a pull
  request, and the three earlier ones were pushed straight to `main` before `enforce_admins` was
  turned on. From this release forward the branch refuses that route, so the ratio is a
  transitional artefact and not a standard being set.
- The Contributors explanation in `MAINTAINERS.md` and `README.md` was updated: the older commits
  are now correctly credited.

## [0.2.0] — 2026-08-06

Trustworthiness release. Everything below was found by auditing the 0.1.0 release rather
than by adding features: a webmail pinned below a security patch floor, a first run that
could not complete, container hardening, and several guards in the test suite that could
not fail. The component licence lists were also wrong in eleven languages.

### Added
- **A hosting playbook** — `docs/HOSTING.md`. From a freshly rented VPS to a working mailbox,
  with a verification command at every step, and the one thing that cannot be fixed later
  stated first: **most cheap providers block outbound port 25**. Server sizing comes from
  `docker stats` against this stack running, not from a vendor's guess — measured idle,
  **218 MiB** for the base edition and **802 MiB** for SSO, of which Keycloak alone is
  **537 MiB**. Image download is **478 MB** / **1197 MB**.
- **Ten more translations**, and the structure to survive them. `README.<tag>.md` at the root
  does not scale past a handful of languages, exactly as `TRANSLATIONS.md` predicted, so
  translations moved to `docs/i18n/<BCP 47 tag>/README.md`: Japanese, Simplified and
  Traditional Chinese, Thai, Indonesian, Hindi, French, Spanish, Portuguese and Russian join
  Vietnamese. English remains the only authority and every translation says so in its own
  language. **They have not been reviewed by native speakers** — that is stated in
  `TRANSLATIONS.md` rather than left for a reader to discover.
- **Four guards for the translations**, because twelve hand-maintained files drift: the
  selector and the table must list the same languages, no file may be an orphan on disk, each
  translation must keep the English section count, and **code blocks must be byte-identical
  to the English**. That last one caught the Vietnamese file translating shell comments —
  a small thing that is how "never translate commands" erodes.
- **The team is named.** `MAINTAINERS.md` and the README now credit the people behind this,
  not only the legal entity, and explain how GitHub attributes a commit — see the authorship
  change below for what that explanation now says.

### Security
- **Every container now drops all Linux capabilities** and adds back only what it provably
  needs: `NET_BIND_SERVICE` for the mail server, and that plus `SETUID`/`SETGID`/`CHOWN`/
  `DAC_OVERRIDE` for nginx, which starts as root to bind 80/443 and then drops its workers.
  The webmail and Keycloak keep nothing. Verified at the kernel, not just in the config:
  `CapEff` drops from `a80425fb` to `0000000000000400`, and a `chown` that succeeds with the
  default set is refused under `cap_drop: ALL`.
- **Every container is bounded** by `mem_limit`, `pids_limit` and rotated JSON logs
  (`10m` x 5). An unbounded container log fills the host disk and takes the mail server with
  it; a runaway process should be stopped by the kernel rather than by the operator.
- **Off two end-of-life branches.** nginx moves from `1.27` — a *mainline* branch, retired;
  nginx numbers stable branches with an even minor — to the current stable **`1.30.4`**.
  Keycloak moves from the retired `26.0` to **`26.7.0`**. Both re-pinned by digest and
  re-tested: the SSO suite now reports Keycloak creating **100** tables where 26.0 created
  87, which is how you can tell the new image actually ran.
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
- **GitHub did not recognise this project as MIT-licensed.** A "SCOPE OF THIS LICENSE" note
  appended to `LICENSE` meant the file no longer matched the MIT text, so GitHub's licence
  detection returned `NOASSERTION` / "Other": the sidebar showed no licence, and the
  repository was excluded from `license:mit` searches. `LICENSE` is now the MIT text and
  nothing else. The scope of that licence — that it covers the orchestration in this
  repository and not the programs it deploys — is unchanged and is stated in `NOTICE`,
  `THIRD_PARTY_LICENSES.md` and the README, which is where it belongs.
- **Eleven translations understated the component licences.** Each listed three of the five
  programs the stack deploys: **nginx** (BSD-2-Clause) and **PostgreSQL** were absent, and
  Stalwart was flattened to a bare `AGPL-3.0` where it is dual `AGPL-3.0-only OR SELv1` —
  the "or later" ambiguity the English text explicitly warns against. All eleven now carry
  the full list. Licence identifiers are left in English because they are legal
  identifiers.
- **The staleness guard excused an undeclared file using other files' declarations.** Its
  regex only matched a SHA cell ending immediately in `|`, so the ten rows reading
  `` `sha` — **STALE** `` were invisible to it and the single undeclared row was the only
  thing it read. It correctly found that row stale, then `grep -q STALE` matched the ten
  other rows and it exited 0. The Vietnamese translation sat undeclared-stale through a green
  suite while shipping the incomplete licence list above. Each row is now judged on its own.
- **The suite failed on every correctly installed system.** `no committed secrets` scanned
  the whole working tree, so the `.env` that `install.sh` writes at mode 600 — gitignored,
  untracked, never committed — was reported as a leaked secret: `189 passed` became
  `188 passed, 1 failed` for anyone who followed the hosting playbook and then ran the tests
  the README invites them to run. It now searches tracked content only — a secret pasted into
  a tracked file is still caught, staged or not. The tradeoff is stated rather than buried:
  an untracked file that is *not* gitignored is no longer scanned, so a stray `notes.txt`
  holding a token would pass. The `.gitignore` checks alongside it cover `.env`, keys,
  certificates and dumps by name, not arbitrary filenames.
- **Eleven translations called the whole stack "memory-safe".** The English was corrected to
  say that the mail server and webmail are memory-safe languages while nginx and PostgreSQL
  are C; the correction reached none of the translations. All eleven now carry it. This is
  a statement about the security properties of the software, so it was treated as one.
- **Two more guards that could not fail.** `every translation records a real commit SHA` used
  the same regex as the staleness guard, so once the last row gained a `STALE` marker it
  matched **zero** rows: every tracked SHA could be fabricated and the suite stayed green.
  It now reads each row, rejects an unresolvable or malformed commit, and fails when the
  table holds fewer than eleven translation rows rather than passing on an empty table. Both
  translation guards and the secret scan now `skip` — loudly, exiting non-zero — outside a
  git checkout of this repository, instead of passing vacuously in a tarball export.
- **`install.sh` printed a warning on a clean first run.** `cp -n` draws
  `behavior of -n is non-portable` from GNU cp; the existence test it stood for is now
  explicit.
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
- **Commits are now authored by the person who made them**, not by the company identity. The
  15 earlier commits are authored as `Novaza Solution JSC <admin@novaza.ai>`. That address is
  not verified on any GitHub account, so GitHub did not credit them to anyone and the
  Contributors list showed only `dependabot`. Copyright is unchanged: `LICENSE` and `NOTICE`
  name Novaza Solution JSC. The published commits are left as they are, because other people
  have already cloned them. `MAINTAINERS.md` also now records that making an organisation
  membership public lists a person on the org page but does not add them to a repository's
  Contributors graph, which is built only from commit author emails.
- **`SECURITY.md` rewritten to the OpenSSF Scorecard criteria**, which score a policy on
  whether a reporter can actually find a way to reach you. It scored 4/10 because it named
  no URL and no email — the two things worth 6 of the 10 points. It now carries the private
  advisory link, `admin@novaza.ai`, a stage-by-stage disclosure timeline in days, an explicit
  coordinated-disclosure commitment, safe-harbour terms, and the upstream advisory channels
  for the components this project only orchestrates.
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
  Pinned by digest so **5/5 images** are reproducible. **Note for anyone reading this at the
  tag:** `v0.1.0` was cut later than this entry was written, and the tagged tree ships
  `BULWARK_VERSION=v1.7.8` and `KEYCLOAK_VERSION=26.7.0` — verify with
  `git show v0.1.0:.env.example`. **The `v0.1.0` tag already contains the fix for
  CVE-2026-34834 and the other four advisories**; the re-pin is filed under `[Unreleased]`
  above because that is when it was committed, not because the tag lacks it.
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
  internal links verified 0 broken (38 at the time; hundreds now, and no CI check enforces it — historical). No `TODO`/`FIXME`/`XXX`/`HACK` anywhere in the tree.

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

1. **The SSO edition was originally verified on Keycloak 24; **closed 2026-08-05** — the suite now runs against the shipped 26.7.0 (15/15).**
   Only Keycloak 24 could be pulled in the environment where this was tested, so what is
   proven is the database wiring, the startup ordering, the health probe and OIDC
   discovery. The Keycloak 26 specifics — `KC_BOOTSTRAP_ADMIN_*`, the full-URL
   `KC_HOSTNAME_VALUE`, and health on management port 9000 instead of 8080 — come from
   the official Keycloak documentation and are **not** measured here. Re-run the SSO
   stack against 26.0 on a host with registry access before relying on it.
   The OIDC login round-trip through the webmail (browser flow) is also untested.
2. **The mail server is on 0.13.4, not the current 0.16 line.** 0.13.4 is the patch floor
   for GHSA-8jqj-qj5p-v5rr, so no known advisory affects what ships. Upstream is at
   `v0.16.16`, and following it is a redesign rather than a tag bump: 0.16.0 replaces the
   TOML configuration with a typed JSON schema, moves config to `/etc/stalwart` and data to
   `/var/lib/stalwart`, runs as a non-root user, and **replaces the REST management API with
   a JMAP one — so `POST /api/principal`, which every first-run instruction in this repo
   uses, no longer exists**. Until that is redesigned and tested, this line stays. Note that
   advisories are not the only reason to move: upstream fixes security bugs without filing
   one, and does not backport them to older lines.
3. **Pins do not self-update.** Every image ships pinned to a version tag *and* a digest,
   which is what makes an install reproducible — and also what stops it drifting onto an
   upstream security fix. Re-pinning is still a deliberate act, but **noticing is no longer
   manual**: `scripts/check_pins.py` runs weekly and fails when a pin falls behind the line
   declared in `scripts/pin_sources.json`. `docs/RUNBOOK.md` has the upgrade and rollback
   procedure. (Until 2026-08-05 this entry said `BULWARK_DIGEST` was empty; that was left
   behind by the release that pinned it.)
4. **No SPF/DKIM/DMARC or deliverability score has been measured** against a real
   public domain; `docs/DNS.md` is guidance, not a verified result.
5. **`SEARCH HEADER Message-ID` returns no hits** on the tested mail server version
   (`SEARCH SUBJECT`/`FROM` work). Clients relying on header search will come up empty.
