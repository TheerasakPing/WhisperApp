#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
require() {
  local file="$1" pattern="$2" message="$3"
  grep -Fq "$pattern" "$ROOT/$file" || { echo "FAIL: $message"; exit 1; }
}
forbid() {
  local file="$1" pattern="$2" message="$3"
  if grep -Fq "$pattern" "$ROOT/$file"; then echo "FAIL: $message"; exit 1; fi
}
require Sources/MeetingNotesService.swift "ProviderFallbackRunner.run" "meeting notes must reuse LLM fallback"
require Sources/MeetingNotesService.swift "LLMRequestBuilder.build" "meeting notes must reuse provider request policy"
require Sources/MeetingTranscriptionService.swift "CloudTranscriptionService" "meeting mode must support configured cloud STT"
require Sources/MeetingTranscriptionService.swift "WhisperService" "meeting mode must support local Whisper STT"
require Sources/MeetingModeController.swift "AudioRecorder" "meeting mode must record microphone audio"
require Sources/MeetingModeController.swift "SystemAudioRecorder" "meeting mode must support system audio recording"
require Sources/MeetingTranscriptionService.swift "AudioChunker" "long recordings must be split into upload-safe chunks"
require Sources/MeetingModeController.swift "removeItem" "temporary meeting audio must be removed after transcription"
require Sources/MeetingModeController.swift "MeetingStore.shared" "meeting transcript/notes must persist locally"
require Sources/AppDelegate.swift "openMeetingMode" "menu bar must expose Meeting Mode"
forbid Sources/MeetingModeController.swift "VoiceCommandProcessor" "meeting transcript must not run dictation voice commands"
forbid Sources/MeetingModeController.swift "VoiceSnippet" "meeting transcript must not run snippets"
forbid Sources/MeetingModeController.swift "CorrectionDictionary" "meeting transcript must remain verbatim"
echo "MeetingIntegration: PASS"
