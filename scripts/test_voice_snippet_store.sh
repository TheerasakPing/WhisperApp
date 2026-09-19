#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-voice-snippet-store-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/VoiceSnippetCore.swift" \
  "$ROOT/Sources/VoiceSnippetStore.swift" \
  "$ROOT/Tests/VoiceSnippetStoreTests.swift" \
  -o "$OUT"
"$OUT"
