import SwiftUI

struct OverlayPickerView: View {
    @ObservedObject var store: CityGameStore

    var body: some View {
        HStack(spacing: 5) {
            ForEach(DataOverlay.allCases) { overlay in
                Button {
                    store.overlay = overlay
                } label: {
                    Image(systemName: overlay.symbol).frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(store.overlay == overlay ? Color.black : Color.primary)
                .background(store.overlay == overlay ? GameTheme.accent : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .help(overlay.title)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
