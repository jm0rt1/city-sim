import Foundation

struct CityPersistenceFeedbackPresentation: Equatable, Sendable {
    let message: String

    static func saved(_ state: CityGameState) -> Self {
        Self(
            message: "\(state.cityName) saved · \(checkpointDescription(for: state))"
        )
    }

    static func loaded(_ state: CityGameState, recoveredFromBackup: Bool) -> Self {
        let action = recoveredFromBackup
            ? "Recovered \(state.cityName) from last known-good save"
            : "\(state.cityName) loaded"
        return Self(
            message: "\(action) · \(checkpointDescription(for: state)) · Simulation paused"
        )
    }

    private static func checkpointDescription(for state: CityGameState) -> String {
        "\(state.formattedDay) · \(state.population.formatted()) residents"
    }
}
