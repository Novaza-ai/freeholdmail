#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-08-13 — binaries are scanned too, via their printable runs. They used to
# be skipped with a comment saying they were "covered by the metadata audit"; no such audit
# existed anywhere in this repository, so the files most likely to carry metadata nobody reads
# were the only ones nothing looked at. The claim is now the code.
#
# A public repository is a published surface, and so is its history. This project shipped a
# maintainer's account billing tier in SECURITY.md on 2026-08-13 and the manual pre-push
# checklist did not catch it, twice, because that checklist is a fixed list of things somebody
# thought to forbid. This check inverts that: it asserts what is ALLOWED and fails on anything
# else, so the categories nobody thought of are covered by construction.
#
# Usage:
#   scripts/check_disclosure.py                # the working tree (what CI runs)
#   scripts/check_disclosure.py --history      # every commit ever made, for a periodic audit
#
# Exit codes:
#   0  nothing outside the allow-list
#   1  something outside the allow-list was found
#   2  the check could not run (missing policy, unreadable tree) -- a failure, not a pass

import argparse
import json
import os
import re
import subprocess
import sys

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
# Hosts are only read from real URLs. A bare word with no dot is a placeholder, not a host.
URL_HOST = re.compile(r"https?://([A-Za-z0-9._-]*[A-Za-z0-9_-]\.[A-Za-z0-9._-]*[A-Za-z0-9_-])")
IPV4 = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")

# Loopback, link-local, the RFC 1918 ranges, and the RFC 5737 documentation ranges. Anything
# else is somebody's real address.
PRIVATE_IPV4 = re.compile(
    r"^(?:127\.|0\.0\.0\.0$|10\.|192\.168\.|169\.254\.|172\.(?:1[6-9]|2\d|3[01])\.|"
    r"192\.0\.2\.|198\.51\.100\.|203\.0\.113\.|255\.255\.255)"
)


# Version strings, durations and the like parse as dotted quads; only treat something as an
# address when all four parts are in range.
def is_ipv4(text):
    parts = text.split(".")
    return len(parts) == 4 and all(p.isdigit() and 0 <= int(p) <= 255 for p in parts)


def run(*argv):
    result = subprocess.run(argv, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError("%s failed: %s" % (" ".join(argv), result.stderr.strip()))
    return result.stdout


# Long enough to be a word, a path or a host; short enough not to miss a bare domain.
PRINTABLE_RUN = re.compile(rb"[\x20-\x7e]{6,}")


def tracked_files(repo):
    for name in run("git", "-C", repo, "ls-files").splitlines():
        path = os.path.join(repo, name)
        try:
            with open(path, encoding="utf-8") as handle:
                yield name, handle.read()
            continue
        except UnicodeDecodeError:
            pass  # not text -- fall through and scan it as a binary
        except (IsADirectoryError, FileNotFoundError):
            continue
        # A binary publishes whatever strings it embeds: EXIF, an author name, the hostname
        # of the machine that produced it, an absolute path from someone's home directory.
        # This used to be skipped with a comment claiming "binaries are covered by the
        # metadata audit" -- there was no such audit anywhere in the repository, so the only
        # files that can carry metadata nobody reads were the only files nothing checked.
        try:
            with open(path, "rb") as handle:
                blob = handle.read()
        except (IsADirectoryError, FileNotFoundError):
            continue
        yield name, "\n".join(m.group().decode("ascii")
                              for m in PRINTABLE_RUN.finditer(blob))


def history_blobs(repo):
    """Every version of every text file in every commit."""
    for commit in run("git", "-C", repo, "rev-list", "--all").split():
        listing = run("git", "-C", repo, "ls-tree", "-r", "--name-only", commit).splitlines()
        for name in listing:
            try:
                yield "%s:%s" % (commit[:7], name), run("git", "-C", repo, "show",
                                                        "%s:%s" % (commit, name))
            except (RuntimeError, UnicodeDecodeError):
                continue


# Two files in this repository exist to RECORD findings, so they necessarily quote the very
# patterns they are about: the policy states its own forbidden patterns, and the baseline
# repeats each accepted finding's explanation verbatim. Matching those rules against these two
# reports the rules as violations of themselves. Only the forbidden-pattern rules are skipped —
# the email, host and address allow-lists still apply, so nothing private can be smuggled in by
# hiding it in either file.
SELF_REFERENTIAL = ("disclosure_policy.json", "disclosure_history_baseline.json")


def scan(sources, policy, policy_name=""):
    emails = set(policy["allowed_email_domains"])
    hosts = set(policy["allowed_hosts"])
    forbidden = [(re.compile(rule["pattern"]), rule["why"])
                 for rule in policy["forbidden_patterns"]]
    findings = []

    for where, text in sources:
        # See SELF_REFERENTIAL above for why exactly two files are exempt from the rules, and
        # why the allow-lists below still apply to them. policy_name is honoured as well, so a
        # policy passed from a non-default path is still recognised as itself.
        names = SELF_REFERENTIAL + ((policy_name,) if policy_name else ())
        rules = [] if any(where.endswith(name) for name in names) else forbidden
        for match in EMAIL.finditer(text):
            domain = match.group(0).split("@", 1)[1].lower().rstrip(".")
            if domain not in emails:
                findings.append((where, "email domain not on the allow-list: %s" % match.group(0)))
        for match in URL_HOST.finditer(text):
            host = match.group(1).lower().rstrip(".")
            # Exact match, never a suffix: allowing "novaza.ai" must not silently allow
            # "internal-service.novaza.ai".
            if host not in hosts:
                findings.append((where, "host not on the allow-list: %s" % host))
        for match in IPV4.finditer(text):
            address = match.group(0)
            if is_ipv4(address) and not PRIVATE_IPV4.match(address):
                findings.append((where, "public IP address: %s" % address))
        for pattern, why in rules:
            if pattern.search(text):
                findings.append((where, "forbidden pattern %s — %s" % (pattern.pattern, why)))
    return findings


def main():
    parser = argparse.ArgumentParser(description="Fail on anything outside the publish allow-list.")
    here = os.path.dirname(os.path.abspath(__file__))
    parser.add_argument("--repo", default=os.path.join(here, os.pardir))
    parser.add_argument("--policy", default=os.path.join(here, "disclosure_policy.json"))
    parser.add_argument("--history", action="store_true",
                        help="scan every commit, not just the working tree")
    parser.add_argument("--baseline",
                        help="JSON file of already-accepted findings; only NEW ones fail")
    arguments = parser.parse_args()

    try:
        with open(arguments.policy, encoding="utf-8") as handle:
            policy = json.load(handle)
        sources = list(history_blobs(arguments.repo) if arguments.history
                       else tracked_files(arguments.repo))
    except (OSError, ValueError, RuntimeError) as error:
        print("could not run the disclosure check: %s" % error)
        print("That is a failure, not a pass: this run measured nothing.")
        return 2

    if not sources:
        print("no files were scanned — refusing to report success")
        return 2

    # Published history cannot be edited away: rewriting it does not remove the old blobs,
    # which stay reachable by SHA until the host garbage-collects them on request. So the
    # honest treatment of a finding in a commit that is already public is to RECORD it, not
    # to hide it — and then to fail on anything that was not recorded. A scan that is
    # permanently red teaches everyone to ignore it, which is how the next one gets missed.
    accepted = set()
    if arguments.baseline:
        try:
            with open(arguments.baseline, encoding="utf-8") as handle:
                accepted = {tuple(entry) for entry in json.load(handle)["accepted"]}
        except (OSError, ValueError, KeyError, TypeError) as error:
            print("could not read the baseline: %s" % error)
            print("That is a failure, not a pass: this run measured nothing.")
            return 2

    findings = scan(sources, policy, os.path.basename(arguments.policy))
    seen, known = set(), set()
    for where, detail in findings:
        key = (where, detail)
        if key in seen or key in known:
            continue
        if key in accepted:
            known.add(key)
        else:
            seen.add(key)
            print("  LEAK  %s: %s" % (where, detail))

    # In history mode a source is one version of one file, not one commit. Saying "commits"
    # here would report a number far larger than the repository has.
    scope = "file versions across all commits" if arguments.history else "tracked files"
    print("== disclosure: %d new finding(s), %d already accepted, across %d %s =="
          % (len(seen), len(known), len(sources), scope))
    # A baseline entry that no longer matches anything is a stale exemption: it would keep
    # excusing a finding that has moved or changed shape. Report it rather than carry it.
    stale = accepted - known
    for where, detail in sorted(stale):
        print("  STALE BASELINE  %s: %s" % (where, detail))
    if seen:
        print("Each finding is either something that should not be public, or a value that is")
        print("intended to be public and belongs in scripts/disclosure_policy.json. Decide which;")
        print("do not widen the policy to silence a real leak.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
