# Getting help

<!-- Last-touched: 2026-08-04 — created during pre-public QA. -->

## Ask in the right place

Freehold Mail assembles four independent projects. Sending a question to the right one gets
you an answer far faster.

| Symptom | Ask here |
|---------|----------|
| `docker compose up` fails, wrong env var, nginx routing, installer bug | **this repo's issues** |
| Mail not delivered, IMAP/JMAP/SMTP errors, storage or spam filtering | [Stalwart](https://github.com/stalwartlabs) |
| Webmail UI problems, login screen, message list, calendar | [Bulwark](https://github.com/bulwarkmail/webmail) |
| SSO/OIDC, realms, token errors | [Keycloak](https://github.com/keycloak/keycloak) |

## Before you open an issue

Please include:

```bash
docker compose ps
docker inspect freeholdmail-mailserver --format 'restarts={{.RestartCount}} status={{.State.Status}}'
docker logs freeholdmail-mailserver 2>&1 | tail -50
docker compose --env-file .env config | grep -E '^\s+image:'
```

Redact `.env` values — never paste secrets into an issue.

## Common problems

**The mail server restart-loops with `Store not configured`.**
Your `config/stalwart/config.toml` is missing the `[store]`/`[storage]`/`[directory]`
blocks. Re-copy it from `config/stalwart/config.toml.example`.

**SMTP AUTH fails with `550 5.7.1 Your account is not authorized to use this service`.**
The account has no role. Add one:

```bash
curl -u admin:$STALWART_FALLBACK_ADMIN_SECRET -X PATCH \
  http://127.0.0.1:8080/api/principal/you@example.com \
  -H 'Content-Type: application/json' \
  -d '[{"action":"addItem","field":"roles","value":"user"}]'
```

**`AUTH` is missing from the EHLO response on port 587.**
That is intentional — authentication is only offered after `STARTTLS`.

**TLS files are empty or missing inside the container.**
You bind-mounted a Let's Encrypt `live/` symlink. Use the resolved `archive/` path
(`readlink -f`), which is what `install.sh` writes.

## Security issues

Do not open a public issue — see `SECURITY.md`.
