<!-- Last-touched: 2026-11-04 — package readme; the documentation lives in docs/MCP.md. -->
# freehold-mcp

MCP server for [Freehold Mail](https://github.com/Novaza-ai/freeholdmail): scoped, audited,
revocable agent access to one self-hosted mailbox over JMAP.

Read [docs/MCP.md](../docs/MCP.md): it covers setup, the tools, the policy file and the
threat model.

```bash
python -m pip install --require-hashes --no-deps -r requirements-dev.txt
python -m pytest -q                         # unit tests
../tests/test_e2e.sh --mcp                  # the real stack, end to end
```
