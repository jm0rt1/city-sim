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
        let detail: String
        if result.recoveredFromBackup {
            sourceLabel = "Last known-good backup"
            sourceSymbol = "arrow.clockwise.icloud.fill"
            detail = "The primary quicksave could not be verified. Continue from this backup; the simulation will remain paused."
        } else if result.isAutosave {
            sourceLabel = "Latest rotating autosave"
            sourceSymbol = "clock.arrow.circlepath"
            detail = "Continue from this verified automatic checkpoint; the simulation will remain paused while you review the city's active pressures."
        } else {
            sourceLabel = "Verified quicksave"
            sourceSymbol = "checkmark.icloud.fill"
            detail = "Continue from this verified quicksave; the simulation will remain paused while you review the city's active pressures."
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
