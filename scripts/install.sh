#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CodexRhythm.app"
APP_DEST="$HOME/Applications/$APP_NAME"
LABEL="app.codexrhythm.macos"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs"
LEGACY_LABEL="io.github.zhanglaojiu.codexquotamenu"
LEGACY_PLIST="$HOME/Library/LaunchAgents/$LEGACY_LABEL.plist"
LEGACY_APP="$HOME/Applications/CodexQuotaMenu.app"

"$ROOT_DIR/scripts/build.sh"

mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$LOG_DIR"
launchctl bootout "gui/$UID" "$PLIST_PATH" 2>/dev/null || true
launchctl bootout "gui/$UID" "$LEGACY_PLIST" 2>/dev/null || true

rm -rf "$APP_DEST"
ditto "$ROOT_DIR/build/$APP_NAME" "$APP_DEST"

TMP_PLIST="$(mktemp "/tmp/$LABEL.XXXXXX")"
trap 'rm -f "$TMP_PLIST"' EXIT
plutil -create xml1 "$TMP_PLIST"
plutil -insert Label -string "$LABEL" "$TMP_PLIST"
plutil -insert ProgramArguments -array "$TMP_PLIST"
plutil -insert ProgramArguments.0 -string "$APP_DEST/Contents/MacOS/CodexRhythm" "$TMP_PLIST"
plutil -insert ProgramArguments.1 -string "--background" "$TMP_PLIST"
plutil -insert RunAtLoad -bool true "$TMP_PLIST"
plutil -insert StandardErrorPath -string "$LOG_DIR/CodexRhythm.err.log" "$TMP_PLIST"
plutil -insert StandardOutPath -string "$LOG_DIR/CodexRhythm.out.log" "$TMP_PLIST"
mv "$TMP_PLIST" "$PLIST_PATH"
trap - EXIT

launchctl bootstrap "gui/$UID" "$PLIST_PATH"
launchctl kickstart -k "gui/$UID/$LABEL"

rm -f "$LEGACY_PLIST"
rm -rf "$LEGACY_APP"

echo "Installed Codex Rhythm. Look for the timer icon in your macOS menu bar."
