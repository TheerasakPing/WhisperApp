#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[ -f "$ROOT/Sources/HistoryView.swift" ]
grep -F 'HistoryStore.shared.append' "$ROOT/Sources/DictationController.swift" >/dev/null
grep -F 'History…' "$ROOT/Sources/AppDelegate.swift" >/dev/null
grep -F 'Paste Last Transcript' "$ROOT/Sources/AppDelegate.swift" >/dev/null
grep -F 'Undo Last Paste' "$ROOT/Sources/AppDelegate.swift" >/dev/null
grep -F 'func undoLastPaste' "$ROOT/Sources/DictationController.swift" >/dev/null
grep -F 'func pasteLastTranscript' "$ROOT/Sources/DictationController.swift" >/dev/null

echo "HistoryUIContract: PASS"
