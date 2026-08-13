import XCTest
@testable import CitySimNative

final class CityBuildOperatingForecastTests: XCTestCase {
    func testServiceForecastUsesAuthoritativeOperatingCharge() throws {
        let state = CityGameState.newCity(seed: 42)
        let tile = try validTile(for: .park, in: state)
        let forecast = try XCTUnwrap(
            CityBuildOperatingForecast.make(kind: .park, tile: tile, state: state)
        )

        XCTAssertEqual(
            forecast.change,
            -BuildingKind.park.upkeep * CitySimulation.upkeepMultiplier,
            accuracy: 0.001
        )
        XCTAssertNotEqual(forecast.change, -BuildingKind.park.upkeep)
    }

    func testProductiveWorkplaceForecastIncludesRevenueAndEmploymentChange() throws {
        var state = CityGameState.newCity(seed: 42)
        state.population = 500
        state.jobs = 120
        let tile = try validTile(for: .commercial, in: state)
        let forecast = try XCTUnwrap(
            CityBuildOperatingForecast.make(kind: .commercial, tile: tile, state: state)
        )

        XCTAssertGreaterThan(forecast.completedBalance, forecast.currentBalance)
        XCTAssertGreaterThan(forecast.change, 0)
    }

    func testReserveUtilityForecastIncludesDiscountAndDemandingEconomy() throws {
        var state = CityGameState.newCity(seed: 42)
        state.sandboxRules = CitySandboxRules(
            economy: .demanding,
            incidentsEnabled: true,
            unlimitedFunds: false
        )
        let tile = try validTile(for: .waterTower, in: state)
        let forecast = try XCTUnwrap(
            CityBuildOperatingForecast.make(kind: .waterTower, tile: tile, state: state)
        )
        let undiscounted = -BuildingKind.waterTower.upkeep
            * CitySimulation.upkeepMultiplier
            * CitySandboxEconomy.demanding.upkeepMultiplier

        XCTAssertGreaterThan(forecast.change, undiscounted)
        XCTAssertLessThan(forecast.change, 0)
    }

    func testUnlimitedFundsPresentationLabelsTrackedNetAndCompletionTiming() throws {
        var state = CityGameState.newCity(seed: 42)
        state.sandboxRules = CitySandboxRules(
            economy: .standard,
            incidentsEnabled: true,
            unlimitedFunds: true
        )
        let tile = try validTile(for: .school, in: state)
        let decision = try XCTUnwrap(
            CityMapPrimaryActionPresentation.make(
                interactionMode: .build(.school),
                tile: tile,
                state: state
            ).buildDecision
        )

        XCTAssertEqual(decision.cost, "Cost waived · online in 4 ticks")
        XCTAssertTrue(decision.operatingImpact.hasPrefix("Tracked net"))
        XCTAssertNotNil(decision.operatingForecast)
    }

    private func validTile(for kind: BuildingKind, in state: CityGameState) throws -> CityTile {
        try XCTUnwrap(state.tiles.first { tile in
            guard tile.kind == .empty else { return false }
            if case .success = CitySimulation.validateBuild(kind, at: tile.coordinate, in: state) {
                return true
            }
            return false
        })
    }
}
