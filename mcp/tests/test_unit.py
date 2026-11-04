# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-11-04 — unit tests: policy, auth, audit, rate limit, scope, JMAP client.
"""Fast tests with no mail server. The end-to-end proof is tests/e2e_mcp.py."""
from __future__ import annotations

import asyncio
import json
import os
import stat
import time
from pathlib import Path

import httpx2
import pytest
from mcp.server.mcpserver.exceptions import ToolError

from freehold_mcp import auth
from freehold_mcp.audit import AuditLog, redact
from freehold_mcp.jmap import JmapClient, JmapError, Mailbox
from freehold_mcp.policy import PolicyError, PolicyStore, hash_token, parse_policy
from freehold_mcp.server import Scope, SendRateLimiter, _check_addresses, html_to_text

TOKEN = "t" * 43
BASE = f'''
[[agent]]
id = "a"
account = "a@example.com"
credential_file = "a.pw"
scopes = ["mail:read", "mail:send"]
folders = ["inbox"]
send_to = ["bob@example.com", "@partner.example"]
token_sha256 = "{hash_token(TOKEN)}"
'''


def policy_file(tmp_path: Path, text: str = BASE) -> PolicyStore:
    (tmp_path / "agents.toml").write_text(text)
    (tmp_path / "a.pw").write_text("secret\n")
    return PolicyStore(tmp_path / "agents.toml")


# --------------------------------------------------------------------------- policy

@pytest.mark.parametrize("edit, message", [
    (lambda s: s.replace('"mail:send"]', '"mail:sned"]'), "unknown scope"),
    (lambda s: s.replace('["mail:read", "mail:send"]', "[]"), "grants no scope"),
    (lambda s: s.replace('folders = ["inbox"]\n', ""), "folders is required"),
    (lambda s: s.replace('send_to = ["bob@example.com", "@partner.example"]\n', ""),
     "requires a send_to"),
    (lambda s: s.replace(hash_token(TOKEN), "abc"), "64 hex"),
    (lambda s: s.replace(hash_token(TOKEN), "z" * 64), "64 hex"),
    (lambda s: s + s, "duplicate agent id"),
    (lambda s: s + s.replace('id = "a"', 'id = "b"'), "token shared"),
    (lambda s: s + 'expires = 2030-01-01T00:00:00\n', "timezone"),
    (lambda s: s + "[[[", "not valid TOML"),
])
def test_policy_refuses_dangerous_or_broken_config(edit, message):
    with pytest.raises(PolicyError, match=message):
        parse_policy(edit(BASE), Path("/"))


def test_send_allow_list_is_exact_or_domain_suffix():
    agent = parse_policy(BASE, Path("/"))["a"]
    assert agent.may_send_to("BOB@example.com")
    assert agent.may_send_to("x@partner.example")
    assert not agent.may_send_to("x@evilpartner.example")
    assert not agent.may_send_to("bob@example.com.evil.example")
    assert not agent.may_send_to("x@sub.partner.example")


def test_expiry_and_revocation(tmp_path):
    past = BASE + "expires = 2000-01-01T00:00:00Z\n"
    assert not parse_policy(past, Path("/"))["a"].active()
    assert not parse_policy(BASE + "revoked = true\n", Path("/"))["a"].active()
    assert parse_policy(BASE, Path("/"))["a"].active()


def test_policy_hot_reload_and_broken_edit_keeps_refusing(tmp_path):
    store = policy_file(tmp_path)
    assert store.by_token(TOKEN).id == "a"
    path = tmp_path / "agents.toml"
    path.write_text(BASE + "revoked = true\n")
    os.utime(path, (time.time() + 5, time.time() + 5))
    assert not store.by_token(TOKEN).active()
    path.write_text("[[[broken")
    os.utime(path, (time.time() + 10, time.time() + 10))
    with pytest.raises(PolicyError):
        store.by_token(TOKEN)


def test_credential_is_read_from_file_relative_to_policy(tmp_path):
    store = policy_file(tmp_path)
    assert store.by_id("a").mailbox_password() == "secret"


# --------------------------------------------------------------------------- auth

def test_static_resolve_requires_the_real_token(tmp_path):
    store = policy_file(tmp_path)
    ident = auth.resolve(store, "static", {"authorization": f"Bearer {TOKEN}"})
    assert ident.agent.id == "a" and ident.transport == "http-static"
    assert auth.resolve(store, "static", {"authorization": "Bearer nope"}) is None
    assert auth.resolve(store, "static", {"x-agent": "a"}) is None
    assert auth.resolve(store, "static", None) is None


def test_static_middleware_401s_and_leaves_health_open(tmp_path):
    store = policy_file(tmp_path)
    seen = []

    async def app(scope, receive, send):
        seen.append(scope["path"])

    mw = auth.StaticBearerMiddleware(app, store, frozenset({"/healthz"}))
    sent = []

    async def send(msg):
        sent.append(msg)

    def http(path, header=None):
        headers = [(b"authorization", header.encode())] if header else []
        return {"type": "http", "path": path, "headers": headers}

    asyncio.run(mw(http("/mcp"), None, send))
    assert sent[0]["status"] == 401
    assert (b"www-authenticate", b'Bearer error="invalid_token"') in sent[0]["headers"]
    asyncio.run(mw(http("/healthz"), None, send))
    asyncio.run(mw(http("/mcp", f"Bearer {TOKEN}"), None, send))
    assert seen == ["/healthz", "/mcp"]


def test_stdio_identity_follows_policy_revocation(tmp_path):
    store = policy_file(tmp_path)
    auth.set_stdio_agent("a")
    try:
        assert auth.resolve(store, "static", None).transport == "stdio"
        path = tmp_path / "agents.toml"
        path.write_text(BASE + "revoked = true\n")
        os.utime(path, (time.time() + 5, time.time() + 5))
        assert auth.resolve(store, "static", None) is None
    finally:
        auth._stdio_agent_id = None


# --------------------------------------------------------------------------- audit

def test_audit_redacts_bodies_and_is_owner_only(tmp_path):
    log = AuditLog(tmp_path / "audit.jsonl")
    log.record(agent="a", transport="t", tool="mail_create_draft", outcome="ok",
               arguments={"to": ["b@example.com"], "body": "secret words"}, ids=["x"])
    raw = (tmp_path / "audit.jsonl").read_text()
    assert "secret words" not in raw
    entry = json.loads(raw)
    assert entry["arguments"]["body"]["length"] == 12
    assert stat.S_IMODE((tmp_path / "audit.jsonl").stat().st_mode) == 0o600
    assert redact({"text": "x", "folder": "Inbox"})["folder"] == "Inbox"


# --------------------------------------------------------------------------- server helpers

def test_rate_limiter_window_and_release():
    rl = SendRateLimiter()
    assert rl.allow("a", 2, now=0) and rl.allow("a", 2, now=1)
    assert not rl.allow("a", 2, now=2)
    rl.release("a")  # the second send failed: its slot comes back
    assert rl.allow("a", 2, now=3)
    assert rl.allow("a", 2, now=3601)  # the first slot expired
    assert rl.allow("b", 0, now=0)  # 0 = unlimited


def test_address_validation_refuses_display_names_and_odd_forms():
    assert _check_addresses(["Bob@Example.com"]) == ["bob@example.com"]
    for bad in ["Bob <bob@example.com>", "a@b@example.com", "bob", "\"x y\"@example.com",
                "bob@example.com, eve@evil.example"]:
        with pytest.raises(ToolError):
            _check_addresses([bad])


def test_scope_by_name_or_role_and_star():
    boxes = [Mailbox("1", "Inbox", "inbox", None, 0, 0),
             Mailbox("2", "Private", None, None, 0, 0),
             Mailbox("3", "Entwürfe", "drafts", None, 0, 0)]
    scope = Scope(("inbox", "drafts"), boxes)
    assert scope.allowed == {"1", "3"}
    assert not scope.visible({"2": True})
    assert scope.visible({"2": True, "1": True})
    assert Scope(("*",), boxes).allowed == {"1", "2", "3"}


def test_html_to_text_drops_script_and_style():
    text = html_to_text("<style>p{}</style><p>Hello</p><script>evil()</script><p>World</p>")
    assert "evil" not in text and "Hello" in text and "World" in text


# --------------------------------------------------------------------------- JMAP client

def jmap_with(handler) -> JmapClient:
    client = JmapClient("https://mail.example.com", "a@example.com", "pw")
    client._client = httpx2.AsyncClient(transport=httpx2.MockTransport(handler))
    return client


SESSION = {"apiUrl": "http://internal-name:8080/jmap/",
           "primaryAccounts": {"urn:ietf:params:jmap:mail": "acc"}}


def test_api_url_host_is_never_taken_from_the_server():
    hits = []

    def handler(request):
        hits.append(str(request.url))
        if request.url.path == "/jmap/session":
            return httpx2.Response(200, json=SESSION)
        reply = [["Mailbox/get", {"list": []}, "c0"]]
        return httpx2.Response(200, json={"methodResponses": reply})
    asyncio.run(jmap_with(handler).mailboxes())
    assert hits == ["https://mail.example.com/jmap/session", "https://mail.example.com/jmap/"]


def test_identity_is_created_only_for_the_named_address():
    calls = []

    def handler(request):
        if request.url.path == "/jmap/session":
            return httpx2.Response(200, json=SESSION)
        method = json.loads(request.content)["methodCalls"][0]
        calls.append(method[0])
        if method[0] == "Identity/get":
            return httpx2.Response(200, json={"methodResponses": [
                ["Identity/get", {"list": [{"id": "i0", "email": "other@example.com"}]}, "c0"]]})
        assert method[1]["create"]["i"]["email"] == "a@example.com"
        return httpx2.Response(200, json={"methodResponses": [
            ["Identity/set", {"created": {"i": {"id": "i1"}}}, "c0"]]})
    assert asyncio.run(jmap_with(handler).identity("a@example.com")) == "i1"
    assert calls == ["Identity/get", "Identity/set"]


def test_jmap_errors_and_401_surface():
    def err(request):
        if request.url.path == "/jmap/session":
            return httpx2.Response(200, json=SESSION)
        return httpx2.Response(200, json={"methodResponses": [
            ["error", {"type": "forbidden"}, "c0"]]})
    with pytest.raises(JmapError, match="forbidden"):
        asyncio.run(jmap_with(err).mailboxes())
    with pytest.raises(PermissionError):
        asyncio.run(jmap_with(lambda r: httpx2.Response(401)).mailboxes())


# --------------------------------------------------------------------------- tools, in process

class FakeJmap:
    """Enough of a mailbox for mail_send: one draft, and a server that will not send."""

    def __init__(self, *args, **kwargs):
        pass

    async def aclose(self):
        pass

    async def mailboxes(self):
        return [Mailbox("d", "Drafts", "drafts", None, 1, 0),
                Mailbox("s", "Sent", "sent", None, 0, 0)]

    async def call(self, *calls):
        name, _ = calls[0]
        assert name == "Email/get", name
        return [(name, {"list": [{"id": "m1", "mailboxIds": {"d": True},
                                  "keywords": {"$draft": True},
                                  "from": [{"email": "a@example.com"}],
                                  "to": [{"email": "bob@example.com"}]}]}, "c0")]

    async def identity(self, email):
        raise JmapError("cannot create a sending identity")


def test_failed_send_gives_its_rate_limit_slot_back(tmp_path, monkeypatch):
    from mcp import Client

    from freehold_mcp import server as srv
    from freehold_mcp.config import Settings
    store = policy_file(tmp_path, BASE + "max_sends_per_hour = 1\n")
    settings = Settings(policy_path=tmp_path / "agents.toml", audit_path=tmp_path / "a.log",
                        jmap_url="http://unused", jmap_verify_tls=True, auth_mode="static",
                        host="127.0.0.1", port=0, allowed_hosts=(), oidc_issuer=None,
                        resource_url=None, audience=None, max_body_chars=1000)
    monkeypatch.setattr(srv, "JmapClient", FakeJmap)
    server = srv.build_server(settings, store, AuditLog(settings.audit_path))

    async def send_twice():
        async with Client(server) as client:
            return [await client.call_tool("mail_send", {"draft_id": "m1"}) for _ in range(2)]
    auth.set_stdio_agent("a")
    try:
        results = asyncio.run(send_twice())
    finally:
        auth._stdio_agent_id = None
    texts = [" ".join(c.text for c in r.content) for r in results]
    # Both attempts fail for the real reason. Without the refund the second one would read
    # "send limit reached" — a send that never happened would have used up the hour.
    assert all(r.is_error for r in results)
    assert all("sending identity" in t for t in texts), texts
    outcomes = [json.loads(x)["outcome"] for x in settings.audit_path.read_text().splitlines()]
    assert outcomes == ["error", "error"]


# --------------------------------------------------------------------------- keycloak mode

def _keypair():
    from cryptography.hazmat.primitives.asymmetric import rsa
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return key, key.public_key()


def test_jwks_verifier_checks_signature_issuer_audience_expiry(monkeypatch):
    import jwt as pyjwt
    issuer, aud = "https://id.example.com/realms/mail", "https://mcp.example.com/mcp"
    private, public = _keypair()
    other, _ = _keypair()
    verifier = auth.JwksTokenVerifier(issuer, aud, aud)

    class Key:
        key = public
    monkeypatch.setattr(verifier._jwks, "get_signing_key_from_jwt", lambda token: Key)
    now = int(time.time())

    def token(signer=private, **over):
        claims = {"iss": issuer, "aud": aud, "exp": now + 300, "azp": "triage-bot",
                  "sub": "u1", "scope": "mail:read mail:send"}
        claims.update(over)
        return pyjwt.encode({k: v for k, v in claims.items() if v is not None}, signer,
                            algorithm="RS256")

    good = asyncio.run(verifier.verify_token(token()))
    assert good.client_id == "triage-bot" and good.scopes == ["mail:read", "mail:send"]
    for bad in (token(aud="https://other.example.com"), token(iss="https://evil.example.com"),
                token(exp=now - 10), token(signer=other), token(azp=None), "not-a-jwt"):
        assert asyncio.run(verifier.verify_token(bad)) is None


def test_oauth_scopes_are_the_intersection_of_token_and_policy(tmp_path, monkeypatch):
    from mcp.server.auth.provider import AccessToken
    store = policy_file(tmp_path, BASE + 'oauth_client_id = "triage-bot"\n')
    token = AccessToken(token="t", client_id="triage-bot", scopes=["mail:read", "mail:draft"])
    monkeypatch.setattr(auth, "get_access_token", lambda: token)
    ident = auth.resolve(store, "keycloak", None)
    # policy grants read+send, token carries read+draft: only read survives
    assert ident.scopes == frozenset({"mail:read"}) and ident.transport == "http-oauth"
    monkeypatch.setattr(auth, "get_access_token", lambda: None)
    assert auth.resolve(store, "keycloak", None) is None


def test_dates_are_sent_as_utc():
    from datetime import datetime, timedelta, timezone

    from freehold_mcp.server import _utc
    assert _utc(datetime(2026, 1, 2, 3, 4, 5)) == "2026-01-02T03:04:05Z"
    plus7 = timezone(timedelta(hours=7))
    assert _utc(datetime(2026, 1, 2, 10, 0, 0, tzinfo=plus7)) == "2026-01-02T03:00:00Z"


def test_unexpected_failure_is_audited_and_not_leaked(tmp_path, monkeypatch):
    from mcp import Client

    from freehold_mcp import server as srv
    from freehold_mcp.config import Settings

    class Down(FakeJmap):
        async def mailboxes(self):
            raise ConnectionError("connect to 10.0.0.7:8080 refused")
    store = policy_file(tmp_path)
    settings = Settings(policy_path=tmp_path / "agents.toml", audit_path=tmp_path / "a.log",
                        jmap_url="http://unused", jmap_verify_tls=True, auth_mode="static",
                        host="127.0.0.1", port=0, allowed_hosts=(), oidc_issuer=None,
                        resource_url=None, audience=None, max_body_chars=1000)
    monkeypatch.setattr(srv, "JmapClient", Down)
    server = srv.build_server(settings, store, AuditLog(settings.audit_path))

    async def call():
        async with Client(server) as client:
            return await client.call_tool("mail_list_folders", {})
    auth.set_stdio_agent("a")
    try:
        result = asyncio.run(call())
    finally:
        auth._stdio_agent_id = None
    text = " ".join(c.text for c in result.content)
    assert result.is_error and "unavailable" in text and "10.0.0.7" not in text
    entry = json.loads(settings.audit_path.read_text())
    assert entry["outcome"] == "error" and "ConnectionError" in entry["reason"]
