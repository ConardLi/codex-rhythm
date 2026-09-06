#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST_PATH="$ROOT_DIR/SupportingFiles/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST_PATH")"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$ROOT_DIR/build/CodexRhythm.app"
ARCHIVE_PATH="$DIST_DIR/Codex-Rhythm-$VERSION-macOS.zip"
SOURCE_ARCHIVE_PATH="$DIST_DIR/Codex-Rhythm-$VERSION-source.zip"

"$ROOT_DIR/scripts/test.sh"
"$ROOT_DIR/scripts/build.sh"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"
(
    cd "$DIST_DIR"
    shasum -a 256 "$(basename "$ARCHIVE_PATH")" > "$(basename "$ARCHIVE_PATH").sha256"
)

PROJECT_DIR_NAME="$(basename "$ROOT_DIR")"
(
    cd "$(dirname "$ROOT_DIR")"
    zip -rq "$SOURCE_ARCHIVE_PATH" "$PROJECT_DIR_NAME" \
        -x "$PROJECT_DIR_NAME/.git/*" \
           "$PROJECT_DIR_NAME/build/*" \
           "$PROJECT_DIR_NAME/dist/*" \
           "$PROJECT_DIR_NAME/.DS_Store"
)
(
    cd "$DIST_DIR"
    shasum -a 256 "$(basename "$SOURCE_ARCHIVE_PATH")" > "$(basename "$SOURCE_ARCHIVE_PATH").sha256"
)

echo "Created $ARCHIVE_PATH"
echo "Created $ARCHIVE_PATH.sha256"
echo "Created $SOURCE_ARCHIVE_PATH"
echo "Created $SOURCE_ARCHIVE_PATH.sha256"
