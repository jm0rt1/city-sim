import Foundation

enum CityObjectiveTrend: String, Equatable, Sendable {
    case baseline
    case improving
    case steady
    case slipping
    case complete

    var title: String {
        switch self {
        case .baseline: "Tracking"
        case .improving: "Improving"
        case .steady: "Holding"
        case .slipping: "Slipping"
        case .complete: "Complete"
        }
    }

    var symbol: String {
        switch self {
        case .baseline: "scope"
        case .improving: "arrow.up.right"
        case .steady: "arrow.right"
        case .slipping: "arrow.down.right"
        case .complete: "checkmark"
        }
    }
}

struct CityObjectivePresentation: Identifiable, Equatable, Sendable {
    let objective: CityObjective
    let currentValue: String
    let targetValue: String
    let trend: CityObjectiveTrend
    let persistence: String
    let deadline: String
    let reward: String
    let passRule: String
    let failRule: String
    let diagnosticLabel: String

    var id: String { objective.id }
    var completed: Bool { objective.completed }

    var accessibilitySummary: String {
        "\(objective.title). Current: \(currentValue). Target: \(targetValue). Trend: \(trend.title). "
            + "Persistence: \(persistence). Deadline: \(deadline). Reward: \(reward). "
            + "Pass: \(passRule). Failure: \(failRule)."
    }

    static func make(
        objective: CityObjective,
        analytics: CityAnalytics,
        previousProgress: Double?
    ) -> Self {
        let trend = trend(
            progress: objective.progress,
            completed: objective.completed,
            previousProgress: previousProgress
        )
        let state = analytics.state

        switch objective.id {
        case "stabilize":
            return Self(
                objective: objective,
                currentValue: "\(analytics.projectedBalance.signedCurrencyText) / cycle",
                targetValue: "$0 or better",
                trend: trend,
                persistence: "Maintain while Charter standards are reviewed",
                deadline: "No fixed deadline",
                reward: "Self-funding operations and Charter eligibility",
                passRule: "Projected operating balance is non-negative.",
                failRule: "A prolonged negative treasury ends the city.",
                diagnosticLabel: "Open City Finances"
            )
        case "capacity":
            return Self(
                objective: objective,
                currentValue: "J \(analytics.jobCapacity) · P \(state.powerCapacity) · W \(state.waterCapacity)",
                targetValue: "J 350 · P 410 · W 370",
                trend: trend,
                persistence: "Keep all three capacities available as the city grows",
                deadline: "No fixed deadline",
                reward: "Capacity for 500 residents and Charter eligibility",
                passRule: "Jobs reach 350, power 410, and water 370 together.",
                failRule: "Any shortfall leaves growth capacity incomplete.",
                diagnosticLabel: "Open Utilities"
            )
        case "town-charter" where objective.completed:
            return Self(
                objective: objective,
                currentValue: "Secured",
                targetValue: "Complete",
                trend: .complete,
                persistence: "Permanent achievement",
                deadline: "Completed",
                reward: "Regional Capital mandate unlocked",
                passRule: "Town Charter standards were sustained for 12 qualifying days.",
                failRule: "The awarded Charter cannot be lost.",
                diagnosticLabel: "Review Charter Record"
            )
        case "town-charter":
            let cycles = analytics.townCharterQualifyingCycles
            return Self(
                objective: objective,
                currentValue: "\(state.population) residents · \(cycles)/12 days",
                targetValue: "500 residents · 12/12 days",
                trend: trend,
                persistence: "\(cycles) of 12 consecutive qualifying days",
                deadline: "No fixed deadline",
                reward: "Permanent Town Charter and a Regional Capital mandate",
                passRule: "Hold 500 population, $10K treasury, balanced operations, 90% employment, full utilities with 15% reserve, 52 happiness, and a 2R/1C/1I mix for 12 days.",
                failRule: "Qualification resets when any standard breaks; an awarded Charter is permanent.",
                diagnosticLabel: "Diagnose Charter"
            )
        case "strategy":
            let phase = analytics.strategyPhase
            let days = analytics.strategyDaysUntilConsequence
            return Self(
                objective: objective,
                currentValue: strategyPhaseTitle(phase),
                targetValue: "Recovery complete",
                trend: trend,
                persistence: strategyPersistence(analytics: analytics),
                deadline: days.map { "\($0) days until next consequence" } ?? "No active countdown",
                reward: strategyReward(analytics.committedStrategy),
                passRule: "Complete the active response and keep the city stable through its resolution.",
                failRule: "Missing the response applies the stated treasury and happiness setback; recovery remains available.",
                diagnosticLabel: "Open Strategy Response"
            )
        case "regional-capital":
            let cycles = analytics.regionalCapitalQualifyingCycles
            let phase = analytics.secondActPhase
            return Self(
                objective: objective,
                currentValue: "\(secondActPhaseTitle(phase)) · \(cycles)/12 days",
                targetValue: "Regional Capital · 12/12 days",
                trend: trend,
                persistence: phase == .qualification
                    ? "\(cycles) of 12 consecutive qualifying days"
                    : "Complete recovery to begin the 12-day review",
                deadline: analytics.secondActDaysUntilConsequence.map {
                    "\($0) days until next consequence"
                } ?? "No active countdown",
                reward: "Permanent Regional Capital recognition",
                passRule: regionalPassRule(strategy: analytics.committedStrategy),
                failRule: "Qualification resets when a standard breaks; earned recognition is permanent.",
                diagnosticLabel: "Diagnose Regional Mandate"
            )
        default:
            return Self(
                objective: objective,
                currentValue: "\((objective.progress * 100).percentText)",
                targetValue: "100%",
                trend: trend,
                persistence: "Maintain progress until completion",
                deadline: "No fixed deadline",
                reward: "Mandate completion",
                passRule: objective.detail,
                failRule: objective.remaining,
                diagnosticLabel: "Review Objective"
            )
        }
    }

    private static func trend(
        progress: Double,
        completed: Bool,
        previousProgress: Double?
    ) -> CityObjectiveTrend {
        if completed { return .complete }
        guard let previousProgress else { return .baseline }
        if progress > previousProgress + 0.0001 { return .improving }
        if progress < previousProgress - 0.0001 { return .slipping }
        return .steady
    }

    private static func strategyPhaseTitle(_ phase: CityStrategyPhase?) -> String {
        switch phase {
        case .opportunity: "Opportunity"
        case .complication: "Complication"
        case .setback: "Setback"
        case .recovery: "Recovery"
        case .completed: "Complete"
        case nil: "Awaiting commitment"
        }
    }

    private static func secondActPhaseTitle(_ phase: CitySecondActPhase?) -> String {
        switch phase {
        case .mandate: "Mandate"
        case .warnedPressure: "Pressure warning"
        case .recovery: "Recovery"
        case .qualification: "Qualification"
        case .completed: "Complete"
        case nil: "Awaiting mandate"
        }
    }

    private static func strategyPersistence(analytics: CityAnalytics) -> String {
        if analytics.strategyPhase == .recovery, analytics.strategyRecoveryResolution == nil {
            return "Choose and complete a recovery response before time expires"
        }
        return "Keep the city stable until the next strategy phase resolves"
    }

    private static func strategyReward(_ strategy: CityStrategy?) -> String {
        strategy == .industrialExpansion
            ? "Freight recovery payoff and Regional Capital eligibility"
            : "Main Street recovery payoff and Regional Capital eligibility"
    }

    private static func regionalPassRule(strategy: CityStrategy?) -> String {
        let route = strategy == .industrialExpansion
            ? "$15K treasury, 44 happiness, 20% utility reserve, and 3 industrial zones"
            : "$12K treasury, 56 happiness, 18% utility reserve, and 3 commercial zones"
        return "After strategy recovery, hold 525 population, balanced operations, 92% employment, full utilities, \(route) for 12 days."
    }
}
