#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/CodexRhythm.app"
CONTENTS_DIR="$APP_DIR/Contents"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
SOURCE_ROOT="$ROOT_DIR/Sources/CodexRhythm"

if ! command -v swiftc >/dev/null 2>&1; then
    echo "error: swiftc was not found. Install Xcode Command Line Tools with: xcode-select --install" >&2
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources" "$MODULE_CACHE_DIR"

cp "$ROOT_DIR/SupportingFiles/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/SupportingFiles/PkgInfo" "$CONTENTS_DIR/PkgInfo"
cp "$ROOT_DIR/Resources/AppIcon/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"
cp "$ROOT_DIR/LICENSE" "$CONTENTS_DIR/Resources/LICENSE.txt"
cp "$ROOT_DIR/NOTICE" "$CONTENTS_DIR/Resources/NOTICE.txt"

SOURCE_FILES=()
while IFS= read -r source_file; do
    SOURCE_FILES+=("$source_file")
done < <(find "$SOURCE_ROOT" -type f -name '*.swift' -print | sort)

if [ "${#SOURCE_FILES[@]}" -eq 0 ]; then
    echo "error: no Swift sources found under $SOURCE_ROOT" >&2
    exit 1
fi

CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
SWIFT_MODULECACHE_PATH="$MODULE_CACHE_DIR" \
swiftc \
    -O \
    -warnings-as-errors \
    -framework AppKit \
    -framework Foundation \
    -framework SwiftUI \
    -framework UserNotifications \
    "${SOURCE_FILES[@]}" \
    -o "$CONTENTS_DIR/MacOS/CodexRhythm"

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Built $APP_DIR"
