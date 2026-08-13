<!-- Last-touched: 2026-08-13 — brand assets added, and the "nothing here is a mockup" claim
     narrowed to the screenshots it was always about. The logo is artwork, not a capture. -->
# Media, and how to regenerate it

Two kinds of image live here, and they are held to different standards.

**Screenshots** are captures of this stack actually running, taken by a script in `scripts/`.
None of them is a mockup, and none is borrowed from an upstream project's marketing. If a
screenshot ever stops matching reality, regenerate it — do not retouch it.

**Brand assets** are artwork. They depict nothing, so there is nothing for them to misrepresent.

| File | What it is | Produced by |
|------|------------|-------------|
| `inbox.png` | The mailbox after `scripts/seed_demo.py`, 1200 px wide | `scripts/capture_tour.mjs` (frame `00-inbox`) |
| `tour.gif` | The in-product tour, one frame per step, 1000 px wide | `scripts/capture_tour.mjs` → `scripts/make_gif.sh` |
| `logo.png` | Horizontal lockup, transparent, 1015×348 | Brand artwork — see below |
| `logo-dark.png` | The same lockup, lightened for dark backgrounds | Derived from `logo.png` |
| `icon.png` | The shield mark alone, square, 512×512 | Cropped from `logo.png` |

## The brand assets

The lockup was extracted from the supplied brand artwork, which arrived as a presentation
mockup — the logo printed on textured paper, with a drop shadow, a vignette and ghosted
watermarks in the corners. None of that belongs in a README, so the mark and wordmark were
isolated onto transparency and everything the mockup added was removed.

`logo-dark.png` exists because the wordmark is navy: on a dark background it recedes into the
page. It is the same artwork with a lightness lift weighted by how dark each pixel is, so the
teal and orange of the mark survive untouched while the navy comes up to a readable blue. The
READMEs select between them with `<picture media="(prefers-color-scheme: dark)">`, which GitHub
honours.

All three are stripped of metadata. The source artwork carried C2PA content credentials; those
are provenance for the artwork, not for this repository, and shipping them would publish a
record nobody reading this needs.

**These files are not covered by the MIT licence** — see `NOTICE`. The code is yours to reuse;
the identity is not.

`docs/media/frames/` holds the intermediate PNGs and is gitignored: the scripts regenerate
them, so there is no reason to carry ~2 MB of duplicates in history.

## Regenerating

```bash
# 1. a stack to photograph — a throwaway one, never a real deployment
docker compose --env-file .env up -d

# 2. content, so the screenshots are not of an empty mailbox
FREEHOLD_ADMIN_SECRET="$(grep '^STALWART_FALLBACK_ADMIN_SECRET=' .env | cut -d= -f2-)" \
  scripts/seed_demo.py          # prints the demo password it generated

# 3. frames, then the GIF
npm i playwright && npx playwright install chromium
FREEHOLD_URL=https://your-demo-host FREEHOLD_USER=ana@freehold.demo \
FREEHOLD_PASSWORD='<the password seed_demo.py printed>' node scripts/capture_tour.mjs
scripts/make_gif.sh
```

## The tour is the product's own

The steps come from the webmail's built-in tour, not from a storyboard we invented:
`components/tour/tour-steps.ts` upstream defines them, each anchored to a `data-tour`
attribute in the interface. `scripts/capture_tour.mjs` starts that tour and advances it
with `ArrowRight`, which the overlay handles natively — no button labels are matched, so
the script does not break when the interface language changes.

The overlay numbers its own steps ("Step 2 of 9"), which is a useful cross-check: if the
capture produces a different number of frames than the overlay reports, something was
skipped and the GIF should not be published.

## The storyboard

| # | Tour step id | Anchor | What the viewer learns |
|---|--------------|--------|------------------------|
| 0 | — | — | The mailbox, with real messages, before anything is explained |
| 1 | `sidebar` | `[data-tour="sidebar"]` | Where folders, tags and accounts live |
| 2 | `compose` | `[data-tour="compose-button"]` | Writing mail, attachments, rich text |
| 3 | `search` | `[data-tour="search-input"]` | Search across the mailbox |
| 4 | `email-list` | `[data-tour="email-list"]` | The message list and its density |
| 5 | `email-viewer` | `[data-tour="email-viewer"]` | The reading pane — the tour opens a message itself |
| 6 | `keywords` | `[data-tour="keyword-tags"]` | Tagging and colour-coding |
| 7 | `nav-contacts` | `[data-tour="nav-contacts"]` | Contacts |
| 8 | `nav-settings` | `[data-tour="nav-settings"]` | Settings |
| 9 | `shortcuts` | `[data-tour="nav-shortcuts"]` | Keyboard shortcuts |

`nav-calendar` is defined upstream but filtered out when the backend does not advertise
calendar support, which is why the capture shows nine steps rather than ten. Enabling
`DEMO_MODE` adds nine further steps (composer, calendar view, event modal, contacts list,
settings tabs, files, quota); those are deliberately **not** in the README GIF, because they
showcase the webmail's own sample data rather than a real deployment.
