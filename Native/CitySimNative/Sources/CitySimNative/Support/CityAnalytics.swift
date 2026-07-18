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
}
