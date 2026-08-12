import Foundation

struct CityStartupResumePresentation: Equatable, Sendable {
    let title: String
    let checkpoint: String
    let sourceLabel: String
    let sourceSymbol: String
    let detail: String
    let resumeActionTitle: String
    let startFreshActionTitle: String
    let recoveredFromBackup: Bool

    var accessibilitySummary: String {
        "\(title). \(checkpoint). \(sourceLabel). \(detail)"
    }

    static func make(_ result: SaveGameLoadResult) -> Self {
        let state = result.state
        let checkpoint = "\(state.cityName) · \(state.formattedDay) · "
            + "\(state.population.formatted()) residents"
        let sourceLabel: String
        let sourceSymbol: String
        var detail: String
        if result.recoveredFromBackup {
            sourceLabel = "Last known-good backup"
            sourceSymbol = "arrow.clockwise.icloud.fill"
            detail = "The primary quicksave could not be verified. Continue from this backup; the simulation will remain paused."
        } else if result.isAutosave {
            sourceLabel = "Latest rotating autosave"
            sourceSymbol = "clock.arrow.circlepath"
            detail = "Continue from this verified automatic checkpoint; the simulation will remain paused while you review the city's active pressures."
        } else if result.isNamedBranch {
            sourceLabel = "Named branch · \(result.branchName ?? state.cityName)"
            sourceSymbol = "arrow.triangle.branch"
            detail = "Continue from this preserved timeline branch; the simulation will remain paused while you review the city's active pressures."
        } else if result.isScenarioCheckpoint {
            sourceLabel = "Scenario checkpoint · "
                + (result.scenarioCheckpointTitle ?? "Authored milestone")
            sourceSymbol = "flag.checkered"
            detail = "Continue from this authored milestone; the simulation will remain paused while you review the city's active pressures."
        } else if result.isMigration {
            sourceLabel = "Upgraded legacy copy"
            sourceSymbol = "arrow.up.doc.fill"
            detail = "Continue from this verified current-format copy; the original legacy checkpoint remains available in Load City."
        } else {
            sourceLabel = "Verified quicksave"
            sourceSymbol = "checkmark.icloud.fill"
            detail = "Continue from this verified quicksave; the simulation will remain paused while you review the city's active pressures."
        }
        if result.isLegacy {
            let original = result.checkpointFileName ?? "legacy checkpoint"
            detail = "Continue from this legacy checkpoint. CitySim will create a verified save-format v\(SaveGameEnvelope.currentSchemaVersion) copy, keep \(original) unchanged, and pause the simulation."
        }
        return Self(
            title: result.recoveredFromBackup
                ? "Recover \(state.cityName)?"
                : "Resume \(state.cityName)?",
            checkpoint: checkpoint,
            sourceLabel: sourceLabel,
            sourceSymbol: sourceSymbol,
            detail: detail,
            resumeActionTitle: result.recoveredFromBackup
                ? "Recover \(state.cityName)"
                : "Resume \(state.cityName)",
            startFreshActionTitle: "Start Fresh",
            recoveredFromBackup: result.recoveredFromBackup
        )
    }
}
