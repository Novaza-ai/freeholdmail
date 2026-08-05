<!-- Last-touched: 2026-08-05 — named the team behind the org rather than only the legal
     entity, and recorded why the GitHub contributor graph does not yet show them. -->
# Maintainers and team

Who to expect a reply from, who can merge, and who is behind this.

## Project lead

**Daika Ginza** — [@daikaginza](https://github.com/daikaginza) ·
[Substack](https://substack.com/@daikaginza) ·
[LinkedIn](https://www.linkedin.com/in/daikaginza/)

Sets direction and scope, owns releases and security response, and has the final say when a
decision has to be made. Writing on the thinking behind this and related work is on the
Substack.

## Team

| Person | GitHub | Role here |
|--------|--------|-----------|
| Daika Ginza | [@daikaginza](https://github.com/daikaginza) | Project lead · maintainer · releases · security response |
| [@anhkk1245](https://github.com/anhkk1245) | [@anhkk1245](https://github.com/anhkk1245) | Team member |

The project is stewarded by **[Novaza Solution JSC](https://novaza.ai)**, which runs this
stack's components (Stalwart and Bulwark) in production for its own mail.

Contact: `admin@novaza.ai`. For anything with a security dimension use the private advisory
flow instead — see [`SECURITY.md`](SECURITY.md). Never report a vulnerability in a public
issue.

## Why GitHub's contributor graph does not show us yet

Worth stating plainly, because it looks like nobody works on this: every commit so far is
authored as `Novaza Solution JSC <admin@novaza.ai>`, a company identity that is not linked
to any GitHub account. GitHub attributes commits by email, so its contributor list currently
shows only `dependabot`. That is an artefact of how we sign commits, not a measure of who
did the work.

If you contribute, commit under **your own** name and email so the graph credits you. There
are two ways for team members to get the same:

```bash
# 1. Add admin@novaza.ai as a verified email on a GitHub account, or
# 2. Co-author, which credits a second person on a commit authored by the company identity:
git commit -m "…" -m "Co-authored-by: Name <email@example.com>"
```

## The honest bus factor

**One person can merge.** That is a real risk to you if you are deciding whether to run this
in production, so it is stated here rather than left to be discovered:

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
