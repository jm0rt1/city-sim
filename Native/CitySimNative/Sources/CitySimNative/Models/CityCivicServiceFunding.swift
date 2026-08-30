import Foundation

enum CityCivicServiceFundingPolicy: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case reduced
    case standard
    case expanded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reduced: "Reduced"
        case .standard: "Standard"
        case .expanded: "Expanded"
        }
    }

    var fundingMultiplier: Double {
        switch self {
        case .reduced: 0.65
        case .standard: 1
        case .expanded: 1.40
        }
    }

    var maximumRoadDistance: Int {
        switch self {
        case .reduced: 8
        case .standard: 12
        case .expanded: 16
        }
    }

    var stormProtectionMultiplier: Double {
        switch self {
        case .reduced: 0.75
        case .standard: 1
        case .expanded: 1.25
        }
    }

    var stormReadinessSummary: String {
        switch self {
        case .reduced: "storms weaker"
        case .standard: "storms baseline"
        case .expanded: "storms stronger"
        }
    }

    var consequence: String {
        switch self {
        case .reduced:
            "Lower upkeep; service reach contracts to 8 road blocks and storm readiness falls."
        case .standard:
            "Current upkeep, 12-block fire, police, and school reach, and baseline storm readiness."
        case .expanded:
            "Higher upkeep; service reach expands to 16 road blocks and storm readiness improves."
        }
    }
}
