# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-11-04 — command line: serve over HTTP or stdio, mint agent tokens.
"""``freehold-mcp`` command line."""
from __future__ import annotations

import argparse
import os
import secrets
import sys

from . import __version__


def _serve_http() -> None:
    import uvicorn

    from .app import build_app
    from .config import Settings

    settings = Settings.from_env()
    uvicorn.run(build_app(settings), host=settings.host, port=settings.port,
                proxy_headers=False, server_header=False, log_level="info")


def _serve_stdio() -> None:
    from .audit import AuditLog
    from .auth import set_stdio_agent
    from .config import Settings
    from .policy import PolicyStore
    from .server import build_server

    agent_id = os.environ.get("FREEHOLD_MCP_AGENT", "").strip()
    if not agent_id:
        raise SystemExit("freehold-mcp: FREEHOLD_MCP_AGENT is required for stdio")
    settings = Settings.from_env()
    policy = PolicyStore(settings.policy_path)
    if policy.by_id(agent_id) is None:
        raise SystemExit(f"freehold-mcp: no agent {agent_id!r} in {settings.policy_path}")
    set_stdio_agent(agent_id)
    build_server(settings, policy, AuditLog(settings.audit_path)).run("stdio")


def _new_token() -> None:
    from .policy import hash_token

    token = secrets.token_urlsafe(32)
    # The token goes to the agent's operator once; only the hash goes in the policy.
    print(f"token        = {token}")
    print(f'token_sha256 = "{hash_token(token)}"')


def _hash_token() -> None:
    from .policy import hash_token

    token = sys.stdin.readline().strip()
    if not token:
        raise SystemExit("freehold-mcp: pass the token on stdin, not as an argument")
    print(hash_token(token))


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(prog="freehold-mcp", description=__doc__)
    parser.add_argument("--version", action="version", version=__version__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("serve-http", help="Streamable HTTP on FREEHOLD_MCP_HOST:PORT")
    sub.add_parser("serve-stdio", help="stdio, for the one agent in FREEHOLD_MCP_AGENT")
    sub.add_parser("new-token", help="mint an agent token and print its policy hash")
    sub.add_parser("hash-token", help="hash a token read from stdin")
    args = parser.parse_args(argv)
    {"serve-http": _serve_http, "serve-stdio": _serve_stdio,
     "new-token": _new_token, "hash-token": _hash_token}[args.command]()


if __name__ == "__main__":
    main()
