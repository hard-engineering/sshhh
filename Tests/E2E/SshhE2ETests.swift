import Testing
import Foundation
@testable import sshhh

/// E2E tests for sshhh recording flow
/// Tests various Option key press scenarios and verifies app state
@Suite("sshhh E2E Tests")
struct SshhE2ETests {

    // MARK: - Brief Tap Tests

    @Test("Brief tap (< activation delay) should not start recording")
    func briefTap_NoRecording() async throws {
        let (controller, mocks) = createTestController()

        // Simulate key down
        controller.onKeyDown()

        // Wait less than activation delay (50ms < 150ms)
        try await Task.sleep(nanoseconds: 50_000_000)

        // Simulate key up before activation
        controller.onKeyUp()

        // Wait for any async processing
        try await Task.sleep(nanoseconds: 100_000_000)

        // Verify no recording started
        #expect(mocks.audioRecorder.startRecordingCallCount == 0, "Recording should not start on brief tap")
        #expect(mocks.widget.isVisible == false, "Widget should not be visible")
    }

    // MARK: - Quick Press Tests (Edge Case)

    @Test("Quick press just over activation delay - empty buffer scenario - widget should not get stuck")
    func quickPress_EmptyBuffer_WidgetNotStuck() async throws {
        let (controller, _) = createTestController(transcriptionResult: nil)

        // Simulate key down
        controller.onKeyDown()

        // Wait past activation delay but release quickly
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s (past 0.15s activation)

        // Key up
        controller.onKeyUp()

        // Wait for async processing to complete
        try await Task.sleep(nanoseconds: 300_000_000)

        // Critical assertion: state should be fully reset
        #expect(controller.isProcessing == false, "isProcessing should be false")
        #expect(controller.isRecording == false, "isRecording should be false")
    }

    // MARK: - Normal Recording Tests

    @Test("Normal press should complete full recording cycle")
    func normalPress_FullCycle() async throws {
        let (controller, mocks) = createTestController(transcriptionResult: "Hello world")

        // Start recording
        controller.onKeyDown()
        try await Task.sleep(nanoseconds: 200_000_000) // Wait past activation

        #expect(controller.isRecording == true, "Should be recording")
        #expect(mocks.widget.isVisible == true, "Widget should be visible")
        #expect(mocks.widget.currentState == .recording, "Widget should show recording")

        // Continue recording, then stop
        try await Task.sleep(nanoseconds: 300_000_000) // Total ~0.5s recording
        controller.onKeyUp()

        // Wait for transcription and insertion
        try await Task.sleep(nanoseconds: 500_000_000)

        // Verify full cycle completed
        #expect(mocks.audioRecorder.startRecordingCallCount == 1)
        #expect(mocks.audioRecorder.stopRecordingCallCount == 1)
        #expect(mocks.textInserter.lastInsertedText == "Hello world")
        #expect(mocks.widget.isVisible == false, "Widget should be hidden after completion")
        #expect(controller.isProcessing == false, "isProcessing should be false")
    }

    // MARK: - Rapid Press Tests

    @Test("Rapid double tap during cooldown should ignore second tap")
    func rapidDoubleTap_SecondIgnored() async throws {
        let (controller, mocks) = createTestController(transcriptionResult: "First")

        // First press
        controller.onKeyDown()
        try await Task.sleep(nanoseconds: 200_000_000)
        controller.onKeyUp()

        // Wait for processing to complete
        try await Task.sleep(nanoseconds: 500_000_000)

        // Second press immediately (within cooldown)
        controller.onKeyDown()
        try await Task.sleep(nanoseconds: 200_000_000)
        controller.onKeyUp()

        try await Task.sleep(nanoseconds: 200_000_000)

        // Only one recording should have occurred
        #expect(mocks.audioRecorder.startRecordingCallCount == 1, "Second press should be ignored during cooldown")
    }

    // MARK: - Error Handling Tests

    @Test("Transcription failure should reset state properly")
    func transcriptionFailure_StateReset() async throws {
        let error = NSError(domain: "MockTranscription", code: -1)
        let (controller, mocks) = createTestController(transcriptionError: error)

        controller.onKeyDown()
        try await Task.sleep(nanoseconds: 400_000_000)
        controller.onKeyUp()

        // Wait for failed transcription
        try await Task.sleep(nanoseconds: 500_000_000)

        // State should be reset
        #expect(controller.isRecording == false)
        #expect(controller.isProcessing == false)
        #expect(mocks.widget.isVisible == false)
        #expect(mocks.textInserter.lastInsertedText == nil, "No text should be inserted on failure")
    }

    @Test("Text insertion callback not firing should not leave widget visible")
    func textInsertionTimeout_WidgetHidden() async throws {
        let (controller, mocks) = createTestController(transcriptionResult: "Test")
        mocks.textInserter.config.shouldCallCompletion = false // Simulate stuck insertion

        controller.onKeyDown()
        try await Task.sleep(nanoseconds: 400_000_000)
        controller.onKeyUp()

        // Wait - completion won't fire
        try await Task.sleep(nanoseconds: 500_000_000)

        // Widget should be hidden even though isProcessing might be stuck
        #expect(mocks.widget.isVisible == false, "Widget should be hidden regardless of completion callback")

        // Manually trigger completion to clean up
        mocks.textInserter.triggerPendingCompletions()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(controller.isProcessing == false, "isProcessing should be false after completion")
    }

    // MARK: - State Consistency Tests

    @Test("State transitions should never have both isRecording and isProcessing true")
    func stateTransitions_MutuallyExclusive() async throws {
        let (controller, _) = createTestController(transcriptionResult: "Test")

        var states: [(isRecording: Bool, isProcessing: Bool)] = []

        // Capture state at each transition
        controller.onStateChange = { isRec, isProc in
            states.append((isRec, isProc))
        }

        controller.onKeyDown()
        try await Task.sleep(nanoseconds: 400_000_000)
        controller.onKeyUp()
        try await Task.sleep(nanoseconds: 600_000_000)

        // Verify we never have both true simultaneously
        for (index, state) in states.enumerated() {
            #expect(
                !(state.isRecording && state.isProcessing),
                "State \(index): Cannot be both recording=\(state.isRecording) and processing=\(state.isProcessing)"
            )
        }
    }

    // MARK: - Test Helpers

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

        // Wire up the transcription provider to simulate streaming session results
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

// MARK: - Mock Widget

class MockWidget: WidgetDisplaying {
    private(set) var isVisible = false
    private(set) var currentState: WidgetState?
    private(set) var showCallCount = 0
    private(set) var hideCallCount = 0

    func show(state: WidgetState) {
        showCallCount += 1
        isVisible = true
        currentState = state
        print("🧪 [MockWidget] show(state: \(state))")
    }

    func hide() {
        hideCallCount += 1
        isVisible = false
        print("🧪 [MockWidget] hide()")
    }

    func reset() {
        isVisible = false
        currentState = nil
        showCallCount = 0
        hideCallCount = 0
    }
}
