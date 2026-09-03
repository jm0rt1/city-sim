import Foundation

/// A read-only index of the same upgrade evaluation used by the simulation and
/// selected-block outlook. Queue order is not an instruction to spend or build.
struct CityGrowthQueue: Equatable, Sendable {
    enum Filter: String, CaseIterable, Identifiable {
        case held, ready, building, all
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    struct Site: Equatable, Identifiable, Sendable {
        let coordinate: GridCoordinate
        let kind: BuildingKind
        let outlook: CityDevelopmentOutlook
        var id: GridCoordinate { coordinate }
        var title: String { "\(kind.title) · Block \(coordinate.x + 1), \(coordinate.y + 1)" }
        var requirementsText: String {
            outlook.requirements.isEmpty ? outlook.detail : outlook.requirements.joined(separator: " · ")
        }
    }

    let sites: [Site]
    static let pageSize = 2

    init(state: CityGameState) {
        sites = state.tiles.compactMap { tile in
            CityDevelopmentOutlook.make(tile: tile, state: state).map {
                Site(coordinate: tile.coordinate, kind: tile.kind, outlook: $0)
            }
        }.sorted { lhs, rhs in
            let left = Self.rank(lhs.outlook.status), right = Self.rank(rhs.outlook.status)
            if left != right { return left < right }
            if lhs.outlook.requirements.count != rhs.outlook.requirements.count {
                return lhs.outlook.requirements.count < rhs.outlook.requirements.count
            }
            if lhs.coordinate.y != rhs.coordinate.y { return lhs.coordinate.y < rhs.coordinate.y }
            return lhs.coordinate.x < rhs.coordinate.x
        }
    }

    func sites(matching filter: Filter) -> [Site] {
        sites.filter { site in
            switch filter {
            case .held: site.outlook.status == .held
            case .ready: site.outlook.status == .ready
            case .building: site.outlook.status == .building
            case .all: true
            }
        }
    }

    private static func rank(_ status: CityDevelopmentOutlook.Status) -> Int {
        switch status {
        case .ready: 0
        case .held: 1
        case .building: 2
        case .mature: 3
        }
    }
}
