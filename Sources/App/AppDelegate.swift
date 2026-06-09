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
    private var permissionsWindowController: PermissionsWindowController?
    private var activeSession: SlidingWindowAsrManager?
    private var sessionCreationTask: Task<SlidingWindowAsrManager?, Never>?
    private var bufferStreamContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var bufferFeederTask: Task<Void, Never>?
    private var recordingGeneration = 0
    let transcriptionStore = TranscriptionStore()
    let dictionaryStore = DictionaryStore()
    let updateChecker = UpdateChecker()

    private var isRecording = false
    private var isProcessing = false
    
    // MARK: - Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menubar-only app)
        NSApp.setActivationPolicy(.accessory)

        // Initialize UI components (Menubar, Widget)
        setupComponents()

        // Check permissions and start services if granted
        checkPermissions()
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
            onOpenApp: { [weak self] in self?.showMainWindow() },
            onShowHistory: { [weak self] in self?.showMainWindow(tab: .history) },
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
        updateChecker.checkOnce()

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
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private func checkPermissions() {
        let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let axGranted = AXIsProcessTrustedWithOptions(axOptions as CFDictionary)
        let micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

        if axGranted && micGranted && hasCompletedOnboarding {
            startServices()
        } else {
            showPermissionsWindow()
        }
    }

    private func showPermissionsWindow() {
        permissionsWindowController = PermissionsWindowController()
        permissionsWindowController?.onAllGranted = { [weak self] in
            self?.hasCompletedOnboarding = true
            self?.permissionsWindowController?.window?.close()
            self?.permissionsWindowController = nil
            self?.startServices()
            self?.showMainWindow()
        }
        permissionsWindowController?.showWindow(nil)
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
        recordingGeneration += 1
        let generation = recordingGeneration
        resetStreamingStateBeforeRecording()

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
        sessionCreationTask = Task { [weak self] in
            guard let self = self else { return nil }

            do {
                let terms = self.dictionaryStore.buildVocabularyTerms()
                let session = try await self.transcriptionEngine?.createSession(terms: terms)

                guard let session = session else {
                    if self.recordingGeneration == generation {
                        self.activeSession = nil
                    }
                    return nil
                }

                guard !Task.isCancelled,
                      self.recordingGeneration == generation,
                      self.isRecording || self.isProcessing else {
                    _ = try? await session.finish()
                    return nil
                }

                // Create feeder task before publishing activeSession, so stop can
                // always await the feeder after observing a ready session.
                self.bufferFeederTask = Task { [weak self] in
                    // First flush audio captured while session was being created
                    if let recorder = self?.audioRecorder {
                        for buffer in recorder.flushPendingBuffers() {
                            guard !Task.isCancelled else { return }
                            await session.streamAudio(buffer)
                        }
                    }
                    // Then drain live audio from the ordered stream
                    for await buffer in bufferStream {
                        guard !Task.isCancelled else { return }
                        await session.streamAudio(buffer)
                    }
                }

                // Now signal ready — stopRecordingAndTranscribe can safely await bufferFeederTask
                self.activeSession = session
                return session
            } catch {
                guard !Task.isCancelled, self.recordingGeneration == generation else {
                    return nil
                }

                print("❌ Failed to start streaming session: \(error)")
                self.audioRecorder?.stopRecording()
                self.bufferStreamContinuation?.finish()
                self.bufferStreamContinuation = nil
                self.bufferFeederTask?.cancel()
                self.bufferFeederTask = nil
                self.sessionCreationTask = nil
                self.activeSession = nil

                await MainActor.run {
                    if self.isRecording {
                        self.isRecording = false
                        self.isProcessing = false
                        self.finishProcessing(text: nil)
                    }
                }
                return nil
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

        let generation = recordingGeneration
        audioRecorder?.stopRecording()
        let peakRMS = audioRecorder?.peakRMS ?? 0
        diag("Audio peakRMS: \(peakRMS), threshold: \(AudioRecorder.silenceThreshold)")

        // Skip transcription entirely if audio was silent.
        if peakRMS < AudioRecorder.silenceThreshold {
            diag("Silent recording detected, skipping transcription")
            cancelStreamingSession(for: generation)
            finishProcessing(text: nil)
            return
        }

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
                    session = await sessionCreationTask?.value
                    guard recordingGeneration == generation else { return }
                    activeSession = session
                }

                guard let session = session else {
                    sessionCreationTask = nil
                    activeSession = nil
                    await MainActor.run {
                        finishProcessing(text: nil)
                    }
                    return
                }

                // Wait for all buffered audio to be fed to the session
                await bufferFeederTask?.value
                bufferFeederTask = nil
                sessionCreationTask = nil

                let text = try await session.finish()
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                activeSession = nil

                await MainActor.run {
                    finishProcessing(text: trimmed.isEmpty ? nil : trimmed)
                }
            } catch {
                guard recordingGeneration == generation else { return }

                print("❌ Transcription error: \(error)")
                bufferFeederTask?.cancel()
                bufferFeederTask = nil
                sessionCreationTask = nil
                activeSession = nil

                await MainActor.run {
                    finishProcessing(text: nil)
                }
            }
        }
    }

    private func resetStreamingStateBeforeRecording() {
        sessionCreationTask?.cancel()
        sessionCreationTask = nil
        bufferStreamContinuation?.finish()
        bufferStreamContinuation = nil
        bufferFeederTask?.cancel()
        bufferFeederTask = nil

        if let staleSession = activeSession {
            activeSession = nil
            Task {
                _ = try? await staleSession.finish()
            }
        }
    }

    private func cancelStreamingSession(for generation: Int) {
        guard recordingGeneration == generation else { return }

        recordingGeneration += 1
        sessionCreationTask?.cancel()
        sessionCreationTask = nil
        bufferStreamContinuation?.finish()
        bufferStreamContinuation = nil
        bufferFeederTask?.cancel()
        bufferFeederTask = nil

        if let session = activeSession {
            activeSession = nil
            Task {
                _ = try? await session.finish()
            }
        } else {
            activeSession = nil
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

    private func showMainWindow(tab: SidebarItem? = nil) {
        if mainWindowController == nil {
            mainWindowController = MainWindowController(
                transcriptionStore: transcriptionStore,
                dictionaryStore: dictionaryStore,
                updateChecker: updateChecker
            )
        }
        if let tab = tab {
            mainWindowController?.navigationState.selection = tab
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
