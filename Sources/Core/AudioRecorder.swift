import AVFoundation
import Accelerate

/// Records audio from microphone at 16kHz mono (required by FluidAudio)
class AudioRecorder: AudioRecording {

    private let audioEngine = AVAudioEngine()

    private let targetSampleRate: Double = 16000
    private var converter: AVAudioConverter?

    private var isRecording = false
    private var onBufferCallback: ((AVAudioPCMBuffer) -> Void)?
    private var _peakRMS: Float = 0.0

    /// Called with each resampled 16kHz mono buffer during recording
    var onBuffer: ((AVAudioPCMBuffer) -> Void)? {
        get {
            bufferLock.lock()
            let callback = onBufferCallback
            bufferLock.unlock()
            return callback
        }
        set {
            bufferLock.lock()
            onBufferCallback = newValue
            bufferLock.unlock()
        }
    }

    /// Internal buffer for audio captured before a streaming session is ready
    private var pendingBuffers: [AVAudioPCMBuffer] = []
    private let bufferLock = NSLock()

    /// Peak RMS across all buffers in the current recording (0.0 = silence, 1.0 = max)
    var peakRMS: Float {
        bufferLock.lock()
        let value = _peakRMS
        bufferLock.unlock()
        return value
    }

    /// Minimum RMS to consider the recording as containing speech
    static let silenceThreshold: Float = 0.04

    init() {}

    func startRecording() {
        guard !isRecording else { return }

        bufferLock.lock()
        pendingBuffers.removeAll()
        _peakRMS = 0.0
        bufferLock.unlock()

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
        guard let newConverter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            print("❌ Failed to create audio converter")
            return
        }
        converter = newConverter

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, outputFormat: outputFormat)
        }

        do {
            try audioEngine.start()
            isRecording = true
            print("🎤 Recording started")
        } catch {
            inputNode.removeTap(onBus: 0)
            converter = nil
            onBuffer = nil
            print("❌ Failed to start audio engine: \(error)")
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
        converter = nil
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

        var callback: ((AVAudioPCMBuffer) -> Void)?
        bufferLock.lock()
        updatePeakRMS(outputBuffer)
        callback = onBufferCallback
        if callback == nil {
            // Buffer audio until streaming session is ready
            pendingBuffers.append(outputBuffer)
        }
        bufferLock.unlock()

        if let callback = callback {
            callback(outputBuffer)
        }
    }

    private func updatePeakRMS(_ outputBuffer: AVAudioPCMBuffer) {
        guard let channelData = outputBuffer.floatChannelData?[0] else {
            return
        }

        let frameCount = Int(outputBuffer.frameLength)
        guard frameCount > 0 else {
            return
        }

        var sumSquares: Float = 0
        vDSP_measqv(channelData, 1, &sumSquares, vDSP_Length(frameCount))
        let rms = sqrtf(sumSquares)
        if rms > _peakRMS {
            _peakRMS = rms
        }
    }
}
