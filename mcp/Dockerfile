# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Novaza Solution JSC
# Last-touched: 2026-11-04 — MCP server image: digest-pinned base, hash-locked deps, non-root.
#
# The base is pinned by digest and every dependency by hash (pip --require-hashes), so a
# rebuild either produces the same inputs or fails. Dependabot proposes both updates.
FROM python:3.15-slim@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928 AS build
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /src
COPY requirements.txt .
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --require-hashes --no-deps -r requirements.txt

FROM python:3.15-slim@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928
LABEL org.opencontainers.image.title="freehold-mcp" \
      org.opencontainers.image.description="MCP server for Freehold Mail" \
      org.opencontainers.image.source="https://github.com/Novaza-ai/freeholdmail" \
      org.opencontainers.image.licenses="MIT"
COPY --from=build /opt/venv /opt/venv
# The package is copied, not pip-installed: building it would pull an unpinned build backend
# into an image whose every other input is pinned.
COPY src/freehold_mcp /opt/app/freehold_mcp
RUN useradd --system --uid 10001 --home-dir /nonexistent --shell /usr/sbin/nologin mcp \
 && mkdir -p /var/log/freehold-mcp && chown mcp /var/log/freehold-mcp
ENV PATH=/opt/venv/bin:$PATH PYTHONPATH=/opt/app PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 \
    FREEHOLD_MCP_HOST=0.0.0.0 FREEHOLD_MCP_PORT=8090 \
    FREEHOLD_MCP_POLICY=/etc/freehold-mcp/agents.toml \
    FREEHOLD_MCP_AUDIT_LOG=/var/log/freehold-mcp/audit.jsonl
USER 10001
EXPOSE 8090
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import os,urllib.request as u; u.urlopen(f'http://127.0.0.1:{os.environ[\"FREEHOLD_MCP_PORT\"]}/healthz', timeout=2)"]
ENTRYPOINT ["python", "-m", "freehold_mcp"]
CMD ["serve-http"]
