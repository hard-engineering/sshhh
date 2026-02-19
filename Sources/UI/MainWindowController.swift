import Cocoa
import SwiftUI

class MainWindowController: NSWindowController, NSWindowDelegate {

    private let transcriptionStore: TranscriptionStore
    private let dictionaryStore: DictionaryStore

    init(transcriptionStore: TranscriptionStore, dictionaryStore: DictionaryStore) {
        self.transcriptionStore = transcriptionStore
        self.dictionaryStore = dictionaryStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "sshhh"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 600, height: 400)
        window.center()

        let contentView = MainContentView(store: transcriptionStore, dictionaryStore: dictionaryStore)
        window.contentView = NSHostingView(rootView: contentView)

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.setActivationPolicy(.regular)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
