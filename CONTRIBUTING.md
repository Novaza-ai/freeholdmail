# Contributing to Freehold Mail

<!-- Last-touched: 2026-08-04 — created during pre-public QA. -->

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

CI runs these; run them locally first:

```bash
bash -n install.sh && shellcheck install.sh
docker compose --env-file .env.example config -q
docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.sso.yml config -q
grep -rnE '(SECRET|PASSWORD|TOKEN|API_KEY)=[A-Za-z0-9+/=_-]{8,}' . # must return nothing
```

## Conventions

- Every file carries a `Last-touched: <YYYY-MM-DD> — <why>` line near the top.
- **No hardcoded** endpoints, credentials, ids, or magic constants — everything comes
  from `.env`. If you need a new knob, add it to `.env.example` with a comment.
- Pin images by digest. A tag is not a version.
- Commit messages: imperative mood, one logical change per commit.

## Reporting security issues

Do not open a public issue — see `SECURITY.md`.

## License

By contributing you agree your contributions are licensed under the MIT License
(`LICENSE`) that covers this repo.
