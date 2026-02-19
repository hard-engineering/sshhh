import Foundation

struct DictionaryEntry: Identifiable, Codable {
    let id: UUID
    let phrase: String
    let spokenForm: String?
    let createdAt: Date

    var hasReplacement: Bool {
        guard let spoken = spokenForm else { return false }
        return spoken.lowercased() != phrase.lowercased()
    }

    init(phrase: String, spokenForm: String? = nil) {
        self.id = UUID()
        self.phrase = phrase
        self.spokenForm = spokenForm
        self.createdAt = Date()
    }
}
