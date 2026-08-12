import Foundation

struct CityDirectResponse: Identifiable, Hashable, Sendable {
    let title: String
    let command: CityCommandID
    let explanation: String
    let focusesMap: Bool

    var id: String { "\(command.rawValue)|\(title)" }
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

struct CityBuildDecisionPresentation: Equatable, Sendable {
    let buildingTitle: String
    let buildingSymbol: String
    let target: String
    let footprint: String
    let cost: String
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
        rejection: BuildRejection?
    ) -> CityBuildDecisionPresentation {
        CityBuildDecisionPresentation(
            buildingTitle: kind.title,
            buildingSymbol: kind.symbol,
            target: "Block \(tile.coordinate.x + 1), \(tile.coordinate.y + 1)",
            footprint: "1 × 1 block",
            cost: "Cost \(kind.buildCost.currencyText) · \(kind.upkeep.currencyText) / cycle",
            availability: rejection == nil ? "Ready to build" : "Blocked",
            disabledReason: rejection?.message,
            likelyConsequence: kind.buildConsequenceSummary,
            cancellation: "Escape cancels without changing the city",
            recovery: rejection?.buildRecovery
        )
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
                return .init(
                    name: "Build \(kind.title) at \(block)",
                    disclosure: "Available. Costs \(kind.buildCost.currencyText) and \(kind.upkeep.currencyText) upkeep per cycle.",
                    isAvailable: true,
                    buildDecision: .make(kind: kind, tile: tile, rejection: nil)
                )
            case .failure(let rejection):
                return .init(
                    name: "Build \(kind.title) at \(block)",
                    disclosure: "Unavailable. \(rejection.message)",
                    isAvailable: false,
                    buildDecision: .make(kind: kind, tile: tile, rejection: rejection)
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
            return .init(
                name: "Demolish \(tile.kind.title) at \(block) for \(tile.kind.demolitionCost.currencyText)",
                disclosure: "Available. Demolition costs \(tile.kind.demolitionCost.currencyText). Undo is available after activation.",
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
        default:
            return []
        }
    }

    static func actions(for title: String, analytics: CityAnalytics) -> [CityDirectResponse] {
        if title == "Town Charter Standards"
            || title == "Town Charter Qualification Interrupted" {
            let support = CityTownCharterDecisionSupport.make(analytics: analytics)
            return ([support.primaryResponse] + support.secondaryResponses).uniquedByCommand()
        }
        if title == "Regional Qualification Interrupted" {
            let support = CityRegionalCapitalDecisionSupport.make(analytics: analytics)
            return ([support.primaryResponse] + support.secondaryResponses).uniquedByCommand()
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
