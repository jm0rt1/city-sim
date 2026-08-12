import Foundation

enum CityTerminationAction: Equatable, Sendable {
    case saveAndQuit
    case quitWithoutSaving
    case cancel
}

struct CityTerminationConfirmationPresentation: Equatable, Sendable {
    let title: String
    let message: String
    let saveActionTitle: String
    let discardActionTitle: String
    let cancelActionTitle: String

    static func isRequired(
        state: CityGameState,
        persistenceStatus: CityPersistenceStatusPresentation
    ) -> Bool {
        switch persistenceStatus.kind {
        case .saved:
            false
        case .unsavedChanges:
            true
        case .notSaved:
            state != .newCity(seed: state.seed)
        }
    }

    static func make(
        state: CityGameState,
        persistenceStatus: CityPersistenceStatusPresentation
    ) -> Self {
        let saveContext = persistenceStatus.kind == .notSaved
            ? "has never been saved"
            : "has changes newer than its last successful save"
        return Self(
            title: "Save \(state.cityName) Before Quitting?",
            message: "\(state.cityName) · \(state.formattedDay) · "
                + "\(state.population.formatted()) residents \(saveContext). "
                + "Save before quitting to keep this checkpoint.",
            saveActionTitle: "Save and Quit",
            discardActionTitle: "Quit Without Saving",
            cancelActionTitle: "Cancel"
        )
    }
}
