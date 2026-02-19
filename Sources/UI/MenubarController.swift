import Cocoa
import SwiftUI

/// Manages the menubar status item and dropdown menu
class MenubarController {
    
    enum State {
        case loading
        case idle
        case recording
        case processing
        case error
    }
    
    private var statusItem: NSStatusItem?
    private let onShowHistory: () -> Void
    private let onQuit: () -> Void

    init(onShowHistory: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onShowHistory = onShowHistory
        self.onQuit = onQuit
        setupStatusItem()
    }
    
    private func getAppLogo() -> NSImage? {
        let image = NSApplication.shared.applicationIconImage.copy() as? NSImage
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = false // Keep original colors
        return image
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = getAppLogo()
        }
        
        // Create menu
        let menu = NSMenu()
        
        let aboutItem = NSMenuItem(title: "sshhh", action: nil, keyEquivalent: "")
        aboutItem.isEnabled = false
        menu.addItem(aboutItem)
        
        let statusMenuItem = NSMenuItem(title: "Hold Option (⌥) to dictate", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "Open sshhh...", action: #selector(openMainWindow), keyEquivalent: ",")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    func setState(_ state: State) {
        guard let button = statusItem?.button else { return }
        
        var image: NSImage?
        let tintColor: NSColor?
        
        switch state {
        case .loading:
            image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Loading")
            tintColor = .systemOrange
        case .idle:
            image = getAppLogo()
            tintColor = nil
        case .recording:
            image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Recording")
            tintColor = .systemRed
        case .processing:
            image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Processing")
            tintColor = .systemBlue
        case .error:
            image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Error")
            tintColor = .systemRed
        }
        
        button.image = image
        
        if let tintColor = tintColor {
            button.image?.isTemplate = true
            button.contentTintColor = tintColor
        } else {
            // For App Logo (idle), keep original colors
            button.contentTintColor = nil
        }
    }
    
    @objc private func openMainWindow() {
        onShowHistory()
    }

    @objc private func quitApp() {
        onQuit()
    }
}
