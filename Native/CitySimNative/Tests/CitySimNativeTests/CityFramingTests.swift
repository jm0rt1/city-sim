import AppKit
import SpriteKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityFramingTests: XCTestCase {
    @MainActor
    func testInitialAndExplicitFrameContainTallAuthoredPlacesWithoutChangingTheirGeometry() throws {
        let state = grownCity()
        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            let insets = CityMapViewportInsets(top: 86, leading: 24, bottom: 90, trailing: 24)
            let scene = CityScene(size: size)
            scene.reducedMotion = true
            scene.updateViewportInsets(insets)
            scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
            assertDistrictFits(scene, insets: insets)
            let tower = GridCoordinate(x: 3, y: 9)
            let bounds = scene.inspectedPlaceBoundsForTesting(at: tower)
            let root = scene.tileRootIdentifier(at: tower)
            scene.zoomCameraForTesting(by: 0.7, anchoredAt: scene.scenePointForTesting(at: tower))
            scene.frameCity()
            assertDistrictFits(scene, insets: insets)
            XCTAssertEqual(scene.inspectedPlaceBoundsForTesting(at: tower), bounds)
            XCTAssertEqual(scene.tileRootIdentifier(at: tower), root)
            let scale = scene.cameraScaleForTesting
            let position = scene.cameraPositionForTesting
            scene.frameCity()
            XCTAssertEqual(scene.cameraScaleForTesting, scale, accuracy: 0.000_001)
            XCTAssertEqual(scene.cameraPositionForTesting, position)
            scene.zoomCameraForTesting(by: 1.1, anchoredAt: nil)
            XCTAssertGreaterThanOrEqual(scene.cameraScaleForTesting, scale,
                "Zoom out at the framed stop must never zoom in")
            XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), fingerprint)
        }
    }

    @MainActor
    func testComposedHUDResizeKeepsFramedDistrictVisibleAndPreservesPlayerZoom() throws {
        let state = grownCity()
        let store = CityGameStore(state: state, startsPaused: true)
        var frames = CityHUDChromeFrames()
        let compact = CGSize(width: 900, height: 600)
        let regular = CGSize(width: 1280, height: 800)
        let host = NSHostingView(rootView: ContentView(store: store) { frames = $0 }
            .transaction { $0.disablesAnimations = true }.frame(width: compact.width, height: compact.height))
        host.frame = CGRect(origin: .zero, size: compact)
        settle(host)
        let scene = try XCTUnwrap(findMap(in: host)?.scene as? CityScene)
        for size in [compact, regular, compact] {
            host.rootView = ContentView(store: store) { frames = $0 }
                .transaction { $0.disablesAnimations = true }.frame(width: size.width, height: size.height)
            host.frame = CGRect(origin: .zero, size: size)
            settle(host)
            let insets = ContentView.mapViewportInsets(windowSize: size,
                compact: ContentView.isCompactLayout(size), chromeFrames: frames)
            assertDistrictFits(scene, insets: insets)
            scene.frameCity()
            assertDistrictFits(scene, insets: insets)
        }
        scene.zoomCameraForTesting(by: 0.75, anchoredAt: nil)
        let zoom = scene.cameraScaleForTesting
        store.openInspector(.finances)
        settle(host)
        XCTAssertEqual(scene.cameraScaleForTesting, zoom, accuracy: 0.000_001)
        XCTAssertEqual(store.state, state)
        XCTAssertNil(store.selectedCoordinate)
    }

    @MainActor
    func testRemoteIsolatedPlaceAndTransientCuesDoNotShrinkTheLivedDistrict() {
        var state = grownCity()
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.reducedMotion = true
        scene.updateViewportInsets(.init(top: 86, leading: 24, bottom: 90, trailing: 24))
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        scene.frameCity()
        let scale = scene.cameraScaleForTesting
        let position = scene.cameraPositionForTesting
        let remote = GridCoordinate(x: 23, y: 0)
        state.updateTile(at: remote) { $0.kind = .waterTower }
        scene.render(state: state, overlay: .water, selection: nil, interactionMode: .inspect)
        scene.frameCity()
        XCTAssertFalse(scene.cameraPriorityCoordinatesForTesting.contains(remote))
        XCTAssertEqual(scene.cameraScaleForTesting, scale, accuracy: 0.000_001)
        XCTAssertEqual(scene.cameraPositionForTesting, position)
        XCTAssertNotNil(scene.tileRootIdentifier(at: remote), "Remote truth remains rendered and inspectable")
    }

    @MainActor
    private func assertDistrictFits(_ scene: CityScene, insets: CityMapViewportInsets,
                                    file: StaticString = #filePath, line: UInt = #line) {
        let aperture = scene.inspectedPlaceViewportForTesting(insets)
        var occupied = CGRect.null
        XCTAssertFalse(scene.cameraPriorityCoordinatesForTesting.isEmpty, file: file, line: line)
        for coordinate in scene.cameraPriorityCoordinatesForTesting {
            let bounds = scene.inspectedPlaceBoundsForTesting(at: coordinate)
            XCTAssertTrue(aperture.contains(bounds), "Cropped \(coordinate): \(bounds) outside \(aperture)", file: file, line: line)
            occupied = occupied.union(bounds)
        }
        XCTAssertGreaterThan(occupied.width / aperture.width, 0.5, "Keep the lived district legible", file: file, line: line)
    }

    private func grownCity() -> CityGameState {
        var state = CityGameState.newCity()
        state.updateTile(at: GridCoordinate(x: 3, y: 9)) { $0.kind = .waterTower }
        state.updateTile(at: GridCoordinate(x: 10, y: 10)) { $0.kind = .commercial }
        return state
    }

    @MainActor
    private func settle(_ host: NSView) {
        for _ in 0..<5 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    @MainActor
    private func findMap(in view: NSView) -> CityMapSKView? {
        if let map = view as? CityMapSKView { return map }
        return view.subviews.lazy.compactMap { self.findMap(in: $0) }.first
    }
}
