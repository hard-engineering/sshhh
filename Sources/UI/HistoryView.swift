import SwiftUI

// MARK: - Navigation State

class NavigationState: ObservableObject {
    @Published var selection: SidebarItem? = .home
}

// MARK: - Root View

struct MainContentView: View {
    @ObservedObject var store: TranscriptionStore
    @ObservedObject var dictionaryStore: DictionaryStore
    @ObservedObject var navigationState: NavigationState

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $navigationState.selection)
                .frame(width: 180)
            Divider()
            Group {
                switch navigationState.selection {
                case .home, .none:
                    HomeView(store: store)
                case .history:
                    HistoryView(store: store)
                case .dictionary:
                    DictionaryView(store: dictionaryStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Sidebar

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case history = "History"
    case dictionary = "Dictionary"

    var id: Self { self }

    var icon: String {
        switch self {
        case .home: return "house"
        case .history: return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .dictionary: return "book"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            Label(item.rawValue, systemImage: item.icon)
                .tag(item)
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Home View

struct HomeView: View {
    @ObservedObject var store: TranscriptionStore
    @State private var tryItText = ""
    @FocusState private var tryItFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("sshhh")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Push-to-talk dictation, entirely on-device")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    StatCard(
                        title: "Dictations",
                        value: "\(dictationCount)",
                        icon: "mic.fill",
                        tint: .red
                    )
                    StatCard(
                        title: "Words",
                        value: formattedWordCount,
                        icon: "text.word.spacing",
                        tint: .blue
                    )
                    StatCard(
                        title: "Avg. Length",
                        value: avgWords,
                        icon: "ruler",
                        tint: .orange
                    )
                }
                .padding(.horizontal, 24)

                // Try it here
                VStack(alignment: .leading, spacing: 8) {
                    Text("Try it here")
                        .font(.headline)
                    Text("Hold Option (\u{2325}) and speak.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $tryItText)
                        .font(.body)
                        .focused($tryItFocused)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 80)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .onAppear { tryItFocused = true }

                // How to Use
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to Use")
                        .font(.headline)

                    HowToStep(
                        number: 1,
                        title: "Hold Option (\u{2325})",
                        description: "Press and hold the Option key anywhere on your Mac to start recording."
                    )
                    HowToStep(
                        number: 2,
                        title: "Speak",
                        description: "Dictate naturally — a floating indicator confirms you're being heard."
                    )
                    HowToStep(
                        number: 3,
                        title: "Release to Transcribe",
                        description: "Let go of Option. Your speech is transcribed and pasted at the cursor."
                    )
                }
                .padding(16)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Tips
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tips")
                        .font(.headline)

                    TipRow(icon: "book.fill", text: "Add custom words in Dictionary to improve accuracy for names and jargon.")
                    TipRow(icon: "arrow.triangle.swap", text: "Dictionary entries with a spoken form auto-replace — say one thing, type another.")
                    TipRow(icon: "lock.shield.fill", text: "Everything runs locally on Apple Neural Engine. No audio leaves your device.")
                }
                .padding(16)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Computed Stats

    private var nonSilentEntries: [TranscriptionEntry] {
        store.entries.filter { !$0.isSilent && !$0.text.isEmpty }
    }

    private var dictationCount: Int {
        nonSilentEntries.count
    }

    private var totalWords: Int {
        nonSilentEntries.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }

    private var formattedWordCount: String {
        if totalWords >= 1000 {
            let k = Double(totalWords) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(totalWords)"
    }

    private var avgWords: String {
        guard dictationCount > 0 else { return "—" }
        let avg = Double(totalWords) / Double(dictationCount)
        return String(format: "%.0f words", avg)
    }
}

// MARK: - Home Subviews

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct HowToStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.primary.opacity(0.7)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - History View

struct HistoryView: View {
    @ObservedObject var store: TranscriptionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("History")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                StatBadge(label: "Entries", value: store.entries.count)
                StatBadge(label: "Words", value: totalWords)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            if store.entries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No transcriptions yet")
                        .foregroundStyle(.secondary)
                    Text("Hold Option (\u{2325}) to dictate")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedEntries, id: \.key) { dateLabel, entries in
                            Section {
                                ForEach(entries) { entry in
                                    HistoryRowView(entry: entry)
                                    Divider().padding(.leading, 20)
                                }
                            } header: {
                                Text(dateLabel)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.background)
                            }
                        }
                    }
                }
            }
        }
    }

    private var totalWords: Int {
        store.entries.reduce(0) { count, entry in
            count + entry.text.split(separator: " ").count
        }
    }

    private var groupedEntries: [(key: String, value: [TranscriptionEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.entries) { entry -> String in
            if calendar.isDateInToday(entry.timestamp) {
                return "Today"
            } else if calendar.isDateInYesterday(entry.timestamp) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: entry.timestamp)
            }
        }
        // Maintain newest-first ordering (entries are already sorted newest-first)
        let order = store.entries.map { entry -> String in
            if calendar.isDateInToday(entry.timestamp) {
                return "Today"
            } else if calendar.isDateInYesterday(entry.timestamp) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: entry.timestamp)
            }
        }
        // Unique ordered keys
        var seen = Set<String>()
        let orderedKeys = order.filter { seen.insert($0).inserted }

        return orderedKeys.compactMap { key in
            guard let values = grouped[key] else { return nil }
            return (key: key, value: values)
        }
    }
}

// MARK: - History Row

struct HistoryRowView: View {
    let entry: TranscriptionEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(timeString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 52, alignment: .leading)

            if entry.isSilent {
                Text("Audio is silent")
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(entry.text)
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: entry.timestamp)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .fontWeight(.medium)
            Text(label)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }
}
