<!-- Last-touched: 2026-08-07 — the approval rule now matches what a one-person project can
     actually enforce, and names what IS enforced on main. -->
# Governance

This project is small and openly says so. This document exists because the question
"who decides, and what happens if the company behind it moves on?" deserves an answer
before you depend on the answer.

## The model

**Company-stewarded, single maintainer.** Novaza Solution JSC sponsors the work and
[`MAINTAINERS.md`](MAINTAINERS.md) names who holds the merge button. There is no committee,
no voting, and pretending otherwise would be theatre at this size.

The maintainer decides scope and releases. In exchange, the maintainer owes contributors a
reason for a "no" — a rejected pull request should come with the reasoning, not just a
close.

## How decisions are made

1. **Ordinary changes** — open a pull request. It needs **green CI**, and **one maintainer
   approval once there is a second maintainer to give it**. See
   [`CONTRIBUTING.md`](CONTRIBUTING.md).

   That second clause is not a loophole, it is the honest state of a one-person project.
   Requiring an approval nobody can give would stop the project, and pretending the rule is
   enforced when it cannot be is worse than saying so. What *is* enforced today, on `main`
   and on administrators too:

   - every change arrives as a pull request — direct pushes are refused;
   - all five CI checks must pass before merge;
   - CodeQL, `shellcheck`, `yamllint` and the 191-check static suite run on the pull
     request, not after the fact.

   Between 2026-08-05 and 2026-08-07 this document said approval was required while every
   commit went straight to `main`. That gap is closed by making the enforceable part real
   and stating the rest plainly, rather than by leaving an aspiration in a governing
   document. When `MAINTAINERS.md` lists two people, required approval turns on and this
   paragraph goes.
2. **Changes to scope, security posture, or licensing** — open an issue first and let it
   sit long enough for objections. These are the changes that are expensive to reverse
   after a release.
3. **Disagreement** — argue it in the issue with evidence. This project's standard is that
   a claim needs a measurement (`CONTRIBUTING.md` §"Ground rule"), and that applies to
   design arguments too: "it feels faster" loses to a number.

## What is deliberately out of scope

Saying no is part of governance. This repository is **orchestration only**: configuration,
installer, docs and tests. It does not carry the source of the mail server or the webmail,
and it never will — copying AGPL source in here would change the licensing of the whole
project. Fixes to those components belong upstream. See
[`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md).

## Becoming a maintainer

There is no quota and no waiting period. The bar is a track record: a handful of merged
pull requests, review comments that catch real problems, and judgement about what *not* to
build. If that describes your contributions, open an issue and say you are interested —
asking is not presumptuous here, it is the documented path.

New maintainers get commit rights and are added to [`MAINTAINERS.md`](MAINTAINERS.md) and
`.github/CODEOWNERS`.

## If the project is abandoned

A promise that costs nothing to make is worth stating plainly:

- The MIT licence on this repository is irrevocable for the code already released. Nobody
  can take back what you already have.
- Your running installation does not depend on this repository staying alive — it runs
  upstream images that are published independently.
- If the maintainer becomes unavailable for **six months** with issues going unanswered,
  treat the project as unmaintained and fork it. No permission is required and none will
  be demanded retroactively. A fork that is doing the work is welcome to say so in an
  issue here, and it will be linked from the README rather than competed with.
- If the sponsoring company ever decides to stop, the intent is to archive the repository
  with a pointer to the most active fork, not to delete it. Deleting a repository that
  people depend on is a hostile act and is ruled out here in advance.
