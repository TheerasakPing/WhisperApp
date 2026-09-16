#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-stt-provider-core-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/STTProviderCore.swift" \
  "$ROOT/Tests/STTProviderCoreTests.swift" \
  -o "$OUT"
"$OUT"
