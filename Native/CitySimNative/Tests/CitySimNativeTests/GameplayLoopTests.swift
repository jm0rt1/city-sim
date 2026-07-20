import Foundation
import XCTest
@testable import CitySimNative

final class GameplayLoopTests: XCTestCase {
    func testLiveCommercialRecoveryReachesACharterPathByDay128() throws {
        var state = CityGameState.newCity(seed: 42)
        advanceToTick(&state, tick: 148)
        try build(.commercial, at: GridCoordinate(x: 8, y: 11), in: &state)
        advance(&state, cycles: 4)
        try build(.powerPlant, at: GridCoordinate(x: 7, y: 11), in: &state)
        state.taxRate = 0.14
        advanceToTick(&state, tick: 509)

        let analytics = CityAnalytics(state: state)
        XCTAssertTrue(state.messages.contains { $0.title == "Main Street Crossroads" })
        XCTAssertTrue(state.messages.contains { $0.title == "Main Street Recovery Delayed" })
        XCTAssertGreaterThan(analytics.projectedBalance, 0)
        XCTAssertGreaterThanOrEqual(state.treasury, BuildingKind.waterTower.buildCost)
        XCTAssertEqual(analytics.waterHeadroom, 0)
        XCTAssertTrue(analytics.townCharterStatusText.contains("add water capacity"))
        XCTAssertGreaterThanOrEqual(state.population, 390)

        try buildFirstValid(.waterTower, in: &state)
        advanceUntil(&state, maximumCycles: 40) {
            $0.treasury >= BuildingKind.commercial.buildCost
        }
        try buildFirstValid(.commercial, in: &state)
        state.taxRate = 0.10
        advanceUntil(&state, maximumCycles: 240) {
            $0.progression?.townCharterAwarded == true
        }

        XCTAssertTrue(state.progression?.townCharterAwarded ?? false)
        XCTAssertLessThanOrEqual(state.tick, 2_200)
        XCTAssertEqual(state.status, .playing)
    }

    func testBothDiscoverableStrategiesReachDurablePayoffWithInteractionMargin() throws {
        var commerce = CityGameState.newCity(seed: 42)
        advanceToTick(&commerce, tick: 148)
        try buildFirstValid(.commercial, in: &commerce)
        advanceToTick(&commerce, tick: CitySimulation.strategyOpportunityTick)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Main Street Crossroads" })
        XCTAssertTrue(commerce.messages.contains { $0.title == "Market Weekend" })
        advanceToTick(&commerce, tick: CitySimulation.strategySetbackTick)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Storefront Slump" })
        try buildFirstValid(.park, in: &commerce)
        advanceToTick(&commerce, tick: CitySimulation.strategyPayoffTick)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Main Street Rebound" })
        try prepareCharterCapacity(in: &commerce, jobs: .commercial)
        commerce.taxRate = 0.10
        let commerceAwardTick = advanceUntil(&commerce, maximumCycles: 430) {
            $0.progression?.townCharterAwarded == true
        }

        var industry = CityGameState.newCity(seed: 42)
        advanceToTick(&industry, tick: 148)
        try buildFirstValid(.industrial, in: &industry)
        advanceToTick(&industry, tick: CitySimulation.strategyOpportunityTick)
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Contract Watch" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Regional Freight Contract" })
        advanceToTick(&industry, tick: CitySimulation.strategySetbackTick)
        XCTAssertTrue(industry.messages.contains { $0.title == "Industrial Load Surge" })
        try prepareReserveUtilities(in: &industry)
        advanceToTick(&industry, tick: CitySimulation.strategyPayoffTick)
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Network Secured" })
        try prepareCharterCapacity(in: &industry, jobs: .industrial)
        industry.taxRate = 0.10
        let industryAwardTick = advanceUntil(&industry, maximumCycles: 430) {
            $0.progression?.townCharterAwarded == true
        }

        XCTAssertLessThanOrEqual(commerceAwardTick, 2_200)
        XCTAssertLessThanOrEqual(industryAwardTick, 2_200)
        XCTAssertEqual(commerceAwardTick, 900)
        XCTAssertEqual(industryAwardTick, 848)
        XCTAssertGreaterThan(commerce.happiness, industry.happiness)
        XCTAssertGreaterThan(CityAnalytics(state: industry).pollutionPressure, CityAnalytics(state: commerce).pollutionPressure)
        XCTAssertGreaterThan(CityAnalytics(state: industry).jobCapacity, CityAnalytics(state: commerce).jobCapacity)
        XCTAssertTrue(commerce.progression?.townCharterAwarded ?? false)
        XCTAssertTrue(industry.progression?.townCharterAwarded ?? false)
    }

    func testOpeningExposesARealButRecoverableTradeoff() {
        let state = CityGameState.newCity(seed: 42)
        let analytics = CityAnalytics(state: state)

        XCTAssertEqual(state.treasury, 26_000)
        XCTAssertEqual(state.population, 300)
        XCTAssertEqual(analytics.jobShortfall, 20)
        XCTAssertEqual(analytics.powerHeadroom, 54)
        XCTAssertEqual(analytics.waterHeadroom, 48)
        XCTAssertEqual(analytics.employmentRate, 190.0 / 210.0, accuracy: 0.000_001)
        XCTAssertEqual(analytics.utilityReserve, 48.0 / 270.0, accuracy: 0.000_001)
        XCTAssertEqual(analytics.projectedBalance, -61.4, accuracy: 0.001)
        XCTAssertGreaterThan(analytics.operatingRunwayCycles ?? 0, 400)
        XCTAssertGreaterThan(state.demand.residential, 0.7)
        XCTAssertTrue(state.messages.contains { $0.title == "A Town at the Crossroads" })
    }

    func testIgnoredGrowthWarnsBeforeAUtilityShortfallAndCanRecover() throws {
        var state = CityGameState.newCity(seed: 42)

        advanceUntil(&state, maximumCycles: 120) {
            $0.messages.contains { $0.title == "Utility Shortfall" }
        }

        XCTAssertTrue(state.messages.contains { $0.title == "Utility Reserve Tight" })
        XCTAssertTrue(state.messages.contains { $0.title == "Hiring Bottleneck" })
        XCTAssertLessThan(CityAnalytics(state: state).utilityCoverage, 0.98)
        XCTAssertEqual(state.status, .playing)

        state.taxRate = 0.18
        advance(&state, cycles: 24)
        try build(.powerPlant, at: GridCoordinate(x: 8, y: 11), in: &state)
        try build(.waterTower, at: GridCoordinate(x: 7, y: 11), in: &state)
        try build(.industrial, at: GridCoordinate(x: 6, y: 11), in: &state)
        advance(&state, cycles: 8)

        let recovered = CityAnalytics(state: state)
        XCTAssertEqual(recovered.utilityCoverage, 1, accuracy: 0.000_001)
        XCTAssertGreaterThan(recovered.utilityReserve, 0.4)
        XCTAssertGreaterThan(recovered.projectedBalance, 0)
        XCTAssertGreaterThan(state.treasury, 0)
        XCTAssertGreaterThan(state.happiness, 35)
        XCTAssertEqual(state.status, .playing)
    }

    func testTwoStrategiesEarnTheCharterAndSurviveTheTwentyMinuteHorizon() throws {
        var industryFirst = try industrialStrategy()
        advance(&industryFirst, cycles: 4)
        try build(.powerPlant, at: GridCoordinate(x: 6, y: 11), in: &industryFirst)
        try build(.waterTower, at: GridCoordinate(x: 5, y: 11), in: &industryFirst)
        advanceToTick(&industryFirst, tick: CitySimulation.strategyPayoffTick)

        var commerceAndTax = try commercialStrategy()
        commerceAndTax.taxRate = 0.10
        advanceToTick(&commerceAndTax, tick: CitySimulation.strategyOpportunityTick)
        try build(.powerPlant, at: GridCoordinate(x: 6, y: 11), in: &commerceAndTax)
        try build(.waterTower, at: GridCoordinate(x: 5, y: 11), in: &commerceAndTax)
        advanceToTick(&commerceAndTax, tick: CitySimulation.strategySetbackTick)
        commerceAndTax.taxRate = 0.09
        advanceToTick(&commerceAndTax, tick: CitySimulation.strategyPayoffTick)

        XCTAssertTrue(industryFirst.messages.contains { $0.title == "Freight Network Secured" })
        XCTAssertTrue(commerceAndTax.messages.contains { $0.title == "Main Street Rebound" })
        commerceAndTax.taxRate = 0.10

        advanceToTick(&industryFirst, tick: 896)
        advanceToTick(&commerceAndTax, tick: 896)

        let industryAnalytics = CityAnalytics(state: industryFirst)
        let commerceAnalytics = CityAnalytics(state: commerceAndTax)
        XCTAssertGreaterThan(industryAnalytics.jobCapacity, commerceAnalytics.jobCapacity)
        XCTAssertGreaterThan(industryAnalytics.pollutionPressure, commerceAnalytics.pollutionPressure)
        XCTAssertLessThan(industryAnalytics.utilityReserve, commerceAnalytics.utilityReserve)
        XCTAssertNotEqual(industryFirst.treasury, commerceAndTax.treasury)
        XCTAssertNotEqual(industryFirst.happiness, commerceAndTax.happiness)
        XCTAssertGreaterThanOrEqual(industryFirst.population, 500)
        XCTAssertGreaterThanOrEqual(commerceAndTax.population, 500)

        // 700 cycles × 4 pulses × 0.42 seconds is approximately a 19.6-minute 1× session.
        advanceToTick(&industryFirst, tick: 2_800)
        advanceToTick(&commerceAndTax, tick: 2_800)
        XCTAssertEqual(industryFirst.tick, 2_800)
        XCTAssertEqual(commerceAndTax.tick, 2_800)
        XCTAssertEqual(industryFirst.day, 701)
        XCTAssertEqual(commerceAndTax.day, 701)
        XCTAssertEqual(industryFirst.population, 560)
        XCTAssertEqual(commerceAndTax.population, 700)
        XCTAssertEqual(industryFirst.treasury, 207_957, accuracy: 0.001)
        XCTAssertEqual(commerceAndTax.treasury, 112_703.6, accuracy: 0.001)
        XCTAssertEqual(industryFirst.jobs, 392)
        XCTAssertEqual(commerceAndTax.jobs, 350)
        XCTAssertEqual(industryFirst.happiness, 53.866_666, accuracy: 0.001)
        XCTAssertEqual(commerceAndTax.happiness, 53.328_571, accuracy: 0.001)
        XCTAssertEqual(industryFirst.powerUsed, 499)
        XCTAssertEqual(commerceAndTax.powerUsed, 588)
        XCTAssertEqual(industryFirst.waterUsed, 438)
        XCTAssertEqual(commerceAndTax.waterUsed, 528)
        XCTAssertTrue(industryFirst.progression?.townCharterAwarded ?? false)
        XCTAssertTrue(commerceAndTax.progression?.townCharterAwarded ?? false)
        XCTAssertEqual(industryFirst.status, .playing)
        XCTAssertEqual(commerceAndTax.status, .playing)
        XCTAssertGreaterThan(industryFirst.treasury, 0)
        XCTAssertGreaterThan(commerceAndTax.treasury, 0)
    }

    func testStrategyStoriesWarnOnDailyBoundaryAndCreateDifferentOpportunities() throws {
        var commerce = try commercialStrategy()
        var industry = try industrialStrategy()

        advanceToTick(&commerce, tick: CitySimulation.strategyWarningTick - 1)
        advanceToTick(&industry, tick: CitySimulation.strategyWarningTick - 1)
        XCTAssertFalse(commerce.messages.contains { $0.title == "Main Street Crossroads" })
        XCTAssertFalse(industry.messages.contains { $0.title == "Freight Contract Watch" })

        CitySimulation.step(&commerce)
        CitySimulation.step(&industry)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Main Street Crossroads" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Contract Watch" })

        advanceToTick(&commerce, tick: CitySimulation.strategyOpportunityTick)
        advanceToTick(&industry, tick: CitySimulation.strategyOpportunityTick)
        let commerceAnalytics = CityAnalytics(state: commerce)
        let industryAnalytics = CityAnalytics(state: industry)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Market Weekend" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Regional Freight Contract" })
        XCTAssertGreaterThan(industry.treasury, commerce.treasury)
        XCTAssertGreaterThan(industryAnalytics.jobCapacity, commerceAnalytics.jobCapacity)
        XCTAssertGreaterThan(industryAnalytics.pollutionPressure, commerceAnalytics.pollutionPressure)
        XCTAssertLessThan(industryAnalytics.utilityReserve, commerceAnalytics.utilityReserve)
        XCTAssertLessThan(industry.happiness, commerce.happiness)
    }

    func testCommercialSetbackSupportsTaxReliefAndParkRecovery() throws {
        var pressured = try commercialStrategy()
        pressured.taxRate = 0.14
        advanceToTick(&pressured, tick: CitySimulation.strategySetbackTick)
        XCTAssertTrue(pressured.messages.contains { $0.title == "Storefront Slump" })
        XCTAssertEqual(pressured.status, .playing)

        var taxRelief = pressured
        taxRelief.taxRate = 0.09
        advanceToTick(&taxRelief, tick: CitySimulation.strategyPayoffTick)
        let taxPayoff = try XCTUnwrap(taxRelief.messages.first { $0.title == "Main Street Rebound" })
        XCTAssertTrue(taxPayoff.detail.contains("tax relief"))
        XCTAssertEqual(taxRelief.status, .playing)

        var placemaking = pressured
        try build(.park, at: GridCoordinate(x: 6, y: 11), in: &placemaking)
        advanceToTick(&placemaking, tick: CitySimulation.strategyPayoffTick)
        let parkPayoff = try XCTUnwrap(placemaking.messages.first { $0.title == "Main Street Rebound" })
        XCTAssertTrue(parkPayoff.detail.contains("new park"))
        XCTAssertEqual(placemaking.status, .playing)
        XCTAssertGreaterThan(placemaking.treasury, taxRelief.treasury)
    }

    func testIndustrialSetbackSupportsUtilityAndGreenBufferRecovery() throws {
        var pressured = try industrialStrategy()
        advanceToTick(&pressured, tick: CitySimulation.strategySetbackTick)
        XCTAssertTrue(pressured.messages.contains { $0.title == "Industrial Load Surge" })
        XCTAssertEqual(pressured.status, .playing)

        var utilityReserve = pressured
        try build(.powerPlant, at: GridCoordinate(x: 6, y: 11), in: &utilityReserve)
        try build(.waterTower, at: GridCoordinate(x: 5, y: 11), in: &utilityReserve)
        advanceToTick(&utilityReserve, tick: CitySimulation.strategyPayoffTick)
        XCTAssertTrue(utilityReserve.messages.contains { $0.title == "Freight Network Secured" })
        XCTAssertGreaterThan(CityAnalytics(state: utilityReserve).utilityReserve, 0.35)
        XCTAssertEqual(utilityReserve.status, .playing)

        var greenBuffer = pressured
        try build(.park, at: GridCoordinate(x: 6, y: 11), in: &greenBuffer)
        advanceToTick(&greenBuffer, tick: CitySimulation.strategyPayoffTick)
        XCTAssertTrue(greenBuffer.messages.contains { $0.title == "Cleaner Industry Compact" })
        XCTAssertGreaterThan(greenBuffer.happiness, pressured.happiness)
        XCTAssertGreaterThan(greenBuffer.treasury, pressured.treasury)
        XCTAssertEqual(greenBuffer.status, .playing)
    }

    func testIgnoringEitherSetbackCostsMoreButLeavesARecoveryPath() throws {
        var commerce = try commercialStrategy()
        commerce.taxRate = 0.14
        var industry = try industrialStrategy()
        advanceToTick(&commerce, tick: CitySimulation.strategyPayoffTick)
        advanceToTick(&industry, tick: CitySimulation.strategyPayoffTick)

        XCTAssertTrue(commerce.messages.contains { $0.title == "Main Street Recovery Delayed" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Recovery Delayed" })
        XCTAssertEqual(commerce.status, .playing)
        XCTAssertEqual(industry.status, .playing)
        XCTAssertGreaterThan(commerce.treasury, 0)
        XCTAssertGreaterThan(industry.treasury, 0)
        XCTAssertGreaterThan(commerce.happiness, 20)
        XCTAssertGreaterThan(industry.happiness, 20)
    }

    func testTemporaryTaxRecoveryImprovesCashflowButSuppressesDemandAndHappiness() {
        var standardTax = CityGameState.newCity(seed: 42)
        var recoveryTax = standardTax
        recoveryTax.taxRate = 0.18

        advance(&standardTax, cycles: 1)
        advance(&recoveryTax, cycles: 1)

        XCTAssertGreaterThan(
            CityAnalytics(state: recoveryTax).projectedBalance,
            CityAnalytics(state: standardTax).projectedBalance
        )
        XCTAssertLessThan(recoveryTax.demand.residential, standardTax.demand.residential)
        XCTAssertLessThan(recoveryTax.happiness, standardTax.happiness)
    }

    func testLegacyStateWithoutProgressionNormalizesOnlyOnDailyBoundary() throws {
        let encoded = try JSONEncoder().encode(CityGameState.newCity(seed: 42))
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        payload.removeValue(forKey: "progression")
        let legacyData = try JSONSerialization.data(withJSONObject: payload)
        var decoded = try JSONDecoder().decode(CityGameState.self, from: legacyData)

        XCTAssertNil(decoded.progression)
        for expectedTick in 1...3 {
            CitySimulation.step(&decoded)
            XCTAssertEqual(decoded.tick, expectedTick)
            XCTAssertNil(decoded.progression)
        }
        CitySimulation.step(&decoded)
        XCTAssertEqual(decoded.tick, 4)
        XCTAssertEqual(decoded.progression, CityProgressionState())
    }

    func testProgressionRoundTripsNewAndAwardedStateExactly() throws {
        let newState = CityGameState.newCity(seed: 42)
        let newRoundTrip = try JSONDecoder().decode(
            CityGameState.self,
            from: JSONEncoder().encode(newState)
        )
        XCTAssertEqual(newRoundTrip.progression, CityProgressionState())

        var awarded = newState
        awarded.progression = CityProgressionState(
            townCharterQualifyingCycles: 12,
            townCharterAwarded: true
        )
        let awardedRoundTrip = try JSONDecoder().decode(
            CityGameState.self,
            from: JSONEncoder().encode(awarded)
        )
        XCTAssertEqual(awardedRoundTrip.progression, awarded.progression)
    }

    func testTownCharterRequiresTwelveConsecutiveDailyChecksAndAwardsOnce() throws {
        var state = try qualifyingTown()
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 1)

        advanceDays(&state, days: 10)
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 11)
        XCTAssertFalse(state.progression?.townCharterAwarded ?? true)
        XCTAssertFalse(state.messages.contains { $0.title == "Town Charter Awarded" })

        advanceDays(&state, days: 1)
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 12)
        XCTAssertTrue(state.progression?.townCharterAwarded ?? false)
        XCTAssertEqual(state.messages.filter { $0.title == "Town Charter Awarded" }.count, 1)

        state.happiness = 0
        advance(&state, cycles: 20)
        XCTAssertTrue(state.progression?.townCharterAwarded ?? false)
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 12)
        XCTAssertEqual(state.messages.filter { $0.title == "Town Charter Awarded" }.count, 1)
    }

    func testFailedTownCharterCheckResetsBeforeLaterSuccessfulRun() throws {
        var state = try qualifyingTown()
        advanceDays(&state, days: 4)
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 5)

        state.happiness = 0
        for _ in 0..<3 { CitySimulation.step(&state) }
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 5)
        CitySimulation.step(&state)
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 0)
        XCTAssertFalse(state.progression?.townCharterAwarded ?? true)

        advanceQualifyingTown(&state, days: 12)
        XCTAssertTrue(state.progression?.townCharterAwarded ?? false)
        XCTAssertEqual(state.messages.filter { $0.title == "Town Charter Awarded" }.count, 1)
    }

    @MainActor
    func testUndoRestoresExactTownCharterProgression() {
        var state = CityGameState.newCity(seed: 42)
        state.progression = CityProgressionState(
            townCharterQualifyingCycles: 7,
            townCharterAwarded: false
        )
        let store = CityGameStore(state: state)
        let beforeBuild = store.state

        store.selectTool(.residential)
        store.primaryAction(at: GridCoordinate(x: 8, y: 11))
        store.state.progression?.townCharterQualifyingCycles = 9
        store.undoLastAction()

        XCTAssertEqual(store.state, beforeBuild)
        XCTAssertEqual(store.state.progression?.townCharterQualifyingCycles, 7)
    }

    @MainActor
    func testTownCharterObjectiveAndAwardMessageRouteToExistingContext() throws {
        var state = try qualifyingTown()
        let store = CityGameStore(state: state)
        let charter = try XCTUnwrap(store.objectives.first { $0.id == "town-charter" })
        let capacity = try XCTUnwrap(store.objectives.first { $0.id == "capacity" })

        XCTAssertEqual(charter.remaining, "1 of 12 qualifying days complete")
        store.openObjective(capacity)
        XCTAssertEqual(store.inspectorSection, .utilities)
        store.openObjective(charter)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.inspectorSection, .overview)

        state.progression = CityProgressionState(
            townCharterQualifyingCycles: 12,
            townCharterAwarded: true
        )
        let award = CityMessage(
            tick: state.tick,
            severity: .good,
            title: "Town Charter Awarded",
            detail: "Sustained achievement"
        )
        store.showObjectives = false
        store.openMessage(award)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.inspectorSection, .overview)
    }

    private func advance(_ state: inout CityGameState, cycles: Int) {
        for _ in 0..<(cycles * 4) {
            CitySimulation.step(&state)
        }
    }

    private func advanceDays(_ state: inout CityGameState, days: Int) {
        for _ in 0..<(days * 4) {
            CitySimulation.step(&state)
        }
    }

    private func advanceToTick(_ state: inout CityGameState, tick: Int) {
        XCTAssertLessThanOrEqual(state.tick, tick)
        while state.tick < tick {
            CitySimulation.step(&state)
        }
    }

    private func advanceQualifyingTown(_ state: inout CityGameState, days: Int) {
        for _ in 0..<days {
            state.population = 500
            state.treasury = max(state.treasury, 50_000)
            state.happiness = 57
            advanceDays(&state, days: 1)
            XCTAssertTrue(
                CitySimulation.meetsTownCharterStandards(in: state),
                CityAnalytics(state: state).townCharterStatusText
            )
        }
    }

    @discardableResult
    private func advanceUntil(
        _ state: inout CityGameState,
        maximumCycles: Int,
        condition: (CityGameState) -> Bool
    ) -> Int {
        for _ in 0..<maximumCycles {
            advance(&state, cycles: 1)
            if condition(state) { return state.tick }
        }
        XCTFail("Expected scenario condition within \(maximumCycles) cycles")
        return state.tick
    }

    private func qualifyingTown() throws -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 50_000
        try build(.industrial, at: GridCoordinate(x: 8, y: 11), in: &state)
        try build(.industrial, at: GridCoordinate(x: 7, y: 11), in: &state)
        try build(.powerPlant, at: GridCoordinate(x: 6, y: 11), in: &state)
        try build(.waterTower, at: GridCoordinate(x: 5, y: 11), in: &state)
        state.population = 500
        state.treasury = 50_000
        state.happiness = 60
        advance(&state, cycles: 1)
        XCTAssertTrue(CityAnalytics(state: state).meetsTownCharterStandards)
        return state
    }

    private func commercialStrategy() throws -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        try build(.commercial, at: GridCoordinate(x: 8, y: 11), in: &state)
        try build(.commercial, at: GridCoordinate(x: 7, y: 11), in: &state)
        return state
    }

    private func industrialStrategy() throws -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        try build(.industrial, at: GridCoordinate(x: 8, y: 11), in: &state)
        try build(.industrial, at: GridCoordinate(x: 7, y: 11), in: &state)
        return state
    }

    private func build(
        _ kind: BuildingKind,
        at coordinate: GridCoordinate,
        in state: inout CityGameState
    ) throws {
        switch CitySimulation.build(kind, at: coordinate, in: &state) {
        case .success:
            return
        case .failure(let rejection):
            throw rejection
        }
    }

    private func buildFirstValid(_ kind: BuildingKind, in state: inout CityGameState) throws {
        for tile in state.tiles where tile.kind == .empty {
            if case .success = CitySimulation.validateBuild(kind, at: tile.coordinate, in: state) {
                try build(kind, at: tile.coordinate, in: &state)
                return
            }
        }
        XCTFail("Expected a visible valid placement for \(kind.title)")
    }

    private func prepareReserveUtilities(in state: inout CityGameState) throws {
        for kind in [BuildingKind.powerPlant, .waterTower] {
            while CityAnalytics(state: state).count(kind) < 2 {
                advanceUntil(&state, maximumCycles: 160) { $0.treasury >= kind.buildCost }
                try buildFirstValid(kind, in: &state)
                advance(&state, cycles: 1)
            }
        }
    }

    private func prepareCharterCapacity(in state: inout CityGameState, jobs: BuildingKind) throws {
        try prepareReserveUtilities(in: &state)
        while CityAnalytics(state: state).jobCapacity < 350 {
            advanceUntil(&state, maximumCycles: 160) { $0.treasury >= jobs.buildCost }
            try buildFirstValid(jobs, in: &state)
            advance(&state, cycles: 1)
        }
    }
}
