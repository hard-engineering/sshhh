# sshhh

System-wide push-to-talk speech-to-text for macOS. Hold Option, speak, release — your words appear in any app. Runs entirely on-device using the Apple Neural Engine.

## Install

```bash
brew install hard-engineering/tap/sshhh
```

Or download the latest DMG from [Releases](https://github.com/hard-engineering/sshhh/releases).

### Requirements
- macOS 14+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- Grant **Microphone** and **Accessibility** permissions when prompted

## Usage

1. Launch sshhh — it lives in the menubar
2. Hold **Option** key and speak
3. Release — text is transcribed and pasted into the active app

### Custom Vocabulary

Open the settings window from the menubar icon. Add words and phrases to the Dictionary to improve recognition accuracy. Entries with a spoken form also trigger text replacement (e.g., say "kube" → inserts "Kubernetes").

## How It Works

- **Engine**: [FluidAudio](https://github.com/FluidInference/FluidAudio) + NVIDIA Parakeet TDT, running on the Apple Neural Engine at up to 190x real-time
- **Privacy**: All transcription happens locally. No audio leaves your device.
- **Hotkey**: Global Option key monitoring via `CGEvent` tap
- **Text insertion**: Clipboard paste simulation (Cmd+V) — fast and compatible with all apps
- **UI**: Menubar-only (`LSUIElement`), floating widget shows recording/processing state

## Build from Source

```bash
git clone https://github.com/hard-engineering/sshhh.git
cd sshhh
bash bundler.sh
open sshhh.app
```

Requires Xcode and Apple Silicon.
