import Foundation

/// Testable recording controller that extracts the core state machine
/// from AppDelegate for isolated testing with mock dependencies
class TestableRecordingController {

    // MARK: - Dependencies (injectable)

    private let audioRecorder: AudioRecording
    private let transcriber: Transcribing
    private let textInserter: TextInserting
    private let widget: WidgetDisplaying

    // MARK: - State

    private(set) var isRecording = false
    private(set) var isProcessing = false
    private var lastProcessingTime: Date = .distantPast

    /// Activation delay before recording starts (filters accidental taps)
    let activationDelay: TimeInterval

    /// Cooldown period after processing before allowing new recording
    let cooldownPeriod: TimeInterval

    // MARK: - Internal State

    private var activationWorkItem: DispatchWorkItem?
    private var recordingActivated = false

    // MARK: - Callbacks for testing

    var onStateChange: ((Bool, Bool) -> Void)? // (isRecording, isProcessing)

    // MARK: - Init

    init(
        audioRecorder: AudioRecording,
        transcriber: Transcribing,
        textInserter: TextInserting,
        widget: WidgetDisplaying,
        activationDelay: TimeInterval = 0.15,
        cooldownPeriod: TimeInterval = 1.0
    ) {
        self.audioRecorder = audioRecorder
        self.transcriber = transcriber
        self.textInserter = textInserter
        self.widget = widget
        self.activationDelay = activationDelay
        self.cooldownPeriod = cooldownPeriod
    }

    // MARK: - Key Events

    func onKeyDown() {
        recordingActivated = false

        // Schedule recording activation after delay
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            print("🎯 [Controller] Activation delay passed")
            self.recordingActivated = true
            self.startRecording()
        }
        activationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay, execute: workItem)

        print("🎯 [Controller] Key down - scheduled activation in \(activationDelay)s")
    }

    func onKeyUp() {
        // Cancel pending activation if still waiting
        activationWorkItem?.cancel()
        activationWorkItem = nil

        // Only stop recording if it was actually activated
        if recordingActivated {
            recordingActivated = false
            stopRecordingAndTranscribe()
        }

        print("🎯 [Controller] Key up - recordingActivated was \(recordingActivated)")
    }

    // MARK: - Recording Flow

    private func startRecording() {
        guard !isRecording, !isProcessing else {
            print("⚠️ [Controller] Cannot start: already recording/processing")
            return
        }

        // Cooldown check
        if Date().timeIntervalSince(lastProcessingTime) < cooldownPeriod {
            print("⏳ [Controller] Cooldown active, ignoring trigger")
            return
        }

        guard transcriber.isReady else {
            print("⚠️ [Controller] Transcriber not ready")
            return
        }

        print("🎤 [Controller] Starting recording")
        isRecording = true
        notifyStateChange()

        DispatchQueue.main.async { [weak self] in
            self?.widget.show(state: .recording)
        }

        audioRecorder.startRecording()
    }

    private func stopRecordingAndTranscribe() {
        guard isRecording else { return }

        isRecording = false
        isProcessing = true
        notifyStateChange()

        // CRITICAL: Capture isProcessing state for the async block
        // This prevents the race condition where the async block
        // shows the widget after finishProcessing has already hidden it
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isProcessing else { return }
            self.widget.show(state: .processing)
        }

        // Get recorded audio
        guard let samples = audioRecorder.stopRecording() else {
            print("⚠️ [Controller] No audio samples (empty buffer)")
            finishProcessing(text: nil)
            return
        }

        print("🔄 [Controller] Transcribing \(samples.count) samples")

        // Transcribe
        Task {
            do {
                let text = try await transcriber.transcribe(samples: samples)
                await MainActor.run {
                    self.finishProcessing(text: text)
                }
            } catch {
                print("❌ [Controller] Transcription error: \(error)")
                await MainActor.run {
                    self.finishProcessing(text: nil)
                }
            }
        }
    }

    private func finishProcessing(text: String?) {
        print("✅ [Controller] Finishing processing, text: \(text ?? "nil")")

        widget.hide()

        if let text = text, !text.isEmpty {
            textInserter.insertText(text) { [weak self] in
                print("✅ [Controller] Text insertion complete")
                self?.isProcessing = false
                self?.lastProcessingTime = Date()
                self?.notifyStateChange()
            }
        } else {
            isProcessing = false
            lastProcessingTime = Date()
            notifyStateChange()
        }
    }

    private func notifyStateChange() {
        onStateChange?(isRecording, isProcessing)
    }
}
