#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

require() {
  local file="$1" pattern="$2" message="$3"
  grep -Fq "$pattern" "$ROOT/$file" || { echo "FAIL: $message"; exit 1; }
}

require Sources/STTProvider.swift "fallbackProviderIDs" "STT settings must persist fallback provider IDs"
require Sources/STTProvider.swift "fallbackToLocalWhisper" "STT settings must expose local Whisper fallback"
require Sources/LLMProvider.swift "fallbackProviderIDs" "LLM settings must persist fallback provider IDs"
require Sources/CloudTranscriptionService.swift "ProviderFallbackRunner.run" "cloud STT must run the configured provider chain"
require Sources/TextCorrectionService.swift "ProviderFallbackRunner.run" "LLM correction must run the configured provider chain"
require Sources/DictationPipelineCore.swift "fallbackToLocalSTT" "dictation request must carry local STT fallback policy"
require Sources/DictationPipeline.swift "request.fallbackToLocalSTT" "pipeline must attempt local STT after cloud chain exhaustion"
require Sources/DictationController.swift "STTSettings.fallbackToLocalWhisper" "controller must pass local fallback policy into requests"
require Sources/SettingsView.swift "ProviderFallbackSettingsView()" "Settings must include the fallback editor"
require Sources/ProviderFallbackSettingsView.swift "Fallback 1" "fallback editor must expose ordered fallback slots"
require Sources/ProviderFallbackSettingsView.swift "Fallback to Local Whisper" "fallback editor must expose local Whisper fallback toggle"

echo "ProviderFallbackIntegration: PASS"
