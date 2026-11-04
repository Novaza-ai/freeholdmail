<!-- Last-touched: 2026-11-04 — new: the test suite recorded on a fresh clone of main, one video per step. -->
# Verification on video

These videos show this repository's own tests running, in the order a release is checked. They
were recorded on a **fresh clone of `main` at `b96d612`** with no local changes, and every
command on screen is one you can run yourself. A green result is only worth something if the
same suite goes red when the code is wrong, so step 5 breaks the security checks one at a time
and shows each failure.

| Step | What it checks | Command | Result on screen |
|---|---|---|---|
| 1 | Compose files, container hardening, the MCP overlay, translations, disclosure | `tests/test_config.sh` | 215 passed, 0 failed |
| 2 | The MCP server's policy, both auth modes (real RS256 JWTs), audit, rate limit | `python -m pytest -v` in `mcp/` | 30 passed |
| 3 | A throwaway mail server and webmail; a real message sent and read back | `tests/test_e2e.sh` | 14 passed, 0 failed |
| 4 | The MCP image built from `mcp/Dockerfile`, three agents, a real MCP client | `tests/test_e2e.sh --mcp` | 43 MCP checks and 17 harness checks, 0 failed |
| 5 | Each security check removed in turn; the suite must fail | see below | 4 of 4 mutations caught |
| 6 | The SSO edition: Keycloak and PostgreSQL overlay, OIDC discovery | `tests/test_e2e.sh --sso` | 15 passed, 0 failed |
| 7 | The mailbox after step 4, in the bundled webmail | browser walkthrough | 26 audit lines for 26 tool calls |

## 1. Static suite

https://github.com/user-attachments/assets/a3a2e4b6-0344-4115-9e7a-ac5ed0e73a09

## 2. MCP server unit tests

https://github.com/user-attachments/assets/9282c7df-195f-4de4-8aa2-6911ce799f4d

## 3. End to end

https://github.com/user-attachments/assets/6c61eb52-94f2-41b2-91cc-dd97c5d2d50f

## 4. End to end with the MCP server

https://github.com/user-attachments/assets/54a60fd0-709f-4e86-b5e8-34353dbfc0e3

## 5. Mutation testing

Each mutation is shown as a `git diff` against `mcp/src/freehold_mcp/server.py`, then the tests
run, then the change is reverted. The video ends with an empty `git status`.

| Mutation | What breaks | Caught by |
|---|---|---|
| M1 | The send allow-list check is disabled | `tests/test_e2e.sh --mcp`: the send to an address off the allow-list is no longer refused |
| M2 | `mail_read` ignores the folder scope | `tests/test_e2e.sh --mcp`: a message outside the agent's folders becomes readable |
| M3 | A failed send no longer gives back its hourly slot | unit test `test_failed_send_gives_its_rate_limit_slot_back` |
| M4 | `mail_move` replaces every folder of a message | `tests/test_e2e.sh --mcp`: the message also leaves a folder the agent cannot see |

https://github.com/user-attachments/assets/da623dd9-cb36-4e42-968f-bda218bf8f3a

## 6. SSO edition

https://github.com/user-attachments/assets/fe8eed00-dc73-49fb-b23b-08c1fd918e60

## 7. The mailbox after step 4

The real webmail on the throwaway stack, after the MCP agents ran. It shows:
- the prompt-injection mail, which caused no action;
- the draft to `attacker@evil.example`, still unsent after the allow-list refused it;
- the single allowed send, delivered to its recipient;
- a message the agent moved, still present in the folder it cannot see;
- the audit log, which has one line per tool call, refusals included.

https://github.com/user-attachments/assets/661dd2f6-9091-43d2-aae9-0f1ad49a066a

## How these were recorded

- **Terminal steps (1 to 6).** Recorded with asciinema and rendered with agg. The output text is
  unchanged. Only the timing was adjusted so it can be read: each new line holds briefly, and
  waits such as image pulls are shortened to at most 1.2 seconds. The bar at the bottom of each
  video names the step and the commit.
- **Browser step (7).** Recorded in headless Chromium. The test harness tears its stack down when
  it finishes, so for this one recording a local copy of `tests/test_e2e.sh` skipped the teardown.
  That was the only change. The captions describe what is on screen.
- **Before upload.** Every video was checked for anything that should not be public. The exact
  terminal text was scanned, and every frame was read back with OCR at one frame per second,
  against a list of host names, paths, account names and credential patterns. Both scans found
  0 matches. A control pattern confirmed that the OCR was reading text. Container metadata is
  stripped from every file.
