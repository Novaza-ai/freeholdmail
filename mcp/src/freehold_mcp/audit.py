# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-11-04 — append-only audit trail: which agent did what, when, with what result.
"""Audit trail.

One JSON object per line, appended, flushed and fsync'd before the tool returns, so a record
exists for every call the server answered — including the ones it refused. The record
answers the roadmap's question, "which agent sent this, on whose authority, when", without
storing message bodies: text is reduced to its length and SHA-256.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import threading
from pathlib import Path
from typing import Any

_BODY_KEYS = frozenset({"body", "text"})


def redact(arguments: dict[str, Any]) -> dict[str, Any]:
    """Keep what identifies the action, drop what is the content."""
    out: dict[str, Any] = {}
    for key, value in arguments.items():
        if key in _BODY_KEYS and isinstance(value, str):
            digest = hashlib.sha256(value.encode("utf-8")).hexdigest()
            out[key] = {"sha256": digest, "length": len(value)}
        else:
            out[key] = value
    return out


class AuditLog:
    def __init__(self, path: Path) -> None:
        self.path = path
        self._lock = threading.Lock()
        path.parent.mkdir(parents=True, exist_ok=True)

    def record(self, *, agent: str, transport: str, tool: str, outcome: str,
               arguments: dict[str, Any], reason: str | None = None,
               ids: list[str] | None = None, duration_ms: float | None = None) -> dict:
        entry = {
            "ts": dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds"),
            "agent": agent,
            "transport": transport,
            "tool": tool,
            "outcome": outcome,
            "arguments": redact(arguments),
        }
        if reason:
            entry["reason"] = reason
        if ids:
            entry["ids"] = ids
        if duration_ms is not None:
            entry["duration_ms"] = round(duration_ms, 1)
        line = json.dumps(entry, ensure_ascii=False, separators=(",", ":")) + "\n"
        with self._lock:
            # O_APPEND makes each write land at the end even with several writers; the lock
            # keeps lines from this process whole.
            fd = os.open(self.path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
            try:
                os.write(fd, line.encode("utf-8"))
                os.fsync(fd)
            finally:
                os.close(fd)
        return entry
