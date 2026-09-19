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

require Sources/WhisperService.swift "LocalWhisperManager.shared.snapshot" "WhisperService must resolve local executable/model through the manager"
forbid Sources/WhisperService.swift 'private let whisperPath = "/opt/homebrew/opt/whisper-cpp/bin/whisper-cli"' "WhisperService must not hard-code one Homebrew path"
require Sources/DictationController.swift "LocalWhisperSettingsStore.shared.preferLocalSTT" "controller must restore persisted local STT preference"
require Sources/AppDelegate.swift "preferLocalSTT" "menu STT toggle must persist local/cloud preference"
require Sources/SettingsView.swift "Local M1–M4 Mode" "Settings must expose Local Mode"
require Sources/SettingsView.swift "Use local STT by default" "Settings must expose local STT preference"
require Sources/SettingsView.swift "Use Ollama" "Settings must provide an Ollama local correction shortcut"
require Sources/SettingsView.swift "Use LM Studio" "Settings must provide an LM Studio local correction shortcut"
require Sources/LocalWhisperManager.swift "availableModelPaths" "manager must discover local Whisper models"

echo "LocalWhisperIntegration: PASS"
