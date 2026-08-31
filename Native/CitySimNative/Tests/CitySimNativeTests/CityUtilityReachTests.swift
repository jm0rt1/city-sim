import XCTest
@testable import CitySimNative

final class CityUtilityReachTests: XCTestCase {
    func testSpareCitywideCapacityDoesNotHideLocalGapsOrCountUnfinishedBlocks() throws {
        var state = district()
        put(.road, at: .init(x: 1, y: 9), in: &state)
        put(.residential, at: .init(x: 4, y: 9), progress: 0.5, in: &state)
        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        let analytics = CityAnalytics(state: state)
        let capacity = CityUtilityDecisionSupport.make(analytics: analytics)
        let reach = CityUtilityReachPresentation(state: state)
        XCTAssertEqual(analytics.utilityCoverage, 1)
        XCTAssertEqual(capacity.status, .healthy)
        XCTAssertEqual(reach.power.totalBlocks, 4)
        XCTAssertEqual(reach.water.totalBlocks, 4)
        XCTAssertEqual(reach.power.weakBlocks, 2)
        XCTAssertEqual(reach.water.weakBlocks, 2)
        XCTAssertEqual(reach.water.severeBlocks, 2)
        XCTAssertEqual(reach.water.weakestCoordinate, .init(x: 2, y: 9))
        XCTAssertEqual(reach.power.weakestCoordinate, .init(x: 15, y: 9))
        XCTAssertEqual(reach.priorityWhenCapacityAvailable(capacity)?.overlay, .water)
        XCTAssertEqual(reach.water.countText, "2 / 4")
        XCTAssertTrue(reach.water.planningDetail.contains("Spare capacity"))
        XCTAssertTrue(reach.water.accessibilitySummary.contains("2 of 4 completed developed blocks"))
        XCTAssertTrue(reach.water.accessibilitySummary.contains("unfinished construction are excluded"))
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), fingerprint)
    }

    func testCapacityShortagesAndTightReservesKeepTheirBuildFirstPriority() {
        var state = district()
        for used in [201, 190] {
            state.powerUsed = used
            let capacity = CityUtilityDecisionSupport.make(analytics: CityAnalytics(state: state))
            let reach = CityUtilityReachPresentation(state: state)
            XCTAssertNotEqual(capacity.status, .healthy)
            XCTAssertEqual(capacity.response?.command, .buildPowerPlant)
            XCTAssertNil(reach.priorityWhenCapacityAvailable(capacity))
            XCTAssertNotNil(reach.priority, "Local diagnostics remain available during a capacity shortage")
        }
    }

    func testCompletedSourcesRefreshCountsAndSevereGapsTakePriority() {
        var state = district()
        let site = GridCoordinate(x: 14, y: 9)
        put(.powerPlant, at: site, progress: 0.5, in: &state)
        let unfinished = CityUtilityReachPresentation(state: state)
        XCTAssertEqual(unfinished.power.severeBlocks, 2)
        state.updateTile(at: site) { $0.constructionProgress = 1 }
        let completed = CityUtilityReachPresentation(state: state)
        XCTAssertEqual(completed.power.totalBlocks, 5)
        XCTAssertEqual(completed.power.severeBlocks, 0)
        XCTAssertEqual(completed.power.weakBlocks, 1, "Distance-two service is strained, not healthy")
        XCTAssertEqual(completed.priority?.overlay, .water)
        XCTAssertEqual(completed, CityUtilityReachPresentation(state: state))
    }

    @MainActor
    func testGapRoutingRechecksLiveStateAndPreservesCityAndSaveIdentity() throws {
        let state = district()
        let store = CityGameStore(state: state)
        store.openInspector(.utilities)
        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        XCTAssertTrue(store.focusUtilityServiceGap(.water))
        XCTAssertEqual(store.overlay, .water)
        XCTAssertEqual(store.selectedCoordinate, .init(x: 2, y: 9))
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertFalse(store.showInspector)
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
        XCTAssertFalse(store.focusUtilityServiceGap(.services))
        XCTAssertEqual(store.overlay, .water)

        // A click must resolve the live map, not reuse a stale view's target.
        store.state = healthyDistrict()
        let selection = store.selectedCoordinate
        XCTAssertFalse(store.focusUtilityServiceGap(.power))
        XCTAssertEqual(store.overlay, .water)
        XCTAssertEqual(store.selectedCoordinate, selection)
        XCTAssertEqual(store.state, healthyDistrict())
    }

    @MainActor
    func testUnaffordableUtilityRemedyTargetsAValidEmptyParcelWithoutFundingOrDemolition() throws {
        var state = district()
        state.treasury = 100
        put(.road, at: .init(x: 3, y: 10), in: &state)
        for kind in [BuildingKind.powerPlant, .waterTower] {
            let store = CityGameStore(state: state)
            store.select(.init(x: 2, y: 9))
            XCTAssertTrue(store.performMapFocused(CityCommandCatalog.id(for: kind)))
            let target = try XCTUnwrap(store.selectedCoordinate)
            XCTAssertEqual(store.state.tile(at: target)?.kind, .empty)
            XCTAssertTrue(store.state.neighbors(of: target).contains { $0.kind == .road })
            guard case .failure(.insufficientFunds) = CitySimulation.validateBuild(kind, at: target, in: store.state) else {
                return XCTFail("Funding must remain the real blocker; the siting preview grants no money")
            }
            var funded = state
            funded.treasury = kind.buildCost
            guard case .success = CitySimulation.validateBuild(kind, at: target, in: funded) else {
                return XCTFail("The selected parcel must pass every nonfinancial placement rule")
            }
            XCTAssertEqual(store.state, state)
            XCTAssertEqual(store.state.tile(at: .init(x: 2, y: 9))?.kind, .powerPlant)
        }
    }

    @MainActor
    func testBlockingModalPreventsGapNavigationWithoutChangingTheCity() {
        let state = district()
        let store = CityGameStore(state: state)
        store.presentBlockingModal(.newRegionSetup)
        XCTAssertFalse(store.focusUtilityServiceGap(.water))
        XCTAssertEqual(store.overlay, .none)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.state, state)
    }

    @MainActor
    func testEmptyAndHealthyDistrictsNeverInventAServiceGap() {
        let healthy = CityUtilityReachPresentation(state: healthyDistrict())
        XCTAssertNil(healthy.priority)
        XCTAssertEqual(healthy.power.countText, "0 / 2")
        XCTAssertNil(healthy.power.weakestCoordinate)
        var empty = healthyDistrict()
        for index in empty.tiles.indices { empty.tiles[index].kind = .empty }
        let result = CityUtilityReachPresentation(state: empty)
        XCTAssertEqual(result.power.countText, "None yet")
        XCTAssertNil(result.priority)
        XCTAssertFalse(CityGameStore(state: empty).focusUtilityServiceGap(.water))
    }

    private func district() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for index in state.tiles.indices {
            state.tiles[index] = CityTile(coordinate: state.tiles[index].coordinate, kind: .empty)
        }
        for (kind, x) in [(BuildingKind.powerPlant, 2), (.residential, 3), (.commercial, 15), (.waterTower, 16)] {
            put(kind, at: .init(x: x, y: 9), in: &state)
        }
        state.powerCapacity = 200
        state.waterCapacity = 200
        state.powerUsed = 100
        state.waterUsed = 100
        return state
    }

    private func healthyDistrict() -> CityGameState {
        var state = district()
        for index in state.tiles.indices { state.tiles[index].kind = .empty }
        put(.powerPlant, at: .init(x: 2, y: 9), in: &state)
        put(.waterTower, at: .init(x: 3, y: 9), in: &state)
        return state
    }

    private func put(_ kind: BuildingKind, at coordinate: GridCoordinate, progress: Double = 1, in state: inout CityGameState) {
        state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: kind, constructionProgress: progress) }
    }
}
