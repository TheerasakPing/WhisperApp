#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-responses-policy-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/LLMProviderCore.swift" \
  "$ROOT/Tests/ResponsesReasoningPolicyTests.swift" \
  -o "$OUT"
"$OUT"
