#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VIEW="$ROOT/Sources/DictionaryView.swift"

grep -q 'DictionaryV2Store.shared' "$VIEW"
grep -q 'DictionaryDocument' "$VIEW"
grep -q 'aliases' "$VIEW"
grep -q 'category' "$VIEW"
grep -q 'acceptSuggestion' "$VIEW"
grep -q 'rejectSuggestion' "$VIEW"

if grep -q 'dictionary.txt' "$VIEW"; then
  echo 'DictionaryView must persist through DictionaryV2Store instead of editing dictionary.txt directly' >&2
  exit 1
fi
if grep -q 'write(toFile:' "$VIEW"; then
  echo 'DictionaryView must not write dictionary files directly' >&2
  exit 1
fi

echo 'DictionaryV2UIContract: PASS'
