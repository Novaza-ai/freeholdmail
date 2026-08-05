#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-08-04 — static checks: everything provable without starting containers.
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

echo "== syntax =="
check "install.sh parses" bash -n install.sh
check "tests/test_e2e.sh parses" bash -n tests/test_e2e.sh
# ast.parse rather than py_compile: py_compile writes a __pycache__ directory into the
# repo, so the test would dirty the tree it is checking.
check "e2e_mail.py parses" \
  python3 -c "import ast; ast.parse(open('tests/e2e_mail.py').read())"
# A workflow that does not parse never runs, so CI would go silently green-by-absence.
check "CI workflow is valid YAML" \
  python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"
if command -v shellcheck >/dev/null 2>&1; then
  check "shellcheck install.sh" shellcheck install.sh
  check "shellcheck tests/*.sh" shellcheck tests/test_config.sh tests/test_e2e.sh
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
check "base edition validates" \
  docker compose --env-file .env.example -f docker-compose.yml config -q
check "SSO edition validates" \
  docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.sso.yml config -q

# The SSO edition once pointed KC_DB_URL at a `db` host that no service defined, so it
# could never start. Assert the service exists rather than trusting the file to look right.
services="$(docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.sso.yml config --services 2>/dev/null | sort | tr '\n' ' ')"
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
refute "no committed secrets" \
  grep -rqE '(SECRET|PASSWORD|TOKEN|API_KEY)=[A-Za-z0-9+/=_-]{8,}' \
    --exclude-dir=.git --exclude-dir=tests --exclude=CHANGELOG.md --exclude=SUPPORT.md .
# RUNBOOK §4 makes operators produce mail-store archives, database dumps and a copy of
# .env. Any of those inside the working tree is one `git add -A` from being published.
for pattern in '.env' '.env.*' '*.pem' '*.key' '*.crt' 'certs/' \
               'config/nginx/mail.conf' 'config/nginx/mail.sso.conf' \
               'config/stalwart/config.toml' \
               'backup/' 'backups/' '*.bak' '*.tar.gz' '*.sql' '*.sql.gz' '*.dump'; do
  check ".gitignore covers $pattern" grep -qxF "$pattern" .gitignore
done
# The runbook must not tell operators to write backups into the repo.
refute "runbook keeps backups out of the working tree" \
  grep -q 'PWD/backup' docs/RUNBOOK.md

echo "== supply chain =="
resolved="$(docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.sso.yml config 2>/dev/null | grep -E '^[[:space:]]+image:')"
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

echo "== hardening =="
for svc_file in docker-compose.yml docker-compose.sso.yml; do
  check "$svc_file sets no-new-privileges" grep -q 'no-new-privileges:true' "$svc_file"
done
refute "no privileged containers" grep -rq 'privileged:[[:space:]]*true' docker-compose.yml docker-compose.sso.yml

# Container hardening, asserted on the RESOLVED config so an overlay cannot quietly drop it.
# Every service must drop ALL capabilities, cap its memory and pids, and rotate its logs —
# an unbounded container log fills the host disk and takes the mail server down with it.
hardening="$(docker compose --env-file .env.example \
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
check "every translation records a real commit SHA" bash -c '
  bad=0
  while read -r sha; do
    git cat-file -e "${sha}^{commit}" 2>/dev/null || { echo "not a commit: $sha"; bad=1; }
  done < <(grep -oE "\| \`[0-9a-f]{7,40}\` \|" TRANSLATIONS.md | tr -d "|\` ")
  exit $bad'
# shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
check "translations are not stale against README.md" bash -c '
  stale=0
  latest=$(git log -1 --format=%h -- README.md)
  while read -r sha; do
    git merge-base --is-ancestor "$sha" HEAD 2>/dev/null || continue
    if ! git merge-base --is-ancestor "$latest" "$sha" 2>/dev/null; then
      echo "README.md moved at $latest; a translation still tracks $sha"; stale=1
    fi
  done < <(grep -oE "\| \`[0-9a-f]{7,40}\` \|" TRANSLATIONS.md | tr -d "|\` " | sort -u)
  # A translation may lag, but it must SAY so. Undeclared staleness is the failure; a row
  # marked STALE is an honest, published debt.
  [ "$stale" = 0 ] && exit 0
  grep -q "STALE" TRANSLATIONS.md || exit 1
  echo "(stale translations are declared in TRANSLATIONS.md)"; exit 0' 
# shellcheck disable=SC2016  # body is deliberately unexpanded; it runs in the child shell
check "every shipped file has a Last-touched line" bash -c '
  missing=0
  while IFS= read -r f; do
    head -6 "$f" | grep -q "Last-touched:" || { echo "$f"; missing=1; }
  done < <(find . -type f \( -name "*.sh" -o -name "*.yml" -o -name "*.py" -o -name "*.example" \) -not -path "./.git/*")
  exit $missing'

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
