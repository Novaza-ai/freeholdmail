<!-- Last-touched: 2026-08-05 — post-publication checklist; several items are repo settings
     that can only be switched on in the GitHub UI, not from this repository. -->
# Publishing checklist

Everything in this repo can be verified from a clone. The items below cannot — they are
either GitHub repository settings or third-party programs that only apply once the repo is
public. Work through them in order after the first push.

## 1. GitHub features, free for public repositories

| Feature | Where | Why it matters here |
|---------|-------|---------------------|
| **Secret scanning** | Settings → Code security | On by default for public repos. Scans history and new pushes for known credential formats and notifies the issuing provider. |
| **Push protection** | Settings → Code security | Blocks a push that contains a recognised secret *before* it lands. This is the single most valuable setting for a project whose runbook has operators handling `.env` files. |
| **Private vulnerability reporting** | Settings → Code security | Gives researchers a private channel. `SECURITY.md` already tells them to use it, so it must actually be enabled. |
| **Dependabot** | `.github/dependabot.yml` (already in repo) | Actions are pinned to commit SHAs; Dependabot is what keeps those pins from going stale. |
| **CodeQL / code scanning** | Settings → Code security | Limited value here — there is no application code — but the `actions` analysis catches workflow issues. Enable it and see. |
| **Branch protection on `main`** | Settings → Rules | Require the `static` and `e2e` checks to pass, require review, block force-push. OpenSSF Scorecard scores this directly. |

## 2. OpenSSF programs

Two different things, often confused:

- **[OpenSSF Scorecard](https://scorecard.dev/)** — *automated*. `.github/workflows/scorecard.yml`
  is already committed; it runs weekly and on pushes to `main`, publishes results to the
  Security tab, and makes the badge resolvable. Nothing is self-reported: the score comes
  from an external analysis of the repo, which is exactly why it is worth having.
  Add the badge to `README.md` once the org and repo name are final:
  ```
  [![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/Novaza-ai/freeholdmail/badge)](https://scorecard.dev/viewer/?uri=github.com/Novaza-ai/freeholdmail)
  ```
- **[OpenSSF Best Practices Badge](https://www.bestpractices.dev/)** — *self-certified*, free,
  a questionnaire covering licensing, documentation, reporting, quality, security and
  analysis, with passing / silver / gold levels. Most of the passing criteria are already
  satisfied by this repo (`LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, a
  public test suite, a stated release process). Because it is self-asserted it carries less
  weight than Scorecard — do it second, and do not treat it as a security audit.

Neither is a security audit. They measure *process*, not whether the code is correct.
Nothing on this list replaces the measurements in `tests/`.

## 3. What is deliberately not claimed

- **No third-party security audit has been performed.** If we ever commission one, the
  report goes in this repo, findings and all.
- **No SLSA provenance or signed release artifacts.** This repo ships no binaries; it
  assembles published images. If we ever publish an artifact, sign it and attest it then —
  not before.
- Do not add a badge for anything that has not actually run. A badge that links to nothing
  is worse than no badge.

## 4. Order of operations

1. `git init`, first commit, push to the org.
2. Turn on the Settings items in §1 — push protection first.
3. Let the Scorecard workflow run once, read the results, fix what it flags.
4. Add the Scorecard badge only after it resolves.
5. Then, optionally, the Best Practices questionnaire.
