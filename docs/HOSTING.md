<!-- Last-touched: 2026-08-05 — hosting playbook: from a freshly rented VPS to a working
     mailbox, with server sizing taken from measurements rather than guesses. -->
# Hosting playbook

You rented a server. This is everything from there to a working mailbox, in order, with the
command to verify each step actually worked. No step says "it should work" — each one tells
you what to run and what you should see.

**Budget about 45 minutes**, most of it waiting for DNS.

> **This project is pre-1.0, and the SSO edition is only partly verified** — its browser
> login round-trip has not been measured. The sizing table below covers it because you asked
> the server how big to be, not because the edition is proven. See
> [Known gaps](../CHANGELOG.md#known-gaps-do-not-publish-without-deciding-these) before you
> put either edition in front of people who depend on their mail.

- [Before you rent](#before-you-rent-the-one-thing-that-cannot-be-fixed-later)
- [Server sizing](#server-sizing-measured-not-guessed)
- [Step 1 — the server](#step-1--prepare-the-server)
- [Step 2 — DNS](#step-2--dns)
- [Step 3 — TLS](#step-3--tls-certificate)
- [Step 4 — install](#step-4--install)
- [Step 5 — first mailbox](#step-5--your-first-mailbox)
- [Step 6 — prove it works](#step-6--prove-it-works)
- [Step 7 — deliverability](#step-7--deliverability-the-part-everyone-skips)
- [If something is wrong](#if-something-is-wrong)

---

## Before you rent: the one thing that cannot be fixed later

**Most cheap VPS providers block outbound port 25, and many will not unblock it.** Without
port 25 your server can receive nothing and send nothing. No amount of configuration fixes
it — it is a decision made on the provider's network, above your machine.

Ask the provider *before paying*: **"Is outbound TCP port 25 open, and will you provide a
PTR / reverse-DNS record for my IP?"** If either answer is no, rent elsewhere. Providers
that generally say yes to both: Hetzner (on request), OVH, Contabo, Vultr (on request),
Scaleway. Providers that generally say no: most large public clouds by default —
AWS EC2, Google Cloud, Azure and Oracle Cloud all block outbound 25 unless you apply and are
approved, and approval is not guaranteed.

Check it from the server the moment you have SSH:

```bash
# Expect a 220 banner within a couple of seconds. A hang or "Connection timed out"
# means port 25 is blocked outbound and this host cannot deliver mail anywhere.
timeout 8 bash -c 'exec 3<>/dev/tcp/gmail-smtp-in.l.google.com/25; head -1 <&3'
```

You also need:

- **A domain you control**, with access to its DNS records.
- **A static, dedicated IPv4 address.** Shared or rotating addresses are usually already on
  a blocklist because of what a previous tenant did.
- **A PTR record** (reverse DNS) mapping that IP back to your mail hostname. Most receivers
  reject or heavily penalise mail from an IP with no PTR. Only your provider can set it —
  it is in their control panel, not your DNS.

---

## Server sizing (measured, not guessed)

Every number here came from `docker stats` against this stack actually running, idle — not
from a vendor recommendation. Reproduce it with `docker stats --no-stream` after
`docker compose up -d`.

**Ranges, not point values, and that is deliberate.** Two independent runs of the same stack
disagreed by **32% on the base edition** (218 → 288 MiB) and **14% on the SSO edition**
(802 → 917 MiB). Idle memory is not a constant: the webmail is Node and its
heap grows before the garbage collector settles, Keycloak is a JVM doing the same, and
PostgreSQL's cache fills as it is used. Anyone quoting you a single figure for this has
measured once.

| Container | Base edition | SSO edition |
|-----------|--------------|-------------|
| Mail server (Stalwart) | 139–141 MiB | 139–141 MiB |
| Webmail (Bulwark) | 61–132 MiB | 61–132 MiB |
| Reverse proxy (nginx) | 17 MiB | 17 MiB |
| PostgreSQL — *SSO only* | — | 48–60 MiB |
| Keycloak — *SSO only* | — | **537–570 MiB** |
| **Total, idle** | **217–290 MiB** | **802–918 MiB** |

Stalwart and nginx are the stable ones — Rust and C, measured within 1% across both runs.
Everything on a managed runtime moved. **Size against the top of each range, never the
bottom.** Keycloak alone is roughly two thirds of the SSO edition, so if you do not need
centralised identity the base edition is dramatically cheaper to host.

### Disk

| Item | Base edition | SSO edition |
|------|--------------|-------------|
| Container images, on disk once pulled | **504 MB** (480 MiB) | **1258 MB** (1200 MiB) |
| Container images, bytes actually downloaded | ~183 MB | ~561 MB |
| Data volumes at first boot | ~3 MB | ~55 MB |
| Docker engine + OS | ~2 GB | ~2 GB |

Mail storage grows with your mail, and that is the number nobody can predict for you.
A rule of thumb that is honest about being a rule of thumb: **users x average mailbox size x
1.4**, where the 1.4 covers the full-text search index and the blob store keeping deleted
messages until they are purged.

### What to actually rent

These recommendations add headroom over the measured idle figures for the OS, page cache,
mail bursts, backups and log churn. The measured idle number is the floor, not the target.

| Scenario | vCPU | RAM | Disk | Notes |
|----------|------|-----|------|-------|
| Base edition, 1–5 mailboxes, personal | 1 | **2 GB** | 20 GB SSD | Idle peaked at 290 MiB across two runs; the rest is OS, page cache and room for delivery bursts |
| Base edition, 5–25 mailboxes, small team | 2 | **4 GB** | 60 GB SSD | Full-text indexing is the CPU spike; it is bursty, not sustained |
| SSO edition, any size | 2 | **4 GB** | 60 GB SSD | Keycloak's JVM alone needs ~1 GB of the limit set in `docker-compose.sso.yml` |
| SSO edition, 25+ mailboxes | 4 | **8 GB** | 100 GB+ SSD | Also the point to move backups off-box |

**Do not rent a 1 GB server for the SSO edition.** Measured idle reached 918 MiB before the OS,
before page cache, before a single message is delivered. It will OOM.

**Swap is not optional on a 2 GB box.** (On btrfs, `fallocate` produces a file with holes
that `swapon` rejects — use `btrfs filesystem mkswapfile` instead.)
 1–2 GB of swap turns a memory spike into a slow
minute instead of an OOM-killed mail server:

```bash
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h | grep -i swap        # expect a non-zero total
```

---

## Step 1 — prepare the server

A current Debian or Ubuntu LTS. Everything below is provider-agnostic.

```bash
# Docker Engine + the compose plugin, from Docker's own repository
curl -fsSL https://get.docker.com | sudo sh
docker --version && docker compose version

# Tools this playbook uses in later steps. dig comes from dnsutils; swaks tests SMTP;
# ufw is not installed by default on a minimal Debian.
sudo apt-get update && sudo apt-get install -y dnsutils swaks ufw
```

Verify — both commands must print a version:

```bash
docker --version          # Docker version 27.x or newer
docker compose version    # Docker Compose version v2.24 or newer
```

**Compose v2.24 is a hard floor**: the test suite uses the `!override` YAML tag, which older
versions do not understand.

Open the ports. Mail needs more than a web server does:

```bash
sudo ufw allow 22/tcp     # SSH — do this FIRST or you will lock yourself out
sudo ufw allow 25/tcp     # SMTP, server-to-server delivery
sudo ufw allow 80/tcp     # HTTP, redirects to HTTPS and renews certificates
sudo ufw allow 443/tcp    # HTTPS, the webmail
sudo ufw allow 465/tcp    # SMTPS submission
sudo ufw allow 587/tcp    # SMTP submission with STARTTLS
sudo ufw allow 993/tcp    # IMAPS
sudo ufw enable
sudo ufw status numbered  # verify: every port above is listed as ALLOW
```

> **`ufw` does not protect the container ports, and `ufw status` will not tell you that.**
> Docker inserts its own DNAT rules in `nat PREROUTING` and filters in `FORWARD`, while ufw
> works in `INPUT` — so a published container port reaches the container even when ufw says
> `DENY`. Check reality with `sudo iptables -t nat -L DOCKER -n`. The rules above still
> matter for anything running on the host itself (SSH), and they document intent, but treat
> the compose `ports:` list as the real firewall: what is published is exposed. This is why
> the admin API is bound to `127.0.0.1:8080` in `docker-compose.yml` rather than left to a
> firewall rule.

Port 8080 is deliberately **not** in that list. The admin API binds to `127.0.0.1` only, and
it returns account passwords in cleartext — see [`../SECURITY.md`](../SECURITY.md). Reach it
over an SSH tunnel, never from the internet.

---

## Step 2 — DNS

Set these at your domain registrar. Substitute your domain and your server's IP.

| Type | Name | Value | Why |
|------|------|-------|-----|
| A | `mail` | your server IPv4 | Where the webmail and the mail server live |
| MX | `@` | `10 mail.example.com.` | Tells the world where to deliver your mail |
| TXT | `@` | `v=spf1 mx -all` | Only your MX host may send as you |
| TXT | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:postmaster@example.com` | What receivers do with failures, and where to report |
| PTR | *(your provider's panel)* | `mail.example.com` | Reverse DNS. **Not** set in your DNS zone |

DKIM comes later — the mail server generates the key at first start, so you cannot publish
that record until Step 7.

Verify before continuing. DNS propagation is the slow part; wait for these to answer:

```bash
dig +short A    mail.example.com     # expect your server's IP
dig +short MX   example.com          # expect: 10 mail.example.com.
dig +short TXT  example.com          # expect the v=spf1 record
dig +short -x   YOUR.SERVER.IP       # expect mail.example.com.  ← the PTR
```

If `dig -x` returns nothing, your provider has not set the PTR. Fix that before sending any
mail: your first messages set your reputation, and a missing PTR poisons it immediately.

---

## Step 3 — TLS certificate

```bash
sudo apt-get update && sudo apt-get install -y certbot
sudo certbot certonly --standalone -d mail.example.com
```

Port 80 must be free while this runs — nothing else may be listening. That is true at
issuance, and it is **also true at every renewal 60 days later**, which is the part that
bites: certbot records the authenticator in
`/etc/letsencrypt/renewal/mail.example.com.conf` and reuses it, but by then the proxy owns
:80 and `--standalone` cannot bind. The certificate then expires silently on a server that
has been working for three months.

Stop and start the proxy around each renewal, so `--standalone` gets the port it needs:

```bash
sudo mkdir -p /etc/letsencrypt/renewal-hooks/{pre,post}
echo -e '#!/bin/sh\ndocker stop freeholdmail-proxy' \
  | sudo tee /etc/letsencrypt/renewal-hooks/pre/stop-proxy.sh
echo -e '#!/bin/sh\ndocker start freeholdmail-proxy' \
  | sudo tee /etc/letsencrypt/renewal-hooks/post/start-proxy.sh
sudo chmod +x /etc/letsencrypt/renewal-hooks/pre/stop-proxy.sh \
              /etc/letsencrypt/renewal-hooks/post/start-proxy.sh
```

**Then prove renewal actually works — but only AFTER Step 4, once the stack exists.** Run
now, the pre-hook's `docker stop` fails with "No such container", certbot reports the failure
and carries on regardless, and the dry-run prints "Congratulations" having tested nothing:

```bash
# AFTER the stack is up (Step 4). Note --run-deploy-hooks: a plain --dry-run skips them.
sudo certbot renew --dry-run --run-deploy-hooks
# expect: "Congratulations, all simulated renewals succeeded" AND no hook error above it.
# Read the hook output, not just the last line.
```

The `post` hook runs whether the renewal succeeded or failed, so the proxy always comes
back. The `deploy` hook below is different — it runs only after a *successful* renewal,
which is why it cannot be the thing that restarts your proxy.

Verify:

```bash
sudo ls -l /etc/letsencrypt/live/mail.example.com/
# expect fullchain.pem and privkey.pem (they are symlinks into ../archive/)
sudo openssl x509 -in /etc/letsencrypt/live/mail.example.com/fullchain.pem -noout -dates
# expect notAfter roughly 90 days out
```

Renewal runs from certbot's own systemd timer. The containers read the certificate from a
bind mount, so a renewed certificate is picked up when the proxy restarts:

```bash
sudo systemctl list-timers | grep certbot     # expect a scheduled timer
```

**Renewal writes a NEW file, and the container is mounted on the old one.** This is the part
that silently breaks. `install.sh` resolves the Let's Encrypt symlink and writes the
*versioned archive path* — `/etc/letsencrypt/archive/<domain>/fullchain1.pem` — into `.env`,
because Docker bind-mounts a symlink itself and it would dangle inside the container. When
certbot renews it creates `fullchain2.pem` and repoints `live/`; your container is still
mounted on `fullchain1.pem`, which certbot leaves on disk. **Nothing errors. Nothing warns.
The proxy serves the expired certificate forever, and restarting it changes nothing** —
the mount is baked into the container at creation.

The deploy hook therefore has to re-resolve the path and *recreate* the containers:

```bash
sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-freeholdmail.sh >/dev/null <<'HOOK'
#!/bin/sh
# certbot renewed the cert: archive/fullchainN.pem is a NEW file, so the compose mount must
# be repointed and the containers recreated. `docker restart` is NOT enough — a restart
# keeps the old bind mount.
set -e
REPO=/opt/freeholdmail            # <-- set this to where you cloned the repo
DOMAIN=mail.example.com           # <-- your mail domain
sed -i "s|^TLS_FULLCHAIN=.*|TLS_FULLCHAIN=$(readlink -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem)|" "$REPO/.env"
sed -i "s|^TLS_PRIVKEY=.*|TLS_PRIVKEY=$(readlink -f /etc/letsencrypt/live/$DOMAIN/privkey.pem)|" "$REPO/.env"
cd "$REPO" && docker compose up -d --force-recreate proxy mailserver
HOOK
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-freeholdmail.sh
```

**Prove it rotated, by reading the date off the live port** — not by trusting the hook:

```bash
echo | openssl s_client -connect mail.example.com:465 2>/dev/null | openssl x509 -noout -dates
# notAfter must move ~90 days forward after a renewal. If it did not, the container is
# still mounted on the previous certificate.
```

`docs/RUNBOOK.md` §"Certificate renewal" is the manual form of the same procedure; run it
once by hand before trusting the hook.

---

## Step 4 — install

```bash
git clone https://github.com/Novaza-ai/freeholdmail
cd freeholdmail
./install.sh
```

The installer asks for your edition and domain, then generates every secret with
`openssl rand`, writes `.env` at mode 600, resolves the Let's Encrypt symlinks (a
bind-mounted symlink dangles inside a container), and offers to start the stack.

Verify:

```bash
ls -l .env                       # expect -rw------- (600). Nothing else may read it.
docker compose ps                # expect mailserver healthy, webmail and proxy running
docker compose logs mailserver | tail -20   # expect no restart loop
```

---

## Step 5 — your first mailbox

The admin API is on `127.0.0.1:8080` and nowhere else. From the server itself:

```bash
# Load the generated admin secret without printing it to your shell history
export ADMIN=$(grep '^STALWART_FALLBACK_ADMIN_SECRET=' .env | cut -d= -f2-)

# 1. your domain
curl -u "admin:$ADMIN" -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' \
  -d '{"type":"domain","name":"example.com"}'

# 2. your mailbox — note "roles":["user"], which everyone forgets
curl -u "admin:$ADMIN" -X POST http://127.0.0.1:8080/api/principal \
  -H 'Content-Type: application/json' \
  -d '{"type":"individual","name":"you@example.com","secrets":["a-strong-password"],
       "emails":["you@example.com"],"roles":["user"]}'
```

**`"roles":["user"]` is required.** Without it the account exists, the password is accepted,
and SMTP AUTH still answers `550 5.7.1` — an error that reads like a wrong password and is
not one.

From your laptop instead of the server, tunnel first — never expose 8080:

```bash
ssh -L 8080:127.0.0.1:8080 you@your-server
```

---

## Step 6 — prove it works

Do not trust the dashboard. Prove each layer:

```bash
# The webmail answers through the proxy. Follow redirects: it routes / to a locale prefix.
curl -sIL https://mail.example.com/ | grep -E '^HTTP'        # expect a final 200

# TLS is modern and obsolete versions are refused
echo | openssl s_client -connect mail.example.com:443 2>/dev/null | grep 'Protocol'
# expect TLSv1.3 (or 1.2). If you see TLSv1 or TLSv1.1, stop and read SECURITY.md.

# The mail server greets on submission
timeout 8 bash -c 'exec 3<>/dev/tcp/mail.example.com/587; head -1 <&3'   # expect 220

# Open relay is refused — this must FAIL, and failing is the pass condition
swaks --to test@example.org --from spam@evil.test --server mail.example.com:25
# expect: 550 5.1.2 Relay not allowed
```

Then send yourself a real message from an outside account and reply to it. A stack that
passes every check above and still cannot exchange mail with Gmail has a deliverability
problem, not a configuration problem — which is Step 7.

---

## Step 7 — deliverability, the part everyone skips

A working mail server that lands in spam is not a working mail server.

1. **Publish DKIM.** The mail server generated a key at first start. Read it from the admin
   API and publish it as a TXT record, then verify with
   `dig +short TXT default._domainkey.example.com`.
2. **Test your score.** Send a message to a free checker such as
   [mail-tester.com](https://www.mail-tester.com/) and read every line of the report. Below
   8/10, fix what it names before sending real mail.
3. **Warm up.** A brand-new IP sending a hundred messages on day one looks exactly like a
   compromised host. Start with a handful a day and grow over two weeks.
4. **Watch your blocklist status.** Check the IP on a public blocklist lookup before you
   depend on it, not after your mail stops arriving.

See [`DNS.md`](DNS.md) for the full record reference.

---

## If something is wrong

| Symptom | Most likely cause | Check |
|---------|-------------------|-------|
| Mail never arrives from outside | Port 25 blocked inbound, or MX wrong | `dig +short MX example.com`; ask the provider about inbound 25 |
| Cannot send anywhere | Port 25 blocked **outbound** by the provider | the `/dev/tcp` probe at the top of this file |
| `550 5.7.1` when sending | The account has no `roles` | recreate it with `"roles":["user"]` |
| Everything lands in spam | No PTR, or no DKIM | `dig +short -x YOUR.IP`, then the DKIM record |
| Webmail shows "Configuration Error" | The app cannot reach its own API | `curl -sk https://mail.example.com/api/config` — expect 200 |
| Mail server restart-loops | Config or storage problem | `docker compose logs mailserver \| tail -40` |
| Container OOM-killed | Server too small for the edition | `free -h`, then the sizing table above |

`docs/RUNBOOK.md` covers day-2 operations: backup, restore, upgrade, rollback.
[`../SUPPORT.md`](../SUPPORT.md) is where to ask when this table does not cover it.
