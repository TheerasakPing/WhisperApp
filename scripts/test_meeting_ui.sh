#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for text in "Meeting Mode" "Microphone only" "Microphone + System Audio" "Start Meeting" "Stop Meeting" "Generate Notes" "Export Markdown" "Transcript" "Meeting Notes"; do
  grep -Fq "$text" "$ROOT/Sources/MeetingView.swift" || { echo "FAIL: missing $text"; exit 1; }
done
echo "MeetingUI: PASS"
