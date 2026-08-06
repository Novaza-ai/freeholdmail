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

## Why GitHub's Contributors list is empty, and how to appear in it

If you look at **Insights → Contributors**, or at the avatars GitHub shows on the repository
home page, you will see `dependabot` and nobody else. That is not a statement about who did
the work. It is a mechanical consequence of how GitHub attributes commits, and it is worth
understanding before you contribute, because the same thing can happen to you.

**How GitHub decides who wrote a commit.** Git stores an author *name and email* in every
commit — that is all. GitHub then looks up that **email address** among the verified emails
on user accounts. If it finds one, the commit is credited to that account and the person
appears in Contributors. If it finds none, the commit still exists and still shows the name,
but it belongs to no account, so it counts toward nobody.

**What that means here, measured rather than assumed:**

```bash
# Every human commit is authored by the company identity
$ git log --format='%an <%ae>' | sort | uniq -c
     14 Novaza Solution JSC <admin@novaza.ai>
      3 dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>

# That address is not a verified email on any GitHub account
$ gh api "search/users?q=admin@novaza.ai+in:email" --jq .total_count
0

# So the Contributors API returns only the bot
$ gh api repos/Novaza-ai/freeholdmail/contributors --jq '.[].login'
dependabot[bot]
```

We chose the company identity deliberately, so that the copyright line, the `NOTICE` file and
the commit author all say the same thing. The cost is this: the humans are invisible in
GitHub's own UI. Naming them in this file is the fix for readers; the fixes below are for the
graph.

**If you contribute, do this** — it takes one minute and it is the only thing that makes
GitHub credit you:

```bash
git config user.name  "Your Name"
git config user.email "the-email-verified-on-your-github-account"
git commit --amend --reset-author   # if you already committed with the wrong one
```

Check the address first at **GitHub → Settings → Emails**. GitHub's `@users.noreply.github.com`
address works and keeps your real address private.

**For the maintainers, three ways to fix it, in increasing order of disruption:**

| Option | What it does | Cost |
|--------|--------------|------|
| Add `admin@novaza.ai` as a **verified email** on a GitHub account (Settings → Emails) | Retroactively credits **all 14 existing commits** to that account | One click, no history rewrite. **This is the recommended one.** |
| Add a `Co-authored-by:` trailer to future commits | Credits a second person per commit, going forward only | One line per commit, nothing retroactive |
| Have each person commit under their own identity | Correct attribution from here on | Loses the single company author line |

Nothing above rewrites history, and none of it is required for the project to function — an
empty Contributors list is cosmetic. It is documented because a reader who sees one bot and
no humans reasonably concludes the project is abandoned, and that conclusion would be wrong.

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
