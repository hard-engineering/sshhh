import Testing
import Foundation
@testable import sshhh

@Suite("TranscriptionStore")
struct TranscriptionStoreTests {

    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
    }

    @Test("addEntry keeps newest entries within retention limit")
    func addEntry_trimsToRetentionLimit() {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = TranscriptionStore(fileURL: url, maxEntries: 2)
        store.addEntry(text: "oldest", isSilent: false)
        store.addEntry(text: "middle", isSilent: false)
        store.addEntry(text: "newest", isSilent: false)

        #expect(store.entries.map(\.text) == ["newest", "middle"])
    }

    @Test("reload keeps persisted history within retention limit")
    func reload_trimsToRetentionLimit() {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = TranscriptionStore(fileURL: url, maxEntries: 3)
        store.addEntry(text: "one", isSilent: false)
        store.addEntry(text: "two", isSilent: false)
        store.addEntry(text: "three", isSilent: false)

        let reloaded = TranscriptionStore(fileURL: url, maxEntries: 2)

        #expect(reloaded.entries.map(\.text) == ["three", "two"])
    }
}
