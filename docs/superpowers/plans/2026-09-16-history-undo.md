# History and Undo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local text history, retention, edit/re-paste, Paste Last Transcript, safe recent undo, and Dictionary V2 learning integration.

**Architecture:** Add a Foundation-only history model/store that is independent of SwiftUI. `DictationController` appends successful outcomes. `HistoryView` edits/searches records and records explicit user corrections into Dictionary V2. `AppDelegate` owns window activation/return-to-target-app behavior and status-menu actions.

**Tech Stack:** Swift 5.9+, Foundation, SwiftUI, AppKit, ApplicationServices, Swift Package Manager, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-16-history-undo-design.md`

## Global Constraints

- macOS minimum remains 13.
- Do not persist recorded audio in History.
- History Off stops new records without silently deleting existing records.
- Dictionary learning requires an explicit user edit; AI correction alone is not a learning signal.
- Undo must expire and be one-shot.
- Existing dictation, Dictionary V2, provider, macOS build, and Windows build tests must remain green.

---

### Task 1: History core and persistence

**Files:**
- Create: `Sources/HistoryCore.swift`
- Create: `Sources/HistoryStore.swift`
- Create: `Tests/HistoryCoreTests.swift`
- Create: `scripts/test_history_core.sh`
- Modify: `.github/workflows/provider-core-tests.yml`

**Interfaces:**
- `HistoryRetention`
- `HistoryRecord`
- `HistoryDocument`
- `HistoryPolicy.pruned(_:now:maxRecords:)`
- `HistoryStore.load/save/append/update/delete/clear/latest`

- [ ] Write failing tests for retention, Off, CRUD, latest, cap, and round-trip.
- [ ] Run CI and verify the History step fails because production files do not exist.
- [ ] Implement the minimal Foundation-only history core/store.
- [ ] Re-run and verify the History core tests pass.

### Task 2: Record successful dictations and track paste undo

**Files:**
- Modify: `Sources/DictationController.swift`
- Modify: `Sources/DictationController.swift` `Paster` section
- Create: `scripts/test_history_integration_contract.sh`

**Interfaces:**
- Dictation success appends `HistoryRecord` before paste.
- `Paster.canUndoRecent(maxAge:) -> Bool`
- `Paster.undoRecent(maxAge:) -> Bool`

- [ ] Add failing source-contract assertions for history append and undo APIs.
- [ ] Verify RED.
- [ ] Append successful outcomes only and add a one-shot 15-second paste token.
- [ ] Verify contract and native macOS build GREEN.

### Task 3: History window and menu actions

**Files:**
- Create: `Sources/HistoryView.swift`
- Modify: `Sources/AppDelegate.swift`
- Create: `scripts/test_history_ui_contract.sh`

**Interfaces:**
- `HistoryView(onPasteAgain: (String) -> Void)`
- status menu actions: History, Paste Last Transcript, Undo Last Dictation
- editing a record calls `DictionaryLearningEngine.recordCorrection` and persists Dictionary V2

- [ ] Add failing UI/menu source contract.
- [ ] Verify RED.
- [ ] Implement HistoryView and AppDelegate window/menu integration.
- [ ] Verify UI contract and native macOS build GREEN.

### Task 4: Final verification and draft PR

- [ ] Compare against `feature/dictionary-v2` and check scope.
- [ ] Confirm final GitHub Actions head: provider/core, History tests, native macOS build, Windows build all successful.
- [ ] Open a draft PR based on `feature/dictionary-v2` with RED/GREEN evidence.
