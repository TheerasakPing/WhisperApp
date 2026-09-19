#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-voice-command-core-tests"

swiftc -parse-as-library \
  "$ROOT/Sources/VoiceCommandCore.swift" \
  "$ROOT/Tests/VoiceCommandCoreTests.swift" \
  -o "$OUT"

"$OUT"
