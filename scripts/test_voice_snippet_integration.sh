#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
require() {
  local file="$1" pattern="$2" message="$3"
  grep -Fq "$pattern" "$ROOT/$file" || { echo "FAIL: $message"; exit 1; }
}
require Sources/DictationPipeline.swift "snippetApply" "pipeline must support post-dictionary snippet expansion"
require Sources/TextCorrectionService.swift "VoiceSnippetEngine.correctionPromptInstructions" "AI correction must preserve snippet invocations"
require Sources/SnippetsView.swift "Voice Snippets" "macOS must expose snippet management UI"
require Sources/AppDelegate.swift "openSnippets" "menu bar must open the snippets editor"
require Sources/VoiceSnippetStore.swift "snippets-v1.json" "snippet store must use versioned JSON persistence"
require Sources/VoiceSnippetRuntime.swift "NSPasteboard.general" "runtime must provide clipboard variable context"
echo "VoiceSnippetIntegration: PASS"
