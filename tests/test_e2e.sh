#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-08-07 — JMAP discovery guard made version-independent and
# origin-checked. End-to-end: stand the real stack up, send a real message, read it back,
# assert the security defaults, then destroy everything.
#
# Everything runs in a throwaway compose project on loopback-only ports, with its own
# volumes and a self-signed certificate, so it cannot collide with a real deployment on
# the same host. The stack is always torn down, including on failure.
#
# Usage:
#   tests/test_e2e.sh                 # base edition (Full Mail)
#   tests/test_e2e.sh --sso           # base + SSO overlay (adds Keycloak + PostgreSQL)
#   FREEHOLDMAIL_TEST_PORT_BASE=13000 tests/test_e2e.sh
#
# Image overrides, for hosts that cannot reach a registry or that want to test a build:
#   FREEHOLDMAIL_TEST_BULWARK_IMAGE=bulwark FREEHOLDMAIL_TEST_BULWARK_VERSION=latest tests/test_e2e.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="freeholdmail-e2e-$$"
PORT_BASE="${FREEHOLDMAIL_TEST_PORT_BASE:-12500}"
DOMAIN="qa.test"
MAIL_HOST="mail.${DOMAIN}"
WITH_SSO=0
[[ "${1:-}" == "--sso" ]] && WITH_SSO=1

SMTP_PORT=$((PORT_BASE + 25))
SUBMISSION_PORT=$((PORT_BASE + 87))
IMAPS_PORT=$((PORT_BASE + 93))
JMAP_PORT=$((PORT_BASE + 80))
HTTPS_PORT=$((PORT_BASE + 43))

WORK="$(mktemp -d)"
# shellcheck disable=SC2317  # invoked via trap, not called directly
cleanup() {
  local rc=$?
  echo "== teardown =="
  docker compose -p "$PROJECT" --project-directory "$WORK" down -v >/dev/null 2>&1 || true
  rm -rf "$WORK"
  exit "$rc"
}
trap cleanup EXIT INT TERM

PASS=0; FAIL=0; SKIP=0
ok()  { printf '  \033[32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31mFAIL\033[0m  %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
gen() { openssl rand -base64 24 | tr -d '\n=+/' | cut -c1-32; }

echo "== preparing throwaway stack in $WORK (project $PROJECT) =="
cp -r "$REPO_DIR/." "$WORK/"
mkdir -p "$WORK/certs"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -keyout "$WORK/certs/privkey.pem" -out "$WORK/certs/fullchain.pem" \
  -subj "/CN=${MAIL_HOST}" -addext "subjectAltName=DNS:${MAIL_HOST}" 2>/dev/null
chmod 644 "$WORK/certs"/*.pem

ADMIN_SECRET="$(gen)"
ALICE_PW="$(gen)"
BOB_PW="$(gen)"

# Start from the shipped .env.example so the test exercises the defaults users get.
sed -e "s|^MAIL_DOMAIN=.*|MAIL_DOMAIN=${MAIL_HOST}|" \
    -e "s|^TLS_FULLCHAIN=.*|TLS_FULLCHAIN=${WORK}/certs/fullchain.pem|" \
    -e "s|^TLS_PRIVKEY=.*|TLS_PRIVKEY=${WORK}/certs/privkey.pem|" \
    -e "s|^WEBMAIL_SESSION_SECRET=.*|WEBMAIL_SESSION_SECRET=$(gen)|" \
    -e "s|^STALWART_FALLBACK_ADMIN_SECRET=.*|STALWART_FALLBACK_ADMIN_SECRET=${ADMIN_SECRET}|" \
    -e "s|^OAUTH_CLIENT_SECRET=.*|OAUTH_CLIENT_SECRET=$(gen)|" \
    -e "s|^KEYCLOAK_ADMIN_PASSWORD=.*|KEYCLOAK_ADMIN_PASSWORD=$(gen)|" \
    -e "s|^KC_DB_PASSWORD=.*|KC_DB_PASSWORD=$(gen)|" \
    "$REPO_DIR/.env.example" > "$WORK/.env"
# Every *_VERSION must have its *_DIGEST overridable next to it. A digest outranks the tag
# it is attached to, so overriding only the version silently keeps the pinned image and the
# test quietly exercises something other than what it claims.
for var in STALWART_VERSION STALWART_DIGEST BULWARK_IMAGE BULWARK_VERSION BULWARK_DIGEST \
           NGINX_VERSION NGINX_DIGEST KEYCLOAK_VERSION KEYCLOAK_DIGEST KC_HOSTNAME_VALUE \
           POSTGRES_VERSION POSTGRES_DIGEST; do
  override="FREEHOLDMAIL_TEST_${var}"
  if [[ -n "${!override:-}" ]]; then
    sed -i "s|^${var}=.*|${var}=${!override}|" "$WORK/.env"
    echo "  override ${var}=${!override}"
  fi
done
chmod 600 "$WORK/.env"

cp -f "$WORK/config/nginx/mail.conf.example" "$WORK/config/nginx/mail.conf"
cp -f "$WORK/config/nginx/mail.sso.conf.example" "$WORK/config/nginx/mail.sso.conf"
sed -i "s/MAIL_DOMAIN_PLACEHOLDER/${MAIL_HOST}/g" "$WORK/config/nginx/mail.conf" "$WORK/config/nginx/mail.sso.conf"
cp -f "$WORK/config/stalwart/config.toml.example" "$WORK/config/stalwart/config.toml"

# `ports` lists MERGE across compose files, they do not replace — hence !override.
# The shipped compose files pin container_name for readable `docker logs` in the runbook.
# Those names are host-global, so the test must rename them or it would collide with a
# real deployment on the same host instead of running beside it.
cat > "$WORK/docker-compose.test.yml" <<EOF
services:
  webmail:
    container_name: ${PROJECT}-webmail
  db:
    container_name: ${PROJECT}-db
  idp:
    container_name: ${PROJECT}-idp
  mailserver:
    container_name: ${PROJECT}-mailserver
    ports: !override
      - "127.0.0.1:${SMTP_PORT}:25"
      - "127.0.0.1:${SUBMISSION_PORT}:587"
      - "127.0.0.1:${IMAPS_PORT}:993"
      - "127.0.0.1:${JMAP_PORT}:8080"
    environment:
      STALWART_HOSTNAME: ${MAIL_HOST}
      STALWART_FALLBACK_ADMIN_SECRET: ${ADMIN_SECRET}
  proxy:
    container_name: ${PROJECT}-proxy
    ports: !override
      - "127.0.0.1:${HTTPS_PORT}:443"
EOF
# The base edition has no db/idp; drop those stanzas unless the overlay is in play.
(( WITH_SSO )) || sed -i '/^  db:$/,+1d; /^  idp:$/,+1d' "$WORK/docker-compose.test.yml"

# Absolute paths: compose resolves -f relative to the current directory, not to
# --project-directory, and these files live in the throwaway copy.
FILES=(-f "$WORK/docker-compose.yml")
(( WITH_SSO )) && FILES+=(-f "$WORK/docker-compose.sso.yml")
FILES+=(-f "$WORK/docker-compose.test.yml")

compose() { docker compose -p "$PROJECT" --project-directory "$WORK" --env-file "$WORK/.env" "${FILES[@]}" "$@"; }

echo "== starting =="
compose up -d

echo "== waiting for the mail server to become healthy =="
deadline=$((SECONDS + 180))
until [[ "$(docker inspect "$(compose ps -q mailserver)" --format '{{.State.Health.Status}}' 2>/dev/null)" == "healthy" ]]; do
  if (( SECONDS > deadline )); then
    bad "mail server never became healthy"
    compose logs --tail 40 mailserver
    echo "== result: $PASS passed, $((FAIL + 1)) failed =="
    exit 1
  fi
  sleep 3
done
restarts="$(docker inspect "$(compose ps -q mailserver)" --format '{{.RestartCount}}')"
if [[ "$restarts" == "0" ]]; then
  ok "mail server healthy, 0 restarts"
else
  bad "mail server restarted $restarts times"
fi

API="http://127.0.0.1:${JMAP_PORT}/api/principal"
api() { curl -s -u "admin:${ADMIN_SECRET}" -o /dev/null -w '%{http_code}' "$@"; }

echo "== provisioning a domain and two mailboxes =="
if [[ "$(api -X POST "$API" -H 'Content-Type: application/json' -d "{\"type\":\"domain\",\"name\":\"${DOMAIN}\"}")" == "200" ]]; then
  ok "domain created"
else
  bad "domain creation failed"
fi
# Without roles:["user"] the account exists but SMTP AUTH answers 550 5.7.1.
for pair in "alice:${ALICE_PW}" "bob:${BOB_PW}"; do
  user="${pair%%:*}"; pw="${pair#*:}"
  code="$(api -X POST "$API" -H 'Content-Type: application/json' \
    -d "{\"type\":\"individual\",\"name\":\"${user}@${DOMAIN}\",\"secrets\":[\"${pw}\"],\"emails\":[\"${user}@${DOMAIN}\"],\"roles\":[\"user\"]}")"
  if [[ "$code" == "200" ]]; then
    ok "mailbox ${user}@${DOMAIN} created"
  else
    bad "mailbox ${user} failed (http $code)"
  fi
done

echo "== end-to-end delivery =="
if FREEHOLDMAIL_TEST_SUBMISSION_PORT="$SUBMISSION_PORT" \
   FREEHOLDMAIL_TEST_IMAP_PORT="$IMAPS_PORT" \
   FREEHOLDMAIL_TEST_DOMAIN="$DOMAIN" \
   FREEHOLDMAIL_TEST_SENDER_PW="$ALICE_PW" \
   FREEHOLDMAIL_TEST_RECIPIENT_PW="$BOB_PW" \
   python3 "$REPO_DIR/tests/e2e_mail.py"; then
  ok "message sent and received with a matching Message-ID"
else
  bad "end-to-end delivery"
fi

echo "== security defaults =="
relay="$(python3 - "$SMTP_PORT" <<'PY'
import smtplib, sys
s = smtplib.SMTP("127.0.0.1", int(sys.argv[1]), timeout=15)
s.ehlo("attacker.example"); s.mail("attacker@evil.example")
code, _ = s.rcpt("victim@example.net"); s.quit(); print(code)
PY
)"
if [[ "$relay" -ge 500 ]]; then
  ok "relaying to an external domain is refused ($relay)"
else
  bad "OPEN RELAY (rcpt returned $relay)"
fi

noauth="$(python3 - "$SUBMISSION_PORT" <<'PY'
import smtplib, sys
s = smtplib.SMTP("127.0.0.1", int(sys.argv[1]), timeout=15)
s.ehlo("x"); code, _ = s.mail("alice@qa.test"); s.quit(); print(code)
PY
)"
if [[ "$noauth" -ge 500 ]]; then
  ok "submission without AUTH is refused ($noauth)"
else
  bad "submission accepted without AUTH ($noauth)"
fi

# `|| true` is load-bearing: under `set -euo pipefail` a non-matching grep exits 1, pipefail
# propagates it, and the assignment kills the script — so the `bad` branch below was
# unreachable and a broken proxy ended the run with no FAIL line and no result line at all.
tls="$(echo | timeout 15 openssl s_client -connect "127.0.0.1:${HTTPS_PORT}" 2>/dev/null \
        | grep -oE 'TLSv1\.[23]' | head -1 || true)"
if [[ -n "$tls" ]]; then
  ok "proxy negotiates $tls"
else
  bad "proxy TLS handshake failed"
fi

# Negotiating a modern protocol proves nothing about the obsolete ones: a client always
# offers its best first. nginx's default protocol list still names TLSv1 and TLSv1.1, so
# whether they are reachable depends on the image's OpenSSL policy rather than on anything
# visible in this repo. Ask for them ON PURPOSE and require refusal — and if this openssl
# build cannot even offer them, say so out loud rather than banking an unearned PASS.
for legacy in tls1 tls1_1; do
  out="$(echo | timeout 15 openssl s_client -connect "127.0.0.1:${HTTPS_PORT}" \
           "-${legacy}" -cipher 'ALL:@SECLEVEL=0' 2>&1 || true)"
  # Read whether a SESSION was established, not which protocol the line mentions:
  # on refusal openssl still prints `Protocol : TLSv1` (the version it *attempted*) next to
  # `Cipher : 0000`, so matching the protocol line alone reports a refusal as an acceptance.
  if grep -q 'no protocols available\|unknown option' <<<"$out"; then
    printf '  \033[33mSKIP\033[0m  %s\n' \
      "cannot test ${legacy}: this openssl refuses to offer it (check NOT run)"
    SKIP=$((SKIP + 1))
  elif grep -qE 'Cipher is \(NONE\)|Cipher *: *0000|alert protocol version|wrong version number|unsupported protocol' <<<"$out"; then
    ok "proxy refuses obsolete ${legacy}"
  elif grep -qE '^ *Protocol *: *TLSv1(\.1)? *$' <<<"$out"; then
    bad "proxy ACCEPTS obsolete ${legacy} — RFC 8996 deprecated it; pin ssl_protocols"
  else
    # Do NOT pass here. Unrecognised output means the probe never reached a live TLS
    # endpoint — a refused connection, an empty reply, a timeout — and "the server did not
    # answer" is not evidence that it refuses obsolete TLS. Passing on the unknown is how a
    # guard silently turns decorative.
    bad "cannot tell whether ${legacy} is refused: unexpected probe output (see below)"
    printf '        %s\n' "$(head -3 <<<"$out")"
  fi
done

hsts="$(curl -sk -o /dev/null -D - --max-time 15 "https://127.0.0.1:${HTTPS_PORT}/" \
         | grep -ci '^strict-transport-security:' || true)"
nosniff="$(curl -sk -o /dev/null -D - --max-time 15 "https://127.0.0.1:${HTTPS_PORT}/" \
            | grep -ci '^x-content-type-options: *nosniff' || true)"
if [[ "$hsts" -ge 1 && "$nosniff" -ge 1 ]]; then
  ok "security headers present (HSTS + nosniff)"
else
  bad "security headers missing (hsts=$hsts nosniff=$nosniff)"
fi

# Follow redirects and require the FINAL status to be 200. Bulwark 1.7 routes `/` through
# a 307 to a locale prefix (`/en`), so asserting 200 on the first hop fails on a perfectly
# healthy stack. Following the chain keeps the check honest in both directions: a redirect
# loop or a redirect to an error page still fails here.
first="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 15 "https://127.0.0.1:${HTTPS_PORT}/")"
final="$(curl -skL -o /dev/null -w '%{http_code}' --max-time 20 "https://127.0.0.1:${HTTPS_PORT}/")"
if [[ "$final" == "200" ]]; then
  ok "webmail served through the proxy (first hop $first, final $final)"
else
  bad "webmail not served (first hop $first, final $final)"
fi

# The HTML shell can render while the app is dead: the client then fetches its own
# /api/config and fails. An over-broad nginx `location ~ ^/(jmap|api|...)` once sent every
# /api/* call to the mail server, which answered 401, and "GET / == 200" never noticed.
code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 15 "https://127.0.0.1:${HTTPS_PORT}/api/config")"
if [[ "$code" == "200" ]]; then
  ok "webmail owns its own /api routes through the proxy (http $code)"
else
  bad "proxy hijacks the webmail's /api routes (http $code on /api/config)"
fi

# JMAP discovery must reach the mail server. What "reached it" looks like is version-dependent
# and this check used to hardcode one version's answer: 0.11.x replied 401 to an
# unauthenticated probe, 0.13.x replies 307 to /jmap/session, which is what RFC 8620 §2.2
# describes. Both prove the route lands on the mail server; a 404 or a redirect to the webmail
# would not. Assert the property, not the status code of whichever release was current.
probe="$(curl -sk -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 15 \
  "https://127.0.0.1:${HTTPS_PORT}/.well-known/jmap")"
code="${probe%% *}"; target="${probe#* }"
# The redirect target is matched against this origin, not just its suffix: `*/jmap/session`
# alone would accept https://evil.example.com/jmap/session, which is a redirect off the box.
if [[ "$code" == "401" ]]; then
  ok "JMAP discovery reaches the mail server (http $code)"
elif [[ "$code" == "30"[0-8] && "$target" == "https://127.0.0.1:${HTTPS_PORT}/"*"jmap/session" ]]; then
  ok "JMAP discovery reaches the mail server (http $code → $target)"
else
  bad "JMAP discovery not routed to the mail server (http $code, redirect '$target')"
fi

if (( WITH_SSO )); then
  echo "== SSO edition =="
  # Keycloak's first boot runs ~124 Liquibase changesets and refuses HTTP meanwhile, so
  # poll rather than sampling once. Polling the database instead of the health endpoint
  # keeps this check version-agnostic: health moved from :8080 to :9000 in Keycloak 25.
  kc_user="$(grep '^KC_DB_USERNAME=' "$WORK/.env" | cut -d= -f2)"
  kc_db="$(grep '^KC_DB_NAME=' "$WORK/.env" | cut -d= -f2)"
  # Wait for a realm ROW, not for a table count: the schema appears progressively as the
  # changesets run, so "enough tables exist" goes true while Keycloak is still migrating.
  # A row in `realm` is the first point at which Keycloak has actually initialised.
  # `|| echo 0` is load-bearing: while Keycloak is still migrating, psql exits non-zero and
  # `set -euo pipefail` would otherwise abort the whole script mid-check, silently.
  kcq() { docker exec "$(compose ps -q db)" psql -U "$kc_user" -d "$kc_db" -tAc "$1" 2>/dev/null | tr -d ' []' || echo 0; }
  realms=0
  deadline=$((SECONDS + 300))
  while (( SECONDS < deadline )); do
    realms="$(kcq 'SELECT count(*) FROM realm;')"
    [[ "$realms" =~ ^[0-9]+$ ]] || realms=0
    (( realms > 0 )) && break
    sleep 5
  done
  db_tables="$(kcq "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")"
  [[ "$db_tables" =~ ^[0-9]+$ ]] || db_tables=0
  if (( realms > 0 )); then
    ok "Keycloak owns its database ($db_tables tables, $realms realm(s))"
  else
    bad "Keycloak never initialised its database ($db_tables tables, 0 realms)"
    compose logs --tail 20 idp
  fi
fi

echo
# A skipped check is not a passed one. Naming the count keeps a partially-hollow board from
# reading as a clean one — the failure mode that once produced a green 86/86 here.
if (( SKIP > 0 )); then
  echo "== result: $PASS passed, $FAIL failed, $SKIP SKIPPED — a check did NOT run =="
else
  echo "== result: $PASS passed, $FAIL failed =="
fi
# CI reads the exit code, not the text — a skip must not exit 0. See test_config.sh.
if (( SKIP > 0 )) && [[ "${FREEHOLDMAIL_ALLOW_SKIPS:-0}" != "1" ]]; then
  echo "   (exiting non-zero: $SKIP check(s) did not run. Set FREEHOLDMAIL_ALLOW_SKIPS=1 to override.)"
  exit 1
fi
exit $(( FAIL > 0 ))
