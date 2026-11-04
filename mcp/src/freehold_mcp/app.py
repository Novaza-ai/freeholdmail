# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-11-04 — HTTP app factory: stateless Streamable HTTP, auth, health.
"""Build the HTTP application for either auth mode."""
from __future__ import annotations

from typing import Any

from mcp.server.transport_security import TransportSecuritySettings
from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.routing import Route

from . import __version__
from .audit import AuditLog
from .auth import StaticBearerMiddleware
from .config import Settings
from .policy import PolicyStore
from .server import build_server

MCP_PATH = "/mcp"
HEALTH_PATH = "/healthz"


def build_app(settings: Settings) -> Any:
    policy = PolicyStore(settings.policy_path)
    policy.agents()  # refuse to start on a broken policy file
    audit = AuditLog(settings.audit_path)
    server = build_server(settings, policy, audit)

    security = TransportSecuritySettings(
        enable_dns_rebinding_protection=True,
        allowed_hosts=list(settings.allowed_hosts) or
        [f"127.0.0.1:{settings.port}", f"localhost:{settings.port}"],
        allowed_origins=[])
    app: Starlette = server.streamable_http_app(
        streamable_http_path=MCP_PATH, stateless_http=True, json_response=True,
        transport_security=security, host=settings.host)

    async def health(_: Request) -> JSONResponse:
        try:
            agents = len(policy.agents())
        except Exception:  # a broken policy means nothing is served; say so
            return JSONResponse({"status": "policy-error"}, status_code=503)
        return JSONResponse({"status": "ok", "version": __version__, "agents": agents})

    app.router.routes.append(Route(HEALTH_PATH, health, methods=["GET"]))
    if settings.auth_mode == "static":
        return StaticBearerMiddleware(app, policy, frozenset({HEALTH_PATH}))
    return app
