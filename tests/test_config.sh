#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-08-13 — four guards added for defects an audit found, each of which had
# been claimed somewhere and asserted nowhere: the shipped .env.example must not resolve to a
# runnable config; only JMAP may reach the mail server through nginx; every workflow must
# parse, not just ci.yml; the SBOM must describe every pinned image.
# Before that, 2026-08-07 — new guard: install.sh image defaults must match .env.example.
# Also: per-row staleness guard, repaired SHA guard, secret scan limited to tracked files.
#
# Fast (seconds, no images pulled). Run this before every commit; CI runs it on every push.
# For the checks that need a running stack, see tests/test_e2e.sh.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR" || { echo "cannot enter $REPO_DIR" >&2; exit 1; }

PASS=0
FAIL=0
SKIP=0

ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS + 1)); }
# A skipped check must be counted, not just printed. A suite that reports "all green"
# while silently skipping is worse than one that fails: it teaches you to trust it.
skip() { printf '  \033[33mSKIP\033[0m  %s\n' "$1" >&2; SKIP=$((SKIP + 1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
check() { # check <description> <command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}
refute() { # refute <description> <command...>  — passes when the command FAILS
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then bad "$desc"; else ok "$desc"; fi
}
# Some checks can only be answered inside a git checkout of THIS repository: a tarball
# export has no history, and a copy vendored inside another repo would answer with the
# parent's history instead of its own. Comparing the toplevel to REPO_DIR rules out both.
# Skipping is the honest outcome there — a skip is counted and exits non-zero, whereas a
# vacuous pass would report a green board over checks that never ran.
in_this_git_repo() {
  [[ "$(git rev-parse --show-toplevel 2>/dev/null)" == "$REPO_DIR" ]]
}

echo "== syntax =="
check "install.sh parses" bash -n install.sh
check "tests/test_e2e.sh parses" bash -n tests/test_e2e.sh
# ast.parse rather than py_compile: py_compile writes a __pycache__ directory into the
# repo, so the test would dirty the tree it is checking.
check "e2e_mail.py parses" \
  python3 -c "import ast; ast.parse(open('tests/e2e_mail.py').read())"
# A workflow that does not parse never runs, so CI would go silently green-by-absence. Every
# workflow, not just ci.yml: this named one file, so the three added since were unchecked —
# the same shrinking-list failure the Python lint step already had to be fixed for.
check "every workflow is valid YAML" \
  python3 -c "
import glob, sys, yaml
files = sorted(glob.glob('.github/workflows/*.yml'))
sys.exit(1) if not files else [yaml.safe_load(open(f)) for f in files]"
if command -v shellcheck >/dev/null 2>&1; then
  check "shellcheck install.sh" shellcheck install.sh
  check "shellcheck tests/*.sh" \
    shellcheck tests/test_config.sh tests/test_e2e.sh tests/lint_env.sh
else
  skip "shellcheck install.sh (shellcheck not installed)"
  skip "shellcheck tests/*.sh (shellcheck not installed)"
fi
if command -v yamllint >/dev/null 2>&1; then
  check "yamllint" yamllint -d '{extends: relaxed, rules: {line-length: {max: 120}}}' .
else
  skip "yamllint (yamllint not installed)"
fi

echo "== compose =="
# Everything below lints the SHAPE of the compose files, which must not require real secrets.
# Since the services now mark their secrets required (${VAR:?...}), .env.example alone no
# longer resolves — deliberately — so linting needs an env with those filled in. The list of
# what to fill is read out of the compose files by tests/lint_env.sh, never restated.
LINT_ENV="$(mktemp)"
trap 'rm -f "$LINT_ENV"' EXIT
if ! tests/lint_env.sh "$LINT_ENV" 2>/dev/null; then
  bad "could not build the lint env (tests/lint_env.sh) — the compose checks did NOT run"
fi

# The defect this pins down: `cp .env.example .env` (which CONTRIBUTING.md documents) used to
# produce a stack with an EMPTY session key and an EMPTY admin secret, and compose resolved it
# without a word. Measured 2026-08-13: the webmail then starts and serves traffic, so nothing
# downstream catches it either. The shipped example must not be startable.
refute "the shipped .env.example alone cannot resolve a runnable config" \
  docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.sso.yml config -q

# A variable marked required in compose but shipped with a VALUE in .env.example would satisfy
# the guard above while handing every operator the same published secret — worse than empty.
# shellcheck disable=SC2317  # both helpers run indirectly, through check()
required_compose_vars() {
  # Comment lines first, or a header that mentions the ${VAR:?} form in prose is read as a
  # variable named VAR. That is not hypothetical: it is how this check first went red.
  grep -hv '^[[:space:]]*#' docker-compose.yml docker-compose.sso.yml \
    | grep -oE '\$\{[A-Z_]+:\?' | sed 's/^\${//; s/:?$//' | sort -u
}
# shellcheck disable=SC2317  # runs indirectly, through check()
every_required_var_ships_empty() {
  local v missing=0
  while read -r v; do
    grep -qE "^${v}=$" .env.example || { echo "not shipped empty: $v"; missing=1; }
  done < <(required_compose_vars)
  return "$missing"
}
check "every required compose secret ships empty in .env.example" every_required_var_ships_empty

check "base edition validates" \
  docker compose --env-file "$LINT_ENV" -f docker-compose.yml config -q
check "SSO edition validates" \
  docker compose --env-file "$LINT_ENV" -f docker-compose.yml -f docker-compose.sso.yml config -q

# The SSO edition once pointed KC_DB_URL at a `db` host that no service defined, so it
# could never start. Assert the service exists rather than trusting the file to look right.
services="$(docker compose --env-file "$LINT_ENV" -f docker-compose.yml -f docker-compose.sso.yml config --services 2>/dev/null | sort | tr '\n' ' ')"
if [[ "$services" == *"db"* && "$services" == *"idp"* ]]; then
  ok "SSO edition defines db and idp (got: ${services% })"
else
  bad "SSO edition missing db and/or idp (got: ${services% })"
fi

# The mail server exits(1) in a restart loop when any storage mapping is missing.
for key in 'storage' 'store\.' 'directory\.'; do
  check "stalwart config declares [$key]" grep -qE "^\[$key" config/stalwart/config.toml.example
done
for k in data fts blob lookup directory; do
  check "storage.$k is mapped" grep -qE "^${k}[[:space:]]*=" config/stalwart/config.toml.example
done
# Published ports with no listener behind them are dead ends; 587 was one.
for port in 25 465 587 993 8080; do
  check "a listener binds :$port" grep -qE "bind = \[\"\[::\]:$port\"\]" config/stalwart/config.toml.example
done

echo "== secrets and placeholders =="
refute "no placeholder values in config files" \
  grep -rqE '=[A-Za-z_]*CHANGEME' .env.example install.sh docker-compose.yml docker-compose.sso.yml config/
refute "no publishing markers left" \
  grep -rq 'SET-BEFORE-PUBLISHING' NOTICE LICENSE README.md
# "Committed" has to mean committed. This scanned the whole working tree, so a correct
# install failed it: install.sh writes .env at mode 600, .gitignore covers it, it is never
# committed — and the check still called it a leaked secret. Reporting a leak on a secure
# system is not a harmless false alarm; it teaches operators to ignore the suite, or to
# delete the file it is complaining about. git grep searches tracked files only, so an
# untracked .env is invisible while a secret pasted into a tracked file is still caught.
# The tradeoff: an untracked file that is not gitignored is no longer scanned either. The
# .gitignore checks just below cover .env, keys, certificates and dumps by name — they do
# not cover an arbitrary filename, so this trades a guaranteed false alarm for a narrow gap.
if in_this_git_repo; then
  refute "no committed secrets" \
    git grep -qE '(SECRET|PASSWORD|TOKEN|API_KEY)=[A-Za-z0-9+/=_-]{8,}' -- \
      ':!tests' ':!CHANGELOG.md' ':!SUPPORT.md'
else
  skip "no committed secrets (not a git checkout)"
fi
# RUNBOOK §4 makes operators produce mail-store archives, database dumps and a copy of
# .env. Any of those inside the working tree is one `git add -A` from being published.
for pattern in '.env' '.env.*' '.demo-password' '*.pem' '*.key' '*.crt' 'certs/' \
               'config/nginx/mail.conf' 'config/nginx/mail.sso.conf' \
               'config/stalwart/config.toml' \
               'backup/' 'backups/' '*.bak' '*.tar.gz' '*.sql' '*.sql.gz' '*.dump'; do
  check ".gitignore covers $pattern" grep -qxF "$pattern" .gitignore
done
# The runbook must not tell operators to write backups into the repo.
refute "runbook keeps backups out of the working tree" \
  grep -q 'PWD/backup' docs/RUNBOOK.md

echo "== supply chain =="
resolved="$(docker compose --env-file "$LINT_ENV" -f docker-compose.yml -f docker-compose.sso.yml config 2>/dev/null | grep -E '^[[:space:]]+image:')"
pinned="$(grep -c '@sha256:' <<<"$resolved")"
total="$(grep -c 'image:' <<<"$resolved")"
# Assert against the RESOLVED config, never the raw compose files: those contain
# ${BULWARK_VERSION}, so grepping them for `:latest` inspects the placeholder and passes
# while the image that actually runs is mutable. Distinguish "not run" from "passed" too —
# an empty resolution means docker could not resolve it, which is a failure, not a pass.
if (( total == 0 )); then
  bad "could not resolve compose config — is docker available? (checks did NOT run)"
elif (( pinned == total )); then
  ok "every resolved image is digest-pinned: $pinned/$total"
else
  bad "only $pinned/$total resolved images are digest-pinned:$(grep -v '@sha256:' <<<"$resolved" | sed 's/^ *image:/ /' | tr -d '\n')"
fi
if (( total > 0 )) && grep -qE ':latest([[:space:]]|@|$)' <<<"$resolved"; then
  bad "a resolved image rides the mutable :latest tag"
else
  ok "no :latest among the resolved images"
fi

# install.sh writes its own defaults into .env; docker-compose.yml then interpolates them.
# Nothing tied the two together, so when the mail server moved to `stalwartlabs/stalwart`
# and v0.13.4, `.env.example` was updated and install.sh was not — leaving the documented
# primary install path producing `stalwartlabs/stalwart:v0.11.8@sha256:a5ce…`, a reference
# that has never existed, because the rename happened at 0.12.0. Every suite stayed green:
# the e2e runs read `.env.example`, never install.sh. Compare them directly.
# shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
check "install.sh image defaults match .env.example" bash -c '
  bad=0
  for key in STALWART BULWARK NGINX KEYCLOAK POSTGRES; do
    for field in IMAGE VERSION DIGEST; do
      inst=$(sed -n "s/^readonly ${key}_${field}_DEFAULT=\"\(.*\)\"$/\1/p" install.sh)
      envx=$(sed -n "s/^${key}_${field}=\(.*\)$/\1/p" .env.example)
      [ -n "$inst" ] || continue          # not every image defines every field; only Bulwark has IMAGE
      if [ "$inst" != "$envx" ]; then
        echo "${key}_${field}: install.sh=[$inst] .env.example=[$envx]"; bad=1
      fi
    done
  done
  exit $bad'

echo "== hardening =="
for svc_file in docker-compose.yml docker-compose.sso.yml; do
  check "$svc_file sets no-new-privileges" grep -q 'no-new-privileges:true' "$svc_file"
done
refute "no privileged containers" grep -rq 'privileged:[[:space:]]*true' docker-compose.yml docker-compose.sso.yml

# Container hardening, asserted on the RESOLVED config so an overlay cannot quietly drop it.
# Every service must drop ALL capabilities, cap its memory and pids, and rotate its logs —
# an unbounded container log fills the host disk and takes the mail server down with it.
hardening="$(docker compose --env-file "$LINT_ENV" \
  -f docker-compose.yml -f docker-compose.sso.yml config 2>/dev/null)"
if [[ -z "$hardening" ]]; then
  bad "could not resolve compose config for the hardening checks (docker available?)"
else
  # Parse the YAML rather than guessing its indentation: an earlier version of this check
  # grepped for a fixed leading-space count, matched nothing, and reported 0/5 on a config
  # that was fully hardened — a guard that is wrong in the safe direction is still wrong.
  for field in cap_drop mem_limit pids_limit logging; do
    counts="$(printf '%s' "$hardening" | python3 -c "
import sys, yaml
svcs = (yaml.safe_load(sys.stdin) or {}).get('services', {})
have = [n for n, s in svcs.items() if (s or {}).get('$field') is not None]
print(f'{len(have)} {len(svcs)}')
" 2>/dev/null)"
    got="${counts% *}"; want="${counts#* }"
    if [[ -n "$got" && "$got" == "$want" && "$want" != "0" ]]; then
      ok "all $want services set $field"
    else
      bad "$field set on ${got:-?}/${want:-?} services — every service must be bounded"
    fi
  done
  refute "no service keeps SYS_ADMIN" grep -q 'SYS_ADMIN' <<<"$hardening"
fi

# The mail server's admin API lives on the same port as JMAP (8080), so what keeps it off the
# internet is one nginx location pattern and nothing else. Compared as a STRING, not matched as
# a regex: any widening at all — an added alternative, a dropped anchor, a trailing .* — has to
# fail, and a regex written to allow "roughly this" would allow exactly the mistake it guards.
# shellcheck disable=SC2317  # runs indirectly, through check()
only_jmap_reaches_mailserver() {
  local conf="$1" line found=0
  local expected='location ~ ^/(jmap|\.well-known/jmap) {'
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"          # strip leading indentation
    if [[ "$line" != "$expected" ]]; then
      echo "$conf proxies to the mail server from an unexpected location: $line"
      return 1
    fi
    found=1
  done < <(awk '/^[[:space:]]*location /{loc=$0}
                /proxy_pass[[:space:]]+http:\/\/mailserver/{print loc}' "$conf")
  # No route at all is also a failure: it means the JMAP location was renamed or removed and
  # this guard would otherwise pass by having nothing left to inspect.
  [[ "$found" -eq 1 ]] || { echo "$conf: nothing routes to the mail server"; return 1; }
  return 0
}

# The two nginx templates must not drift apart: the SSO edition is the one users reach for
# when they care about identity, so it must never be the laxer of the two. nginx's own
# defaults enable TLSv1/TLSv1.1 and a 1m body limit, so every directive below is a
# correction of a default, not a preference.
for conf in config/nginx/mail.conf.example config/nginx/mail.sso.conf.example; do
  check "$(basename "$conf") pins ssl_protocols to 1.2/1.3" \
    grep -qE '^\s*ssl_protocols\s+TLSv1\.2\s+TLSv1\.3;' "$conf"
  refute "$(basename "$conf") does not allow TLSv1/TLSv1.1" \
    grep -qE '^\s*ssl_protocols[^;]*TLSv1(\.1)?[[:space:];]' "$conf"
  check "$(basename "$conf") sets HSTS" \
    grep -q 'Strict-Transport-Security' "$conf"
  check "$(basename "$conf") sets nosniff" \
    grep -q 'X-Content-Type-Options' "$conf"
  check "$(basename "$conf") forbids framing" \
    grep -q "frame-ancestors 'none'" "$conf"
  check "$(basename "$conf") hides the nginx version" \
    grep -qE '^\s*server_tokens\s+off;' "$conf"
  check "$(basename "$conf") raises client_max_body_size above the 1m default" \
    grep -qE '^\s*client_max_body_size\s+[0-9]+m;' "$conf"
  refute "$(basename "$conf") does not hardcode Connection: upgrade" \
    grep -q 'proxy_set_header Connection "upgrade"' "$conf"
  # The property this file itself calls load-bearing — "the mail server's admin API must
  # never be reachable from the public internet" — and, until 2026-08-13, the only nginx
  # property with no guard at all. Eight others were asserted; widening the location to
  # ^/(jmap|api) would have passed every one of them.
  check "$(basename "$conf") routes only JMAP to the mail server" \
    only_jmap_reaches_mailserver "$conf"
done
refute "keycloak database is not published to the host" \
  bash -c "grep -A12 '^  db:' docker-compose.sso.yml | grep -qE '^[[:space:]]+ports:'"

echo "== installer unit checks =="
# valid_domain() guards a value that is interpolated into sed and into nginx config.
# Extract ONLY that definition — it is a single line. A range-based extraction here once
# swallowed the rest of the installer and executed it.
domain_fn="$(grep -m1 '^valid_domain() {.*}$' install.sh)"
if [[ -z "$domain_fn" ]]; then
  bad "could not extract valid_domain() from install.sh"
else
  eval "$domain_fn"
fi
for good in example.com mail.example.com a-b.co.uk xn--80ak6aa92e.com; do
  check "valid_domain accepts $good" valid_domain "$good"
done
for bad_input in "" "no-dot" "sp ace.com" "semi;colon.com" "sla/sh.com" "-lead.com" "amp&.com"; do
  refute "valid_domain rejects '${bad_input}'" valid_domain "$bad_input"
done

echo "== installer end-to-end (no containers) =="
# install.sh is the first thing every user runs, and until now only valid_domain() was
# covered. Drive it non-interactively in a throwaway copy and assert what it produced.
installer_tmp="$(mktemp -d)"
cp -r "$REPO_DIR/." "$installer_tmp/"
rm -f "$installer_tmp/.env"
if printf '1\nmail.qa.test\nQA Mail\nn\n' | (cd "$installer_tmp" && ./install.sh) >/dev/null 2>&1; then
  ok "install.sh completes non-interactively"
else
  bad "install.sh failed to complete"
fi
# shellcheck disable=SC2016  # single quotes are required: the body runs in the child
# shell, which receives the directory as $1 rather than by string interpolation.
check ".env created mode 600" \
  bash -c '[ "$(stat -c %a "$1/.env")" = 600 ]' _ "$installer_tmp"
for key in MAIL_DOMAIN STALWART_VERSION STALWART_DIGEST BULWARK_IMAGE NGINX_DIGEST \
           TLS_FULLCHAIN WEBMAIL_SESSION_SECRET STALWART_FALLBACK_ADMIN_SECRET; do
  check ".env contains $key" grep -q "^${key}=" "$installer_tmp/.env"
done
# Secrets must be generated, not left empty or templated.
# shellcheck disable=SC2016  # body runs in the child shell; directory arrives as $1
check "generated secrets are non-trivial" bash -c '
  for k in WEBMAIL_SESSION_SECRET STALWART_FALLBACK_ADMIN_SECRET; do
    v=$(grep "^${k}=" "$1/.env" | cut -d= -f2-)
    [ "${#v}" -ge 32 ] || { echo "$k too short: ${#v}"; exit 1; }
  done' _ "$installer_tmp"
check "installer materialised the nginx config" test -f "$installer_tmp/config/nginx/mail.conf"
check "domain substituted into nginx config" \
  grep -q 'server_name mail.qa.test;' "$installer_tmp/config/nginx/mail.conf"
refute "installer left no placeholder in nginx config" \
  grep -q 'MAIL_DOMAIN_PLACEHOLDER' "$installer_tmp/config/nginx/mail.conf"
# A rerun must refuse rather than silently rotate live secrets.
if printf '1\nmail.qa.test\nQA Mail\nn\n' | (cd "$installer_tmp" && ./install.sh) >/dev/null 2>&1; then
  bad "install.sh overwrote an existing .env without --force"
else
  ok "install.sh refuses to clobber an existing .env"
fi
rm -rf "$installer_tmp"

echo "== docs =="
for doc in README.md LICENSE NOTICE SECURITY.md CONTRIBUTING.md CODE_OF_CONDUCT.md \
           SUPPORT.md CHANGELOG.md ROADMAP.md THIRD_PARTY_LICENSES.md docs/DNS.md docs/RUNBOOK.md \
           docs/REQUIREMENTS.md docs/PUBLISHING.md docs/media/README.md \
           tests/README.md TRANSLATIONS.md; do
  check "$doc exists" test -f "$doc"
done
check "NOTICE carries a contact address" grep -qE 'Contact:.*@' NOTICE

echo "== supply chain (workflows) =="
# A mutable ref means whoever controls that action can change what runs in our CI at any
# time. This repo pins every action to a commit SHA; OpenSSF Scorecard checks the same.
# shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
check "every action is pinned to a commit SHA" bash -c '
  bad=$(grep -rhoE "uses:[[:space:]]*[^[:space:]]+" .github/workflows/ \
        | awk "{print \$2}" | grep -vE "@[0-9a-f]{40}$" || true)
  [ -z "$bad" ] || { echo "$bad"; exit 1; }'
check "dependabot keeps those pins fresh" test -f .github/dependabot.yml
check "scorecard workflow present" test -f .github/workflows/scorecard.yml
for wf in .github/workflows/*.yml; do
  check "$(basename "$wf") is valid YAML" \
    python3 -c "import yaml,sys; yaml.safe_load(open('$wf'))"
done

echo "== media =="
# A README that points at a missing image is worse than a README with no images.
for img in docs/media/inbox.png docs/media/tour.gif; do
  check "$img exists" test -f "$img"
  check "$img is referenced by README.md" grep -q "$img" README.md
done
# ImageMagick is not on a stock GitHub runner. Without this guard `identify` fails, the
# frame count reads 0, and the check reports "only 0 frames" — accusing a perfectly good GIF
# instead of naming the missing tool, which is how a maintainer ends up debugging an artifact
# that was never broken. A tool that is absent is a SKIP, and a skip is not a pass.
if command -v identify >/dev/null 2>&1; then
  # shellcheck disable=SC2016  # body runs in the child shell, deliberately unexpanded
  check "tour.gif is a real animation" bash -c '
    frames=$(identify docs/media/tour.gif | wc -l)
    [ "${frames:-0}" -ge 5 ] || { echo "only ${frames} frames"; exit 1; }'
else
  skip "tour.gif is a real animation (ImageMagick not installed)"
fi
# GitHub renders inline images from the repository; keep them small enough to load.
# shellcheck disable=SC2016  # body runs in the child shell, deliberately unexpanded
check "media stays under 2 MB total" bash -c '
  kb=$(du -sk docs/media | cut -f1)
  [ "$kb" -lt 2048 ] || { echo "${kb} KB"; exit 1; }'
check ".gitignore excludes intermediate frames" grep -qxF 'docs/media/frames/' .gitignore

echo "== language =="
# English is the source of truth. Nothing outside a declared translation file may carry
# non-English letters — a stray localised sentence in the canonical docs is a defect.
# shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
check "canonical files are English-only" bash -c '
  # Translations live under docs/i18n/ and are the only files allowed non-English letters.
  # The root README carries a language selector, so its own non-ASCII line is expected.
  # README.md and TRANSLATIONS.md carry the language selector, which must show each
  # language in its own script. Everything else canonical stays ASCII.
  hits=$(grep -rlP "[^\x00-\x7F]" --include="*.md" . 2>/dev/null \
         | grep -v "docs/i18n/" \
         | xargs -r grep -lP "[\x{00C0}-\x{024F}\x{1E00}-\x{1EFF}]" 2>/dev/null \
         | grep -vE "(^|/)(README|TRANSLATIONS)\.md$")
  [ -z "$hits" ] || { echo "$hits"; exit 1; }'
check "README.md carries the language selector" grep -q 'docs/i18n/vi/README.md' README.md
# Every language advertised in TRANSLATIONS.md must actually exist, or the selector lies.
# shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
check "every declared translation file exists" bash -c '
  missing=0
  for f in $(grep -oE "docs/i18n/[a-zA-Z-]+/README\.md" TRANSLATIONS.md | sort -u); do
    [ -f "$f" ] || { echo "declared but missing: $f"; missing=1; }
  done
  exit $missing'
# The selector in README.md and the table in TRANSLATIONS.md must agree. One advertising a
# language the other does not is how a reader lands on a 404.
# shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
check "selector and translation table list the same languages" bash -c '
  a=$(grep -oE "docs/i18n/[a-zA-Z-]+/README\.md" README.md | sort -u)
  b=$(grep -oE "docs/i18n/[a-zA-Z-]+/README\.md" TRANSLATIONS.md | sort -u)
  [ "$a" = "$b" ] || { echo "selector vs table differ:"; diff <(echo "$a") <(echo "$b"); exit 1; }'
# Nothing on disk may be an orphan: a translation nobody links to is one nobody maintains.
# shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
check "no translation file is unadvertised" bash -c '
  orphan=0
  for f in docs/i18n/*/README.md; do
    grep -q "$f" TRANSLATIONS.md || { echo "on disk but undeclared: $f"; orphan=1; }
  done
  exit $orphan'
while IFS= read -r tr; do
  check "$tr links back to the English source" grep -q '(\.\./\.\./\.\./README\.md)' "$tr"
  # Language-neutral on purpose: match the link, not a phrase in the target language,
  # so this file stays English-only like every other canonical file.
  check "$tr points at the translation policy" grep -q 'TRANSLATIONS.md' "$tr"
  # Every translation must warn that it is not authoritative, or a reader may act on a
  # stale instruction believing it current. Matched by the link, not by translated words.
  # shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
  # Code blocks must be byte-identical to the English. The policy forbids translating
  # commands, and a translated comment inside a shell block is how that rule erodes: it
  # looks harmless, then someone translates a flag. Caught the Vietnamese file doing it.
  check "$tr keeps code blocks identical to English" python3 -c '
import re, sys
b = lambda t: re.findall(r"```[a-z]*\n(.*?)```", t, re.S)
en = b(open("README.md", encoding="utf-8").read())
tr = b(open(sys.argv[1], encoding="utf-8").read())
sys.exit(0 if en == tr else 1)' "$tr"
  # Fenced blocks were only half of it: a translated placeholder inside an INLINE `code`
  # span slipped past the check above (`<your-domain>` became `<domain-cua-ban>`). Inline
  # spans that look like commands, paths, env vars or placeholders must survive untouched.
  # shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
  check "$tr keeps command-like inline code identical to English" python3 -c '
import re, sys
def spans(t):
    t = re.sub(r"```.*?```", "", t, flags=re.S)
    keep = re.compile(r"^([<$/.]|[A-Za-z0-9_.-]+\.(md|sh|py|yml|toml|example)$|[A-Z_]{4,}$|https?://)")
    return sorted({s for s in re.findall(r"`([^`\n]+)`", t) if keep.match(s)})
en = spans(open("README.md", encoding="utf-8").read())
tr = spans(open(sys.argv[1], encoding="utf-8").read())
missing = [x for x in en if x not in tr]
sys.exit(0 if not missing else 1)' "$tr"
  # shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
  check "$tr keeps the same section count as English" bash -c '
    en=$(grep -c "^## " README.md); tr=$(grep -c "^## " "$0")
    [ "$en" = "$tr" ] || { echo "English has $en sections, $0 has $tr"; exit 1; }' "$tr"
done < <(grep -oE 'docs/i18n/[a-zA-Z-]+/README\.md' TRANSLATIONS.md | sort -u)
# Drift is the failure mode that beat every other guard here: a fix lands in the file it was
# found in and never reaches the translations. TRANSLATIONS.md step 5 always required each
# translation to record the commit of README.md it tracks; nothing enforced it. Now something
# does — if README.md has moved since a recorded SHA, that translation is stale by definition.
# shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
if in_this_git_repo; then
check "every translation records a real commit SHA" bash -c '
  bad=0
  rows=0
  while IFS= read -r row; do
    rows=$((rows + 1))
    sha=$(printf "%s" "$row" | grep -oE "\`[0-9a-f]{7,}\`" | tail -1 | tr -d "\`")
    if [ -z "$sha" ]; then echo "row has no tracked commit: $row"; bad=1; continue; fi
    git cat-file -e "${sha}^{commit}" 2>/dev/null || { echo "not a commit: $sha"; bad=1; }
  done < <(grep -E "^\|.*docs/i18n/[a-zA-Z-]+/README\.md" TRANSLATIONS.md)
  # An empty or truncated table must not pass by having nothing left to check. The English
  # row is excluded on purpose: it is the source, so it tracks no commit of itself.
  if [ "$rows" -lt 11 ]; then
    echo "expected 11 translation rows, found $rows"; bad=1
  fi
  exit $bad'
# shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
# Judged per row, because the whole-file version excused an undeclared row using OTHER
# rows' declarations: its regex only matched a SHA cell ending immediately in "|", so the
# ten rows reading "`sha` — **STALE**" were invisible to it and the one undeclared row was
# the only thing it read. It found that row stale, then `grep -q STALE` matched the ten
# other rows and it exited 0. Vietnamese sat undeclared-stale through a green suite,
# shipping a licence list missing two components. Each row now answers for itself.
check "every stale translation declares itself STALE" bash -c '
  bad=0
  latest=$(git log -1 --format=%h -- README.md)
  while IFS= read -r row; do
    sha=$(printf "%s" "$row" | grep -oE "\`[0-9a-f]{7,}\`" | tail -1 | tr -d "\`")
    [ -n "$sha" ] || continue
    # An unreachable SHA must fail loudly. Skipping it here would let a fabricated or
    # orphaned commit exempt a row from the staleness rule entirely.
    if ! git merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
      echo "tracked commit $sha is not reachable from HEAD: $row"; bad=1; continue
    fi
    git merge-base --is-ancestor "$latest" "$sha" 2>/dev/null && continue
    case "$row" in
      *"— **STALE**"*) ;;
      *) echo "README.md moved at $latest; this row still tracks $sha and does not say STALE:"
         echo "  $row"; bad=1 ;;
    esac
  done < <(grep -E "^\|.*\`[0-9a-f]{7,40}\`" TRANSLATIONS.md)
  exit $bad'
else
  skip "every translation records a real commit SHA (not a git checkout of this repo)"
  skip "every stale translation declares itself STALE (not a git checkout of this repo)"
fi
# shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
check "every shipped file has a Last-touched line" bash -c '
  missing=0
  while IFS= read -r f; do
    head -6 "$f" | grep -q "Last-touched:" || { echo "$f"; missing=1; }
  done < <(find . -type f \( -name "*.sh" -o -name "*.yml" -o -name "*.py" -o -name "*.example" \) -not -path "./.git/*")
  exit $missing'

# The pin-currency check reads scripts/pin_sources.json. If someone adds an image to
# .env.example and forgets that file, the check keeps passing while covering less — the
# failure mode this project keeps finding in its own guards. So the coverage is asserted
# here, on every push, without touching the network.
if command -v python3 >/dev/null 2>&1; then
  check "every pinned image in .env.example is covered by scripts/pin_sources.json" \
    python3 -c '
import json, re, sys
declared = {c["digest_var"] for c in json.load(open("scripts/pin_sources.json"))["components"]}
pinned = set(re.findall(r"^([A-Z0-9_]+_DIGEST)=", open(".env.example").read(), re.M))
missing, extra = pinned - declared, declared - pinned
for name in sorted(missing):
    print("%s is pinned in .env.example but absent from pin_sources.json" % name)
for name in sorted(extra):
    print("%s is declared in pin_sources.json but no longer pinned in .env.example" % name)
sys.exit(1 if missing or extra else 0)'
  check "scripts/check_pins.py compiles" python3 -m py_compile scripts/check_pins.py
  # A public repository is a published surface. The manual pre-push checklist missed an
  # account-level disclosure twice, because a checklist only covers what somebody thought to
  # forbid. This asserts the inverse — nothing outside the publish allow-list — on every push.
  check "nothing outside the publish allow-list (scripts/check_disclosure.py)" \
    python3 scripts/check_disclosure.py
  check "scripts/check_disclosure.py compiles" python3 -m py_compile scripts/check_disclosure.py
  check "scripts/make_sbom.py compiles" python3 -m py_compile scripts/make_sbom.py
  # The SBOM is a release artifact, so it is only ever built at release time — where a broken
  # generator would be found by a red release, after the tag exists. Build one here, on every
  # push, and assert it actually describes the images this repository pins. An SBOM that
  # silently lists fewer components than the stack runs is worse than shipping none.
  # shellcheck disable=SC2317  # runs indirectly, through check()
  sbom_describes_every_pinned_image() {
    python3 - <<'PYEOF'
import json, subprocess, sys
out = subprocess.run(["scripts/make_sbom.py", "--version", "v0.0.0-test",
                      "--created", "2026-01-01T00:00:00Z"],
                     capture_output=True, text=True)
if out.returncode != 0:
    print(out.stderr.strip()); sys.exit(1)
document = json.loads(out.stdout)
pinned = {c["digest_var"] for c in json.load(open("scripts/pin_sources.json"))["components"]}
# one package per pinned image, plus the repository itself
sys.exit(0 if len(document["packages"]) == len(pinned) + 1 else 1)
PYEOF
  }
  check "the SBOM describes every pinned image" sbom_describes_every_pinned_image
else
  skip "every pinned image in .env.example is covered by scripts/pin_sources.json (no python3)"
  skip "scripts/check_pins.py compiles (no python3)"
  skip "nothing outside the publish allow-list (no python3)"
  skip "scripts/check_disclosure.py compiles (no python3)"
  skip "scripts/make_sbom.py compiles (no python3)"
  skip "the SBOM describes every pinned image (no python3)"
fi

echo
if (( SKIP > 0 )); then
  echo "== result: $PASS passed, $FAIL failed, $SKIP SKIPPED — install the missing tools before trusting this =="
else
  echo "== result: $PASS passed, $FAIL failed =="
fi
# A skip must not exit 0. Counting and printing skips was only half the fix: CI reads the
# exit code, not the text, so a runner without yamllint or shellcheck would report a green
# `static` job over a board where those checks never ran. Set FREEHOLDMAIL_ALLOW_SKIPS=1 to
# accept a partial run knowingly — never in CI.
if (( SKIP > 0 )) && [[ "${FREEHOLDMAIL_ALLOW_SKIPS:-0}" != "1" ]]; then
  echo "   (exiting non-zero: $SKIP check(s) did not run. Set FREEHOLDMAIL_ALLOW_SKIPS=1 to override.)"
  exit 1
fi
exit $(( FAIL > 0 ))
