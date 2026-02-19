import Foundation
import FluidAudio

/// Wrapper around FluidAudio ASR for speech transcription
class TranscriptionEngine {
    
    private var asrManager: AsrManager?
    private var ctcModels: CtcModels?
    private(set) var isReady = false
    
    init() {}
    
    /// Initialize the transcription engine (downloads model on first run)
    func initialize() async throws {
        print("⏳ Loading Parakeet v3 model...")
        
        // Download and load models
        // v2 = English-only (higher recall for English)
        // v3 = multilingual (25 European languages, auto-detects)
        let models = try await AsrModels.downloadAndLoad(version: .v2)
        
        // Create ASR manager with default config
        asrManager = AsrManager(config: .default)
        try await asrManager?.initialize(models: models)
        
        isReady = true
        print("✅ Parakeet v3 model loaded")
    }
    
    /// Transcribe audio samples
    /// - Parameter samples: Float array of 16kHz mono audio samples
    /// - Returns: Transcribed text
    func transcribe(samples: [Float]) async throws -> String? {
        guard let asrManager = asrManager, isReady else {
            throw TranscriptionError.notInitialized
        }
        
        guard !samples.isEmpty else {
            return nil
        }
        
        print("⏳ Transcribing \(samples.count) samples...")
        
        diag(" CTC models loaded = \(ctcModels != nil)")

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await asrManager.transcribe(samples)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        print("✅ Transcription completed in \(String(format: "%.2f", duration))s")
        print("📝 Result: \(result.text)")
        diag(" ctcDetectedTerms: \(result.ctcDetectedTerms ?? [])")
        diag(" ctcAppliedTerms: \(result.ctcAppliedTerms ?? [])")

        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// Configure vocabulary boosting with custom terms
    func configureVocabulary(terms: [CustomVocabularyTerm]) async {
        diag(" configureVocabulary entered with \(terms.count) term(s)")
        guard let asrManager = asrManager else {
            diag("   BAIL: asrManager is nil — engine not initialized yet")
            return
        }

        guard !terms.isEmpty else {
            asrManager.disableVocabularyBoosting()
            diag("   No terms — vocabulary boosting disabled")
            return
        }

        do {
            if ctcModels == nil {
                diag("   CTC models not loaded, downloading ctc110m...")
                ctcModels = try await CtcModels.downloadAndLoad(variant: .ctc110m)
                diag("   CTC models downloaded and loaded")
            } else {
                diag("   CTC models already loaded")
            }

            let vocabulary = CustomVocabularyContext(terms: terms)
            try await asrManager.configureVocabularyBoosting(
                vocabulary: vocabulary,
                ctcModels: ctcModels!
            )
            diag("   SUCCESS: vocabulary boosting configured with \(terms.count) term(s)")
            diag("   vocabulary boosting configuration succeeded")
        } catch {
            diag("   FAILED: \(error)")
        }
    }
}

enum TranscriptionError: Error {
    case notInitialized
    case transcriptionFailed
}
