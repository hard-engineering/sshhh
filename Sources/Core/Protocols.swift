import Foundation
import AVFoundation

// MARK: - Protocols for testability

/// Protocol for audio recording functionality
protocol AudioRecording {
    var onBuffer: ((AVFoundation.AVAudioPCMBuffer) -> Void)? { get set }
    func startRecording()
    func stopRecording()
    func flushPendingBuffers() -> [AVAudioPCMBuffer]
}

/// Protocol for transcription functionality
protocol Transcribing {
    var isReady: Bool { get }
}

/// Protocol for text insertion functionality
protocol TextInserting {
    func insertText(_ text: String, completion: @escaping () -> Void)
}

/// Protocol for widget display
protocol WidgetDisplaying {
    func show(state: WidgetState)
    func hide()
}

/// Unified widget state enum
enum WidgetState {
    case recording
    case processing
}

/// Observable app state for testing
struct AppState: Equatable {
    var isRecording: Bool = false
    var isProcessing: Bool = false
    var widgetVisible: Bool = false
    var widgetState: WidgetState? = nil
    var lastTranscription: String? = nil
}

/// Delegate to observe state changes (for testing)
protocol AppStateObserver: AnyObject {
    func appStateDidChange(_ state: AppState)
}
