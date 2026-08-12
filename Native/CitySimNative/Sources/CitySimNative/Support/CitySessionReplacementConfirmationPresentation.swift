import Foundation

enum CitySessionReplacementAction: Equatable, Sendable {
    case newRegion
    case loadQuicksave
}

struct CitySessionReplacementConfirmationPresentation: Equatable, Sendable {
    let action: CitySessionReplacementAction
    let title: String
    let message: String
    let destructiveActionTitle: String
    let cancelActionTitle: String

    static func make(
        state: CityGameState,
        action: CitySessionReplacementAction,
        loadResult: SaveGameLoadResult? = nil
    ) -> Self {
        let checkpoint = "\(state.cityName) · \(state.formattedDay) · "
            + "\(state.population.formatted()) residents"
        switch action {
        case .newRegion:
            return Self(
                action: action,
                title: "Replace \(state.cityName)?",
                message: "\(checkpoint) will be replaced. "
                    + "Save the city first if you want to return to this checkpoint.",
                destructiveActionTitle: "Start New Region",
                cancelActionTitle: "Keep \(state.cityName)"
            )
        case .loadQuicksave:
            let loaded = loadResult?.state ?? state
            let savedCheckpoint = "\(loaded.cityName) · \(loaded.formattedDay) · "
                + "\(loaded.population.formatted()) residents"
            let sourceNote: String
            if loadResult?.recoveredFromBackup == true {
                sourceNote = " This checkpoint was recovered from the last known-good backup."
            } else if loadResult?.isAutosave == true {
                sourceNote = " This is the latest verified rotating autosave."
            } else if loadResult?.isNamedBranch == true {
                sourceNote = " This checkpoint is the named timeline branch “"
                    + "\(loadResult?.branchName ?? loaded.cityName)”."
            } else {
                sourceNote = ""
            }
            return Self(
                action: action,
                title: "Load \(loaded.cityName)?",
                message: "\(savedCheckpoint) will replace \(checkpoint). "
                    + "Save \(state.cityName) first if you want to return to its current checkpoint."
                    + sourceNote,
                destructiveActionTitle: "Load \(loaded.cityName)",
                cancelActionTitle: "Keep \(state.cityName)"
            )
        }
    }
}
