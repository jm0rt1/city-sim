import SwiftUI

struct EventFeedView: View {
    @ObservedObject var store: CityGameStore
    var compact = false
    @State private var visibleSummaryID: String?

    var body: some View {
        Group {
            if let summary = store.messageSummaries.first, visibleSummaryID == summary.id {
                HStack(alignment: .top, spacing: 9) {
                Button { store.openMessage(summary.message) } label: {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: symbol(summary.message.severity))
                            .foregroundStyle(color(summary.message.severity))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(summary.message.title).font(.system(size: 12, weight: .semibold))
                                if summary.count > 1 {
                                    Text("×\(summary.count)")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(.primary.opacity(0.1), in: Capsule())
                                }
                                Text("Day \(summary.message.tick / 4 + 1)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                            Text(summary.message.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                            if store.messageSummaries.count > 1 {
                                Text("\(store.messageSummaries.count - 1) more in City Journal")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(summary.message.title)")
                .accessibilityValue(summary.count > 1 ? "\(summary.count) similar events" : summary.message.detail)
                Button { store.dismissMessageSummary(summary) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(width: GameTheme.controlMinimum, height: GameTheme.controlMinimum)
                    .contentShape(Rectangle())
                    .help("Dismiss \(summary.message.title) notifications")
                    .accessibilityLabel("Dismiss \(summary.message.title) notifications")
            }
            .padding(10)
            .frame(width: compact ? 260 : 292, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(color(summary.message.severity).opacity(0.55), lineWidth: 1.5))
                .help("Open the related city information")
            }
        }
        .task(id: store.messageSummaries.first?.presentationID) {
            guard let summary = store.messageSummaries.first else {
                visibleSummaryID = nil
                return
            }
            let summaryID = summary.id
            visibleSummaryID = summaryID
            do {
                try await Task.sleep(nanoseconds: 6_000_000_000)
            } catch {
                return
            }
            if visibleSummaryID == summaryID {
                visibleSummaryID = nil
            }
        }
    }

    private func symbol(_ severity: MessageSeverity) -> String {
        switch severity { case .good: "sparkles"; case .information: "info.circle.fill"; case .warning: "exclamationmark.triangle.fill"; case .critical: "xmark.octagon.fill" }
    }
    private func color(_ severity: MessageSeverity) -> Color {
        switch severity { case .good: GameTheme.accent; case .information: .cyan; case .warning: GameTheme.warning; case .critical: GameTheme.danger }
    }
}
