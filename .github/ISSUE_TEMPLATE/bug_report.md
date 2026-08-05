---
name: Bug report
about: Something in the orchestration (compose, nginx, installer, docs) is broken
title: ''
labels: bug
---

<!-- Last-touched: 2026-08-04 -->

**Is this actually a Freehold Mail issue?**
This repo is orchestration only. Mail delivery / IMAP / storage bugs go to Stalwart;
webmail UI bugs go to Bulwark; SSO internals go to Keycloak. See SUPPORT.md.

- [ ] I checked SUPPORT.md's "Common problems"
- [ ] This is about compose/nginx/installer/docs, not upstream behaviour

**Edition**: Full Mail / Mail + SSO

**What happened**

**What you expected**

**Reproduction**
```bash
# the exact commands you ran
```

**Measurements** (please paste real output, redact secrets)
```bash
docker compose ps
docker inspect freeholdmail-mailserver --format 'restarts={{.RestartCount}} status={{.State.Status}}'
docker logs freeholdmail-mailserver 2>&1 | tail -50
docker compose --env-file .env config | grep -E '^\s+image:'
```

**Environment**
- OS / kernel:
- `docker --version`:
- `docker compose version`:
- Image versions/digests from `.env` (not the secrets):
