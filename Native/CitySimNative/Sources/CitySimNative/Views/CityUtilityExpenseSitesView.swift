import SwiftUI

struct CityUtilityExpenseSitesView: View {
    let presentation: CityOperatingExpensePresentation
    let compact: Bool
    let onBack: () -> Void
    let onFind: (GridCoordinate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Button(action: onBack) { Label("All expenses", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("finance.utility-sites.back")
                Spacer()
                Text("Utilities · \(presentation.rows.first { $0.category == .utilities }?.amountText ?? "$0.00") / cycle")
                    .fontWeight(.semibold).monospacedDigit()
            }
            .font(.caption)
            Text("Upkeep shares include reserve discounts; not demolition savings.")
                .font(.caption2).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: compact ? 2 : 3), spacing: 4) {
                ForEach(presentation.utilitySites) { site in
                    Button { onFind(site.coordinate) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text(site.kind.title).lineLimit(1)
                                Spacer(minLength: 2)
                                Label("Find", systemImage: "scope").foregroundStyle(GameTheme.accent)
                            }
                            .font(.system(size: 12, weight: .semibold))
                            HStack(spacing: 4) {
                                Text(site.block)
                                Spacer(minLength: 2)
                                Text(site.upkeep.value).monospacedDigit()
                            }
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum, alignment: .leading)
                        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(site.upkeep.explanation)
                    .accessibilityLabel("Find \(site.kind.title) at \(site.block.lowercased())")
                    .accessibilityValue(site.accessibilitySummary)
                    .accessibilityHint("Focuses this facility on its service map. Open Details to review operations and demolition impacts. No spending.")
                    .accessibilityIdentifier("finance.utility-site.\(site.coordinate.x).\(site.coordinate.y)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Utility upkeep by completed facility, largest first. These shares are not demolition savings.")
        .accessibilityIdentifier("finance.utility-sites")
    }

    @MainActor @discardableResult
    static func find(_ coordinate: GridCoordinate, on store: CityGameStore) -> Bool {
        guard !store.isPhotoModeEnabled, store.commandPolicy == .enabled,
              let tile = store.state.tile(at: coordinate), tile.constructionProgress >= 1,
              tile.kind == .powerPlant || tile.kind == .waterTower else { return false }
        let command: CityCommandID = tile.kind == .powerPlant ? .overlayPower : .overlayWater
        guard store.performMapFocused(command) else { return false }
        return store.focusDiagnosticHotspot(coordinate)
    }
}
