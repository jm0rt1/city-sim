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
    static let commercialJobCapacity = 80
    static let industrialJobCapacity = 110
    static let powerCapacityPerPlant = 300
    static let waterCapacityPerTower = 270
    static let residentRevenueBase = 3.0
    static let employedResidentRevenueBase = 10.0
    static let commercialRevenue = 140.0
    static let industrialRevenue = 190.0
    static let upkeepMultiplier = 1.8

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
        state.treasury -= tile.kind.demolitionCost
        state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: .empty) }
        return true
    }

    static func activeTiles(in state: CityGameState) -> [CityTile] {
        state.tiles.filter { $0.constructionProgress >= 1 }
    }

    static func housingCapacity(in state: CityGameState) -> Int {
        activeTiles(in: state)
            .filter { $0.kind == .residential }
            .reduce(0) { $0 + 280 * $1.level }
    }

    static func jobCapacity(in state: CityGameState) -> Int {
        activeTiles(in: state).reduce(0) { partial, tile in
            partial + jobCapacity(for: tile.kind) * max(1, tile.level)
        }
    }

    static func jobCapacity(for kind: BuildingKind) -> Int {
        switch kind {
        case .commercial: commercialJobCapacity
        case .industrial: industrialJobCapacity
        default: 0
        }
    }

    static func projectedRevenue(in state: CityGameState) -> Double {
        let active = activeTiles(in: state)
        let counts = Dictionary(grouping: active, by: \.kind).mapValues(\.count)
        return (Double(state.population) * residentRevenueBase
                + Double(state.jobs) * employedResidentRevenueBase) * state.taxRate
            + Double(counts[.commercial] ?? 0) * commercialRevenue
            + Double(counts[.industrial] ?? 0) * industrialRevenue
    }

    static func projectedUpkeep(in state: CityGameState) -> Double {
        activeTiles(in: state).reduce(0.0) {
            $0 + $1.kind.upkeep * Double(max(1, $1.level))
        } * upkeepMultiplier + max(0, -state.treasury) * 0.006
    }

    static func projectedBalance(in state: CityGameState) -> Double {
        projectedRevenue(in: state) - projectedUpkeep(in: state)
    }

    static func utilityCoverage(in state: CityGameState) -> Double {
        min(
            1,
            min(
                Double(state.powerCapacity) / Double(max(1, state.powerUsed)),
                Double(state.waterCapacity) / Double(max(1, state.waterUsed))
            )
        )
    }

    static func utilityReserve(in state: CityGameState) -> Double {
        min(
            reserve(capacity: state.powerCapacity, used: state.powerUsed),
            reserve(capacity: state.waterCapacity, used: state.waterUsed)
        )
    }

    static func step(_ state: inout CityGameState) {
        guard state.status == .playing else { return }
        let previousPopulation = state.population
        state.tick += 1

        for index in state.tiles.indices where state.tiles[index].constructionProgress < 1 {
            state.tiles[index].constructionProgress = min(1, state.tiles[index].constructionProgress + 0.25)
        }

        let active = activeTiles(in: state)
        let counts = Dictionary(grouping: active, by: \.kind).mapValues(\.count)
        let residentialCapacity = housingCapacity(in: state)
        let jobCapacity = jobCapacity(in: state)
        state.powerCapacity = (counts[.powerPlant] ?? 0) * powerCapacityPerPlant
        state.waterCapacity = (counts[.waterTower] ?? 0) * waterCapacityPerTower
        state.powerUsed = Int(Double(state.population) * 0.82)
        state.waterUsed = Int(Double(state.population) * 0.74)
        let workforceTarget = max(1, state.population * 7 / 10)
        state.jobs = min(jobCapacity, workforceTarget)

        let utilityCoverage = utilityCoverage(in: state)
        let utilityReserve = utilityReserve(in: state)
        let employment = min(1, Double(jobCapacity) / Double(workforceTarget))
        let parkBonus = min(12, Double(counts[.park] ?? 0) * 3)
        let services = min(10, Double((counts[.fireStation] ?? 0) + (counts[.policeStation] ?? 0) + (counts[.school] ?? 0)) * 2.5)
        let pollution = min(26, Double(counts[.industrial] ?? 0) * 3.5 + Double(counts[.powerPlant] ?? 0) * 4)
        let taxPressure = max(0, state.taxRate - 0.10) * 140
        let shortagePressure = max(0, 0.98 - utilityCoverage) * 100
        let targetHappiness = 32 + utilityCoverage * 18 + employment * 16
            + min(4, utilityReserve * 20) + parkBonus + services
            - pollution - taxPressure - shortagePressure
        state.happiness += (targetHappiness - state.happiness) * 0.08
        state.happiness = min(100, max(0, state.happiness))
        state.approval += ((state.happiness - 50) * 0.08 - max(0, -state.treasury / 80_000))
        state.approval = min(100, max(0, state.approval))

        let housingVacancy = max(0, Double(residentialCapacity - state.population) / Double(max(1, residentialCapacity)))
        let employmentGap = max(0, 1 - employment)
        state.demand.residential = clamp(
            0.50 + employment * 0.28 + (state.happiness - 50) / 140
                + min(0.15, utilityReserve * 0.45) - housingVacancy * 0.35
                - max(0, state.taxRate - 0.10) * 2.5
        )
        state.demand.commercial = clamp(
            0.38 + Double(state.population) / 1_000 + employmentGap * 0.9
                - Double(counts[.commercial] ?? 0) * 0.09
                - max(0, state.taxRate - 0.10) * 2
        )
        state.demand.industrial = clamp(
            0.36 + (1 - housingVacancy) * 0.35 + employmentGap * 0.65
                - pollution / 140 - max(0, state.taxRate - 0.10)
        )

        if state.tick.isMultiple(of: 4) {
            let attractiveCapacity = min(residentialCapacity, max(120, jobCapacity * 2))
            if state.population < attractiveCapacity && utilityCoverage > 0.88 && state.happiness > 45 {
                let growth = max(1, Int(Double(state.population) * (0.0015 + state.demand.residential * 0.0015)))
                state.population = min(attractiveCapacity, state.population + growth)
            } else if utilityCoverage < 0.82 || state.happiness < 32 {
                state.population = max(0, state.population - max(1, state.population / 150))
            }
            state.treasury += projectedBalance(in: state)
        }

        rebalanceOccupancy(&state, capacity: residentialCapacity)
        maybeUpgrade(&state)
        if state.tick.isMultiple(of: 4) {
            issuePressureWarnings(&state)
            maybeCreateEvent(&state)
            checkMilestones(&state, previousPopulation: previousPopulation)
            checkEndState(&state)
        }
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
        guard state.population >= 500, state.tick % 160 == 0 else { return }
        state.seed = state.seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let roll = Double(state.seed % 10_000) / 10_000
        if roll < 0.22 {
            state.treasury -= 2_000
            state.happiness = max(0, state.happiness - 3)
            state.messages.insert(CityMessage(tick: state.tick, severity: .warning, title: "Severe Storm", detail: "Emergency repairs cost $2,000. Resilient services soften future shocks."), at: 0)
        } else if roll > 0.82 {
            state.treasury += 3_000
            state.messages.insert(CityMessage(tick: state.tick, severity: .good, title: "State Growth Grant", detail: "New Arcadia received $3,000 for responsible growth."), at: 0)
        }
    }

    private static func issuePressureWarnings(_ state: inout CityGameState) {
        let balance = projectedBalance(in: state)
        let coverage = utilityCoverage(in: state)
        let reserve = utilityReserve(in: state)
        let workforceTarget = max(1, state.population * 7 / 10)
        let employment = min(1, Double(jobCapacity(in: state)) / Double(workforceTarget))

        if balance < 0 {
            postOnce(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Budget Gap",
                    detail: "Operations are projected to use \((-balance).currencyText) per cycle. Add taxable activity or accept the happiness cost of a temporary tax increase."
                ),
                to: &state
            )
        }
        if reserve < 0.12, coverage >= 0.98 {
            postOnce(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Utility Reserve Tight",
                    detail: "Only \(max(0, state.powerCapacity - state.powerUsed)) power and \(max(0, state.waterCapacity - state.waterUsed)) water remain spare. Expansion now risks a shortfall."
                ),
                to: &state
            )
        }
        if coverage < 0.98 {
            postOnce(
                CityMessage(
                    tick: state.tick,
                    severity: .critical,
                    title: "Utility Shortfall",
                    detail: "Power or water is below current use. Growth has stalled and livability will keep falling until capacity or demand changes."
                ),
                to: &state
            )
        }
        if employment < 0.82 {
            postOnce(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Hiring Bottleneck",
                    detail: "The town is short \(max(0, workforceTarget - state.jobs)) filled jobs. Commercial growth is cleaner; industry restores the tax base faster but adds pollution."
                ),
                to: &state
            )
        }
    }

    private static func postOnce(_ message: CityMessage, to state: inout CityGameState) {
        guard !state.messages.contains(where: { $0.title == message.title }) else { return }
        state.messages.insert(message, at: 0)
        state.messages = Array(state.messages.prefix(12))
    }

    private static func checkMilestones(_ state: inout CityGameState, previousPopulation: Int) {
        for milestone in [500, 1_000, 1_500, 2_000] where previousPopulation < milestone && state.population >= milestone {
            state.messages.insert(CityMessage(tick: state.tick, severity: .good, title: "Population Milestone", detail: "\(milestone.formatted()) residents. Growth alone is not enough: protect the treasury, jobs, utilities, and livability to earn the Town Charter."), at: 0)
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

    private static func reserve(capacity: Int, used: Int) -> Double {
        guard capacity > 0 else { return 0 }
        return max(0, Double(capacity - used) / Double(capacity))
    }
}

private extension Int {
    func formatted() -> String { NumberFormatter.localizedString(from: NSNumber(value: self), number: .decimal) }
}
