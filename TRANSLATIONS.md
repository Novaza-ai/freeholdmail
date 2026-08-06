<!-- Last-touched: 2026-08-06 — licence and memory-safety corrections recorded; the Vietnamese row declared STALE; tracked-commit column explained. -->
# Translations

**English is the source of truth.** Every file in this repository is written in English, and
`README.md` is the version that governs. Translations are a courtesy for readers, never an
authority.

Available: [English](README.md) · [Tiếng Việt](docs/i18n/vi/README.md) · [日本語](docs/i18n/ja/README.md) · [简体中文](docs/i18n/zh-CN/README.md) · [繁體中文](docs/i18n/zh-TW/README.md) · [ไทย](docs/i18n/th/README.md) · [Bahasa Indonesia](docs/i18n/id/README.md) · [हिन्दी](docs/i18n/hi/README.md) · [Français](docs/i18n/fr/README.md) · [Español](docs/i18n/es/README.md) · [Português](docs/i18n/pt/README.md) · [Русский](docs/i18n/ru/README.md)

## The convention this repo follows

There is no official standard from GitHub for multilingual repositories, so this repo
follows the convention that large, well-maintained projects converged on, plus one actual
standard for the language codes.

| Rule | Choice here | Why |
|------|-------------|-----|
| Canonical language | English, `README.md` at the repo root | GitHub renders the root `README.md` as the project home page; it must be the one everybody can read |
| Filename pattern | `docs/i18n/<tag>/README.md` | Moved here at 12 languages, exactly as the note at the bottom of this file said to. `README.<tag>.md` at the root is more discoverable but stops scaling: eleven `README.*.md` files bury every other root document |
| Language codes | **BCP 47** ([RFC 5646](https://www.rfc-editor.org/rfc/rfc5646)) | The real standard. Use the bare subtag when the region does not matter (`vi`, `ja`, `de`), the regional form when it does (`zh-CN` vs `zh-TW`, `pt-BR` vs `pt-PT`) |
| Language selector | Full list on `README.md`; each translation links **back to English** | The stated goal is that a reader landing on a translation is one click from the authoritative text, and a back-link achieves it. Repeating a 12-item list in 12 files is the drift this section warns about — the root README is the one place it stays correct |
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

1. Copy `README.md` to `docs/i18n/<tag>/README.md` using the correct BCP 47 tag.
2. Translate prose only, following the rules above. Prefix every repo-root link with
   `../../../`, and leave inline `` `code` `` spans alone as well as fenced blocks.
3. Keep the first two lines: the `Last-touched` comment, then a selector line that links
   **back to English** and names your language. Add your language to the full selector in
   `README.md` and to the table below — those two are the only places the full list lives.
4. Add the file and its tag to the table in this document.
5. Open a PR. State which commit of `README.md` you translated — that is what a later
   reviewer needs to see how far the translation has drifted.

Translations are reviewed for accuracy against the English source, not for style. If you
believe the English is wrong, fix the English first: a translation must never quietly
correct the original.

## Current translations

| Language | Tag | File | Tracks (commit of `README.md`) |
|----------|-----|------|--------|
| English (source) | `en` | [`README.md`](README.md) | — |
| Vietnamese | `vi` | [`docs/i18n/vi/README.md`](docs/i18n/vi/README.md) | `1ed15b3` — **STALE** |
| Japanese | `ja` | [`docs/i18n/ja/README.md`](docs/i18n/ja/README.md) | `1ed15b3` — **STALE** |
| Chinese (Simplified) | `zh-CN` | [`docs/i18n/zh-CN/README.md`](docs/i18n/zh-CN/README.md) | `1ed15b3` — **STALE** |
| Chinese (Traditional) | `zh-TW` | [`docs/i18n/zh-TW/README.md`](docs/i18n/zh-TW/README.md) | `1ed15b3` — **STALE** |
| Thai | `th` | [`docs/i18n/th/README.md`](docs/i18n/th/README.md) | `1ed15b3` — **STALE** |
| Indonesian | `id` | [`docs/i18n/id/README.md`](docs/i18n/id/README.md) | `1ed15b3` — **STALE** |
| Hindi | `hi` | [`docs/i18n/hi/README.md`](docs/i18n/hi/README.md) | `1ed15b3` — **STALE** |
| French | `fr` | [`docs/i18n/fr/README.md`](docs/i18n/fr/README.md) | `1ed15b3` — **STALE** |
| Spanish | `es` | [`docs/i18n/es/README.md`](docs/i18n/es/README.md) | `1ed15b3` — **STALE** |
| Portuguese | `pt` | [`docs/i18n/pt/README.md`](docs/i18n/pt/README.md) | `1ed15b3` — **STALE** |
| Russian | `ru` | [`docs/i18n/ru/README.md`](docs/i18n/ru/README.md) | `1ed15b3` — **STALE** |

**On regional tags.** `zh-CN` and `zh-TW` are kept apart because the scripts and the
vocabulary genuinely differ. `es` and `pt` are deliberately *not* split into `es-ES`/`es-MX`
or `pt-PT`/`pt-BR`: for technical prose of this kind the regional differences are small, and
one well-maintained file beats two that drift. Split them the day a reader shows a passage
that actually misleads.

### Known stale, stated rather than hidden

**All eleven translations are behind the English right now**, and every row above says so.

**Two claims that were wrong in every language have been corrected in all eleven:**

- **The licence list.** Each named three of the five programs this stack deploys. **nginx**
  (BSD-2-Clause) and **PostgreSQL** were absent, and Stalwart was flattened to a bare
  `AGPL-3.0` where it is dual `AGPL-3.0-only OR SELv1`. Stating component licences
  incompletely on a public repo is a legal accuracy problem.
- **"Memory-safe".** Every translation described the whole stack that way. The English was
  corrected to say what is actually true — the mail server and webmail are memory-safe
  languages, nginx and PostgreSQL are C — and the correction had reached none of the eleven.
  This describes the security properties of the software, so it was corrected in the same pass.

**What is still behind**, and is genuinely prose: ten of the eleven do not name the
**Agentic Mail** milestone in the roadmap line (`vi` does), and all eleven carry the older,
shorter note about GitHub's contributor graph. Correcting PRs are welcome.

**Do not read the tracked-commit column as proof of fidelity.** It records the commit a
translation was filed against, not a verified match. Measured: `README.md` already named
Agentic Mail at `1ed15b3`, yet ten of the rows recording `1ed15b3` never carried it — so for
those ten the column was optimistic from the day it was written. The `STALE` markers are the
honest signal; the column is a starting point for whoever re-translates.

Two things let the licence gap hide longer than it should have. The Vietnamese row was stale
and did **not** carry a `STALE` marker, and the guard meant to catch that read the file as a
whole: it found the one undeclared row, then saw the word `STALE` elsewhere in the table and
passed. `tests/test_config.sh` now judges **each row on its own** — a row whose tracked commit
is behind `README.md` must carry its own marker, no other row's honesty can cover for it, an
unreachable or malformed commit fails loudly instead of exempting the row, and a table with
fewer than eleven translation rows fails rather than passing because there was nothing left
to check.

**These translations have not been reviewed by native speakers.** They were produced against
the English source and checked for structure, not for idiom. If you speak one of these
languages and something reads wrong, a correcting PR is genuinely welcome — that is the fastest
path from "machine-accurate" to "actually good".

## If this grows

The move to `docs/i18n/<tag>/` happened at 12 languages. The rest of that original advice
still stands and is now the live problem: **hand-maintained translations drift silently.**
Keeping eleven files in step with the English by hand has not worked so far.

The next step, before adding a thirteenth language, is a translation platform —
[Weblate](https://weblate.org/) or [Crowdin](https://crowdin.com/), both free for open-source
projects and both able to open PRs automatically. Do not build a custom pipeline for this.

Until that lands, `tests/test_config.sh` enforces the mechanical half: every language
advertised in the selector must exist on disk, and every translated file must carry the
"English wins" banner. It cannot check whether a translation is *correct* — only a reader can.
