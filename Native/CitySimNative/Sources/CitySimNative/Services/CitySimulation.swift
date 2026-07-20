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
    static let townCharterQualificationCycles = 12
    static let strategyWarningTick = 80
    static let strategyOpportunityTick = 160
    static let strategySetbackTick = 320
    static let strategyPayoffTick = 480
    static let commercialJobCapacity = 80
    static let industrialJobCapacity = 110
    static let powerCapacityPerPlant = 300
    static let waterCapacityPerTower = 270
    static let residentRevenueBase = 3.0
    static let employedResidentRevenueBase = 10.0
    static let commercialRevenue = 140.0
    static let industrialRevenue = 190.0
    static let upkeepMultiplier = 1.8
    static let reserveUtilityUpkeepFactor = 0.75

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
        let active = activeTiles(in: state)
        let grossUpkeep = active.reduce(0.0) {
            $0 + $1.kind.upkeep * Double(max(1, $1.level))
        }
        let reserveUtilityDiscount = [BuildingKind.powerPlant, .waterTower].reduce(0.0) { discount, kind in
            let reserveUnits = max(0, active.filter { $0.kind == kind }.count - 1)
            return discount + Double(reserveUnits) * kind.upkeep * (1 - reserveUtilityUpkeepFactor)
        }
        return (grossUpkeep - reserveUtilityDiscount) * upkeepMultiplier
            + max(0, -state.treasury) * 0.006
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

    static func meetsTownCharterStandards(in state: CityGameState) -> Bool {
        let active = activeTiles(in: state)
        let counts = Dictionary(grouping: active, by: \.kind).mapValues(\.count)
        let workforceTarget = max(1, state.population * 7 / 10)
        let employment = min(1, Double(state.jobs) / Double(workforceTarget))
        return state.population >= 500
            && state.treasury >= 10_000
            && projectedBalance(in: state) >= 0
            && employment >= 0.9
            && utilityCoverage(in: state) >= 1
            && utilityReserve(in: state) >= 0.15
            && state.happiness >= 52
            && (counts[.residential] ?? 0) >= 2
            && (counts[.commercial] ?? 0) >= 1
            && (counts[.industrial] ?? 0) >= 1
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
        let commercialExpansion = max(0, (counts[.commercial] ?? 0) - 1)
        let industrialExpansion = max(0, (counts[.industrial] ?? 0) - 1)
        state.powerUsed = Int(Double(state.population) * 0.82)
            + commercialExpansion * 7 + industrialExpansion * 20
        state.waterUsed = Int(Double(state.population) * 0.74)
            + commercialExpansion * 5 + industrialExpansion * 12
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
            advanceStrategyStory(&state)
            maybeCreateEvent(&state)
            updateTownCharterProgression(&state)
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
        guard state.population >= 500, state.tick >= 640, state.tick % 160 == 0 else { return }
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

    private static func advanceStrategyStory(_ state: inout CityGameState) {
        guard let strategy = leadingStrategy(in: state) else { return }
        if state.tick >= strategyWarningTick, state.tick < strategyOpportunityTick {
            switch strategy {
            case .commercialStewardship:
                postOnce(
                    CityMessage(
                        tick: state.tick,
                        severity: .warning,
                        title: "Main Street Crossroads",
                        detail: "A regional market weekend arrives by Day 41. Local shops can thrive, but the later storefront slump will need either temporary tax relief or a second park to restore foot traffic."
                    ),
                    to: &state
                )
            case .industrialExpansion:
                postOnce(
                    CityMessage(
                        tick: state.tick,
                        severity: .warning,
                        title: "Freight Contract Watch",
                        detail: "A regional freight contract arrives by Day 41. It will accelerate jobs and cash, then strain the district; reserve power and water or a second park can lead the recovery."
                    ),
                    to: &state
                )
            }
        }
        switch (strategy, state.tick) {
        case (.commercialStewardship, strategyOpportunityTick):
            state.treasury += 1_800
            state.happiness = min(100, state.happiness + 2)
            state.approval = min(100, state.approval + 1)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Market Weekend",
                    detail: "Independent shops generated a $1,800 revenue lift and a burst of civic pride. Main Street is prosperous, but its margins remain sensitive to the coming slowdown."
                ),
                to: &state
            )
        case (.industrialExpansion, strategyOpportunityTick):
            state.treasury += 5_000
            state.happiness = max(0, state.happiness - 1)
            state.approval = max(0, state.approval - 0.5)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Regional Freight Contract",
                    detail: "Factories landed a $5,000 freight contract and expanded the employment base. The faster return arrives with heavier utility demand and neighborhood pressure."
                ),
                to: &state
            )
        case (.commercialStewardship, strategySetbackTick):
            state.treasury -= 3_000
            state.happiness = max(0, state.happiness - 5)
            state.approval = max(0, state.approval - 3)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .critical,
                    title: "Storefront Slump",
                    detail: "A regional chain drew shoppers away, costing $3,000 and hurting confidence. Lower tax to 9% or less, or build a second park, before the 40-day recovery review."
                ),
                to: &state
            )
        case (.industrialExpansion, strategySetbackTick):
            state.treasury -= 5_500
            state.happiness = max(0, state.happiness - 8)
            state.approval = max(0, state.approval - 5)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .critical,
                    title: "Industrial Load Surge",
                    detail: "Freight traffic and overtime forced $5,500 in repairs and damaged livability. Add reserve power and water, or build a second park, before the 40-day recovery review."
                ),
                to: &state
            )
        case (.commercialStewardship, strategyPayoffTick):
            resolveCommercialRecovery(&state)
        case (.industrialExpansion, strategyPayoffTick):
            resolveIndustrialRecovery(&state)
        default:
            break
        }
    }

    private static func resolveCommercialRecovery(_ state: inout CityGameState) {
        let parkCount = activeTiles(in: state).filter { $0.kind == .park }.count
        if state.taxRate <= 0.09 {
            state.treasury += 1_500
            state.happiness = min(100, state.happiness + 7)
            state.approval = min(100, state.approval + 5)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Main Street Rebound",
                    detail: "Temporary tax relief brought customers back. Shops stabilized with a $1,500 recovery dividend and a major confidence gain."
                ),
                to: &state
            )
        } else if parkCount >= 2 {
            state.treasury += 2_500
            state.happiness = min(100, state.happiness + 6)
            state.approval = min(100, state.approval + 4)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Main Street Rebound",
                    detail: "The new park restored foot traffic without sacrificing the tax base. Shops delivered a $2,500 placemaking dividend."
                ),
                to: &state
            )
        } else {
            state.treasury -= 1_000
            state.happiness = max(0, state.happiness - 2)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Main Street Recovery Delayed",
                    detail: "Without tax relief or a second park, vacant storefronts cost another $1,000. The city remains playable, but commerce has not delivered its payoff."
                ),
                to: &state
            )
        }
    }

    private static func resolveIndustrialRecovery(_ state: inout CityGameState) {
        let active = activeTiles(in: state)
        let powerPlants = active.filter { $0.kind == .powerPlant }.count
        let waterTowers = active.filter { $0.kind == .waterTower }.count
        let parkCount = active.filter { $0.kind == .park }.count
        if powerPlants >= 2, waterTowers >= 2 {
            state.treasury += 5_500
            state.happiness = min(100, state.happiness + 2)
            state.approval = min(100, state.approval + 2)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Freight Network Secured",
                    detail: "Utility reserves absorbed the freight surge. Reliable factories renewed the contract and repaid the $5,500 disruption cost."
                ),
                to: &state
            )
        } else if parkCount >= 2 {
            state.treasury += 3_500
            state.happiness = min(100, state.happiness + 7)
            state.approval = min(100, state.approval + 5)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Cleaner Industry Compact",
                    detail: "A new green buffer won neighborhood support. Industry retained the contract with a $3,500 dividend and a strong livability recovery."
                ),
                to: &state
            )
        } else {
            state.treasury -= 2_000
            state.happiness = max(0, state.happiness - 3)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Freight Recovery Delayed",
                    detail: "Without utility reserves or a green buffer, emergency maintenance cost another $2,000. The city remains recoverable, but the contract payoff is deferred."
                ),
                to: &state
            )
        }
    }

    private static func leadingStrategy(in state: CityGameState) -> StrategyStory? {
        let commercial = state.tiles.filter { $0.kind == .commercial }.count
        let industrial = state.tiles.filter { $0.kind == .industrial }.count
        if commercial >= industrial + 1 { return .commercialStewardship }
        if industrial >= commercial + 1 { return .industrialExpansion }
        return nil
    }

    private static func issuePressureWarnings(_ state: inout CityGameState) {
        let balance = projectedBalance(in: state)
        let coverage = utilityCoverage(in: state)
        let reserve = utilityReserve(in: state)
        let workforceTarget = max(1, state.population * 7 / 10)
        let employment = min(1, Double(jobCapacity(in: state)) / Double(workforceTarget))

        postOnce(
            CityMessage(
                tick: state.tick,
                severity: .information,
                title: "Town Charter Standards",
                detail: "Reach 500 residents, $10,000 treasury, non-negative cashflow, 90% employment, full utilities with 15% reserve, and 52% happiness; keep every zone active for 12 consecutive days. Growth needs job openings and utility headroom."
            ),
            to: &state
        )

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
            let powerSpare = max(0, state.powerCapacity - state.powerUsed)
            let waterSpare = max(0, state.waterCapacity - state.waterUsed)
            let remedy = waterSpare <= powerSpare
                ? "Build a Water Tower ($8,500) before adding more homes or jobs."
                : "Build a Power Plant ($12,000) before adding more homes or jobs."
            postOnce(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Utility Reserve Tight",
                    detail: "Only \(powerSpare) power and \(waterSpare) water remain spare. \(remedy)"
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
        post(message, to: &state)
    }

    private static func post(_ message: CityMessage, to state: inout CityGameState) {
        state.messages.insert(message, at: 0)
        state.messages = Array(state.messages.prefix(12))
    }

    private static func updateTownCharterProgression(_ state: inout CityGameState) {
        var progression = state.progression ?? CityProgressionState()
        guard !progression.townCharterAwarded else {
            state.progression = progression
            return
        }

        if meetsTownCharterStandards(in: state) {
            progression.townCharterQualifyingCycles = min(
                townCharterQualificationCycles,
                progression.townCharterQualifyingCycles + 1
            )
        } else {
            progression.townCharterQualifyingCycles = 0
        }

        let awardedNow = progression.townCharterQualifyingCycles == townCharterQualificationCycles
        if awardedNow {
            progression.townCharterAwarded = true
        }
        state.progression = progression

        if awardedNow {
            postOnce(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Town Charter Awarded",
                    detail: "New Arcadia sustained healthy finances, employment, utilities, and livability for 12 consecutive days. The Town Charter is now permanent."
                ),
                to: &state
            )
        }
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

private enum StrategyStory {
    case commercialStewardship
    case industrialExpansion
}

private extension Int {
    func formatted() -> String { NumberFormatter.localizedString(from: NSNumber(value: self), number: .decimal) }
}
