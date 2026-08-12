import Foundation

enum CityScenarioMedal: String, Codable, CaseIterable, Equatable, Sendable {
    case bronze
    case silver
    case gold

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .bronze: "medal.fill"
        case .silver: "medal.fill"
        case .gold: "trophy.fill"
        }
    }
}

enum CityAuthoredScenarioResult: String, Codable, Equatable, Sendable {
    case active
    case bronze
    case silver
    case gold
    case failedDeadline
    case failedCityCrisis

    var medal: CityScenarioMedal? {
        switch self {
        case .bronze: .bronze
        case .silver: .silver
        case .gold: .gold
        case .active, .failedDeadline, .failedCityCrisis: nil
        }
    }

    var isComplete: Bool { self != .active }
}

struct CityAuthoredScenarioSession: Codable, Equatable, Sendable {
    let scenarioID: String
    let startedTick: Int
    let deadlineTick: Int
    var result: CityAuthoredScenarioResult
}

struct CityScenarioTargetTier: Identifiable, Equatable, Sendable {
    let medal: CityScenarioMedal
    let title: String
    let requirements: String
    let deadline: String

    var id: String { medal.rawValue }
}

struct CityAuthoredScenarioDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let cityName: String
    let eyebrow: String
    let briefing: String
    let objective: String
    let constraints: [String]
    let estimatedDuration: String
    let targetTiers: [CityScenarioTargetTier]
    let seed: UInt64
    let deadlineTick: Int

    func makeState() -> CityGameState {
        var state = CityGameState.newCity(seed: seed)
        state.cityName = cityName
        state.population = 360
        state.jobs = 190
        state.treasury = 16_000
        state.happiness = 52
        state.approval = 49
        state.powerUsed = 295
        state.waterUsed = 266
        state.progression = nil
        state.authoredScenario = CityAuthoredScenarioSession(
            scenarioID: id,
            startedTick: 0,
            deadlineTick: deadlineTick,
            result: .active
        )
        state.messages = [
            CityMessage(
                tick: 0,
                severity: .warning,
                title: "Harbor Recovery Begins",
                detail: "Harbor Point has 40 city days to restore non-negative cashflow, full utility coverage, at least 50% happiness, a $15,000 reserve, and 380 residents. Start by diagnosing the operating gap and near-capacity utilities."
            )
        ]
        return state
    }
}

enum CityAuthoredScenarioCatalog {
    static let harborRecovery = CityAuthoredScenarioDefinition(
        id: "harbor-recovery",
        title: "Harbor Recovery",
        cityName: "Harbor Point",
        eyebrow: "Standalone Scenario",
        briefing: "A fast-growing harbor town has exhausted its early job base and nearly filled its utility network. Stabilize daily operations without draining the emergency reserve, then restore measured growth.",
        objective: "Reach 380 residents with non-negative cashflow, full utilities, at least 50% happiness, and $15,000 in reserve before Day 41.",
        constraints: [
            "No creative resources: construction, upkeep, demand, and consequences remain active.",
            "The scenario ends if the city enters its normal insolvency or confidence crisis.",
            "The deadline arrives after 40 city days; pause never consumes scenario time.",
        ],
        estimatedDuration: "15–25 minutes",
        targetTiers: [
            CityScenarioTargetTier(
                medal: .bronze,
                title: "Recovery",
                requirements: "380 residents · $15K reserve · balanced operations · full utilities · 50 happiness",
                deadline: "Before Day 41"
            ),
            CityScenarioTargetTier(
                medal: .silver,
                title: "Strong Recovery",
                requirements: "400 residents · $22K reserve · 55 happiness · 12% utility reserve",
                deadline: "By Day 28"
            ),
            CityScenarioTargetTier(
                medal: .gold,
                title: "Harbor Turnaround",
                requirements: "450 residents · $30K reserve · 60 happiness · 18% utility reserve",
                deadline: "By Day 22"
            ),
        ],
        seed: 2_026_081_201,
        deadlineTick: 160
    )

    static let all = [harborRecovery]

    static func definition(for id: String) -> CityAuthoredScenarioDefinition? {
        all.first { $0.id == id }
    }
}

struct CityAuthoredScenarioEvaluation: Equatable, Sendable {
    let definition: CityAuthoredScenarioDefinition
    let session: CityAuthoredScenarioSession
    let projectedBalance: Double
    let utilityCoverage: Double
    let utilityReserve: Double
    let treasury: Double
    let population: Int
    let happiness: Double
    let currentTick: Int
    let daysRemaining: Int

    static func make(state: CityGameState) -> Self? {
        guard let session = state.authoredScenario,
              let definition = CityAuthoredScenarioCatalog.definition(for: session.scenarioID) else {
            return nil
        }
        return Self(
            definition: definition,
            session: session,
            projectedBalance: CitySimulation.projectedBalance(in: state),
            utilityCoverage: CitySimulation.utilityCoverage(in: state),
            utilityReserve: CitySimulation.utilityReserve(in: state),
            treasury: state.treasury,
            population: state.population,
            happiness: state.happiness,
            currentTick: state.tick,
            daysRemaining: max(0, (session.deadlineTick - state.tick + 3) / 4)
        )
    }

    var mandatoryComplete: Bool {
        projectedBalance >= 0
            && utilityCoverage >= 1
            && treasury >= 15_000
            && population >= 380
            && happiness >= 50
    }

    var earnedMedal: CityScenarioMedal? {
        guard mandatoryComplete else { return nil }
        let relativeTick = max(0, currentTick - session.startedTick)
        if population >= 450,
           treasury >= 30_000,
           happiness >= 60,
           utilityReserve >= 0.18,
           relativeTick <= 84 {
            return .gold
        }
        if population >= 400,
           treasury >= 22_000,
           happiness >= 55,
           utilityReserve >= 0.12,
           relativeTick <= 108 {
            return .silver
        }
        return .bronze
    }

    var adaptiveHint: String {
        if utilityCoverage < 1 {
            return "Utilities are constraining recovery. Add power or water capacity before more growth."
        }
        if utilityReserve < 0.08 {
            return "Utility coverage is full but fragile. Build reserve capacity before adding residents."
        }
        if projectedBalance < 0 {
            return "Operations still lose \((-projectedBalance).currencyText) per cycle. Add productive jobs, adjust tax deliberately, or trim new upkeep."
        }
        if treasury < 15_000 {
            return "Cashflow is stable. Pause major construction until the reserve returns to $15,000."
        }
        if population < 380 {
            return "The base is stable. Add connected homes and enough jobs to welcome \(380 - population) more residents."
        }
        return earnedMedal.map { "\($0.title) target secured. The scenario will close at the next daily review." }
            ?? "Recovery standards are within reach. Hold every requirement together."
    }

    var objectives: [CityObjective] {
        let balanceProgress = min(1, max(0, 1 + projectedBalance / 250))
        let utilityProgress = min(1, utilityCoverage)
        let happinessProgress = min(1, happiness / 50)
        return [
            CityObjective(
                id: "scenario-stability",
                title: "Restore Daily Stability",
                detail: "Balance operations while keeping utilities full and happiness at 50%",
                progress: min(balanceProgress, min(utilityProgress, happinessProgress)),
                remaining: adaptiveHint
            ),
            CityObjective(
                id: "scenario-reserve",
                title: "Protect the Reserve",
                detail: "Finish with at least $15,000 available",
                progress: min(1, max(0, treasury / 15_000)),
                remaining: treasury >= 15_000
                    ? "Emergency reserve protected"
                    : "Rebuild \((15_000 - treasury).currencyText)"
            ),
            CityObjective(
                id: "scenario-population",
                title: "Restore Measured Growth",
                detail: "Reach 380 residents without breaking stability",
                progress: min(1, max(0, Double(population) / 380)),
                remaining: population >= 380
                    ? "Population target reached"
                    : "Welcome \(380 - population) more residents"
            ),
        ]
    }

    func presentations(previousProgressByID: [String: Double]) -> [CityObjectivePresentation] {
        objectives.map { objective in
            let trend = CityObjectivePresentation.trendForScenario(
                progress: objective.progress,
                completed: objective.completed,
                previousProgress: previousProgressByID[objective.id]
            )
            let sharedDeadline = "\(daysRemaining) city days remaining · ends before Day 41"
            switch objective.id {
            case "scenario-stability":
                return CityObjectivePresentation(
                    objective: objective,
                    currentValue: "\(projectedBalance.signedCurrencyText) · U \(Int((utilityCoverage * 100).rounded()))% · H \(Int(happiness.rounded()))%",
                    targetValue: "$0+ · U 100% · H 50%",
                    trend: trend,
                    persistence: "Hold all three conditions together at a daily review",
                    deadline: sharedDeadline,
                    reward: "Qualifies the city for a recovery medal",
                    passRule: "Cashflow is non-negative, utilities are fully covered, and happiness is at least 50%.",
                    failRule: "Any missing condition leaves daily stability incomplete when the deadline arrives.",
                    diagnosticLabel: "Diagnose Stability"
                )
            case "scenario-reserve":
                return CityObjectivePresentation(
                    objective: objective,
                    currentValue: treasury.currencyText,
                    targetValue: "$15,000",
                    trend: trend,
                    persistence: "Available when the recovery is evaluated",
                    deadline: sharedDeadline,
                    reward: "Protects Harbor Point from one more shock",
                    passRule: "Treasury is at least $15,000 when all recovery standards align.",
                    failRule: "Construction that drops the reserve below target must be recovered before the deadline.",
                    diagnosticLabel: "Open City Finances"
                )
            default:
                return CityObjectivePresentation(
                    objective: objective,
                    currentValue: "\(population) residents",
                    targetValue: "380 residents",
                    trend: trend,
                    persistence: "Population and stability must align at one daily review",
                    deadline: sharedDeadline,
                    reward: "Completes Harbor Point's mandatory recovery",
                    passRule: "Reach 380 residents while every stability and reserve requirement also passes.",
                    failRule: "Population alone does not complete the scenario if finances, utilities, or happiness fail.",
                    diagnosticLabel: "Diagnose Growth"
                )
            }
        }
    }
}

enum CityAuthoredScenarioEngine {
    static func evaluate(_ state: inout CityGameState) {
        guard var session = state.authoredScenario,
              session.result == .active,
              let evaluation = CityAuthoredScenarioEvaluation.make(state: state) else { return }

        if state.status == .lost {
            session.result = .failedCityCrisis
            state.authoredScenario = session
            postResult(
                title: "Harbor Recovery Ended",
                detail: "Harbor Point entered a citywide crisis before the recovery standards aligned.",
                severity: .critical,
                to: &state
            )
            return
        }

        if let medal = evaluation.earnedMedal {
            session.result = switch medal {
            case .bronze: .bronze
            case .silver: .silver
            case .gold: .gold
            }
            state.authoredScenario = session
            state.status = .won
            postResult(
                title: "Harbor Recovery Complete",
                detail: "\(medal.title) recovery secured on \(state.formattedDay). Cashflow, utilities, happiness, reserves, and measured growth aligned.",
                severity: .good,
                to: &state
            )
            return
        }

        if state.tick >= session.deadlineTick {
            session.result = .failedDeadline
            state.authoredScenario = session
            state.status = .lost
            postResult(
                title: "Recovery Deadline Reached",
                detail: "The 40-day window closed before every mandatory recovery standard aligned. The debrief identifies the remaining gap.",
                severity: .critical,
                to: &state
            )
        }
    }

    private static func postResult(
        title: String,
        detail: String,
        severity: MessageSeverity,
        to state: inout CityGameState
    ) {
        state.messages.insert(
            CityMessage(tick: state.tick, severity: severity, title: title, detail: detail),
            at: 0
        )
        state.messages = Array(state.messages.prefix(12))
    }
}

struct CityScenarioDebriefMetric: Identifiable, Equatable, Sendable {
    let label: String
    let value: String
    let symbol: String

    var id: String { label }
}

struct CityScenarioDebriefPresentation: Equatable, Sendable {
    let eyebrow: String
    let title: String
    let summary: String
    let outcomeDetail: String
    let nextStep: String
    let accessibilityLabel: String
    let succeeded: Bool
    let metrics: [CityScenarioDebriefMetric]

    var accessibilitySummary: String {
        ([eyebrow, title, summary] + metrics.map { "\($0.label): \($0.value)" }
            + [outcomeDetail, nextStep])
            .joined(separator: ". ")
    }

    static func make(state: CityGameState) -> Self? {
        guard let session = state.authoredScenario,
              session.result.isComplete,
              let evaluation = CityAuthoredScenarioEvaluation.make(state: state) else {
            return nil
        }
        let metrics = [
            CityScenarioDebriefMetric(
                label: "Residents",
                value: state.population.formatted(),
                symbol: "person.3.fill"
            ),
            CityScenarioDebriefMetric(
                label: "Treasury",
                value: state.treasury.currencyText,
                symbol: "banknote.fill"
            ),
            CityScenarioDebriefMetric(
                label: "Cashflow",
                value: evaluation.projectedBalance.signedCurrencyText,
                symbol: evaluation.projectedBalance >= 0
                    ? "arrow.up.right.circle.fill"
                    : "arrow.down.right.circle.fill"
            ),
            CityScenarioDebriefMetric(
                label: "Utilities",
                value: "\(Int((evaluation.utilityCoverage * 100).rounded()))% · \(Int((evaluation.utilityReserve * 100).rounded()))% reserve",
                symbol: "bolt.fill"
            ),
        ]

        if let medal = session.result.medal {
            return Self(
                eyebrow: "\(medal.title) Scenario Medal",
                title: "Harbor Point Recovered",
                summary: "Every mandatory recovery standard aligned on \(state.formattedDay).",
                outcomeDetail: medal == .bronze
                    ? "The city is stable again. Faster growth, a larger reserve, and stronger utility headroom remain available for a higher medal."
                    : "The recovery exceeded its mandatory target with stronger reserves, livability, growth, and timing.",
                nextStep: "Replay Harbor Recovery for another strategy or continue with a new guided or sandbox city.",
                accessibilityLabel: "Harbor Recovery scenario complete with \(medal.title) medal",
                succeeded: true,
                metrics: metrics
            )
        }

        let deadlineFailure = session.result == .failedDeadline
        return Self(
            eyebrow: "Scenario Debrief",
            title: deadlineFailure ? "Harbor Recovery Missed Its Deadline" : "Harbor Point Entered Crisis",
            summary: deadlineFailure
                ? "The 40-day recovery window closed before every mandatory standard aligned."
                : "A citywide insolvency or confidence crisis ended the recovery attempt.",
            outcomeDetail: evaluation.adaptiveHint,
            nextStep: "Replay from the same deterministic seed, protect the reserve, and address the earliest diagnosed pressure first.",
            accessibilityLabel: deadlineFailure
                ? "Harbor Recovery scenario failed at the deadline"
                : "Harbor Recovery scenario failed after a city crisis",
            succeeded: false,
            metrics: metrics
        )
    }
}

private extension Int {
    func formatted() -> String {
        NumberFormatter.localizedString(from: NSNumber(value: self), number: .decimal)
    }
}
