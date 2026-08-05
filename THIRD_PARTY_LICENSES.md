<!-- Last-touched: 2026-08-04 — new repo scaffold: third-party license separation -->
# Third-Party Licenses & Compliance

**Read this before you deploy, fork, or offer this stack as a service.**

`Freehold Mail` itself is **MIT** (see `LICENSE`) — that covers only the
orchestration, config, installer and docs written in *this* repository.

This project is an **assembly**: it wires together independent, separately-licensed
programs that run as their own containers and talk to each other only over the
network (HTTP/JMAP/OIDC/SMTP/IMAP). This repo ships **no third-party source code**
and **applies no patches** to them — it pulls their **official images** at install time.

## Components pulled at install time

| Component | Role | License | Source | Ships in this repo? |
|-----------|------|---------|--------|---------------------|
| Stalwart Mail Server | Backend mail server (JMAP/IMAP/SMTP store) | **AGPL-3.0-only OR SELv1** (dual) | https://github.com/stalwartlabs/stalwart | ❌ pulled as official image |
| Bulwark Webmail | Frontend webmail UI | **AGPL-3.0-only** | https://github.com/bulwarkmail/webmail | ❌ pulled as official image |
| Keycloak *(SSO edition only)* | Identity provider / SSO (OIDC) | **Apache-2.0** | https://github.com/keycloak/keycloak | ❌ pulled as official image |
| PostgreSQL *(SSO edition only)* | Keycloak's database | **PostgreSQL License** | https://www.postgresql.org/about/licence/ | ❌ pulled as official image |
| nginx | Reverse proxy / TLS termination | **BSD-2-Clause** | https://nginx.org/LICENSE | ❌ pulled as official image |

> **On Stalwart's licence, precisely.** Upstream states AGPL-3.0 *as published by the Free
> Software Foundation*, dual-licensed with the Stalwart Enterprise License v1 — it does not
> offer an "or later" option, and this repository must not restate it as `-or-later`, which
> would grant a permission the copyright holder did not. Which of the two licences governs
> the binary in the official image is a question for Stalwart Labs, not for this repo.

> Verify the exact image coordinates in `docker-compose.yml` against each project's
> official registry before publishing — do not assume a registry path.

## What this means for you (plain language)

1. **You self-host, unmodified images → nothing extra to do.** AGPL's "network use"
   clause only obliges *whoever modifies* the AGPL program and then serves/distributes it.
   Running the official Stalwart/Bulwark images imposes no new obligation on you.

2. **You modify Stalwart or Bulwark and run it for others → you must publish your
   modified source** of that component under AGPL-3.0 to those users. This obligation
   attaches to the *modified component*, **not** to this MIT orchestration repo.

3. **You must NOT copy AGPL source into this MIT repo.** If a fix to Bulwark/Stalwart
   is needed, either (a) upstream it as an AGPL pull request so the official image
   carries it, or (b) keep the modified component in a **separate, clearly AGPL-licensed
   repository** with its own published source — never bundled here.

4. **Keycloak (Apache-2.0)** is permissive; keep its `NOTICE`/attribution if you
   redistribute its files.

## Attribution

This project would not exist without the upstream work of Stalwart Labs, the Bulwark
Project Authors, and the Keycloak community. This project is **not affiliated with,
sponsored by, or endorsed by** any of them. "Stalwart", "Bulwark" and "Keycloak" are
the marks of their respective owners.
