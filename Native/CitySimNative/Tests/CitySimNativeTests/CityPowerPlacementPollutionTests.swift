import XCTest
@testable import CitySimNative

final class CityPowerPlacementPollutionTests: XCTestCase {
    func testPowerDecisionShowsServiceBenefitAndExactCompletedNeighborhoodPollutionWithoutMutation() throws {
        var state = fixture()
        put(.residential, at: .init(x: 10, y: 9), in: &state)
        put(.commercial, at: .init(x: 12, y: 10), in: &state)
        put(.residential, at: .init(x: 10, y: 13), in: &state)
        put(.residential, at: .init(x: 11, y: 10), progress: 0.5, in: &state)
        let before = state
        let target = GridCoordinate(x: 10, y: 10)
        let forecast = try XCTUnwrap(CityUtilityPlacementForecast.make(kind: .powerPlant, at: target, in: state))
        let impact = try XCTUnwrap(forecast.pollutionImpact)
        XCTAssertEqual(forecast.improvedDevelopedBlocks, 3)
        XCTAssertEqual(impact.affectedBlocks, 3, "Exclude roads, empty land, construction and the new plant")
        XCTAssertEqual(impact.affectedHomes, 2)
        XCTAssertEqual(impact.greatestIncrease, 0.7175, accuracy: 0.000_001)
        XCTAssertEqual(impact.summary, "Pollution: 3 blocks · max +72 pts")

        let decision = CityBuildDecisionPresentation.make(kind: .powerPlant, tile: try XCTUnwrap(state.tile(at: target)), rejection: nil, state: state)
        XCTAssertEqual(decision.pollutionImpact, impact)
        XCTAssertEqual(decision.likelyConsequence, forecast.summary)
        XCTAssertTrue(decision.accessibilitySummary.contains("including 2 residential blocks"))
        XCTAssertTrue(decision.accessibilitySummary.contains("72 percentage points"))
        XCTAssertTrue(decision.accessibilitySummary.contains("Escape cancels without changing the city"))

        var completed = state
        guard case .success = CitySimulation.build(.powerPlant, at: target, in: &completed) else {
            return XCTFail("Fixture must permit actual construction")
        }
        completed.updateTile(at: target) { $0.constructionProgress = 1 }
        let oldMap = CitySpatialConsequenceMap(state: state)
        let newMap = CitySpatialConsequenceMap(state: completed)
        let increases = oldMap.samples.filter { $0.vitality != .notApplicable }.compactMap { old -> Double? in
            guard let new = newMap[old.coordinate] else { return nil }
            let increase = new.pollutionExposure - old.pollutionExposure
            return increase > 0.000_000_001 ? increase : nil
        }
        XCTAssertEqual(impact.affectedBlocks, increases.count)
        XCTAssertEqual(impact.greatestIncrease, try XCTUnwrap(increases.max()), accuracy: 0.000_001)
        XCTAssertEqual(state, before)
    }

    func testMovingAwayFromDevelopmentRemovesCurrentExposureButDoesNotPromiseFutureSafety() throws {
        var state = fixture()
        put(.residential, at: .init(x: 10, y: 9), in: &state)
        for x in 2...9 { put(.road, at: .init(x: x, y: 1), in: &state) }
        for y in 2...9 { put(.road, at: .init(x: 9, y: y), in: &state) }
        let near = try XCTUnwrap(CityUtilityPlacementForecast.make(kind: .powerPlant, at: .init(x: 10, y: 10), in: state)?.pollutionImpact)
        let far = try XCTUnwrap(CityUtilityPlacementForecast.make(kind: .powerPlant, at: .init(x: 1, y: 1), in: state)?.pollutionImpact)
        XCTAssertGreaterThan(near.affectedBlocks, far.affectedBlocks)
        XCTAssertEqual(far.affectedBlocks, 0)
        XCTAssertEqual(far.greatestIncrease, 0)
        XCTAssertEqual(far.summary, "Pollution: no existing block worsens")
        XCTAssertTrue(far.accessibilitySummary.contains("Future development may still be exposed"))
        XCTAssertNil(CityUtilityPlacementForecast.make(kind: .waterTower, at: .init(x: 10, y: 10), in: state)?.pollutionImpact)
        XCTAssertNil(CityUtilityPlacementForecast.make(kind: .powerPlant, at: .init(x: 10, y: 9), in: state))
    }

    func testSeverePowerShortageStillDisclosesPollutionWithoutHealthyRecovery() throws {
        var state = fixture()
        put(.powerPlant, at: .init(x: 9, y: 10), in: &state)
        put(.residential, at: .init(x: 11, y: 10), in: &state)
        put(.road, at: .init(x: 10, y: 9), in: &state)
        put(.road, at: .init(x: 10, y: 11), in: &state)
        state.powerCapacity = CitySimulation.powerCapacityPerPlant
        state.powerUsed = 10_000
        let forecast = try XCTUnwrap(CityUtilityPlacementForecast.make(kind: .powerPlant, at: .init(x: 10, y: 10), in: state))
        XCTAssertEqual(forecast.restoredHealthyBlocks, 0)
        XCTAssertGreaterThan(try XCTUnwrap(forecast.pollutionImpact).affectedHomes, 0)
    }

    func testParkReliefAndExistingPollutionUseCappedAuthoritativeExposure() throws {
        var state = fixture()
        put(.residential, at: .init(x: 10, y: 9), in: &state)
        put(.industrial, at: .init(x: 11, y: 9), in: &state)
        put(.park, at: .init(x: 10, y: 8), in: &state)
        let target = GridCoordinate(x: 10, y: 10)
        let before = CitySpatialConsequenceMap(state: state)
        let forecast = try XCTUnwrap(CityUtilityPlacementForecast.make(kind: .powerPlant, at: target, in: state))
        var completed = state
        put(.powerPlant, at: target, in: &completed)
        let after = CitySpatialConsequenceMap(state: completed)
        let expected = before.samples.filter { $0.vitality != .notApplicable }.map { old in
            after[old.coordinate]!.pollutionExposure - old.pollutionExposure
        }
        XCTAssertEqual(forecast.pollutionImpact?.affectedBlocks, expected.filter { $0 > 0.000_000_001 }.count)
        XCTAssertEqual(try XCTUnwrap(forecast.pollutionImpact).greatestIncrease, try XCTUnwrap(expected.max()), accuracy: 0.000_001)
        XCTAssertEqual(CityPlacementPollutionImpact(affectedBlocks: 1, affectedHomes: 1, greatestIncrease: 0.004).summary,
                       "Pollution: 1 block · max under +1 pt")
    }

    private func fixture() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for index in state.tiles.indices { state.tiles[index] = CityTile(coordinate: state.tiles[index].coordinate, kind: .empty) }
        state.treasury = 100_000
        state.powerCapacity = 0
        state.powerUsed = 150
        state.waterCapacity = 0
        state.waterUsed = 135
        put(.road, at: .init(x: 9, y: 10), in: &state)
        put(.road, at: .init(x: 9, y: 9), in: &state)
        return state
    }

    private func put(_ kind: BuildingKind, at coordinate: GridCoordinate, progress: Double = 1, in state: inout CityGameState) {
        state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: kind, constructionProgress: progress) }
    }
}
