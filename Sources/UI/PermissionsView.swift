import SwiftUI
import Cocoa
import AVFoundation

// MARK: - Permission State

enum PermissionStatus {
    case needed
    case requesting
    case granted
    case denied
}

// MARK: - Permissions View Model

class PermissionsViewModel: ObservableObject {
    @Published var micStatus: PermissionStatus = .needed
    @Published var accessibilityStatus: PermissionStatus = .needed
    @Published var hasInteracted = false

    var allGranted: Bool {
        micStatus == .granted && accessibilityStatus == .granted
    }

    private var pollTimer: Timer?

    init() {
        checkCurrentStatus()
    }

    func checkCurrentStatus() {
        // Check accessibility
        let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        if AXIsProcessTrustedWithOptions(axOptions as CFDictionary) {
            accessibilityStatus = .granted
        }

        // Check microphone
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            micStatus = .granted
        case .denied, .restricted:
            micStatus = .denied
        default:
            micStatus = .needed
        }
    }

    func requestMicrophone() {
        hasInteracted = true
        micStatus = .requesting
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.micStatus = .granted
                } else {
                    self?.micStatus = .denied
                }
            }
        }
    }

    func requestAccessibility() {
        hasInteracted = true
        accessibilityStatus = .requesting
        // This opens System Settings
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        startPolling()
    }

    func openMicSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    func quitAndReopen() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", bundlePath]
        task.launch()
        NSApp.terminate(nil)
    }

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollPermissions()
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollPermissions() {
        // Poll accessibility
        if accessibilityStatus != .granted {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
            if AXIsProcessTrustedWithOptions(options as CFDictionary) {
                accessibilityStatus = .granted
            }
        }

        // Poll microphone
        if micStatus != .granted {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                micStatus = .granted
            case .denied, .restricted:
                micStatus = .denied
            default:
                break
            }
        }
    }
}

// MARK: - Permissions View

struct PermissionsView: View {
    @ObservedObject var viewModel: PermissionsViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 80, height: 80)
                }

                Text("sshhh")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Permissions Required")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("sshhh needs a couple of permissions to work properly.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                PermissionCard(
                    icon: "mic",
                    iconColor: .orange,
                    title: "Microphone Access",
                    description: "Required to hear your voice for transcription.",
                    status: viewModel.micStatus,
                    onRequest: { viewModel.requestMicrophone() },
                    onOpenSettings: { viewModel.openMicSettings() }
                )

                PermissionCard(
                    icon: "keyboard",
                    iconColor: .orange,
                    title: "Accessibility Access",
                    description: "Required to type transcribed text into your applications.",
                    status: viewModel.accessibilityStatus,
                    onRequest: { viewModel.requestAccessibility() },
                    onOpenSettings: { viewModel.openAccessibilitySettings() }
                )
            }
            .padding(.horizontal, 24)

            if viewModel.allGranted {
                VStack(spacing: 10) {
                    Text("You're all set!")
                        .font(.callout)
                        .foregroundStyle(.green)
                        .fontWeight(.medium)

                    HStack(spacing: 6) {
                        Text("Hold")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\u{2325} Option")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("to start dictating. sshhh lives in your menu bar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Close this window") {
                        NSApp.keyWindow?.close()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            } else if viewModel.hasInteracted {
                VStack(spacing: 4) {
                    Text("Granted permissions but stuck?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Restart sshhh") {
                        viewModel.quitAndReopen()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(width: 480, height: 500)
    }
}

// MARK: - Permission Card

struct PermissionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let status: PermissionStatus
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Status row
                switch status {
                case .needed:
                    Button("Grant Permission") { onRequest() }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)

                case .requesting:
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Waiting...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("Open System Settings") { onOpenSettings() }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                case .granted:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Granted")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.green)

                case .denied:
                    Button("Open System Settings") { onOpenSettings() }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - Permissions Window Controller

class PermissionsWindowController: NSWindowController, NSWindowDelegate {

    let viewModel = PermissionsViewModel()
    var onAllGranted: (() -> Void)?
    private var cancellable: Any?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "sshhh"
        window.titlebarAppearsTransparent = true
        window.center()

        let view = PermissionsView(viewModel: PermissionsViewModel())
        window.contentView = NSHostingView(rootView: view)

        super.init(window: window)
        window.delegate = self

        // Use the same viewModel instance
        let sharedViewModel = self.viewModel
        window.contentView = NSHostingView(rootView: PermissionsView(viewModel: sharedViewModel))

        // Observe when all permissions are granted — start services immediately
        // but let user close the window themselves
        cancellable = sharedViewModel.$micStatus.combineLatest(sharedViewModel.$accessibilityStatus)
            .receive(on: RunLoop.main)
            .sink { [weak self] mic, ax in
                if mic == .granted && ax == .granted {
                    self?.viewModel.stopPolling()
                    self?.onAllGranted?()
                    self?.onAllGranted = nil // Only fire once
                }
            }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        viewModel.startPolling()
    }

    func windowWillClose(_ notification: Notification) {
        viewModel.stopPolling()
        NSApp.setActivationPolicy(.accessory)
    }
}
