# Dictation Pipeline Foundation Design

## Goal

Refactor the macOS dictation flow so recording/UI state is separated from processing orchestration. The new pipeline must preserve existing behavior while establishing stable extension points for History, App-aware Profiles, provider fallback, mixed Thai/English processing, voice commands, snippets, local AI, AI Actions, and Meeting Mode.

## Current problem

`DictationController` currently owns recording state, cloud/local STT selection, sound-annotation cleanup, LLM correction, dictionary application, temporary-audio cleanup, status updates, and paste. This makes future fallback and history features risky because provider failures, temporary-file lifetime, and final text transformations are coupled to UI state.

## Architecture

### UI/controller boundary

`DictationController` remains an `ObservableObject` responsible for:

- starting/stopping `AudioRecorder`
- mapping pipeline events into `status` and `Stage`
- initiating one processing request per completed recording
- pasting the final text

It no longer decides how transcription, correction, text cleanup, or audio lifetime work.

### Pipeline core

Create `Sources/DictationPipelineCore.swift` with Foundation-only value types and pure policy helpers so it can be compiled/tested on Linux CI:

- `DictationSource`: `.cloud` or `.local`
- `DictationRequest`: audio URL, language, source, correction enabled
- `DictationOutcome`: final text plus raw transcript and corrected text
- `DictationPipelineEvent`: transcribing/correcting/completed/failed
- `DictationTextProcessor.stripSoundAnnotations(_:)`: existing annotation-removal behavior moved out of the controller
- `DictationTextProcessor.finalize(_:dictionaryApply:)`: trims/validates and applies the final dictionary transform

`DictationPipelineCore` must import Foundation only and must not depend on AppKit, Combine, provider implementations, or UI state.

### macOS orchestration

Create `Sources/DictationPipeline.swift` as the concrete macOS orchestration layer. It coordinates existing services:

1. choose cloud or local transcription based on `DictationRequest.source`
2. emit `.transcribing`
3. strip sound annotations
4. fail with `.emptyTranscript` when no usable speech remains
5. if correction is enabled, emit `.correcting` and run `TextCorrectionService`
6. fall back to the cleaned transcript when correction returns nil
7. apply `CorrectionDictionary.shared` exactly once as the final transform
8. delete the temporary recording only after all processing that needs it is complete
9. deliver one terminal completion to the controller

The pipeline owns temporary-audio lifetime. Future STT fallback can therefore retry the same file before deletion.

### Service abstraction

Define small protocols in `DictationPipeline.swift` for the concrete services needed by orchestration:

- cloud transcription
- local transcription
- text correction

Existing `CloudTranscriptionService`, `WhisperService`, and `TextCorrectionService` are adapted without changing their external behavior. The protocols exist to make orchestration independently testable later and to avoid coupling future routers directly to UI code.

## Behavior preservation

Phase 0 must preserve these user-visible behaviors:

- cloud/local STT toggle still selects the same existing service
- language value is passed to STT/correction as before
- AI correction remains optional
- nil AI correction falls back to the cleaned STT text
- dictionary replacement remains the final text transform
- empty/sound-only transcripts show the existing no-audio error path
- successful output is pasted into the previously focused app
- temporary recordings are removed after processing

No provider fallback, history persistence, profile selection, command parsing, or meeting capture is implemented in Phase 0. This refactor only creates the boundaries those features will use.

## Error model

Add `DictationPipelineError` with stable cases:

- `transcriptionFailed`
- `emptyTranscript`

Provider-specific HTTP errors stay inside provider services for now. Phase 4 will replace the single-service route with provider chains and richer retry/fallback classification.

## Testing

Add Linux-compatible regression tests for `DictationPipelineCore` covering:

- sound annotations are removed for ASCII/fullwidth parentheses, brackets, and asterisks
- whitespace is normalized after annotation removal
- ordinary parentheses containing meaningful text are currently removed to preserve existing behavior
- finalization rejects empty/whitespace-only transcript
- finalization applies dictionary transform after cleanup

Add a CI script `scripts/test_dictation_pipeline_core.sh` and run it in the existing Provider Core Tests workflow. A native macOS app build remains a separate verification requirement because `DictationPipeline.swift` and `DictationController.swift` depend on AppKit/Combine.

## Future extension points

- History records subscribe to completed outcomes rather than intercepting paste logic.
- App-aware Profiles resolve request fields before the pipeline starts.
- STT/LLM fallback replace single concrete services behind the pipeline protocols.
- Thai-English mixed mode becomes a text-processing/profile policy without controller changes.
- Voice commands and snippets insert processors between cleaned transcript and correction/finalization.
- Local Model Manager changes the local transcription implementation without changing the pipeline API.
- AI Actions use the same LLM routing layer but a separate action request type.
- Meeting Mode reuses transcription/correction routers but owns a long-form audio/chunking pipeline.
