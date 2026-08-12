import Foundation

struct CityStartupResumePresentation: Equatable, Sendable {
    let title: String
    let checkpoint: String
    let detail: String
    let resumeActionTitle: String
    let startFreshActionTitle: String
    let recoveredFromBackup: Bool

    var accessibilitySummary: String {
        "\(title). \(checkpoint). \(detail)"
    }

    static func make(_ result: SaveGameLoadResult) -> Self {
        let state = result.state
        let checkpoint = "\(state.cityName) · \(state.formattedDay) · "
            + "\(state.population.formatted()) residents"
        let detail = result.recoveredFromBackup
            ? "The primary quicksave could not be verified. Continue from the last known-good backup; the simulation will remain paused."
            : "Continue from this verified quicksave; the simulation will remain paused while you review the city's active pressures."
        return Self(
            title: result.recoveredFromBackup
                ? "Recover \(state.cityName)?"
                : "Resume \(state.cityName)?",
            checkpoint: checkpoint,
            detail: detail,
            resumeActionTitle: result.recoveredFromBackup
                ? "Recover \(state.cityName)"
                : "Resume \(state.cityName)",
            startFreshActionTitle: "Start Fresh",
            recoveredFromBackup: result.recoveredFromBackup
        )
    }
}
