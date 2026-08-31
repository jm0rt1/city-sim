import AppKit
import XCTest
@testable import CitySimNative

final class CityTrafficRemedyTests: XCTestCase {
    private let home = GridCoordinate(x: 4, y: 10)
    private let road = GridCoordinate(x: 6, y: 9)

    @MainActor
    func testRoadAndHomeDiagnosesOpenTrafficWithoutChangingTheirTargetOrCity() throws {
        for (state, coordinate, title) in [
            (district(), road, "Show traffic"),
            (district(), home, "Show traffic"),
            (district(connected: false), home, "Show commute routes")
        ] {
            let response = try trafficResponse(in: state, at: coordinate)
            XCTAssertEqual(response.title, title)
            let store = CityGameStore(state: state)
            store.select(coordinate)
            store.overlay = .services
            store.speed = .fastest
            let guide = store.foundationsGuideProgress
            let focus = store.mapFocusRequestGeneration

            StrategyCommandCenterView.perform(response, on: store)

            XCTAssertEqual(store.overlay, .traffic, title)
            XCTAssertEqual(store.speed, .paused, title)
            XCTAssertEqual(store.selectedCoordinate, coordinate)
            XCTAssertEqual(store.hudContextScope, .selection)
            XCTAssertEqual(store.interactionMode, .inspect)
            XCTAssertTrue(store.showInspector, "Keep the diagnosis available while comparing the map")
            XCTAssertEqual(store.mapFocusRequestGeneration, focus + 1)
            XCTAssertEqual(store.foundationsGuideProgress, guide)
            XCTAssertEqual(store.state, state)
            XCTAssertFalse(store.canUndo)
        }
    }

    @MainActor
    func testTrafficRemedyTransfersFocusOnceAndExposesTheLayerToAccessibility() throws {
        let state = district()
        let store = CityGameStore(state: state)
        store.select(road)
        var queued: [CitySceneView.Coordinator.MainLoopAction] = []
        let coordinator = CitySceneView.Coordinator(store: store) { queued.append($0) }
        let map = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let field = NSTextField(frame: CGRect(x: 0, y: 0, width: 100, height: 24))
        let content = NSView(frame: map.frame)
        content.addSubview(map)
        content.addSubview(field)
        let window = NSWindow(contentRect: map.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = content
        XCTAssertTrue(window.makeFirstResponder(field))

        StrategyCommandCenterView.perform(try trafficResponse(in: state, at: road), on: store)

        XCTAssertTrue(coordinator.synchronizeMapFocusRequest(store.mapFocusRequestGeneration, in: map))
        XCTAssertFalse(coordinator.synchronizeMapFocusRequest(store.mapFocusRequestGeneration, in: map))
        XCTAssertEqual(queued.count, 1)
        try XCTUnwrap(queued.first)()
        XCTAssertTrue(window.firstResponder === map)
        coordinator.configureMapAccessibility(in: map)
        let value = try XCTUnwrap(map.accessibilityValue() as? String)
        XCTAssertTrue(value.contains("Traffic overlay active"))
        XCTAssertTrue(value.contains("block 7, 10"))
        XCTAssertEqual(store.state, state)
    }

    @MainActor
    func testWelcomeStillQuarantinesRoadAndCommuteTrafficResponses() throws {
        for coordinate in [road, home] {
            let state = district(connected: false)
            let store = CityGameStore(state: state, commandPolicy: .blocked(.welcome))
            store.overlay = .services
            let speed = store.speed

            StrategyCommandCenterView.perform(try trafficResponse(in: state, at: coordinate), on: store)

            XCTAssertEqual(store.overlay, .services)
            XCTAssertEqual(store.speed, speed)
            XCTAssertNil(store.selectedCoordinate)
            XCTAssertEqual(store.mapFocusRequestGeneration, 0)
            XCTAssertEqual(store.state, state)
            XCTAssertFalse(store.canUndo)
        }
    }

    private func trafficResponse(in state: CityGameState, at coordinate: GridCoordinate) throws -> CityDirectResponse {
        let diagnosis = try XCTUnwrap(CitySelectedLocationDiagnosis.make(
            tile: XCTUnwrap(state.tile(at: coordinate)),
            snapshot: CityPresentationSnapshot(state: state)
        ))
        let response = try XCTUnwrap(diagnosis.responses.first { $0.command == .overlayTraffic })
        XCTAssertTrue(response.focusesMap)
        return response
    }

    private func district(connected: Bool = true) -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for index in state.tiles.indices {
            state.tiles[index] = CityTile(coordinate: state.tiles[index].coordinate, kind: .empty)
        }
        state.demand.commercial = 1
        state.updateTile(at: home) {
            $0.kind = .residential
            $0.occupancy = 280
        }
        state.updateTile(at: GridCoordinate(x: 10, y: 10)) {
            $0.kind = .commercial
            $0.occupancy = CitySimulation.commercialJobCapacity
        }
        for x in 4...10 where connected || x != 7 {
            state.updateTile(at: GridCoordinate(x: x, y: 9)) { $0.kind = .road }
        }
        return state
    }
}
