#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-meeting-core-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/MeetingCore.swift" \
  "$ROOT/Tests/MeetingCoreTests.swift" \
  -o "$OUT"
"$OUT"
