import Foundation
import AVFoundation
@testable import sshhh

/// Mock audio recorder for testing
/// Simulates recording with configurable behavior
class MockAudioRecorder: AudioRecording {

    // Tracking for assertions
    private(set) var startRecordingCallCount = 0
    private(set) var stopRecordingCallCount = 0
    private(set) var isCurrentlyRecording = false

    /// Callback for streaming audio buffers to the transcription session
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    // Callbacks for test observation
    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?

    func startRecording() {
        guard !isCurrentlyRecording else { return }
        startRecordingCallCount += 1
        isCurrentlyRecording = true
        onStartRecording?()
        print("🧪 [MockAudioRecorder] Recording started")
    }

    func stopRecording() {
        guard isCurrentlyRecording else { return }
        stopRecordingCallCount += 1
        isCurrentlyRecording = false
        onBuffer = nil
        onStopRecording?()
        print("🧪 [MockAudioRecorder] Recording stopped")
    }

    func flushPendingBuffers() -> [AVAudioPCMBuffer] {
        return []
    }

    func reset() {
        startRecordingCallCount = 0
        stopRecordingCallCount = 0
        isCurrentlyRecording = false
        onBuffer = nil
    }
}
