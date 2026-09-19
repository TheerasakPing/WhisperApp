#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-local-core-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/LocalWhisperCore.swift" \
  "$ROOT/Tests/LocalWhisperCoreTests.swift" \
  -o "$OUT"
"$OUT"
