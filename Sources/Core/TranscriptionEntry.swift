import Foundation

struct TranscriptionEntry: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let isSilent: Bool

    init(text: String, isSilent: Bool = false) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.isSilent = isSilent
    }
}
