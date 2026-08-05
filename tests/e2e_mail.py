#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-08-04 — E2E: prove a real message travels SMTP submission → mailbox → IMAP.
#
# This is the test that matters. "The container is Up" and "the config looks right" have both
# been wrong before in this repo; only a message that comes back out is evidence.
#
# Called by tests/test_e2e.sh, which stands the stack up first. Ports come from the
# environment so the script never assumes a deployment layout.
#
# Exit 0 = the exact message that was sent came back. Anything else is a failure.

import email
import imaplib
import os
import smtplib
import ssl
import sys
import time
import uuid

SUBMISSION_PORT = int(os.environ["FREEHOLDMAIL_TEST_SUBMISSION_PORT"])
IMAP_PORT = int(os.environ["FREEHOLDMAIL_TEST_IMAP_PORT"])
HOST = os.environ.get("FREEHOLDMAIL_TEST_HOST", "127.0.0.1")
DOMAIN = os.environ.get("FREEHOLDMAIL_TEST_DOMAIN", "qa.test")
SENDER = f"alice@{DOMAIN}"
RECIPIENT = f"bob@{DOMAIN}"
SENDER_PW = os.environ["FREEHOLDMAIL_TEST_SENDER_PW"]
RECIPIENT_PW = os.environ["FREEHOLDMAIL_TEST_RECIPIENT_PW"]
DEADLINE_S = float(os.environ.get("FREEHOLDMAIL_TEST_DELIVERY_DEADLINE", "30"))

# A throwaway stack uses a self-signed certificate; verification is not what is under test.
TLS = ssl.create_default_context()
TLS.check_hostname = False
TLS.verify_mode = ssl.CERT_NONE


def fail(msg):
    print(f"FAIL: {msg}")
    sys.exit(1)


def main():
    imap = imaplib.IMAP4_SSL(HOST, IMAP_PORT, ssl_context=TLS)
    imap.login(RECIPIENT, RECIPIENT_PW)
    imap.select("INBOX")
    # Baseline of existing UIDs. Without this, a poll loop can "succeed" on an older
    # message and report a delivery time that was never measured.
    before = set(imap.uid("search", None, "ALL")[1][0].split())

    message_id = f"<{uuid.uuid4()}@{DOMAIN}>"
    body = (
        f"From: {SENDER}\r\n"
        f"To: {RECIPIENT}\r\n"
        "Subject: Freehold Mail E2E\r\n"
        f"Message-ID: {message_id}\r\n"
        "\r\n"
        "End-to-end delivery test.\r\n"
    )

    t0 = time.time()
    smtp = smtplib.SMTP(HOST, SUBMISSION_PORT, timeout=20)
    smtp.ehlo("freeholdmail.test")
    if "auth" in smtp.esmtp_features:
        mechs = smtp.esmtp_features["auth"].upper()
        if "PLAIN" in mechs or "LOGIN" in mechs:
            fail(f"password AUTH offered before STARTTLS (advertised: {mechs.strip()})")
    smtp.starttls(context=TLS)
    smtp.ehlo("freeholdmail.test")
    smtp.login(SENDER, SENDER_PW)
    smtp.sendmail(SENDER, [RECIPIENT], body)
    smtp.quit()
    submit_s = time.time() - t0

    t1 = time.time()
    delivered = None
    while time.time() - t1 < DEADLINE_S:
        imap.select("INBOX")
        new = set(imap.uid("search", None, "ALL")[1][0].split()) - before
        if new:
            uid = sorted(new)[-1]
            parsed = email.message_from_bytes(imap.uid("fetch", uid, "(RFC822)")[1][0][1])
            delivered = parsed.get("Message-ID")
            break
        time.sleep(0.05)
    deliver_s = time.time() - t1
    imap.logout()

    if delivered is None:
        fail(f"no new message in {RECIPIENT} after {deliver_s:.1f}s (sent {message_id})")
    if delivered != message_id:
        fail(f"wrong message: sent {message_id}, received {delivered}")

    print(f"PASS  submit={submit_s:.3f}s  deliver={deliver_s:.3f}s  message_id={message_id}")


if __name__ == "__main__":
    main()
