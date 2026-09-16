# History and Undo Design

## Goal

Add privacy-first local dictation history, safe recent undo, paste-last, edit-and-repaste, and the first real user-correction signal for Dictionary V2 learning.

## Storage

History is text-only by default and this phase never persists recorded audio. A Foundation-only JSON store at `~/.whisperapp/history-v1.json` contains a schema version, retention policy, and records. Writes are atomic and serialized. Records include timestamp, raw transcript, corrected text when available, final text, language, cloud/local source, and whether AI correction was enabled.

Retention options are Off, 1 day, 7 days, 30 days, and Forever. Pruning occurs on load and append. Turning history Off stops new records; existing records remain until the user clears or changes them explicitly.

## Dictation integration

`DictationController` appends a history record after a successful pipeline outcome and before the final paste. No history write occurs for failed/empty dictations.

## History UI

A dedicated SwiftUI window supports search, Copy, Paste Again, Edit, Delete, Clear All, and retention selection. Editing a stored result is an explicit user correction: when the edited text differs from the stored final text, `DictionaryLearningEngine.recordCorrection` receives the old and new text and persists the updated Dictionary V2 document. Repeated equivalent edits can therefore surface as dictionary suggestions, but still require user approval in Dictionary V2.

## Paste Again

Opening History captures the previously frontmost application before Whisper activates its history window. Paste Again closes/hides History, reactivates that application, then pastes after a short delay. The status-menu Paste Last Transcript command does not activate a window and can paste directly.

## Undo

`Paster` tracks the time of the latest simulated paste regardless of whether it came from normal dictation, History, or Paste Last Transcript. `undoRecent(maxAge:)` emits Command-Z only when the paste is recent (default 15 seconds), then consumes the undo token. This limits accidental undo of unrelated user work. The status menu disables Undo Last Dictation when there is no recent paste token.

## Privacy

- No audio is persisted.
- History can be disabled.
- Clear All removes all stored records.
- All history and dictionary-learning data stays under the app's local data directory.

## Testing

Foundation-only tests cover retention pruning, Off behavior, append/update/delete/clear, latest record, JSON round-trip, and maximum record cap. Source-contract tests require successful dictations to append through `HistoryStore` and AppDelegate to expose History/Paste Last/Undo actions. Native macOS CI verifies SwiftUI/AppKit integration.
