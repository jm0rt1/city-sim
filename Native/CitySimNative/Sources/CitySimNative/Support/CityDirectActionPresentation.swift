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
        let threshold = 0.000_000_001

        for current in currentConsequences.samples where current.vitality != .notApplicable {
            guard let projected = completedConsequences[current.coordinate] else { continue }
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
            greatestServiceGain: greatestGain
        )
    }
}

struct CityCivicServicePlacementForecast: Equatable, Sendable {
    let kind: BuildingKind
    let happinessTargetGain: Double
    let stormDamageReduction: Double

    var summary: String {
        var outcomes: [String] = []
        if happinessTargetGain > 0.000_000_001 {
            outcomes.append("Happiness target +\(Self.points(happinessTargetGain))")
        }
        if stormDamageReduction > 0.000_000_001 {
            outcomes.append("storm damage -\(Self.points(stormDamageReduction * 100))")
        }
        return outcomes.isEmpty
            ? "No additional citywide service benefit at current staffing"
            : outcomes.joined(separator: " · ")
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

        let currentHappinessBonus = CitySimulation.civicServiceHappinessBonus(in: state)
        let projectedHappinessBonus = CitySimulation.civicServiceHappinessBonus(in: completed)
        let currentStormDamage = CitySimulation.stormProtection(in: state).estimatedConditionDamage
        let projectedStormDamage = CitySimulation.stormProtection(in: completed).estimatedConditionDamage
        return Self(
            kind: kind,
            happinessTargetGain: max(0, projectedHappinessBonus - currentHappinessBonus),
            stormDamageReduction: max(0, currentStormDamage - projectedStormDamage)
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
        case .fireStation, .policeStation, .school:
            "Removes civic service and storm protection"
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
    let availability: String
    let disabledReason: String?
    let likelyConsequence: String
    let cancellation: String
    let recovery: CityDirectResponse?

    var accessibilitySummary: String {
        [
            "\(buildingTitle) placement",
            "Target \(target)",
            "Footprint \(footprint)",
            cost,
            operatingImpact,
            availability,
            disabledReason,
            "Likely consequence: \(likelyConsequence)",
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
        unlimitedFunds: Bool = false
    ) -> CityBuildDecisionPresentation {
        let cost = unlimitedFunds
            ? "Cost waived · \(kind == .road ? "online now" : "online in 4 ticks")"
            : "Cost \(kind.buildCost.currencyText) · \(kind == .road ? "online now" : "online in 4 ticks")"
        let forecast = rejection == nil
            ? CityBuildOperatingForecast.make(kind: kind, tile: tile, state: state)
            : nil
        return CityBuildDecisionPresentation(
            buildingTitle: kind.title,
            buildingSymbol: kind.symbol,
            target: "Block \(tile.coordinate.x + 1), \(tile.coordinate.y + 1)",
            footprint: "1 × 1 block",
            cost: cost,
            operatingImpact: operatingImpact(forecast: forecast, unlimitedFunds: unlimitedFunds),
            operatingForecast: forecast,
            availability: rejection == nil ? "Ready to build" : "Blocked",
            disabledReason: rejection?.message,
            likelyConsequence: likelyConsequence(
                kind: kind,
                tile: tile,
                state: state
            ),
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
        state: CityGameState
    ) -> String {
        switch kind {
        case .road:
            CityRoadPlacementForecast.make(at: tile.coordinate, in: state)?.summary
                ?? "Clear this occupied block before the road network can change"
        case .park:
            CityParkPlacementForecast.make(at: tile.coordinate, in: state)?.summary
                ?? kind.buildConsequenceSummary
        case .powerPlant, .waterTower:
            CityUtilityPlacementForecast.make(
                kind: kind,
                at: tile.coordinate,
                in: state
            )?.summary ?? kind.buildConsequenceSummary
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
        state: CityGameState
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
                        unlimitedFunds: state.usesUnlimitedFunds
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
                        unlimitedFunds: state.usesUnlimitedFunds
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
        guard tile.kind != .empty, tile.kind != .road, tile.constructionProgress >= 1,
              let sample = snapshot.spatialConsequences[tile.coordinate],
              sample.vitality != .notApplicable else { return nil }

        var causes: [String] = []
        var responses: [CityDirectResponse] = []

        if sample.utility.powerBand != .healthy {
            causes.append("Power service is \(sample.utility.powerBand.title) at \((sample.utility.power * 100).percentText)")
            responses.append(.init(
                title: "Add power capacity",
                command: .buildPowerPlant,
                explanation: "Place a power plant where its service can reach this area; placement does not guarantee recovery.",
                focusesMap: true
            ))
        }
        if sample.utility.waterBand != .healthy {
            causes.append("Water service is \(sample.utility.waterBand.title) at \((sample.utility.water * 100).percentText)")
            responses.append(.init(
                title: "Add water capacity",
                command: .buildWaterTower,
                explanation: "Place a water tower where its service can reach this area; placement does not guarantee recovery.",
                focusesMap: true
            ))
        }
        if sample.pollutionBand != .healthy {
            causes.append("Pollution exposure is \(sample.pollutionBand.title) at \((sample.pollutionExposure * 100).percentText)")
            responses.append(.init(
                title: "Add a green buffer",
                command: .buildPark,
                explanation: "Place a park nearby to mitigate exposure; it does not promise a specific vitality score.",
                focusesMap: true
            ))
        }

        if sample.utility.combinedBand != .healthy {
            responses.append(.init(
                title: "Show utility service",
                command: .overlayUtilities,
                explanation: "Compare power and water service on the map.",
                focusesMap: true
            ))
        }
        if sample.pollutionBand != .healthy {
            responses.append(.init(
                title: "Show pollution",
                command: .overlayPollution,
                explanation: "Inspect the accepted local pollution exposure map.",
                focusesMap: true
            ))
        }
        if causes.isEmpty {
            causes.append("Local utility service and pollution exposure are healthy")
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
            consequence: "This block is \(sample.vitality.title) at \((sample.vitalityScore * 100).percentText) vitality.",
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
        case .fireStation, .policeStation, .school:
            "Adds a civic-service contribution after construction"
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
