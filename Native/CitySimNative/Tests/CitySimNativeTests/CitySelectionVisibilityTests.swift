import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CitySelectionVisibilityTests: XCTestCase {
    @MainActor
    func testPendingParcelResizeKeepsDistrictScaleAcrossChangingChromeMeasurements() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        store.speed = .paused
        let compact = CGSize(width: 900, height: 600)
        let regular = CGSize(width: 1280, height: 800)
        var frames = CityHUDChromeFrames()
        let host = NSHostingView(rootView: ContentView(store: store) { frames = $0 }
            .transaction { $0.disablesAnimations = true }
            .frame(width: compact.width, height: compact.height))
        host.frame = CGRect(origin: .zero, size: compact)
        settle(host)
        let scene = try XCTUnwrap(findMap(in: host)?.scene as? CityScene)
        store.selectTool(.commercial)
        let target = GridCoordinate(x: 11, y: 11)
        store.selectedCoordinate = target
        settle(host)
        scene.frameCity()
        let state = store.state
        var scale = scene.cameraScaleForTesting
        for (index, size) in [regular, compact, regular, compact].enumerated() {
            if index == 2 {
                scene.zoomCameraForTesting(by: 0.9, anchoredAt: scene.scenePointForTesting(at: target))
                scale = scene.cameraScaleForTesting
            }
            host.rootView = ContentView(store: store) { frames = $0 }
                .transaction { $0.disablesAnimations = true }
                .frame(width: size.width, height: size.height)
            host.frame = CGRect(origin: .zero, size: size)
            settle(host)
            XCTAssertTrue(findMap(in: host)?.scene === scene)
            XCTAssertEqual(scene.size, size)
            XCTAssertEqual(scene.cameraScaleForTesting, scale, accuracy: 0.000_001,
                "Resize must not fit pending development against intermediate chrome measurements: \(size), \(frames)")
            let insets = ContentView.mapViewportInsets(windowSize: size,
                compact: ContentView.isCompactLayout(size), chromeFrames: frames)
            XCTAssertTrue(scene.safeViewportRectForTesting(insets).contains(scene.scenePointForTesting(at: target)))
            XCTAssertEqual(store.selectedCoordinate, target)
            XCTAssertEqual(store.state, state)
        }
    }

    @MainActor
    func testBuildFinanceRoundTripPreservesDistrictScaleAndPlayerZoom() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            var state = CityGameState.newCity(seed: 42)
            let power = try XCTUnwrap(state.tiles.first { $0.kind == .powerPlant }?.coordinate)
            let target = try XCTUnwrap(state.tiles.filter { tile in
                if case .success = CitySimulation.validateBuild(.waterTower, at: tile.coordinate, in: state) {
                    return true
                }
                return false
            }.min {
                abs($0.coordinate.x - power.x) + abs($0.coordinate.y - power.y)
                    < abs($1.coordinate.x - power.x) + abs($1.coordinate.y - power.y)
            }?.coordinate)
            state.treasury = 0
            let store = CityGameStore(state: state)
            store.speed = .paused
            let fingerprint = try CityStateFingerprinter.fingerprint(store.state)
            var frames = CityHUDChromeFrames()
            let host = NSHostingView(rootView:
                ContentView(store: store) { frames = $0 }
                    .transaction { $0.disablesAnimations = true }
                    .frame(width: size.width, height: size.height)
            )
            host.frame = CGRect(origin: .zero, size: size)
            settle(host)
            let scene = try XCTUnwrap(findMap(in: host)?.scene as? CityScene)
            store.selectTool(.waterTower)
            store.selectedCoordinate = target
            settle(host)
            let decision = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction.buildDecision)
            let recovery = try XCTUnwrap(decision.recovery)
            XCTAssertEqual(recovery.command, .inspectorFinances)
            let scale = scene.cameraScaleForTesting

            XCTAssertTrue(store.performBuildRecovery(recovery))
            settle(host)
            XCTAssertTrue(store.showInspector)
            XCTAssertFalse(frames.inspector.isEmpty)
            XCTAssertEqual(scene.cameraScaleForTesting, scale, accuracy: 0.000_001,
                "Temporary finance chrome must not shrink the district: \(size)")
            let panelInsets = ContentView.mapViewportInsets(
                windowSize: size, compact: ContentView.isCompactLayout(size), chromeFrames: frames
            )
            XCTAssertTrue(scene.safeViewportRectForTesting(panelInsets).contains(scene.scenePointForTesting(at: target)))
            store.toggleInspector()
            settle(host)
            XCTAssertEqual(scene.cameraScaleForTesting, scale, accuracy: 0.000_001)
            XCTAssertEqual(store.selectedCoordinate, target)
            XCTAssertEqual(store.interactionMode, .build(.waterTower))

            XCTAssertTrue(store.performBuildRecovery(recovery))
            settle(host)
            XCTAssertTrue(store.performMapCommand(.mapMoveEast))
            settle(host)
            let movedTarget = try XCTUnwrap(store.selectedCoordinate)
            XCTAssertNotEqual(movedTarget, target)
            XCTAssertEqual(scene.cameraScaleForTesting, scale, accuracy: 0.000_001,
                "Keyboard targets stay legible while temporary Details is open")
            XCTAssertTrue(scene.safeViewportRectForTesting(panelInsets).contains(scene.scenePointForTesting(at: movedTarget)))
            scene.zoomCameraForTesting(by: 0.9, anchoredAt: scene.scenePointForTesting(at: target))
            let playerScale = scene.cameraScaleForTesting
            store.toggleInspector()
            settle(host)
            XCTAssertEqual(scene.cameraScaleForTesting, playerScale, accuracy: 0.000_001,
                "Closing a panel must preserve an explicit zoom made while it was open")
            XCTAssertEqual(store.selectedCoordinate, movedTarget)
            XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
            XCTAssertFalse(store.canUndo)
        }
    }

    @MainActor
    func testComposedDetailsReportsItsFloatingBoundsAndRevealsTheSameBuilding() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            let state = CityGameState.newCity(seed: 42)
            let coordinate = try XCTUnwrap(state.tiles.first { $0.kind == .powerPlant }?.coordinate)
            let store = CityGameStore(state: state)
            store.speed = .paused
            let fingerprint = try CityStateFingerprinter.fingerprint(store.state)
            var frames = CityHUDChromeFrames()
            let host = NSHostingView(rootView:
                ContentView(store: store) { frames = $0 }
                    .transaction { $0.disablesAnimations = true }
                    .frame(width: size.width, height: size.height)
            )
            host.frame = CGRect(origin: .zero, size: size)
            settle(host)
            let map = try XCTUnwrap(findMap(in: host))
            let scene = try XCTUnwrap(map.scene as? CityScene)
            XCTAssertFalse(frames.bottom.isEmpty)
            XCTAssertTrue(frames.inspector.isEmpty)
            let closedRail = frames.bottom

            store.select(coordinate)
            settle(host)
            XCTAssertTrue(store.showInspector)
            XCTAssertFalse(frames.inspector.isEmpty, "Floating Details must be measured, not just the unchanged rail")
            XCTAssertLessThan(frames.inspector.minY, frames.bottom.minY - 200)
            XCTAssertLessThanOrEqual(frames.inspector.maxY, frames.bottom.minY - 7)
            XCTAssertEqual(frames.bottom, closedRail, "Measuring Details must not expand the persistent rail")
            let insets = ContentView.mapViewportInsets(
                windowSize: size, compact: ContentView.isCompactLayout(size), chromeFrames: frames
            )
            XCTAssertGreaterThanOrEqual(insets.bottom, size.height - frames.inspector.minY)
            XCTAssertTrue(scene.inspectedPlaceViewportForTesting(insets)
                .contains(scene.inspectedPlaceBoundsForTesting(at: coordinate)), "\(size)")
            let position = scene.cameraPositionForTesting
            let scale = scene.cameraScaleForTesting

            store.toggleInspector()
            settle(host)
            XCTAssertTrue(frames.inspector.isEmpty, "Closing Details must release the temporary exclusion")
            XCTAssertEqual(frames.bottom, closedRail)
            XCTAssertEqual(scene.cameraPositionForTesting, position, "Closing must not snap the inspected place away")
            XCTAssertEqual(scene.cameraScaleForTesting, scale)
            store.toggleInspector()
            settle(host)
            XCTAssertFalse(frames.inspector.isEmpty)
            XCTAssertEqual(store.selectedCoordinate, coordinate)
            XCTAssertEqual(scene.cameraPositionForTesting, position, "Repeated open/close must not drift")
            XCTAssertEqual(scene.cameraScaleForTesting, scale)

            XCTAssertTrue(store.performMapFocused(.buildWaterTower))
            settle(host)
            XCTAssertFalse(store.showInspector)
            XCTAssertTrue(frames.inspector.isEmpty)
            let buildInsets = ContentView.mapViewportInsets(
                windowSize: size, compact: ContentView.isCompactLayout(size), chromeFrames: frames
            )
            let expected = CityScene(size: scene.size)
            expected.reducedMotion = true
            expected.updateViewportInsets(buildInsets)
            expected.render(state: state, overlay: store.overlay, selection: nil, interactionMode: .inspect)
            expected.camera?.position = position
            expected.camera?.setScale(scale)
            expected.render(
                state: state, overlay: store.overlay, selection: store.selectedCoordinate,
                interactionMode: store.interactionMode,
                activeActionTarget: store.activeMapActionTargetPresentation
            )
            XCTAssertLessThanOrEqual(scene.cameraScaleForTesting, expected.cameraScaleForTesting + 0.001,
                "A build response must not retain a zoom-out calculated against outgoing Details")
            XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
        }
    }

    @MainActor
    private func settle(_ view: NSView) {
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        view.layoutSubtreeIfNeeded()
    }

    @MainActor
    private func findMap(in view: NSView) -> CityMapSKView? {
        if let map = view as? CityMapSKView { return map }
        return view.subviews.lazy.compactMap { self.findMap(in: $0) }.first
    }

    @MainActor
    func testInspectedTallBuildingFitsBothNativeAperturesWithoutChangingCityOrNormalZoom() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            var state = CityGameState.newCity(seed: 42)
            let coordinate = GridCoordinate(x: 3, y: 9)
            state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: .powerPlant) }
            let fingerprint = try CityStateFingerprinter.fingerprint(state)
            let scene = CityScene(size: size)
            scene.reducedMotion = true
            let insets = CityMapViewportInsets(top: 86, leading: 24, bottom: 90, trailing: 24)
            scene.updateViewportInsets(insets)
            scene.render(state: state, overlay: .water, selection: nil, interactionMode: .inspect)
            let offset = size.width == 900 ? 3 : 5
            scene.configureProofCamera(
                detail: .neighborhood,
                centeredOn: .init(x: coordinate.x + offset, y: coordinate.y + offset),
                framingScale: 1.1
            )
            let bounds = scene.inspectedPlaceBoundsForTesting(at: coordinate)
            let before = scene.inspectedPlaceViewportForTesting(insets)
            XCTAssertGreaterThan(before.width, bounds.width)
            XCTAssertGreaterThan(before.height, bounds.height)
            XCTAssertTrue(before.contains(scene.scenePointForTesting(at: coordinate)))
            XCTAssertFalse(before.contains(bounds), "Ground-point visibility must not hide the clipped roof regression")
            XCTAssertGreaterThan(bounds.height, scene.tileGroundBoundsForTesting(at: coordinate).height * 3)
            XCTAssertTrue(scene.tileDescendantNamesForTesting(at: coordinate).contains { $0.hasPrefix("lot.four-view.") })
            let scale = scene.cameraScaleForTesting
            scene.render(state: state, overlay: .water, selection: coordinate, interactionMode: .inspect)
            XCTAssertTrue(scene.inspectedPlaceViewportForTesting(insets).contains(bounds), "\(size): \(bounds)")
            XCTAssertEqual(scene.cameraScaleForTesting, scale, accuracy: 0.000_001)
            XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), fingerprint)
            XCTAssertFalse(scene.selectionIsHiddenForTesting)

            let position = scene.cameraPositionForTesting
            scene.revealSelection(coordinate, viewportInsets: insets)
            XCTAssertEqual(scene.cameraPositionForTesting, position, "Repeated focus must not drift")
            XCTAssertEqual(scene.cameraScaleForTesting, scale, accuracy: 0.000_001)
        }
    }

    @MainActor
    func testOpeningDetailsKeepsTheSameInspectedBuildingInsideTheReducedAperture() {
        let state = CityGameState.newCity(seed: 42)
        let coordinate = state.tiles.first { $0.kind == .powerPlant }!.coordinate
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.reducedMotion = true
        let closed = CityMapViewportInsets(top: 86, leading: 24, bottom: 90, trailing: 24)
        let details = CityMapViewportInsets(top: 86, leading: 24, bottom: 330, trailing: 24)
        scene.updateViewportInsets(closed)
        scene.render(state: state, overlay: .none, selection: coordinate, interactionMode: .inspect)
        scene.updateViewportInsets(details)
        XCTAssertTrue(scene.inspectedPlaceViewportForTesting(details).contains(scene.inspectedPlaceBoundsForTesting(at: coordinate)))
        let position = scene.cameraPositionForTesting
        let scale = scene.cameraScaleForTesting
        scene.render(state: state, overlay: .water, selection: coordinate, interactionMode: .inspect)
        XCTAssertEqual(scene.cameraPositionForTesting, position)
        XCTAssertEqual(scene.cameraScaleForTesting, scale)
        scene.updateViewportInsets(closed)
        XCTAssertTrue(scene.inspectedPlaceViewportForTesting(closed).contains(scene.inspectedPlaceBoundsForTesting(at: coordinate)))
    }

    @MainActor
    func testKeyboardLikeSelectionAcrossDevelopedPlacesRetainsEveryAuthoredBuilding() {
        let state = CityGameState.newCity(seed: 42)
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.reducedMotion = true
        let insets = CityMapViewportInsets(top: 86, leading: 24, bottom: 90, trailing: 24)
        scene.updateViewportInsets(insets)
        for tile in state.tiles where tile.kind != .empty && tile.kind != .road {
            scene.render(state: state, overlay: .none, selection: tile.coordinate, interactionMode: .inspect)
            XCTAssertTrue(scene.inspectedPlaceViewportForTesting(insets).contains(scene.inspectedPlaceBoundsForTesting(at: tile.coordinate)), "\(tile.kind) \(tile.coordinate)")
            XCTAssertTrue(scene.activeTargetContextBoundsForTesting.isNull)
            XCTAssertNil(scene.activeTargetRoadFrontierForTesting)
        }
    }

    @MainActor
    func testUnmeasuredOrDegenerateApertureCannotProduceInvalidCameraGeometry() {
        let state = CityGameState.newCity(seed: 42)
        let coordinate = state.tiles.first { $0.kind == .powerPlant }!.coordinate
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: coordinate, interactionMode: .inspect)
        scene.revealSelection(coordinate, viewportInsets: .init(top: 400, leading: 600, bottom: 400, trailing: 600))
        XCTAssertTrue(scene.cameraPositionForTesting.x.isFinite)
        XCTAssertTrue(scene.cameraPositionForTesting.y.isFinite)
        XCTAssertTrue(scene.cameraScaleForTesting.isFinite)
        XCTAssertGreaterThan(scene.cameraScaleForTesting, 0)
    }
}
