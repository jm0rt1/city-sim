import Foundation

enum CityRoadMaintenancePolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case deferred
    case routine
    case preventive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deferred: "Deferred"
        case .routine: "Routine"
        case .preventive: "Preventive"
        }
    }

    var fundingMultiplier: Double {
        switch self {
        case .deferred: 0.55
        case .routine: 1
        case .preventive: 1.50
        }
    }

    var wearMultiplier: Double {
        switch self {
        case .deferred: 1.45
        case .routine: 1
        case .preventive: 0.50
        }
    }

    var consequence: String {
        switch self {
        case .deferred:
            "Lower upkeep now; busy roads wear 45% faster."
        case .routine:
            "Current upkeep and road wear."
        case .preventive:
            "Higher upkeep; busy roads wear 50% slower."
        }
    }

    var wearSummary: String {
        switch self {
        case .deferred: "+45% wear"
        case .routine: "baseline"
        case .preventive: "−50% wear"
        }
    }
}

enum CityRoadConditionBand: String, Equatable, Sendable {
    case maintained
    case worn
    case damaged

    init(condition: Double) {
        switch CityRoadMaintenance.clamp(condition) {
        case CityRoadMaintenance.maintainedConditionThreshold...:
            self = .maintained
        case CityRoadMaintenance.damagedConditionThreshold...:
            self = .worn
        default:
            self = .damaged
        }
    }

    var title: String {
        switch self {
        case .maintained: "Maintained"
        case .worn: "Worn"
        case .damaged: "Damaged"
        }
    }
}

enum CityRoadRepairRejection: Error, Equatable, Sendable {
    case notRoad
    case alreadyMaintained
    case insufficientFunds(required: Double, available: Double)

    var message: String {
        switch self {
        case .notRoad:
            "Only roads can be resurfaced."
        case .alreadyMaintained:
            "This road is already fully maintained."
        case .insufficientFunds(let required, let available):
            "Road repair needs \(required.currencyText); only \(available.currencyText) is available."
        }
    }
}

enum CityRoadMaintenance {
    static let maintainedConditionThreshold = 0.86
    static let damagedConditionThreshold = 0.55
    static let minimumWearPressure = 0.25

    static func conditionBand(_ condition: Double) -> CityRoadConditionBand {
        CityRoadConditionBand(condition: condition)
    }

    static func capacityFactor(for condition: Double) -> Double {
        0.60 + clamp(condition) * 0.40
    }

    static func dailyWear(
        for pressure: Double,
        policy: CityRoadMaintenancePolicy = .routine
    ) -> Double {
        let pressure = clamp(pressure)
        guard pressure >= minimumWearPressure else { return 0 }
        return (0.002 + pressure * pressure * 0.016) * policy.wearMultiplier
    }

    static func repairCost(for condition: Double) -> Double {
        let missingCondition = max(0, 1 - clamp(condition))
        guard missingCondition > 0.000_001 else { return 0 }
        return max(20, ceil(missingCondition * 130 / 10) * 10)
    }

    static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

struct CityRoadMaintenancePresentation: Equatable, Sendable {
    let conditionPercent: Int
    let band: CityRoadConditionBand
    let repairCost: Double
    let spendingWaived: Bool
    let canAfford: Bool

    var needsRepair: Bool { repairCost > 0 }

    var statusDetail: String {
        switch band {
        case .maintained:
            "Strong road capacity and reliability. Traffic gradually wears busy streets."
        case .worn:
            "Reduced capacity is increasing modeled delay and lowering commute reliability."
        case .damaged:
            "Severely reduced capacity is increasing congestion and weakening connected commutes."
        }
    }

    var repairTitle: String {
        spendingWaived ? "Repair road · Waived" : "Repair road · \(repairCost.currencyText)"
    }

    var accessibilitySummary: String {
        let repair = needsRepair
            ? (spendingWaived
                ? "Repair spending is waived."
                : "Repair costs \(repairCost.currencyText).")
            : "No repair is needed."
        return "Road condition \(conditionPercent) percent, \(band.title.lowercased()). "
            + "\(statusDetail) \(repair)"
    }

    static func make(tile: CityTile, state: CityGameState) -> CityRoadMaintenancePresentation? {
        guard tile.kind == .road else { return nil }
        let condition = CityRoadMaintenance.clamp(tile.condition)
        let repairCost = CityRoadMaintenance.repairCost(for: condition)
        return CityRoadMaintenancePresentation(
            conditionPercent: Int((condition * 100).rounded()),
            band: CityRoadMaintenance.conditionBand(condition),
            repairCost: repairCost,
            spendingWaived: state.usesUnlimitedFunds,
            canAfford: state.usesUnlimitedFunds || state.treasury >= repairCost
        )
    }
}
