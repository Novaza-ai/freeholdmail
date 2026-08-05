#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-08-05 — assembles captured tour frames into the README GIF.
#
# Frames come from scripts/capture_tour.mjs. ImageMagick is the only dependency; ffmpeg
# is not needed for a slideshow-style GIF and produces a larger file for this content.
#
# Usage:
#   scripts/make_gif.sh [frames_dir] [output.gif]
set -euo pipefail

readonly FRAMES="${1:-docs/media/frames}"
readonly OUTPUT="${2:-docs/media/tour.gif}"
# 1000px keeps captions legible on GitHub without shipping a multi-megabyte asset.
readonly WIDTH="${GIF_WIDTH:-1000}"
# Hundredths of a second. Each frame carries a sentence, so it needs reading time.
readonly DELAY="${GIF_DELAY:-260}"

err() { printf '%s\n' "$*" >&2; }

command -v convert >/dev/null || { err "❌ ImageMagick (convert) not found"; exit 1; }

shopt -s nullglob
frames=("${FRAMES}"/*.png)
shopt -u nullglob
if (( ${#frames[@]} == 0 )); then
  err "❌ no PNG frames in ${FRAMES} — run scripts/capture_tour.mjs first"
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT}")"

# -layers Optimize rewrites each frame as a diff against the previous one, which matters
# here because consecutive tour steps differ only in the callout.
convert -delay "${DELAY}" -loop 0 "${frames[@]}" \
        -resize "${WIDTH}" -layers Optimize "${OUTPUT}"

# The last frame lingers so the GIF does not snap back the instant it ends.
convert "${OUTPUT}" \( -clone -1 -set delay 400 \) -delete -2 "${OUTPUT}"

printf 'Wrote %s (%s frames, %s)\n' \
  "${OUTPUT}" "${#frames[@]}" "$(du -h "${OUTPUT}" | cut -f1)"
