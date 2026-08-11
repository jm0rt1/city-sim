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
    static let regionalCapitalQualificationCycles = 12
    static let strategyPhaseIntervalTicks = 64
    static let strategyMinimumWarningTicks = strategyPhaseIntervalTicks
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
        retireActiveStormRecoveryTarget(at: coordinate, in: &state)
        return .success(())
    }

    static func demolish(at coordinate: GridCoordinate, in state: inout CityGameState) -> Bool {
        guard let tile = state.tile(at: coordinate), tile.kind != .empty, tile.kind != .cityHall else { return false }
        state.treasury -= tile.kind.demolitionCost
        state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: .empty) }
        retireActiveStormRecoveryTarget(at: coordinate, in: &state)
        return true
    }

    private static func retireActiveStormRecoveryTarget(
        at coordinate: GridCoordinate,
        in state: inout CityGameState
    ) {
        guard var recovery = state.stormRecovery,
              recovery.disposition == .active,
              recovery.targets.contains(where: {
                  $0.coordinate == coordinate
              }) else { return }

        recovery.targets.removeAll { $0.coordinate == coordinate }
        if recovery.targets.isEmpty {
            recovery.disposition = .recovered
        }
        state.stormRecovery = recovery
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
        let commercialLevelGrowth = active
            .filter { $0.kind == .commercial }
            .reduce(0) { $0 + max(0, $1.level - 1) }
        let industrialLevelGrowth = active
            .filter { $0.kind == .industrial }
            .reduce(0) { $0 + max(0, $1.level - 1) }
        return (Double(state.population) * residentRevenueBase
                + Double(state.jobs) * employedResidentRevenueBase) * state.taxRate
            + Double(counts[.commercial] ?? 0) * commercialRevenue
            + Double(counts[.industrial] ?? 0) * industrialRevenue
            + Double(commercialLevelGrowth) * 45
            + Double(industrialLevelGrowth) * 60
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

    static func meetsRegionalCapitalStandards(in state: CityGameState) -> Bool {
        guard let story = state.progression?.strategy,
              story.currentPhase == .completed,
              story.recoveryResolution != nil else { return false }

        let active = activeTiles(in: state)
        let counts = Dictionary(grouping: active, by: \.kind).mapValues(\.count)
        let workforceTarget = max(1, state.population * 7 / 10)
        let employment = min(1, Double(state.jobs) / Double(workforceTarget))
        let sharedStandards = state.population >= 525
            && projectedBalance(in: state) >= 0
            && employment >= 0.92
            && utilityCoverage(in: state) >= 1
            && utilityReserve(in: state) >= 0.18

        guard sharedStandards else { return false }
        switch story.committedStrategy {
        case .commercialStewardship:
            return state.treasury >= 12_000
                && state.happiness >= 56
                && (counts[.commercial] ?? 0) >= 3
        case .industrialExpansion:
            return state.treasury >= 15_000
                && state.happiness >= 44
                && utilityReserve(in: state) >= 0.20
                && (counts[.industrial] ?? 0) >= 3
        }
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
        let commercialTiles = active.filter { $0.kind == .commercial }
        let industrialTiles = active.filter { $0.kind == .industrial }
        let commercialExpansion = max(0, commercialTiles.count - 1)
        let industrialExpansion = max(0, industrialTiles.count - 1)
        let commercialLevelGrowth = commercialTiles.reduce(0) {
            $0 + max(0, $1.level - 1)
        }
        let industrialLevelGrowth = industrialTiles.reduce(0) {
            $0 + max(0, $1.level - 1)
        }
        state.powerUsed = Int(Double(state.population) * 0.82)
            + commercialExpansion * 7 + industrialExpansion * 20
            + commercialLevelGrowth * 2 + industrialLevelGrowth * 2
        state.waterUsed = Int(Double(state.population) * 0.74)
            + commercialExpansion * 5 + industrialExpansion * 12
            + commercialLevelGrowth + industrialLevelGrowth
        let workforceTarget = max(1, state.population * 7 / 10)
        state.jobs = min(jobCapacity, workforceTarget)

        let utilityCoverage = utilityCoverage(in: state)
        let utilityReserve = utilityReserve(in: state)
        let employment = min(1, Double(jobCapacity) / Double(workforceTarget))
        let parkBonus = min(12, Double(counts[.park] ?? 0) * 3)
        let services = min(10, Double((counts[.fireStation] ?? 0) + (counts[.policeStation] ?? 0) + (counts[.school] ?? 0)) * 2.5)
        let pollution = min(
            26,
            Double(industrialTiles.count) * 3.5
                + Double(industrialLevelGrowth) * 0.5
                + Double(counts[.powerPlant] ?? 0) * 4
        )
        let taxPressure = max(0, state.taxRate - 0.10) * 140
        let shortagePressure = max(0, 0.98 - utilityCoverage) * 100
        let targetHappiness = 32 + utilityCoverage * 18 + employment * 16
            + min(4, utilityReserve * 20) + parkBonus + services
            - pollution - taxPressure - shortagePressure
        state.happiness += (targetHappiness - state.happiness) * 0.08
        state.happiness = min(100, max(0, state.happiness))
        state.approval += ((state.happiness - 50) * 0.08 - max(0, -state.treasury / 80_000))
        state.approval = min(100, max(0, state.approval))

        let housingVacancy = max(
            0,
            Double(residentialCapacity - state.population)
                / Double(max(1, residentialCapacity))
        )
        let employmentGap = max(0, 1 - employment)
        let jobCapacityUtilization = min(
            1,
            Double(state.jobs) / Double(max(1, jobCapacity))
        )
        let industrialEmploymentPressure = employment * jobCapacityUtilization
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
            0.36 + industrialEmploymentPressure * 0.35 + employmentGap * 0.65
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
            repairResidentialStormDamage(&state)
            issuePressureWarnings(&state)
            advanceStrategyStory(&state)
            maybeCreateEvent(&state)
            updateTownCharterProgression(&state)
            updateSecondActProgression(&state)
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
        let charterReviewActive = !(state.progression?.townCharterAwarded ?? false)
            && (state.progression?.townCharterQualifyingCycles ?? 0) > 0
        let regionalReviewActive = state.progression?.secondAct?.phase == .qualification
            && (state.progression?.secondAct?.qualifyingCycles ?? 0) > 0
        guard state.tick % 64 == 0,
              state.treasury >= 5_000,
              projectedBalance(in: state) >= 0,
              utilityCoverage(in: state) >= 1,
              !charterReviewActive,
              !regionalReviewActive
        else { return }

        let strategyKind: BuildingKind? = switch state.progression?.strategy?.committedStrategy {
        case .commercialStewardship: .commercial
        case .industrialExpansion: .industrial
        case nil: nil
        }
        let candidates = state.tiles.indices.filter { index in
            let tile = state.tiles[index]
            guard [.residential, .commercial, .industrial].contains(tile.kind),
                  strategyKind == nil || tile.kind == strategyKind,
                  tile.level < maximumDevelopmentLevel(for: tile.kind),
                  tile.constructionProgress >= 1,
                  tile.condition >= 0.75,
                  state.happiness >= minimumDevelopmentHappiness(for: tile.kind),
                  developmentDemand(for: tile.kind, in: state) >= minimumDevelopmentDemand(for: tile.kind),
                  preservesDevelopmentCashflow(afterDeveloping: tile.kind, in: state),
                  preservesProgressionUtilityReserve(afterDeveloping: tile.kind, in: state)
            else { return false }

            let utilization = Double(tile.occupancy)
                / Double(max(1, developmentCapacity(for: tile.kind, level: tile.level)))
            return utilization >= minimumDevelopmentUtilization(for: tile.level)
        }
        guard let index = candidates.sorted(by: { lhs, rhs in
            let left = state.tiles[lhs]
            let right = state.tiles[rhs]
            let leftPreferred = left.kind == strategyKind
            let rightPreferred = right.kind == strategyKind
            if leftPreferred != rightPreferred { return leftPreferred }

            let leftUtilization = Double(left.occupancy)
                / Double(max(1, developmentCapacity(for: left.kind, level: left.level)))
            let rightUtilization = Double(right.occupancy)
                / Double(max(1, developmentCapacity(for: right.kind, level: right.level)))
            if leftUtilization != rightUtilization {
                return leftUtilization > rightUtilization
            }
            if left.level != right.level { return left.level < right.level }
            if left.coordinate.y != right.coordinate.y {
                return left.coordinate.y < right.coordinate.y
            }
            return left.coordinate.x < right.coordinate.x
        }).first else { return }

        state.tiles[index].level += 1
        state.tiles[index].constructionProgress = 0.6
        let upgraded = state.tiles[index]
        post(
            CityMessage(
                tick: state.tick,
                severity: .good,
                title: "Neighborhood Upgraded",
                detail: "\(upgraded.kind.title) at block \(upgraded.coordinate.x + 1), \(upgraded.coordinate.y + 1) reached level \(upgraded.level) because occupancy and demand stayed strong. Capacity and the tax base increased, but developed levels also add upkeep\(upgraded.kind == .industrial ? ", pollution," : "") and utility load."
            ),
            to: &state
        )
    }

    private static func developmentCapacity(for kind: BuildingKind, level: Int) -> Int {
        switch kind {
        case .residential: 280 * max(1, level)
        case .commercial, .industrial: jobCapacity(for: kind) * max(1, level)
        default: 0
        }
    }

    private static func maximumDevelopmentLevel(for kind: BuildingKind) -> Int {
        switch kind {
        case .commercial: 2
        case .residential, .industrial: 3
        default: 1
        }
    }

    private static func developmentDemand(for kind: BuildingKind, in state: CityGameState) -> Double {
        switch kind {
        case .residential: state.demand.residential
        case .commercial: state.demand.commercial
        case .industrial: state.demand.industrial
        default: 0
        }
    }

    private static func minimumDevelopmentDemand(for kind: BuildingKind) -> Double {
        switch kind {
        case .residential: 0.45
        case .commercial: 0.38
        case .industrial: 0.34
        default: 1
        }
    }

    private static func minimumDevelopmentHappiness(for kind: BuildingKind) -> Double {
        switch kind {
        case .residential: 52
        case .commercial: 50
        case .industrial: 42
        default: 100
        }
    }

    private static func minimumDevelopmentUtilization(for level: Int) -> Double {
        switch level {
        case 1: 0.30
        case 2: 0.38
        default: 0.45
        }
    }

    private static func nearTermPopulationPotential(
        in state: CityGameState,
        additionalJobCapacity: Int = 0
    ) -> Int {
        let milestonePopulation = (state.progression?.townCharterAwarded ?? false) ? 525 : 500
        let employmentReach = max(
            120,
            (jobCapacity(in: state) + additionalJobCapacity) * 2
        )
        let reachablePopulation = min(housingCapacity(in: state), employmentReach)
        var horizonPopulation = state.population
        for _ in 0..<(strategyMinimumWarningTicks / 4)
            where horizonPopulation < reachablePopulation {
            let growth = max(
                1,
                Int(
                    Double(horizonPopulation)
                        * (0.0015 + state.demand.residential * 0.0015)
                )
            )
            horizonPopulation = min(reachablePopulation, horizonPopulation + growth)
        }
        return max(
            state.population,
            min(reachablePopulation, max(milestonePopulation, horizonPopulation))
        )
    }

    private static func preservesProgressionUtilityReserve(
        afterDeveloping kind: BuildingKind,
        in state: CityGameState
    ) -> Bool {
        let addedPower: Int
        let addedWater: Int
        switch kind {
        case .commercial:
            addedPower = 2
            addedWater = 1
        case .industrial:
            addedPower = 2
            addedWater = 1
        default:
            addedPower = 0
            addedWater = 0
        }

        let addedJobCapacity = jobCapacity(for: kind)
        let targetPopulation = nearTermPopulationPotential(
            in: state,
            additionalJobCapacity: addedJobCapacity
        )
        let nonPopulationPower = state.powerUsed - Int(Double(state.population) * 0.82)
        let nonPopulationWater = state.waterUsed - Int(Double(state.population) * 0.74)
        let active = activeTiles(in: state)
        let anticipatedExpansionPower: Int
        let anticipatedExpansionWater: Int
        if !(state.progression?.townCharterAwarded ?? false) {
            switch state.progression?.strategy?.committedStrategy {
            case .commercialStewardship:
                let remainingLots = max(0, 3 - active.filter { $0.kind == .commercial }.count)
                anticipatedExpansionPower = remainingLots * 7
                anticipatedExpansionWater = remainingLots * 5
            case .industrialExpansion:
                let remainingLots = max(0, 3 - active.filter { $0.kind == .industrial }.count)
                anticipatedExpansionPower = remainingLots * 20
                anticipatedExpansionWater = remainingLots * 12
            case nil:
                anticipatedExpansionPower = 0
                anticipatedExpansionWater = 0
            }
        } else {
            anticipatedExpansionPower = 0
            anticipatedExpansionWater = 0
        }
        let forecastPowerUsed = Int(Double(targetPopulation) * 0.82)
            + nonPopulationPower + anticipatedExpansionPower + addedPower
        let forecastWaterUsed = Int(Double(targetPopulation) * 0.74)
            + nonPopulationWater + anticipatedExpansionWater + addedWater
        let powerReserve = Double(state.powerCapacity - forecastPowerUsed)
            / Double(max(1, state.powerCapacity))
        let waterReserve = Double(state.waterCapacity - forecastWaterUsed)
            / Double(max(1, state.waterCapacity))
        let requiredReserve: Double
        if !(state.progression?.townCharterAwarded ?? false) {
            requiredReserve = 0.16
        } else if state.progression?.strategy?.committedStrategy == .industrialExpansion {
            requiredReserve = 0.21
        } else {
            requiredReserve = 0.19
        }
        return min(powerReserve, waterReserve) >= requiredReserve
    }

    private static func preservesDevelopmentCashflow(
        afterDeveloping kind: BuildingKind,
        in state: CityGameState
    ) -> Bool {
        projectedBalance(in: state) - kind.upkeep * upkeepMultiplier >= 0
    }

    private static let firstOrdinaryStormTick = 800

    private static func maybeCreateEvent(_ state: inout CityGameState) {
        guard state.population >= 500, state.tick >= 640, state.tick % 160 == 0 else { return }
        state.seed = state.seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let roll = Double(state.seed % 10_000) / 10_000
        let guaranteesFirstOrdinaryStorm = state.stormRecovery == nil
            && state.tick >= firstOrdinaryStormTick
        if guaranteesFirstOrdinaryStorm || roll < 0.22 {
            state.treasury -= 2_000
            state.happiness = max(0, state.happiness - 3)
            let outcome = weatherCompletedResidentialLots(in: &state)
            recordStormRecovery(
                eventTick: state.tick,
                eventSeed: state.seed,
                targets: outcome.targets,
                in: &state
            )
            let reservePercent = Int((outcome.utilityReserve * 100).rounded())
            let damagePercent = Int((outcome.damage * 100).rounded())
            let coordinates = outcome.coordinates
                .map { "\($0.x + 1), \($0.y + 1)" }
                .joined(separator: "; ")
            let damageDetail = if outcome.affectedCount > 0 {
                "weathered \(outcome.affectedCount) completed homes at blocks \(coordinates)"
            } else {
                "did not weather any completed homes"
            }
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Severe Storm",
                    detail: "Next decision: protect recovery by keeping utility reserve at or above 15%, or invest in a park or emergency service. Consequence: Emergency repairs cost $2,000, happiness fell 3 points, and \(damageDetail). Diagnosis: \(reservePercent)% utility reserve, \(outcome.parkCount) \(outcome.parkCount == 1 ? "park" : "parks"), and \(outcome.serviceCount) emergency services limited average damage to \(damagePercent)%. Objective: keep utilities fully covered with at least 15% reserve while parks and emergency services accelerate Residential repairs until all recorded storm damage clears."
                ),
                to: &state
            )
        } else if roll > 0.82 {
            state.treasury += 3_000
            state.messages.insert(CityMessage(tick: state.tick, severity: .good, title: "State Growth Grant", detail: "New Arcadia received $3,000 for responsible growth."), at: 0)
        }
    }

    private static func weatherCompletedResidentialLots(
        in state: inout CityGameState
    ) -> (
        affectedCount: Int,
        coordinates: [GridCoordinate],
        targets: [CityStormRecoveryTarget],
        damage: Double,
        utilityReserve: Double,
        parkCount: Int,
        serviceCount: Int
    ) {
        let active = activeTiles(in: state)
        let reserve = utilityReserve(in: state)
        let parkCount = active.filter { $0.kind == .park }.count
        let serviceCount = active.filter {
            [.fireStation, .policeStation, .school].contains($0.kind)
        }.count
        let utilityProtection = min(0.10, max(0, reserve) * 0.25)
        let parkProtection = min(0.06, Double(parkCount) * 0.02)
        let serviceProtection = min(0.12, Double(serviceCount) * 0.04)
        let damage = max(
            0.08,
            0.38 - utilityProtection - parkProtection - serviceProtection
        )

        let targets = state.tiles.indices
            .filter {
                state.tiles[$0].kind == .residential
                    && state.tiles[$0].constructionProgress >= 1
            }
            .sorted {
                let left = state.tiles[$0].coordinate
                let right = state.tiles[$1].coordinate
                if left.y != right.y { return left.y < right.y }
                return left.x < right.x
            }
            .prefix(3)
        var damagedTargets: [CityStormRecoveryTarget] = []
        for index in targets {
            let conditionBeforeStorm = state.tiles[index].condition
            let conditionAfterStorm = max(
                0,
                conditionBeforeStorm - damage
            )
            let actualDamage = conditionBeforeStorm - conditionAfterStorm
            state.tiles[index].condition = conditionAfterStorm
            if actualDamage > 0 {
                damagedTargets.append(
                    CityStormRecoveryTarget(
                        coordinate: state.tiles[index].coordinate,
                        remainingConditionDamage: actualDamage
                    )
                )
            }
        }
        let averageActualDamage = damagedTargets.isEmpty
            ? 0
            : damagedTargets.reduce(0) { $0 + $1.remainingConditionDamage }
                / Double(damagedTargets.count)

        return (
            affectedCount: damagedTargets.count,
            coordinates: damagedTargets.map(\.coordinate),
            targets: damagedTargets,
            damage: averageActualDamage,
            utilityReserve: reserve,
            parkCount: parkCount,
            serviceCount: serviceCount
        )
    }

    private static func recordStormRecovery(
        eventTick: Int,
        eventSeed: UInt64,
        targets newTargets: [CityStormRecoveryTarget],
        in state: inout CityGameState
    ) {
        guard !newTargets.isEmpty else { return }

        if var recovery = state.stormRecovery,
           recovery.disposition == .active {
            var damageByCoordinate = Dictionary(
                uniqueKeysWithValues: recovery.targets.map {
                    ($0.coordinate, max(0, $0.remainingConditionDamage))
                }
            )
            for target in newTargets {
                damageByCoordinate[target.coordinate, default: 0]
                    += max(0, target.remainingConditionDamage)
            }
            recovery.latestEventTick = eventTick
            recovery.latestEventSeed = eventSeed
            recovery.targets = damageByCoordinate.map {
                CityStormRecoveryTarget(
                    coordinate: $0.key,
                    remainingConditionDamage: $0.value
                )
            }
            .sorted { rowMajor($0.coordinate, before: $1.coordinate) }
            state.stormRecovery = recovery
        } else {
            state.stormRecovery = CityStormRecoveryState(
                latestEventTick: eventTick,
                latestEventSeed: eventSeed,
                targets: newTargets.sorted {
                    rowMajor($0.coordinate, before: $1.coordinate)
                },
                disposition: .active
            )
        }
    }

    private static func repairResidentialStormDamage(
        _ state: inout CityGameState
    ) {
        guard var recovery = state.stormRecovery,
              recovery.disposition == .active else { return }

        recovery.targets.removeAll { target in
            guard let tile = state.tile(at: target.coordinate) else { return true }
            return tile.kind != .residential || tile.constructionProgress < 1
        }
        for index in recovery.targets.indices {
            let coordinate = recovery.targets[index].coordinate
            let condition = state.tile(at: coordinate)?.condition ?? 1
            let recoverableDeficit = max(0, 1 - condition)
            recovery.targets[index].remainingConditionDamage = min(
                max(0, recovery.targets[index].remainingConditionDamage),
                recoverableDeficit
            )
        }
        if recovery.targets.allSatisfy({ $0.remainingConditionDamage == 0 }) {
            finishStormRecovery(&recovery, in: &state)
            return
        }

        let reserve = utilityReserve(in: state)
        guard utilityCoverage(in: state) >= 1,
              reserve >= 0.15 else {
            state.stormRecovery = recovery
            return
        }

        let active = activeTiles(in: state)
        let parkCount = active.filter { $0.kind == .park }.count
        let serviceCount = active.filter {
            [.fireStation, .policeStation, .school].contains($0.kind)
        }.count
        let dailyRepair = 0.04
            + min(0.03, Double(parkCount) * 0.01)
            + min(0.03, Double(serviceCount) * 0.01)

        for index in recovery.targets.indices {
            let coordinate = recovery.targets[index].coordinate
            let condition = state.tile(at: coordinate)?.condition ?? 1
            let headroom = max(0, 1 - condition)
            let appliedRepair = min(
                dailyRepair,
                recovery.targets[index].remainingConditionDamage,
                headroom
            )
            state.updateTile(at: coordinate) {
                $0.condition = min(1, $0.condition + appliedRepair)
            }
            recovery.targets[index].remainingConditionDamage = max(
                0,
                recovery.targets[index].remainingConditionDamage - appliedRepair
            )
        }

        guard recovery.targets.allSatisfy({
            $0.remainingConditionDamage <= 0.000_000_001
        }) else {
            state.stormRecovery = recovery
            return
        }
        finishStormRecovery(&recovery, in: &state)
    }

    private static func finishStormRecovery(
        _ recovery: inout CityStormRecoveryState,
        in state: inout CityGameState
    ) {
        for index in recovery.targets.indices {
            recovery.targets[index].remainingConditionDamage = 0
        }
        recovery.disposition = .recovered
        state.stormRecovery = recovery
        guard !recovery.targets.isEmpty else { return }

        let reserve = utilityReserve(in: state)
        let active = activeTiles(in: state)
        let parkCount = active.filter { $0.kind == .park }.count
        let serviceCount = active.filter {
            [.fireStation, .policeStation, .school].contains($0.kind)
        }.count
        let reservePercent = Int((reserve * 100).rounded())
        let lotLabel = recovery.targets.count == 1
            ? "Residential lot"
            : "Residential lots"
        post(
            CityMessage(
                tick: state.tick,
                severity: .good,
                title: "Storm Recovery Complete",
                detail: "\(recovery.targets.count) \(lotLabel) cleared their recorded storm damage. Current protection: \(reservePercent)% utility reserve, \(parkCount) \(parkCount == 1 ? "park" : "parks"), and \(serviceCount) emergency services. Keep utilities healthy to protect the recovery; Commercial and Industrial conditions were unchanged."
            ),
            to: &state
        )
    }

    private static func rowMajor(
        _ left: GridCoordinate,
        before right: GridCoordinate
    ) -> Bool {
        if left.y != right.y { return left.y < right.y }
        return left.x < right.x
    }

    private static func advanceStrategyStory(_ state: inout CityGameState) {
        var progression = state.progression ?? CityProgressionState()

        guard var story = progression.strategy else {
            guard let strategy = leadingStrategy(in: state) else { return }
            let opportunityTick = state.tick + strategyPhaseIntervalTicks
            progression.strategy = CityStrategyProgression(
                committedStrategy: strategy,
                currentPhase: .opportunity,
                nextScheduledTick: opportunityTick
            )
            state.progression = progression
            retireOpeningStrategyGuidance(in: &state)
            postStrategyCommitment(strategy, opportunityTick: opportunityTick, to: &state)
            return
        }

        if story.currentPhase == .completed {
            captureFirstQualifyingResolution(for: &story, in: state)
            progression.strategy = story
            state.progression = progression
            return
        }

        guard
              let scheduledTick = story.nextScheduledTick,
              state.tick >= scheduledTick else { return }

        let nextTick = state.tick + strategyPhaseIntervalTicks
        switch (story.committedStrategy, story.currentPhase) {
        case (.commercialStewardship, .opportunity):
            resolveCommercialOpportunity(&state)
            story.currentPhase = .complication
            story.nextScheduledTick = nextTick
        case (.industrialExpansion, .opportunity):
            resolveIndustrialOpportunity(&state)
            story.currentPhase = .complication
            story.nextScheduledTick = nextTick
        case (.commercialStewardship, .complication):
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Chain Store Rumor",
                    detail: "A regional chain opens by \(formattedDay(for: nextTick)). Accept lower tax at 9% or less, or fund a second park, to prevent the storefront slump; waiting preserves cash now but risks a $3,000 shock."
                ),
                to: &state
            )
            story.currentPhase = .setback
            story.nextScheduledTick = nextTick
        case (.industrialExpansion, .complication):
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Freight Load Forecast",
                    detail: "The freight surge lands by \(formattedDay(for: nextTick)). A second power plant and water tower, or a second park, prevents the load shock; waiting preserves capital now but risks $5,500 and livability."
                ),
                to: &state
            )
            story.currentPhase = .setback
            story.nextScheduledTick = nextTick
        case (.commercialStewardship, .setback):
            captureFirstQualifyingResolution(for: &story, in: state)
            resolveCommercialComplication(
                &state,
                resolution: story.recoveryResolution,
                recoveryTick: nextTick
            )
            story.currentPhase = .recovery
            story.nextScheduledTick = nextTick
        case (.industrialExpansion, .setback):
            captureFirstQualifyingResolution(for: &story, in: state)
            resolveIndustrialComplication(
                &state,
                resolution: story.recoveryResolution,
                recoveryTick: nextTick
            )
            story.currentPhase = .recovery
            story.nextScheduledTick = nextTick
        case (.commercialStewardship, .recovery):
            captureFirstQualifyingResolution(for: &story, in: state)
            resolveCommercialRecovery(&state, resolution: story.recoveryResolution)
            story.currentPhase = .completed
            story.nextScheduledTick = nil
        case (.industrialExpansion, .recovery):
            captureFirstQualifyingResolution(for: &story, in: state)
            resolveIndustrialRecovery(&state, resolution: story.recoveryResolution)
            story.currentPhase = .completed
            story.nextScheduledTick = nil
        case (_, .completed):
            story.nextScheduledTick = nil
        }

        progression.strategy = story
        state.progression = progression
    }

    private static func captureFirstQualifyingResolution(
        for story: inout CityStrategyProgression,
        in state: CityGameState
    ) {
        guard story.recoveryResolution == nil else { return }
        story.recoveryResolution = qualifyingResolution(for: story.committedStrategy, in: state)
    }

    private static func qualifyingResolution(
        for strategy: CityStrategy,
        in state: CityGameState
    ) -> CityStrategyRecoveryResolution? {
        let active = activeTiles(in: state)
        let parkCount = active.filter { $0.kind == .park }.count

        switch strategy {
        case .commercialStewardship:
            if state.taxRate <= 0.09 { return .commercialTaxRelief }
            if parkCount >= 2 { return .commercialPublicRealmInvestment }
        case .industrialExpansion:
            let hasReserveUtilities = active.filter { $0.kind == .powerPlant }.count >= 2
                && active.filter { $0.kind == .waterTower }.count >= 2
            if hasReserveUtilities { return .industrialUtilityExpansion }
            if parkCount >= 2 { return .industrialGreenBuffer }
        }
        return nil
    }

    private static func postStrategyCommitment(
        _ strategy: CityStrategy,
        opportunityTick: Int,
        to state: inout CityGameState
    ) {
        switch strategy {
        case .commercialStewardship:
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Main Street Crossroads",
                    detail: "Commercial stewardship is committed. A regional market weekend arrives by \(formattedDay(for: opportunityTick)); temporary tax relief or a second park can protect foot traffic from the chain-store complication that follows."
                ),
                to: &state
            )
        case .industrialExpansion:
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Freight Contract Watch",
                    detail: "Industrial expansion is committed. A regional freight contract arrives by \(formattedDay(for: opportunityTick)); reserve power and water or a second park can absorb the load complication that follows."
                ),
                to: &state
            )
        }
    }

    private static func resolveCommercialOpportunity(_ state: inout CityGameState) {
        let commercialCount = activeTiles(in: state).filter { $0.kind == .commercial }.count
        if commercialCount >= 3 {
            state.treasury += 2_400
            state.happiness = min(100, state.happiness + 1)
            state.approval = min(100, state.approval + 0.5)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Market Weekend",
                    detail: "Doubling down on storefronts produced a $2,400 festival return and more jobs. The larger district also has more utility exposure when the chain store arrives."
                ),
                to: &state
            )
        } else {
            state.treasury += 1_800
            state.happiness = min(100, state.happiness + 2)
            state.approval = min(100, state.approval + 1)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Market Weekend",
                    detail: "A measured Main Street generated $1,800 and civic pride. It earns less than a storefront push, but keeps utility exposure lower for the coming chain store."
                ),
                to: &state
            )
        }
    }

    private static func resolveIndustrialOpportunity(_ state: inout CityGameState) {
        let industrialCount = activeTiles(in: state).filter { $0.kind == .industrial }.count
        if industrialCount >= 3 {
            state.treasury += 6_500
            state.happiness = max(0, state.happiness - 2)
            state.approval = max(0, state.approval - 1)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Regional Freight Contract",
                    detail: "Doubling down on factories won a $6,500 freight return and more jobs. The faster payoff brings heavier pollution and utility exposure before the load surge."
                ),
                to: &state
            )
        } else {
            state.treasury += 5_000
            state.happiness = max(0, state.happiness - 1)
            state.approval = max(0, state.approval - 0.5)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Regional Freight Contract",
                    detail: "Measured industrial growth won $5,000 and more jobs. It earns less than a factory push, but limits pollution and utility exposure before the load surge."
                ),
                to: &state
            )
        }
    }

    private static func resolveCommercialComplication(
        _ state: inout CityGameState,
        resolution: CityStrategyRecoveryResolution?,
        recoveryTick: Int
    ) {
        if resolution == .commercialTaxRelief || resolution == .commercialPublicRealmInvestment {
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Storefront Slump Avoided",
                    detail: resolution == .commercialTaxRelief
                        ? "Early tax relief kept customers local. The city avoided the $3,000 shock, but accepted lower revenue and demand while the policy remains."
                        : "The second park kept Main Street busy. The city avoided the $3,000 shock after investing capital and upkeep in public space."
                ),
                to: &state
            )
        } else {
            state.treasury -= 3_000
            state.happiness = max(0, state.happiness - 5)
            state.approval = max(0, state.approval - 3)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .critical,
                    title: "Storefront Slump",
                    detail: "The chain drew shoppers away, costing $3,000 and confidence. Lower tax to 9% or less, or build a second park, before the \(formattedDay(for: recoveryTick)) recovery review."
                ),
                to: &state
            )
        }
    }

    private static func resolveIndustrialComplication(
        _ state: inout CityGameState,
        resolution: CityStrategyRecoveryResolution?,
        recoveryTick: Int
    ) {
        if resolution == .industrialUtilityExpansion || resolution == .industrialGreenBuffer {
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Industrial Load Absorbed",
                    detail: resolution == .industrialUtilityExpansion
                        ? "Early reserve utilities absorbed the surge. The city avoided the $5,500 shock after committing capital and upkeep to capacity."
                        : "The green buffer protected nearby blocks. The city avoided the $5,500 shock after committing capital and upkeep to public space."
                ),
                to: &state
            )
        } else {
            state.treasury -= 5_500
            state.happiness = max(0, state.happiness - 8)
            state.approval = max(0, state.approval - 5)
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .critical,
                    title: "Industrial Load Surge",
                    detail: "Freight traffic forced $5,500 in repairs and damaged livability. Add reserve power and water, or build a second park, before the \(formattedDay(for: recoveryTick)) recovery review."
                ),
                to: &state
            )
        }
    }

    private static func resolveCommercialRecovery(
        _ state: inout CityGameState,
        resolution: CityStrategyRecoveryResolution?
    ) {
        if resolution == .commercialTaxRelief {
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
        } else if resolution == .commercialPublicRealmInvestment {
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

    private static func resolveIndustrialRecovery(
        _ state: inout CityGameState,
        resolution: CityStrategyRecoveryResolution?
    ) {
        if resolution == .industrialUtilityExpansion {
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
        } else if resolution == .industrialGreenBuffer {
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

    private static func leadingStrategy(in state: CityGameState) -> CityStrategy? {
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

        if state.progression?.strategy == nil {
            postOnce(
                CityMessage(
                    tick: state.tick,
                    severity: .information,
                    title: "Choose a Growth Engine",
                    detail: "Add Commercial for cleaner, flexible growth or Industrial for faster jobs and cash with heavier pollution and utility load. The first successful route commits at the next daily review."
                ),
                to: &state
            )
        }

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

    private static func retireOpeningStrategyGuidance(in state: inout CityGameState) {
        state.messages.removeAll { $0.title == "Choose a Growth Engine" }
    }

    private static func formattedDay(for tick: Int) -> String {
        "Day \(tick / 4 + 1)"
    }

    private static func updateTownCharterProgression(_ state: inout CityGameState) {
        var progression = state.progression ?? CityProgressionState()
        guard !progression.townCharterAwarded else {
            state.progression = progression
            if progression.secondAct == nil {
                // Preserve the accepted legacy awarded + playing normalization.
                state.status = .won
            }
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
            progression.secondAct = CitySecondActProgression(
                phase: .mandate,
                nextScheduledTick: state.tick + strategyPhaseIntervalTicks
            )
        }
        state.progression = progression

        if awardedNow {
            postOnce(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Town Charter Awarded",
                    detail: "New Arcadia sustained healthy finances, employment, utilities, and livability for 12 consecutive days. The Charter is permanent; a Regional Capital mandate arrives by \(formattedDay(for: state.tick + strategyPhaseIntervalTicks))."
                ),
                to: &state
            )
        }
    }

    private static func updateSecondActProgression(_ state: inout CityGameState) {
        guard var progression = state.progression,
              var secondAct = progression.secondAct,
              let story = progression.strategy,
              !secondAct.regionalCapitalAwarded else { return }
        // Older awarded states can have a completed first-act strategy without
        // a recorded recovery choice. Keep those saves moving through the
        // already-scheduled second act without adding a schema field or
        // pretending that a choice was made retroactively.
        let resolution = story.recoveryResolution
            ?? deferredSecondActResolution(for: story.committedStrategy)

        switch secondAct.phase {
        case .mandate:
            guard let scheduledTick = secondAct.nextScheduledTick,
                  state.tick >= scheduledTick else { return }
            postRegionalWarning(for: story.committedStrategy, resolution: resolution, to: &state)
            secondAct.phase = .warnedPressure
            secondAct.nextScheduledTick = state.tick + strategyMinimumWarningTicks
        case .warnedPressure:
            guard let scheduledTick = secondAct.nextScheduledTick,
                  state.tick >= scheduledTick else { return }
            applyRegionalPressure(for: story.committedStrategy, resolution: resolution, to: &state)
            secondAct.phase = .recovery
            secondAct.nextScheduledTick = nil
        case .recovery:
            guard meetsSecondActRecovery(for: resolution, in: state) else { return }
            applyRegionalRecovery(for: story.committedStrategy, resolution: resolution, to: &state)
            secondAct.phase = .qualification
            secondAct.qualifyingCycles = 0
            secondAct.nextScheduledTick = nil
        case .qualification:
            if meetsRegionalCapitalStandards(in: state) {
                secondAct.qualifyingCycles = min(
                    regionalCapitalQualificationCycles,
                    secondAct.qualifyingCycles + 1
                )
            } else {
                secondAct.qualifyingCycles = 0
            }

            if secondAct.qualifyingCycles == regionalCapitalQualificationCycles {
                secondAct.phase = .completed
                secondAct.regionalCapitalAwarded = true
                state.status = .won
                applyRegionalCapitalPayoff(for: story.committedStrategy, to: &state)
            }
        case .completed:
            secondAct.nextScheduledTick = nil
        }

        progression.secondAct = secondAct
        state.progression = progression
    }

    private static func deferredSecondActResolution(
        for strategy: CityStrategy
    ) -> CityStrategyRecoveryResolution {
        switch strategy {
        case .commercialStewardship:
            .commercialTaxRelief
        case .industrialExpansion:
            .industrialUtilityExpansion
        }
    }

    private static func postRegionalWarning(
        for strategy: CityStrategy,
        resolution: CityStrategyRecoveryResolution,
        to state: inout CityGameState
    ) {
        let deadline = state.tick + strategyMinimumWarningTicks
        switch strategy {
        case .commercialStewardship:
            let remedy = resolution == .commercialTaxRelief
                ? "Lower tax to 8% or less after the pressure lands."
                : "Build a third park after the pressure lands."
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Regional Retail Challenge",
                    detail: "The Charter has drawn regional competitors. A $4,500 confidence shock lands by \(formattedDay(for: deadline)). \(remedy)"
                ),
                to: &state
            )
        case .industrialExpansion:
            let remedy = resolution == .industrialUtilityExpansion
                ? "Add a third Power Plant and Water Tower after the pressure lands."
                : "Build a third park after the pressure lands."
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .warning,
                    title: "Regional Grid Mandate",
                    detail: "The Charter has brought a regional freight-grid audit. A $7,000 repair and livability shock lands by \(formattedDay(for: deadline)). \(remedy)"
                ),
                to: &state
            )
        }
    }

    private static func applyRegionalPressure(
        for strategy: CityStrategy,
        resolution: CityStrategyRecoveryResolution,
        to state: inout CityGameState
    ) {
        switch strategy {
        case .commercialStewardship:
            state.treasury -= 4_500
            state.happiness = max(0, state.happiness - 5)
            state.approval = max(0, state.approval - 3)
            let stressedLots = applyDevelopmentPressure(
                to: .commercial,
                reductions: [0.66, 0.46],
                in: &state
            )
            let remedy = resolution == .commercialTaxRelief
                ? "Lower tax to 8% or less to restore local foot traffic."
                : "Build a third park to create a regional public-realm draw."
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .critical,
                    title: "Regional Retail Pressure",
                    detail: "Competitors pulled spending away, costing $4,500 and 5 happiness. \(stressedLots) developed storefront parcels now show the damage. \(remedy)"
                ),
                to: &state
            )
        case .industrialExpansion:
            state.treasury -= 7_000
            state.happiness = max(0, state.happiness - 8)
            state.approval = max(0, state.approval - 5)
            let stressedLots = applyDevelopmentPressure(
                to: .industrial,
                reductions: [0.72, 0.52],
                in: &state
            )
            let remedy = resolution == .industrialUtilityExpansion
                ? "Add a third Power Plant and Water Tower to prove regional reserve capacity."
                : "Build a third park to buffer freight pollution."
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .critical,
                    title: "Regional Freight Overload",
                    detail: "The grid audit exposed freight strain, costing $7,000 and 8 happiness. \(stressedLots) developed industrial parcels now show the damage. \(remedy)"
                ),
                to: &state
            )
        }
    }

    private static func meetsSecondActRecovery(
        for resolution: CityStrategyRecoveryResolution,
        in state: CityGameState
    ) -> Bool {
        let active = activeTiles(in: state)
        switch resolution {
        case .commercialTaxRelief:
            return state.taxRate <= 0.08
        case .commercialPublicRealmInvestment, .industrialGreenBuffer:
            return active.filter { $0.kind == .park }.count >= 3
        case .industrialUtilityExpansion:
            return active.filter { $0.kind == .powerPlant }.count >= 3
                && active.filter { $0.kind == .waterTower }.count >= 3
        }
    }

    private static func applyRegionalRecovery(
        for strategy: CityStrategy,
        resolution: CityStrategyRecoveryResolution,
        to state: inout CityGameState
    ) {
        switch strategy {
        case .commercialStewardship:
            state.treasury += 2_000
            state.happiness = min(100, state.happiness + 4)
            state.approval = min(100, state.approval + 3)
            let weatheredLots = repairDevelopmentPressure(
                for: .commercial,
                improvement: 0.34,
                in: &state
            )
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Regional Main Street Recovery",
                    detail: "\(resolution == .commercialTaxRelief ? "Tax relief restored local foot traffic." : "The third park became a regional destination.") Repairs stabilized the storefronts while \(weatheredLots) parcel remains weathered as a visible recovery record. The city recovered $2,000 and 4 happiness; now sustain 525 residents, $12,000, 56 happiness, 92% employment, balanced cashflow, and 18% utility reserve for 12 days."
                ),
                to: &state
            )
        case .industrialExpansion:
            state.treasury += 4_000
            state.happiness = min(100, state.happiness + 3)
            state.approval = min(100, state.approval + 2)
            let weatheredLots = repairDevelopmentPressure(
                for: .industrial,
                improvement: 0.36,
                in: &state
            )
            post(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Regional Freight Recovery",
                    detail: "\(resolution == .industrialUtilityExpansion ? "New utility reserves passed the grid audit." : "The third park buffered freight pollution.") Repairs stabilized the freight district while \(weatheredLots) parcel remains weathered as a visible recovery record. The city recovered $4,000 and 3 happiness; now sustain 525 residents, $15,000, 44 happiness, 92% employment, balanced cashflow, and 20% utility reserve for 12 days."
                ),
                to: &state
            )
        }
    }

    @discardableResult
    private static func applyDevelopmentPressure(
        to kind: BuildingKind,
        reductions: [Double],
        in state: inout CityGameState
    ) -> Int {
        let candidates = state.tiles.indices
            .filter {
                state.tiles[$0].kind == kind
                    && state.tiles[$0].constructionProgress >= 1
            }
            .sorted {
                let left = state.tiles[$0]
                let right = state.tiles[$1]
                if left.level != right.level { return left.level > right.level }
                if left.coordinate.y != right.coordinate.y {
                    return left.coordinate.y < right.coordinate.y
                }
                return left.coordinate.x < right.coordinate.x
            }
        let affected = min(candidates.count, reductions.count)
        for offset in 0..<affected {
            let index = candidates[offset]
            state.tiles[index].condition = max(
                0.2,
                state.tiles[index].condition - reductions[offset]
            )
        }
        return affected
    }

    @discardableResult
    private static func repairDevelopmentPressure(
        for kind: BuildingKind,
        improvement: Double,
        in state: inout CityGameState
    ) -> Int {
        for index in state.tiles.indices
        where state.tiles[index].kind == kind && state.tiles[index].condition < 1 {
            state.tiles[index].condition = min(
                1,
                state.tiles[index].condition + improvement
            )
        }
        return state.tiles.filter {
            $0.kind == kind && $0.condition >= 0.4 && $0.condition < 0.75
        }.count
    }

    private static func applyRegionalCapitalPayoff(
        for strategy: CityStrategy,
        to state: inout CityGameState
    ) {
        switch strategy {
        case .commercialStewardship:
            state.treasury += 8_000
            state.happiness = min(100, state.happiness + 6)
            state.approval = min(100, state.approval + 5)
            postOnce(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Regional Capital Recognized",
                    detail: "Twelve durable days proved New Arcadia's Main Street model. Regional Capital recognition grants $8,000, 6 happiness, and a permanent commercial-stewardship victory."
                ),
                to: &state
            )
        case .industrialExpansion:
            state.treasury += 12_000
            state.happiness = min(100, state.happiness + 3)
            state.approval = min(100, state.approval + 4)
            postOnce(
                CityMessage(
                    tick: state.tick,
                    severity: .good,
                    title: "Regional Capital Recognized",
                    detail: "Twelve durable days proved New Arcadia's freight network. Regional Capital recognition grants $12,000, 3 happiness, and a permanent industrial-expansion victory."
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
        guard state.status == .playing else { return }
        if state.treasury < -75_000 || (state.tick > 40 && state.happiness < 10) {
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
