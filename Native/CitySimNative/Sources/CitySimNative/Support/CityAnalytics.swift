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
        let industrial = activeTiles.filter { $0.kind == .industrial }
        let levelGrowth = industrial.reduce(0) {
            $0 + max(0, $1.level - 1)
        }
        return min(
            100,
            Double(industrial.count) * 8
                + Double(levelGrowth) * 2
                + Double(count(.powerPlant)) * 20
        )
    }

    var serviceBuildings: Int {
        count(.fireStation) + count(.policeStation) + count(.school)
    }

    var awaitingStrategyChoice: Bool {
        state.progression?.strategy == nil
    }

    var committedStrategy: CityStrategy? {
        state.progression?.strategy?.committedStrategy
    }

    var strategyPhase: CityStrategyPhase? {
        state.progression?.strategy?.currentPhase
    }

    var strategyRecoveryResolution: CityStrategyRecoveryResolution? {
        state.progression?.strategy?.recoveryResolution
    }

    var strategyDaysUntilConsequence: Int? {
        guard let nextTick = state.progression?.strategy?.nextScheduledTick else { return nil }
        let remainingTicks = max(0, nextTick - state.tick)
        return (remainingTicks + 3) / 4
    }

    var strategyObjective: CityObjective? {
        guard let strategy = committedStrategy,
              let phase = strategyPhase,
              phase != .completed else { return nil }

        let days = strategyDaysUntilConsequence ?? 0
        let progress: Double = switch phase {
        case .opportunity: 0.25
        case .complication: 0.50
        case .setback: 0.65
        case .recovery: 0.80
        case .completed: 1
        }

        switch strategy {
        case .commercialStewardship:
            let response = strategyRecoveryResolution == nil
                ? "Lower tax to 9% or build a second park"
                : "Keep the city stable while the response resolves"
            let title = phase == .recovery ? "Recover Main Street" : "Protect Main Street"
            let remaining = if phase == .recovery, strategyRecoveryResolution == nil {
                "The storefront slump cost $3,000 and 5 happiness. Lower tax to 9% or build a second park within \(days) days to restore local foot traffic."
            } else if phase == .recovery {
                "Response secured; keep the city stable for \(days) days to earn the recovery payoff."
            } else {
                "Chain-store pressure arrives in \(days) days. \(response) to protect local foot traffic."
            }
            return CityObjective(
                id: "strategy",
                title: title,
                detail: "Guide Commercial growth through a market opportunity, chain-store pressure, and a recovery payoff.",
                progress: progress,
                remaining: remaining
            )
        case .industrialExpansion:
            let response = strategyRecoveryResolution == nil
                ? "Add a second Power Plant and Water Tower, or build a second park"
                : "Keep the city stable while the response resolves"
            let title = phase == .recovery ? "Recover the Freight Network" : "Secure the Freight Network"
            let remaining = if phase == .recovery, strategyRecoveryResolution == nil {
                "The freight load cost $5,500 and 8 happiness. Add a second Power Plant and Water Tower, or build a second park within \(days) days to protect the contract."
            } else if phase == .recovery {
                "Response secured; keep the city stable for \(days) days to earn the recovery payoff."
            } else {
                "Freight pressure arrives in \(days) days. \(response) to protect the contract."
            }
            return CityObjective(
                id: "strategy",
                title: title,
                detail: "Guide Industrial growth through a freight contract, load pressure, and a recovery payoff.",
                progress: progress,
                remaining: remaining
            )
        }
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

    var secondActPhase: CitySecondActPhase? {
        state.progression?.secondAct?.phase
    }

    var secondActDaysUntilConsequence: Int? {
        guard let nextTick = state.progression?.secondAct?.nextScheduledTick else { return nil }
        let remainingTicks = max(0, nextTick - state.tick)
        return (remainingTicks + 3) / 4
    }

    var regionalCapitalQualifyingCycles: Int {
        state.progression?.secondAct?.qualifyingCycles ?? 0
    }

    var regionalCapitalAwarded: Bool {
        state.progression?.secondAct?.regionalCapitalAwarded ?? false
    }

    var meetsRegionalCapitalStandards: Bool {
        CitySimulation.meetsRegionalCapitalStandards(in: state)
    }

    var regionalCapitalStatusText: String {
        guard townCharterAwarded else { return "Earn the Town Charter to open the Regional Capital mandate" }
        guard let secondAct = state.progression?.secondAct else {
            return "Legacy Charter victory remains complete"
        }
        if secondAct.regionalCapitalAwarded {
            return "Regional Capital recognition secured permanently"
        }

        let resolution = strategyRecoveryResolution
        switch secondAct.phase {
        case .mandate:
            if resolution == nil {
                return committedStrategy == .commercialStewardship
                    ? "Finish recovery: lower tax to 9% or build a second park"
                    : "Finish recovery: add reserve utilities or build a second park"
            }
            return "Regional mandate arrives in \(secondActDaysUntilConsequence ?? 0) days"
        case .warnedPressure:
            return "Pressure lands in \(secondActDaysUntilConsequence ?? 0) days · protect cash and livability"
        case .recovery:
            switch resolution {
            case .commercialTaxRelief:
                return "Lower tax to 8% or less to restore local foot traffic"
            case .commercialPublicRealmInvestment:
                return "Build a third park to create a regional destination"
            case .industrialUtilityExpansion:
                return "Add a third Power Plant and Water Tower for reserve capacity"
            case .industrialGreenBuffer:
                return "Build a third park to buffer freight pollution"
            case nil:
                return "Complete the established recovery before qualification"
            }
        case .qualification:
            if state.population < 525 {
                return "Grow \((525 - state.population).formatted()) residents without losing daily standards"
            }
            if committedStrategy == .commercialStewardship {
                if state.treasury < 12_000 { return "Restore the treasury to $12,000" }
                if state.happiness < 56 { return "Raise happiness to 56%" }
                if count(.commercial) < 3 { return "Maintain three active Commercial zones" }
            } else {
                if state.treasury < 15_000 { return "Restore the treasury to $15,000" }
                if state.happiness < 44 { return "Raise happiness to 44%" }
                if count(.industrial) < 3 { return "Maintain three active Industrial zones" }
                if utilityReserve < 0.20 { return "Build 20% utility reserve" }
            }
            if projectedBalance < 0 {
                return "Close the \((-projectedBalance).currencyText) operating gap"
            }
            if employmentRate < 0.92 { return "Raise employment to 92%" }
            if utilityCoverage < 1 { return "Restore complete utility coverage" }
            if utilityReserve < 0.18 { return "Build 18% utility reserve" }
            return "\(regionalCapitalQualifyingCycles) of \(CitySimulation.regionalCapitalQualificationCycles) qualifying days complete"
        case .completed:
            return "Regional Capital recognition secured permanently"
        }
    }

    var townCharterStatusText: String {
        if townCharterAwarded {
            if state.progression?.secondAct == nil {
                return "Town Charter secured permanently · Charter victory is complete"
            }
            return "Town Charter secured · Regional Capital chapter is active"
        }
        if waterHeadroom == 0 {
            return "Next: add water capacity · then grow \(max(0, 500 - state.population)) residents"
        }
        if powerHeadroom == 0 {
            return "Next: add power capacity · then grow \(max(0, 500 - state.population)) residents"
        }
        if state.happiness < 45 {
            return "Next: restore utilities or parks to lift happiness \(Int(ceil(52 - state.happiness))) points"
        }
        if state.population < 500 {
            // The charter's 500-resident review has a 350-person workforce
            // target; 90% employment therefore requires 315 available jobs.
            let charterWorkforceTarget = 500 * 7 / 10
            let charterJobCapacity = Int(ceil(Double(charterWorkforceTarget) * 0.9))
            if jobCapacity < charterJobCapacity {
                return "Next: prepare \(charterJobCapacity - jobCapacity) jobs · grow \((500 - state.population).formatted()) residents"
            }
            return "Next: grow \((500 - state.population).formatted()) residents with 15% utility reserve"
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
