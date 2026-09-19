#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grep -Fq 'Local M1–M4 Mode' "$ROOT/Sources/SettingsView.swift"
grep -Fq 'Auto Detect' "$ROOT/Sources/SettingsView.swift"
grep -Fq 'Whisper model' "$ROOT/Sources/SettingsView.swift"
grep -Fq 'Ready for offline STT' "$ROOT/Sources/SettingsView.swift"
grep -Fq 'Ollama' "$ROOT/Sources/SettingsView.swift"
grep -Fq 'LM Studio' "$ROOT/Sources/SettingsView.swift"
echo "LocalWhisperUI: PASS"
