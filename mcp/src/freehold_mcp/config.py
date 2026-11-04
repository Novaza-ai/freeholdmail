# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-11-04 — every setting comes from the environment; nothing is hardcoded.
"""Runtime settings. Read once at startup; the policy file is what changes at runtime."""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def _require(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"freehold-mcp: {name} is required")
    return value


def _bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None or raw.strip() == "":
        return default
    if raw.strip().lower() in {"1", "true", "yes", "on"}:
        return True
    if raw.strip().lower() in {"0", "false", "no", "off"}:
        return False
    raise SystemExit(f"freehold-mcp: {name} must be true or false, got {raw!r}")


@dataclass(frozen=True)
class Settings:
    policy_path: Path
    audit_path: Path
    jmap_url: str
    jmap_verify_tls: bool
    auth_mode: str
    host: str
    port: int
    allowed_hosts: tuple[str, ...]
    oidc_issuer: str | None
    resource_url: str | None
    audience: str | None
    max_body_chars: int

    @classmethod
    def from_env(cls) -> "Settings":
        mode = os.environ.get("FREEHOLD_MCP_AUTH", "static").strip().lower()
        if mode not in {"static", "keycloak"}:
            raise SystemExit("freehold-mcp: FREEHOLD_MCP_AUTH must be 'static' or 'keycloak'")
        issuer = resource = None
        if mode == "keycloak":
            issuer = _require("FREEHOLD_MCP_OIDC_ISSUER")
            resource = _require("FREEHOLD_MCP_RESOURCE_URL")
        hosts = tuple(h.strip() for h in os.environ.get("FREEHOLD_MCP_ALLOWED_HOSTS", "")
                      .split(",") if h.strip())
        return cls(
            policy_path=Path(_require("FREEHOLD_MCP_POLICY")),
            audit_path=Path(_require("FREEHOLD_MCP_AUDIT_LOG")),
            jmap_url=_require("FREEHOLD_MCP_JMAP_URL"),
            jmap_verify_tls=_bool("FREEHOLD_MCP_JMAP_VERIFY_TLS", True),
            auth_mode=mode,
            host=os.environ.get("FREEHOLD_MCP_HOST", "127.0.0.1"),
            port=int(os.environ.get("FREEHOLD_MCP_PORT", "8090")),
            allowed_hosts=hosts,
            oidc_issuer=issuer,
            resource_url=resource,
            audience=os.environ.get("FREEHOLD_MCP_AUDIENCE") or resource,
            max_body_chars=int(os.environ.get("FREEHOLD_MCP_MAX_BODY_CHARS", "20000")),
        )
