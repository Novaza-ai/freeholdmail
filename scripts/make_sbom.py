#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-08-13 — new: releases carried no artifacts at all, so a consumer had
# nothing to verify and no way to answer "what would this actually run on my machine?".
#
# This project ships no binaries. What it ships is a decision about WHICH images an operator
# will run, pinned to exact digests -- so that decision is the bill of materials, and an SBOM
# listing the five pinned images is a more honest description of this release than one
# listing the shell scripts would be.
#
# Nothing about the components is stated here. Image references come from the compose files,
# versions and digests from .env.example, and licences from scripts/pin_sources.json. This
# script only joins them: a new component appears in the SBOM by being added to those files,
# never by editing this one.
#
# Usage:
#   scripts/make_sbom.py --version v0.5.0 --created 2026-08-13T00:00:00Z > sbom.spdx.json
#
# Exit codes:
#   0  document written
#   2  the inputs disagree (an image with no pin, a pin with no component) -- a failure,
#      because an SBOM that quietly omits a component is worse than none at all.

import argparse
import json
import os
import re
import sys

IMAGE_LINE = re.compile(r"^\s*image:\s*(\S+)\s*$")
VAR = re.compile(r"\$\{([A-Z_]+)\}")
NAMESPACE = "https://github.com/Novaza-ai/freeholdmail"


def read_env(path):
    values = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            values[key] = value
    return values


def resolve_images(repo, env):
    """Every image reference the two editions would pull, with variables substituted."""
    images = []
    for name in ("docker-compose.yml", "docker-compose.sso.yml"):
        with open(os.path.join(repo, name), encoding="utf-8") as handle:
            for line in handle:
                match = IMAGE_LINE.match(line)
                if not match:
                    continue
                ref = match.group(1)
                missing = [v for v in VAR.findall(ref) if v not in env]
                if missing:
                    raise SystemExit("no value in .env.example for %s (in %s)"
                                     % (", ".join(missing), name))
                images.append(VAR.sub(lambda m: env[m.group(1)], ref))
    return images


def spdx_id(text):
    return "SPDXRef-Package-" + re.sub(r"[^A-Za-z0-9.-]", "-", text)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description="Emit an SPDX 2.3 SBOM of the pinned images.")
    parser.add_argument("--repo", default=os.path.join(here, os.pardir))
    parser.add_argument("--version", required=True, help="the release being described")
    parser.add_argument("--created", required=True,
                        help="RFC3339 timestamp; passed in so the document is reproducible")
    arguments = parser.parse_args()

    env = read_env(os.path.join(arguments.repo, ".env.example"))
    with open(os.path.join(arguments.repo, "scripts", "pin_sources.json"),
              encoding="utf-8") as handle:
        components = json.load(handle)["components"]

    # Join on the digest: it is the only value that appears in both the resolved image
    # reference and the component record, and it is what actually identifies the bytes.
    by_digest = {}
    for component in components:
        digest = env.get(component["digest_var"], "")
        if not digest:
            raise SystemExit("component %r has no digest in .env.example — refusing to emit "
                             "an SBOM that cannot identify what it describes" % component["name"])
        by_digest[digest.lstrip("@")] = component

    packages, relationships = [], []
    for image in resolve_images(arguments.repo, env):
        name, _, digest = image.partition("@")
        name, _, tag = name.partition(":")
        component = by_digest.get(digest)
        if component is None:
            raise SystemExit("image %s is not described in scripts/pin_sources.json" % image)
        identifier = spdx_id(name)
        packages.append({
            "SPDXID": identifier,
            "name": name,
            "versionInfo": tag,
            "downloadLocation": "NOASSERTION",
            "filesAnalyzed": False,
            "licenseConcluded": "NOASSERTION",
            "licenseDeclared": component.get("license", "NOASSERTION"),
            "supplier": "NOASSERTION",
            "checksums": [{"algorithm": "SHA256", "checksumValue": digest.split(":", 1)[1]}],
            "externalRefs": [{
                "referenceCategory": "PACKAGE-MANAGER",
                "referenceType": "purl",
                "referenceLocator": "pkg:oci/%s@%s" % (name.rsplit("/", 1)[-1], digest),
            }],
        })
        relationships.append({
            "spdxElementId": "SPDXRef-Package-freeholdmail",
            "relationshipType": "CONTAINS",
            "relatedSpdxElement": identifier,
        })

    if not packages:
        raise SystemExit("no images resolved — refusing to emit an empty SBOM")

    document = {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": "freeholdmail-%s" % arguments.version,
        "documentNamespace": "%s/sbom/%s" % (NAMESPACE, arguments.version),
        "creationInfo": {
            "created": arguments.created,
            "creators": ["Tool: scripts/make_sbom.py", "Organization: Novaza Solution JSC"],
        },
        "packages": [{
            "SPDXID": "SPDXRef-Package-freeholdmail",
            "name": "freeholdmail",
            "versionInfo": arguments.version,
            "downloadLocation": "%s/releases/tag/%s" % (NAMESPACE, arguments.version),
            "filesAnalyzed": False,
            "licenseConcluded": "NOASSERTION",
            "licenseDeclared": "MIT",
            "supplier": "Organization: Novaza Solution JSC",
        }] + packages,
        "relationships": [{
            "spdxElementId": "SPDXRef-DOCUMENT",
            "relationshipType": "DESCRIBES",
            "relatedSpdxElement": "SPDXRef-Package-freeholdmail",
        }] + relationships,
    }
    json.dump(document, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
