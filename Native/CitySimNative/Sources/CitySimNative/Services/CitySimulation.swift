import Foundation

enum BuildRejection: Error, Equatable {
    case outsideMap, occupied, insufficientFunds, roadAccessRequired, uniqueBuildingExists

    var message: String {
        switch self {
        case .outsideMap: "That location is outside the city limits."
        case .occupied: "Demolish the existing structure before building here."
        case .insufficientFunds: "The city treasury cannot fund this project."
        case .roadAccessRequired: "This building needs direct road access."
        case .uniqueBuildingExists: "Only one City Hall may be built."
        }
    }
}

enum CitySimulation {
    static func validateBuild(
        _ kind: BuildingKind,
        at coordinate: GridCoordinate,
        in state: CityGameState
    ) -> Result<Void, BuildRejection> {
        guard let existing = state.tile(at: coordinate) else { return .failure(.outsideMap) }
        guard existing.kind == .empty else { return .failure(.occupied) }
        guard state.treasury >= kind.buildCost else { return .failure(.insufficientFunds) }
        if kind.requiresRoad && !state.neighbors(of: coordinate).contains(where: { $0.kind == .road }) {
            return .failure(.roadAccessRequired)
        }
        if kind == .cityHall && state.tiles.contains(where: { $0.kind == .cityHall }) {
            return .failure(.uniqueBuildingExists)
        }
        return .success(())
    }

    static func build(_ kind: BuildingKind, at coordinate: GridCoordinate, in state: inout CityGameState) -> Result<Void, BuildRejection> {
        let validation = validateBuild(kind, at: coordinate, in: state)
        guard case .success = validation else { return validation }
        state.treasury -= kind.buildCost
        state.updateTile(at: coordinate) {
            $0.kind = kind
            $0.level = 1
            $0.occupancy = 0
            $0.condition = 1
            $0.constructionProgress = kind == .road ? 1 : 0
        }
        return .success(())
    }

    static func demolish(at coordinate: GridCoordinate, in state: inout CityGameState) -> Bool {
        guard let tile = state.tile(at: coordinate), tile.kind != .empty, tile.kind != .cityHall else { return false }
        state.treasury -= max(50, tile.kind.buildCost * 0.08)
        state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: .empty) }
        return true
    }

    static func step(_ state: inout CityGameState) {
        guard state.status == .playing else { return }
        let previousPopulation = state.population
        state.tick += 1

        for index in state.tiles.indices where state.tiles[index].constructionProgress < 1 {
            state.tiles[index].constructionProgress = min(1, state.tiles[index].constructionProgress + 0.25)
        }

        let active = state.tiles.filter { $0.constructionProgress >= 1 }
        let counts = Dictionary(grouping: active, by: \.kind).mapValues(\.count)
        let residentialCapacity = active.filter { $0.kind == .residential }.reduce(0) { $0 + 280 * $1.level }
        let jobCapacity = active.reduce(0) { partial, tile in
            partial + (tile.kind == .commercial ? 170 * tile.level : tile.kind == .industrial ? 240 * tile.level : 0)
        }
        state.powerCapacity = (counts[.powerPlant] ?? 0) * 2_200
        state.waterCapacity = (counts[.waterTower] ?? 0) * 2_000
        state.powerUsed = Int(Double(state.population) * 0.82)
        state.waterUsed = Int(Double(state.population) * 0.74)
        state.jobs = min(jobCapacity, Int(Double(state.population) * 0.72))

        let utilityCoverage = min(
            1,
            min(Double(state.powerCapacity) / Double(max(1, state.powerUsed)),
                Double(state.waterCapacity) / Double(max(1, state.waterUsed)))
        )
        let employment = min(1, Double(jobCapacity) / Double(max(1, state.population * 7 / 10)))
        let parkBonus = min(12, Double(counts[.park] ?? 0) * 1.8)
        let services = min(10, Double((counts[.fireStation] ?? 0) + (counts[.policeStation] ?? 0) + (counts[.school] ?? 0)) * 2.4)
        let pollution = min(24, Double(counts[.industrial] ?? 0) * 1.6 + Double(counts[.powerPlant] ?? 0) * 4)
        let targetHappiness = 42 + utilityCoverage * 20 + employment * 12 + parkBonus + services - pollution - max(0, state.taxRate - 0.10) * 120
        state.happiness += (targetHappiness - state.happiness) * 0.12
        state.happiness = min(100, max(0, state.happiness))
        state.approval += ((state.happiness - 50) * 0.08 - max(0, -state.treasury / 80_000))
        state.approval = min(100, max(0, state.approval))

        let attractiveCapacity = min(residentialCapacity, max(120, jobCapacity * 2))
        if state.population < attractiveCapacity && utilityCoverage > 0.8 && state.happiness > 48 {
            let growth = max(2, Int(Double(state.population) * (0.006 + state.demand.residential * 0.004)))
            state.population = min(attractiveCapacity, state.population + growth)
        } else if utilityCoverage < 0.65 || state.happiness < 32 {
            state.population = max(0, state.population - max(2, state.population / 100))
        }

        let revenue = Double(state.population) * 55 * state.taxRate
            + Double(counts[.commercial] ?? 0) * 240
            + Double(counts[.industrial] ?? 0) * 310
        let upkeep = active.reduce(0.0) { $0 + $1.kind.upkeep * Double(max(1, $1.level)) } * 1.8
        let debtInterest = max(0, -state.treasury) * 0.006
        state.treasury += revenue - upkeep - debtInterest

        state.demand.residential = clamp(0.35 + employment * 0.45 + (state.happiness - 50) / 120 - Double(residentialCapacity - state.population) / 4_000)
        state.demand.commercial = clamp(Double(state.population) / Double(max(1, (counts[.commercial] ?? 0) * 550 + 350)))
        state.demand.industrial = clamp(0.35 + Double(residentialCapacity - jobCapacity) / 4_000)

        rebalanceOccupancy(&state, capacity: residentialCapacity)
        maybeUpgrade(&state)
        maybeCreateEvent(&state)
        checkMilestones(&state, previousPopulation: previousPopulation)
        checkEndState(&state)
    }

    private static func rebalanceOccupancy(_ state: inout CityGameState, capacity: Int) {
        let residential = state.tiles.indices.filter { state.tiles[$0].kind == .residential && state.tiles[$0].constructionProgress >= 1 }
        let perBuilding = residential.isEmpty ? 0 : min(280, state.population / residential.count)
        for index in residential { state.tiles[index].occupancy = perBuilding }
        let jobsPerBuilding = max(0, state.jobs / max(1, state.tiles.filter { [.commercial, .industrial].contains($0.kind) }.count))
        for index in state.tiles.indices where [.commercial, .industrial].contains(state.tiles[index].kind) {
            state.tiles[index].occupancy = jobsPerBuilding
        }
    }

    private static func maybeUpgrade(_ state: inout CityGameState) {
        guard state.tick % 20 == 0 else { return }
        for index in state.tiles.indices {
            let tile = state.tiles[index]
            guard [.residential, .commercial, .industrial].contains(tile.kind), tile.level < 4,
                  tile.constructionProgress >= 1, tile.occupancy > 150, state.happiness > 58 else { continue }
            state.tiles[index].level += 1
            state.tiles[index].constructionProgress = 0.6
            state.messages.insert(CityMessage(tick: state.tick, severity: .good, title: "Neighborhood Upgraded", detail: "Strong demand has attracted denser development."), at: 0)
            break
        }
    }

    private static func maybeCreateEvent(_ state: inout CityGameState) {
        guard state.tick % 28 == 0 else { return }
        state.seed = state.seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let roll = Double(state.seed % 10_000) / 10_000
        if roll < 0.22 {
            state.treasury -= 4_500
            state.happiness = max(0, state.happiness - 5)
            state.messages.insert(CityMessage(tick: state.tick, severity: .warning, title: "Severe Storm", detail: "Emergency repairs cost $4,500. Resilient services soften future shocks."), at: 0)
        } else if roll > 0.82 {
            state.treasury += 7_500
            state.messages.insert(CityMessage(tick: state.tick, severity: .good, title: "State Growth Grant", detail: "New Arcadia received $7,500 for responsible growth."), at: 0)
        }
    }

    private static func checkMilestones(_ state: inout CityGameState, previousPopulation: Int) {
        for milestone in [500, 1_000, 1_500, 2_000] where previousPopulation < milestone && state.population >= milestone {
            state.treasury += 10_000
            state.messages.insert(CityMessage(tick: state.tick, severity: .good, title: "Population Milestone", detail: "\(milestone.formatted()) residents! A $10,000 development grant was awarded."), at: 0)
        }
        state.messages = Array(state.messages.prefix(12))
    }

    private static func checkEndState(_ state: inout CityGameState) {
        if state.population >= 2_500 && state.happiness >= 65 && state.treasury >= 0 {
            state.status = .won
        } else if state.treasury < -75_000 || (state.tick > 40 && state.happiness < 10) {
            state.status = .lost
        }
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
}

private extension Int {
    func formatted() -> String { NumberFormatter.localizedString(from: NSNumber(value: self), number: .decimal) }
}
