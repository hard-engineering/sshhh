import SwiftUI

// MARK: - Dictionary View

struct DictionaryView: View {
    @ObservedObject var store: DictionaryStore
    @State private var showAddSheet = false
    @AppStorage("dictionaryOnboardingDismissed") private var onboardingDismissed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Dictionary")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    showAddSheet = true
                } label: {
                    Label("Add new", systemImage: "plus")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !onboardingDismissed {
                        OnboardingCard {
                            onboardingDismissed = true
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    }

                    if store.entries.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "book")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            Text("No dictionary entries yet")
                                .foregroundStyle(.secondary)
                            Text("Add words to improve recognition accuracy")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(store.entries) { entry in
                                DictionaryRowView(entry: entry, onDelete: { store.deleteEntry(entry) })
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteEntry(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                Divider().padding(.leading, 20)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddDictionaryEntrySheet(store: store)
        }
    }
}

// MARK: - Dictionary Row

struct DictionaryRowView: View {
    let entry: DictionaryEntry
    var onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text(entry.phrase)
                .lineLimit(1)

            if entry.hasReplacement {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            if isHovered {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else if let spoken = entry.spokenForm, entry.hasReplacement {
                Text(spoken)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Onboarding Card

struct OnboardingCard: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Custom vocabulary")
                    .font(.headline)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("Add words and phrases to improve recognition accuracy. Terms with a spoken form also trigger text replacement.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ExampleChip("Q3 Roadmap")
                ExampleChip("Whispr \u{2192} Wispr")
                ExampleChip("SF MOMA")
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ExampleChip: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
    }
}

// MARK: - Add Entry Sheet

struct AddDictionaryEntrySheet: View {
    @ObservedObject var store: DictionaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var phrase = ""
    @State private var spokenForm = ""
    @State private var enableReplacement = false

    private var canAdd: Bool {
        !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add dictionary entry")
                .font(.headline)

            TextField("Word or phrase", text: $phrase)
                .textFieldStyle(.roundedBorder)

            Toggle("Text replacement", isOn: $enableReplacement)

            if enableReplacement {
                TextField("Spoken form (what you say)", text: $spokenForm)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    store.addEntry(
                        phrase: phrase,
                        spokenForm: enableReplacement ? spokenForm : nil
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdd)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
