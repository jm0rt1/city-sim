import Foundation

/// A deterministic capacity check for the next 100 residents at the city's
/// current developed footprint. Utility support preserves the same 15%
/// reserve used by Charter qualification and storm recovery.
struct CityGrowthCapacityPresentation: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case currentShortfall
        case prepare
        case ready
    }

    enum Constraint: String, CaseIterable, Equatable, Sendable {
        case housing
        case jobs
        case power
        case water

        var title: String {
            switch self {
            case .housing: "Housing"
            case .jobs: "Job capacity"
            case .power: "Power"
            case .water: "Water"
            }
        }

        var symbol: String {
            switch self {
            case .housing: BuildingKind.residential.symbol
            case .jobs: "briefcase.fill"
            case .power: BuildingKind.powerPlant.symbol
            case .water: BuildingKind.waterTower.symbol
            }
        }
    }

    let phase: Phase
    let constraint: Constraint?
    let targetPopulation: Int
    let supportedPopulation: Int
    let headroom: Int
    let status: String
    let title: String
    let detail: String
    let response: CityDirectResponse

    var accessibilitySummary: String {
        "Growth capacity forecast. \(status). \(title). \(detail) Next action: \(response.title)."
    }

    var decisionTitle: String {
        switch phase {
        case .currentShortfall: "\(constraint?.title ?? "Capacity") short now"
        case .prepare: "\(constraint?.title ?? "Capacity") limits +100"
        case .ready: "Ready for +100"
        }
    }

    static func make(analytics: CityAnalytics) -> Self {
        let state = analytics.state
        let target = state.population + 100
        let candidates = candidates(analytics: analytics, targetPopulation: target)
        let limiting = candidates.min {
            if $0.supportedPopulation != $1.supportedPopulation {
                return $0.supportedPopulation < $1.supportedPopulation
            }
            return $0.priority < $1.priority
        }!
        let supported = max(0, limiting.supportedPopulation)
        let headroom = max(0, supported - state.population)

        guard limiting.supportedPopulation < target else {
            return Self(
                phase: .ready,
                constraint: nil,
                targetPopulation: target,
                supportedPopulation: supported,
                headroom: max(100, headroom),
                status: "READY",
                title: "Capacity supports the next 100 residents",
                detail: "At the current footprint, housing, jobs, power, and water support at least \(target.formatted()) residents while utilities retain 15% reserve.",
                response: .init(
                    title: "Review demand",
                    command: .inspectorDemand,
                    explanation: "Capacity is ready; review demand before committing the next growth project.",
                    focusesMap: false
                )
            )
        }

        let currentShortfall = limiting.supportedPopulation < state.population
        let phase: Phase = currentShortfall ? .currentShortfall : .prepare
        let status = currentShortfall ? "CURRENT SHORTFALL" : "PREPARE"
        let title = currentShortfall
            ? "\(limiting.constraint.title) is below current need"
            : "\(limiting.constraint.title) is the next growth bottleneck"
        let supportText = currentShortfall
            ? "supports only about \(supported.formatted()) residents"
            : "supports about \(supported.formatted()) residents, \(headroom.formatted()) above today"

        return Self(
            phase: phase,
            constraint: limiting.constraint,
            targetPopulation: target,
            supportedPopulation: supported,
            headroom: headroom,
            status: status,
            title: title,
            detail: "At the current footprint and 15% utility reserve, \(limiting.constraint.title.lowercased()) \(supportText). Reaching \(target.formatted()) needs \(limiting.gap.formatted()) more \(limiting.gapUnit).",
            response: limiting.response
        )
    }

    private struct Candidate {
        let constraint: Constraint
        let supportedPopulation: Int
        let gap: Int
        let gapUnit: String
        let response: CityDirectResponse
        let priority: Int
    }

    private static func candidates(
        analytics: CityAnalytics,
        targetPopulation: Int
    ) -> [Candidate] {
        let state = analytics.state
        let utilityReserve = 1 - CitySimulation.stormRecoveryRequiredUtilityReserve
        let nonPopulationPower = state.powerUsed - Int(Double(state.population) * 0.82)
        let nonPopulationWater = state.waterUsed - Int(Double(state.population) * 0.74)
        let powerSupport = supportedPopulation(
            capacity: state.powerCapacity,
            nonPopulationUse: nonPopulationPower,
            populationUse: 0.82,
            reserve: utilityReserve
        )
        let waterSupport = supportedPopulation(
            capacity: state.waterCapacity,
            nonPopulationUse: nonPopulationWater,
            populationUse: 0.74,
            reserve: utilityReserve
        )
        let targetPowerUse = Int(Double(targetPopulation) * 0.82) + nonPopulationPower
        let targetWaterUse = Int(Double(targetPopulation) * 0.74) + nonPopulationWater
        let requiredPowerCapacity = Int(ceil(Double(targetPowerUse) / utilityReserve))
        let requiredWaterCapacity = Int(ceil(Double(targetWaterUse) / utilityReserve))
        let requiredJobCapacity = Int(ceil(Double(targetPopulation) / 2))
        let powerReserve = currentReserve(capacity: state.powerCapacity, used: state.powerUsed)
        let waterReserve = currentReserve(capacity: state.waterCapacity, used: state.waterUsed)
        let powerPriority = powerReserve < waterReserve ? 2 : 3
        let waterPriority = waterReserve <= powerReserve ? 2 : 3
        let preferredJobsKind: BuildingKind = switch analytics.committedStrategy {
        case .commercialStewardship: .commercial
        case .industrialExpansion: .industrial
        case nil: state.demand.commercial >= state.demand.industrial ? .commercial : .industrial
        }

        return [
            Candidate(
                constraint: .housing,
                supportedPopulation: analytics.housingCapacity,
                gap: max(0, targetPopulation - analytics.housingCapacity),
                gapUnit: "housing capacity",
                response: .init(
                    title: "Build homes",
                    command: .buildResidential,
                    explanation: "Add residential capacity before the current neighborhoods cap population growth.",
                    focusesMap: true
                ),
                priority: 0
            ),
            Candidate(
                constraint: .jobs,
                supportedPopulation: max(120, analytics.jobCapacity * 2),
                gap: max(0, requiredJobCapacity - analytics.jobCapacity),
                gapUnit: "jobs",
                response: .init(
                    title: "Build \(preferredJobsKind.title.lowercased())",
                    command: CityCommandCatalog.id(for: preferredJobsKind),
                    explanation: "Add job capacity on the stronger demand route before employment limits growth.",
                    focusesMap: true
                ),
                priority: 1
            ),
            Candidate(
                constraint: .power,
                supportedPopulation: powerSupport,
                gap: max(0, requiredPowerCapacity - state.powerCapacity),
                gapUnit: "power capacity",
                response: .init(
                    title: "Build Power Plant",
                    command: .buildPowerPlant,
                    explanation: "Add power capacity so projected growth retains the 15% resilience reserve.",
                    focusesMap: true
                ),
                priority: powerPriority
            ),
            Candidate(
                constraint: .water,
                supportedPopulation: waterSupport,
                gap: max(0, requiredWaterCapacity - state.waterCapacity),
                gapUnit: "water capacity",
                response: .init(
                    title: "Build Water Tower",
                    command: .buildWaterTower,
                    explanation: "Add water capacity so projected growth retains the 15% resilience reserve.",
                    focusesMap: true
                ),
                priority: waterPriority
            ),
        ]
    }

    /// Mirrors the simulation's integer-truncated population consumption:
    /// `Int(Double(population) * rate) + nonPopulationUse`.
    private static func supportedPopulation(
        capacity: Int,
        nonPopulationUse: Int,
        populationUse: Double,
        reserve: Double
    ) -> Int {
        let maximumUse = Int(floor(Double(capacity) * reserve))
        let availablePopulationUse = maximumUse - nonPopulationUse
        guard availablePopulationUse >= 0 else { return 0 }
        return max(0, Int(ceil(Double(availablePopulationUse + 1) / populationUse)) - 1)
    }

    private static func currentReserve(capacity: Int, used: Int) -> Double {
        guard capacity > 0 else { return used > 0 ? -.infinity : 0 }
        return Double(capacity - used) / Double(capacity)
    }
}
