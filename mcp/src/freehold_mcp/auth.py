# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-11-04 — agent identity for the two auth modes and for stdio.
"""Who is calling.

Three ways in, one answer — an :class:`~freehold_mcp.policy.Agent` or a refusal:

* **stdio** — the operator started the process for one agent (``FREEHOLD_MCP_AGENT``). The
  process boundary is the trust boundary, as for any local MCP server.
* **static** (HTTP, base edition) — a per-agent bearer token, stored only as SHA-256 in the
  policy. There is no authorization server in the base edition, so this mode deliberately
  publishes **no** OAuth metadata: advertising discovery documents for an authorization
  server that does not exist would be a lie a client could act on.
* **keycloak** (HTTP, SSO edition) — the server is an OAuth 2.1 resource server. Tokens are
  JWTs from the realm, checked for signature (JWKS), issuer, audience/resource (RFC 8707)
  and expiry; the SDK publishes Protected Resource Metadata (RFC 9728) and answers 401 with
  ``WWW-Authenticate``. The token's client id selects the agent's policy, and the scopes
  that apply are the *intersection* of what the token carries and what the policy grants.
"""
from __future__ import annotations

import json
from collections.abc import Mapping
from typing import Any

import anyio
import jwt
from mcp.server.auth.middleware.auth_context import get_access_token
from mcp.server.auth.provider import AccessToken

from .policy import Agent, PolicyStore

# Set once at startup when serving stdio; None for HTTP.
_stdio_agent_id: str | None = None


class Identity:
    """The resolved caller for one tool call."""

    def __init__(self, agent: Agent, scopes: frozenset[str], transport: str) -> None:
        self.agent = agent
        self.scopes = scopes
        self.transport = transport


def set_stdio_agent(agent_id: str) -> None:
    global _stdio_agent_id
    _stdio_agent_id = agent_id


def _bearer(headers: Mapping[str, str] | None) -> str | None:
    if not headers:
        return None
    value = headers.get("authorization") or headers.get("Authorization") or ""
    if value[:7].lower() == "bearer " and value[7:].strip():
        return value[7:].strip()
    return None


def resolve(policy: PolicyStore, mode: str, headers: Mapping[str, str] | None) -> Identity | None:
    """Every lookup goes back to the policy store, so a revocation wins mid-session."""
    if _stdio_agent_id is not None:
        agent = policy.by_id(_stdio_agent_id)
        if agent is None or not agent.active():
            return None
        return Identity(agent, agent.scopes, "stdio")
    if mode == "static":
        # The token is verified against the SHA-256 in the policy — this is authentication,
        # not trusting a client-supplied header. The middleware already refused bad tokens
        # with 401; this repeats the check because the tool must not depend on that order.
        token = _bearer(headers)
        agent = policy.by_token(token) if token else None
        if agent is None or not agent.active():
            return None
        return Identity(agent, agent.scopes, "http-static")
    access = get_access_token()
    if access is None or not access.client_id:
        return None
    agent = policy.by_oauth_client(access.client_id)
    if agent is None or not agent.active():
        return None
    return Identity(agent, agent.scopes & frozenset(access.scopes), "http-oauth")


class StaticBearerMiddleware:
    """ASGI middleware: 401 unless the bearer token belongs to an active agent."""

    def __init__(self, app: Any, policy: PolicyStore, open_paths: frozenset[str]) -> None:
        self.app = app
        self.policy = policy
        self.open_paths = open_paths

    async def __call__(self, scope: dict, receive: Any, send: Any) -> None:
        if scope["type"] != "http" or scope["path"] in self.open_paths:
            await self.app(scope, receive, send)
            return
        header = dict(scope.get("headers") or []).get(b"authorization", b"").decode("latin-1")
        agent = None
        if header[:7].lower() == "bearer " and header[7:].strip():
            agent = self.policy.by_token(header[7:].strip())
        if agent is None or not agent.active():
            body = json.dumps({"error": "invalid_token"}).encode()
            await send({"type": "http.response.start", "status": 401, "headers": [
                (b"content-type", b"application/json"),
                (b"www-authenticate", b'Bearer error="invalid_token"'),
                (b"content-length", str(len(body)).encode())]})
            await send({"type": "http.response.body", "body": body})
            return
        await self.app(scope, receive, send)


class JwksTokenVerifier:
    """TokenVerifier for keycloak mode: signature, issuer, audience and expiry, or nothing."""

    def __init__(self, issuer: str, audience: str, resource: str) -> None:
        self.issuer = issuer.rstrip("/")
        self.audience = audience
        self.resource = resource
        self._jwks = jwt.PyJWKClient(f"{self.issuer}/protocol/openid-connect/certs",
                                     cache_keys=True, lifespan=300)

    def _decode(self, token: str) -> dict:
        key = self._jwks.get_signing_key_from_jwt(token)
        return jwt.decode(token, key.key, algorithms=["RS256", "ES256", "PS256"],
                          issuer=self.issuer, audience=self.audience,
                          options={"require": ["exp", "iss", "aud"]})

    async def verify_token(self, token: str) -> AccessToken | None:
        try:
            claims = await anyio.to_thread.run_sync(self._decode, token)
        except (jwt.PyJWTError, OSError):
            return None
        client_id = claims.get("azp") or claims.get("client_id")
        if not client_id:
            return None
        return AccessToken(
            token=token, client_id=client_id,
            scopes=str(claims.get("scope", "")).split(),
            expires_at=int(claims["exp"]), resource=self.resource,
            subject=claims.get("sub"), claims=claims)
