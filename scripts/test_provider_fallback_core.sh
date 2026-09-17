#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-provider-fallback-core-tests"

test -f "$ROOT/Sources/ProviderFallbackCore.swift" || { echo 'FAIL: Sources/ProviderFallbackCore.swift missing'; exit 1; }

swiftc -parse-as-library \
  "$ROOT/Sources/ProviderFallbackCore.swift" \
  "$ROOT/Tests/ProviderFallbackCoreTests.swift" \
  -o "$OUT"
"$OUT"
