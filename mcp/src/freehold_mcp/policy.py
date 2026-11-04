# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-11-04 — per-agent policy: who an agent is, what it may do, where.
"""Per-agent policy, loaded from an operator-owned TOML file.

The file is the single place an operator grants, narrows and revokes agent access. It is
re-read whenever its modification time changes, so a revocation takes effect on the next
request without restarting anything.

An agent never sees a mailbox credential. The policy names a file the *server* reads the
mailbox app password from; the agent only ever holds its own MCP token (static mode) or a
token issued to its own OAuth client (keycloak mode).
"""
from __future__ import annotations

import datetime as dt
import hashlib
import hmac
import os
import threading
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

# Scopes are a closed set. An unknown scope in the file is a configuration error, not
# something to ignore: a typo such as "mail:sned" must not silently grant nothing while the
# operator believes it granted send.
SCOPE_READ = "mail:read"
SCOPE_DRAFT = "mail:draft"
SCOPE_ORGANIZE = "mail:organize"
SCOPE_SEND = "mail:send"
KNOWN_SCOPES = frozenset({SCOPE_READ, SCOPE_DRAFT, SCOPE_ORGANIZE, SCOPE_SEND})

ALL_FOLDERS = "*"


class PolicyError(ValueError):
    """The policy file is malformed. Raised at load time, never at request time."""


@dataclass(frozen=True)
class Agent:
    id: str
    account: str
    credential_file: Path
    scopes: frozenset[str]
    folders: tuple[str, ...]
    send_to: tuple[str, ...] = ()
    max_sends_per_hour: int = 0
    token_sha256: str | None = None
    oauth_client_id: str | None = None
    expires: dt.datetime | None = None
    revoked: bool = False

    def allows(self, scope: str) -> bool:
        return scope in self.scopes

    def active(self, now: dt.datetime | None = None) -> bool:
        if self.revoked:
            return False
        if self.expires is None:
            return True
        return (now or dt.datetime.now(dt.timezone.utc)) < self.expires

    def may_send_to(self, address: str) -> bool:
        """True when any rule matches: an exact address, or an '@domain' suffix."""
        address = address.strip().lower()
        for rule in self.send_to:
            rule = rule.strip().lower()
            if rule.startswith("@") and address.endswith(rule):
                return True
            if address == rule:
                return True
        return False

    def mailbox_password(self) -> str:
        # Read on use rather than cached: rotating the app password in the file then
        # needs no restart either. Trailing newline stripped, nothing else.
        return self.credential_file.read_text(encoding="utf-8").rstrip("\r\n")


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _parse_expiry(value: object, agent_id: str) -> dt.datetime | None:
    if value is None:
        return None
    if isinstance(value, dt.datetime):
        if value.tzinfo is None:
            raise PolicyError(f"agent {agent_id!r}: expires must carry a timezone (use Z)")
        return value
    raise PolicyError(f"agent {agent_id!r}: expires must be a TOML datetime, got {value!r}")


def _parse_agent(raw: dict, base: Path) -> Agent:
    agent_id = raw.get("id")
    if not isinstance(agent_id, str) or not agent_id:
        raise PolicyError("every [[agent]] needs a non-empty string id")
    for key in ("account", "credential_file"):
        if not isinstance(raw.get(key), str) or not raw[key]:
            raise PolicyError(f"agent {agent_id!r}: {key} is required")
    scopes = frozenset(raw.get("scopes", []))
    unknown = scopes - KNOWN_SCOPES
    if unknown:
        raise PolicyError(f"agent {agent_id!r}: unknown scope(s) {sorted(unknown)}")
    if not scopes:
        raise PolicyError(f"agent {agent_id!r}: grants no scope")
    folders = tuple(raw.get("folders", []))
    if not folders:
        raise PolicyError(f"agent {agent_id!r}: folders is required ('*' means all)")
    send_to = tuple(raw.get("send_to", []))
    if SCOPE_SEND in scopes and not send_to:
        # Send without a recipient allow-list would be an open relay for whoever holds the
        # token. Refuse the configuration instead of defaulting to "anyone".
        raise PolicyError(f"agent {agent_id!r}: mail:send requires a send_to allow-list")
    token = raw.get("token_sha256")
    client = raw.get("oauth_client_id")
    if token is not None and (not isinstance(token, str) or len(token) != 64
                              or not all(c in "0123456789abcdefABCDEF" for c in token)):
        raise PolicyError(f"agent {agent_id!r}: token_sha256 must be 64 hex characters")
    credential = Path(raw["credential_file"])
    if not credential.is_absolute():
        credential = base / credential
    return Agent(
        id=agent_id,
        account=raw["account"],
        credential_file=credential,
        scopes=scopes,
        folders=folders,
        send_to=send_to,
        max_sends_per_hour=int(raw.get("max_sends_per_hour", 0)),
        token_sha256=token.lower() if token else None,
        oauth_client_id=client,
        expires=_parse_expiry(raw.get("expires"), agent_id),
        revoked=bool(raw.get("revoked", False)),
    )


def parse_policy(text: str, base: Path) -> dict[str, Agent]:
    try:
        data = tomllib.loads(text)
    except tomllib.TOMLDecodeError as exc:
        raise PolicyError(f"policy is not valid TOML: {exc}") from exc
    agents: dict[str, Agent] = {}
    tokens: set[str] = set()
    for raw in data.get("agent", []):
        agent = _parse_agent(raw, base)
        if agent.id in agents:
            raise PolicyError(f"duplicate agent id {agent.id!r}")
        if agent.token_sha256:
            if agent.token_sha256 in tokens:
                raise PolicyError(f"agent {agent.id!r}: token shared with another agent")
            tokens.add(agent.token_sha256)
        agents[agent.id] = agent
    return agents


@dataclass
class PolicyStore:
    """The policy file, re-read when it changes on disk."""

    path: Path
    _agents: dict[str, Agent] = field(default_factory=dict)
    _mtime: float = -1.0
    _lock: threading.Lock = field(default_factory=threading.Lock)

    def agents(self) -> dict[str, Agent]:
        mtime = os.stat(self.path).st_mtime
        with self._lock:
            if mtime != self._mtime:
                # A broken edit raises here and keeps refusing until fixed. Falling back to
                # the previous file would keep a just-revoked agent alive.
                self._agents = parse_policy(self.path.read_text("utf-8"), self.path.parent)
                self._mtime = mtime
            return self._agents

    def by_id(self, agent_id: str) -> Agent | None:
        return self.agents().get(agent_id)

    def by_token(self, token: str) -> Agent | None:
        digest = hash_token(token)
        for agent in self.agents().values():
            # Constant-time compare per candidate; the loop length leaks only the agent count.
            if agent.token_sha256 and hmac.compare_digest(agent.token_sha256, digest):
                return agent
        return None

    def by_oauth_client(self, client_id: str) -> Agent | None:
        for agent in self.agents().values():
            if agent.oauth_client_id and agent.oauth_client_id == client_id:
                return agent
        return None
