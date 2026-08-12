import Foundation

struct CityCheckpointSupportFeedback: Equatable, Sendable {
    let message: String
    let isError: Bool
}

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
    let canBranch: Bool
    let canExportSupportReport: Bool

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
        case .branch:
            sourceLabel = "Named timeline branch"
            sourceSymbol = "arrow.triangle.branch"
        case .scenario:
            sourceLabel = "Authored scenario checkpoint"
            sourceSymbol = "flag.checkered"
        }

        guard let result = entry.loadResult, entry.integrity == .verified else {
            let issue = entry.issue ?? .unreadable
            return Self(
                id: entry.id,
                title: issue.title,
                sourceLabel: sourceLabel,
                sourceSymbol: sourceSymbol,
                checkpoint: "Unavailable checkpoint",
                detail: "\(issue.explanation) The original file was left untouched.",
                modifiedAt: entry.modifiedAt,
                integrityLabel: "Integrity check failed",
                integritySymbol: "exclamationmark.triangle.fill",
                isLoadable: false,
                canBranch: false,
                canExportSupportReport: true
            )
        }

        let state = result.state
        let schemaLabel = result.schemaVersion == 0
            ? "Legacy save format"
            : "Save format v\(result.schemaVersion)"
        let checkpoint = [.branch, .scenario].contains(entry.source)
            ? "\(state.cityName) · \(state.formattedDay) · \(state.population.formatted()) residents"
            : "\(state.formattedDay) · \(state.population.formatted()) residents"
        return Self(
            id: entry.id,
            title: entry.branchName ?? entry.scenarioCheckpointTitle ?? state.cityName,
            sourceLabel: sourceLabel,
            sourceSymbol: sourceSymbol,
            checkpoint: checkpoint,
            detail: "\(state.treasury.currencyText) treasury · \(schemaLabel)",
            modifiedAt: entry.modifiedAt,
            integrityLabel: "Verified",
            integritySymbol: "checkmark.shield.fill",
            isLoadable: true,
            canBranch: true,
            canExportSupportReport: false
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
            ? "Load a checkpoint, or preserve any verified moment as a named timeline branch."
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
