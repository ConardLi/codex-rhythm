# Contributing to Codex Rhythm

Thank you for improving Codex Rhythm. Small, reviewable changes are the easiest to merge safely.

## Before opening an issue

1. Reproduce the problem on the latest version.
2. Run `./scripts/test.sh` and `./scripts/build.sh`.
3. Check `~/Library/Logs/CodexRhythm.debug.log` for the active data source.
4. Remove access tokens, account IDs, cookies, request IDs, and unrelated prompt content from every attachment.

Use a GitHub Security Advisory instead of a public issue if the problem could expose credentials or execute unintended code.

## Development workflow

```bash
./scripts/test.sh
./scripts/build.sh
open build/CodexRhythm.app
```

Keep behavioral changes separate from broad formatting. New quota or scheduling behavior should include a deterministic regression test.

## Pull requests

A pull request should explain:

- the user-visible problem;
- the chosen behavior and any trade-offs;
- how the change was tested;
- whether it changes network access, credential handling, CLI execution, or persistence.

All pull requests must compile without warnings and pass the regression suite on macOS.

## Style

- Prefer plain Swift and native Apple frameworks.
- Keep side effects in service types, not SwiftUI views or domain policies.
- Treat official quota data as authoritative; local fallback data must remain clearly labeled.
- Never log credentials, raw authenticated responses, or full Codex transcripts.
- Preserve backward-compatible preference migration when renaming persisted settings.

By contributing, you agree that your contribution is licensed under the project's MIT License.
