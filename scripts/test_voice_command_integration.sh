#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

require() {
  local file="$1" pattern="$2" message="$3"
  grep -Fq "$pattern" "$ROOT/$file" || { echo "FAIL: $message"; exit 1; }
}

require Sources/DictationPipeline.swift "VoiceCommandProcessor.apply" "pipeline must apply voice commands before correction"
require Sources/TextCorrectionService.swift "VoiceCommandProcessor.correctionPromptInstructions" "LLM prompt must handle unresolved self-corrections"
require Sources/VoiceCommandCore.swift "ขึ้นบรรทัดใหม่" "Thai newline command must be supported"
require Sources/VoiceCommandCore.swift "new line" "English newline command must be supported"
require Sources/VoiceCommandCore.swift "ลบประโยคก่อนหน้า" "Thai delete-previous-sentence command must be supported"
require Sources/VoiceCommandCore.swift "delete previous sentence" "English delete-previous-sentence command must be supported"
require Sources/VoiceCommandCore.swift "ไม่ใช่" "Thai backtracking cue must be supported"
require Sources/VoiceCommandCore.swift "I mean" "English backtracking cue must be supported"

echo "VoiceCommandIntegration: PASS"
