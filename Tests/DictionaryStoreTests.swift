import Testing
import Foundation
@testable import sshhh

@Suite("DictionaryStore")
struct DictionaryStoreTests {

    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
    }

    private func makeStore(url: URL? = nil) -> (DictionaryStore, URL) {
        let fileURL = url ?? makeTempURL()
        return (DictionaryStore(fileURL: fileURL), fileURL)
    }

    // MARK: - CRUD

    @Test("addEntry inserts at front")
    func addEntry_insertsAtFront() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.addEntry(phrase: "first", spokenForm: nil)
        store.addEntry(phrase: "second", spokenForm: nil)

        #expect(store.entries.count == 2)
        #expect(store.entries[0].phrase == "second")
        #expect(store.entries[1].phrase == "first")
    }

    @Test("deleteEntry removes by id")
    func deleteEntry_removesById() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.addEntry(phrase: "keep", spokenForm: nil)
        store.addEntry(phrase: "remove", spokenForm: nil)

        let toRemove = store.entries.first { $0.phrase == "remove" }!
        store.deleteEntry(toRemove)

        #expect(store.entries.count == 1)
        #expect(store.entries[0].phrase == "keep")
    }

    @Test("updateEntry replaces in-place")
    func updateEntry_replacesInPlace() throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.addEntry(phrase: "original", spokenForm: "orig")
        let existing = store.entries[0]

        let updated = try makeUpdatedEntry(from: existing, newPhrase: "updated", newSpokenForm: "upd")
        store.updateEntry(updated)

        #expect(store.entries.count == 1)
        #expect(store.entries[0].phrase == "updated")
        #expect(store.entries[0].spokenForm == "upd")
        #expect(store.entries[0].id == existing.id)
    }

    // MARK: - Whitespace trimming

    @Test("addEntry trims whitespace from phrase and spokenForm")
    func addEntry_trimsWhitespace() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.addEntry(phrase: "  Kubernetes  ", spokenForm: "  kube  ")

        #expect(store.entries[0].phrase == "Kubernetes")
        #expect(store.entries[0].spokenForm == "kube")
    }

    @Test("addEntry converts empty spokenForm to nil")
    func addEntry_emptySpokenFormBecomesNil() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.addEntry(phrase: "API", spokenForm: "   ")

        #expect(store.entries[0].spokenForm == nil)
    }

    // MARK: - Persistence

    @Test("save then reload from same file restores entries")
    func persistence_saveAndReload() {
        let url = makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = DictionaryStore(fileURL: url)
        store.addEntry(phrase: "gRPC", spokenForm: "g r p c")
        store.addEntry(phrase: "API", spokenForm: nil)

        let reloaded = DictionaryStore(fileURL: url)

        #expect(reloaded.entries.count == 2)
        #expect(reloaded.entries[0].phrase == "API")
        #expect(reloaded.entries[1].phrase == "gRPC")
        #expect(reloaded.entries[1].spokenForm == "g r p c")
    }

    // MARK: - buildVocabularyTerms

    @Test("buildVocabularyTerms returns correct terms with and without spokenForm")
    func buildVocabularyTerms() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.addEntry(phrase: "Kubernetes", spokenForm: "kube")
        store.addEntry(phrase: "API", spokenForm: nil)

        let terms = store.buildVocabularyTerms()

        #expect(terms.count == 2)

        // "API" inserted last, so at front
        #expect(terms[0].text == "API")
        #expect(terms[0].weight == 10.0)
        #expect(terms[0].aliases == nil)

        #expect(terms[1].text == "Kubernetes")
        #expect(terms[1].weight == 10.0)
        #expect(terms[1].aliases == ["kube"])
    }

    // MARK: - applyReplacements

    @Test("applyReplacements replaces spoken form with phrase case-insensitively")
    func applyReplacements_caseInsensitive() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.addEntry(phrase: "Kubernetes", spokenForm: "kube")

        let result = store.applyReplacements(to: "deploy to Kube cluster")
        #expect(result == "deploy to Kubernetes cluster")
    }

    @Test("applyReplacements skips entries without replacement")
    func applyReplacements_skipsNoReplacement() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.addEntry(phrase: "API", spokenForm: nil)
        store.addEntry(phrase: "Docker", spokenForm: "docker")

        let result = store.applyReplacements(to: "API and docker")
        #expect(result == "API and docker")
    }

    @Test("applyReplacements leaves unmatched text unchanged")
    func applyReplacements_unmatchedText() {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.addEntry(phrase: "Kubernetes", spokenForm: "kube")

        let result = store.applyReplacements(to: "hello world")
        #expect(result == "hello world")
    }

    // MARK: - Helpers

    private func makeUpdatedEntry(
        from original: DictionaryEntry,
        newPhrase: String,
        newSpokenForm: String?
    ) throws -> DictionaryEntry {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        var dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        dict["phrase"] = newPhrase
        dict["spokenForm"] = newSpokenForm
        let modified = try JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DictionaryEntry.self, from: modified)
    }
}
