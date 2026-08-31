import SwiftUI

struct CityDevelopmentUtilityControls: View {
    @ObservedObject var store: CityGameStore
    let presentation: CityDevelopmentUtilityPresentation

    var body: some View {
        HStack(spacing: 4) {
            ForEach(presentation.networks) { network in
                let selected = store.overlay == network.overlay
                Button {
                    store.toggleDevelopmentUtilityOverlay(network.overlay)
                } label: {
                    VStack(spacing: 1) {
                        Label(network.title, systemImage: network.overlay.symbol)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Text(selected ? "Return to city" : network.detail)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .frame(minHeight: GameTheme.controlMinimum)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selected ? Color.black : (network.limitsSite ? GameTheme.warning : .primary))
                .background(selected ? GameTheme.information : GameTheme.inactiveControl,
                            in: RoundedRectangle(cornerRadius: 8))
                .fixedSize(horizontal: true, vertical: true)
                .disabled(!store.canPerform(CityCommandCatalog.id(for: network.overlay)))
                .help(network.accessibilitySummary)
                .accessibilityLabel("\(network.overlay.title) service for proposed development")
                .accessibilityValue(network.accessibilitySummary + (selected ? ". Network layer shown" : ""))
                .accessibilityHint(selected
                    ? "Return to the city view without changing the proposed site or buying anything"
                    : "Show the \(network.overlay.title.lowercased()) network without changing the proposed site or buying anything")
                .accessibilityIdentifier("hud.build.utility.\(network.overlay.rawValue)")
            }
        }
    }
}
