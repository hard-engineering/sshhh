import Foundation
@testable import sshhh

/// Mock audio recorder for testing
/// Simulates recording with configurable behavior
class MockAudioRecorder: AudioRecording {

    /// Configuration for mock behavior
    struct Config {
        /// Minimum recording duration to produce samples (simulates brief press returning nil)
        var minDurationForSamples: TimeInterval = 0.1
        /// Sample rate for generated audio
        var sampleRate: Double = 16000
        /// Default samples to return (if nil, generates sine wave)
        var fixedSamples: [Float]? = nil
    }

    var config = Config()

    // Tracking for assertions
    private(set) var startRecordingCallCount = 0
    private(set) var stopRecordingCallCount = 0
    private(set) var isCurrentlyRecording = false
    private var recordingStartTime: Date?

    // Callbacks for test observation
    var onStartRecording: (() -> Void)?
    var onStopRecording: (([Float]?) -> Void)?

    func startRecording() {
        guard !isCurrentlyRecording else { return }
        startRecordingCallCount += 1
        isCurrentlyRecording = true
        recordingStartTime = Date()
        onStartRecording?()
        print("🧪 [MockAudioRecorder] Recording started")
    }

    func stopRecording() -> [Float]? {
        guard isCurrentlyRecording else { return nil }
        stopRecordingCallCount += 1
        isCurrentlyRecording = false

        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())
        recordingStartTime = nil

        // Simulate brief press returning nil
        if duration < config.minDurationForSamples {
            print("🧪 [MockAudioRecorder] Recording too brief (\(String(format: "%.3f", duration))s), returning nil")
            onStopRecording?(nil)
            return nil
        }

        // Return fixed samples or generate test audio
        let samples: [Float]
        if let fixed = config.fixedSamples {
            samples = fixed
        } else {
            // Generate a short sine wave
            let sampleCount = Int(duration * config.sampleRate)
            samples = (0..<sampleCount).map { i in
                sin(Float(i) * 0.1) * 0.5
            }
        }

        print("🧪 [MockAudioRecorder] Returning \(samples.count) samples (\(String(format: "%.2f", duration))s)")
        onStopRecording?(samples)
        return samples
    }

    func reset() {
        startRecordingCallCount = 0
        stopRecordingCallCount = 0
        isCurrentlyRecording = false
        recordingStartTime = nil
    }
}
