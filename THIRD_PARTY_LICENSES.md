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
| Stalwart Mail Server | Backend mail server (JMAP/IMAP/SMTP store) | **AGPL-3.0-or-later** (dual w/ proprietary Enterprise license) | https://github.com/stalwartlabs/mail-server | ❌ pulled as official image |
| Bulwark Webmail | Frontend webmail UI | **AGPL-3.0-only** | https://github.com/bulwarkmail/webmail | ❌ pulled as official image |
| Keycloak *(SSO edition only)* | Identity provider / SSO (OIDC) | **Apache-2.0** | https://github.com/keycloak/keycloak | ❌ pulled as official image |
| nginx | Reverse proxy | BSD-2-Clause | https://nginx.org | ❌ pulled as official image |

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
