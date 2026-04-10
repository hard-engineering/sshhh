import Testing
import Foundation
import AVFoundation
@testable import sshhh

@Suite("Streaming Flow")
struct StreamingFlowTests {

    // MARK: - Audio Buffer Streaming

    @Test("MockAudioRecorder clears onBuffer on stop, matching real AudioRecorder contract")
    func onBuffer_ClearedOnStop() {
        let recorder = MockAudioRecorder()
        recorder.onBuffer = { _ in }

        #expect(recorder.onBuffer != nil)

        recorder.startRecording()
        recorder.stopRecording()

        #expect(recorder.onBuffer == nil, "onBuffer should be cleared by stopRecording")
    }

    @Test("Audio buffers are forwarded via onBuffer callback")
    func audioBuffers_Forwarded() throws {
        let recorder = MockAudioRecorder()
        var buffersReceived = 0

        recorder.onBuffer = { _ in
            buffersReceived += 1
        }

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1600))
        buffer.frameLength = 1600

        recorder.onBuffer?(buffer)
        recorder.onBuffer?(buffer)
        recorder.onBuffer?(buffer)

        #expect(buffersReceived == 3, "All buffers should be forwarded via callback")
    }

    @Test("onBuffer is not called after stopRecording")
    func onBuffer_NotCalledAfterStop() throws {
        let recorder = MockAudioRecorder()
        var buffersReceived = 0

        recorder.onBuffer = { _ in
            buffersReceived += 1
        }

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1600))
        buffer.frameLength = 1600

        recorder.onBuffer?(buffer)
        recorder.startRecording()
        recorder.stopRecording()

        // onBuffer is nil now, so this is a no-op
        recorder.onBuffer?(buffer)

        #expect(buffersReceived == 1, "No buffers should be forwarded after stop")
    }

    // MARK: - Transcription Provider

    @Test("transcriptionProvider is invoked on stop and result flows to textInserter")
    func transcriptionProvider_ResultFlows() async throws {
        var providerCalled = false
        let (controller, mocks) = createTestController()

        controller.transcriptionProvider = {
            providerCalled = true
            return "streaming result"
        }

        controller.onKeyDown()
        try await Task.sleep(nanoseconds: 200_000_000)
        controller.onKeyUp()
        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(providerCalled == true, "transcriptionProvider should be called")
        #expect(mocks.textInserter.lastInsertedText == "streaming result",
                "Result should flow to textInserter")
    }

    @Test("transcriptionProvider returning nil does not insert text")
    func transcriptionProvider_NilResult() async throws {
        let (controller, mocks) = createTestController(transcriptionResult: nil)

        controller.onKeyDown()
        try await Task.sleep(nanoseconds: 200_000_000)
        controller.onKeyUp()
        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(mocks.textInserter.insertTextCallCount == 0,
                "No text should be inserted for nil result")
        #expect(controller.isProcessing == false, "Should reset to idle")
    }

    @Test("transcriptionProvider returning empty string does not insert text")
    func transcriptionProvider_EmptyResult() async throws {
        let (controller, mocks) = createTestController(transcriptionResult: "")

        controller.onKeyDown()
        try await Task.sleep(nanoseconds: 200_000_000)
        controller.onKeyUp()
        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(mocks.textInserter.insertTextCallCount == 0,
                "No text should be inserted for empty result")
        #expect(controller.isProcessing == false, "Should reset to idle")
    }

    @Test("transcriptionProvider error resets state without inserting text")
    func transcriptionProvider_Error() async throws {
        let (controller, mocks) = createTestController()

        controller.transcriptionProvider = {
            throw NSError(domain: "test", code: 1)
        }

        controller.onKeyDown()
        try await Task.sleep(nanoseconds: 200_000_000)
        controller.onKeyUp()
        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(mocks.textInserter.insertTextCallCount == 0)
        #expect(controller.isRecording == false)
        #expect(controller.isProcessing == false)
    }

    // MARK: - TranscriptionEngine Error Paths

    @Test("TranscriptionEngine.createSession throws when not initialized")
    func engine_ThrowsWhenNotReady() async throws {
        let engine = TranscriptionEngine()

        #expect(engine.isReady == false)

        await #expect(throws: TranscriptionError.self) {
            _ = try await engine.createSession(terms: [])
        }
    }

    // MARK: - Helpers

    struct TestMocks {
        let audioRecorder: MockAudioRecorder
        let transcriber: MockTranscriptionEngine
        let textInserter: MockTextInserter
        let widget: MockWidget
    }

    func createTestController(
        transcriptionResult: String? = nil,
        transcriptionError: Error? = nil
    ) -> (TestableRecordingController, TestMocks) {
        let audioRecorder = MockAudioRecorder()
        let transcriber = MockTranscriptionEngine()
        let textInserter = MockTextInserter()
        let widget = MockWidget()

        let controller = TestableRecordingController(
            audioRecorder: audioRecorder,
            transcriber: transcriber,
            textInserter: textInserter,
            widget: widget
        )

        controller.transcriptionProvider = {
            if let error = transcriptionError {
                throw error
            }
            return transcriptionResult
        }

        let mocks = TestMocks(
            audioRecorder: audioRecorder,
            transcriber: transcriber,
            textInserter: textInserter,
            widget: widget
        )

        return (controller, mocks)
    }
}
