import SwiftUI

struct BuildToolbarView: View {
    @ObservedObject var store: CityGameStore

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label("BUILD", systemImage: "hammer.fill")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                Divider().frame(height: 28)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(BuildingKind.buildPalette) { kind in
                            toolButton(kind)
                        }
                    }
                }
                Divider().frame(height: 28)
                Button(role: .destructive) { store.toggleBulldozer() } label: {
                    Label(store.bulldozeMode ? "Bulldozing" : "Bulldoze", systemImage: "trash.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(store.bulldozeMode ? GameTheme.danger : .gray)
                .help("Toggle bulldozer, then click structures on the map")
            }
            demandStrip
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
    }

    private func toolButton(_ kind: BuildingKind) -> some View {
        Button {
            store.selectTool(kind)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: kind.symbol).font(.system(size: 16, weight: .semibold))
                Text(kind.title).font(.system(size: 9, weight: .medium)).lineLimit(1)
                Text(kind.buildCost.currencyText).font(.system(size: 8, design: .rounded)).foregroundStyle(.secondary)
            }
            .frame(width: 68, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(store.selectedTool == kind && !store.bulldozeMode ? Color.black : Color.primary)
        .background(store.selectedTool == kind && !store.bulldozeMode ? GameTheme.accent : Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
        .help("Build \(kind.title) · \(kind.buildCost.currencyText) · \(kind.upkeep.currencyText)/tick")
    }

    private var demandStrip: some View {
        HStack(spacing: 14) {
            Text("DEMAND").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
            DemandBar(label: "Residential", value: store.state.demand.residential, color: .cyan) { store.openInspector(.demand) }
            DemandBar(label: "Commercial", value: store.state.demand.commercial, color: .purple) { store.openInspector(.demand) }
            DemandBar(label: "Industrial", value: store.state.demand.industrial, color: .orange) { store.openInspector(.demand) }
            Spacer()
            Label("Click open land to build · Right-click to demolish · Drag to pan · Scroll to zoom", systemImage: "computermouse")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct DemandBar: View {
    let label: String
    let value: Double
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.primary.opacity(0.1))
                        Capsule().fill(color.gradient).frame(width: proxy.size.width * value)
                    }
                }
                .frame(width: 62, height: 5)
            }
        }
        .buttonStyle(.plain)
        .help("Open demand details")
    }
}
