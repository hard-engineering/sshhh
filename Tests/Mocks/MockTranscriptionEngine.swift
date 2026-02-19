import Foundation
@testable import sshhh

/// Mock transcription engine for testing
class MockTranscriptionEngine: Transcribing {

    struct Config {
        /// Simulated transcription delay
        var transcriptionDelay: TimeInterval = 0.1
        /// Text to return (if nil, returns generic text)
        var fixedResult: String? = nil
        /// Should throw an error?
        var shouldFail: Bool = false
        /// Error to throw if shouldFail is true
        var errorToThrow: Error = NSError(domain: "MockTranscription", code: -1)
    }

    var config = Config()

    private(set) var _isReady = true
    var isReady: Bool { _isReady }

    private(set) var transcribeCallCount = 0
    private(set) var lastSamplesReceived: [Float]?

    var onTranscribe: (([Float]) -> Void)?

    func setReady(_ ready: Bool) {
        _isReady = ready
    }

    func transcribe(samples: [Float]) async throws -> String? {
        transcribeCallCount += 1
        lastSamplesReceived = samples
        onTranscribe?(samples)

        print("🧪 [MockTranscriptionEngine] Transcribing \(samples.count) samples...")

        // Simulate processing delay
        try await Task.sleep(nanoseconds: UInt64(config.transcriptionDelay * 1_000_000_000))

        if config.shouldFail {
            print("🧪 [MockTranscriptionEngine] Throwing error")
            throw config.errorToThrow
        }

        let result = config.fixedResult ?? "Test transcription \(transcribeCallCount)"
        print("🧪 [MockTranscriptionEngine] Returning: \"\(result)\"")
        return result
    }

    func reset() {
        transcribeCallCount = 0
        lastSamplesReceived = nil
        config = Config()
    }
}
