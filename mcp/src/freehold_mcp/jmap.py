# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-11-04 — minimal async JMAP client (RFC 8620 core, RFC 8621 mail).
"""Just enough JMAP for the tools in server.py, and nothing that guesses.

The session document's apiUrl carries whatever hostname the mail server believes it has
(measured on Stalwart 0.13.4: ``http://mail.qa.test:8080/jmap/`` when reached on loopback).
Only its *path* is used; scheme, host and port always come from the configured base URL, so
the client cannot be steered to another host by the server's own idea of its name.
"""
from __future__ import annotations

import urllib.parse
from dataclasses import dataclass
from typing import Any

import httpx2

CORE = "urn:ietf:params:jmap:core"
MAIL = "urn:ietf:params:jmap:mail"
SUBMISSION = "urn:ietf:params:jmap:submission"
USING = [CORE, MAIL, SUBMISSION]


class JmapError(RuntimeError):
    """The server answered, but not with what was asked for."""


@dataclass
class Mailbox:
    id: str
    name: str
    role: str | None
    parent_id: str | None
    total: int
    unread: int


class JmapClient:
    def __init__(self, base_url: str, username: str, password: str,
                 timeout: float = 20.0, verify: bool | str = True) -> None:
        self._base = urllib.parse.urlsplit(base_url.rstrip("/"))
        self._client = httpx2.AsyncClient(
            auth=httpx2.BasicAuth(username, password), timeout=timeout, verify=verify)
        self._api_url: str | None = None
        self.account_id: str | None = None

    async def aclose(self) -> None:
        await self._client.aclose()

    def _rebase(self, url: str) -> str:
        parts = urllib.parse.urlsplit(url)
        return urllib.parse.urlunsplit(
            (self._base.scheme, self._base.netloc, parts.path, parts.query, ""))

    async def session(self) -> None:
        url = urllib.parse.urlunsplit(
            (self._base.scheme, self._base.netloc, "/jmap/session", "", ""))
        resp = await self._client.get(url)
        if resp.status_code == 401:
            raise PermissionError("mailbox credential refused by the mail server")
        resp.raise_for_status()
        doc = resp.json()
        self._api_url = self._rebase(doc["apiUrl"])
        self.account_id = doc["primaryAccounts"][MAIL]

    async def call(self, *calls: tuple[str, dict[str, Any]]) -> list[tuple[str, dict, str]]:
        if self._api_url is None:
            await self.session()
        body = {
            "using": USING,
            "methodCalls": [[name, {"accountId": self.account_id, **args}, f"c{i}"]
                            for i, (name, args) in enumerate(calls)],
        }
        resp = await self._client.post(self._api_url, json=body)
        if resp.status_code == 401:
            raise PermissionError("mailbox credential refused by the mail server")
        resp.raise_for_status()
        responses = resp.json()["methodResponses"]
        for name, payload, _tag in responses:
            if name == "error":
                raise JmapError(f"{payload.get('type')}: {payload.get('description', '')}")
        return responses

    async def mailboxes(self) -> list[Mailbox]:
        (_, got, _), = await self.call(("Mailbox/get", {
            "ids": None,
            "properties": ["name", "role", "parentId", "totalEmails", "unreadEmails"]}))
        return [Mailbox(m["id"], m["name"], m.get("role"), m.get("parentId"),
                        m.get("totalEmails", 0), m.get("unreadEmails", 0))
                for m in got["list"]]

    async def identity(self, email: str) -> str:
        """The id of the sending identity for exactly ``email``, created if missing.

        A new Stalwart account has no identities (measured on 0.13.4: ``Identity/get`` returns
        ``[]``), and every webmail client creates one on first use. Creating it here is safe
        because the mail server only accepts an identity for an address the account owns
        (measured: ``invalidProperties``, "Invalid e-mail address." for anyone else's). There
        is no fallback to "the first identity": sending as an address the policy did not name
        is exactly the kind of guess this module refuses to make.
        """
        (_, got, _), = await self.call(("Identity/get", {"ids": None}))
        for ident in got["list"]:
            if ident.get("email", "").lower() == email.lower():
                return ident["id"]
        (_, made, _), = await self.call(("Identity/set", {
            "create": {"i": {"email": email, "name": email}}}))
        if "i" not in made.get("created", {}):
            # Stalwart 0.13 refuses an identity whose domain is not under a Public Suffix
            # List entry (e.g. *.test, *.internal) with only "Invalid e-mail address."
            why = (made.get("notCreated", {}).get("i") or {}).get("description", "refused")
            raise JmapError(f"cannot create a sending identity for {email}: {why} "
                            "(Stalwart requires a domain under a public suffix)")
        return made["created"]["i"]["id"]
