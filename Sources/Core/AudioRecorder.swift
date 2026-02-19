import AVFoundation
import Accelerate

/// Records audio from microphone at 16kHz mono (required by FluidAudio)
class AudioRecorder: AudioRecording {
    
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    
    private let targetSampleRate: Double = 16000
    private var converter: AVAudioConverter?
    
    private var isRecording = false
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        // Request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if granted {
                print("✅ Microphone access granted")
            } else {
                print("❌ Microphone access denied")
            }
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        bufferLock.lock()
        audioBuffer.removeAll()
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
    
    func stopRecording() -> [Float]? {
        guard isRecording else { return nil }
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
        
        bufferLock.lock()
        let samples = audioBuffer
        bufferLock.unlock()
        
        print("🎤 Recording stopped, \(samples.count) samples (\(String(format: "%.2f", Double(samples.count) / targetSampleRate))s)")
        
        return samples.isEmpty ? nil : samples
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
        
        // Extract float samples
        guard let channelData = outputBuffer.floatChannelData?[0] else { return }
        let frameLength = Int(outputBuffer.frameLength)
        
        var samples = [Float](repeating: 0, count: frameLength)
        for i in 0..<frameLength {
            samples[i] = channelData[i]
        }
        
        // Append to buffer
        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)
        bufferLock.unlock()
    }
}
