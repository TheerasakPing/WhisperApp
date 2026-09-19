#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-voice-snippet-core-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/VoiceSnippetCore.swift" \
  "$ROOT/Tests/VoiceSnippetCoreTests.swift" \
  -o "$OUT"
"$OUT"
