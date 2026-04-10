import Foundation
@testable import sshhh

/// Mock transcription engine for testing
class MockTranscriptionEngine: Transcribing {

    private(set) var _isReady = true
    var isReady: Bool { _isReady }

    func setReady(_ ready: Bool) {
        _isReady = ready
    }

    func reset() {
        _isReady = true
    }
}
