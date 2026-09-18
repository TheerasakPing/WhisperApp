#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-thai-english-mixed-tests"

swiftc -parse-as-library \
  "$ROOT/Sources/Language.swift" \
  "$ROOT/Sources/ThaiEnglishMixedModeCore.swift" \
  "$ROOT/Tests/ThaiEnglishMixedModeTests.swift" \
  -o "$OUT"

"$OUT"
