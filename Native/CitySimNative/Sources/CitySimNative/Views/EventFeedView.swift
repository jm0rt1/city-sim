import SwiftUI

struct EventFeedView: View {
    @ObservedObject var store: CityGameStore

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(store.state.messages.prefix(3)) { message in
                HStack(alignment: .top, spacing: 9) {
                    Button { store.openMessage(message) } label: {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: symbol(message.severity))
                                .foregroundStyle(color(message.severity))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(message.title).font(.system(size: 12, weight: .semibold))
                                Text(message.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    Button { store.dismissMessage(message.id) } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Dismiss")
                }
                .padding(10)
                .frame(width: 280, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(color(message.severity).opacity(0.25)))
                .help("Open the related city information")
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
