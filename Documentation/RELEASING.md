# Release process

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `SupportingFiles/Info.plist`.
2. Update the client version in `Sources/CodexRhythm/Services/CodexCLI/QuotaResetService.swift` and the user agent in `Sources/CodexRhythm/Services/CodexAPI/CodexUsageService.swift` when appropriate.
3. Add a dated section to `CHANGELOG.md`.
4. If the icon source changes, regenerate `Resources/AppIcon/AppIcon.icns`:

   ```bash
   CLANG_MODULE_CACHE_PATH=/tmp/codex-rhythm-icon-cache \
   SWIFT_MODULECACHE_PATH=/tmp/codex-rhythm-icon-cache \
   ./scripts/generate-icon.swift Resources/AppIcon/AppIcon.iconset Resources/AppIcon/AppIcon.icns
   ```

5. Run the complete local verification:

   ```bash
   ./scripts/test.sh
   ./scripts/build.sh
   ./scripts/package.sh
   ```

6. Open `build/CodexRhythm.app` and verify quota refresh, the control-center layout, and any changed interaction.
7. Confirm `LICENSE.txt` and `NOTICE.txt` are present under the app bundle's `Contents/Resources` directory.
8. Create an annotated Git tag such as `v3.5.0`.
9. Publish the macOS and source archives from `dist/` with their SHA-256 checksums and release notes.

The default build is ad-hoc signed for local distribution. A broadly distributed binary should instead use a Developer ID certificate and Apple notarization.
