import Foundation

struct CityPersistenceFeedbackPresentation: Equatable, Sendable {
    let message: String

    static func saved(_ state: CityGameState) -> Self {
        Self(
            message: "\(state.cityName) saved · \(checkpointDescription(for: state))"
        )
    }

    static func autosaved(_ state: CityGameState) -> Self {
        Self(
            message: "\(state.cityName) autosaved · \(checkpointDescription(for: state))"
        )
    }

    static func branched(_ state: CityGameState, name: String) -> Self {
        Self(
            message: "Timeline branch “\(name)” created · \(checkpointDescription(for: state))"
        )
    }

    static func scenarioCheckpoint(_ state: CityGameState, title: String) -> Self {
        Self(
            message: "Scenario checkpoint “\(title)” secured · \(checkpointDescription(for: state))"
        )
    }

    static func scenarioCheckpointAlreadyExists(title: String) -> Self {
        Self(
            message: "Scenario checkpoint “\(title)” is already preserved · "
                + "Create a named branch to keep this timeline"
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

    static func loadedAutosave(_ state: CityGameState) -> Self {
        Self(
            message: "\(state.cityName) resumed from autosave · "
                + "\(checkpointDescription(for: state)) · Simulation paused"
        )
    }

    static func loadedBranch(_ state: CityGameState, name: String) -> Self {
        Self(
            message: "Resumed “\(name)” · \(checkpointDescription(for: state)) · Simulation paused"
        )
    }

    static func loadedScenarioCheckpoint(_ state: CityGameState, title: String) -> Self {
        Self(
            message: "Resumed scenario “\(title)” · "
                + "\(checkpointDescription(for: state)) · Simulation paused"
        )
    }

    static func loadedLegacyMigration(
        _ state: CityGameState,
        migration: SaveGameMigrationResult
    ) -> Self {
        let action = migration.createdCopy
            ? "Legacy save upgraded to format v\(SaveGameEnvelope.currentSchemaVersion)"
            : "Verified format v\(SaveGameEnvelope.currentSchemaVersion) copy reopened"
        return Self(
            message: "\(action) · Original \(migration.originalFileName) preserved · "
                + "\(checkpointDescription(for: state)) · Simulation paused"
        )
    }

    static func loadedMigration(_ state: CityGameState) -> Self {
        Self(
            message: "Resumed upgraded legacy copy · "
                + "\(checkpointDescription(for: state)) · Simulation paused"
        )
    }

    static func legacyMigrationFailed(
        _ state: CityGameState,
        originalFileName: String?,
        error: Error
    ) -> Self {
        let original = originalFileName.map { "CitySim did not change \($0)" }
            ?? "CitySim did not change the source checkpoint"
        return Self(
            message: "\(state.cityName) loaded from legacy save · Upgrade copy failed · "
                + "\(original): \(error.localizedDescription)"
        )
    }

    private static func checkpointDescription(for state: CityGameState) -> String {
        "\(state.formattedDay) · \(state.population.formatted()) residents"
    }
}
