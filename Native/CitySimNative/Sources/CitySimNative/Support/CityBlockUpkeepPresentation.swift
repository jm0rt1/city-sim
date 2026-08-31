import Foundation

/// Read-only site attribution of the operating forecast; never changes simulation or saves.
struct CityBlockUpkeepPresentation: Equatable {
    let amount: Double
    let label: String
    let note: String?
    let explanation: String

    var value: String {
        "\(amount.formatted(.currency(code: "USD").precision(.fractionLength(2)))) / cycle"
    }

    var accessibilitySummary: String {
        "\(label), \(value.replacingOccurrences(of: "/ cycle", with: "per cycle")). \(explanation)"
    }

    static func make(for tile: CityTile, in state: CityGameState) -> Self {
        guard tile.constructionProgress >= 1 else {
            return Self(amount: 0, label: "Upkeep", note: "Starts when operational",
                        explanation: "Construction has no recurring upkeep until this site is operational.")
        }

        var base = tile.kind.upkeep * Double(max(1, tile.level))
        var label = "Upkeep"
        var note: String?
        var explanation = "Current level and city economy, excluding citywide debt interest."
        switch tile.kind {
        case .road:
            base *= state.effectiveRoadMaintenancePolicy.fundingMultiplier
            explanation = "\(state.effectiveRoadMaintenancePolicy.title) road funding. " + explanation
        case .fireStation, .policeStation, .school:
            base *= state.effectiveCivicServiceFundingPolicy.fundingMultiplier
            explanation = "\(state.effectiveCivicServiceFundingPolicy.title) service funding. " + explanation
        case .powerPlant, .waterTower:
            let count = CitySimulation.activeTiles(in: state).filter { $0.kind == tile.kind }.count
            if count > 1 {
                // The model discounts the fleet, not a particular reserve facility.
                // Attribute that discount equally among completed sites of the same kind.
                base -= Double(count - 1) * tile.kind.upkeep
                    * (1 - CitySimulation.reserveUtilityUpkeepFactor) / Double(count)
                label = "Upkeep share"
                note = "Shared reserve discount"
                explanation = "Includes an equal share of the reserve discount across \(count) completed \(tile.kind.title.lowercased()) sites. This is an operating-cost share, not demolition savings. " + explanation
            }
        default:
            break
        }
        return Self(
            amount: base * CitySimulation.upkeepMultiplier * (state.sandboxRules?.economy.upkeepMultiplier ?? 1),
            label: label, note: note, explanation: explanation
        )
    }
}
