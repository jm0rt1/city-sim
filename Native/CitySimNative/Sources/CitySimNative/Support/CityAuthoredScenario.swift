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

enum CityAuthoredScenarioKind: String, Equatable, Sendable {
    case recovery
    case waterResilience
}

struct CityScenarioOpening: Equatable, Sendable {
    let population: Int
    let jobs: Int
    let treasury: Double
    let happiness: Double
    let approval: Double
    let powerUsed: Int
    let waterUsed: Int
    let messageTitle: String
    let messageDetail: String
}

struct CityAuthoredScenarioDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let kind: CityAuthoredScenarioKind
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
    let opening: CityScenarioOpening

    var deadlineDay: Int { deadlineTick / 4 + 1 }

    func makeState() -> CityGameState {
        var state = CityGameState.newCity(seed: seed)
        state.cityName = cityName
        state.population = opening.population
        state.jobs = opening.jobs
        state.treasury = opening.treasury
        state.happiness = opening.happiness
        state.approval = opening.approval
        state.powerUsed = opening.powerUsed
        state.waterUsed = opening.waterUsed
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
                title: opening.messageTitle,
                detail: opening.messageDetail
            )
        ]
        state.beginHistoryTracking()
        return state
    }
}

enum CityAuthoredScenarioCatalog {
    static let harborRecovery = CityAuthoredScenarioDefinition(
        id: "harbor-recovery",
        kind: .recovery,
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
        deadlineTick: 160,
        opening: CityScenarioOpening(
            population: 360,
            jobs: 190,
            treasury: 16_000,
            happiness: 52,
            approval: 49,
            powerUsed: 295,
            waterUsed: 266,
            messageTitle: "Harbor Recovery Begins",
            messageDetail: "Harbor Point has 40 city days to restore non-negative cashflow, full utility coverage, at least 50% happiness, a $15,000 reserve, and 380 residents. Start by diagnosing the operating gap and near-capacity utilities."
        )
    )

    static let waterlineEmergency = CityAuthoredScenarioDefinition(
        id: "waterline-emergency",
        kind: .waterResilience,
        title: "Waterline Emergency",
        cityName: "Mesa Verde",
        eyebrow: "Water Stress Scenario",
        briefing: "Mesa Verde's dry-season demand has consumed nearly every gallon of spare capacity. Build durable water headroom while preserving public confidence and a construction reserve.",
        objective: "Reach 25% water reserve with non-negative cashflow, at least 52% happiness, and $12,000 in reserve before Day 37.",
        constraints: [
            "Water capacity—not population growth—is the mandatory resilience target.",
            "Normal construction costs, upkeep, demand, and city crises remain active.",
            "The deadline arrives after 36 city days; pause never consumes scenario time.",
        ],
        estimatedDuration: "15–25 minutes",
        targetTiers: [
            CityScenarioTargetTier(
                medal: .bronze,
                title: "Water Security",
                requirements: "25% water reserve · $12K reserve · balanced operations · 52 happiness",
                deadline: "Before Day 37"
            ),
            CityScenarioTargetTier(
                medal: .silver,
                title: "Dry-Season Ready",
                requirements: "35% water reserve · $18K reserve · 56 happiness",
                deadline: "By Day 26"
            ),
            CityScenarioTargetTier(
                medal: .gold,
                title: "Desert Resilience",
                requirements: "45% water reserve · $24K reserve · 60 happiness",
                deadline: "By Day 20"
            ),
        ],
        seed: 2_026_081_202,
        deadlineTick: 144,
        opening: CityScenarioOpening(
            population: 390,
            jobs: 220,
            treasury: 18_000,
            happiness: 48,
            approval: 46,
            powerUsed: 250,
            waterUsed: 264,
            messageTitle: "Waterline Emergency Begins",
            messageDetail: "Mesa Verde has 36 city days to establish 25% water reserve, restore non-negative cashflow, lift happiness to 52%, and protect $12,000. Start with the water network, then balance resilience against upkeep and confidence."
        )
    )

    static let all = [harborRecovery, waterlineEmergency]

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
    let waterReserve: Double
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
            waterReserve: max(
                0,
                Double(state.waterCapacity - state.waterUsed) / Double(max(1, state.waterCapacity))
            ),
            treasury: state.treasury,
            population: state.population,
            happiness: state.happiness,
            currentTick: state.tick,
            daysRemaining: max(0, (session.deadlineTick - state.tick + 3) / 4)
        )
    }

    var mandatoryComplete: Bool {
        switch definition.kind {
        case .recovery:
            projectedBalance >= 0
                && utilityCoverage >= 1
                && treasury >= 15_000
                && population >= 380
                && happiness >= 50
        case .waterResilience:
            projectedBalance >= 0
                && utilityCoverage >= 1
                && waterReserve >= 0.25
                && treasury >= 12_000
                && happiness >= 52
        }
    }

    var earnedMedal: CityScenarioMedal? {
        guard mandatoryComplete else { return nil }
        let relativeTick = max(0, currentTick - session.startedTick)
        switch definition.kind {
        case .recovery:
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
        case .waterResilience:
            if waterReserve >= 0.45,
               treasury >= 24_000,
               happiness >= 60,
               relativeTick <= 76 {
                return .gold
            }
            if waterReserve >= 0.35,
               treasury >= 18_000,
               happiness >= 56,
               relativeTick <= 100 {
                return .silver
            }
        }
        return .bronze
    }

    var adaptiveHint: String {
        switch definition.kind {
        case .recovery:
            recoveryHint
        case .waterResilience:
            waterResilienceHint
        }
    }

    private var recoveryHint: String {
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

    private var waterResilienceHint: String {
        if utilityCoverage < 1 || waterReserve < 0.25 {
            let percent = Int((waterReserve * 100).rounded())
            return "Water reserve is \(percent)%. Add a Water Tower and avoid new demand until it reaches 25%."
        }
        if projectedBalance < 0 {
            return "Water is secure, but operations lose \((-projectedBalance).currencyText) per cycle. Restore cashflow without consuming the reserve."
        }
        if happiness < 52 {
            return "The network is resilient. Raise happiness by \(Int(ceil(52 - happiness))) points while protecting water headroom."
        }
        if treasury < 12_000 {
            return "Core standards are stable. Rebuild \((12_000 - treasury).currencyText) before the deadline."
        }
        return earnedMedal.map { "\($0.title) target secured. The scenario will close at the next daily review." }
            ?? "Water resilience standards are aligned. Hold them together through the next review."
    }

    var objectives: [CityObjective] {
        switch definition.kind {
        case .recovery:
            recoveryObjectives
        case .waterResilience:
            waterResilienceObjectives
        }
    }

    private var recoveryObjectives: [CityObjective] {
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

    private var waterResilienceObjectives: [CityObjective] {
        let balanceProgress = min(1, max(0, 1 + projectedBalance / 250))
        let happinessProgress = min(1, happiness / 52)
        return [
            CityObjective(
                id: "scenario-water",
                title: "Secure the Waterline",
                detail: "Reach 25% water reserve with full utility coverage",
                progress: min(1, max(0, waterReserve / 0.25)),
                remaining: waterReserve >= 0.25 && utilityCoverage >= 1
                    ? "Water resilience target reached"
                    : "Build water headroom before adding demand"
            ),
            CityObjective(
                id: "scenario-stability",
                title: "Restore Public Confidence",
                detail: "Balance operations while lifting happiness to 52%",
                progress: min(balanceProgress, happinessProgress),
                remaining: adaptiveHint
            ),
            CityObjective(
                id: "scenario-reserve",
                title: "Protect Construction Reserve",
                detail: "Finish with at least $12,000 available",
                progress: min(1, max(0, treasury / 12_000)),
                remaining: treasury >= 12_000
                    ? "Construction reserve protected"
                    : "Rebuild \((12_000 - treasury).currencyText)"
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
            let sharedDeadline = "\(daysRemaining) city days remaining · ends before Day \(definition.deadlineDay)"
            if definition.kind == .waterResilience {
                return waterResiliencePresentation(for: objective, trend: trend, deadline: sharedDeadline)
            }
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

    private func waterResiliencePresentation(
        for objective: CityObjective,
        trend: CityObjectiveTrend,
        deadline: String
    ) -> CityObjectivePresentation {
        switch objective.id {
        case "scenario-water":
            CityObjectivePresentation(
                objective: objective,
                currentValue: "\(Int((waterReserve * 100).rounded()))% water reserve",
                targetValue: "25% water reserve",
                trend: trend,
                persistence: "Hold full coverage and water headroom at a daily review",
                deadline: deadline,
                reward: "Qualifies Mesa Verde for a resilience medal",
                passRule: "Water reserve is at least 25% and all utility demand remains covered.",
                failRule: "Coverage without 25% water headroom does not secure the city.",
                diagnosticLabel: "Inspect Water"
            )
        case "scenario-stability":
            CityObjectivePresentation(
                objective: objective,
                currentValue: "\(projectedBalance.signedCurrencyText) · H \(Int(happiness.rounded()))%",
                targetValue: "$0+ · H 52%",
                trend: trend,
                persistence: "Cashflow and happiness must align with water security",
                deadline: deadline,
                reward: "Turns emergency capacity into a durable recovery",
                passRule: "Cashflow is non-negative and happiness is at least 52%.",
                failRule: "Water construction alone cannot complete the scenario if confidence or operations fail.",
                diagnosticLabel: "Diagnose Confidence"
            )
        default:
            CityObjectivePresentation(
                objective: objective,
                currentValue: treasury.currencyText,
                targetValue: "$12,000",
                trend: trend,
                persistence: "Available when all resilience standards align",
                deadline: deadline,
                reward: "Leaves Mesa Verde ready for the next dry season",
                passRule: "Treasury is at least $12,000 when the scenario evaluates.",
                failRule: "Capacity spending must not leave the city below its protected reserve.",
                diagnosticLabel: "Open City Finances"
            )
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
                title: "\(evaluation.definition.title) Ended",
                detail: "\(evaluation.definition.cityName) entered a citywide crisis before the scenario standards aligned.",
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
                title: "\(evaluation.definition.title) Complete",
                detail: completionDetail(for: evaluation, medal: medal, day: state.formattedDay),
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
                title: "\(evaluation.definition.title) Deadline Reached",
                detail: "The \(evaluation.definition.deadlineDay - 1)-day window closed before every mandatory scenario standard aligned. The debrief identifies the remaining gap.",
                severity: .critical,
                to: &state
            )
        }
    }

    private static func completionDetail(
        for evaluation: CityAuthoredScenarioEvaluation,
        medal: CityScenarioMedal,
        day: String
    ) -> String {
        switch evaluation.definition.kind {
        case .recovery:
            "\(medal.title) recovery secured on \(day). Cashflow, utilities, happiness, reserves, and measured growth aligned."
        case .waterResilience:
            "\(medal.title) resilience secured on \(day). Water headroom, cashflow, happiness, and the construction reserve aligned."
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
        let resilienceMetric = switch evaluation.definition.kind {
        case .recovery:
            CityScenarioDebriefMetric(
                label: "Utilities",
                value: "\(Int((evaluation.utilityCoverage * 100).rounded()))% · \(Int((evaluation.utilityReserve * 100).rounded()))% reserve",
                symbol: "bolt.fill"
            )
        case .waterResilience:
            CityScenarioDebriefMetric(
                label: "Water reserve",
                value: "\(Int((evaluation.waterReserve * 100).rounded()))%",
                symbol: "drop.fill"
            )
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
            resilienceMetric,
        ]

        if let medal = session.result.medal {
            let outcome = successfulOutcome(evaluation: evaluation, medal: medal, day: state.formattedDay)
            return Self(
                eyebrow: "\(medal.title) Scenario Medal",
                title: outcome.title,
                summary: outcome.summary,
                outcomeDetail: outcome.detail,
                nextStep: "Replay \(evaluation.definition.title) for another strategy or choose a different authored scenario.",
                accessibilityLabel: "\(evaluation.definition.title) scenario complete with \(medal.title) medal",
                succeeded: true,
                metrics: metrics
            )
        }

        let deadlineFailure = session.result == .failedDeadline
        return Self(
            eyebrow: "Scenario Debrief",
            title: deadlineFailure
                ? "\(evaluation.definition.title) Missed Its Deadline"
                : "\(evaluation.definition.cityName) Entered Crisis",
            summary: deadlineFailure
                ? "The \(evaluation.definition.deadlineDay - 1)-day window closed before every mandatory standard aligned."
                : "A citywide insolvency or confidence crisis ended this scenario attempt.",
            outcomeDetail: evaluation.adaptiveHint,
            nextStep: "Replay from the same deterministic seed, protect the reserve, and address the earliest diagnosed pressure first.",
            accessibilityLabel: deadlineFailure
                ? "\(evaluation.definition.title) scenario failed at the deadline"
                : "\(evaluation.definition.title) scenario failed after a city crisis",
            succeeded: false,
            metrics: metrics
        )
    }

    private static func successfulOutcome(
        evaluation: CityAuthoredScenarioEvaluation,
        medal: CityScenarioMedal,
        day: String
    ) -> (title: String, summary: String, detail: String) {
        switch evaluation.definition.kind {
        case .recovery:
            (
                "Harbor Point Recovered",
                "Every mandatory recovery standard aligned on \(day).",
                medal == .bronze
                    ? "The city is stable again. Faster growth, a larger reserve, and stronger utility headroom remain available for a higher medal."
                    : "The recovery exceeded its mandatory target with stronger reserves, livability, growth, and timing."
            )
        case .waterResilience:
            (
                "Mesa Verde Water-Secure",
                "Every mandatory water resilience standard aligned on \(day).",
                medal == .bronze
                    ? "The dry-season emergency is contained. More water headroom, confidence, reserve cash, and speed remain available for a higher medal."
                    : "Mesa Verde exceeded its resilience target with stronger water headroom, confidence, reserves, and timing."
            )
        }
    }
}

private extension Int {
    func formatted() -> String {
        NumberFormatter.localizedString(from: NSNumber(value: self), number: .decimal)
    }
}
