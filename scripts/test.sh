#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/CodexRhythm-tests.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

PRODUCTION_SOURCES=()
while IFS= read -r production_source; do
    PRODUCTION_SOURCES+=("$production_source")
done < <(
    find "$ROOT_DIR/Sources/CodexRhythm/Domain" -type f -name '*.swift' -print
    find "$ROOT_DIR/Sources/CodexRhythm/Features/TimerAssistant" -type f -name '*.swift' -print
    find "$ROOT_DIR/Sources/CodexRhythm/Services/CodexCLI" -type f -name '*.swift' -print
    find "$ROOT_DIR/Sources/CodexRhythm/Services/CodexAPI" -type f -name '*Payload*.swift' -print
    find "$ROOT_DIR/Sources/CodexRhythm/Services/LocalUsage" -type f -name 'Telemetry*.swift' -print
)
TEST_SOURCES=()
while IFS= read -r test_source; do
    TEST_SOURCES+=("$test_source")
done < <(find "$ROOT_DIR/Tests/CodexRhythmTests" -type f -name '*.swift' -print | sort)

CLANG_MODULE_CACHE_PATH="$TMP_DIR/module-cache" \
SWIFT_MODULECACHE_PATH="$TMP_DIR/module-cache" \
swiftc \
    -warnings-as-errors \
    -framework Foundation \
    "${PRODUCTION_SOURCES[@]}" \
    "${TEST_SOURCES[@]}" \
    -o "$TMP_DIR/CodexRhythmTests"

"$TMP_DIR/CodexRhythmTests"
