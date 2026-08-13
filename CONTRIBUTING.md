# Contributing to Freehold Mail

<!-- Last-touched: 2026-08-13 — documents what the ruleset on `main` enforces, including the new
     signed-commit requirement and the fact that GitHub signs the squash-merge so contributors need
     no key of their own. Earlier the same day: named the three suites CI actually gates on. -->

Thanks for helping. This repo is **orchestration only** — compose files, nginx config,
an installer, and docs. Please read this before opening a PR, because where a change
belongs matters more here than in most projects.

## Where does my change belong?

| You want to change… | Where it goes |
|---------------------|---------------|
| How the containers are wired, defaults, installer, docs | **here** |
| Mail server behaviour (IMAP/SMTP/JMAP bugs, storage) | [Stalwart](https://github.com/stalwartlabs) |
| Webmail UI/UX, login flow | [Bulwark](https://github.com/bulwarkmail/webmail) |
| SSO/identity internals | [Keycloak](https://github.com/keycloak/keycloak) |

**Never vendor third-party source into this repo.** Stalwart and Bulwark are AGPL-3.0;
this repo is MIT precisely because it contains none of their code and only pulls
published images. A PR that copies their source in changes the licensing of the whole
project and will be closed.

## Ground rule: claims need measurements

A PR that changes runtime behaviour must say **what you ran and what it returned** —
not "works on my machine". The bar that the maintainers hold themselves to:

```bash
# the stack actually starts (not just "container is Up")
docker compose up -d && docker inspect freeholdmail-mailserver --format '{{.RestartCount}}'
# a real mail actually flows
# send via SMTP submission, then fetch it back over IMAP and compare Message-ID
```

The most recent QA found a defect that made the default edition unable to boot, while
every file "looked right". Artifacts are not evidence; measurements are.

## Development setup

```bash
git clone https://github.com/Novaza-ai/freeholdmail && cd freeholdmail
cp .env.example .env         # or run ./install.sh
# point the *_VERSION / *_DIGEST vars at images you can pull
docker compose --env-file .env up -d
```

To test without touching a real mail setup, override the published ports
(compose **merges** port lists, so use the `!override` tag):

```yaml
# docker-compose.local.yml
services:
  mailserver:
    ports: !override ["127.0.0.1:12525:25", "127.0.0.1:15587:587", "127.0.0.1:19993:993"]
```

## Checks that must pass

CI runs these; run them locally first. **The suites are the ones that will fail your pull
request** — the lint commands below them are the cheap early warnings.

```bash
# The static suite. Fast, needs no images, and is what CI's "Static checks" job runs.
# Read the result line, not the colour: a SKIP means a tool is missing and that check
# did not run, so install it and re-run rather than trusting a green board.
tests/test_config.sh                      # expect: N passed, 0 failed, and no SKIPPED

# End to end. These start containers and put a real message through SMTP → mailbox → IMAP.
tests/test_e2e.sh                         # expect: 14 passed, 0 failed
tests/test_e2e.sh --sso                   # expect: 15 passed, 0 failed
```

Two guards run inside the static suite and are worth running directly when you touch what
they cover:

```bash
# Nothing outside the publish allow-list — hosts, email domains, addresses.
# If this fires on something you added, decide whether it should be public before
# adding it to scripts/disclosure_policy.json.
scripts/check_disclosure.py               # expect: 0 finding(s)

# Every pinned image against the upstream line declared in scripts/pin_sources.json.
# Scheduled weekly, not a required check — it fails when upstream moves, not when you do.
scripts/check_pins.py                     # expect: 0 behind
```

Lint and validation:

```bash
bash -n install.sh && shellcheck install.sh
docker compose --env-file .env.example config -q
docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.sso.yml config -q
grep -rnE '(SECRET|PASSWORD|TOKEN|API_KEY)=[A-Za-z0-9+/=_-]{8,}' . # must return nothing
```

`tests/README.md` explains what each suite covers and what it deliberately does not.

## Conventions

- Every file carries a `Last-touched: <YYYY-MM-DD> — <why>` line near the top.
- **No hardcoded** endpoints, credentials, ids, or magic constants — everything comes
  from `.env`. If you need a new knob, add it to `.env.example` with a comment.
- Pin images by digest. A tag is not a version.
- Commit messages: imperative mood, one logical change per commit.

## How `main` is protected

A repository ruleset guards the default branch. Knowing what it enforces saves you a surprise at
merge time:

| Rule | What it means for you |
|---|---|
| Pull requests required | A direct push to `main` is refused. Work on a branch |
| 5 status checks required | The suites in the section above — they must be green |
| Linear history, no force-push, no deletion | `main` only ever moves forward |
| **Signed commits required** | Only commits landing on `main` are checked. **GitHub signs the squash-merge for you**, so the normal pull-request flow satisfies this with no key of your own |
| Conversation resolution required | Resolve review threads before merging |

**Your branch commits do not need to be signed** — the rule applies to the default branch, not to
yours. If you prefer to sign your own work anyway, GitHub's docs on commit signature verification
cover GPG, SSH and S/MIME keys.

Review approval is deliberately **not** required, because a single-maintainer project cannot approve
its own work. `GOVERNANCE.md` says when that changes.

## Reporting security issues

Do not open a public issue — see `SECURITY.md`.

## License

By contributing you agree your contributions are licensed under the MIT License
(`LICENSE`) that covers this repo.
