#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grep -Fq 'TextField("Trigger' "$ROOT/Sources/SnippetsView.swift"
grep -Fq 'TextEditor' "$ROOT/Sources/SnippetsView.swift"
grep -Fq '{date}' "$ROOT/Sources/SnippetsView.swift"
grep -Fq '{time}' "$ROOT/Sources/SnippetsView.swift"
grep -Fq '{clipboard}' "$ROOT/Sources/SnippetsView.swift"
echo "VoiceSnippetUI: PASS"
