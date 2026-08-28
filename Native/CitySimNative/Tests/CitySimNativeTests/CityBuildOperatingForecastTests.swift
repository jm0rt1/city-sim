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

    func testRoadPlacementForecastDistinguishesNetworkShapeAndNewAccess() throws {
        var state = CityGameState.newCity(seed: 42)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        let target = GridCoordinate(x: 10, y: 10)
        let north = GridCoordinate(x: 10, y: 9)
        let east = GridCoordinate(x: 11, y: 10)
        let south = GridCoordinate(x: 10, y: 11)
        let west = GridCoordinate(x: 9, y: 10)

        XCTAssertEqual(
            CityRoadPlacementForecast.make(at: target, in: state)?.summary,
            "Separate road segment · serves 4 open parcels"
        )

        state.updateTile(at: north) { $0.kind = .road }
        XCTAssertEqual(
            CityRoadPlacementForecast.make(at: target, in: state)?.summary,
            "Extends 1 approach · serves 3 open parcels"
        )

        state.updateTile(at: south) { $0.kind = .road }
        let twoApproach = try XCTUnwrap(
            CityRoadPlacementForecast.make(at: target, in: state)
        )
        XCTAssertEqual(twoApproach.adjacentRoadApproaches, 2)
        XCTAssertEqual(twoApproach.newlyServedOpenParcels, 2)
        XCTAssertEqual(
            twoApproach.summary,
            "Connects 2 approaches · serves 2 open parcels"
        )

        let targetTile = try XCTUnwrap(state.tile(at: target))
        let decision = CityBuildDecisionPresentation.make(
            kind: .road,
            tile: targetTile,
            rejection: nil,
            state: state
        )
        XCTAssertEqual(decision.likelyConsequence, twoApproach.summary)
        XCTAssertTrue(decision.accessibilitySummary.contains(twoApproach.summary))

        state.updateTile(at: east) { $0.kind = .road }
        XCTAssertEqual(
            CityRoadPlacementForecast.make(at: target, in: state)?.summary,
            "3-way junction · serves 1 open parcel"
        )

        state.updateTile(at: west) { $0.kind = .road }
        XCTAssertEqual(
            CityRoadPlacementForecast.make(at: target, in: state)?.summary,
            "4-way junction · serves no new open parcel"
        )

        state.updateTile(at: target) { $0.kind = .residential }
        let occupied = CityBuildDecisionPresentation.make(
            kind: .road,
            tile: try XCTUnwrap(state.tile(at: target)),
            rejection: .occupied,
            state: state
        )
        XCTAssertEqual(
            occupied.likelyConsequence,
            "Clear this occupied block before the road network can change"
        )
        XCTAssertNil(CityRoadPlacementForecast.make(at: target, in: state))
    }

    func testDemolitionForecastNamesHousingJobsUtilitiesRoadsAndServices() throws {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 100_000
        for kind in [BuildingKind.commercial, .powerPlant, .waterTower, .fireStation] {
            let coordinate = try validTile(for: kind, in: state).coordinate
            guard case .success = CitySimulation.build(kind, at: coordinate, in: &state) else {
                return XCTFail("Expected \(kind.title) fixture to build")
            }
            state.updateTile(at: coordinate) { $0.constructionProgress = 1 }
        }
        state.powerCapacity = CitySimulation.powerCapacityPerPlant * 2
        state.waterCapacity = CitySimulation.waterCapacityPerTower * 2

        let residential = try XCTUnwrap(state.tiles.first { $0.kind == .residential })
        let road = try XCTUnwrap(state.tiles.first { $0.kind == .road })
        XCTAssertTrue(try XCTUnwrap(CityDemolitionForecast.make(tile: residential, state: state)).capacityImpact.hasPrefix("Housing "))
        XCTAssertTrue(try XCTUnwrap(CityDemolitionForecast.make(tile: try tile(.commercial, in: state), state: state)).capacityImpact.hasPrefix("Jobs "))
        XCTAssertTrue(try XCTUnwrap(CityDemolitionForecast.make(tile: try tile(.powerPlant, in: state), state: state)).capacityImpact.hasPrefix("Power "))
        XCTAssertTrue(try XCTUnwrap(CityDemolitionForecast.make(tile: try tile(.waterTower, in: state), state: state)).capacityImpact.hasPrefix("Water "))
        XCTAssertEqual(
            try XCTUnwrap(CityDemolitionForecast.make(tile: road, state: state)).capacityImpact,
            "Road access may change for adjacent blocks"
        )
        XCTAssertEqual(
            try XCTUnwrap(CityDemolitionForecast.make(tile: try tile(.fireStation, in: state), state: state)).capacityImpact,
            "Removes civic service and storm protection"
        )
    }

    func testDemolitionForecastIncludesFeeDebtAndUnlimitedFundsRules() throws {
        var funded = CityGameState.newCity(seed: 42)
        let residential = try XCTUnwrap(funded.tiles.first { $0.kind == .residential })
        let fundedForecast = try XCTUnwrap(CityDemolitionForecast.make(tile: residential, state: funded))
        funded.treasury = 0
        let debtForecast = try XCTUnwrap(CityDemolitionForecast.make(tile: residential, state: funded))
        funded.sandboxRules = CitySandboxRules(
            economy: .standard,
            incidentsEnabled: true,
            unlimitedFunds: true
        )
        let unlimitedForecast = try XCTUnwrap(CityDemolitionForecast.make(tile: residential, state: funded))

        XCTAssertLessThan(debtForecast.balanceChange, fundedForecast.balanceChange)
        XCTAssertGreaterThan(unlimitedForecast.balanceChange, debtForecast.balanceChange)
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

    private func tile(_ kind: BuildingKind, in state: CityGameState) throws -> CityTile {
        try XCTUnwrap(state.tiles.first { $0.kind == kind })
    }
}
