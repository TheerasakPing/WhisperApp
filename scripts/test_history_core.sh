#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-history-core-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/HistoryCore.swift" \
  "$ROOT/Sources/HistoryStore.swift" \
  "$ROOT/Tests/HistoryCoreTests.swift" \
  -o "$OUT"
"$OUT"
