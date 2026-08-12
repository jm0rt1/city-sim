import Foundation

struct CityScenarioCheckpoint: Equatable, Sendable {
    let id: String
    let title: String
}

enum CityScenarioCheckpointDetector {
    static func newlyReached(
        from previous: CityGameState,
        to current: CityGameState
    ) -> [CityScenarioCheckpoint] {
        newlyReached(from: previous.progression, to: current.progression)
    }

    static func newlyReached(
        from previousProgression: CityProgressionState?,
        to currentProgression: CityProgressionState?
    ) -> [CityScenarioCheckpoint] {
        var checkpoints: [CityScenarioCheckpoint] = []

        if previousProgression?.strategy == nil,
           let strategy = currentProgression?.strategy?.committedStrategy {
            checkpoints.append(strategy.commitmentCheckpoint)
        }

        if previousProgression?.strategy?.currentPhase != .completed,
           let strategy = currentProgression?.strategy,
           strategy.currentPhase == .completed {
            checkpoints.append(strategy.committedStrategy.recoveryCheckpoint)
        }

        if previousProgression?.townCharterAwarded != true,
           currentProgression?.townCharterAwarded == true {
            checkpoints.append(
                CityScenarioCheckpoint(id: "town-charter", title: "Town Charter Secured")
            )
        }

        if previousProgression?.secondAct?.regionalCapitalAwarded != true,
           currentProgression?.secondAct?.regionalCapitalAwarded == true {
            checkpoints.append(
                CityScenarioCheckpoint(
                    id: "regional-capital",
                    title: "Regional Capital Recognized"
                )
            )
        }

        return checkpoints
    }
}

private extension CityStrategy {
    var commitmentCheckpoint: CityScenarioCheckpoint {
        switch self {
        case .commercialStewardship:
            CityScenarioCheckpoint(
                id: "commercial-stewardship-chosen",
                title: "Commercial Stewardship Chosen"
            )
        case .industrialExpansion:
            CityScenarioCheckpoint(
                id: "industrial-expansion-chosen",
                title: "Industrial Expansion Chosen"
            )
        }
    }

    var recoveryCheckpoint: CityScenarioCheckpoint {
        switch self {
        case .commercialStewardship:
            CityScenarioCheckpoint(
                id: "commercial-recovery-secured",
                title: "Main Street Recovery Secured"
            )
        case .industrialExpansion:
            CityScenarioCheckpoint(
                id: "industrial-recovery-secured",
                title: "Freight Recovery Secured"
            )
        }
    }
}
