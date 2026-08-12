import Foundation

struct CityCheckpointCardPresentation: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let sourceLabel: String
    let sourceSymbol: String
    let checkpoint: String
    let detail: String
    let modifiedAt: Date
    let integrityLabel: String
    let integritySymbol: String
    let isLoadable: Bool

    var accessibilitySummary: String {
        "\(title). \(sourceLabel). \(checkpoint). \(detail). \(integrityLabel)."
    }

    static func make(_ entry: SaveGameCheckpointCatalogEntry) -> Self {
        let sourceLabel: String
        let sourceSymbol: String
        switch entry.source {
        case .primary:
            sourceLabel = "Manual quicksave"
            sourceSymbol = "square.and.arrow.down.fill"
        case .backup:
            sourceLabel = "Known-good backup"
            sourceSymbol = "arrow.clockwise.icloud.fill"
        case .autosave:
            sourceLabel = "Rotating autosave"
            sourceSymbol = "clock.arrow.circlepath"
        }

        guard let result = entry.loadResult, entry.integrity == .verified else {
            return Self(
                id: entry.id,
                title: "Recovery File Unavailable",
                sourceLabel: sourceLabel,
                sourceSymbol: sourceSymbol,
                checkpoint: "Unavailable checkpoint",
                detail: "Could not verify \(entry.fileName). The original file was left untouched.",
                modifiedAt: entry.modifiedAt,
                integrityLabel: "Integrity check failed",
                integritySymbol: "exclamationmark.triangle.fill",
                isLoadable: false
            )
        }

        let state = result.state
        let schemaLabel = result.schemaVersion == 0
            ? "Legacy save format"
            : "Save format v\(result.schemaVersion)"
        return Self(
            id: entry.id,
            title: state.cityName,
            sourceLabel: sourceLabel,
            sourceSymbol: sourceSymbol,
            checkpoint: "\(state.formattedDay) · \(state.population.formatted()) residents",
            detail: "\(state.treasury.currencyText) treasury · \(schemaLabel)",
            modifiedAt: entry.modifiedAt,
            integrityLabel: "Verified",
            integritySymbol: "checkmark.shield.fill",
            isLoadable: true
        )
    }
}

struct CityCheckpointLibraryPresentation: Equatable, Sendable {
    let title: String
    let detail: String
    let cards: [CityCheckpointCardPresentation]
    let verifiedCount: Int
    let invalidCount: Int

    static func make(_ entries: [SaveGameCheckpointCatalogEntry]) -> Self {
        let cards = entries.map(CityCheckpointCardPresentation.make)
        let verifiedCount = cards.filter(\.isLoadable).count
        let invalidCount = cards.count - verifiedCount
        let verifiedLabel = verifiedCount == 1
            ? "1 verified checkpoint"
            : "\(verifiedCount) verified checkpoints"
        let detail = invalidCount == 0
            ? "Choose a checkpoint to resume. Your current city remains unchanged until you confirm."
            : "Choose from \(verifiedLabel). \(invalidCount) recovery file"
                + (invalidCount == 1 ? " is" : "s are")
                + " visible but unavailable because integrity verification failed."
        return Self(
            title: "Load a Checkpoint",
            detail: detail,
            cards: cards,
            verifiedCount: verifiedCount,
            invalidCount: invalidCount
        )
    }
}
