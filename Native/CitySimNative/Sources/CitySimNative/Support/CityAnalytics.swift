import Foundation

struct CityAnalytics {
    let state: CityGameState

    private var activeTiles: [CityTile] {
        state.tiles.filter { $0.constructionProgress >= 1 }
    }

    func count(_ kind: BuildingKind) -> Int {
        activeTiles.filter { $0.kind == kind }.count
    }

    var housingCapacity: Int {
        activeTiles.filter { $0.kind == .residential }.reduce(0) { $0 + 280 * $1.level }
    }

    var jobCapacity: Int {
        activeTiles.reduce(0) { result, tile in
            result + (tile.kind == .commercial ? 170 * tile.level : tile.kind == .industrial ? 240 * tile.level : 0)
        }
    }

    var housingHeadroom: Int {
        max(0, housingCapacity - state.population)
    }

    var jobHeadroom: Int {
        max(0, jobCapacity - state.jobs)
    }

    var powerHeadroom: Int {
        max(0, state.powerCapacity - state.powerUsed)
    }

    var waterHeadroom: Int {
        max(0, state.waterCapacity - state.waterUsed)
    }

    var housingUtilization: Double {
        min(1, Double(state.population) / Double(max(1, housingCapacity)))
    }

    var jobUtilization: Double {
        min(1, Double(state.jobs) / Double(max(1, jobCapacity)))
    }

    var employmentRate: Double {
        min(1, Double(state.jobs) / Double(max(1, state.population * 7 / 10)))
    }

    var utilityCoverage: Double {
        min(
            1,
            min(
                Double(state.powerCapacity) / Double(max(1, state.powerUsed)),
                Double(state.waterCapacity) / Double(max(1, state.waterUsed))
            )
        )
    }

    var projectedRevenue: Double {
        Double(state.population) * 55 * state.taxRate
            + Double(count(.commercial)) * 240
            + Double(count(.industrial)) * 310
    }

    var projectedUpkeep: Double {
        activeTiles.reduce(0.0) { $0 + $1.kind.upkeep * Double(max(1, $1.level)) } * 1.8
            + max(0, -state.treasury) * 0.006
    }

    var projectedBalance: Double { projectedRevenue - projectedUpkeep }

    var pollutionPressure: Double {
        min(100, Double(count(.industrial)) * 8 + Double(count(.powerPlant)) * 20)
    }

    var serviceBuildings: Int {
        count(.fireStation) + count(.policeStation) + count(.school)
    }

    func hasRoadAccess(at coordinate: GridCoordinate) -> Bool {
        let neighbors = [
            GridCoordinate(x: coordinate.x, y: coordinate.y - 1),
            GridCoordinate(x: coordinate.x + 1, y: coordinate.y),
            GridCoordinate(x: coordinate.x, y: coordinate.y + 1),
            GridCoordinate(x: coordinate.x - 1, y: coordinate.y)
        ]
        return neighbors.contains { state.tile(at: $0)?.kind == .road }
    }

    func capacity(for tile: CityTile) -> Int {
        switch tile.kind {
        case .residential: 280 * tile.level
        case .commercial: 170 * tile.level
        case .industrial: 240 * tile.level
        default: 0
        }
    }
}
