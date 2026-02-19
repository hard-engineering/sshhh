## Project Summary

**sshhh** is a native macOS menubar app for system-wide speech-to-text.

1. **Push-to-talk voice input** — Hold Option key anywhere to transcribe speech instantly into any app
2. **Privacy-first** — Uses NVIDIA Parakeet model running locally on Apple Neural Engine; no audio leaves the device
3. **Built in Swift** — SwiftUI app targeting macOS 14+ on Apple Silicon, distributed as a signed DMG
4. **Custom vocabulary** — Supports user-defined phrase replacements and spoken-form aliases for specialized terms
5. **Minimal UI** — Menubar-only with a floating widget that morphs based on recording/processing state

@agents.md

## Build

Always create a new DMG when building the app:

```bash
cd /Users/sks/ws/learn/sshhh/sshhh && bash bundler.sh
```

This does a release build, creates the app bundle, code-signs it (ad-hoc), and produces:
- `sshhh/sshhh.app` — The application bundle
- `sshhh/sshhh.dmg` — The distributable disk image

## Tests

### Unit Tests
Mock-based tests for the recording state machine and dictionary logic:
```bash
cd /Users/sks/ws/learn/sshhh/sshhh && swift test
```

### Integration Tests
Real E2E tests that launch the app and simulate Option key presses:
```bash
cd /Users/sks/ws/learn/sshhh/sshhh && swift run IntegrationTests ./sshhh.app
```
Requires accessibility permissions for the terminal.

## Architecture

### Key Components
- `AppDelegate.swift` — Main coordinator, manages recording flow and state
- `HotkeyManager.swift` — Global Option key monitoring via CGEvent tap
- `AudioRecorder.swift` — Microphone capture at 16kHz mono
- `TranscriptionEngine.swift` — FluidAudio/Parakeet ASR wrapper
- `TextInserter.swift` — Clipboard-based text insertion via Cmd+V
- `FloatingWidget.swift` — Visual indicator (recording/processing states)

### Recording Flow
1. Option key down → 150ms activation delay (filters accidental taps)
2. If held past delay → `startRecording()` → widget shows recording state
3. Option key up → `stopRecordingAndTranscribe()` → widget shows processing
4. Transcription completes → `finishProcessing()` → text inserted, widget hidden

### State Flags
- `isRecording` — Audio capture in progress
- `isProcessing` — Transcription/insertion in progress
- 1 second cooldown after processing prevents rapid re-triggering

### Diagnostic Log
State changes logged to `/tmp/sshhh_diag.log` for debugging:
- `STATE: recording=true/false`
- `STATE: processing=true`
- `STATE: finishing processing`