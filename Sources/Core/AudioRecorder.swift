import AVFoundation
import Accelerate

/// Records audio from microphone at 16kHz mono (required by FluidAudio)
class AudioRecorder: AudioRecording {

    private let audioEngine = AVAudioEngine()

    private let targetSampleRate: Double = 16000
    private var converter: AVAudioConverter?

    private var isRecording = false

    /// Called with each resampled 16kHz mono buffer during recording
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    /// Internal buffer for audio captured before a streaming session is ready
    private var pendingBuffers: [AVAudioPCMBuffer] = []
    private let bufferLock = NSLock()

    /// Peak RMS across all buffers in the current recording (0.0 = silence, 1.0 = max)
    private(set) var peakRMS: Float = 0.0

    /// Minimum RMS to consider the recording as containing speech
    static let silenceThreshold: Float = 0.04

    init() {}

    func startRecording() {
        guard !isRecording else { return }

        bufferLock.lock()
        pendingBuffers.removeAll()
        bufferLock.unlock()
        peakRMS = 0.0

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create output format (16kHz mono)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("❌ Failed to create output format")
            return
        }

        // Create converter
        converter = AVAudioConverter(from: inputFormat, to: outputFormat)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, outputFormat: outputFormat)
        }

        do {
            try audioEngine.start()
            isRecording = true
            print("🎤 Recording started")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
        onBuffer = nil

        print("🎤 Recording stopped")
    }

    /// Returns and clears any audio buffers captured before onBuffer was set
    func flushPendingBuffers() -> [AVAudioPCMBuffer] {
        bufferLock.lock()
        let buffers = pendingBuffers
        pendingBuffers.removeAll()
        bufferLock.unlock()
        return buffers
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, outputFormat: AVAudioFormat) {
        guard let converter = converter else { return }

        // Calculate output buffer size
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        ) else { return }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil else {
            print("❌ Conversion error: \(error?.localizedDescription ?? "unknown")")
            return
        }

        // Track peak RMS for silence detection
        if let channelData = outputBuffer.floatChannelData?[0] {
            let frameCount = Int(outputBuffer.frameLength)
            if frameCount > 0 {
                var sumSquares: Float = 0
                vDSP_measqv(channelData, 1, &sumSquares, vDSP_Length(frameCount))
                let rms = sqrtf(sumSquares)
                if rms > peakRMS {
                    peakRMS = rms
                }
            }
        }

        if let callback = onBuffer {
            callback(outputBuffer)
        } else {
            // Buffer audio until streaming session is ready
            bufferLock.lock()
            pendingBuffers.append(outputBuffer)
            bufferLock.unlock()
        }
    }
}
