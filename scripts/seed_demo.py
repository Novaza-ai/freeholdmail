#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-08-05 — demo data for screenshots, GIFs and manual exploration.
#
# Fills a running Freehold Mail stack with a small, believable mailbox so the UI has
# something to show. Nothing here is required to run the product; it exists so that
# documentation screenshots are not of an empty inbox.
#
# NEVER point this at a production deployment: it creates accounts with known passwords.
#
# Usage:
#   FREEHOLD_ADMIN_SECRET=... scripts/seed_demo.py
#   FREEHOLD_API=http://127.0.0.1:8080 FREEHOLD_SUBMISSION_PORT=587 scripts/seed_demo.py

import base64
import json
import os
import secrets
import smtplib
import time
import ssl
import sys
import urllib.error
import urllib.request
from email.message import EmailMessage
from email.utils import formatdate, make_msgid

API = os.environ.get("FREEHOLD_API", "http://127.0.0.1:8080")
SMTP_HOST = os.environ.get("FREEHOLD_SMTP_HOST", "127.0.0.1")
SUBMISSION_PORT = int(os.environ.get("FREEHOLD_SUBMISSION_PORT", "587"))
DOMAIN = os.environ.get("FREEHOLD_DEMO_DOMAIN", "freehold.demo")
ADMIN_SECRET = os.environ.get("FREEHOLD_ADMIN_SECRET", "")
# No default password ships in this repository. One is generated per run unless you
# supply your own, so a public clone never carries a working credential.
DEMO_PASSWORD = os.environ.get("FREEHOLD_DEMO_PASSWORD") or f"demo-{secrets.token_urlsafe(12)}"

# The person whose inbox the screenshots show, plus the colleagues who write to them.
OWNER = "ana"
PEOPLE = {
    "ana": "Ana Duarte",
    "ben": "Ben Okafor",
    "chi": "Chi Nguyen",
    "dev": "Dev Team",
}

# Subject lines a reader can scan in one second, and one required by the product tour:
# components/tour/tour-steps.ts looks for an email whose subject contains
# "Welcome to Bulwark Mail" to open the reading pane. Keep it.
MESSAGES = [
    ("dev", "Welcome to Bulwark Mail",
     "This is your new mailbox. Everything in it lives on hardware you control.\n\n"
     "Nothing here is synced to a third party, and no one is reading it to sell you\n"
     "anything. Use the tour in the top banner for a two-minute walkthrough."),
    ("ben", "Q3 infrastructure review — Thursday 14:00",
     "Agenda:\n"
     "  1. Mail migration status\n"
     "  2. Backup restore rehearsal (we still have not done one end to end)\n"
     "  3. Certificate renewal automation\n\n"
     "Notes in the shared folder. Bring numbers, not impressions."),
    ("chi", "Re: DNS cutover window",
     "Friday 02:00 UTC works. MX and SPF are staged; DKIM selector is published but\n"
     "not yet signing. DMARC stays at p=quarantine until we see a clean week of\n"
     "aggregate reports."),
    ("dev", "Deploy 2026.08.04 succeeded",
     "All services healthy, zero restarts.\n\n"
     "  mailserver   healthy   0 restarts\n"
     "  webmail      running\n"
     "  proxy        running\n\n"
     "End-to-end delivery check passed: submit 0.069s, deliver 0.085s."),
    ("ben", "Storage plan for next quarter",
     "Current mail volume grows about 4 GB per month. The volume is on its own disk,\n"
     "so expanding it does not touch the host root. Proposal attached to the ticket."),
    ("chi", "Lunch?",
     "There is a new place near the office that does actual pho. 12:30?"),
]


def api_call(path, payload=None, method="GET"):
    """Call the mail server admin API. Returns the parsed body, or raises."""
    url = f"{API}{path}"
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    token = base64.b64encode(f"admin:{ADMIN_SECRET}".encode()).decode()
    req.add_header("Authorization", f"Basic {token}")
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read() or b"{}")


def ensure_principal(payload, label):
    try:
        api_call("/api/principal", payload, method="POST")
        print(f"  created  {label}")
    except urllib.error.HTTPError as exc:
        # The API answers 400 when the principal already exists; re-running is fine.
        if exc.code in (400, 409):
            print(f"  exists   {label}")
        else:
            raise


def seed_accounts():
    print(f"Provisioning {DOMAIN}")
    ensure_principal({"type": "domain", "name": DOMAIN}, DOMAIN)
    for user, display in PEOPLE.items():
        ensure_principal(
            {
                "type": "individual",
                "name": f"{user}@{DOMAIN}",
                "description": display,
                "secrets": [DEMO_PASSWORD],
                "emails": [f"{user}@{DOMAIN}"],
                # Without a role the account exists but SMTP AUTH refuses it (550 5.7.1).
                "roles": ["user"],
            },
            f"{user}@{DOMAIN} ({display})",
        )


def connect(sender, tls, attempts=3):
    """Authenticated submission session. Mail servers rate-limit new connections, so
    retry with backoff rather than dropping half the demo data on the floor."""
    last = None
    for attempt in range(attempts):
        try:
            smtp = smtplib.SMTP(SMTP_HOST, SUBMISSION_PORT, timeout=20)
            smtp.ehlo("seed.local")
            smtp.starttls(context=tls)
            smtp.ehlo("seed.local")
            smtp.login(f"{sender}@{DOMAIN}", DEMO_PASSWORD)
            return smtp
        except (smtplib.SMTPException, OSError) as exc:
            last = exc
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"could not open a submission session for {sender}: {last}")


def send_messages():
    tls = ssl.create_default_context()
    tls.check_hostname = False
    tls.verify_mode = ssl.CERT_NONE  # a demo stack uses a self-signed certificate

    # One session per sender, not one per message: fewer connections, and it is what a
    # real client does.
    by_sender = {}
    for sender, subject, body in MESSAGES:
        by_sender.setdefault(sender, []).append((subject, body))

    print(f"Delivering {len(MESSAGES)} messages to {OWNER}@{DOMAIN}")
    for sender, items in by_sender.items():
        smtp = connect(sender, tls)
        try:
            for subject, body in items:
                msg = EmailMessage()
                msg["From"] = f"{PEOPLE[sender]} <{sender}@{DOMAIN}>"
                msg["To"] = f"{PEOPLE[OWNER]} <{OWNER}@{DOMAIN}>"
                msg["Subject"] = subject
                msg["Date"] = formatdate(localtime=True)
                msg["Message-ID"] = make_msgid(domain=DOMAIN)
                msg.set_content(body)
                smtp.send_message(msg)
                print(f"  sent     {sender} → {OWNER}: {subject}")
        finally:
            smtp.quit()


def main():
    if not ADMIN_SECRET:
        print("FREEHOLD_ADMIN_SECRET is not set — read it from your .env", file=sys.stderr)
        return 1
    seed_accounts()
    send_messages()
    print(f"\nDone. Sign in as {OWNER}@{DOMAIN}")
    if not os.environ.get("FREEHOLD_DEMO_PASSWORD"):
        print(f"Generated demo password: {DEMO_PASSWORD}")
        print("Set FREEHOLD_DEMO_PASSWORD to choose your own on the next run.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
