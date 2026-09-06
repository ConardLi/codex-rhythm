#!/bin/bash

set -euo pipefail

LABEL="app.codexrhythm.macos"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
APP_PATH="$HOME/Applications/CodexRhythm.app"
LEGACY_LABEL="io.github.zhanglaojiu.codexquotamenu"
LEGACY_PLIST="$HOME/Library/LaunchAgents/$LEGACY_LABEL.plist"
LEGACY_APP="$HOME/Applications/CodexQuotaMenu.app"

launchctl bootout "gui/$UID" "$PLIST_PATH" 2>/dev/null || true
launchctl bootout "gui/$UID" "$LEGACY_PLIST" 2>/dev/null || true
rm -f "$PLIST_PATH"
rm -rf "$APP_PATH"
rm -f "$LEGACY_PLIST"
rm -rf "$LEGACY_APP"

echo "Uninstalled Codex Rhythm. Log files in ~/Library/Logs were kept for troubleshooting."
