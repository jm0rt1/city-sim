import SwiftUI

/// Immediate site facts above the compact diagnosis; uses the same upkeep attribution as Operations.
struct CityCompactBlockFactsView: View {
    let tile: CityTile
    let upkeep: CityBlockUpkeepPresentation
    let hasRoadAccess: Bool

    var status: String {
        tile.constructionProgress < 1
            ? "Building \((tile.constructionProgress * 100).percentText)"
            : "Operational"
    }

    var roadStatus: String {
        tile.kind.requiresRoad ? (hasRoadAccess ? "Connected" : "Missing") : "Not required"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            fact("Level \(tile.level)", value: status)
            fact("Condition", value: (tile.condition * 100).percentText)
            fact("Road", value: roadStatus)
            fact(upkeep.label, value: upkeep.value)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(upkeep.accessibilitySummary)
                .help(upkeep.explanation)
        }
        .padding(8)
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected block operating facts")
        .accessibilityIdentifier("hud.selection.operating-facts")
    }

    private func fact(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
