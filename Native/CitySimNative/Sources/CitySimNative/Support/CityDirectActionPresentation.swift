import Foundation

struct CityMapPrimaryActionPresentation: Equatable, Sendable {
    let name: String
    let disclosure: String
    let isAvailable: Bool

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
                    isAvailable: true
                )
            case .failure(let rejection):
                return .init(
                    name: "Build \(kind.title) at \(block)",
                    disclosure: "Unavailable. \(rejection.message)",
                    isAvailable: false
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

struct CityDirectResponse: Identifiable, Hashable, Sendable {
    let title: String
    let command: CityCommandID
    let explanation: String
    let focusesMap: Bool

    var id: String { "\(command.rawValue)|\(title)" }
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
        "Regional Retail Pressure", "Regional Grid Mandate", "Regional Freight Overload"
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
        default:
            return []
        }
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
