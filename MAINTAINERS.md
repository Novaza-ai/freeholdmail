<!-- Last-touched: 2026-08-06 — the company address is now a verified email, so all fifteen
     older commits are credited; measured block updated to match. -->
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

## Who a commit is credited to, and how to appear in the Contributors list

**Commits are authored by the person who made them.** Each maintainer sets `user.name` and
`user.email` to their own details, using an address verified on their GitHub account.
Copyright is separate and does not change: [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE) name
**Novaza Solution JSC**.

Earlier commits were made under the company identity, `Novaza Solution JSC
<admin@novaza.ai>`. For a while that address was verified on no GitHub account, so those
commits were credited to nobody and `dependabot` was the only name under
**Insights → Contributors**. Adding the address to a maintainer's verified emails fixed it
for all fifteen at once, with no change to the commits themselves. They are published, and
rewriting them was never on the table.

The mechanism is worth knowing before you contribute, because the same thing can happen to
your own commits.

**How GitHub decides who wrote a commit.** Git stores an author *name and email* in every
commit — that is all. GitHub then looks up that **email address** among the verified emails
on user accounts. If it finds one, the commit is credited to that account and the person
appears in Contributors. If it finds none, the commit still exists and still shows the name,
but it belongs to no account, so it counts toward nobody.

**What that means here, measured rather than assumed:**

```bash
# Two author identities in the history: the company on older commits, a person on newer ones
$ git log --format='%an <%ae>' | sort | uniq -c
      4 Daika Ginza <54053998+daikaginza@users.noreply.github.com>
     15 Novaza Solution JSC <admin@novaza.ai>
      3 dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>

# Both addresses now resolve, so every commit is credited: 19 + 3 = 22, the whole history
$ gh api repos/Novaza-ai/freeholdmail/contributors --jq '.[] | "\(.login) \(.contributions)"'
daikaginza 19
dependabot[bot] 3

# Including commits written long before the address was verified
$ gh api repos/Novaza-ai/freeholdmail/commits/ae4de00 --jq .author.login
daikaginza
```

Verifying the address did that; the commits were not touched. Note that
`gh api "search/users?q=admin@novaza.ai+in:email"` still returns `0` — user search only
indexes addresses set to **public**, and a verified address can stay private. Verified is
what attribution needs; public is not.

**Making an organisation membership public does not affect this.** That setting lists a
member at `github.com/orgs/Novaza-ai/people`. The Contributors graph on a repository is
built only from commit author emails, so publishing a membership does not add anyone to it.

**If you contribute, do this** — it takes one minute and it is the only thing that makes
GitHub credit you:

```bash
git config user.name  "Your Name"
git config user.email "the-email-verified-on-your-github-account"
git commit --amend --reset-author   # if you already committed with the wrong one
```

Check the address first at **GitHub → Settings → Emails**. GitHub's `@users.noreply.github.com`
address works and keeps your real address private.

**What this project does, and what is left over:**

| Option | What it does | Status here |
|--------|--------------|-------------|
| Each person commits under their own identity | Correct attribution from here on | **Adopted.** The repository no longer has a single author line |
| Add `admin@novaza.ai` as a **verified email** on a GitHub account (Settings → Emails) | Credits the **15 older commits** to that account | **Done.** One setting, and the only option that reaches commits already published |
| Add a `Co-authored-by:` trailer | Credits an additional person on one commit | Used when two people worked on the same change |

None of these rewrite history. The commits made under the company identity are left as they
are, because other people have already cloned them.

## The honest bus factor

**One person can merge.** That is a real risk to you if you are deciding whether to run this
in production, so it is stated here rather than left to be discovered:

- A single person can be unavailable, and there is no second reviewer to merge in the
  meantime.
- The project is MIT-licensed and the stack it assembles is upstream software under its own
  licences. If this repository stopped being maintained tomorrow, your running installation
  would keep working, and anyone could fork it without asking permission. That is the
  intended safety net for this risk.
- [`GOVERNANCE.md`](GOVERNANCE.md) states what happens if the maintainer steps away, and
  how the maintainer list grows.

We want to add maintainers. The path is in
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
