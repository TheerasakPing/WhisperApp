#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-local-settings-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/LocalWhisperSettings.swift" \
  "$ROOT/Tests/LocalWhisperSettingsTests.swift" \
  -o "$OUT"
"$OUT"
