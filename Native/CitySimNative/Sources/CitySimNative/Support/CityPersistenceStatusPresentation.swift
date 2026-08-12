import Foundation

enum CityPersistenceStatusKind: Equatable, Sendable {
    case notSaved
    case saved
    case unsavedChanges
}

enum CityPersistenceCheckpointKind: Equatable, Sendable {
    case manual
    case autosave
    case branch
    case scenario
    case migration
}

struct CityPersistenceStatusPresentation: Equatable, Sendable {
    let kind: CityPersistenceStatusKind
    let label: String
    let symbol: String
    let help: String

    static func make(
        current: CityGameState,
        lastPersisted: CityGameState?,
        checkpointKind: CityPersistenceCheckpointKind = .manual
    ) -> Self {
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
        if checkpointKind == .autosave {
            return Self(
                kind: .saved,
                label: "Autosaved",
                symbol: "checkmark.icloud.fill",
                help: "This city matches its latest rotating autosave"
            )
        }
        if checkpointKind == .branch {
            return Self(
                kind: .saved,
                label: "Branched",
                symbol: "arrow.triangle.branch",
                help: "This city matches its latest named timeline branch"
            )
        }
        if checkpointKind == .scenario {
            return Self(
                kind: .saved,
                label: "Checkpointed",
                symbol: "flag.checkered",
                help: "This city matches its latest authored scenario checkpoint"
            )
        }
        if checkpointKind == .migration {
            return Self(
                kind: .saved,
                label: "Upgraded",
                symbol: "arrow.up.doc.fill",
                help: "This city matches its verified current-format migration copy"
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
