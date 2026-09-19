#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-ai-action-core-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/AIActionCore.swift" \
  "$ROOT/Tests/AIActionCoreTests.swift" \
  -o "$OUT"
"$OUT"
