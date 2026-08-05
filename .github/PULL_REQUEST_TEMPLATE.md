<!-- Last-touched: 2026-08-04 -->

## What this changes

## Why

## Measurements

Claims about runtime behaviour need evidence — paste what you ran and what it returned.

```
# e.g. docker inspect freeholdmail-mailserver --format '{{.RestartCount}}'  → 0
# e.g. SMTP submit + IMAP fetch, Message-ID matched
```

## Checklist

- [ ] `bash -n install.sh` and `shellcheck install.sh` pass
- [ ] `docker compose --env-file .env.example config -q` passes for both editions
- [ ] No third-party source vendored into this repo (it would break the MIT/AGPL split)
- [ ] No hardcoded endpoints, credentials, ids, or magic constants — new knobs added to `.env.example`
- [ ] Images referenced by digest, not just a tag
- [ ] `Last-touched:` line updated on every file I changed
- [ ] Docs updated (`README.md` / `SECURITY.md` / `CHANGELOG.md`) if behaviour changed
