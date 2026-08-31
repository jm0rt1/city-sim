import AppKit
import SpriteKit
import XCTest
@testable import CitySimNative

final class CityNativeResizeTests: XCTestCase {
    @MainActor
    func testResizePerimeterAndLiveResizeDoNotRetargetPendingDevelopment() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            let store = CityGameStore(state: .newCity(seed: 42))
            store.speed = .paused
            store.selectTool(.commercial)
            let target = GridCoordinate(x: 11, y: 11)
            store.selectedCoordinate = target
            let state = store.state
            let scene = CityScene(size: size)
            let view = CityMapSKView(frame: CGRect(origin: .zero, size: size))
            view.presentScene(scene)
            scene.render(state: state, overlay: .none, selection: target,
                interactionMode: store.interactionMode,
                activeActionTarget: store.activeMapActionTargetPresentation)
            scene.onActiveActionTargetCandidate = { store.acceptPointerMapActionCandidate($0) }
            scene.onPrimaryAction = { store.primaryAction(at: $0) }
            scene.frameCity()
            let scale = scene.cameraScaleForTesting
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for point in [CGPoint(x: 2, y: 2), CGPoint(x: size.width - 2, y: 2),
                          CGPoint(x: 2, y: size.height - 2), CGPoint(x: size.width - 2, y: size.height - 2)] {
                let hover = try event(.mouseMoved, at: point)
                XCTAssertFalse(view.acceptsMapPointerEvent(hover))
                scene.mouseMoved(with: hover)
                scene.mouseDown(with: try event(.leftMouseDown, at: point))
                scene.mouseUp(with: try event(.leftMouseUp, at: point))
            }
            view.viewWillStartLiveResize()
            XCTAssertFalse(view.acceptsMapPointerEvent(try event(.mouseMoved, at: center)))
            scene.mouseMoved(with: try event(.mouseMoved, at: center))
            scene.mouseDown(with: try event(.leftMouseDown, at: center))
            scene.mouseUp(with: try event(.leftMouseUp, at: center))
            view.viewDidEndLiveResize()
            scene.mouseUp(with: try event(.leftMouseUp, at: center))
            XCTAssertEqual(store.selectedCoordinate, target)
            XCTAssertEqual(store.state, state)
            XCTAssertFalse(store.canUndo)
            XCTAssertEqual(scene.cameraScaleForTesting, scale, accuracy: 0.000_001)
            XCTAssertTrue(view.acceptsMapPointerEvent(try event(.mouseMoved, at: center)))
        }
    }

    @MainActor
    func testUnmatchedOrResizeCanceledReleaseCannotActivateMapButFreshClickCan() throws {
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        let view = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        view.presentScene(scene)
        scene.render(state: .newCity(seed: 42), overlay: .none, selection: nil, interactionMode: .inspect)
        var actions = 0
        scene.onPrimaryAction = { _ in actions += 1 }
        let point = scene.convertPoint(toView: scene.scenePointForTesting(at: GridCoordinate(x: 11, y: 11)))
        let down = try event(.leftMouseDown, at: point)
        let up = try event(.leftMouseUp, at: point)
        scene.mouseUp(with: up)
        XCTAssertEqual(actions, 0)
        scene.mouseDown(with: down)
        view.viewWillStartLiveResize()
        view.viewDidEndLiveResize()
        scene.mouseUp(with: up)
        XCTAssertEqual(actions, 0)
        scene.mouseDown(with: down)
        scene.mouseUp(with: up)
        XCTAssertEqual(actions, 1)
    }

    @MainActor
    private func event(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
            timestamp: 1, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
    }
}
