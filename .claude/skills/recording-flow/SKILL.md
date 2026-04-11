---
name: recording-flow
description: Streaming recording architecture for sshhh. Use when modifying AppDelegate recording flow, AudioRecorder, TranscriptionEngine, or SlidingWindowAsrManager session lifecycle.
---

# Recording Flow & Streaming Session Lifecycle

## Recording Flow (AppDelegate)

1. Option key down → 150ms activation delay (filters accidental taps)
2. `startRecording()` → mic starts **immediately** (synchronous), widget shows recording
3. Async Task creates `SlidingWindowAsrManager` session, configures vocab boosting
4. Early audio flushed from `AudioRecorder.pendingBuffers` to session
5. Live audio streamed via ordered `AsyncStream` → single feeder Task calls `streamAudio` sequentially
6. Option key up → `stopRecordingAndTranscribe()` → buffer stream closed, feeder drained, `session.finish()` called
7. `finishProcessing()` → text inserted via `TextInserter`, widget hidden

## Critical Invariants

### Session Creation Race
- Mic must start before async session creation — audio is buffered in `AudioRecorder.pendingBuffers`
- `stopRecordingAndTranscribe` awaits session readiness via `CheckedContinuation` if session isn't created yet
- Error paths must reset **both** `isRecording` and `isProcessing`

### Audio Buffer Ordering
- Never spawn a `Task` per audio buffer — breaks ordering, loses tail audio
- Use `AsyncStream` with a single feeder Task for sequential `streamAudio` calls
- Drain all buffered audio (`await bufferFeederTask?.value`) before calling `session.finish()`

### Insertion Loop Prevention
The `HotkeyManager` MUST be stopped before `TextInserter` starts and resumed only after it finishes. `TextInserter` simulates `Cmd+V` which would re-trigger the hotkey listener.

### SlidingWindowAsrManager Lifecycle
- New session created per recording (not reused)
- `configureVocabularyBoosting()` must be called **before** `start()`
- `finish()` closes the input stream and returns final transcription

## State Flags
- `isRecording` — Audio capture in progress
- `isProcessing` — Transcription/insertion in progress
- `activeSession` — Current `SlidingWindowAsrManager` (nil between recordings)
- `sessionReady` — `CheckedContinuation` for stop-before-session-ready race
- 1 second cooldown after processing prevents rapid re-triggering

## Diagnostic Log
State changes logged to `/tmp/sshhh_diag.log` (truncated on app launch):
- `STATE: recording=true/false`
- `STATE: processing=true`
- `STATE: finishing processing`
