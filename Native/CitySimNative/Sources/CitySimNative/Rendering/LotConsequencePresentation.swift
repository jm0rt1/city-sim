import Foundation

enum LotConstructionStage: Int, CaseIterable, Sendable {
    case site
    case foundation
    case structure
    case finishing
    case complete

    init(progress rawProgress: Double) {
        let progress = min(1, max(0, rawProgress))
        switch progress {
        case 1...:
            self = .complete
        case 0.75...:
            self = .finishing
        case 0.50...:
            self = .structure
        case 0.25...:
            self = .foundation
        default:
            self = .site
        }
    }

    var label: String {
        switch self {
        case .site: "SITE"
        case .foundation: "FOUNDATION"
        case .structure: "FRAME"
        case .finishing: "FINISHING"
        case .complete: "COMPLETE"
        }
    }
}

enum LotConditionPresentation: Int, CaseIterable, Sendable {
    case maintained
    case weathered
    case distressed

    init(condition rawCondition: Double) {
        let condition = min(1, max(0, rawCondition))
        switch condition {
        case 0.75...:
            self = .maintained
        case 0.40...:
            self = .weathered
        default:
            self = .distressed
        }
    }
}

/// A renderer-only interpretation of authoritative `CityTile` fields.
///
/// Thresholds select visual treatments; they do not feed back into simulation,
/// assign economic meaning, or infer utility/environment state that is absent
/// from the model.
struct LotConsequencePresentation: Equatable, Sendable {
    let construction: LotConstructionStage
    let condition: LotConditionPresentation
    let growthTier: Int

    init(tile: CityTile) {
        construction = LotConstructionStage(progress: tile.constructionProgress)
        condition = LotConditionPresentation(condition: tile.condition)
        growthTier = max(1, tile.level)
    }
}
