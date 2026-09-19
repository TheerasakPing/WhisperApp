#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-meeting-store-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/MeetingCore.swift" \
  "$ROOT/Sources/MeetingStore.swift" \
  "$ROOT/Tests/MeetingStoreTests.swift" \
  -o "$OUT"
"$OUT"
