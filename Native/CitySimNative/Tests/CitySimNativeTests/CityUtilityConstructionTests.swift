import XCTest
@testable import CitySimNative

final class CityUtilityConstructionTests: XCTestCase {
    @MainActor
    func testCitywideConstructionStartsAtAnEmptySiteAndDisclosesRealFunding() throws {
        for kind in [BuildingKind.powerPlant, .waterTower] {
            for treasury in [100.0, 32_000.0] {
                var state = CityGameState.newCity(seed: 42)
                state.treasury = treasury
                let occupied = try XCTUnwrap(state.tiles.first { $0.kind == .powerPlant }?.coordinate)
                let store = CityGameStore(state: state)
                store.select(occupied)
                store.openInspector(.utilities)
                store.overlay = .water
                store.speed = .fastest
                let guide = store.foundationsGuideProgress
                let focus = store.mapFocusRequestGeneration

                XCTAssertTrue(CityUtilityDecisionView(store: store).beginConstruction(kind))

                let target = try XCTUnwrap(store.selectedCoordinate)
                XCTAssertNotEqual(target, occupied)
                XCTAssertEqual(store.state.tile(at: target)?.kind, .empty)
                XCTAssertEqual(store.interactionMode, .build(kind))
                XCTAssertEqual(store.selectedTool, kind)
                XCTAssertFalse(store.showInspector)
                XCTAssertEqual(store.speed, .paused)
                XCTAssertEqual(store.overlay, .water)
                XCTAssertEqual(store.mapFocusRequestGeneration, focus + 1)
                XCTAssertEqual(store.state, state)
                XCTAssertEqual(store.foundationsGuideProgress, guide)
                XCTAssertFalse(store.canUndo)
                let action = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction)
                let decision = try XCTUnwrap(action.buildDecision)
                XCTAssertTrue(decision.accessibilitySummary.contains(kind.buildCost.currencyText))
                if treasury < kind.buildCost {
                    XCTAssertFalse(action.isAvailable)
                    XCTAssertEqual(decision.recovery?.command, .inspectorFinances)
                    guard case .failure(.insufficientFunds) = CitySimulation.validateBuild(kind, at: target, in: state) else {
                        return XCTFail("Funding, not demolition, must be the remaining blocker")
                    }
                } else {
                    XCTAssertTrue(action.isAvailable)
                    XCTAssertNil(decision.disabledReason)
                    XCTAssertNotNil(decision.operatingForecast)
                }

                store.cancelBuildDecision()
                XCTAssertNil(store.selectedCoordinate)
                XCTAssertEqual(store.interactionMode, .build(kind))
                XCTAssertEqual(store.state, state)
                XCTAssertEqual(store.foundationsGuideProgress, guide)
                XCTAssertFalse(store.canUndo)
            }
        }
    }

    @MainActor
    func testCitywideUtilityConstructionRequiresConfirmationAndUndoesExactly() throws {
        for kind in [BuildingKind.powerPlant, .waterTower] {
            let state = CityGameState.newCity(seed: 42)
            let occupied = try XCTUnwrap(state.tiles.first { $0.kind == .powerPlant }?.coordinate)
            let store = CityGameStore(state: state)
            store.select(occupied)
            store.openInspector(.utilities)
            XCTAssertTrue(CityUtilityDecisionView(store: store).beginConstruction(kind))
            let target = try XCTUnwrap(store.selectedCoordinate)
            XCTAssertEqual(store.state, state)

            XCTAssertTrue(store.performMapCommand(.mapPrimaryAction))
            XCTAssertEqual(store.state.tile(at: target)?.kind, kind)
            XCTAssertEqual(store.state.tile(at: occupied), state.tile(at: occupied))
            XCTAssertEqual(store.state.treasury, state.treasury - kind.buildCost)
            XCTAssertLessThan(try XCTUnwrap(store.state.tile(at: target)).constructionProgress, 1)
            XCTAssertTrue(store.perform(.undo))
            XCTAssertEqual(store.state, state)
        }
    }

    @MainActor
    func testCitywideUtilityConstructionHonorsBlockingModal() throws {
        let state = CityGameState.newCity(seed: 42)
        for kind in [BuildingKind.powerPlant, .waterTower] {
            let store = CityGameStore(state: state)
            store.presentBlockingModal(.newRegionSetup)
            let focus = store.mapFocusRequestGeneration
            let mode = store.interactionMode
            let speed = store.speed
            XCTAssertFalse(CityUtilityDecisionView(store: store).beginConstruction(kind))
            XCTAssertEqual(store.interactionMode, mode)
            XCTAssertEqual(store.speed, speed)
            XCTAssertEqual(store.mapFocusRequestGeneration, focus)
            XCTAssertNil(store.selectedCoordinate)
            XCTAssertEqual(store.state, state)
            XCTAssertFalse(store.canUndo)
        }
    }
}
