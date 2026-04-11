# Agent Guide: sshhh

Native macOS menubar app for system-wide push-to-talk speech-to-text. Holds Option key to record, releases to transcribe and insert text. Runs NVIDIA Parakeet model locally on Apple Neural Engine — no audio leaves the device.

## Build

Always create a new DMG when building the app:
```bash
bash bundler.sh
```
Produces `sshhh.app` and `sshhh.dmg` (ad-hoc signed).

## Tests

Requires **Xcode** toolchain (not Command Line Tools). Tests use Swift Testing framework.
```bash
swift test                                    # Unit tests
swift run IntegrationTests ./sshhh.app        # E2E (needs accessibility permissions)
```

## Architecture

macOS **LSUIElement** (menubar-only). Key components:

| File | Role |
|------|------|
| `AppDelegate` | Central coordinator — recording flow, session lifecycle, state |
| `HotkeyManager` | Global Option key via `CGEvent.tap` |
| `AudioRecorder` | Mic capture at 16kHz mono, buffers until session ready |
| `TranscriptionEngine` | Loads models once, creates `SlidingWindowAsrManager` per recording |
| `TextInserter` | Clipboard paste via Cmd+V simulation |
| `FloatingWidget` | SwiftUI overlay for recording/processing states |
| `DictionaryStore` | Custom vocabulary terms for boosting + text replacement |

## Critical Invariants

1. **HotkeyManager must pause during text insertion** — `TextInserter` simulates Cmd+V which would re-trigger the hotkey
2. **Mic starts immediately, session is async** — early audio buffered in `AudioRecorder.pendingBuffers`, flushed when session ready
3. **Audio buffers flow through AsyncStream** — single feeder Task, never a Task-per-buffer
4. **Vocab boosting configured before `start()`** — required by `SlidingWindowAsrManager`
5. **FluidAudio pinned to exact version** — `Package.resolved` pins by commit hash

## Rules

1. **Keep it Native** — Swift and system APIs only, no cross-platform libraries
2. **Privacy First** — On-device inference only, never add network dependencies for core logic
3. **Accessibility** — Always check `AXIsProcessTrusted`, app depends on event taps
4. **Performance** — Never block main thread during transcription, use async/await
