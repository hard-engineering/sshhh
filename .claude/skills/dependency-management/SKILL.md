---
name: dependency-management
description: Dependency pinning, FluidAudio version management, and build toolchain details for sshhh. Use when updating dependencies, changing Package.swift, or debugging build/test failures.
---

# Dependency Management

## FluidAudio Pinning
- Pinned to exact version in `Package.swift` (`exact: "0.13.6"`)
- `Package.resolved` pins all dependencies (including transitive) by commit hash — this is the real supply-chain protection
- Do not use `from:` ranges — a compromised maintainer could push a malicious patch release

## FluidAudio API Notes (0.13.6)
- Batch `AsrManager` no longer supports vocabulary boosting
- Vocabulary boosting only available via `SlidingWindowAsrManager`
- `AsrManager.initialize(models:)` was renamed to `loadModels(_:)` in 0.13.x
- Streaming ASR moved from `ASR/Streaming/` to `ASR/Parakeet/SlidingWindow/`

## Build Toolchain
- `swift-tools-version: 6.0` with `swiftLanguageModes: [.v5]`
- tools-version 6.0 enables Swift Testing framework (`import Testing`) for tests
- `swiftLanguageModes: [.v5]` avoids strict concurrency errors in app code
- Requires **Xcode** toolchain (not just Command Line Tools) — Swift Testing is only shipped with Xcode
- Ensure `xcode-select -p` points to `/Applications/Xcode.app`

## Audio Constraints
- FluidAudio models require exactly **16,000Hz** sample rate
- Format: Mono, PCM Float32
- Hardware: Configured to favor Apple Neural Engine (ANE)
- `SlidingWindowAsrManager.streamAudio` auto-converts any format to 16kHz mono

## Homebrew Distribution
- Cask formula lives in separate repo: `hard-engineering/homebrew-tap`
- Users install with: `brew install hard-engineering/tap/sshhh`
- GitHub Actions release workflow (`release.yml`) auto-updates the cask on tag push
- Requires `TAP_TOKEN` secret (fine-grained PAT scoped to homebrew-tap repo)
