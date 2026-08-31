import Foundation

struct CityDirectResponse: Identifiable, Hashable, Sendable {
    let title: String
    let command: CityCommandID
    let explanation: String
    let focusesMap: Bool

    var id: String { "\(command.rawValue)|\(title)" }
}

struct CityResumeBriefPresentation: Equatable, Sendable {
    let title: String
    let detail: String
    let nextAction: String
    let command: CityCommandID?

    init(
        title: String,
        detail: String,
        nextAction: String,
        command: CityCommandID? = nil
    ) {
        self.title = title
        self.detail = detail
        self.nextAction = nextAction
        self.command = command
    }

    var compactText: String {
        "\(title) · Next: \(nextAction)"
    }

    var accessibilitySummary: String {
        "\(title). \(detail) Next: \(nextAction)."
    }

    static func make(analytics: CityAnalytics) -> Self? {
        guard analytics.state.status == .playing else { return nil }

        if let pressure = currentPressure(analytics: analytics) { return pressure }

        if analytics.awaitingStrategyChoice {
            return Self(
                title: "Choose a Growth Engine",
                detail: "Commit Commercial Stewardship or Industrial Expansion by building one route first.",
                nextAction: "Build commercial or industrial"
            )
        }

        if let phase = analytics.strategyPhase, phase != .completed {
            if let objective = analytics.strategyObjective {
                let action = strategyAction(analytics: analytics, phase: phase)
                return Self(
                    title: objective.title,
                    detail: objective.remaining,
                    nextAction: action.title,
                    command: action.command
                )
            }
        }

        if analytics.townCharterAwarded, let phase = analytics.secondActPhase {
            if phase == .qualification {
                let support = CityRegionalCapitalDecisionSupport.make(analytics: analytics)
                return Self(
                    title: support.title,
                    detail: support.detail,
                    nextAction: support.primaryResponse.title,
                    command: support.primaryResponse.command
                )
            }

            let action = regionalCapitalAction(analytics: analytics, phase: phase)
            return Self(
                title: "Continue the Regional Capital mandate",
                detail: analytics.regionalCapitalStatusText,
                nextAction: action.title,
                command: action.command
            )
        }

        let support = CityTownCharterDecisionSupport.make(analytics: analytics)
        return Self(
            title: support.title,
            detail: analytics.townCharterStatusText,
            nextAction: support.primaryResponse.title,
            command: support.primaryResponse.command
        )
    }

    private static func currentPressure(analytics: CityAnalytics) -> Self? {
        let utility = CityUtilityDecisionSupport.make(analytics: analytics)
        if utility.status == .shortfall {
            return Self(
                title: "Utility Shortfall",
                detail: utility.detail,
                nextAction: utility.response?.title ?? "Review utilities",
                command: utility.response?.command ?? .inspectorUtilities
            )
        }
        if analytics.projectedBalance < 0 {
            return Self(
                title: "Budget Gap",
                detail: "Operations are projected to use \((-analytics.projectedBalance).currencyText) per cycle.",
                nextAction: "Review finances",
                command: .inspectorFinances
            )
        }
        if let warning = CitySimulation.hiringBottleneckWarning(in: analytics.state) {
            let routeKind: BuildingKind? = analytics.committedStrategy.map {
                $0 == .industrialExpansion ? .industrial : .commercial
            }
            let route = routeKind.map { "\($0.title.lowercased()) jobs" }
                ?? "commercial or industrial jobs"
            return Self(
                title: "Hiring Bottleneck",
                detail: warning.detail,
                nextAction: "Build \(route)",
                command: routeKind.map(CityCommandCatalog.id(for:)) ?? .inspectorEmployment
            )
        }
        if utility.status == .tight {
            return Self(
                title: "Utility Reserve Tight",
                detail: utility.detail,
                nextAction: utility.response?.title ?? "Review utilities",
                command: utility.response?.command ?? .inspectorUtilities
            )
        }
        return nil
    }

    private static func strategyAction(
        analytics: CityAnalytics,
        phase: CityStrategyPhase
    ) -> (title: String, command: CityCommandID) {
        guard phase == .recovery else {
            return ("Review the strategy timeline", .inspectorOverview)
        }
        if analytics.strategyRecoveryResolution != nil {
            return ("Review recovery progress", .inspectorOverview)
        }
        return analytics.committedStrategy == .industrialExpansion
            ? ("Review reserve utilities", .inspectorUtilities)
            : ("Review tax policy", .inspectorFinances)
    }

    private static func regionalCapitalAction(
        analytics: CityAnalytics,
        phase: CitySecondActPhase
    ) -> (title: String, command: CityCommandID) {
        guard phase == .recovery else {
            return ("Review Regional Capital progress", .inspectorOverview)
        }
        return switch analytics.strategyRecoveryResolution {
        case .commercialTaxRelief:
            ("Review tax policy", .inspectorFinances)
        case .commercialPublicRealmInvestment, .industrialGreenBuffer:
            ("Build a park", .buildPark)
        case .industrialUtilityExpansion:
            CityUtilityDecisionSupport.make(analytics: analytics).priorityKind == .waterTower
                ? ("Build Water Tower", .buildWaterTower)
                : ("Build Power Plant", .buildPowerPlant)
        case nil:
            ("Review the established recovery", .inspectorOverview)
        }
    }
}

struct CityUtilityDecisionSupport: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case healthy
        case tight
        case shortfall
    }

    let status: Status
    let title: String
    let detail: String
    let priorityKind: BuildingKind
    let response: CityDirectResponse?

    static func make(analytics: CityAnalytics) -> Self {
        let state = analytics.state
        let powerSpare = state.powerCapacity - state.powerUsed
        let waterSpare = state.waterCapacity - state.waterUsed
        let powerReserve = reserve(capacity: state.powerCapacity, used: state.powerUsed)
        let waterReserve = reserve(capacity: state.waterCapacity, used: state.waterUsed)
        let priorityKind: BuildingKind = waterReserve <= powerReserve ? .waterTower : .powerPlant
        let prioritySpare = priorityKind == .waterTower ? waterSpare : powerSpare
        let priorityReserve = priorityKind == .waterTower ? waterReserve : powerReserve
        let otherTitle = priorityKind == .waterTower ? "Power" : "Water"
        let otherSpare = priorityKind == .waterTower ? powerSpare : waterSpare

        if powerSpare < 0 || waterSpare < 0 {
            let priorityTitle = priorityKind == .waterTower ? "Water" : "Power"
            let projectTitle = priorityKind == .waterTower ? "Build Water Tower" : "Build Power Plant"
            let otherState = otherSpare < 0
                ? "\(otherTitle) is also short by \((-otherSpare).formatted())."
                : "\(otherTitle) still has \(otherSpare.formatted()) spare."
            return Self(
                status: .shortfall,
                title: "\(priorityTitle) shortfall",
                detail: "\(priorityTitle) is short by \((-prioritySpare).formatted()). \(otherState) Restore capacity before resuming growth.",
                priorityKind: priorityKind,
                response: .init(
                    title: projectTitle,
                    command: CityCommandCatalog.id(for: priorityKind),
                    explanation: "Restore the most constrained utility first; the city may still need the other network afterward.",
                    focusesMap: true
                )
            )
        }

        let priorityTitle = priorityKind == .waterTower ? "Water" : "Power"
        if priorityReserve < 0.12 {
            let projectTitle = priorityKind == .waterTower ? "Build Water Tower" : "Build Power Plant"
            return Self(
                status: .tight,
                title: "\(priorityTitle) reserve tight",
                detail: "\(priorityTitle) is limiting growth with \(prioritySpare.formatted()) spare (\((priorityReserve * 100).percentText) reserve). Expand before adding homes or jobs.",
                priorityKind: priorityKind,
                response: .init(
                    title: projectTitle,
                    command: CityCommandCatalog.id(for: priorityKind),
                    explanation: "Add capacity to the tighter network before committing more growth.",
                    focusesMap: true
                )
            )
        }

        return Self(
            status: .healthy,
            title: "\(priorityTitle) is the tighter network",
            detail: "\(priorityTitle) has \(prioritySpare.formatted()) spare (\((priorityReserve * 100).percentText) reserve). Both utilities cover current use.",
            priorityKind: priorityKind,
            response: nil
        )
    }

    private static func reserve(capacity: Int, used: Int) -> Double {
        guard capacity > 0 else { return used > 0 ? -Double(used) : 0 }
        return Double(capacity - used) / Double(capacity)
    }
}

struct CityTownCharterDecisionSupport: Equatable, Sendable {
    let title: String
    let primaryResponse: CityDirectResponse
    let secondaryResponses: [CityDirectResponse]

    static func make(analytics: CityAnalytics) -> Self {
        if analytics.waterHeadroom == 0 {
            return utility(
                title: "Add water capacity",
                kind: .waterTower,
                explanation: "Add water capacity before committing more growth."
            )
        }
        if analytics.powerHeadroom == 0 {
            return utility(
                title: "Add power capacity",
                kind: .powerPlant,
                explanation: "Add power capacity before committing more growth."
            )
        }
        if analytics.state.happiness < 45 {
            return park(
                title: "Restore livability",
                explanation: "Place a park while reviewing utility service and local happiness."
            )
        }
        if analytics.state.population < 500 {
            if let forecast = analytics.townCharterUtilityForecast {
                let network = forecast.kind == .waterTower ? "water" : "power"
                return utility(
                    title: "Prepare \(network) for 500 residents",
                    kind: forecast.kind,
                    explanation: "Add at least \(forecast.capacityGap.formatted()) \(network) capacity so projected use of \(forecast.projectedUse.formatted()) keeps the Charter's 15% reserve."
                )
            }
            let charterWorkforceTarget = 500 * 7 / 10
            let charterJobCapacity = Int(ceil(Double(charterWorkforceTarget) * 0.9))
            if analytics.jobCapacity < charterJobCapacity {
                return jobs(
                    analytics: analytics,
                    title: "Prepare \((charterJobCapacity - analytics.jobCapacity).formatted()) jobs"
                )
            }
            return build(
                title: "Grow to 500 residents",
                kind: .residential,
                explanation: "Add housing capacity for the remaining \((500 - analytics.state.population).formatted()) residents.",
                inspectorTitle: "Review population",
                inspectorCommand: .inspectorPopulation,
                inspectorExplanation: "Review residents, housing capacity, and current growth conditions."
            )
        }
        if analytics.state.treasury < 10_000 {
            return finances(
                title: "Restore the treasury",
                explanation: "Review revenue, upkeep, tax policy, and runway before spending again."
            )
        }
        if analytics.projectedBalance < 0 {
            return finances(
                title: "Balance city operations",
                explanation: "Review revenue, upkeep, and tax policy to close the operating gap."
            )
        }
        if analytics.employmentRate < 0.9 {
            return jobs(analytics: analytics, title: "Restore 90% employment")
        }
        if analytics.utilityCoverage < 1 || analytics.utilityReserve < 0.15 {
            let utilitySupport = CityUtilityDecisionSupport.make(analytics: analytics)
            let kind = utilitySupport.priorityKind
            return utility(
                title: analytics.utilityCoverage < 1
                    ? "Restore utility coverage"
                    : "Build 15% utility reserve",
                kind: kind,
                explanation: "Expand the tighter utility network before Charter qualification continues."
            )
        }
        if analytics.state.happiness < 52 {
            return park(
                title: "Raise happiness to 52%",
                explanation: "Place a park where it can improve livability without promising a fixed result."
            )
        }
        for kind in [BuildingKind.residential, .commercial, .industrial]
        where analytics.count(kind) < (kind == .residential ? 2 : 1) {
            return build(
                title: "Restore \(kind.title) activity",
                kind: kind,
                explanation: "Select \(kind.title) and target the nearest valid parcel for the Charter's balanced-town standard.",
                inspectorTitle: "Review development demand",
                inspectorCommand: .inspectorDemand,
                inspectorExplanation: "Review current demand before restoring the missing district activity."
            )
        }

        return Self(
            title: "Hold every Charter standard",
            primaryResponse: inspect(
                title: "Review Charter standards",
                command: .inspectorOverview,
                explanation: "Review the balanced city indicators while qualification advances."
            ),
            secondaryResponses: []
        )
    }

    private static func jobs(analytics: CityAnalytics, title: String) -> Self {
        let kind: BuildingKind = analytics.committedStrategy == .industrialExpansion
            ? .industrial
            : .commercial
        return build(
            title: title,
            kind: kind,
            explanation: "Add \(kind.title) jobs on the committed growth route.",
            inspectorTitle: "Review employment",
            inspectorCommand: .inspectorEmployment,
            inspectorExplanation: "Review workforce size, job capacity, and the remaining employment gap."
        )
    }

    private static func utility(
        title: String,
        kind: BuildingKind,
        explanation: String
    ) -> Self {
        build(
            title: title,
            kind: kind,
            explanation: explanation,
            inspectorTitle: "Review utilities",
            inspectorCommand: .inspectorUtilities,
            inspectorExplanation: "Review power, water, coverage, and reserve before placing the project."
        )
    }

    private static func park(title: String, explanation: String) -> Self {
        build(
            title: title,
            kind: .park,
            explanation: explanation,
            inspectorTitle: "Review happiness",
            inspectorCommand: .inspectorHappiness,
            inspectorExplanation: "Review the citywide happiness factors before choosing a location."
        )
    }

    private static func finances(title: String, explanation: String) -> Self {
        Self(
            title: title,
            primaryResponse: inspect(
                title: "Review finances",
                command: .inspectorFinances,
                explanation: explanation
            ),
            secondaryResponses: []
        )
    }

    private static func build(
        title: String,
        kind: BuildingKind,
        explanation: String,
        inspectorTitle: String,
        inspectorCommand: CityCommandID,
        inspectorExplanation: String
    ) -> Self {
        Self(
            title: title,
            primaryResponse: .init(
                title: "Build \(kind.title)",
                command: CityCommandCatalog.id(for: kind),
                explanation: explanation,
                focusesMap: true
            ),
            secondaryResponses: [inspect(
                title: inspectorTitle,
                command: inspectorCommand,
                explanation: inspectorExplanation
            )]
        )
    }

    private static func inspect(
        title: String,
        command: CityCommandID,
        explanation: String
    ) -> CityDirectResponse {
        CityDirectResponse(
            title: title,
            command: command,
            explanation: explanation,
            focusesMap: false
        )
    }
}

struct CityRegionalCapitalDecisionSupport: Equatable, Sendable {
    let title: String
    let detail: String
    let primaryResponse: CityDirectResponse
    let secondaryResponses: [CityDirectResponse]

    static func make(analytics: CityAnalytics) -> Self {
        let strategy = analytics.committedStrategy ?? .commercialStewardship
        var requirements: [Requirement] = []

        if analytics.state.population < 525 {
            requirements.append(.init(
                title: "Grow to 525 residents",
                detail: "Add housing for \((525 - analytics.state.population).formatted()) more residents while protecting the other standards.",
                shortfall: "population \(analytics.state.population.formatted()) / 525",
                primaryResponse: .init(
                    title: "Build homes",
                    command: .buildResidential,
                    explanation: "Select Residential and target the nearest valid parcel to create growth capacity.",
                    focusesMap: true
                ),
                secondaryResponses: [inspect(
                    title: "Review population",
                    command: .inspectorPopulation,
                    explanation: "Review residents, housing capacity, and current growth conditions."
                )]
            ))
        }

        let treasuryTarget = strategy == .commercialStewardship ? 12_000.0 : 15_000.0
        if analytics.state.treasury < treasuryTarget {
            requirements.append(.init(
                title: "Restore the treasury",
                detail: "Reach \(treasuryTarget.currencyText) before the Regional Capital review can advance.",
                shortfall: "treasury \(analytics.state.treasury.currencyText) / \(treasuryTarget.currencyText)",
                primaryResponse: inspect(
                    title: "Review finances",
                    command: .inspectorFinances,
                    explanation: "Review revenue, upkeep, tax policy, and runway before committing more spending."
                ),
                secondaryResponses: []
            ))
        }

        let happinessTarget = strategy == .commercialStewardship ? 56.0 : 44.0
        if analytics.state.happiness < happinessTarget {
            requirements.append(.init(
                title: "Restore livability",
                detail: "Raise happiness to \(Int(happinessTarget))% while keeping the city financially stable.",
                shortfall: "happiness \(Int(analytics.state.happiness))% / \(Int(happinessTarget))%",
                primaryResponse: .init(
                    title: "Build a park",
                    command: .buildPark,
                    explanation: "Select Park and target the nearest valid parcel; local conditions still determine the result.",
                    focusesMap: true
                ),
                secondaryResponses: [inspect(
                    title: "Review happiness",
                    command: .inspectorHappiness,
                    explanation: "Review the citywide happiness factors before choosing a location."
                )]
            ))
        }

        let routeKind: BuildingKind = strategy == .commercialStewardship ? .commercial : .industrial
        if analytics.count(routeKind) < 3 {
            requirements.append(.init(
                title: "Complete the \(routeKind.title) district",
                detail: "Maintain three active \(routeKind.title) zones for the committed regional strategy.",
                shortfall: "\(routeKind.title.lowercased()) zones \(analytics.count(routeKind)) / 3",
                primaryResponse: .init(
                    title: "Build \(routeKind.title.lowercased())",
                    command: CityCommandCatalog.id(for: routeKind),
                    explanation: "Select \(routeKind.title) and target the nearest valid parcel to complete the committed district.",
                    focusesMap: true
                ),
                secondaryResponses: [inspect(
                    title: "Review demand",
                    command: .inspectorDemand,
                    explanation: "Review current development demand and route conditions."
                )]
            ))
        }

        if analytics.projectedBalance < 0 {
            requirements.append(.init(
                title: "Balance city operations",
                detail: "Close the \((-analytics.projectedBalance).currencyText) operating gap before restarting qualification.",
                shortfall: "operating gap \((-analytics.projectedBalance).currencyText)",
                primaryResponse: inspect(
                    title: "Review finances",
                    command: .inspectorFinances,
                    explanation: "Review revenue, upkeep, and tax policy to close the operating gap."
                ),
                secondaryResponses: []
            ))
        }

        if analytics.employmentRate < 0.92 {
            requirements.append(.init(
                title: "Restore employment",
                detail: "Raise employment to 92% by adding jobs on the committed \(routeKind.title) route.",
                shortfall: "employment \((analytics.employmentRate * 100).percentText) / 92%",
                primaryResponse: .init(
                    title: "Build \(routeKind.title.lowercased()) jobs",
                    command: CityCommandCatalog.id(for: routeKind),
                    explanation: "Select \(routeKind.title) and target the nearest valid parcel to add route-aligned jobs.",
                    focusesMap: true
                ),
                secondaryResponses: [inspect(
                    title: "Review employment",
                    command: .inspectorEmployment,
                    explanation: "Review workforce size, job capacity, and the remaining employment gap."
                )]
            ))
        }

        let reserveTarget = strategy == .industrialExpansion ? 0.20 : 0.18
        if analytics.utilityCoverage < 1 || analytics.utilityReserve < reserveTarget {
            let utility = CityUtilityDecisionSupport.make(analytics: analytics)
            let kind = utility.priorityKind
            let network = kind == .powerPlant ? "power" : "water"
            requirements.append(.init(
                title: analytics.utilityCoverage < 1 ? "Restore complete utility coverage" : "Build regional utility reserve",
                detail: analytics.utilityCoverage < 1
                    ? "Restore full utility coverage, then hold \((reserveTarget * 100).percentText) reserve. Add \(network) capacity first."
                    : "Raise the tighter \(network) network to keep at least \((reserveTarget * 100).percentText) citywide reserve.",
                shortfall: analytics.utilityCoverage < 1
                    ? "utility coverage \((analytics.utilityCoverage * 100).percentText) / 100%"
                    : "utility reserve \((analytics.utilityReserve * 100).percentText) / \((reserveTarget * 100).percentText)",
                primaryResponse: .init(
                    title: kind == .powerPlant ? "Build Power Plant" : "Build Water Tower",
                    command: CityCommandCatalog.id(for: kind),
                    explanation: "Expand the tighter utility network before qualification resumes.",
                    focusesMap: true
                ),
                secondaryResponses: [inspect(
                    title: "Review utilities",
                    command: .inspectorUtilities,
                    explanation: "Review power, water, coverage, and reserve before placing the project."
                )]
            ))
        }

        guard let primary = requirements.first else {
            let remaining = max(
                0,
                CitySimulation.regionalCapitalQualificationCycles
                    - analytics.regionalCapitalQualifyingCycles
            )
            return Self(
                title: "Hold every regional standard",
                detail: "All standards are met now. Hold them together for \(remaining) more qualifying days.",
                primaryResponse: inspect(
                    title: "Review city standards",
                    command: .inspectorOverview,
                    explanation: "Review the citywide indicators while the qualification clock advances."
                ),
                secondaryResponses: []
            )
        }

        let concurrent = requirements.dropFirst().map(\.shortfall)
        let detail = concurrent.isEmpty
            ? primary.detail
            : "\(primary.detail) Also below standard: \(concurrent.joined(separator: "; "))."
        return Self(
            title: primary.title,
            detail: detail,
            primaryResponse: primary.primaryResponse,
            secondaryResponses: primary.secondaryResponses
        )
    }

    private struct Requirement {
        let title: String
        let detail: String
        let shortfall: String
        let primaryResponse: CityDirectResponse
        let secondaryResponses: [CityDirectResponse]
    }

    private static func inspect(
        title: String,
        command: CityCommandID,
        explanation: String
    ) -> CityDirectResponse {
        CityDirectResponse(
            title: title,
            command: command,
            explanation: explanation,
            focusesMap: false
        )
    }
}

struct CityBuildOperatingForecast: Equatable, Sendable {
    let currentBalance: Double
    let completedBalance: Double
    let change: Double

    static func make(
        kind: BuildingKind,
        tile: CityTile,
        state: CityGameState
    ) -> Self? {
        let current = CitySimulation.projectedBalance(in: state)
        var completed = state
        guard case .success = CitySimulation.build(kind, at: tile.coordinate, in: &completed) else {
            return nil
        }
        completed.updateTile(at: tile.coordinate) { $0.constructionProgress = 1 }
        completed.jobs = min(
            CitySimulation.jobCapacity(in: completed),
            max(1, completed.population * 7 / 10)
        )
        let projected = CitySimulation.projectedBalance(in: completed)
        return Self(
            currentBalance: current,
            completedBalance: projected,
            change: projected - current
        )
    }
}

struct CityRoadConnectionPlanPresentation: Equatable, Sendable {
    let remainingBlocks: Int
    let constructionCost: Double
    let fundingGap: Double
    let currentBalance: Double
    let completedBalance: Double
    let balanceChange: Double
    let destinationTitle: String
    let projectConstructionCost: Double
    let projectFundingGap: Double
    let projectCompletedBalance: Double
    let usesUnlimitedFunds: Bool

    var headline: String {
        if usesUnlimitedFunds {
            return "\(remainingBlocks) \(blockWord) · cost waived"
        }
        if fundingGap > 0 {
            return "\(remainingBlocks) \(blockWord) · \(constructionCost.currencyText) route · project \(projectFundingGap.currencyText) short"
        }
        return "\(remainingBlocks) \(blockWord) · \(constructionCost.currencyText) route · \(projectConstructionCost.currencyText) project"
    }

    var operatingImpact: String {
        let prefix = usesUnlimitedFunds ? "Tracked net" : "Net"
        return "\(prefix) \(currentBalance.signedCurrencyText) → route "
            + "\(completedBalance.signedCurrencyText) → \(destinationTitle) "
            + "\(projectCompletedBalance.signedCurrencyText) / cycle"
    }

    var buildActionHint: String {
        if fundingGap > 0 {
            return "Needs \(fundingGap.currencyText) more to build all \(remainingBlocks) \(blockWord) without a partial route."
        }
        return "Builds all \(remainingBlocks) \(blockWord) for \(constructionCost.currencyText) as one reversible construction action."
    }

    var accessibilitySummary: String {
        var facts = ["Guided street route plan", "\(remainingBlocks) \(blockWord)"]
        if usesUnlimitedFunds {
            facts.append("Construction spending is waived")
        } else {
            facts.append("Total construction cost \(constructionCost.currencyText)")
            if fundingGap > 0 {
                facts.append("Current funding shortfall \(fundingGap.currencyText)")
            } else {
                facts.append("Currently funded")
            }
        }
        facts.append(
            "Full-route net \(currentBalance.signedCurrencyText) to "
                + "\(completedBalance.signedCurrencyText) per cycle "
                + "(\(balanceChange.signedCurrencyText))"
        )
        if usesUnlimitedFunds {
            facts.append("\(destinationTitle) project construction spending is waived")
        } else {
            facts.append("\(destinationTitle) project total cost \(projectConstructionCost.currencyText)")
            if projectFundingGap > 0 {
                facts.append("Full project funding shortfall \(projectFundingGap.currencyText)")
            } else {
                facts.append("Full project currently funded")
            }
        }
        facts.append("Net after completing \(destinationTitle) \(projectCompletedBalance.signedCurrencyText) per cycle")
        return facts.joined(separator: ". ")
    }

    static func make(
        route: [GridCoordinate],
        destinationKind: BuildingKind,
        destinationCoordinate: GridCoordinate,
        state: CityGameState
    ) -> Self? {
        guard !route.isEmpty else { return nil }
        let constructionCost = Double(route.count) * BuildingKind.road.buildCost
        let projectConstructionCost = constructionCost + destinationKind.buildCost
        let currentBalance = CitySimulation.projectedBalance(in: state)
        var completed = state
        if !state.usesUnlimitedFunds {
            completed.treasury = max(completed.treasury, projectConstructionCost + 1_000_000)
        }
        for coordinate in route {
            guard case .success = CitySimulation.build(.road, at: coordinate, in: &completed) else {
                return nil
            }
            completed.updateTile(at: coordinate) { $0.constructionProgress = 1 }
        }
        let completedBalance = CitySimulation.projectedBalance(in: completed)
        guard case .success = CitySimulation.build(
            destinationKind,
            at: destinationCoordinate,
            in: &completed
        ) else {
            return nil
        }
        completed.updateTile(at: destinationCoordinate) { $0.constructionProgress = 1 }
        completed.jobs = min(
            CitySimulation.jobCapacity(in: completed),
            max(1, completed.population * 7 / 10)
        )
        let projectCompletedBalance = CitySimulation.projectedBalance(in: completed)
        return Self(
            remainingBlocks: route.count,
            constructionCost: constructionCost,
            fundingGap: state.usesUnlimitedFunds
                ? 0
                : max(0, constructionCost - state.treasury),
            currentBalance: currentBalance,
            completedBalance: completedBalance,
            balanceChange: completedBalance - currentBalance,
            destinationTitle: destinationKind.title,
            projectConstructionCost: projectConstructionCost,
            projectFundingGap: state.usesUnlimitedFunds
                ? 0
                : max(0, projectConstructionCost - state.treasury),
            projectCompletedBalance: projectCompletedBalance,
            usesUnlimitedFunds: state.usesUnlimitedFunds
        )
    }

    private var blockWord: String {
        remainingBlocks == 1 ? "block" : "blocks"
    }
}

struct CityRoadPlacementForecast: Equatable, Sendable {
    let adjacentRoadApproaches: Int
    let newlyServedOpenParcels: Int

    var summary: String {
        "\(topologySummary) · \(accessSummary)"
    }

    static func make(
        at coordinate: GridCoordinate,
        in state: CityGameState
    ) -> Self? {
        guard state.tile(at: coordinate)?.kind == .empty else { return nil }
        let neighbors = state.neighbors(of: coordinate)
        let approaches = neighbors.filter { $0.kind == .road }.count
        let newlyServed = neighbors.filter { neighbor in
            guard neighbor.kind == .empty else { return false }
            return !state.neighbors(of: neighbor.coordinate).contains {
                $0.kind == .road
            }
        }.count
        return Self(
            adjacentRoadApproaches: approaches,
            newlyServedOpenParcels: newlyServed
        )
    }

    private var topologySummary: String {
        switch adjacentRoadApproaches {
        case 0: "Separate road segment"
        case 1: "Extends 1 approach"
        case 2: "Connects 2 approaches"
        case 3: "3-way junction"
        default: "4-way junction"
        }
    }

    private var accessSummary: String {
        switch newlyServedOpenParcels {
        case 0: "serves no new open parcel"
        case 1: "serves 1 open parcel"
        default: "serves \(newlyServedOpenParcels) open parcels"
        }
    }
}

struct CityBuildOpportunityInventory: Equatable, Sendable {
    // Build legality remains wholly owned by CitySimulation. This is a
    // presentation-only shortlist centered on the completed city so entering
    // Build mode reveals useful choices without painting the whole road grid.
    static let outlineLimit = 6

    enum DevelopmentStrength: String, CaseIterable, Hashable, Sendable {
        case utility
        case value
        case cleanAir

        var accessibilityTitle: String {
            switch self {
            case .utility: "Strongest utilities"
            case .value: "Highest land value"
            case .cleanAir: "Lowest pollution"
            }
        }
    }

    let totalCount: Int
    let outlinedCoordinates: [GridCoordinate]
    let developmentForecastByCoordinate: [GridCoordinate: CityDevelopmentSiteForecast]
    let developmentStrengthsByCoordinate: [GridCoordinate: Set<DevelopmentStrength>]

    init(
        totalCount: Int,
        outlinedCoordinates: [GridCoordinate],
        developmentForecastByCoordinate: [GridCoordinate: CityDevelopmentSiteForecast] = [:],
        developmentStrengthsByCoordinate: [GridCoordinate: Set<DevelopmentStrength>] = [:]
    ) {
        self.totalCount = totalCount
        self.outlinedCoordinates = outlinedCoordinates
        self.developmentForecastByCoordinate = developmentForecastByCoordinate.filter {
            outlinedCoordinates.contains($0.key)
        }
        self.developmentStrengthsByCoordinate = developmentStrengthsByCoordinate.filter {
            outlinedCoordinates.contains($0.key)
        }
    }

    var titleSuffix: String? {
        guard !outlinedCoordinates.isEmpty else { return nil }
        let representedStrengths = developmentStrengthsByCoordinate.values.reduce(into: Set<DevelopmentStrength>()) {
            $0.formUnion($1)
        }
        if !representedStrengths.isEmpty, outlinedCoordinates.count > 1 {
            return representedStrengths.count == 1
                ? "1 site strength"
                : "\(representedStrengths.count) site strengths"
        }
        if outlinedCoordinates.count == totalCount {
            return outlinedCoordinates.count == 1
                ? "1 site"
                : "\(outlinedCoordinates.count) sites"
        }
        return outlinedCoordinates.count == 1
            ? "1 nearby site"
            : "\(outlinedCoordinates.count) nearby sites"
    }

    var detail: String {
        guard totalCount > 0 else { return "No eligible sites" }
        return outlinedCoordinates.count == totalCount
            ? "All eligible sites outlined"
            : "\(totalCount) eligible"
    }

    var accessibilitySummary: String {
        guard totalCount > 0 else {
            return "No eligible sites are available under current funds and placement rules."
        }
        let strengthSummary = developmentStrengthAccessibilitySummary.map { " \($0)" } ?? ""
        if outlinedCoordinates.count == totalCount {
            let noun = totalCount == 1 ? "site is" : "sites are"
            return "\(totalCount) eligible \(noun) outlined on the map.\(strengthSummary)"
        }
        let noun = outlinedCoordinates.count == 1 ? "site is" : "sites are"
        return "\(outlinedCoordinates.count) nearby eligible \(noun) outlined on the map; \(totalCount) sites are eligible in total.\(strengthSummary)"
    }

    var developmentStrengthAccessibilitySummary: String? {
        let highlights = DevelopmentStrength.allCases.compactMap {
            strength -> String? in
            guard let coordinate = outlinedCoordinates.first(where: {
                developmentStrengthsByCoordinate[$0]?.contains(strength) == true
            }), let forecast = developmentForecastByCoordinate[coordinate] else {
                return nil
            }
            let block = "Block \(coordinate.x + 1), \(coordinate.y + 1)"
            let fact = switch strength {
            case .utility:
                "\(Int((forecast.utilityService * 100).rounded())) percent utility service"
            case .value:
                "land value \(Int((forecast.landValueIndex * 100).rounded()))"
            case .cleanAir:
                "pollution \(Int((forecast.pollutionExposure * 100).rounded()))"
            }
            return "\(strength.accessibilityTitle): \(block), \(fact)"
        }
        guard !highlights.isEmpty else {
            return nil
        }
        return "Highlighted markers expose separate site strengths rather than one recommendation. "
            + highlights.joined(separator: ". ") + "."
    }

    var visibleStrengthLegend: String? {
        let legendOrder: [DevelopmentStrength] = [.value, .utility, .cleanAir]
        let represented = developmentStrengthsByCoordinate.values.reduce(into: Set<DevelopmentStrength>()) {
            $0.formUnion($1)
        }
        let entries = legendOrder.compactMap { strength -> String? in
            guard represented.contains(strength) else { return nil }
            return switch strength {
            case .value: "◆ Value"
            case .utility: "•• Util"
            case .cleanAir: "○ Air"
            }
        }
        return entries.isEmpty ? nil : entries.joined(separator: " · ")
    }

    static func make(
        kind: BuildingKind,
        in state: CityGameState,
        outlineLimit: Int = Self.outlineLimit
    ) -> Self? {
        guard kind != .road else { return nil }
        let eligible = CitySimulation.buildableCoordinates(for: kind, in: state)
        guard !eligible.isEmpty else {
            return Self(totalCount: 0, outlinedCoordinates: [])
        }

        let completedPlaces = state.tiles.filter {
            $0.kind != .empty
                && $0.kind != .road
                && $0.constructionProgress >= 1
        }
        let centerX: Double
        let centerY: Double
        if completedPlaces.isEmpty {
            centerX = Double(max(0, state.gridWidth - 1)) / 2
            centerY = Double(max(0, state.gridHeight - 1)) / 2
        } else {
            centerX = completedPlaces.map { Double($0.coordinate.x) }.reduce(0, +)
                / Double(completedPlaces.count)
            centerY = completedPlaces.map { Double($0.coordinate.y) }.reduce(0, +)
                / Double(completedPlaces.count)
        }

        let outlined = eligible.sorted { lhs, rhs in
            let lhsX = Double(lhs.x) - centerX
            let lhsY = Double(lhs.y) - centerY
            let rhsX = Double(rhs.x) - centerX
            let rhsY = Double(rhs.y) - centerY
            let lhsDistance = lhsX * lhsX + lhsY * lhsY
            let rhsDistance = rhsX * rhsX + rhsY * rhsY
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            if lhs.y != rhs.y { return lhs.y < rhs.y }
            return lhs.x < rhs.x
        }
        .prefix(max(0, outlineLimit))

        let outlinedCoordinates = Array(outlined)
        let forecasts = Dictionary(uniqueKeysWithValues: outlinedCoordinates.compactMap {
            coordinate -> (GridCoordinate, CityDevelopmentSiteForecast)? in
            guard let forecast = CityDevelopmentSiteForecast.make(
                kind: kind,
                at: coordinate,
                in: state
            ) else { return nil }
            return (coordinate, forecast)
        })
        var strengths: [GridCoordinate: Set<DevelopmentStrength>] = [:]
        if forecasts.count == outlinedCoordinates.count, outlinedCoordinates.count > 1 {
            let utilityValues = forecasts.values.map(\.utilityService)
            let valueValues = forecasts.values.map(\.landValueIndex)
            let pollutionValues = forecasts.values.map(\.pollutionExposure)

            func markLeader(
                _ strength: DevelopmentStrength,
                values: [Double],
                prefers: (Double, Double) -> Bool
            ) {
                guard let minimum = values.min(), let maximum = values.max(),
                      maximum - minimum > 0.005 else { return }
                var leader: GridCoordinate?
                for coordinate in outlinedCoordinates where forecasts[coordinate] != nil {
                    guard let current = leader else {
                        leader = coordinate
                        continue
                    }
                    let candidate = forecasts[coordinate].map {
                        switch strength {
                        case .utility: $0.utilityService
                        case .value: $0.landValueIndex
                        case .cleanAir: $0.pollutionExposure
                        }
                    } ?? 0
                    let incumbent = forecasts[current].map {
                        switch strength {
                        case .utility: $0.utilityService
                        case .value: $0.landValueIndex
                        case .cleanAir: $0.pollutionExposure
                        }
                    } ?? 0
                    if prefers(candidate, incumbent) { leader = coordinate }
                }
                if let leader { strengths[leader, default: []].insert(strength) }
            }

            markLeader(.utility, values: utilityValues, prefers: >)
            markLeader(.value, values: valueValues, prefers: >)
            markLeader(.cleanAir, values: pollutionValues, prefers: <)
        }

        return Self(
            totalCount: eligible.count,
            outlinedCoordinates: outlinedCoordinates,
            developmentForecastByCoordinate: forecasts,
            developmentStrengthsByCoordinate: strengths
        )
    }
}

struct CityDevelopmentSiteForecast: Equatable, Sendable {
    let capacity: String
    let landValueIndex: Double
    let utilityService: Double
    let pollutionExposure: Double

    var summary: String {
        "\(capacity) · value \(Self.points(landValueIndex)) · utility \(Self.points(utilityService))% · pollution \(Self.points(pollutionExposure))%"
    }

    static func make(
        kind: BuildingKind,
        at coordinate: GridCoordinate,
        in state: CityGameState
    ) -> Self? {
        guard [.residential, .commercial, .industrial].contains(kind),
              state.tile(at: coordinate)?.kind == .empty else {
            return nil
        }

        var completed = state
        if !completed.usesUnlimitedFunds {
            completed.treasury = max(completed.treasury, kind.buildCost)
        }
        guard case .success = CitySimulation.build(kind, at: coordinate, in: &completed) else {
            return nil
        }
        completed.updateTile(at: coordinate) {
            $0.constructionProgress = 1
            $0.condition = 1
        }
        guard let sample = CitySpatialConsequenceMap(state: completed)[coordinate],
              let landValueIndex = sample.landValueIndex else {
            return nil
        }
        return Self(
            capacity: Self.capacity(for: kind),
            landValueIndex: landValueIndex,
            utilityService: sample.utility.combined,
            pollutionExposure: sample.pollutionExposure
        )
    }

    private static func capacity(for kind: BuildingKind) -> String {
        switch kind {
        case .residential:
            "280 homes"
        case .commercial:
            "\(CitySimulation.commercialJobCapacity) jobs"
        case .industrial:
            "\(CitySimulation.industrialJobCapacity) jobs"
        default:
            "No development capacity"
        }
    }

    private static func points(_ value: Double) -> Int {
        Int((value * 100).rounded())
    }
}

struct CityDevelopmentSiteReference: Equatable, Sendable {
    let kind: BuildingKind
    let coordinate: GridCoordinate
}

struct CityDevelopmentSiteComparisonPresentation: Equatable, Sendable {
    let referenceTarget: String
    let referenceAbbreviation: String
    let capacity: String
    let currentLandValue: Int
    let currentUtilityService: Int
    let currentPollutionExposure: Int
    let landValueDelta: Int
    let utilityServiceDelta: Int
    let pollutionExposureDelta: Int

    var accessibilitySummary: String {
        "Compared with \(referenceTarget): land value \(Self.changeDescription(landValueDelta)); "
            + "utility \(Self.changeDescription(utilityServiceDelta)); "
            + "pollution \(Self.changeDescription(pollutionExposureDelta))"
    }

    var landValueDeltaText: String { Self.signed(landValueDelta) }
    var utilityServiceDeltaText: String { Self.signed(utilityServiceDelta) }
    var pollutionExposureDeltaText: String { Self.signed(pollutionExposureDelta) }

    static func make(
        kind: BuildingKind,
        coordinate: GridCoordinate,
        currentForecast: CityDevelopmentSiteForecast?,
        reference: CityDevelopmentSiteReference?,
        state: CityGameState
    ) -> Self? {
        guard let currentForecast,
              let reference,
              reference.kind == kind,
              reference.coordinate != coordinate,
              let referenceForecast = CityDevelopmentSiteForecast.make(
                  kind: kind,
                  at: reference.coordinate,
                  in: state
              ) else {
            return nil
        }

        return Self(
            referenceTarget: "Block \(reference.coordinate.x + 1), \(reference.coordinate.y + 1)",
            referenceAbbreviation: "B\(reference.coordinate.x + 1),\(reference.coordinate.y + 1)",
            capacity: currentForecast.capacity,
            currentLandValue: points(currentForecast.landValueIndex),
            currentUtilityService: points(currentForecast.utilityService),
            currentPollutionExposure: points(currentForecast.pollutionExposure),
            landValueDelta: points(currentForecast.landValueIndex - referenceForecast.landValueIndex),
            utilityServiceDelta: points(currentForecast.utilityService - referenceForecast.utilityService),
            pollutionExposureDelta: points(currentForecast.pollutionExposure - referenceForecast.pollutionExposure)
        )
    }

    private static func points(_ value: Double) -> Int {
        Int((value * 100).rounded())
    }

    private static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private static func changeDescription(_ value: Int) -> String {
        if value > 0 { return "\(value) points higher" }
        if value < 0 { return "\(-value) points lower" }
        return "unchanged"
    }
}

struct CityParkPlacementForecast: Equatable, Sendable {
    let benefitedDevelopedBlocks: Int
    let pollutionRelievedBlocks: Int
    let greatestPollutionReduction: Double

    var summary: String {
        guard benefitedDevelopedBlocks > 0 else {
            return "No additional local benefit at this site"
        }
        let blockLabel = benefitedDevelopedBlocks == 1 ? "block" : "blocks"
        guard pollutionRelievedBlocks > 0 else {
            return "Benefits \(benefitedDevelopedBlocks) \(blockLabel) · local value or happiness rises"
        }
        let pointValue = greatestPollutionReduction * 100
        let reduction = pointValue < 1
            ? "under 1 pt"
            : "\(Int(pointValue.rounded())) pts"
        return "Benefits \(benefitedDevelopedBlocks) \(blockLabel) · pollution up to \(reduction) lower"
    }

    static func make(
        at coordinate: GridCoordinate,
        in state: CityGameState
    ) -> Self? {
        guard state.tile(at: coordinate)?.kind == .empty else { return nil }

        var completed = state
        if !completed.usesUnlimitedFunds {
            completed.treasury = max(completed.treasury, BuildingKind.park.buildCost)
        }
        guard case .success = CitySimulation.build(.park, at: coordinate, in: &completed) else {
            return nil
        }
        completed.updateTile(at: coordinate) { $0.constructionProgress = 1 }

        let currentConsequences = CitySpatialConsequenceMap(state: state)
        let completedConsequences = CitySpatialConsequenceMap(state: completed)
        var benefitedBlocks = 0
        var relievedBlocks = 0
        var greatestReduction = 0.0
        let threshold = 0.000_000_001

        for current in currentConsequences.samples where current.vitality != .notApplicable {
            guard let projected = completedConsequences[current.coordinate] else { continue }
            let pollutionReduction = current.pollutionExposure - projected.pollutionExposure
            let landValueGain = (projected.landValueIndex ?? 0) - (current.landValueIndex ?? 0)
            let happinessGain = (projected.localHappinessIndex ?? 0) - (current.localHappinessIndex ?? 0)
            let vitalityGain = projected.vitalityScore - current.vitalityScore
            guard pollutionReduction > threshold
                    || landValueGain > threshold
                    || happinessGain > threshold
                    || vitalityGain > threshold else {
                continue
            }
            benefitedBlocks += 1
            if pollutionReduction > threshold {
                relievedBlocks += 1
                greatestReduction = max(greatestReduction, pollutionReduction)
            }
        }

        return Self(
            benefitedDevelopedBlocks: benefitedBlocks,
            pollutionRelievedBlocks: relievedBlocks,
            greatestPollutionReduction: greatestReduction
        )
    }
}

struct CityUtilityPlacementForecast: Equatable, Sendable {
    let kind: BuildingKind
    let improvedDevelopedBlocks: Int
    let restoredHealthyBlocks: Int
    let greatestServiceGain: Double
    var pollutionImpact: CityPlacementPollutionImpact? = nil

    var summary: String {
        let service = kind == .powerPlant ? "Power" : "Water"
        guard improvedDevelopedBlocks > 0 else {
            return "No current block gains \(service.lowercased()) service here"
        }
        let blockChange = improvedDevelopedBlocks == 1
            ? "1 block improves"
            : "\(improvedDevelopedBlocks) blocks improve"
        if restoredHealthyBlocks > 0 {
            let recovery = restoredHealthyBlocks == 1
                ? "1 reaches healthy"
                : "\(restoredHealthyBlocks) reach healthy"
            return "\(service): \(blockChange) · \(recovery)"
        }
        let gainPoints = greatestServiceGain * 100
        let gain = gainPoints < 1
            ? "under +1 pt"
            : "+\(Int(gainPoints.rounded())) pts"
        return "\(service): \(blockChange) · best \(gain)"
    }

    static func make(
        kind: BuildingKind,
        at coordinate: GridCoordinate,
        in state: CityGameState
    ) -> Self? {
        guard kind == .powerPlant || kind == .waterTower,
              state.tile(at: coordinate)?.kind == .empty else {
            return nil
        }

        var completed = state
        if !completed.usesUnlimitedFunds {
            completed.treasury = max(completed.treasury, kind.buildCost)
        }
        guard case .success = CitySimulation.build(kind, at: coordinate, in: &completed) else {
            return nil
        }
        completed.updateTile(at: coordinate) { $0.constructionProgress = 1 }
        let active = CitySimulation.activeTiles(in: completed)
        completed.powerCapacity = active.filter { $0.kind == .powerPlant }.count
            * CitySimulation.powerCapacityPerPlant
        completed.waterCapacity = active.filter { $0.kind == .waterTower }.count
            * CitySimulation.waterCapacityPerTower

        let currentConsequences = CitySpatialConsequenceMap(state: state)
        let completedConsequences = CitySpatialConsequenceMap(state: completed)
        var improvedBlocks = 0
        var healthyRecoveries = 0
        var greatestGain = 0.0
        var pollutedBlocks = 0
        var pollutedHomes = 0
        var greatestPollutionIncrease = 0.0
        let threshold = 0.000_000_001

        for current in currentConsequences.samples where current.vitality != .notApplicable {
            guard let projected = completedConsequences[current.coordinate] else { continue }
            // Count harms independently: a block can gain pollution even when
            // its power service was already healthy and cannot improve further.
            let pollutionIncrease = projected.pollutionExposure - current.pollutionExposure
            if kind == .powerPlant, pollutionIncrease > threshold {
                pollutedBlocks += 1
                if state.tile(at: current.coordinate)?.kind == .residential { pollutedHomes += 1 }
                greatestPollutionIncrease = max(greatestPollutionIncrease, pollutionIncrease)
            }
            let currentService = kind == .powerPlant
                ? current.utility.power
                : current.utility.water
            let projectedService = kind == .powerPlant
                ? projected.utility.power
                : projected.utility.water
            let currentBand = kind == .powerPlant
                ? current.utility.powerBand
                : current.utility.waterBand
            let projectedBand = kind == .powerPlant
                ? projected.utility.powerBand
                : projected.utility.waterBand
            let gain = projectedService - currentService
            guard gain > threshold else { continue }
            improvedBlocks += 1
            greatestGain = max(greatestGain, gain)
            if currentBand != .healthy, projectedBand == .healthy {
                healthyRecoveries += 1
            }
        }

        return Self(
            kind: kind,
            improvedDevelopedBlocks: improvedBlocks,
            restoredHealthyBlocks: healthyRecoveries,
            greatestServiceGain: greatestGain,
            pollutionImpact: kind == .powerPlant ? CityPlacementPollutionImpact(
                affectedBlocks: pollutedBlocks,
                affectedHomes: pollutedHomes,
                greatestIncrease: greatestPollutionIncrease
            ) : nil
        )
    }
}

struct CityCivicServicePlacementForecast: Equatable, Sendable {
    let kind: BuildingKind
    let outcomeCoverageGain: Double
    let stormDamageReduction: Double
    let residentialDemandGain: Double
    let commercialDemandGain: Double

    var summary: String {
        let reach = "\(outcomeTitle) reach +\(Self.points(outcomeCoverageGain * 100))"
        return switch kind {
        case .fireStation where stormDamageReduction > 0.000_000_001:
            "\(reach) · storm damage -\(Self.points(stormDamageReduction * 100))"
        case .policeStation where commercialDemandGain > 0.000_000_001:
            "\(reach) · Commercial demand +\(Self.points(commercialDemandGain * 100))"
        case .school where residentialDemandGain > 0.000_000_001:
            "\(reach) · Residential demand +\(Self.points(residentialDemandGain * 100))"
        default:
            "No additional \(outcomeTitle.lowercased()) outcome at this site"
        }
    }

    private var outcomeTitle: String {
        switch kind {
        case .fireStation: "Fire"
        case .policeStation: "Police"
        case .school: "School"
        default: "Service"
        }
    }

    static func make(
        kind: BuildingKind,
        at coordinate: GridCoordinate,
        in state: CityGameState
    ) -> Self? {
        guard [.fireStation, .policeStation, .school].contains(kind),
              state.tile(at: coordinate)?.kind == .empty else {
            return nil
        }

        var completed = state
        if !completed.usesUnlimitedFunds {
            completed.treasury = max(completed.treasury, kind.buildCost)
        }
        guard case .success = CitySimulation.build(kind, at: coordinate, in: &completed) else {
            return nil
        }
        completed.updateTile(at: coordinate) { $0.constructionProgress = 1 }

        let currentServices = CityCivicServiceAnalysis(state: state)
        let projectedServices = CityCivicServiceAnalysis(state: completed)
        let currentCoverage = currentServices.outcomeCoverage(for: kind) ?? 0
        let projectedCoverage = projectedServices.outcomeCoverage(for: kind) ?? 0
        let currentStormDamage = CitySimulation.stormProtection(in: state).estimatedConditionDamage
        let projectedStormDamage = CitySimulation.stormProtection(in: completed).estimatedConditionDamage
        return Self(
            kind: kind,
            outcomeCoverageGain: max(0, projectedCoverage - currentCoverage),
            stormDamageReduction: kind == .fireStation
                ? max(0, currentStormDamage - projectedStormDamage)
                : 0,
            residentialDemandGain: kind == .school
                && !state.preservesLegacyReplayConsequences
                ? max(
                    0,
                    (projectedServices.citywideResidentialSchoolCoverage - currentServices.citywideResidentialSchoolCoverage)
                        * CitySimulation.maximumSchoolResidentialDemandBonus
                )
                : 0,
            commercialDemandGain: kind == .policeStation
                && !state.preservesLegacyReplayConsequences
                ? max(
                    0,
                    (projectedServices.citywideCommercialPoliceCoverage - currentServices.citywideCommercialPoliceCoverage)
                        * CitySimulation.maximumPoliceCommercialDemandBonus
                )
                : 0
        )
    }

    private static func points(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.000_001 {
            return "\(Int(rounded)) pts"
        }
        return "\(String(format: "%.1f", value)) pts"
    }
}

struct CityDemolitionForecast: Equatable, Sendable {
    let currentBalance: Double
    let projectedBalance: Double
    let balanceChange: Double
    let capacityImpact: String

    var summary: String {
        "Net \(currentBalance.signedCurrencyText) → \(projectedBalance.signedCurrencyText) / cycle "
            + "(\(balanceChange.signedCurrencyText)) · \(capacityImpact)"
    }

    static func make(tile: CityTile, state: CityGameState) -> Self? {
        guard tile.kind != .empty, tile.kind != .cityHall else { return nil }
        let currentBalance = CitySimulation.projectedBalance(in: state)
        let housingBefore = CitySimulation.housingCapacity(in: state)
        let jobsBefore = CitySimulation.jobCapacity(in: state)
        let powerBefore = state.powerCapacity
        let waterBefore = state.waterCapacity
        var projected = state
        guard CitySimulation.demolish(at: tile.coordinate, in: &projected) else { return nil }
        let active = CitySimulation.activeTiles(in: projected)
        projected.powerCapacity = active.filter { $0.kind == .powerPlant }.count
            * CitySimulation.powerCapacityPerPlant
        projected.waterCapacity = active.filter { $0.kind == .waterTower }.count
            * CitySimulation.waterCapacityPerTower
        projected.jobs = min(
            CitySimulation.jobCapacity(in: projected),
            max(1, projected.population * 7 / 10)
        )
        let completedBalance = CitySimulation.projectedBalance(in: projected)
        let impact: String = switch tile.kind {
        case .residential:
            "Housing \(housingBefore.formatted()) → \(CitySimulation.housingCapacity(in: projected).formatted())"
        case .commercial, .industrial:
            "Jobs \(jobsBefore.formatted()) → \(CitySimulation.jobCapacity(in: projected).formatted())"
        case .powerPlant:
            "Power \(powerBefore.formatted()) → \(projected.powerCapacity.formatted())"
        case .waterTower:
            "Water \(waterBefore.formatted()) → \(projected.waterCapacity.formatted())"
        case .road:
            "Road access may change for adjacent blocks"
        case .park:
            "Removes park livability and storm protection"
        case .fireStation:
            "Removes fire reach and storm protection"
        case .policeStation:
            "Removes police reach and Commercial demand support"
        case .school:
            "Removes school reach and Residential demand support"
        case .empty, .cityHall:
            "No removable capacity"
        }
        return Self(
            currentBalance: currentBalance,
            projectedBalance: completedBalance,
            balanceChange: completedBalance - currentBalance,
            capacityImpact: impact
        )
    }
}

struct CityBuildDecisionPresentation: Equatable, Sendable {
    let buildingTitle: String
    let buildingSymbol: String
    let target: String
    let footprint: String
    let cost: String
    let operatingImpact: String
    let operatingForecast: CityBuildOperatingForecast?
    let siteComparison: CityDevelopmentSiteComparisonPresentation?
    let availability: String
    let disabledReason: String?
    let likelyConsequence: String
    let pollutionImpact: CityPlacementPollutionImpact?
    let cancellation: String
    let recovery: CityDirectResponse?

    var accessibilitySummary: String {
        [
            "\(buildingTitle) placement",
            "Target \(target)",
            "Footprint \(footprint)",
            cost,
            operatingImpact,
            siteComparison?.accessibilitySummary,
            availability,
            disabledReason,
            "Likely consequence: \(likelyConsequence)",
            pollutionImpact?.accessibilitySummary,
            cancellation,
            recovery.map { "Recovery: \($0.title). \($0.explanation)" },
        ]
        .compactMap { $0 }
        .joined(separator: ". ")
    }

    static func make(
        kind: BuildingKind,
        tile: CityTile,
        rejection: BuildRejection?,
        state: CityGameState,
        unlimitedFunds: Bool = false,
        siteComparisonReference: CityDevelopmentSiteReference? = nil
    ) -> CityBuildDecisionPresentation {
        let cost = unlimitedFunds
            ? "Cost waived · \(kind == .road ? "online now" : "online in 4 ticks")"
            : "Cost \(kind.buildCost.currencyText) · \(kind == .road ? "online now" : "online in 4 ticks")"
        let forecast = rejection == nil
            ? CityBuildOperatingForecast.make(kind: kind, tile: tile, state: state)
            : nil
        let developmentForecast = rejection == nil
            ? CityDevelopmentSiteForecast.make(kind: kind, at: tile.coordinate, in: state)
            : nil
        let utilityForecast = CityUtilityPlacementForecast.make(kind: kind, at: tile.coordinate, in: state)
        return CityBuildDecisionPresentation(
            buildingTitle: kind.title,
            buildingSymbol: kind.symbol,
            target: "Block \(tile.coordinate.x + 1), \(tile.coordinate.y + 1)",
            footprint: "1 × 1 block",
            cost: cost,
            operatingImpact: operatingImpact(forecast: forecast, unlimitedFunds: unlimitedFunds),
            operatingForecast: forecast,
            siteComparison: CityDevelopmentSiteComparisonPresentation.make(
                kind: kind,
                coordinate: tile.coordinate,
                currentForecast: developmentForecast,
                reference: siteComparisonReference,
                state: state
            ),
            availability: rejection == nil ? "Ready to build" : "Blocked",
            disabledReason: rejection?.message,
            likelyConsequence: likelyConsequence(
                kind: kind,
                tile: tile,
                state: state,
                developmentForecast: developmentForecast,
                utilityForecast: utilityForecast
            ),
            pollutionImpact: utilityForecast?.pollutionImpact,
            cancellation: "Escape cancels without changing the city",
            recovery: rejection?.buildRecovery
        )
    }

    private static func operatingImpact(
        forecast: CityBuildOperatingForecast?,
        unlimitedFunds: Bool
    ) -> String {
        guard let forecast else { return "Net forecast available when ready" }
        let prefix = unlimitedFunds ? "Tracked net" : "Net on completion"
        return "\(prefix) \(forecast.currentBalance.signedCurrencyText) → "
            + "\(forecast.completedBalance.signedCurrencyText) / cycle "
            + "(\(forecast.change.signedCurrencyText))"
    }

    private static func likelyConsequence(
        kind: BuildingKind,
        tile: CityTile,
        state: CityGameState,
        developmentForecast: CityDevelopmentSiteForecast?,
        utilityForecast: CityUtilityPlacementForecast?
    ) -> String {
        switch kind {
        case .residential, .commercial, .industrial:
            developmentForecast?.summary ?? kind.buildConsequenceSummary
        case .road:
            CityRoadPlacementForecast.make(at: tile.coordinate, in: state)?.summary
                ?? "Clear this occupied block before the road network can change"
        case .park:
            CityParkPlacementForecast.make(at: tile.coordinate, in: state)?.summary
                ?? kind.buildConsequenceSummary
        case .powerPlant, .waterTower:
            utilityForecast?.summary ?? kind.buildConsequenceSummary
        case .fireStation, .policeStation, .school:
            CityCivicServicePlacementForecast.make(
                kind: kind,
                at: tile.coordinate,
                in: state
            )?.summary ?? kind.buildConsequenceSummary
        default:
            kind.buildConsequenceSummary
        }
    }
}

struct CityMapPrimaryActionPresentation: Equatable, Sendable {
    let name: String
    let disclosure: String
    let isAvailable: Bool
    let buildDecision: CityBuildDecisionPresentation?

    init(
        name: String,
        disclosure: String,
        isAvailable: Bool,
        buildDecision: CityBuildDecisionPresentation? = nil
    ) {
        self.name = name
        self.disclosure = disclosure
        self.isAvailable = isAvailable
        self.buildDecision = buildDecision
    }

    static func make(
        interactionMode: CityInteractionMode,
        tile: CityTile,
        state: CityGameState,
        siteComparisonReference: CityDevelopmentSiteReference? = nil
    ) -> CityMapPrimaryActionPresentation {
        let block = "block \(tile.coordinate.x + 1), \(tile.coordinate.y + 1)"
        switch interactionMode {
        case .inspect:
            return .init(
                name: "Inspect \(tile.kind.title) at \(block)",
                disclosure: "Available. Opens details for the selected target.",
                isAvailable: true
            )
        case .build(let kind):
            switch CitySimulation.validateBuild(kind, at: tile.coordinate, in: state) {
            case .success:
                let disclosure = state.usesUnlimitedFunds
                    ? "Available. Sandbox funds waive spending; the tracked operating forecast is shown before placement."
                    : "Available. Costs \(kind.buildCost.currencyText); the operating forecast is shown before placement."
                return .init(
                    name: "Build \(kind.title) at \(block)",
                    disclosure: disclosure,
                    isAvailable: true,
                    buildDecision: .make(
                        kind: kind,
                        tile: tile,
                        rejection: nil,
                        state: state,
                        unlimitedFunds: state.usesUnlimitedFunds,
                        siteComparisonReference: siteComparisonReference
                    )
                )
            case .failure(let rejection):
                return .init(
                    name: "Build \(kind.title) at \(block)",
                    disclosure: "Unavailable. \(rejection.message)",
                    isAvailable: false,
                    buildDecision: .make(
                        kind: kind,
                        tile: tile,
                        rejection: rejection,
                        state: state,
                        unlimitedFunds: state.usesUnlimitedFunds,
                        siteComparisonReference: siteComparisonReference
                    )
                )
            }
        case .bulldoze:
            if tile.kind == .cityHall {
                return .init(
                    name: "Demolish City Hall at \(block)",
                    disclosure: "Unavailable. City Hall is a protected landmark.",
                    isAvailable: false
                )
            }
            if tile.kind == .empty {
                return .init(
                    name: "Demolish Open Land at \(block)",
                    disclosure: "Unavailable. There is nothing to demolish.",
                    isAvailable: false
                )
            }
            let demolitionName = state.usesUnlimitedFunds
                ? "Demolish \(tile.kind.title) at \(block)"
                : "Demolish \(tile.kind.title) at \(block) for \(tile.kind.demolitionCost.currencyText)"
            let forecast = CityDemolitionForecast.make(tile: tile, state: state)
            let demolitionDisclosure = state.usesUnlimitedFunds
                ? "Available. Demolition spending is waived. \(forecast?.summary ?? "Impact unavailable"). Undo is available after activation."
                : "Available. Demolition costs \(tile.kind.demolitionCost.currencyText). \(forecast?.summary ?? "Impact unavailable"). Undo is available after activation."
            return .init(
                name: demolitionName,
                disclosure: demolitionDisclosure,
                isAvailable: true
            )
        }
    }
}

struct CityMapActionTargetPresentation: Equatable, Sendable {
    let coordinate: GridCoordinate
    let primaryAction: CityMapPrimaryActionPresentation
}

struct CitySelectedLocationConditions: Equatable, Sendable {
    let coordinate: GridCoordinate
    let landValueIndex: Int
    let utilityService: Int
    let civicServiceCoverage: Int
    let commuteAccess: Int?
    let pollutionExposure: Int
    let trafficExposure: Int
    let vitalityScore: Int
    let vitality: String

    var accessibilitySummary: String {
        "Block \(coordinate.x + 1), \(coordinate.y + 1). Local conditions: "
            + "land value \(landValueIndex), utilities \(utilityService) percent, "
            + "civic service coverage \(civicServiceCoverage) percent, "
            + (commuteAccess.map { "commute access \($0) percent, " } ?? "")
            + "traffic exposure \(trafficExposure) percent, pollution \(pollutionExposure) percent, "
            + "vitality \(vitality), \(vitalityScore) percent."
    }

    static func make(
        tile: CityTile,
        snapshot: CityPresentationSnapshot
    ) -> CitySelectedLocationConditions? {
        guard tile.kind != .empty, tile.kind != .road, tile.constructionProgress >= 1,
              let sample = snapshot.spatialConsequences[tile.coordinate],
              let landValueIndex = sample.landValueIndex,
              let trafficExposure = sample.trafficExposure,
              let civicService = sample.civicService,
              sample.vitality != .notApplicable else { return nil }

        return CitySelectedLocationConditions(
            coordinate: tile.coordinate,
            landValueIndex: points(landValueIndex),
            utilityService: points(sample.utility.combined),
            civicServiceCoverage: points(civicService.combined),
            commuteAccess: CityTrafficAnalysis(state: snapshot.state)
                .place(at: tile.coordinate)?.commute.map { points($0.access) },
            pollutionExposure: points(sample.pollutionExposure),
            trafficExposure: points(trafficExposure),
            vitalityScore: points(sample.vitalityScore),
            vitality: sample.vitality.title
        )
    }

    private static func points(_ value: Double) -> Int {
        Int((min(max(value, 0), 1) * 100).rounded())
    }
}

struct CityDevelopmentOutlook: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case ready
        case held
        case building
        case mature
    }

    let status: Status
    let statusLabel: String
    let detail: String
    let payoff: String
    let accessibilitySummary: String

    static func make(tile: CityTile, state: CityGameState) -> CityDevelopmentOutlook? {
        guard [.residential, .commercial, .industrial].contains(tile.kind) else { return nil }
        let evaluation = CitySimulation.developmentUpgradeEvaluation(for: tile, in: state)
        let capacityName = tile.kind == .residential ? "resident capacity" : "job capacity"
        let visibleCapacityName = tile.kind == .residential ? "residents" : "jobs"

        if evaluation.blockers == [.maximumLevel] {
            let detail = "Level \(evaluation.currentLevel) is the \(tile.kind.title) cap"
            let payoff = "\(evaluation.currentCapacity.formatted()) \(capacityName)"
            return CityDevelopmentOutlook(
                status: .mature,
                statusLabel: "Mature",
                detail: detail,
                payoff: payoff,
                accessibilitySummary: "Growth mature. \(detail). \(payoff)."
            )
        }

        if case let .construction(progress) = evaluation.blockers.first {
            let detail = "Construction \((progress * 100).percentText) complete"
            let payoff = "Level \(evaluation.currentLevel) · \(evaluation.currentCapacity.formatted()) \(capacityName)"
            return CityDevelopmentOutlook(
                status: .building,
                statusLabel: "Building",
                detail: detail,
                payoff: payoff,
                accessibilitySummary: "Growth building. \(detail). \(payoff)."
            )
        }

        let payoff = "L\(evaluation.currentLevel) → L\(evaluation.currentLevel + 1) · "
            + "\(evaluation.currentCapacity.formatted()) → \(evaluation.nextCapacity.formatted()) \(visibleCapacityName)"
        let accessibilityPayoff = "Level \(evaluation.currentLevel) to level \(evaluation.currentLevel + 1) "
            + "would raise \(capacityName) from \(evaluation.currentCapacity.formatted()) "
            + "to \(evaluation.nextCapacity.formatted())"
        if evaluation.isEligible {
            return CityDevelopmentOutlook(
                status: .ready,
                statusLabel: "Ready for review",
                detail: "All upgrade gates met",
                payoff: payoff,
                accessibilitySummary: "Growth ready for review. All upgrade gates are met. \(accessibilityPayoff)."
            )
        }

        let blockerDetails = evaluation.blockers.map(blockerDetail)
        let primary = evaluation.blockers.first.map(blockerVisibleDetail)
            ?? "Upgrade requirements are not met"
        let remaining = max(0, blockerDetails.count - 1)
        let detail = remaining == 0
            ? primary
            : "\(primary) · +\(remaining) \(remaining == 1 ? "gate" : "gates")"
        return CityDevelopmentOutlook(
            status: .held,
            statusLabel: "Held",
            detail: detail,
            payoff: payoff,
            accessibilitySummary: "Growth held. \(accessibilityPayoff). Requirements not met: \(blockerDetails.joined(separator: "; "))."
        )
    }

    private static func blockerVisibleDetail(_ blocker: CityDevelopmentUpgradeBlocker) -> String {
        switch blocker {
        case .unsupported:
            "Does not develop"
        case .maximumLevel:
            "Maximum level"
        case let .construction(progress):
            "Building \((progress * 100).percentText)"
        case let .operatingBalance(current):
            "Balance \(current.signedCurrencyText)"
        case let .utilityCoverage(current):
            "Utilities \((current * 100).percentText)"
        case let .treasury(current):
            "Treasury \(current.currencyText)"
        case .townCharterReview:
            "Charter review active"
        case .regionalReview:
            "Regional review active"
        case let .strategyPriority(kind):
            "\(kind.title) priority"
        case let .condition(current, required):
            "Condition \((current * 100).percentText) / \((required * 100).percentText)"
        case let .happiness(current, required):
            "Happiness \(current.percentText) / \(required.percentText)"
        case let .demand(current, required):
            "Demand \((current * 100).percentText) / \((required * 100).percentText)"
        case let .developmentCashflow(projected):
            "Upgrade net \(projected.signedCurrencyText)"
        case .progressionUtilityReserve:
            "Utility reserve low"
        case let .utilization(current, required):
            "Occupancy \((current * 100).percentText) / \((required * 100).percentText)"
        }
    }

    private static func blockerDetail(_ blocker: CityDevelopmentUpgradeBlocker) -> String {
        switch blocker {
        case .unsupported:
            "This block does not develop"
        case .maximumLevel:
            "Maximum level reached"
        case let .construction(progress):
            "Construction \((progress * 100).percentText) complete"
        case let .operatingBalance(current):
            "Balance \(current.signedCurrencyText) / cycle needs $0"
        case let .utilityCoverage(current):
            "Utilities \((current * 100).percentText) need 100%"
        case let .treasury(current):
            "Treasury \(current.currencyText) needs $5,000"
        case .townCharterReview:
            "Town Charter review is active"
        case .regionalReview:
            "Regional qualification review is active"
        case let .strategyPriority(kind):
            "City strategy prioritizes \(kind.title) upgrades"
        case let .condition(current, required):
            "Condition \((current * 100).percentText) needs \((required * 100).percentText)"
        case let .happiness(current, required):
            "Happiness \(current.percentText) needs \(required.percentText)"
        case let .demand(current, required):
            "Demand \((current * 100).percentText) needs \((required * 100).percentText)"
        case let .developmentCashflow(projected):
            "Upgrade upkeep would leave \(projected.signedCurrencyText) / cycle"
        case .progressionUtilityReserve:
            "Planned utility reserve is too low"
        case let .utilization(current, required):
            "Occupancy \((current * 100).percentText) needs \((required * 100).percentText)"
        }
    }
}

struct CityDevelopmentPipeline: Equatable, Sendable {
    private enum Gate: CaseIterable, Hashable {
        case finances
        case utilities
        case review
        case strategy
        case condition
        case happiness
        case demand
        case utilization
    }

    let readyCount: Int
    let heldCount: Int
    let buildingCount: Int
    let matureCount: Int
    let detail: String
    let response: CityDirectResponse?
    let accessibilitySummary: String

    static func make(state: CityGameState) -> Self {
        var readyCount = 0
        var heldCount = 0
        var buildingCount = 0
        var matureCount = 0
        var gateCounts: [Gate: Int] = [:]

        for tile in state.tiles where [.residential, .commercial, .industrial].contains(tile.kind) {
            let evaluation = CitySimulation.developmentUpgradeEvaluation(for: tile, in: state)
            if evaluation.blockers == [.maximumLevel] {
                matureCount += 1
            } else if evaluation.blockers.contains(where: { blocker in
                if case .construction = blocker { return true }
                return false
            }) {
                buildingCount += 1
            } else if evaluation.isEligible {
                readyCount += 1
            } else {
                heldCount += 1
                let gates = Set(evaluation.blockers.compactMap(gate(for:)))
                for gate in gates {
                    gateCounts[gate, default: 0] += 1
                }
            }
        }

        let dominantGate = Gate.allCases.max { lhs, rhs in
            gateCounts[lhs, default: 0] < gateCounts[rhs, default: 0]
        }.flatMap { gateCounts[$0, default: 0] > 0 ? $0 : nil }
        let dominantCount = dominantGate.map { gateCounts[$0, default: 0] } ?? 0
        let detail: String
        let response: CityDirectResponse?
        if let dominantGate {
            detail = gateDetail(dominantGate, count: dominantCount)
            response = recommendedResponse(for: dominantGate)
        } else if readyCount > 0 {
            detail = "\(siteCount(readyCount)) ready for the next development review"
            response = nil
        } else if buildingCount > 0 {
            detail = "\(siteCount(buildingCount)) building; none ready yet"
            response = nil
        } else if matureCount > 0 {
            detail = "All \(siteCount(matureCount)) are fully developed"
            response = nil
        } else {
            detail = "Build a growable block to start the pipeline"
            response = nil
        }

        let accessibilitySummary = "Development pipeline. \(readyCount) ready, \(heldCount) held, "
            + "\(buildingCount) building, and \(matureCount) mature. \(detail)."
        return Self(
            readyCount: readyCount,
            heldCount: heldCount,
            buildingCount: buildingCount,
            matureCount: matureCount,
            detail: detail,
            response: response,
            accessibilitySummary: accessibilitySummary
        )
    }

    private static func gate(for blocker: CityDevelopmentUpgradeBlocker) -> Gate? {
        switch blocker {
        case .unsupported, .maximumLevel, .construction:
            nil
        case .operatingBalance, .treasury, .developmentCashflow:
            .finances
        case .utilityCoverage, .progressionUtilityReserve:
            .utilities
        case .townCharterReview, .regionalReview:
            .review
        case .strategyPriority:
            .strategy
        case .condition:
            .condition
        case .happiness:
            .happiness
        case .demand:
            .demand
        case .utilization:
            .utilization
        }
    }

    private static func gateDetail(_ gate: Gate, count: Int) -> String {
        let sites = siteCount(count)
        return switch gate {
        case .finances: "Finances hold \(sites)"
        case .utilities: "Utilities hold \(sites)"
        case .review: "Milestone review holds \(sites)"
        case .strategy: "City strategy holds \(sites)"
        case .condition: "Building condition holds \(sites)"
        case .happiness: "Happiness holds \(sites)"
        case .demand: "Demand holds \(sites)"
        case .utilization: "Occupancy holds \(sites)"
        }
    }

    private static func recommendedResponse(for gate: Gate) -> CityDirectResponse? {
        switch gate {
        case .finances:
            CityDirectResponse(
                title: "Review finances",
                command: .inspectorFinances,
                explanation: "Review revenue, upkeep, and tax policy affecting development upgrades.",
                focusesMap: false
            )
        case .utilities:
            CityDirectResponse(
                title: "Review utilities",
                command: .inspectorUtilities,
                explanation: "Review coverage and reserve capacity affecting development upgrades.",
                focusesMap: false
            )
        case .review, .strategy:
            CityDirectResponse(
                title: "Review city progress",
                command: .inspectorOverview,
                explanation: "Review the active milestone and city strategy affecting development upgrades.",
                focusesMap: false
            )
        case .condition, .happiness:
            CityDirectResponse(
                title: "Review happiness",
                command: .inspectorHappiness,
                explanation: "Review local conditions and resident happiness affecting development upgrades.",
                focusesMap: false
            )
        case .utilization:
            CityDirectResponse(
                title: "Review employment",
                command: .inspectorEmployment,
                explanation: "Review occupied jobs and workforce capacity affecting development upgrades.",
                focusesMap: false
            )
        case .demand:
            nil
        }
    }

    private static func siteCount(_ count: Int) -> String {
        "\(count) \(count == 1 ? "site" : "sites")"
    }
}

struct CitySelectedLocationDiagnosis: Equatable, Sendable {
    let coordinate: GridCoordinate
    let cause: String
    let consequence: String
    let responses: [CityDirectResponse]

    var accessibilitySummary: String {
        "Block \(coordinate.x + 1), \(coordinate.y + 1). Cause: \(cause) Consequence: \(consequence)"
    }

    static func make(
        tile: CityTile,
        snapshot: CityPresentationSnapshot
    ) -> CitySelectedLocationDiagnosis? {
        guard tile.kind != .empty, tile.constructionProgress >= 1,
              let sample = snapshot.spatialConsequences[tile.coordinate],
              tile.kind == .road || sample.vitality != .notApplicable else { return nil }

        if tile.kind == .road {
            guard let reading = CityTrafficAnalysis(state: snapshot.state)[tile.coordinate] else {
                return nil
            }
            let impact = CityTrafficImpact(pressure: reading.pressure)
            var responses = [CityDirectResponse(
                title: "Show traffic",
                command: .overlayTraffic,
                explanation: "Compare modeled home-to-work route pressure across the street network.",
                focusesMap: true
            )]
            if impact.appliesLocalPenalty {
                responses.insert(.init(
                    title: "Add alternate street",
                    command: .buildRoad,
                    explanation: "Add a connected alternative between nearby homes and jobs; exact relief depends on route assignment.",
                    focusesMap: true
                ), at: 0)
            }
            let threshold = Int((CityTrafficImpact.localPenaltyThreshold * 100).rounded())
            let penaltyNote = impact.appliesLocalPenalty
                ? " Nearby completed places can lose local value, happiness, and vitality above \(threshold)% pressure."
                : " No local congestion penalty applies at or below \(threshold)% pressure."
            return CitySelectedLocationDiagnosis(
                coordinate: tile.coordinate,
                cause: "Assigned home-to-work trips put this street at \((reading.pressure * 100).percentText) pressure",
                consequence: "Modeled delay is \((reading.delay * 100).percentText) with \((reading.reliability * 100).percentText) reliability." + penaltyNote,
                responses: responses
            )
        }

        var causes: [String] = []
        var responses: [CityDirectResponse] = []
        var consequences = [
            "This block is \(sample.vitality.title) at \((sample.vitalityScore * 100).percentText) vitality."
        ]
        func appendResponse(_ response: CityDirectResponse) {
            guard !responses.contains(where: { $0.command == response.command }) else { return }
            responses.append(response)
        }

        if sample.utility.powerBand != .healthy {
            causes.append("Power service is \(sample.utility.powerBand.title) at \((sample.utility.power * 100).percentText)")
            appendResponse(.init(
                title: "Add power capacity",
                command: .buildPowerPlant,
                explanation: "Place a power plant where its service can reach this area; placement does not guarantee recovery.",
                focusesMap: true
            ))
        }
        if sample.utility.waterBand != .healthy {
            causes.append("Water service is \(sample.utility.waterBand.title) at \((sample.utility.water * 100).percentText)")
            appendResponse(.init(
                title: "Add water capacity",
                command: .buildWaterTower,
                explanation: "Place a water tower where its service can reach this area; placement does not guarantee recovery.",
                focusesMap: true
            ))
        }
        if sample.pollutionBand != .healthy {
            causes.append("Pollution exposure is \(sample.pollutionBand.title) at \((sample.pollutionExposure * 100).percentText)")
            appendResponse(.init(
                title: "Add a green buffer",
                command: .buildPark,
                explanation: "Place a park nearby to mitigate exposure; it does not promise a specific vitality score.",
                focusesMap: true
            ))
        }
        if let exposure = sample.trafficExposure {
            let impact = CityTrafficImpact(pressure: exposure)
            if impact.appliesLocalPenalty {
                let localValueDrag = String(format: "%.1f%%", impact.localPenalty * 100)
                causes.append("Traffic exposure is congested at \((exposure * 100).percentText)")
                consequences.append(
                    "Modeled congestion adds \((impact.delay * 100).percentText) delay and applies a \(localValueDrag) local-value drag."
                )
                appendResponse(.init(
                    title: "Add alternate street",
                    command: .buildRoad,
                    explanation: "Add a connected alternative between nearby homes and jobs; exact relief depends on route assignment.",
                    focusesMap: true
                ))
                appendResponse(.init(
                    title: "Show traffic",
                    command: .overlayTraffic,
                    explanation: "Compare modeled home-to-work route pressure across the street network.",
                    focusesMap: true
                ))
            }
        }
        if tile.kind == .residential,
           let commute = CityTrafficAnalysis(state: snapshot.state)
            .place(at: tile.coordinate)?.commute,
           commute.access < CityCommuteAccessReading.healthyAccessThreshold {
            let route = commute.routeLength.map { " over \($0) road blocks" } ?? " with no connected route"
            causes.append(
                "Commute access is strained at \((commute.access * 100).percentText): "
                    + "\(commute.reachableJobs) reachable jobs for \(commute.requiredWorkers) workers\(route)"
            )
            consequences.append(
                "Reachable job coverage, route length, and weakest-route reliability now affect local value, happiness, vitality, and the city happiness target."
            )
            appendResponse(.init(
                title: "Connect homes and jobs",
                command: .buildRoad,
                explanation: "Add or shorten a connected street route between this home and occupied workplaces; exact access depends on the completed network.",
                focusesMap: true
            ))
            appendResponse(.init(
                title: "Show commute routes",
                command: .overlayTraffic,
                explanation: "Compare assigned home-to-work pressure and inspect route bottlenecks on the connected street network.",
                focusesMap: true
            ))
        }
        if let service = sample.civicService,
           service.combined < CityCivicServiceAnalysis.healthyCoverageThreshold {
            let weakest = service.weakestService
            causes.append(
                "Civic service coverage is weak at \((service.combined * 100).percentText): "
                    + "Fire \((service.fire * 100).percentText), "
                    + "Police \((service.police * 100).percentText), "
                    + "School \((service.school * 100).percentText)"
            )
            consequences.append(
                "Only completed civic sites reachable over connected streets support local value, happiness, and vitality."
            )
            appendResponse(.init(
                title: "Build \(weakest.title.lowercased())",
                command: CityCommandCatalog.id(for: weakest),
                explanation: "Place a completed \(weakest.title.lowercased()) on the connected street network where it can reach this block.",
                focusesMap: true
            ))
            appendResponse(.init(
                title: "Show service coverage",
                command: .overlayServices,
                explanation: "Compare the reachable Fire, Police, and School mix across completed places.",
                focusesMap: true
            ))
        }

        if sample.utility.combinedBand != .healthy {
            appendResponse(.init(
                title: "Show utility service",
                command: .overlayUtilities,
                explanation: "Compare power and water service on the map.",
                focusesMap: true
            ))
        }
        if sample.pollutionBand != .healthy {
            appendResponse(.init(
                title: "Show pollution",
                command: .overlayPollution,
                explanation: "Inspect the accepted local pollution exposure map.",
                focusesMap: true
            ))
        }
        if causes.isEmpty {
            causes.append("Local utility, civic service, pollution, and traffic conditions are healthy")
            responses.append(.init(
                title: "Review city factors",
                command: .inspectorOverview,
                explanation: "Review citywide conditions without claiming a local fix.",
                focusesMap: false
            ))
        }

        return CitySelectedLocationDiagnosis(
            coordinate: tile.coordinate,
            cause: causes.joined(separator: "; "),
            consequence: consequences.joined(separator: " "),
            responses: responses.uniquedByCommand()
        )
    }
}

enum CityNoticeActionCatalog {
    static let governedTitles: Set<String> = [
        "Choose a Growth Engine", "Chain Store Rumor", "Freight Load Forecast",
        "Industrial Load Absorbed", "Main Street Crossroads", "Storefront Slump",
        "Main Street Rebound", "Freight Network Secured", "Cleaner Industry Compact",
        "Main Street Recovery Delayed", "Freight Contract Watch", "Industrial Load Surge",
        "Freight Recovery Delayed", "Budget Gap", "Utility Reserve Tight", "Utility Shortfall",
        "Hiring Bottleneck", "Severe Storm", "Regional Retail Challenge",
        "Regional Retail Pressure", "Regional Grid Mandate", "Regional Freight Overload",
        "Regional Qualification Interrupted", "Regional Qualification Resumed",
        "Town Charter Standards", "Town Charter Qualification Interrupted",
        "Town Charter Qualification Resumed"
    ]

    static func actions(for title: String) -> [CityDirectResponse] {
        switch title {
        case "Choose a Growth Engine", "Hiring Bottleneck":
            return [
                .init(title: "Build commercial", command: .buildCommercial, explanation: "Add cleaner taxable activity and jobs with a slower payoff.", focusesMap: true),
                .init(title: "Build industrial", command: .buildIndustrial, explanation: "Add jobs and revenue faster while accepting more pollution and utility load.", focusesMap: true)
            ]
        case "Chain Store Rumor", "Main Street Crossroads", "Storefront Slump",
             "Main Street Recovery Delayed", "Regional Retail Challenge",
             "Regional Retail Pressure":
            return [
                .init(title: "Review tax policy", command: .inspectorFinances, explanation: "Tax relief may support demand but reduces revenue.", focusesMap: false),
                .init(title: "Build a park", command: .buildPark, explanation: "Placemaking costs capital and upkeep; it does not guarantee recovery.", focusesMap: true)
            ]
        case "Freight Load Forecast", "Freight Contract Watch", "Industrial Load Surge",
             "Freight Recovery Delayed", "Regional Grid Mandate",
             "Regional Freight Overload":
            return [
                .init(title: "Add power", command: .buildPowerPlant, explanation: "Add power capacity and upkeep where service can reach demand.", focusesMap: true),
                .init(title: "Add water", command: .buildWaterTower, explanation: "Add water capacity and upkeep where service can reach demand.", focusesMap: true),
                .init(title: "Add green buffer", command: .buildPark, explanation: "Mitigate local exposure without promising a fixed result.", focusesMap: true)
            ]
        case "Industrial Load Absorbed", "Severe Storm":
            return [.init(title: "Review utilities", command: .inspectorUtilities, explanation: "Inspect current service evidence; this does not reverse an applied cost.", focusesMap: false)]
        case "Budget Gap":
            return [.init(title: "Review finances", command: .inspectorFinances, explanation: "Inspect revenue, upkeep, and tax policy before committing more spending.", focusesMap: false)]
        case "Utility Reserve Tight", "Utility Shortfall":
            return [
                .init(title: "Show utility service", command: .overlayUtilities, explanation: "Find the accepted local service gaps.", focusesMap: true),
                .init(title: "Add power", command: .buildPowerPlant, explanation: "Add capacity where power service can reach demand.", focusesMap: true),
                .init(title: "Add water", command: .buildWaterTower, explanation: "Add capacity where water service can reach demand.", focusesMap: true)
            ]
        case "Regional Qualification Interrupted":
            return [.init(
                title: "Review regional standards",
                command: .inspectorOverview,
                explanation: "Review the current Regional Capital standards and restart qualification.",
                focusesMap: false
            )]
        case "Regional Qualification Resumed":
            return [.init(
                title: "Review qualifying progress",
                command: .inspectorOverview,
                explanation: "Review the restored standards and remaining qualifying days.",
                focusesMap: false
            )]
        case "Town Charter Qualification Interrupted":
            return [.init(
                title: "Review Town Charter standards",
                command: .inspectorOverview,
                explanation: "Review the current Town Charter blocker and restart qualification.",
                focusesMap: false
            )]
        case "Town Charter Qualification Resumed":
            return [.init(
                title: "Review Charter progress",
                command: .inspectorOverview,
                explanation: "Review the restored standards and remaining qualifying days.",
                focusesMap: false
            )]
        case "Town Charter Standards":
            return [.init(
                title: "Review Town Charter standards",
                command: .inspectorOverview,
                explanation: "Review the live Charter standard that needs attention next.",
                focusesMap: false
            )]
        case "Main Street Rebound", "Freight Network Secured", "Cleaner Industry Compact":
            return [.init(
                title: "Continue to the Town Charter",
                command: .inspectorOverview,
                explanation: "Review the live Town Charter standard that needs attention next.",
                focusesMap: false
            )]
        default:
            return []
        }
    }

    static func actions(for title: String, analytics: CityAnalytics) -> [CityDirectResponse] {
        let strategyCompletionTitles: Set<String> = [
            "Main Street Rebound", "Main Street Recovery Delayed",
            "Freight Network Secured", "Cleaner Industry Compact", "Freight Recovery Delayed"
        ]
        if title == "Town Charter Standards"
            || title == "Town Charter Qualification Interrupted"
            || (strategyCompletionTitles.contains(title)
                && analytics.strategyPhase == .completed
                && !analytics.townCharterAwarded) {
            let support = CityTownCharterDecisionSupport.make(analytics: analytics)
            return ([support.primaryResponse] + support.secondaryResponses).uniquedByCommand()
        }
        if title == "Regional Qualification Interrupted" {
            let support = CityRegionalCapitalDecisionSupport.make(analytics: analytics)
            return ([support.primaryResponse] + support.secondaryResponses).uniquedByCommand()
        }
        if title == "Hiring Bottleneck", let strategy = analytics.committedStrategy {
            let kind: BuildingKind = strategy == .industrialExpansion ? .industrial : .commercial
            return [
                .init(
                    title: "Build \(kind.title.lowercased()) jobs",
                    command: CityCommandCatalog.id(for: kind),
                    explanation: "Add jobs on the committed \(kind.title) route without reopening the growth-engine decision.",
                    focusesMap: true
                ),
                .init(
                    title: "Review employment",
                    command: .inspectorEmployment,
                    explanation: "Review workforce size, job capacity, and the remaining employment gap.",
                    focusesMap: false
                )
            ]
        }
        guard title == "Utility Reserve Tight" || title == "Utility Shortfall" else {
            return actions(for: title)
        }

        let support = CityUtilityDecisionSupport.make(analytics: analytics)
        guard let priority = support.response else {
            return [
                .init(
                    title: "Review utilities",
                    command: .inspectorUtilities,
                    explanation: "Current use is covered; inspect live reserve before adding more capacity.",
                    focusesMap: false
                )
            ]
        }
        return [priority] + actions(for: title).filter { $0.command != priority.command }
    }
}

private extension Array where Element == CityDirectResponse {
    func uniquedByCommand() -> [CityDirectResponse] {
        var seen: Set<CityCommandID> = []
        return filter { seen.insert($0.command).inserted }
    }
}

private extension CityConsequenceBand {
    var title: String {
        switch self {
        case .severe: "severe"
        case .strained: "strained"
        case .healthy: "healthy"
        }
    }
}

private extension BuildingKind {
    var buildConsequenceSummary: String {
        switch self {
        case .empty:
            "No construction effect"
        case .road:
            "Connects adjacent blocks for development"
        case .residential:
            "Adds 280 homes after construction"
        case .commercial:
            "Adds up to \(CitySimulation.commercialJobCapacity) jobs and taxable activity"
        case .industrial:
            "Adds up to \(CitySimulation.industrialJobCapacity) jobs with heavier utility and pollution pressure"
        case .park:
            "Can reduce nearby pollution exposure and support livability"
        case .powerPlant:
            "Adds \(CitySimulation.powerCapacityPerPlant) citywide power capacity after construction"
        case .waterTower:
            "Adds \(CitySimulation.waterCapacityPerTower) citywide water capacity after construction"
        case .fireStation:
            "Adds road-connected fire reach for storm protection"
        case .policeStation:
            "Adds road-connected police reach for Commercial demand"
        case .school:
            "Adds road-connected school reach for Residential demand"
        case .cityHall:
            "Adds a protected civic landmark"
        }
    }
}

private extension BuildRejection {
    var buildRecovery: CityDirectResponse? {
        switch self {
        case .outsideMap:
            nil
        case .occupied:
            CityDirectResponse(
                title: "Bulldoze",
                command: .bulldozeMode,
                explanation: "Inspect the demolition cost before removing the existing structure.",
                focusesMap: true
            )
        case .insufficientFunds:
            CityDirectResponse(
                title: "Review finances",
                command: .inspectorFinances,
                explanation: "Review revenue, upkeep, and tax policy before committing more spending.",
                focusesMap: false
            )
        case .roadAccessRequired:
            CityDirectResponse(
                title: "Target adjacent road",
                command: .buildRoad,
                explanation: "Select one validated open block beside this parcel, then confirm Road construction.",
                focusesMap: true
            )
        case .cityRoadConnectionRequired:
            CityDirectResponse(
                title: "Connect street",
                command: .buildRoad,
                explanation: "Extend this isolated street until it reaches the active city network, then return to this parcel.",
                focusesMap: true
            )
        case .uniqueBuildingExists:
            CityDirectResponse(
                title: "City overview",
                command: .inspectorOverview,
                explanation: "Review the existing City Hall before choosing another project.",
                focusesMap: false
            )
        }
    }
}

private extension CityLocationVitality {
    var title: String {
        switch self {
        case .notApplicable: "not applicable"
        case .strained: "strained"
        case .stable: "stable"
        case .prosperous: "prosperous"
        }
    }
}
