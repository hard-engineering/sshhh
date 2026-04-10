import SwiftUI

// MARK: - Root View

struct MainContentView: View {
    @ObservedObject var store: TranscriptionStore
    @ObservedObject var dictionaryStore: DictionaryStore
    @State private var selection: SidebarItem? = .home

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .home, .none:
                HistoryView(store: store)
            case .dictionary:
                DictionaryView(store: dictionaryStore)
            }
        }
    }
}

// MARK: - Sidebar

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case dictionary = "Dictionary"

    var id: Self { self }

    var icon: String {
        switch self {
        case .home: return "house"
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
        .navigationSplitViewColumnWidth(min: 160, ideal: 180)
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
