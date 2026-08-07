<!-- Last-touched: 2026-08-07 — §6: in-place upgrade from v0.11.x is destructive; measured and documented. -->
# Runbook

> **Pre-1.0.** This document describes day-2 operations as if the stack were mature. It is
> not: the SSO edition's browser login round-trip is unverified, and the admin API used
> below returns account passwords in cleartext. Read [`../SECURITY.md`](../SECURITY.md)
> first.

Day-2 operations. Every command here is meant to be copy-pasted on the host running the
stack. Commands that touch secrets never print them.

Conventions: `$` is the host shell, run from the repo directory. Service names are
`mailserver`, `webmail`, `proxy`, plus `idp` and `db` on the SSO edition.

---

## 1. Is it healthy?

```bash
docker compose ps
docker inspect freeholdmail-mailserver --format 'restarts={{.RestartCount}} health={{.State.Health.Status}}'
curl -sk -o /dev/null -w '%{http_code} %{time_total}s\n' https://<your-domain>/
```

Healthy looks like: every service `running`, mail server `healthy`, `restarts=0`, webmail
`200`. A climbing restart count is the signal that matters — see §8.

Full verification, on a machine that can spare a couple of minutes:

```bash
tests/test_e2e.sh          # stands up a throwaway copy; does not touch this deployment
```

---

## 2. Add, inspect, or remove a mailbox

The admin API listens on the mail server's HTTP port; keep it off the public internet.

```bash
ADMIN="admin:$(grep '^STALWART_FALLBACK_ADMIN_SECRET=' .env | cut -d= -f2-)"
API=http://127.0.0.1:8080/api/principal

# add a domain
curl -s -u "$ADMIN" -X POST "$API" -H 'Content-Type: application/json' \
  -d '{"type":"domain","name":"example.com"}'

# add a mailbox — roles is REQUIRED, without it SMTP AUTH returns 550 5.7.1
curl -s -u "$ADMIN" -X POST "$API" -H 'Content-Type: application/json' \
  -d '{"type":"individual","name":"you@example.com","secrets":["<password>"],
       "emails":["you@example.com"],"roles":["user"]}'

# list
curl -s -u "$ADMIN" "$API?limit=50"

# remove
curl -s -u "$ADMIN" -X DELETE "$API/you@example.com"
```

> ⚠️ Listing principals returns each account's password **in cleartext** — upstream
> behaviour, see `SECURITY.md`. Never pipe this output into a log or a ticket.

---

## 3. Rotate the bootstrap admin secret

Do this once your real accounts exist, and after anyone who had it leaves.

```bash
NEW=$(openssl rand -base64 32 | tr -d '\n=+/' | cut -c1-40)
sed -i "s|^STALWART_FALLBACK_ADMIN_SECRET=.*|STALWART_FALLBACK_ADMIN_SECRET=${NEW}|" .env
docker compose up -d --force-recreate mailserver
unset NEW
```

Verify with an authenticated call (expect `200`):

```bash
curl -s -o /dev/null -w '%{http_code}\n' -u "admin:$(grep '^STALWART_FALLBACK_ADMIN_SECRET=' .env | cut -d= -f2-)" \
  http://127.0.0.1:8080/api/principal
```

---

## 4. Back up and restore

State lives in named volumes, not in the repo. Back up all of them plus `.env`.

**Back up outside the repository.** A backup contains every message plus a copy of `.env`;
inside the working tree it is one `git add -A` away from being published. `.gitignore`
covers the usual names as a safety net, but the default here deliberately points elsewhere.

```bash
BACKUP_DIR=/var/backups/freeholdmail        # NOT inside this repo
install -d -m 700 "$BACKUP_DIR"

# backup (stop first for a consistent copy of the mail store)
docker compose stop mailserver
docker run --rm -v freeholdmail_mailserver_data:/data -v "$BACKUP_DIR:/backup" alpine \
  tar czf /backup/mailserver-$(date +%F).tar.gz -C /data .
docker compose start mailserver
cp .env "$BACKUP_DIR/env-$(date +%F).bak" && chmod 600 "$BACKUP_DIR"/env-*.bak
```

On the SSO edition also dump Keycloak's database:

```bash
docker exec freeholdmail-idp-db pg_dump -U keycloak keycloak \
  | gzip > "$BACKUP_DIR/keycloak-$(date +%F).sql.gz"
```

Restore is the inverse — stop the stack, untar into the volume, `docker compose up -d`.
**Test your restore on a throwaway host before you need it.** Until a backup has been
restored at least once, you do not know whether it works.

---

## 5. Renew TLS certificates

`.env` points at the **resolved** certificate files, not the Let's Encrypt `live/`
symlinks — a bind-mounted symlink dangles inside the container because its target is not
mounted. After certbot renews, the resolved path changes (`fullchain1.pem` →
`fullchain2.pem`), so re-resolve and recreate:

```bash
certbot renew
sed -i "s|^TLS_FULLCHAIN=.*|TLS_FULLCHAIN=$(readlink -f /etc/letsencrypt/live/<domain>/fullchain.pem)|" .env
sed -i "s|^TLS_PRIVKEY=.*|TLS_PRIVKEY=$(readlink -f /etc/letsencrypt/live/<domain>/privkey.pem)|" .env
docker compose up -d --force-recreate proxy mailserver
echo | openssl s_client -connect <your-domain>:465 2>/dev/null | openssl x509 -noout -dates
```

Automate it as a certbot `--deploy-hook` once you have run it manually once.

---

## 6. Upgrade a component

Change one component at a time and verify between steps.

```bash
docker compose --env-file .env config | grep -E '^\s+image:'   # what you run now
docker manifest inspect <image>:<new-tag>                       # confirm it exists
sed -i 's|^STALWART_VERSION=.*|STALWART_VERSION=<new-tag>|' .env
sed -i 's|^STALWART_DIGEST=.*|STALWART_DIGEST=@sha256:<digest>|' .env
docker compose pull mailserver && docker compose up -d mailserver
docker inspect freeholdmail-mailserver --format 'restarts={{.RestartCount}} health={{.State.Health.Status}}'
tests/test_e2e.sh
```

Rollback: put the previous tag and digest back in `.env` and repeat. This is why the
digest is pinned — the old bytes are still addressable even if the tag moved.

### Upgrading an existing install from the v0.11.x mail server

Releases up to and including `v0.2.0` shipped `stalwartlabs/mail-server:v0.11.8`. This repo
now ships `stalwartlabs/stalwart:v0.13.4`, which closes GHSA-8jqj-qj5p-v5rr — a High,
pre-authentication advisory. **A fresh install needs nothing from this section.**

> ⚠️ **Do not upgrade an existing install in place. We tested it and it destroys the
> database.** Read this whole section before touching a server that holds mail.

**What we measured**, on a throwaway stack, on 2026-08-07:

| Attempt | Result |
|---|---|
| 0.11.8 data → start 0.13.4 on the same volume, config path updated | Starts, listeners healthy, but `GET /api/principal` → **HTTP 500** and `ERROR Data corruption detected … "Archive integrity compromised"` at `crates/store/src/write/serialize.rs:71` |
| Same, but stepping through 0.12.5 first | Identical corruption error, **HTTP 500**. No migration ever ran |
| Same, but leaving the config pointed at the old `/opt/stalwart-mail/data` | Admin authentication itself fails, **HTTP 401** — the server quietly creates an empty database at the stale path while the real data sits unreferenced |
| **Rolling back to 0.11.8 afterwards** | **Works.** Accounts read back in full, `HTTP 200`, zero errors in the log |

0.13.4 cannot deserialize a 0.11.x principal record — the payload in the corruption log
decodes to the account itself, so it is the storage format that changed, not the path.

**Your data is not destroyed by a failed attempt.** We tested the rollback that §6 above
already describes — put the previous tag and digest back in `.env` — and v0.11.8 read
everything back. Going *forward* to 0.12.5 after 0.13.4 has touched the volume does not work
(`panicked: Unknown database schema version, expected 2 or below, found 3`), so roll back to
the version you came from, not to an intermediate.

Upstream's `UPGRADING/v0_12.md` states the migration is automatic on startup. In this
deployment it was not. We are reporting what our own measurements show; if you find a
configuration where the in-place path works, we want the correction.

**There is no migration path this project has verified.** That is the honest position, and
it leaves you two options: stay on `v0.11.8` with the mitigations below, or attempt
upstream's export/import on a *copy* of your data, at your own risk. What follows is the
least-bad order for the second option, not a procedure we have walked end to end.

1. **Stop the mail server and take a backup you have actually read back.**
   ```bash
   docker compose stop mailserver
   docker run --rm -v freeholdmail_mailserver_data:/data -v /var/backups:/backup alpine \
     tar czf /backup/mailserver-pre-0.13-$(date +%F).tar.gz -C /data .
   # Verify it, do not just look at its size — a truncated archive has a size too.
   tar tzf /var/backups/mailserver-pre-0.13-*.tar.gz | head
   tar tzf /var/backups/mailserver-pre-0.13-*.tar.gz | wc -l    # expect hundreds of entries
   ```
   If you run compose with `-p <name>`, the volume is `<name>_mailserver_data` — check with
   `docker volume ls` rather than trusting the name above.
2. **Record what you have, so you can tell afterwards whether anything is missing.**
   ```bash
   ADMIN="admin:$(grep '^STALWART_FALLBACK_ADMIN_SECRET=' .env | cut -d= -f2-)"
   curl -s -u "$ADMIN" 'http://127.0.0.1:8080/api/principal?limit=1000' \
     | python3 -c 'import sys,json; d=json.load(sys.stdin)["data"]; print("principals:", d["total"])'
   ```
   Write that number down. Also note the message count in at least one busy mailbox from
   your own client.
3. **Do not point 0.13.4 at that volume.** Stand up the new version beside the old one, on a
   copy of the data or on an empty volume, and migrate accounts and mail across using
   upstream's export/import utility — see
   <https://stalw.art/docs/management/migration>. **We have not verified that path**; our
   attempt to run `--export` through the 0.11.8 Docker entrypoint did not complete, so treat
   upstream's instructions as the authority and test on a copy first.
4. **Verify against your own migrated instance before you cut over.** Not with
   `tests/test_e2e.sh` — that suite stands up a *throwaway* stack from `.env.example`, with
   its own project name, its own volumes and its own certificate. It proves the shipped
   defaults work; it says nothing about your data. Check the thing you actually care about:
   ```bash
   # same query as step 2, against the migrated instance — the number must match
   curl -s -u "$ADMIN" 'http://127.0.0.1:8080/api/principal?limit=1000' \
     | python3 -c 'import sys,json; d=json.load(sys.stdin)["data"]; print("principals:", d["total"])'
   ```
   Then log in as a real account, confirm the folder and message counts you noted in step 2,
   and send one message in and one out. Only then cut over.

**If you cannot migrate yet**, staying on `v0.11.8` means staying exposed to
GHSA-8jqj-qj5p-v5rr, which needs no credentials and only a reachable IMAP port. Restrict
source addresses on 993 at the firewall (`ufw allow from <range> to any port 993`) until you
can move.

**What changed besides the version.** The image was renamed from `stalwartlabs/mail-server`
to `stalwartlabs/stalwart`, and its volume moved from `/opt/stalwart-mail` to
`/opt/stalwart` — so `config/stalwart/config.toml` needs its `store."db".path` updated to
`/opt/stalwart/data`, which the shipped example already does. None of the settings renamed in
0.12.0 appear in the config this repo ships. One visible behaviour change: `/.well-known/jmap`
answered `401` on 0.11 and answers `307` to `/jmap/session` on 0.13, which is what RFC 8620
describes; `tests/test_e2e.sh` accepts both.

**Before crossing to v0.16 or later**, read `CHANGELOG.md` "Known gaps". That is a different
kind of upgrade again: the TOML configuration becomes a typed JSON schema and v0.16.0 replaces
the REST management API with a JMAP one, so `POST /api/principal` — the call every first-run
instruction here uses — no longer exists.

---

## 7. Check deliverability

Not covered by the automated tests — it needs a real public domain.

```bash
dig +short MX <your-domain>
dig +short TXT <your-domain>              # SPF
dig +short TXT _dmarc.<your-domain>       # DMARC
dig +short TXT <selector>._domainkey.<your-domain>   # DKIM
```

Then send a message from a real mailbox to a scoring service such as mail-tester.com and
read the report. Records are documented in `docs/DNS.md`.

---

## 8. Incidents

> **Blast radius: an unhealthy mail server takes the whole site down, not just mail.**
> `docker-compose.yml` gives the proxy `depends_on: mailserver: condition: service_healthy`,
> so while the mail server is unhealthy the proxy never starts — you lose the webmail, port
> 443 **and port 80**, and with port 80 the ACME http-01 renewal path in
> [`HOSTING.md`](HOSTING.md). Measured on a throwaway stack: proxy stuck in `Created`,
> `curl` to the site refused. There is no graceful degradation here. Fix the mail server
> first, and treat a long outage as also putting your certificate at risk.

**Mail server restart-loops.** Almost always configuration.

```bash
docker logs freeholdmail-mailserver 2>&1 | grep -iE 'error|not-configured' | head -20
```

`Store not configured` means `config/stalwart/config.toml` is missing its
`[store]`/`[storage]`/`[directory]` blocks — re-copy from
`config/stalwart/config.toml.example`.

**Users can't send: `550 5.7.1 Your account is not authorized to use this service`.**
The account has no role — see §2 and add `roles:["user"]`.

**Users can't send: `No suitable authentication method found`.**
The client is trying to authenticate before STARTTLS. Password mechanisms are only offered
on an encrypted connection; this is intended. Configure the client for STARTTLS on 587 or
implicit TLS on 465.

**Mail is accepted but never arrives elsewhere.** Check the queue and your outbound
reputation before suspecting the stack:

```bash
docker logs freeholdmail-mailserver 2>&1 | grep -i 'queue\|delivery' | tail -30
```

**Keycloak won't start (SSO edition).** It waits for the database healthcheck; if `db` is
unhealthy, Keycloak never starts by design. Check `docker logs freeholdmail-idp-db`. On first
boot Keycloak runs ~124 schema changesets and refuses HTTP for about a minute — that is
normal, not a fault.

**Webmail loads but cannot reach mail.** The webmail talks to the mail server over
`JMAP_SERVER_URL`; confirm the proxy routes `/jmap` and `/api` and that the value in `.env`
is the public URL, not a container name.

---

## 9. Decommission

```bash
docker compose down                # keep data
docker compose down -v             # DESTROY the mail store and Keycloak database
```

`down -v` is irreversible. Take a backup first (§4).
