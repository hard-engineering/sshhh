import Foundation
import FluidAudio

/// Wrapper around FluidAudio ASR for speech transcription
class TranscriptionEngine {

    private var models: AsrModels?
    private var ctcModels: CtcModels?
    private(set) var isReady = false

    init() {}

    /// Initialize the transcription engine (downloads model on first run)
    func initialize() async throws {
        diag("Loading Parakeet v2 model...")

        models = try await AsrModels.downloadAndLoad(version: .v2)
        isReady = true
        diag("Parakeet v2 model loaded, isReady=true")
    }

    /// Create a new streaming transcription session with optional vocabulary boosting
    /// - Parameter terms: Custom vocabulary terms for boosting (empty = no boosting)
    /// - Returns: A started SlidingWindowAsrManager ready to receive audio
    func createSession(terms: [CustomVocabularyTerm]) async throws -> SlidingWindowAsrManager {
        guard let models = models, isReady else {
            throw TranscriptionError.notInitialized
        }

        let manager = SlidingWindowAsrManager(config: .streaming)

        // Configure vocabulary boosting before start (required ordering)
        if !terms.isEmpty {
            do {
                if ctcModels == nil {
                    diag("  CTC models not loaded, downloading ctc110m...")
                    ctcModels = try await CtcModels.downloadAndLoad(variant: .ctc110m)
                    diag("  CTC models downloaded and loaded")
                }

                let vocabulary = CustomVocabularyContext(terms: terms)
                try await manager.configureVocabularyBoosting(
                    vocabulary: vocabulary,
                    ctcModels: ctcModels!
                )
                diag("  Vocabulary boosting configured with \(terms.count) term(s)")
            } catch {
                diag("  Vocabulary boosting failed: \(error)")
            }
        }

        try await manager.start(models: models, source: .microphone)
        return manager
    }
}

enum TranscriptionError: Error {
    case notInitialized
    case transcriptionFailed
}
