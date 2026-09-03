import XCTest
@testable import CitySimNative

final class CityGrowthQueueTests: XCTestCase {
    func testQueueUsesEveryAuthoritativeRequirementWithoutMutatingTheCity() throws {
        let state = CityGameState.newCity(seed: 42)
        let before = try CityStateFingerprinter.fingerprint(state)
        let queue = CityGrowthQueue(state: state)
        let pipeline = CityDevelopmentPipeline.make(state: state)
        XCTAssertEqual(queue.sites(matching: .held).count, pipeline.heldCount)
        XCTAssertEqual(queue.sites(matching: .ready).count, pipeline.readyCount)
        XCTAssertEqual(queue.sites(matching: .building).count, pipeline.buildingCount)
        XCTAssertEqual(queue.sites.count, pipeline.heldCount + pipeline.readyCount + pipeline.buildingCount + pipeline.matureCount)
        XCTAssertTrue(queue.sites.contains { $0.outlook.requirements.count > 1 })
        for site in queue.sites {
            let tile = try XCTUnwrap(state.tile(at: site.coordinate))
            let evaluation = CitySimulation.developmentUpgradeEvaluation(for: tile, in: state)
            XCTAssertEqual(site.outlook, CityDevelopmentOutlook.make(tile: tile, state: state))
            if site.outlook.status == .held {
                XCTAssertEqual(site.outlook.requirements.count, evaluation.blockers.count)
                for requirement in site.outlook.requirements {
                    XCTAssertTrue(site.requirementsText.contains(requirement))
                    XCTAssertTrue(site.outlook.accessibilitySummary.contains(requirement))
                }
            }
        }
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), before)
        XCTAssertEqual(queue, CityGrowthQueue(state: state))
    }

    func testReadyHeldBuildingAndMatureRemainDistinctAndEverySiteIsReachable() {
        let state = mixedDistrict()
        let queue = CityGrowthQueue(state: state)
        XCTAssertEqual(queue.sites(matching: .ready).count, 1)
        XCTAssertEqual(queue.sites(matching: .held).count, 5)
        XCTAssertEqual(queue.sites(matching: .building).count, 1)
        XCTAssertEqual(queue.sites.filter { $0.outlook.status == .mature }.count, 1)
        XCTAssertEqual(queue.sites.count, 8)
        XCTAssertEqual(queue.sites.first?.outlook.status, .ready)
        XCTAssertEqual(queue.sites.last?.outlook.status, .mature)
        let held = queue.sites(matching: .held)
        let pages = stride(from: 0, to: held.count, by: CityGrowthQueue.pageSize).map {
            Array(held.dropFirst($0).prefix(CityGrowthQueue.pageSize))
        }
        XCTAssertEqual(pages.map(\.count), [2, 2, 1])
        XCTAssertEqual(pages.flatMap { $0 }.map(\.coordinate), held.map(\.coordinate))
        XCTAssertEqual(Set(held.map(\.coordinate)).count, held.count)
        XCTAssertEqual(held.map { $0.outlook.requirements.count }, held.map { $0.outlook.requirements.count }.sorted())
        XCTAssertEqual(queue.sites[0].outlook.payoff, "L1 → L2 · 80 → 160 jobs")
    }

    func testQueueReevaluatesChangedConditionsInsteadOfCachingEligibility() {
        var state = mixedDistrict()
        let coordinate = GridCoordinate(x: 3, y: 2)
        XCTAssertEqual(CityGrowthQueue(state: state).sites.first { $0.coordinate == coordinate }?.outlook.status, .held)
        state.updateTile(at: coordinate) { $0.condition = 1; $0.occupancy = 110 }
        XCTAssertEqual(CityGrowthQueue(state: state).sites.first { $0.coordinate == coordinate }?.outlook.status, .ready)
        state.updateTile(at: coordinate) { $0.kind = .empty }
        XCTAssertFalse(CityGrowthQueue(state: state).sites.contains { $0.coordinate == coordinate })
    }

    @MainActor
    func testInspectAndReturnPauseWithoutBuildingSpendingOrChangingSaveIdentity() throws {
        let state = mixedDistrict()
        let store = CityGameStore(state: state)
        store.selectTool(.industrial)
        store.openInspector(.demand)
        store.setSpeed(.fast)
        let before = try CityStateFingerprinter.fingerprint(store.state)
        let coordinate = GridCoordinate(x: 3, y: 2)
        XCTAssertTrue(store.inspectGrowthSite(coordinate))
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertEqual(store.selectedCoordinate, coordinate)
        XCTAssertEqual(store.hudContextScope, .selection)
        XCTAssertTrue(store.showInspector)
        XCTAssertEqual(store.inspectorSection, .demand)
        XCTAssertTrue(store.perform(.inspectorDemand))
        XCTAssertEqual(store.hudContextScope, .city)
        XCTAssertEqual(store.selectedCoordinate, coordinate)
        XCTAssertTrue(store.showInspector)
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), before)
    }

    @MainActor
    func testStaleTargetsAndBlockingModalsCannotChangeTheSelectionOrCity() {
        let store = CityGameStore(state: mixedDistrict())
        let before = store.state
        XCTAssertFalse(store.inspectGrowthSite(.init(x: -1, y: 0)))
        XCTAssertFalse(store.inspectGrowthSite(.init(x: 0, y: 0)))
        XCTAssertNil(store.selectedCoordinate)
        store.presentBlockingModal(.newRegionSetup)
        XCTAssertFalse(store.inspectGrowthSite(.init(x: 3, y: 2)))
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.state, before)
    }

    @MainActor
    func testQueueUsesABoundedTemporaryPanelAndLeavesDefaultDemandHeightAlone() {
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: true, selectedBlock: false, growthQueue: true), 248)
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: false, selectedBlock: false, growthQueue: true), 248)
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: false, selectedBlock: true, growthQueue: true), 220)
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: false, selectedBlock: false), 144)
        XCTAssertEqual(BuildToolbarView.detailsHeight(compact: true, selectedBlock: false), 196)
    }

    private func mixedDistrict() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: .empty) }
        }
        state.progression = nil
        state.treasury = 100_000
        state.population = 10_000
        state.jobs = 10_000
        state.happiness = 100
        state.demand = DemandLevels(residential: 1, commercial: 1, industrial: 1)
        state.powerCapacity = 100_000
        state.waterCapacity = 100_000
        state.powerUsed = 100
        state.waterUsed = 100
        let ready = GridCoordinate(x: 2, y: 2)
        state.updateTile(at: ready) { $0 = CityTile(coordinate: ready, kind: .commercial, occupancy: 80) }
        for x in 3...7 {
            let held = GridCoordinate(x: x, y: 2)
            state.updateTile(at: held) {
                $0 = CityTile(coordinate: held, kind: .industrial, occupancy: x == 7 ? 0 : 110, condition: 0.5)
            }
        }
        let building = GridCoordinate(x: 4, y: 3)
        state.updateTile(at: building) {
            $0 = CityTile(coordinate: building, kind: .residential, occupancy: 280, constructionProgress: 0.5)
        }
        let mature = GridCoordinate(x: 5, y: 3)
        state.updateTile(at: mature) { $0 = CityTile(coordinate: mature, kind: .commercial, level: 2, occupancy: 160) }
        return state
    }
}
