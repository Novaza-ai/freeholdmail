#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-08-13 — new: the shipped .env.example no longer resolves to a runnable
# compose config, on purpose, so anything that only wants to LINT the config needs an env
# where the required values are present but obviously fake.
#
# Why this exists at all: docker-compose.yml marks its secrets required with ${VAR:?...}, so
# `docker compose --env-file .env.example config` now fails — which is the point (an operator
# who copies the example instead of running install.sh must be stopped, not silently given an
# empty session key). Linting the file's SHAPE is a different question from whether an
# operator has real secrets, and it still has to be possible.
#
# The required list is READ FROM the compose files rather than restated here. Add a new
# ${NEW_SECRET:?...} to a service and this script covers it on the next run, with nothing to
# remember. A hand-maintained list is how the two gates drift apart.
#
# Usage:  tests/lint_env.sh <output-path>
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dst="${1:?usage: lint_env.sh <output-path>}"

# Deliberately not a plausible secret: this value must never look like something to reuse,
# and it must not trip the "no committed secrets" scan if it is ever pasted somewhere.
filler='lint-only-do-not-use'

# Comment lines are stripped first: a header that explains the ${VAR:?} form in prose would
# otherwise be read as a variable literally named VAR.
mapfile -t required < <(
  grep -hv '^[[:space:]]*#' "$REPO_DIR/docker-compose.yml" "$REPO_DIR/docker-compose.sso.yml" \
    | grep -oE '\$\{[A-Z_]+:\?' | sed 's/^\${//; s/:?$//' | sort -u
)
if [[ "${#required[@]}" -eq 0 ]]; then
  echo "lint_env.sh: no required variables found in the compose files — refusing to" >&2
  echo "write an env that would make a broken compose file look valid." >&2
  exit 2
fi

cp "$REPO_DIR/.env.example" "$dst"
for var in "${required[@]}"; do
  # Only fill it when the example ships it empty; never overwrite a real value.
  sed -i "s|^${var}=$|${var}=${filler}|" "$dst"
done
