#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

require() {
  local file="$1" pattern="$2" message="$3"
  grep -Fq "$pattern" "$ROOT/$file" || { echo "FAIL: $message"; exit 1; }
}

require Sources/Language.swift 'code: "th-en"' "language registry must expose th-en"
require Sources/CloudTranscriptionService.swift "ThaiEnglishMixedMode.cloudLanguageCode" "cloud STT must use mixed-language policy"
require Sources/WhisperService.swift "ThaiEnglishMixedMode.localWhisperLanguage" "local Whisper must map mixed mode to auto detection"
require Sources/TextCorrectionService.swift "protectLatinTerms" "LLM correction must protect Latin terms in mixed mode"
require Sources/TextCorrectionService.swift "restore(in:" "LLM correction must restore protected Latin terms"
require Sources/TextCorrectionService.swift "correctionInstructions" "LLM correction prompt must include mixed-language instructions"
require Sources/ProfilesView.swift 'tag("th-en")' "app profiles must allow Thai-English mixed mode"

echo "ThaiEnglishMixedModeIntegration: PASS"
