# Agent Guide: sshhh 🤫

This document provides a high-level overview of the `sshhh` codebase for AI agents and developers. It highlights the core patterns, critical constraints, and architectural invariants.

## 🏗️ Core Architecture

The app is a native macOS **LSUIElement** (menubar-only agent app).

- **`AppDelegate`**: The central brain. Coordinates between hotkey events, audio recording, and transcription.
- **`HotkeyManager`**: Uses `CGEvent.tap` to monitor the **Option (⌥)** key globally.
- **`TranscriptionEngine`**: Wrapper for the **FluidAudio SDK**. Manages model lifecycle and inference on the Neural Engine.
- **`TextInserter`**: Handles the final output. Uses a `Cmd+V` (Clipboard Paste) simulation.
- **`FloatingWidget`**: A SwiftUI-based overlay that provides visual feedback.

## 🛠️ Critical Patterns & Invariants

### 1. The "Insertion Loop" Prevention
**Invariance**: The `HotkeyManager` MUST be stopped before `TextInserter` starts and resumed only after it finishes.
- **Reason**: `TextInserter` simulates `Cmd+V` which involves keyboard events. Without pausing, these events might trigger the global hotkey listener, leading to phantom recording loops.

### 2. Audio Constraints
- **Sample Rate**: FluidAudio/WhisperKit models require exactly **16,000Hz**. 
- **Format**: Mono, PCM 16-bit.
- **Hardware**: Transcription is explicitly configured to favor the **Apple Neural Engine (ANE)**.

### 3. Widget Lifecycle
- The widget is a borderless `NSWindow` with a transparent background.
- It dynamically toggles between a "Wide" layout (Idle/Processing) and a "Compact" layout (Recording).

## 🚀 Build & Branding Flow

- **Iconography**: Icons are NOT stored in the repo. They are generated programmatically by `IconGenerator.swift` during the build process to ensure resolution and consistency.
- **Distribution**: The `bundler.sh` script is the source of truth for creating the distribution bundle. It handles ad-hoc signing and DMG creation.

## 🤝 Rules for Future Agents

1. **Keep it Native**: Use Swift and system APIs (`AVFoundation`, `CoreGraphics`) over cross-platform libraries.
2. **Privacy First**: Maintain the on-device inference pattern. Never add network dependencies for core logic.
3. **Accessibility**: Always check for `AXIsProcessTrusted` as the app depends on event taps for its core value.
4. **Performance**: Avoid blocking the main thread during transcription; use Swift Concurrency (`async/await`) with high-priority tasks.

---
*This guide is maintained for agents. Current build: v1.0 (Sonoma+)*
