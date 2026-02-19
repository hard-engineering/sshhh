import Testing
import Foundation
@testable import sshhh

@Suite("DictionaryEntry")
struct DictionaryEntryTests {

    // MARK: - hasReplacement

    @Test("hasReplacement returns false when spokenForm is nil")
    func hasReplacement_nilSpokenForm() {
        let entry = DictionaryEntry(phrase: "Kubernetes")
        #expect(entry.hasReplacement == false)
    }

    @Test("hasReplacement returns false when spokenForm matches phrase case-insensitively")
    func hasReplacement_matchesPhrase() {
        let entry = DictionaryEntry(phrase: "Kubernetes", spokenForm: "kubernetes")
        #expect(entry.hasReplacement == false)
    }

    @Test("hasReplacement returns true when spokenForm differs from phrase")
    func hasReplacement_differsFromPhrase() {
        let entry = DictionaryEntry(phrase: "Kubernetes", spokenForm: "koo-ber-net-eez")
        #expect(entry.hasReplacement == true)
    }

    // MARK: - Codable round-trip

    @Test("Codable round-trip with spokenForm")
    func codableRoundTrip_withSpokenForm() throws {
        let entry = DictionaryEntry(phrase: "gRPC", spokenForm: "g r p c")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DictionaryEntry.self, from: data)

        #expect(decoded.id == entry.id)
        #expect(decoded.phrase == entry.phrase)
        #expect(decoded.spokenForm == entry.spokenForm)
        #expect(abs(decoded.createdAt.timeIntervalSinceReferenceDate - entry.createdAt.timeIntervalSinceReferenceDate) < 1.0)
    }

    @Test("Codable round-trip with nil spokenForm")
    func codableRoundTrip_nilSpokenForm() throws {
        let entry = DictionaryEntry(phrase: "API")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DictionaryEntry.self, from: data)

        #expect(decoded.id == entry.id)
        #expect(decoded.phrase == "API")
        #expect(decoded.spokenForm == nil)
    }
}
