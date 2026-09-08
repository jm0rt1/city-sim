import SwiftUI

/// A reading selection, not a new piece of saved city state. Group identity
/// keeps a notice selected when another occurrence updates its date or count.
struct CityNoticeJournalSelection {
    static func index(for id: String?, in summaries: [CityMessageSummary]) -> Int? {
        guard !summaries.isEmpty else { return nil }
        return summaries.firstIndex { $0.id == id } ?? 0
    }

    static func afterDismissal(at index: Int, in summaries: [CityMessageSummary]) -> String? {
        guard summaries.count > 1 else { return nil }
        return summaries[index + 1 < summaries.count ? index + 1 : index - 1].id
    }
}

struct CityNoticeJournalView: View {
    @ObservedObject var store: CityGameStore
    let compact: Bool
    @State private var selectedID: String?

    var body: some View {
        let summaries = store.messageSummaries
        Group {
            if let index = CityNoticeJournalSelection.index(for: selectedID, in: summaries) {
                reader(summaries[index], index: index, summaries: summaries)
            } else {
                Label("All clear · There are no active city notices.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(GameTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(height: compact ? 132 : 148)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("City notice journal")
        .onAppear { selectedID = summaries.first?.id }
        .onChange(of: store.state.seed) { _, _ in selectedID = nil }
        .onChange(of: summaries.map(\.id)) { _, ids in
            if !ids.contains(where: { $0 == selectedID }) { selectedID = ids.first }
        }
    }

    private func reader(_ summary: CityMessageSummary, index: Int, summaries: [CityMessageSummary]) -> some View {
        let message = summary.message
        let actions = CityNoticeActionCatalog.actions(for: message.title, analytics: store.analytics)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Label(message.title, systemImage: message.severity.symbol)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(message.severity.tint)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("Day \(message.tick / 4 + 1)" + (summary.count > 1 ? " · ×\(summary.count)" : ""))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .accessibilityLabel("Day \(message.tick / 4 + 1), \(summary.count) \(summary.count == 1 ? "notice" : "occurrences")")
            }
            ScrollView(.vertical) {
                Text(message.detail)
                    .font(.system(size: GameTheme.hudSupportTextSize, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 10)
                    .textSelection(.enabled)
            }
            .scrollIndicators(.visible)
            .id(summary.id)
            .accessibilityLabel("Full notice text")
            .accessibilityHint("Scroll to read longer notices. Notice actions remain below the text.")

            HStack(spacing: 8) {
                Button { selectedID = summaries[index - 1].id } label: {
                    Image(systemName: "chevron.left")
                        .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
                }
                .disabled(index == 0)
                .accessibilityLabel("Previous city notice")
                Menu("\(index + 1) of \(summaries.count)") {
                    ForEach(summaries) { item in
                        Button("\(item.message.title) · Day \(item.message.tick / 4 + 1)") { selectedID = item.id }
                    }
                }
                .fixedSize()
                .accessibilityLabel("Choose city notice")
                .accessibilityValue("\(index + 1) of \(summaries.count), \(message.title)")
                Button { selectedID = summaries[index + 1].id } label: {
                    Image(systemName: "chevron.right")
                        .frame(minWidth: GameTheme.controlMinimum, minHeight: GameTheme.controlMinimum)
                }
                .disabled(index == summaries.count - 1)
                .accessibilityLabel("Next city notice")
                Spacer(minLength: 4)
                Button("Related data") { store.openMessage(message) }
                    .frame(minHeight: GameTheme.controlMinimum)
                if !actions.isEmpty {
                    Menu("Actions") {
                        ForEach(actions) { response in
                            Button(response.title) { StrategyCommandCenterView.perform(response, on: store) }
                                .accessibilityHint(response.explanation + (response.focusesMap ? " Focus returns to the map." : ""))
                        }
                    }
                    .fixedSize()
                    .frame(minHeight: GameTheme.controlMinimum)
                    .accessibilityLabel("Act on \(message.title)")
                }
                Button("Dismiss") {
                    selectedID = CityNoticeJournalSelection.afterDismissal(at: index, in: summaries)
                    store.dismissMessageSummary(summary)
                }
                .frame(minHeight: GameTheme.controlMinimum)
                .accessibilityLabel("Dismiss \(message.title) notices")
            }
            .buttonStyle(.borderless)
            .font(.caption.weight(.semibold))
        }
    }
}

private extension MessageSeverity {
    var symbol: String {
        switch self {
        case .good: "sparkles"
        case .information: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .good: GameTheme.accent
        case .information: GameTheme.information
        case .warning: GameTheme.warning
        case .critical: GameTheme.danger
        }
    }
}
