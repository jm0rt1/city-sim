import Foundation
import XCTest
@testable import CitySimNative

final class GameplayLoopTests: XCTestCase {
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
        var industryFirst = CityGameState.newCity(seed: 42)
        try build(.industrial, at: GridCoordinate(x: 8, y: 11), in: &industryFirst)
        try build(.industrial, at: GridCoordinate(x: 7, y: 11), in: &industryFirst)
        advance(&industryFirst, cycles: 4)
        try build(.powerPlant, at: GridCoordinate(x: 6, y: 11), in: &industryFirst)
        try build(.waterTower, at: GridCoordinate(x: 5, y: 11), in: &industryFirst)
        advance(&industryFirst, cycles: 220)

        var commerceAndTax = CityGameState.newCity(seed: 42)
        commerceAndTax.taxRate = 0.14
        try build(.commercial, at: GridCoordinate(x: 8, y: 11), in: &commerceAndTax)
        try build(.commercial, at: GridCoordinate(x: 7, y: 11), in: &commerceAndTax)
        advance(&commerceAndTax, cycles: 2)
        try build(.powerPlant, at: GridCoordinate(x: 6, y: 11), in: &commerceAndTax)
        try build(.waterTower, at: GridCoordinate(x: 5, y: 11), in: &commerceAndTax)
        advance(&commerceAndTax, cycles: 220)

        let industryAnalytics = CityAnalytics(state: industryFirst)
        let commerceAnalytics = CityAnalytics(state: commerceAndTax)
        XCTAssertTrue(industryAnalytics.meetsTownCharterStandards)
        XCTAssertTrue(commerceAnalytics.meetsTownCharterStandards)
        XCTAssertGreaterThan(industryAnalytics.pollutionPressure, commerceAnalytics.pollutionPressure)
        XCTAssertLessThan(industryFirst.taxRate, commerceAndTax.taxRate)
        XCTAssertGreaterThanOrEqual(industryFirst.population, 500)
        XCTAssertGreaterThanOrEqual(commerceAndTax.population, 500)
        XCTAssertTrue(industryFirst.progression?.townCharterAwarded ?? false)
        XCTAssertTrue(commerceAndTax.progression?.townCharterAwarded ?? false)
        XCTAssertEqual(industryFirst.messages.filter { $0.title == "Town Charter Awarded" }.count, 1)
        XCTAssertEqual(commerceAndTax.messages.filter { $0.title == "Town Charter Awarded" }.count, 1)

        // 700 cycles × 4 pulses × 0.42 seconds is approximately a 19.6-minute 1× session.
        advance(&industryFirst, cycles: 480)
        advance(&commerceAndTax, cycles: 480)
        XCTAssertTrue(industryFirst.progression?.townCharterAwarded ?? false)
        XCTAssertTrue(commerceAndTax.progression?.townCharterAwarded ?? false)
        XCTAssertNotEqual(industryFirst.status, .lost)
        XCTAssertNotEqual(commerceAndTax.status, .lost)
        XCTAssertGreaterThan(industryFirst.treasury, 0)
        XCTAssertGreaterThan(commerceAndTax.treasury, 0)
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
        CitySimulation.step(&decoded)
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
        advanceDays(&state, days: 1)
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
        for _ in 0..<days {
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

    private func advanceUntil(
        _ state: inout CityGameState,
        maximumCycles: Int,
        condition: (CityGameState) -> Bool
    ) {
        for _ in 0..<maximumCycles {
            advance(&state, cycles: 1)
            if condition(state) { return }
        }
        XCTFail("Expected scenario condition within \(maximumCycles) cycles")
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
}
