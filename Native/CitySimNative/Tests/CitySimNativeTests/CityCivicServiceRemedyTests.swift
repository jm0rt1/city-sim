import AppKit
import XCTest
@testable import CitySimNative

final class CityCivicServiceRemedyTests: XCTestCase {
    private let services: [BuildingKind] = [.fireStation, .policeStation, .school]
    private let home = GridCoordinate(x: 3, y: 9)

    @MainActor
    func testDiagnosedServiceRemediesOpenCancelablePlacementWithoutChangingCity() throws {
        for kind in services {
            let state = district(missing: kind)
            let response = try remedy(for: kind, in: state)
            let store = CityGameStore(state: state)
            store.select(home)
            store.overlay = .services
            store.speed = .fastest
            let focus = store.mapFocusRequestGeneration
            let guide = store.foundationsGuideProgress

            StrategyCommandCenterView.perform(response, on: store)

            XCTAssertEqual(store.interactionMode, .build(kind), kind.title)
            XCTAssertEqual(store.selectedTool, kind)
            XCTAssertEqual(store.selectedBuildCategory, .services)
            XCTAssertFalse(store.showInspector)
            XCTAssertEqual(store.speed, .paused)
            XCTAssertEqual(store.overlay, .services)
            XCTAssertEqual(store.mapFocusRequestGeneration, focus + 1)
            XCTAssertEqual(store.state, state)
            XCTAssertEqual(store.foundationsGuideProgress, guide)
            XCTAssertFalse(store.canUndo)
            let target = try XCTUnwrap(store.activeMapActionTargetPresentation)
            XCTAssertTrue(target.primaryAction.isAvailable)
            let decision = try XCTUnwrap(target.primaryAction.buildDecision)
            XCTAssertEqual(decision.buildingTitle, kind.title)
            XCTAssertTrue(decision.accessibilitySummary.contains(kind.buildCost.currencyText))
            XCTAssertNil(decision.disabledReason)

            store.cancelBuildDecision()

            XCTAssertNil(store.selectedCoordinate)
            XCTAssertEqual(store.interactionMode, .build(kind))
            XCTAssertEqual(store.state, state)
            XCTAssertEqual(store.foundationsGuideProgress, guide)
            XCTAssertFalse(store.canUndo)
        }
    }

    @MainActor
    func testDiagnosedServiceRemediesCommitOnlyOnConfirmationAndUndoExactly() throws {
        for kind in services {
            let state = district(missing: kind)
            let store = CityGameStore(state: state)
            store.select(home)
            StrategyCommandCenterView.perform(try remedy(for: kind, in: state), on: store)
            let target = try XCTUnwrap(store.selectedCoordinate)

            XCTAssertTrue(store.performMapCommand(.mapPrimaryAction))
            XCTAssertEqual(store.state.tile(at: target)?.kind, kind)
            XCTAssertEqual(store.state.treasury, state.treasury - kind.buildCost)
            XCTAssertLessThan(try XCTUnwrap(store.state.tile(at: target)).constructionProgress, 1)
            XCTAssertTrue(store.perform(.undo))
            XCTAssertEqual(store.state, state)
        }
    }

    @MainActor
    func testRemedyFocusProtectsSuggestedParcelUntilIntentionalPointerMovement() throws {
        let state = district(missing: .fireStation)
        let store = CityGameStore(state: state)
        let gate = CityMapPointerTransitionGate()
        var queued: [CitySceneView.Coordinator.MainLoopAction] = []
        let coordinator = CitySceneView.Coordinator(store: store, pointerTransitionGate: gate) {
            queued.append($0)
        }
        let map = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 1280, height: 800))
        let window = NSWindow(contentRect: map.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = map
        defer { gate.cancel() }
        store.select(home)
        StrategyCommandCenterView.perform(try remedy(for: .fireStation, in: state), on: store)
        let suggested = try XCTUnwrap(store.selectedCoordinate)
        XCTAssertTrue(coordinator.synchronizeMapFocusRequest(store.mapFocusRequestGeneration, in: map))
        XCTAssertEqual(queued.count, 1)
        queued.removeFirst()()
        XCTAssertTrue(window.firstResponder === map)
        let staleHover = GridCoordinate(x: 0, y: 0)

        XCTAssertNil(coordinator.acceptPointerMapActionCandidate(staleHover, in: map))
        XCTAssertFalse(coordinator.performPointerPrimaryAction(at: staleHover, in: map))
        XCTAssertEqual(store.selectedCoordinate, suggested)
        let anchor = try XCTUnwrap(gate.anchor)
        let stationary = try XCTUnwrap(NSEvent.mouseEvent(
            with: .mouseMoved, location: anchor, modifierFlags: [], timestamp: 1,
            windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 0, pressure: 0
        ))
        XCTAssertFalse(gate.observeMovement(stationary))
        XCTAssertNil(coordinator.acceptPointerMapActionCandidate(staleHover, in: map))
        // Keyboard and VoiceOver keep their authoritative target while hover is quarantined.
        XCTAssertTrue(store.canPerformMapCommand(.mapPrimaryAction))
        coordinator.configureMapAccessibility(in: map)
        XCTAssertTrue((map.accessibilityValue() as? String)?.contains("pending Fire Station placement") == true)
        XCTAssertEqual(store.state, state)

        let movement = try XCTUnwrap(NSEvent.mouseEvent(
            with: .mouseMoved,
            location: NSPoint(x: anchor.x + CityMapPointerTransitionGate.movementThreshold + 1, y: anchor.y),
            modifierFlags: [], timestamp: 2, windowNumber: window.windowNumber,
            context: nil, eventNumber: 2, clickCount: 0, pressure: 0
        ))
        XCTAssertTrue(gate.observeMovement(movement))
        XCTAssertNotNil(coordinator.acceptPointerMapActionCandidate(staleHover, in: map))
        XCTAssertEqual(store.selectedCoordinate, staleHover)
        XCTAssertEqual(store.state, state)
    }

    @MainActor
    func testWelcomeQuarantinesEveryDiagnosedServiceRemedy() throws {
        for kind in services {
            let state = district(missing: kind)
            let store = CityGameStore(state: state, commandPolicy: .blocked(.welcome))
            let mode = store.interactionMode
            let speed = store.speed
            StrategyCommandCenterView.perform(try remedy(for: kind, in: state), on: store)
            XCTAssertEqual(store.interactionMode, mode)
            XCTAssertEqual(store.speed, speed)
            XCTAssertNil(store.selectedCoordinate)
            XCTAssertEqual(store.mapFocusRequestGeneration, 0)
            XCTAssertEqual(store.state, state)
            XCTAssertFalse(store.canUndo)
        }
    }

    private func remedy(for kind: BuildingKind, in state: CityGameState) throws -> CityDirectResponse {
        let snapshot = try CityPresentationSnapshot(state: state)
        let diagnosis = try XCTUnwrap(CitySelectedLocationDiagnosis.make(
            tile: XCTUnwrap(state.tile(at: home)), snapshot: snapshot
        ))
        let response = try XCTUnwrap(diagnosis.responses.first {
            $0.command == CityCommandCatalog.id(for: kind)
        })
        XCTAssertTrue(response.focusesMap)
        XCTAssertEqual(response.title, "Build \(kind.title.lowercased())")
        return response
    }

    private func district(missing: BuildingKind) -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for tile in state.tiles {
            state.updateTile(at: tile.coordinate) { $0 = CityTile(coordinate: tile.coordinate, kind: .empty) }
        }
        for x in 2...10 {
            let coordinate = GridCoordinate(x: x, y: 10)
            state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: .road) }
        }
        state.updateTile(at: home) { $0 = CityTile(coordinate: home, kind: .residential) }
        for (index, kind) in services.enumerated() where kind != missing {
            let coordinate = GridCoordinate(x: index + 2, y: 11)
            state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: kind) }
        }
        return state
    }
}
