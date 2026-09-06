# Publishing checklist

Complete these repository-owner steps before making the project public:

- [ ] Create the destination GitHub repository under the intended account or organization.
- [ ] Choose a history strategy: preserve the existing ancestry, or initialize a clean release repository from the generated source archive while retaining `LICENSE` and `NOTICE`.
- [ ] Add the destination repository as `origin`; keep the source project as `upstream` only in the development checkout when useful.
- [ ] Push only the intended branch and new release tags; do not publish inherited branches or tags accidentally.
- [ ] Replace any repository-owner contact details you choose to publish.
- [ ] Enable GitHub Actions and confirm the macOS CI workflow passes.
- [ ] Enable private vulnerability reporting in GitHub Security settings.
- [x] Add one current screenshot to the README after checking it for account information.
- [x] Review source files and release archives for stale branding, local paths, credentials, and account identifiers.
- [ ] Tag the first public release and attach the archive plus SHA-256 checksum.
- [ ] For broad binary distribution, sign with Developer ID and notarize with Apple.

Do not remove the original MIT copyright notice or `NOTICE`; both belong in source and binary distributions.
