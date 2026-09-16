#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-dictation-pipeline-core-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/DictationPipelineCore.swift" \
  "$ROOT/Tests/DictationPipelineCoreTests.swift" \
  -o "$OUT"
"$OUT"
