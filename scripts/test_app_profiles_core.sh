#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-app-profile-core-tests"

test -f "$ROOT/Sources/AppProfileCore.swift" || { echo 'FAIL: Sources/AppProfileCore.swift missing'; exit 1; }
test -f "$ROOT/Sources/AppProfileStore.swift" || { echo 'FAIL: Sources/AppProfileStore.swift missing'; exit 1; }

swiftc -parse-as-library \
  "$ROOT/Sources/AppProfileCore.swift" \
  "$ROOT/Sources/AppProfileStore.swift" \
  "$ROOT/Tests/AppProfileCoreTests.swift" \
  -o "$OUT"
"$OUT"
