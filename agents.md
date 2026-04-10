# Agent Guide: sshhh

This document provides a high-level overview of the `sshhh` codebase for AI agents and developers. It highlights the core patterns, critical constraints, and architectural invariants.

## Project Summary

**sshhh** is a native macOS menubar app for system-wide speech-to-text.

1. **Push-to-talk voice input** — Hold Option key anywhere to transcribe speech instantly into any app
2. **Privacy-first** — Uses NVIDIA Parakeet model running locally on Apple Neural Engine; no audio leaves the device
3. **Built in Swift** — SwiftUI app targeting macOS 14+ on Apple Silicon, distributed as a signed DMG
4. **Custom vocabulary** — Supports user-defined phrase replacements and spoken-form aliases for specialized terms
5. **Minimal UI** — Menubar-only with a floating widget that morphs based on recording/processing state

## Build

Always create a new DMG when building the app:

```bash
bash bundler.sh
```

This does a release build, creates the app bundle, code-signs it (ad-hoc), and produces:
- `sshhh.app` — The application bundle
- `sshhh.dmg` — The distributable disk image

## Tests

### Unit Tests
Mock-based tests for the recording state machine and dictionary logic:
```bash
swift test
```

### Integration Tests
Real E2E tests that launch the app and simulate Option key presses:
```bash
swift run IntegrationTests ./sshhh.app
```
Requires accessibility permissions for the terminal.

## Core Architecture

The app is a native macOS **LSUIElement** (menubar-only agent app).

### Key Components
- **`AppDelegate`** — Central coordinator. Manages recording flow, session lifecycle, and state.
- **`HotkeyManager`** — Uses `CGEvent.tap` to monitor the **Option** key globally.
- **`AudioRecorder`** — Microphone capture at 16kHz mono. Buffers audio internally until a streaming session is ready, then streams via `onBuffer` callback.
- **`TranscriptionEngine`** — FluidAudio SDK wrapper. Loads models once at startup, creates `SlidingWindowAsrManager` sessions per recording with optional vocabulary boosting.
- **`TextInserter`** — Clipboard-based text insertion via Cmd+V simulation.
- **`FloatingWidget`** — SwiftUI-based overlay for visual feedback (recording/processing states).

### Recording Flow
1. Option key down → 150ms activation delay (filters accidental taps)
2. If held past delay → `startRecording()` → mic starts immediately, widget shows recording state
3. Streaming session created async → early audio flushed from buffer → live audio streamed via ordered AsyncStream
4. Option key up → `stopRecordingAndTranscribe()` → buffer stream closed, feeder drained, `session.finish()` called
5. Transcription completes → `finishProcessing()` → text inserted, widget hidden

### State Flags
- `isRecording` — Audio capture in progress
- `isProcessing` — Transcription/insertion in progress
- 1 second cooldown after processing prevents rapid re-triggering

### Diagnostic Log
State changes logged to `/tmp/sshhh_diag.log` for debugging:
- `STATE: recording=true/false`
- `STATE: processing=true`
- `STATE: finishing processing`

## Critical Patterns & Invariants

### 1. The "Insertion Loop" Prevention
**Invariance**: The `HotkeyManager` MUST be stopped before `TextInserter` starts and resumed only after it finishes.
- **Reason**: `TextInserter` simulates `Cmd+V` which involves keyboard events. Without pausing, these events might trigger the global hotkey listener, leading to phantom recording loops.

### 2. Audio Constraints
- **Sample Rate**: FluidAudio models require exactly **16,000Hz**.
- **Format**: Mono, PCM 16-bit.
- **Hardware**: Transcription is explicitly configured to favor the **Apple Neural Engine (ANE)**.

### 3. Widget Lifecycle
- The widget is a borderless `NSWindow` with a transparent background.
- It dynamically toggles between a "Wide" layout (Idle/Processing) and a "Compact" layout (Recording).

### 4. Streaming Session Lifecycle
- A new `SlidingWindowAsrManager` is created per recording session.
- Vocabulary boosting must be configured **before** `start()` is called on the session.
- Audio buffers must flow through an ordered channel (AsyncStream) — never spawn a Task per buffer.
- All buffered audio must be drained before calling `finish()` on the session.

## Build & Branding Flow

- **Iconography**: Icons are NOT stored in the repo. They are generated programmatically by `IconGenerator.swift` during the build process to ensure resolution and consistency.
- **Distribution**: The `bundler.sh` script is the source of truth for creating the distribution bundle. It handles ad-hoc signing and DMG creation. Homebrew Cask distribution via `hard-engineering/homebrew-tap`.

## Rules for Future Agents

1. **Keep it Native**: Use Swift and system APIs (`AVFoundation`, `CoreGraphics`) over cross-platform libraries.
2. **Privacy First**: Maintain the on-device inference pattern. Never add network dependencies for core logic.
3. **Accessibility**: Always check for `AXIsProcessTrusted` as the app depends on event taps for its core value.
4. **Performance**: Avoid blocking the main thread during transcription; use Swift Concurrency (`async/await`) with high-priority tasks.
