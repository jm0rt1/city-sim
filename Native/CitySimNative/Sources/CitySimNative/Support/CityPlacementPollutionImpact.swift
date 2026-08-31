import Foundation

/// Current developed-neighborhood exposure after completion, not a future-growth prediction.
struct CityPlacementPollutionImpact: Equatable, Sendable {
    let affectedBlocks: Int
    let affectedHomes: Int
    let greatestIncrease: Double

    private var increaseText: String {
        let points = greatestIncrease * 100
        return points < 1 ? "under 1 pt" : "\(Int(points.rounded())) pts"
    }

    var summary: String {
        guard affectedBlocks > 0 else { return "Pollution: no existing block worsens" }
        let unit = affectedBlocks == 1 ? "block" : "blocks"
        let maximum = greatestIncrease * 100 < 1 ? "under +1 pt" : "+\(increaseText)"
        return "Pollution: \(affectedBlocks) \(unit) · max \(maximum)"
    }

    var accessibilitySummary: String {
        guard affectedBlocks > 0 else {
            return "No existing completed block gains pollution at this site. Future development may still be exposed."
        }
        let points = greatestIncrease * 100 < 1 ? "less than 1" : "\(Int((greatestIncrease * 100).rounded()))"
        return "On completion, pollution increases at \(affectedBlocks) existing completed blocks, including \(affectedHomes) residential blocks. The largest increase is \(points) percentage points. This compares current development only; the new plant and future growth are not counted."
    }
}
