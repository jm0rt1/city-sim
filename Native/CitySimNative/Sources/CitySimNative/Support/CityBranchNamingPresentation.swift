import Foundation

struct CityBranchNamingPresentation: Equatable, Sendable {
    let title: String
    let checkpoint: String
    let detail: String
    let sourceLabel: String
    let sourceSymbol: String
    let createActionTitle: String

    static func make(state: CityGameState, source: SaveGameSource?) -> Self {
        let sourceLabel: String
        let sourceSymbol: String
        let detail: String
        switch source {
        case .autosave:
            sourceLabel = "Branch from rotating autosave"
            sourceSymbol = "clock.arrow.circlepath"
            detail = "Preserve this automatic checkpoint as a named timeline without loading it or changing the current city."
        case .branch:
            sourceLabel = "Branch from named timeline"
            sourceSymbol = "arrow.triangle.branch"
            detail = "Preserve this checkpoint under a new timeline name without changing the current city."
        case .primary:
            sourceLabel = "Branch from manual quicksave"
            sourceSymbol = "square.and.arrow.down.fill"
            detail = "Preserve this manual checkpoint under a timeline name without changing the current city."
        case .backup:
            sourceLabel = "Branch from known-good backup"
            sourceSymbol = "arrow.clockwise.icloud.fill"
            detail = "Preserve this recovery checkpoint under a timeline name without changing the current city."
        case .scenario:
            sourceLabel = "Branch from scenario checkpoint"
            sourceSymbol = "flag.checkered"
            detail = "Preserve this authored milestone under a timeline name without changing the current city."
        case .migration:
            sourceLabel = "Branch from upgraded legacy copy"
            sourceSymbol = "arrow.up.doc.fill"
            detail = "Preserve this upgraded checkpoint under a timeline name without changing the current city."
        case nil:
            sourceLabel = "Branch from current city"
            sourceSymbol = "building.2.crop.circle.fill"
            detail = "Preserve the city exactly as it is now, then continue playing on the current timeline."
        }
        return Self(
            title: "Create Timeline Branch",
            checkpoint: "\(state.cityName) · \(state.formattedDay) · "
                + "\(state.population.formatted()) residents",
            detail: detail,
            sourceLabel: sourceLabel,
            sourceSymbol: sourceSymbol,
            createActionTitle: "Create Branch"
        )
    }
}
