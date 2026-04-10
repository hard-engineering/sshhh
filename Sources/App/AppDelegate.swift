import Cocoa
import SwiftUI
import AVFoundation
import FluidAudio

private let diagLog: FileHandle = {
    let path = "/tmp/sshhh_diag.log"
    FileManager.default.createFile(atPath: path, contents: Data())
    let handle = FileHandle(forWritingAtPath: path)!
    handle.truncateFile(atOffset: 0)
    return handle
}()

func diag(_ msg: String) {
    let line = "[DIAG \(Date())] \(msg)\n"
    diagLog.seekToEndOfFile()
    diagLog.write(line.data(using: .utf8)!)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    private var menubarController: MenubarController?
    private var floatingWidget: FloatingWidget?
    private var hotkeyManager: HotkeyManager?
    private var audioRecorder: AudioRecorder?
    private var transcriptionEngine: TranscriptionEngine?
    private var textInserter: TextInserter?
    private var mainWindowController: MainWindowController?
    private var activeSession: SlidingWindowAsrManager?
    private var sessionReady: CheckedContinuation<SlidingWindowAsrManager?, Never>?
    private var bufferStreamContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var bufferFeederTask: Task<Void, Never>?
    let transcriptionStore = TranscriptionStore()
    let dictionaryStore = DictionaryStore()

    private var isRecording = false
    private var isProcessing = false
    
    // MARK: - Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menubar-only app)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize UI components (Menubar, Widget)
        setupComponents()
        
        // Check permissions and start services if granted
        checkAccessibilityPermissions()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.stop()
    }
    
    // MARK: - Setup
    private func setupComponents() {
        // Text inserter
        textInserter = TextInserter()
        
        // Audio recorder
        audioRecorder = AudioRecorder()
        
        // Floating widget
        floatingWidget = FloatingWidget()
        
        // Menubar
        menubarController = MenubarController(
            onShowHistory: { [weak self] in self?.showMainWindow() },
            onQuit: { NSApp.terminate(nil) }
        )
        
        // Hotkey manager (initialized but not started)
        hotkeyManager = HotkeyManager(
            onKeyDown: { [weak self] in
                self?.startRecording()
            },
            onKeyUp: { [weak self] in
                self?.stopRecordingAndTranscribe()
            }
        )
    }
    
    private func startServices() {
        print("🚀 Starting services...")
        hotkeyManager?.start()

        Task {
            await initializeTranscriptionEngine()
        }
    }

    private func initializeTranscriptionEngine() async {
        diag("initializeTranscriptionEngine started")
        menubarController?.setState(.loading)

        do {
            transcriptionEngine = TranscriptionEngine()
            try await transcriptionEngine?.initialize()

            await MainActor.run {
                menubarController?.setState(.idle)
                diag("Transcription engine ready, isReady=\(self.transcriptionEngine?.isReady ?? false)")
            }
        } catch {
            diag("Transcription engine FAILED: \(error)")
            await MainActor.run {
                menubarController?.setState(.error)
                print("❌ Failed to initialize transcription engine: \(error)")
            }
        }
    }
    
    private var permissionTimer: Timer?
    
    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if accessEnabled {
            startServices()
        } else {
            print("⏳ Accessibility access not granted. Waiting for user input via System Prompt...")
            // Don't show custom alert immediately as it conflicts with System Alert.
            // Just start polling.
            startPollingPermissions()
        }
    }
    
    private func startPollingPermissions() {
        print("⏳ Polling for permissions (silently)...")
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            // Use false for prompt here! Otherwise it keeps re-triggering or insisting on the dialog.
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
            let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
            
            if accessEnabled {
                print("✅ Permissions granted! Starting services.")
                timer.invalidate()
                self?.permissionTimer = nil
                self?.startServices()
            }
        }
    }
    
    // MARK: - Recording Flow
    private var lastProcessingTime: Date = .distantPast
    
    private func startRecording() {
        guard !isRecording, !isProcessing else {
            print("⚠️ Cannot start: already recording/processing")
            return
        }

        // Cooldown check (prevent accidental re-triggering)
        if Date().timeIntervalSince(lastProcessingTime) < 1.0 {
            print("⏳ Cooldown active, ignoring trigger")
            return
        }

        guard transcriptionEngine?.isReady == true else {
            print("⚠️ Transcription engine not ready")
            return
        }

        print("🎤 Starting recording sequence...")
        diag("STATE: recording=true")
        isRecording = true

        DispatchQueue.main.async { [weak self] in
            self?.menubarController?.setState(.recording)
            self?.floatingWidget?.show(state: .recording)
            self?.playSound(.startRecording)
        }

        // Start mic capture immediately — audio is buffered internally
        // until the streaming session is ready (fixes lost audio bug)
        audioRecorder?.startRecording()

        // Set up ordered buffer stream (fixes ordering + tail audio bugs)
        let (bufferStream, continuation) = AsyncStream<AVAudioPCMBuffer>.makeStream()
        bufferStreamContinuation = continuation

        // Wire recorder to push into the ordered stream
        audioRecorder?.onBuffer = { [weak self] buffer in
            self?.bufferStreamContinuation?.yield(buffer)
        }

        // Create session in background, then flush early audio and start feeding
        Task {
            do {
                let terms = dictionaryStore.buildVocabularyTerms()
                let session = try await transcriptionEngine?.createSession(terms: terms)
                activeSession = session

                // Signal that session is ready (for stopRecordingAndTranscribe to await)
                sessionReady?.resume(returning: session)
                sessionReady = nil

                guard let session = session else { return }

                // Flush audio captured while session was being created
                if let recorder = audioRecorder {
                    for buffer in recorder.flushPendingBuffers() {
                        await session.streamAudio(buffer)
                    }
                }

                // Single feeder task: reads from ordered stream, calls streamAudio sequentially
                bufferFeederTask = Task {
                    for await buffer in bufferStream {
                        await session.streamAudio(buffer)
                    }
                }
            } catch {
                print("❌ Failed to start streaming session: \(error)")
                sessionReady?.resume(returning: nil)
                sessionReady = nil
                audioRecorder?.stopRecording()
                bufferStreamContinuation?.finish()
                bufferStreamContinuation = nil
                await MainActor.run {
                    isRecording = false
                    isProcessing = false
                    finishProcessing(text: nil)
                }
            }
        }
    }

    private func stopRecordingAndTranscribe() {
        guard isRecording else { return }

        isRecording = false
        isProcessing = true
        diag("STATE: recording=false, processing=true")

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isProcessing else { return }
            self.menubarController?.setState(.processing)
            self.floatingWidget?.show(state: .processing)
            self.playSound(.stopRecording)
        }

        // Stop mic capture
        audioRecorder?.stopRecording()

        // Close the buffer stream so the feeder task can drain and finish
        bufferStreamContinuation?.finish()
        bufferStreamContinuation = nil

        Task {
            do {
                // If session is still being created, wait for it
                let session: SlidingWindowAsrManager?
                if let active = activeSession {
                    session = active
                } else {
                    session = await withCheckedContinuation { cont in
                        sessionReady = cont
                    }
                    activeSession = session
                }

                // Wait for all buffered audio to be fed to the session
                await bufferFeederTask?.value
                bufferFeederTask = nil

                let text = try await session?.finish()
                let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
                activeSession = nil

                await MainActor.run {
                    finishProcessing(text: (trimmed?.isEmpty == false) ? trimmed : nil)
                }
            } catch {
                print("❌ Transcription error: \(error)")
                bufferFeederTask?.cancel()
                bufferFeederTask = nil
                activeSession = nil

                await MainActor.run {
                    finishProcessing(text: nil)
                }
            }
        }
    }
    
    private func finishProcessing(text: String?) {
        // Keeping isProcessing = true until text is inserted to prevent overlaps
        // Don't set isProcessing = false here yet if we are going to insert text
        
        diag("STATE: finishing processing")
        menubarController?.setState(.idle)
        floatingWidget?.hide()
        
        // Insert text if we got a result
        if let text = text, !text.isEmpty {
            diag("ASR raw result: \"\(text)\"")
            let finalText = dictionaryStore.applyReplacements(to: text)
            if finalText != text {
                diag("applyReplacements changed text to: \"\(finalText)\"")
            } else {
                diag("applyReplacements: no changes applied")
            }
            transcriptionStore.addEntry(text: finalText, isSilent: false)

            print("⌨️ Pausing hotkey manager for text insertion...")
            hotkeyManager?.stop() // CRITICAL: Stop listening to prevent feedback loop

            textInserter?.insertText(finalText) { [weak self] in
                print("✅ Text insertion complete. Resuming hotkey manager.")
                self?.hotkeyManager?.start()
                self?.isProcessing = false
                self?.lastProcessingTime = Date()
            }
        } else {
            transcriptionStore.addEntry(text: "", isSilent: true)
            isProcessing = false
            lastProcessingTime = Date()
        }
    }
    
    // MARK: - Main Window

    private func showMainWindow() {
        if mainWindowController == nil {
            mainWindowController = MainWindowController(
                transcriptionStore: transcriptionStore,
                dictionaryStore: dictionaryStore
            )
        }
        mainWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Audio Feedback
    private enum SoundType {
        case startRecording
        case stopRecording
    }
    
    private func playSound(_ type: SoundType) {
        let soundName: NSSound.Name
        switch type {
        case .startRecording:
            soundName = NSSound.Name("Morse")
        case .stopRecording:
            soundName = NSSound.Name("Pop")
        }
        NSSound(named: soundName)?.play()
    }
}
