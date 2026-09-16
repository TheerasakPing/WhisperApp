#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-dictionary-v2-core-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/DictionaryV2Core.swift" \
  "$ROOT/Sources/DictionaryV2Store.swift" \
  "$ROOT/Tests/DictionaryV2CoreTests.swift" \
  -o "$OUT"
"$OUT"
