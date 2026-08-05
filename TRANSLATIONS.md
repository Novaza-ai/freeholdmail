<!-- Last-touched: 2026-08-04 — translation policy for the public repo. -->
# Translations

**English is the source of truth.** Every file in this repository is written in English, and
`README.md` is the version that governs. Translations are a courtesy for readers, never an
authority.

Available: [English](README.md) · [Tiếng Việt](README.vi.md)

## The convention this repo follows

There is no official standard from GitHub for multilingual repositories, so this repo
follows the convention that large, well-maintained projects converged on, plus one actual
standard for the language codes.

| Rule | Choice here | Why |
|------|-------------|-----|
| Canonical language | English, `README.md` at the repo root | GitHub renders the root `README.md` as the project home page; it must be the one everybody can read |
| Filename pattern | `README.<tag>.md` at the repo root | Most discoverable. The alternative, `docs/i18n/<tag>/README.md`, keeps the root cleaner and is worth switching to past ~4 languages |
| Language codes | **BCP 47** ([RFC 5646](https://www.rfc-editor.org/rfc/rfc5646)) | The real standard. Use the bare subtag when the region does not matter (`vi`, `ja`, `de`), the regional form when it does (`zh-CN` vs `zh-TW`, `pt-BR` vs `pt-PT`) |
| Language selector | First line of every version, linking all versions | A reader who lands on a translation must be one click from the authoritative text |
| Staleness | Translations may lag; English wins on any conflict | Stated on every translated file so nobody acts on an outdated instruction |

## What gets translated, and what must not

**Translate:** prose, headings, table cell text, explanatory comments in the document.

**Never translate:**

- commands, code blocks, file names, paths, environment variable names;
- error strings we quote (`550 5.1.2 Relay not allowed.` is what the server actually
  prints — a translated version would be unsearchable);
- badge URLs and link targets;
- `LICENSE`, `NOTICE`, `SECURITY.md`, `CHANGELOG.md`. Legal and security text is
  authoritative in English only; a mistranslated security instruction is a vulnerability,
  and a translated licence has no legal standing.

Keep the heading structure identical to the English file. It makes drift visible and lets
readers cross-reference by section.

## Contributing a translation

1. Copy `README.md` to `README.<tag>.md` using the correct BCP 47 tag.
2. Translate prose only, following the rules above.
3. Keep the language selector line at the top, and add your language to it in **every**
   existing translated file plus `README.md`.
4. Add the file and its tag to the table in this document.
5. Open a PR. State which commit of `README.md` you translated — that is what a later
   reviewer needs to see how far the translation has drifted.

Translations are reviewed for accuracy against the English source, not for style. If you
believe the English is wrong, fix the English first: a translation must never quietly
correct the original.

## Current translations

| Language | Tag | File | Tracks |
|----------|-----|------|--------|
| English (source) | `en` | [`README.md`](README.md) | — |
| Vietnamese | `vi` | [`README.vi.md`](README.vi.md) | initial translation, 2026-08-04 |

## If this grows

Past roughly four languages, hand-maintained files stop working: they drift silently and
nobody notices. At that point move to `docs/i18n/<tag>/` and adopt a translation platform
such as [Weblate](https://weblate.org/) or [Crowdin](https://crowdin.com/), both of which
have free tiers for open-source projects and can open PRs automatically. Do not build a
custom pipeline for this.
