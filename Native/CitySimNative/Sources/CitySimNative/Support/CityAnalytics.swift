import Foundation

struct CityAnalytics {
    let state: CityGameState

    private var activeTiles: [CityTile] {
        CitySimulation.activeTiles(in: state)
    }

    func count(_ kind: BuildingKind) -> Int {
        activeTiles.filter { $0.kind == kind }.count
    }

    var housingCapacity: Int {
        CitySimulation.housingCapacity(in: state)
    }

    var jobCapacity: Int {
        CitySimulation.jobCapacity(in: state)
    }

    var workforceTarget: Int {
        max(1, state.population * 7 / 10)
    }

    var jobShortfall: Int {
        max(0, workforceTarget - state.jobs)
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
        min(1, Double(state.jobs) / Double(workforceTarget))
    }

    var utilityCoverage: Double {
        CitySimulation.utilityCoverage(in: state)
    }

    var utilityReserve: Double {
        CitySimulation.utilityReserve(in: state)
    }

    var projectedRevenue: Double {
        CitySimulation.projectedRevenue(in: state)
    }

    var projectedUpkeep: Double {
        CitySimulation.projectedUpkeep(in: state)
    }

    var projectedBalance: Double { CitySimulation.projectedBalance(in: state) }

    var operatingRunwayCycles: Double? {
        guard projectedBalance < 0, state.treasury > 0 else { return nil }
        return state.treasury / -projectedBalance
    }

    var pollutionPressure: Double {
        min(100, Double(count(.industrial)) * 8 + Double(count(.powerPlant)) * 20)
    }

    var serviceBuildings: Int {
        count(.fireStation) + count(.policeStation) + count(.school)
    }

    var meetsTownCharterStandards: Bool {
        CitySimulation.meetsTownCharterStandards(in: state)
    }

    var townCharterQualifyingCycles: Int {
        state.progression?.townCharterQualifyingCycles ?? 0
    }

    var townCharterAwarded: Bool {
        state.progression?.townCharterAwarded ?? false
    }

    var townCharterStatusText: String {
        if townCharterAwarded {
            return "Town Charter secured permanently"
        }
        if state.population < 500 {
            return "\((500 - state.population).formatted()) residents to charter review"
        }
        if state.treasury < 10_000 {
            return "Restore the treasury to $10,000"
        }
        if projectedBalance < 0 {
            return "Close the \((-projectedBalance).currencyText) operating gap"
        }
        if employmentRate < 0.9 {
            return "Raise employment to 90%"
        }
        if utilityCoverage < 1 {
            return "Restore complete utility coverage"
        }
        if utilityReserve < 0.15 {
            return "Build 15% utility reserve"
        }
        if state.happiness < 52 {
            return "Raise happiness to 52%"
        }
        if count(.residential) < 2 || count(.commercial) < 1 || count(.industrial) < 1 {
            return "Maintain residential, commercial, and industrial activity"
        }
        return "\(townCharterQualifyingCycles) of \(CitySimulation.townCharterQualificationCycles) qualifying days complete"
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
        case .commercial, .industrial: CitySimulation.jobCapacity(for: tile.kind) * tile.level
        default: 0
        }
    }
}
