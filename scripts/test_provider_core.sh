#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-provider-core-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/LLMProviderCore.swift" \
  "$ROOT/Tests/ProviderCoreTests.swift" \
  -o "$OUT"
"$OUT"
