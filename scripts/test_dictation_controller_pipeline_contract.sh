#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTROLLER="$ROOT/Sources/DictationController.swift"
WHISPER="$ROOT/Sources/WhisperService.swift"

grep -q 'private let pipeline = DictationPipeline()' "$CONTROLLER"
grep -q 'pipeline.process' "$CONTROLLER"

if grep -q 'CloudTranscriptionService()' "$CONTROLLER"; then
  echo 'DictationController must not own CloudTranscriptionService directly' >&2
  exit 1
fi
if grep -q 'WhisperService()' "$CONTROLLER"; then
  echo 'DictationController must not own WhisperService directly' >&2
  exit 1
fi
if grep -q 'TextCorrectionService()' "$CONTROLLER"; then
  echo 'DictationController must not own TextCorrectionService directly' >&2
  exit 1
fi
if grep -q 'removeItem(at: url)' "$CONTROLLER"; then
  echo 'DictationController must not own temporary-audio cleanup' >&2
  exit 1
fi
if grep -q 'stripSoundAnnotations' "$CONTROLLER"; then
  echo 'DictationController must not own transcript cleanup policy' >&2
  exit 1
fi
if grep -q 'removeItem(at: fileURL)' "$WHISPER"; then
  echo 'WhisperService must not delete the pipeline-owned recording' >&2
  exit 1
fi

echo 'DictationControllerPipelineContract: PASS'
