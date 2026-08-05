<!-- Last-touched: 2026-08-04 — created during pre-public QA. -->
# Requirements

What you need before running `./install.sh`. Read the DNS and network sections carefully —
they are what usually stops a self-hosted mail server from working, not the software.

## Host

| Item | Minimum | Notes |
|------|---------|-------|
| OS | Any Linux with a modern kernel | Tested on Linux 6.8 |
| Docker Engine | 24+ | `docker --version` |
| Docker Compose | **2.24+** | `docker compose version` — the test suite uses the `!override` tag, added in 2.24 |
| CPU | 2 cores | Keycloak (SSO edition) is the heaviest component |
| RAM | 2 GB base edition · 4 GB with SSO | Keycloak alone wants ~1 GB |
| Disk | 20 GB + mail volume | Mail storage grows with usage; plan for your mailbox sizes |
| Tools | `openssl`, `curl`, `bash` | `install.sh` checks for docker and openssl and exits if missing |

Everything else arrives as container images. Nothing is compiled on your host and no
third-party source is vendored into this repo.

## Network

| Port | Protocol | Purpose | Must be reachable from |
|------|----------|---------|------------------------|
| 25 | SMTP | Receiving mail from other servers | The internet |
| 587 | SMTP submission (STARTTLS) | Your users' mail clients | Your users |
| 465 | SMTP submission (implicit TLS) | Your users' mail clients | Your users |
| 993 | IMAPS | Your users' mail clients | Your users |
| 80 | HTTP | ACME challenges, redirect to HTTPS | The internet |
| 443 | HTTPS | Webmail and JMAP | Your users |

Two things that catch people out:

- **Many cloud providers block outbound port 25 by default.** Without it you can receive
  mail but not send it. Check with your provider before you start; it is usually a support
  request.
- **You need a static IP with a matching PTR (reverse DNS) record.** Receiving servers
  check it. A residential or rotating IP will land your mail in spam regardless of how
  correctly the stack is configured.

## DNS

Set up before or immediately after install — see [`DNS.md`](DNS.md) for exact records:
`MX`, `SPF`, `DKIM`, `DMARC`, and an `A`/`AAAA` for the mail host. The installer prints
what you need.

## TLS certificate

A certificate for your mail domain must exist before the stack starts, e.g.:

```bash
certbot certonly --standalone -d mail.example.com
```

`install.sh` resolves the Let's Encrypt `live/` symlinks to their real `archive/` paths,
because Docker bind-mounts the symlink itself and its target would not be mounted.

## SSO edition, additionally

- A second hostname for the identity server (e.g. `id.example.com`) with its own DNS record.
- ~1 GB extra RAM.
- The bundled PostgreSQL service; you do not need to provide a database.

## Not required

- No external database for the base edition — the mail server uses an embedded store.
- No Keycloak, and no identity server of any kind, for the base edition.
- No mail-specific kernel tuning or system users; everything runs in containers.
