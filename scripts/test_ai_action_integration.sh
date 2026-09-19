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

require Sources/AIActionService.swift "ProviderFallbackRunner.run" "AI actions must reuse provider fallback"
require Sources/AIActionService.swift "LLMRequestBuilder.build" "AI actions must reuse provider request policies"
require Sources/CommandModeController.swift "SelectionCaptureService" "Command Mode must capture selected text"
require Sources/CommandModeController.swift "Paster.paste" "Command Mode must return transformed text to the cursor"
require Sources/CommandHotkeyManager.swift "CommandHotkeyManager" "Command Mode must have a second global hotkey"
require Sources/AppDelegate.swift "setupCommandHotkey" "App lifecycle must start the Command Mode hotkey"
require Sources/AppDelegate.swift "openCommandMode" "menu/hotkey must open Command Mode"
require Sources/SettingsView.swift "Command Mode Hotkey" "Settings must configure the second hotkey"
forbid Sources/AIActionService.swift "Process()" "AI text actions must never execute shell processes"
forbid Sources/CommandModeController.swift "Process()" "Command Mode must never execute shell processes"

echo "AIActionIntegration: PASS"
