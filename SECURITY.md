# Security Policy

<!-- Last-touched: 2026-08-04 — written during the pre-public GATE-2 security review. -->

## Reporting a vulnerability

Report privately — **do not open a public issue**.

- Preferred: GitHub **Security → Report a vulnerability** (private advisory) on this repo.
- Alternative: email the address in `NOTICE`, subject prefixed `[SECURITY]`.

We aim to acknowledge within **3 business days** and to ship a fix or a documented
mitigation within **30 days** for issues we can reproduce. We will credit you unless
you ask otherwise.

**Scope.** This repo is *orchestration*: compose files, nginx config, the installer,
and docs. Vulnerabilities inside Stalwart, Bulwark, Keycloak, or nginx belong to those
projects — please report them upstream. If an upstream flaw is *made worse by our
defaults*, that is in scope here and we want to hear about it.

## Known security properties (measured 2026-08-04, not assumed)

Verified on a throwaway stack built from this repo:

| Property | Result | How it was checked |
|----------|--------|--------------------|
| Open relay | **Denied** — `550 5.1.2 Relay not allowed` | `MAIL FROM` external, `RCPT TO` external on port 25 |
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
4. **Digest pinning is partial.** `BULWARK_DIGEST` ships empty, so that image
   follows a mutable tag until you pin it. Pin it before production.
5. **TLS material is bind-mounted from the host.** Anyone who can write those
   files can impersonate your mail server.

## Supported versions

Pre-1.0. Only the latest tag receives fixes.
