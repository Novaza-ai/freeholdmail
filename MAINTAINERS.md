<!-- Last-touched: 2026-08-05 — created for the 0.1.0 release: name the humans behind the org. -->
# Maintainers

Who to expect a reply from, and who can merge.

| Role | Who | GitHub | Scope |
|------|-----|--------|-------|
| Maintainer | Novaza Solution JSC | [@daikaginza](https://github.com/daikaginza) | Everything: releases, security response, final say on scope |

Contact: `admin@novaza.ai`. For anything with a security dimension use GitHub's private
advisory flow instead — see [`SECURITY.md`](SECURITY.md). Do not report vulnerabilities in
public issues.

## The honest bus factor

**There is one maintainer.** That is a real risk to you if you are deciding whether to run
this in production, so it is stated here rather than left to be discovered:

- A single person can be unavailable, and there is no second reviewer to merge in the
  meantime.
- The project is MIT-licensed and the stack it assembles is upstream software under its own
  licences. If this repository stopped being maintained tomorrow, your running installation
  would keep working, and anyone could fork it without asking permission. That is the
  intended safety net, not an afterthought.
- [`GOVERNANCE.md`](GOVERNANCE.md) states what happens if the maintainer steps away, and
  how the maintainer list grows.

Growing this list is wanted, not merely tolerated. The path is in
[`GOVERNANCE.md`](GOVERNANCE.md#becoming-a-maintainer).

## Response expectations

These are intentions, not an SLA — a volunteer project that promises an SLA is lying:

| Kind | Aim |
|------|-----|
| Security report (private advisory) | acknowledge within 72 hours |
| Bug report | triage within 2 weeks |
| Pull request | first response within 2 weeks |

If something has gone quiet past these, a polite bump on the thread is welcome and is not
considered rude.
