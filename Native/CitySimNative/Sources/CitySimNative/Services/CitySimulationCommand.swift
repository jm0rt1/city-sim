import Foundation

enum CitySimulationCommand: Codable, Equatable, Sendable {
    case build(kind: BuildingKind, coordinate: GridCoordinate)
    case demolish(coordinate: GridCoordinate)
    case setTaxRate(Double)
    case advanceOneDailyBoundary
}

enum CitySimulationCommandRejection: String, Codable, Equatable, Sendable {
    case outsideMap
    case occupied
    case insufficientFunds
    case roadAccessRequired
    case uniqueBuildingExists
    case demolitionNotAllowed
    case simulationNotPlaying
}

enum CitySimulationCommandResult: Equatable, Sendable {
    case applied
    case rejected(CitySimulationCommandRejection)
}

enum CitySimulationCommandExecutor {
    static func apply(
        _ command: CitySimulationCommand,
        to state: inout CityGameState
    ) -> CitySimulationCommandResult {
        switch command {
        case .build(let kind, let coordinate):
            switch CitySimulation.build(kind, at: coordinate, in: &state) {
            case .success:
                return .applied
            case .failure(let rejection):
                return .rejected(map(rejection))
            }
        case .demolish(let coordinate):
            return CitySimulation.demolish(at: coordinate, in: &state)
                ? .applied
                : .rejected(.demolitionNotAllowed)
        case .setTaxRate(let value):
            state.taxRate = min(0.18, max(0.04, value))
            return .applied
        case .advanceOneDailyBoundary:
            guard state.status == .playing else { return .rejected(.simulationNotPlaying) }
            let ticksToBoundary = 4 - state.tick % 4
            for _ in 0..<ticksToBoundary { CitySimulation.step(&state) }
            return .applied
        }
    }

    private static func map(_ rejection: BuildRejection) -> CitySimulationCommandRejection {
        switch rejection {
        case .outsideMap: .outsideMap
        case .occupied: .occupied
        case .insufficientFunds: .insufficientFunds
        case .roadAccessRequired: .roadAccessRequired
        case .uniqueBuildingExists: .uniqueBuildingExists
        }
    }
}
