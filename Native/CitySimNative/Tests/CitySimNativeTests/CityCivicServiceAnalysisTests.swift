import Foundation
import XCTest
@testable import CitySimNative

final class CityCivicServiceAnalysisTests: XCTestCase {
    func testCoverageRequiresCompletedServiceAndAConnectedStreetRoute() throws {
        let home = GridCoordinate(x: 3, y: 9)
        let fireStation = GridCoordinate(x: 4, y: 11)
        var connected = serviceRouteState()
        place(.fireStation, at: fireStation, in: &connected)

        let connectedReading = try XCTUnwrap(CityCivicServiceAnalysis(state: connected)[home])
        XCTAssertGreaterThan(connectedReading.fire, 0.9)
        XCTAssertEqual(connectedReading.police, 0)
        XCTAssertEqual(connectedReading.school, 0)
        XCTAssertEqual(connectedReading.combined, connectedReading.fire / 3, accuracy: 0.000_001)

        var incomplete = connected
        incomplete.updateTile(at: fireStation) { $0.constructionProgress = 0.75 }
        XCTAssertEqual(
            try XCTUnwrap(CityCivicServiceAnalysis(state: incomplete)[home]).combined,
            0
        )

        var disconnected = connected
        disconnected.updateTile(at: fireStation) {
            $0 = CityTile(coordinate: fireStation, kind: .empty)
        }
        let isolatedRoad = GridCoordinate(x: 4, y: 14)
        disconnected.updateTile(at: isolatedRoad) {
            $0 = CityTile(coordinate: isolatedRoad, kind: .road)
        }
        place(.fireStation, at: GridCoordinate(x: 4, y: 15), in: &disconnected)
        XCTAssertEqual(
            try XCTUnwrap(CityCivicServiceAnalysis(state: disconnected)[home]).combined,
            0
        )
    }

    func testCoverageDecaysByRoadDistanceAndRewardsAReachableServiceMix() throws {
        let nearHome = GridCoordinate(x: 3, y: 9)
        let farHome = GridCoordinate(x: 20, y: 9)
        var state = serviceRouteState()
        place(.residential, at: farHome, occupancy: 40, in: &state)
        place(.fireStation, at: GridCoordinate(x: 4, y: 11), in: &state)
        place(.policeStation, at: GridCoordinate(x: 5, y: 11), in: &state)
        place(.school, at: GridCoordinate(x: 6, y: 11), in: &state)

        let analysis = CityCivicServiceAnalysis(state: state)
        let near = try XCTUnwrap(analysis[nearHome])
        let far = try XCTUnwrap(analysis[farHome])
        XCTAssertGreaterThan(near.fire, near.police)
        XCTAssertGreaterThan(near.police, near.school)
        XCTAssertGreaterThan(near.combined, 0.8)
        XCTAssertEqual(near.weakestService, .school)
        XCTAssertEqual(far.combined, 0)
    }

    func testResidentWeightedCoverageChangesTheHappinessTargetWithoutMutatingState() throws {
        let serviceCoordinate = GridCoordinate(x: 4, y: 11)
        var near = serviceRouteState()
        place(.fireStation, at: serviceCoordinate, in: &near)
        let original = near

        let first = CityCivicServiceAnalysis(state: near)
        let second = CityCivicServiceAnalysis(state: near)
        XCTAssertEqual(first, second)
        XCTAssertEqual(near, original)
        XCTAssertGreaterThan(first.citywideResidentialCoverage, 0)
        XCTAssertEqual(
            CitySimulation.civicServiceHappinessBonus(in: near),
            first.citywideResidentialCoverage * 10,
            accuracy: 0.000_001
        )

        var beyondReach = serviceRouteState()
        place(.fireStation, at: GridCoordinate(x: 20, y: 11), in: &beyondReach)
        XCTAssertGreaterThan(
            CitySimulation.civicServiceHappinessBonus(in: near),
            CitySimulation.civicServiceHappinessBonus(in: beyondReach)
        )

        let beforeBytes = try sortedEncoding(near)
        _ = CitySimulation.civicServiceHappinessBonus(in: near)
        _ = CitySpatialConsequenceMap(state: near)
        XCTAssertEqual(try sortedEncoding(near), beforeBytes)
    }

    func testSameServiceCountProducesDifferentHappinessWhenOnlyOneSiteReachesResidents() {
        var near = serviceRouteState()
        place(.fireStation, at: GridCoordinate(x: 4, y: 11), in: &near)
        var beyondReach = serviceRouteState()
        place(.fireStation, at: GridCoordinate(x: 20, y: 11), in: &beyondReach)
        let nearCount = near.tiles.filter { $0.kind == .fireStation }.count
        let farCount = beyondReach.tiles.filter { $0.kind == .fireStation }.count

        CitySimulation.step(&near)
        CitySimulation.step(&beyondReach)

        XCTAssertEqual(nearCount, farCount)
        XCTAssertGreaterThan(near.happiness, beyondReach.happiness)
        XCTAssertEqual(near.tick, beyondReach.tick)
    }

    func testReachableServicesImproveLocalValueHappinessAndVitality() throws {
        let home = GridCoordinate(x: 3, y: 9)
        let withoutServices = serviceRouteState()
        var withServices = withoutServices
        place(.fireStation, at: GridCoordinate(x: 4, y: 11), in: &withServices)
        place(.policeStation, at: GridCoordinate(x: 5, y: 11), in: &withServices)
        place(.school, at: GridCoordinate(x: 6, y: 11), in: &withServices)

        let baseline = try XCTUnwrap(CitySpatialConsequenceMap(state: withoutServices)[home])
        let served = try XCTUnwrap(CitySpatialConsequenceMap(state: withServices)[home])
        XCTAssertEqual(baseline.civicService?.combined, 0)
        XCTAssertGreaterThan(try XCTUnwrap(served.civicService?.combined), 0.8)
        XCTAssertGreaterThan(try XCTUnwrap(served.landValueIndex), try XCTUnwrap(baseline.landValueIndex))
        XCTAssertGreaterThan(try XCTUnwrap(served.localHappinessIndex), try XCTUnwrap(baseline.localHappinessIndex))
        XCTAssertGreaterThan(served.vitalityScore, baseline.vitalityScore)
    }

    func testWeakCoverageDiagnosisAndOverlayExposeTheMissingReachableService() throws {
        let home = GridCoordinate(x: 3, y: 9)
        var state = serviceRouteState()
        place(.fireStation, at: GridCoordinate(x: 4, y: 11), in: &state)
        let snapshot = try CityPresentationSnapshot(state: state)
        let tile = try XCTUnwrap(state.tile(at: home))
        let sample = try XCTUnwrap(snapshot.spatialConsequences[home])
        let diagnosis = try XCTUnwrap(
            CitySelectedLocationDiagnosis.make(tile: tile, snapshot: snapshot)
        )
        let conditions = try XCTUnwrap(
            CitySelectedLocationConditions.make(tile: tile, snapshot: snapshot)
        )

        XCTAssertTrue(diagnosis.cause.contains("Civic service coverage is weak"))
        XCTAssertTrue(diagnosis.cause.contains("Fire"))
        XCTAssertTrue(diagnosis.cause.contains("Police 0%"))
        XCTAssertTrue(diagnosis.cause.contains("School 0%"))
        XCTAssertTrue(diagnosis.consequence.contains("reachable over connected streets"))
        XCTAssertTrue(diagnosis.responses.contains { $0.command == .buildPoliceStation })
        XCTAssertTrue(diagnosis.responses.contains { $0.command == .overlayServices })
        XCTAssertEqual(
            conditions.civicServiceCoverage,
            Int((try XCTUnwrap(sample.civicService).combined * 100).rounded())
        )
        XCTAssertTrue(conditions.accessibilitySummary.contains("civic service coverage"))

        let overlay = OverlayDiagnosticsPalettePresentation.make(
            overlay: .services,
            consequence: sample,
            tick: state.tick,
            selectionApplies: true
        )
        XCTAssertEqual(overlay.title, "Civic service coverage")
        XCTAssertEqual(overlay.applicability, "Completed places")
        XCTAssertEqual(overlay.source, "Completed civic sites over connected streets")
        XCTAssertEqual(overlay.visualKey, "More reach signals show a larger service gap")
    }

    private func serviceRouteState() -> CityGameState {
        var state = CityGameState.newCity(seed: 818)
        for tile in state.tiles {
            state.updateTile(at: tile.coordinate) {
                $0 = CityTile(coordinate: tile.coordinate, kind: .empty)
            }
        }
        for x in 2...21 {
            let coordinate = GridCoordinate(x: x, y: 10)
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .road)
            }
        }
        place(.residential, at: GridCoordinate(x: 3, y: 9), occupancy: 120, in: &state)
        state.population = 120
        state.happiness = 50
        state.powerCapacity = 300
        state.waterCapacity = 300
        state.powerUsed = 120
        state.waterUsed = 120
        return state
    }

    private func place(
        _ kind: BuildingKind,
        at coordinate: GridCoordinate,
        occupancy: Int = 0,
        in state: inout CityGameState
    ) {
        state.updateTile(at: coordinate) {
            $0 = CityTile(coordinate: coordinate, kind: kind)
            $0.constructionProgress = 1
            $0.condition = 1
            $0.occupancy = occupancy
        }
    }

    private func sortedEncoding(_ state: CityGameState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }
}
