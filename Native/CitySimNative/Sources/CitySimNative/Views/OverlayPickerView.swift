import SwiftUI

struct OverlayPickerView: View {
    @ObservedObject var store: CityGameStore
    var compact = false

    var body: some View {
        Menu {
            ForEach(DataOverlay.allCases) { overlay in
                Button { store.perform(CityCommandCatalog.id(for: overlay)) } label: {
                    Label(
                        overlay.title,
                        systemImage: store.overlay == overlay ? "checkmark.circle.fill" : overlay.symbol
                    )
                }
            }
        } label: {
            Label(compact ? store.overlay.title : "Layer: \(store.overlay.title)", systemImage: store.overlay.symbol)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .frame(minHeight: GameTheme.controlMinimum)
        }
        .menuStyle(.borderlessButton)
        .background(GameTheme.inactiveControl, in: RoundedRectangle(cornerRadius: 9))
        .help("Choose a city data layer. Select City to clear diagnostics.")
        .accessibilityLabel("Choose city data layer")
        .accessibilityValue(store.overlay.title)
    }
}
