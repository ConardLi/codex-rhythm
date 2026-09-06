# Security Policy

## Supported versions

Security fixes are applied to the latest released version of Codex Rhythm.

## Trust model

Codex Rhythm needs authenticated quota data. It reads the existing Codex credentials from `~/.codex/auth.json` and sends the access token only to the relevant HTTPS endpoints under `https://chatgpt.com/backend-api/wham/`.

The app does not persist, print, or log access tokens, refresh tokens, ID tokens, or account IDs. It uses an ephemeral `URLSession`, contains no analytics SDK, and makes no request to project-owned infrastructure.

If the official quota request fails, the app invokes `/usr/bin/sqlite3` to read recent `x-codex-*` response headers from Codex's local log database. The database is not modified.

The timer assistant is disabled by default. When enabled or invoked manually, it launches a locally resolved `codex` executable using an ephemeral session, a read-only sandbox, and a fixed prompt. Credentials are not passed on the command line. A custom executable path is trusted code and should point only to a verified Codex CLI installation.

The banked-reset action is explicit and requires confirmation because a successful reset consumes one available reset credit.

## Reporting a vulnerability

Please report credential exposure, unintended command execution, or authentication flaws through a private GitHub Security Advisory. Do not include real tokens, account IDs, `auth.json`, or unredacted Codex logs in a public issue.

Ordinary display, scheduling, or compatibility bugs can use the public issue tracker after sensitive details are removed.
