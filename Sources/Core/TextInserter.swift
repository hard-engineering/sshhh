import Cocoa
import Carbon

/// Inserts text into the currently focused application using CGEvents
class TextInserter: TextInserting {

    private let focusDelay: TimeInterval = 0.05
    private let pasteCompletionDelay: TimeInterval = 0.2
    
    func insertText(_ text: String, completion: @escaping () -> Void = {}) {
        // Small delay to ensure focus is on target app
        DispatchQueue.main.asyncAfter(deadline: .now() + self.focusDelay) {
            // Save existing clipboard contents before overwriting
            let previousContents = self.saveClipboard()

            let pasteboardChangeCount = self.typeText(text)

            // Allow time for paste to complete. Restore only if the user has not
            // copied something else since sshhh staged the dictated text.
            DispatchQueue.main.asyncAfter(deadline: .now() + self.pasteCompletionDelay) {
                if NSPasteboard.general.changeCount == pasteboardChangeCount {
                    self.restoreClipboard(previousContents)
                }
                completion()
            }
        }
    }

    /// Saves all current pasteboard items so they can be restored later.
    private func saveClipboard() -> [NSPasteboardItem] {
        let pasteboard = NSPasteboard.general
        var saved: [NSPasteboardItem] = []

        for item in pasteboard.pasteboardItems ?? [] {
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            saved.append(copy)
        }
        return saved
    }

    /// Restores previously saved pasteboard items.
    private func restoreClipboard(_ items: [NSPasteboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    @discardableResult
    private func typeText(_ text: String) -> Int {
        // 1. Copy text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let pasteboardChangeCount = pasteboard.changeCount
        
        // 2. Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Cmd down
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand
        cmdDown?.post(tap: .cghidEventTap)
        
        // V down
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)
        
        // V up
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        vUp?.post(tap: .cghidEventTap)
        
        // Cmd up
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        cmdUp?.post(tap: .cghidEventTap)
        
        print("📋 Pasted text using Cmd+V")
        return pasteboardChangeCount
    }
}
