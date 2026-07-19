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

    func testIndustryFirstAndCommerceTaxStrategiesBothMeetTownCharterStandards() throws {
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

    private func advance(_ state: inout CityGameState, cycles: Int) {
        for _ in 0..<(cycles * 4) {
            CitySimulation.step(&state)
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
