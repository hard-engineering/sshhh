import Foundation

class TranscriptionStore: ObservableObject {

    static let defaultMaxEntries = 500

    @Published private(set) var entries: [TranscriptionEntry] = []

    private let fileURL: URL
    private let maxEntries: Int

    init(maxEntries: Int = defaultMaxEntries) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("com.sshhh.app", isDirectory: true)

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        self.fileURL = appDir.appendingPathComponent("transcription_history.json")
        self.maxEntries = maxEntries
        load()
    }

    init(fileURL: URL, maxEntries: Int = defaultMaxEntries) {
        self.fileURL = fileURL
        self.maxEntries = maxEntries
        load()
    }

    // MARK: - Public

    func addEntry(text: String, isSilent: Bool) {
        let entry = TranscriptionEntry(text: text, isSilent: isSilent)
        entries.insert(entry, at: 0) // newest first
        trimToRetentionLimit()
        save()
    }

    func deleteEntry(_ entry: TranscriptionEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([TranscriptionEntry].self, from: data)
            let originalCount = entries.count
            trimToRetentionLimit()
            if entries.count != originalCount {
                save()
            }
        } catch {
            print("⚠️ Failed to load transcription history: \(error)")
        }
    }

    private func trimToRetentionLimit() {
        guard entries.count > maxEntries else {
            return
        }
        entries.removeSubrange(maxEntries..<entries.count)
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("⚠️ Failed to save transcription history: \(error)")
        }
    }
}
