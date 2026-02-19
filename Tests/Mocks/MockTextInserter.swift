import Foundation
@testable import sshhh

/// Mock text inserter for testing
class MockTextInserter: TextInserting {

    struct Config {
        /// Simulated insertion delay
        var insertionDelay: TimeInterval = 0.05
        /// Should the completion callback be called?
        var shouldCallCompletion: Bool = true
    }

    var config = Config()

    private(set) var insertTextCallCount = 0
    private(set) var lastInsertedText: String?
    private(set) var pendingCompletions: [() -> Void] = []

    var onInsertText: ((String) -> Void)?

    func insertText(_ text: String, completion: @escaping () -> Void) {
        insertTextCallCount += 1
        lastInsertedText = text
        onInsertText?(text)

        print("🧪 [MockTextInserter] Inserting: \"\(text)\"")

        if config.shouldCallCompletion {
            DispatchQueue.main.asyncAfter(deadline: .now() + config.insertionDelay) {
                print("🧪 [MockTextInserter] Insertion complete")
                completion()
            }
        } else {
            // Store completion for manual triggering in tests
            pendingCompletions.append(completion)
            print("🧪 [MockTextInserter] Completion deferred (manual trigger required)")
        }
    }

    /// Manually trigger pending completions (for testing stuck states)
    func triggerPendingCompletions() {
        let completions = pendingCompletions
        pendingCompletions.removeAll()
        completions.forEach { $0() }
    }

    func reset() {
        insertTextCallCount = 0
        lastInsertedText = nil
        pendingCompletions.removeAll()
        config = Config()
    }
}
