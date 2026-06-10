import Foundation
import FluidAudio

class DictionaryStore: ObservableObject {

    @Published private(set) var entries: [DictionaryEntry] = []
    @Published private(set) var vocabularyBoostingWarning: String?

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("com.sshhh.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("dictionary.json")
        load()
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    // MARK: - Public

    func addEntry(phrase: String, spokenForm: String?) {
        let spoken = spokenForm?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = DictionaryEntry(
            phrase: phrase.trimmingCharacters(in: .whitespacesAndNewlines),
            spokenForm: (spoken?.isEmpty == false) ? spoken : nil
        )
        entries.insert(entry, at: 0)
        save()
    }

    func deleteEntry(_ entry: DictionaryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func updateEntry(_ entry: DictionaryEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        save()
    }

    func setVocabularyBoostingWarning(_ warning: String?) {
        vocabularyBoostingWarning = warning
    }

    // MARK: - Vocabulary Boosting

    func buildVocabularyTerms() -> [CustomVocabularyTerm] {
        entries.map { entry in
            let aliases: [String]? = entry.spokenForm.map { [$0] }
            return CustomVocabularyTerm(
                text: entry.phrase,
                weight: 10.0,
                aliases: aliases
            )
        }
    }

    // MARK: - Text Replacement

    func applyReplacements(to text: String) -> String {
        var result = text
        let replacementEntries = entries
            .filter { $0.hasReplacement && $0.spokenForm?.isEmpty == false }
            .sorted { ($0.spokenForm ?? "").count > ($1.spokenForm ?? "").count }

        for entry in replacementEntries {
            guard let spoken = entry.spokenForm, entry.hasReplacement else { continue }
            let pattern = replacementPattern(for: spoken)
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }

            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: NSRegularExpression.escapedTemplate(for: entry.phrase)
            )
        }
        return result
    }

    private func replacementPattern(for spoken: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: spoken)
        let startBoundary = spoken.first?.needsWordBoundary == true ? "\\b" : ""
        let endBoundary = spoken.last?.needsWordBoundary == true ? "\\b" : ""
        return startBoundary + escaped + endBoundary
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([DictionaryEntry].self, from: data)
        } catch {
            print("⚠️ Failed to load dictionary: \(error)")
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("⚠️ Failed to save dictionary: \(error)")
        }
    }
}

private extension Character {
    var needsWordBoundary: Bool {
        isLetter || isNumber || self == "_"
    }
}
