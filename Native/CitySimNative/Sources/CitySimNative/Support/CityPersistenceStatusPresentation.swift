import Foundation

enum CityPersistenceStatusKind: Equatable, Sendable {
    case notSaved
    case saved
    case unsavedChanges
}

struct CityPersistenceStatusPresentation: Equatable, Sendable {
    let kind: CityPersistenceStatusKind
    let label: String
    let symbol: String
    let help: String

    static func make(current: CityGameState, lastPersisted: CityGameState?) -> Self {
        guard let lastPersisted else {
            return Self(
                kind: .notSaved,
                label: "Not saved",
                symbol: "icloud.slash",
                help: "This city has not been saved yet"
            )
        }
        guard current == lastPersisted else {
            return Self(
                kind: .unsavedChanges,
                label: "Unsaved changes",
                symbol: "circle.fill",
                help: "This city has changes newer than its last save"
            )
        }
        return Self(
            kind: .saved,
            label: "Saved",
            symbol: "checkmark.circle.fill",
            help: "This city matches its last successful save"
        )
    }
}
