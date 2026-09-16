#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/whisper-zai-provider-tests"
swiftc -parse-as-library \
  "$ROOT/Sources/LLMProviderCore.swift" \
  "$ROOT/Tests/ZAIProviderTests.swift" \
  -o "$OUT"
"$OUT"

grep -F 'DefaultEndpoint = "https://api.z.ai/api/paas/v4/chat/completions"' "$ROOT/windows/src/Providers.cs" >/dev/null
grep -F 'DefaultModel = "glm-5.1"' "$ROOT/windows/src/Providers.cs" >/dev/null
grep -F 'EnvKey = "ZAI_API_KEY", Style = LlmStyle.OpenAI' "$ROOT/windows/src/Providers.cs" >/dev/null

echo "ZAIWindowsProviderContract: PASS"
