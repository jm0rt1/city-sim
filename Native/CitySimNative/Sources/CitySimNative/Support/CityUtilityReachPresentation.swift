import Foundation

/// Local service is distinct from the citywide capacity budget. Summarize the
/// existing spatial bands; this presentation never changes service or city state.
struct CityUtilityReachPresentation: Equatable, Sendable {
    struct Network: Equatable, Sendable {
        let overlay: DataOverlay
        let totalBlocks: Int
        let weakBlocks: Int
        let severeBlocks: Int
        let weakestCoordinate: GridCoordinate?
        let weakestValue: Double?

        var countText: String { totalBlocks == 0 ? "None yet" : "\(weakBlocks) / \(totalBlocks)" }
        var actionTitle: String { "Find \(overlay.title.lowercased()) gap" }
        var planningTitle: String { "\(overlay.title) reach gap" }
        var planningDetail: String {
            "Spare capacity, but \(weakBlocks) of \(totalBlocks) blocks have weak \(overlay.title.lowercased()) service."
        }
        var accessibilitySummary: String {
            var summary = "\(overlay.title): \(weakBlocks) of \(totalBlocks) completed developed blocks have weak local service; \(severeBlocks) are severe. Weak includes strained and severe service. Roads, open land and unfinished construction are excluded."
            if let coordinate = weakestCoordinate, let value = weakestValue {
                summary += " Lowest service is \(Int((value * 100).rounded())) percent at Block \(coordinate.x + 1), \(coordinate.y + 1)."
            }
            return summary
        }
    }

    let power: Network
    let water: Network

    /// Most severe blocks first, then the total affected count and lowest
    /// reading. Water wins an exact tie so routing remains deterministic.
    var priority: Network? {
        guard power.weakBlocks > 0 || water.weakBlocks > 0 else { return nil }
        if power.severeBlocks != water.severeBlocks {
            return power.severeBlocks > water.severeBlocks ? power : water
        }
        if power.weakBlocks != water.weakBlocks {
            return power.weakBlocks > water.weakBlocks ? power : water
        }
        return (power.weakestValue ?? 1) < (water.weakestValue ?? 1) ? power : water
    }

    func priorityWhenCapacityAvailable(_ capacity: CityUtilityDecisionSupport) -> Network? {
        capacity.status == .healthy ? priority : nil
    }

    func network(for overlay: DataOverlay) -> Network? {
        switch overlay {
        case .power: power
        case .water: water
        default: nil
        }
    }

    init(state: CityGameState) {
        let map = CitySpatialConsequenceMap(state: state)
        let developed = map.samples.filter { sample in
            guard let tile = state.tile(at: sample.coordinate) else { return false }
            return tile.kind != .empty && tile.kind != .road && tile.constructionProgress >= 1
        }
        power = Self.summarize(.power, samples: developed)
        water = Self.summarize(.water, samples: developed)
    }

    private static func summarize(_ overlay: DataOverlay, samples: [CitySpatialConsequence]) -> Network {
        let weak = samples.filter {
            (overlay == .power ? $0.utility.powerBand : $0.utility.waterBand) != .healthy
        }
        let severe = weak.filter {
            (overlay == .power ? $0.utility.powerBand : $0.utility.waterBand) == .severe
        }
        let lowest = weak.min {
            let lhs = overlay == .power ? $0.utility.power : $0.utility.water
            let rhs = overlay == .power ? $1.utility.power : $1.utility.water
            if lhs != rhs { return lhs < rhs }
            if $0.coordinate.y != $1.coordinate.y { return $0.coordinate.y < $1.coordinate.y }
            return $0.coordinate.x < $1.coordinate.x
        }
        return Network(
            overlay: overlay, totalBlocks: samples.count, weakBlocks: weak.count,
            severeBlocks: severe.count, weakestCoordinate: lowest?.coordinate,
            weakestValue: lowest.flatMap { overlay.utilityValue(in: $0.utility) }
        )
    }
}
