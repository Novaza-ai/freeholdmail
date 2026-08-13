#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-08-13 — new: fails when a pinned image falls behind its upstream line.
#
# SECURITY.md records that pin currency is a manual duty on this project, and that the duty
# was missed twice: the webmail sat below the patch floor for five High advisories, and the
# mail server below the floor for GHSA-8jqj-qj5p-v5rr. Dependabot cannot cover this, because
# compose refers to every image through an .env variable and there is no literal tag to parse.
# This is that missing check.
#
# What it does NOT do, deliberately: decide whether an advisory applies to the pinned version.
# GitHub's vulnerable_version_range has no lower bound, so it matches releases the advisory
# never applied to -- the trap documented in SECURITY.md weakness 6. Advisories are printed as
# context for a human to read; they never decide the exit code.
#
# Usage:
#   scripts/check_pins.py                  # check .env.example against scripts/pin_sources.json
#   scripts/check_pins.py --env FILE --sources FILE
#
# Exit codes:
#   0  every pin is current, or is behind with a valid acknowledgement
#   1  a pin is behind with no acknowledgement, or an acknowledgement has expired
#   2  a pin could not be checked at all (network, API, or unsupported registry)
#
# Exit 2 is a failure on purpose. A currency check that goes green when it could not reach
# upstream teaches you to trust a board that is measuring nothing.

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import date

TIMEOUT = 20
USER_AGENT = "freeholdmail-pin-currency-check"


def http_json(url, headers=None):
    """GET url and parse JSON. Raises on any failure -- callers turn that into exit 2."""
    request = urllib.request.Request(url)
    request.add_header("User-Agent", USER_AGENT)
    request.add_header("Accept", "application/json")
    for name, value in (headers or {}).items():
        request.add_header(name, value)
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        return json.loads(response.read().decode("utf-8"))


def github_headers():
    """Unauthenticated GitHub allows 60 requests an hour, which a scheduled run can exhaust."""
    token = os.environ.get("GITHUB_TOKEN", "")
    return {"Authorization": "Bearer " + token} if token else {}


def read_env(path):
    """Parse KEY=value lines. Not a shell parser: these files hold literals, not expansions."""
    values = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            values[key.strip()] = value.strip()
    return values


def version_key(text):
    """Sort key from the numeric runs in a version.

    '1.30.4-alpine' -> (1, 30, 4). Enough for every format this project pins, and it ignores
    the suffix rather than guessing an ordering for it -- which is why `line` must pin the
    suffix down when one matters.
    """
    return tuple(int(number) for number in re.findall(r"\d+", text))


def normalise(version):
    """Image tags here carry a leading v where upstream release tags sometimes do not."""
    return version.lstrip("vV")


def candidates_from_github(repo):
    releases = http_json(
        "https://api.github.com/repos/%s/releases?per_page=100" % repo,
        github_headers(),
    )
    return [
        release["tag_name"]
        for release in releases
        if not release.get("draft") and not release.get("prerelease")
    ]


def candidates_from_dockerhub(image):
    tags = []
    url = "https://hub.docker.com/v2/repositories/%s/tags?page_size=100" % image
    # Two pages is enough to see the current line on these images and bounds the request
    # count. If a line ever falls off the end, the check reports "no candidate" -- which is
    # exit 2, not a silent pass.
    for _ in range(2):
        page = http_json(url)
        tags.extend(result["name"] for result in page.get("results", []))
        url = page.get("next")
        if not url:
            break
    return tags


def current_digest(image, tag):
    """The manifest digest a `@sha256:` pin in compose refers to.

    Docker Hub's registry needs an anonymous pull token even for public images.
    """
    token = http_json(
        "https://auth.docker.io/token?service=registry.docker.io&scope=repository:%s:pull"
        % image
    )["token"]
    request = urllib.request.Request(
        "https://registry-1.docker.io/v2/%s/manifests/%s" % (image, tag)
    )
    request.add_header("User-Agent", USER_AGENT)
    request.add_header("Authorization", "Bearer " + token)
    request.add_header(
        "Accept",
        "application/vnd.oci.image.index.v1+json,"
        "application/vnd.docker.distribution.manifest.list.v2+json",
    )
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        digest = response.headers.get("Docker-Content-Digest")
    if not digest:
        raise RuntimeError("registry returned no Docker-Content-Digest for %s:%s" % (image, tag))
    return digest


def advisories_for(repo):
    """Published advisories, newest first. Context only -- never a pass/fail signal."""
    try:
        published = http_json(
            "https://api.github.com/repos/%s/security-advisories?per_page=5" % repo,
            github_headers(),
        )
    except (urllib.error.URLError, urllib.error.HTTPError, ValueError, OSError):
        # Many repositories publish none and some return 404 for the endpoint. This is
        # decoration on the report; it must never change the outcome.
        return []
    return [
        "%s (%s) %s"
        % (item.get("ghsa_id", "?"), item.get("severity", "?"), item.get("summary", ""))
        for item in published
        if isinstance(item, dict)
    ]


def pick_latest(component):
    """Highest candidate version allowed by this component's declared line."""
    source = component["source"]
    if source["kind"] == "github_releases":
        candidates = candidates_from_github(source["repo"])
    elif source["kind"] == "dockerhub_tags":
        candidates = candidates_from_dockerhub(source["image"])
    else:
        raise RuntimeError("unsupported source kind: %s" % source["kind"])

    line = component.get("line")
    if line:
        pattern = re.compile(line)
        candidates = [tag for tag in candidates if pattern.search(tag)]
    candidates = [tag for tag in candidates if re.search(r"\d", tag)]
    if not candidates:
        raise RuntimeError("no candidate version matched line %r" % (line or "(any)"))
    return max(candidates, key=lambda tag: version_key(normalise(tag)))


def check_exact(component, pinned):
    """Compare a one-release pin against the newest release its line allows."""
    latest = pick_latest(component)
    if version_key(normalise(pinned)) >= version_key(normalise(latest)):
        return "current", "pinned %s, newest in line %s" % (pinned, latest)
    return "behind", "pinned %s, upstream has %s" % (pinned, latest)


def check_floating(component, pinned_digest, tag):
    """A floating tag moves upstream; only the digest holds this install still."""
    source = component["source"]
    if source["kind"] != "dockerhub_tags":
        raise RuntimeError(
            "floating pins are only implemented for dockerhub_tags, not %s" % source["kind"]
        )
    upstream = current_digest(source["image"], tag)
    pinned = pinned_digest.lstrip("@")
    if pinned == upstream:
        return "current", "tag %s still resolves to the pinned digest" % tag
    return "behind", "tag %s now resolves to %s, pinned %s" % (tag, upstream, pinned)


def acknowledgement_state(component, today):
    """None, ('valid', text) or ('expired', text)."""
    ack = component.get("acknowledged_lag")
    if not ack:
        return None
    review_by = ack.get("review_by", "")
    try:
        deadline = date.fromisoformat(review_by)
    except ValueError:
        return ("expired", "acknowledged_lag has an unreadable review_by %r" % review_by)
    if today < deadline:
        return ("valid", "acknowledged until %s: %s" % (review_by, ack.get("reason", "")))
    return ("expired", "acknowledgement expired %s and must be re-argued: %s"
            % (review_by, ack.get("reason", "")))


def main():
    parser = argparse.ArgumentParser(description="Check pinned images against upstream.")
    here = os.path.dirname(os.path.abspath(__file__))
    parser.add_argument("--env", default=os.path.join(here, os.pardir, ".env.example"))
    parser.add_argument("--sources", default=os.path.join(here, "pin_sources.json"))
    parser.add_argument("--today", default="", help="override today's date (YYYY-MM-DD), for tests")
    arguments = parser.parse_args()

    today = date.fromisoformat(arguments.today) if arguments.today else date.today()
    with open(arguments.sources, encoding="utf-8") as handle:
        components = json.load(handle)["components"]
    env = read_env(arguments.env)

    behind, unknown, acknowledged, current = [], [], [], []

    for component in components:
        name = component["name"]
        pinned_version = env.get(component["version_var"], "")
        pinned_digest = env.get(component["digest_var"], "")
        if not pinned_version:
            unknown.append((name, "%s is not set in the env file" % component["version_var"]))
            continue

        try:
            if component.get("pin_style", "exact") == "floating":
                if not pinned_digest:
                    raise RuntimeError("%s is empty, so nothing holds this floating tag"
                                       % component["digest_var"])
                state, detail = check_floating(component, pinned_digest, pinned_version)
            else:
                state, detail = check_exact(component, pinned_version)
        except Exception as error:                       # noqa: BLE001 - see exit code 2
            unknown.append((name, "could not determine: %s" % error))
            continue

        if state == "current":
            current.append((name, detail))
            continue

        ack = acknowledgement_state(component, today)
        if ack and ack[0] == "valid":
            acknowledged.append((name, "%s -- %s" % (detail, ack[1])))
        elif ack:
            behind.append((name, "%s -- %s" % (detail, ack[1])))
        else:
            behind.append((name, detail))

    def report(title, rows, marker):
        if not rows:
            return
        print("\n%s" % title)
        for name, detail in rows:
            print("  %s %s: %s" % (marker, name, detail))

    report("Current", current, "OK  ")
    report("Behind, acknowledged (passes until review_by)", acknowledged, "NOTE")
    report("Behind", behind, "FAIL")
    report("Could not be checked", unknown, "STOP")

    if behind:
        print("\nAdvisories published upstream, for context only -- a range in this list does")
        print("NOT mean the pinned version is affected (SECURITY.md weakness 6):")
        for component in components:
            repo = (component.get("advisories") or {}).get("repo")
            if not repo or component["name"] not in [name for name, _ in behind]:
                continue
            for line in advisories_for(repo):
                print("  %s: %s" % (component["name"], line))

    print(
        "\n== result: %d current, %d acknowledged, %d behind, %d unchecked =="
        % (len(current), len(acknowledged), len(behind), len(unknown))
    )

    if unknown:
        print("A pin could not be checked. That is a failure, not a pass: this run measured"
              " less than it appears to.")
        return 2
    if behind:
        print("Re-pin and verify with tests/test_e2e.sh, or record an acknowledged_lag with a"
              " review_by date in scripts/pin_sources.json. Do not silence this by narrowing"
              " `line` to the version already pinned.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
