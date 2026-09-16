# Dictation Pipeline Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract dictation processing from `DictationController` into a testable pipeline while preserving existing user-visible behavior and creating extension points for the planned feature roadmap.

**Architecture:** Keep `DictationController` as the UI/recording state owner. Move Foundation-only text policy into `DictationPipelineCore.swift` and concrete macOS service orchestration into `DictationPipeline.swift`. The pipeline owns temporary-audio lifetime and returns a terminal outcome/error to the controller.

**Tech Stack:** Swift 5.9+, Foundation, AppKit, Combine, AVFoundation, Swift Package Manager, shell-based Swift regression executables, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-16-dictation-pipeline-foundation-design.md`

## Global Constraints

- Minimum platform remains macOS 13.
- Keep package/target name `WhisperApp` and bundle identity unchanged.
- Preserve current cloud/local STT selection behavior.
- Preserve optional correction with fallback to cleaned STT text.
- Apply `CorrectionDictionary` exactly once as the final text transform.
- Do not add History, provider fallback, Profiles, commands, snippets, or Meeting Mode in this phase.
- `DictationPipelineCore.swift` must compile on Linux with Foundation only.

---

### Task 1: Foundation-only pipeline core

**Files:**
- Create: `Tests/DictationPipelineCoreTests.swift`
- Create: `scripts/test_dictation_pipeline_core.sh`
- Create: `Sources/DictationPipelineCore.swift`
- Modify: `.github/workflows/provider-core-tests.yml`

**Interfaces:**
- Produces: `DictationSource`, `DictationRequest`, `DictationOutcome`, `DictationPipelineError`, `DictationPipelineEvent`, `DictationTextProcessor.stripSoundAnnotations(_:)`, `DictationTextProcessor.finalize(_:dictionaryApply:)`.
- Consumes: Foundation `URL` and `String` only.

- [ ] **Step 1: Write failing core tests**

Create tests that assert annotation stripping, whitespace normalization, empty-result rejection, and final dictionary transformation.

- [ ] **Step 2: Run the new script in CI and verify RED**

Expected: compilation fails because `Sources/DictationPipelineCore.swift` and its symbols do not exist.

- [ ] **Step 3: Implement the minimal Foundation-only core**

Add the value types, error cases, and pure text processor required by the tests. Do not import AppKit or Combine.

- [ ] **Step 4: Run the full provider-core workflow and verify GREEN**

Expected: existing provider tests plus `test_dictation_pipeline_core.sh` pass.

- [ ] **Step 5: Commit**

Commit message: `feat: add dictation pipeline core`

---

### Task 2: Concrete macOS orchestration

**Files:**
- Create: `Sources/DictationPipeline.swift`
- Modify: `Sources/CloudTranscriptionService.swift`
- Modify: `Sources/WhisperService.swift`
- Modify: `Sources/TextCorrectionService.swift`

**Interfaces:**
- Consumes: `DictationRequest` from Task 1.
- Produces: `DictationPipeline.process(_:onEvent:completion:)` with exactly one terminal completion.
- Protocol adapters expose existing callback-based services without changing provider behavior.

- [ ] **Step 1: Add compile-contract tests where possible**

Add source-level regression assertions to the Phase 0 test script verifying that the concrete pipeline exists, owns temp-file removal, and does not paste directly.

- [ ] **Step 2: Verify RED**

Expected: source contract fails because `Sources/DictationPipeline.swift` does not exist.

- [ ] **Step 3: Implement the orchestration layer**

The implementation must:

```swift
func process(
    _ request: DictationRequest,
    onEvent: @escaping (DictationPipelineEvent) -> Void,
    completion: @escaping (Result<DictationOutcome, DictationPipelineError>) -> Void
)
```

Cloud/local transcription is selected from `request.source`; correction runs only when requested; nil correction falls back to the cleaned transcript; dictionary application is the final transform; temporary audio is removed only from pipeline terminal paths.

- [ ] **Step 4: Verify source contract and existing core tests GREEN**

Expected: all shell regression scripts pass.

- [ ] **Step 5: Commit**

Commit message: `feat: add dictation processing pipeline`

---

### Task 3: Refactor DictationController to the pipeline

**Files:**
- Modify: `Sources/DictationController.swift`

**Interfaces:**
- Consumes: `DictationPipeline.process` and its event/outcome/error values.
- Produces: unchanged public recording API (`start`, `stop`, `toggle`) and unchanged observable UI state.

- [ ] **Step 1: Add a source-contract regression test**

Assert that `DictationController` owns a `DictationPipeline`, no longer calls `CloudTranscriptionService.transcribe`, `WhisperService.transcribe`, or `TextCorrectionService.correct` directly, and no longer removes the recording file itself.

- [ ] **Step 2: Verify RED**

Expected: controller contract fails on the existing implementation.

- [ ] **Step 3: Refactor the controller**

Build a `DictationRequest` in `handleAudio`, map `.transcribing`/`.correcting` events to existing status/stage values, map terminal errors to the existing no-audio/transcription error UX, and paste `outcome.finalText` on success.

- [ ] **Step 4: Verify all CI tests GREEN**

Expected: pipeline core, controller source contract, provider core, Responses policy, optional STT core, and Windows build all pass.

- [ ] **Step 5: Commit**

Commit message: `refactor: route dictation through pipeline`

---

### Task 4: Documentation and PR verification

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md` if present and relevant

**Interfaces:**
- Documents the new pipeline boundary and states that subsequent roadmap features build on it.

- [ ] **Step 1: Update architecture documentation**

Document `DictationController -> DictationPipeline -> STT -> correction -> dictionary -> paste` and clarify that temporary-audio lifetime now belongs to the pipeline.

- [ ] **Step 2: Run fresh verification**

Run/confirm the current head GitHub Actions workflow and inspect failed job logs if any job is not successful.

- [ ] **Step 3: Review the diff**

Compare against `feature/responses-api-adapter`; verify scope contains only Phase 0 foundation work plus design/plan docs.

- [ ] **Step 4: Open a draft PR**

Base: `feature/responses-api-adapter`.

Title: `Refactor dictation processing into pipeline foundation`.
