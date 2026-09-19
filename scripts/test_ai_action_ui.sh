#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for text in "Command Mode" "Polite" "Concise" "Formal" "Summarize" "Translate Thai" "Translate English"; do
  grep -Fq "$text" "$ROOT/Sources/CommandModeView.swift" || { echo "FAIL: missing $text"; exit 1; }
done
grep -Fq "Command Mode Hotkey" "$ROOT/Sources/SettingsView.swift"
echo "AIActionUI: PASS"
