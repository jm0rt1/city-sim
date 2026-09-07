import AppKit
import SpriteKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityDiagnosticFocusTests: XCTestCase {
    @MainActor
    func testUtilityGapLeavesThePanelAtAReadablePlaceAndPreservesSubsequentPlayerZoom() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            for overlay in [DataOverlay.power, .water] {
                var state = CityGameState.newCity(seed: 42)
                state.updateTile(at: .init(x: 3, y: 9)) { $0.kind = .waterTower }
                let store = CityGameStore(state: state, startsPaused: true)
                var frames = CityHUDChromeFrames()
                let host = NSHostingView(rootView: ContentView(store: store) { frames = $0 }
                    .transaction { $0.disablesAnimations = true }
                    .frame(width: size.width, height: size.height))
                host.frame = CGRect(origin: .zero, size: size)
                settle(host)
                let map = try XCTUnwrap(findMap(in: host))
                let scene = try XCTUnwrap(map.scene as? CityScene)
                store.openInspector(.utilities)
                settle(host)
                let panelScale = scene.cameraScaleForTesting
                XCTAssertTrue(store.focusUtilityServiceGap(overlay))
                settle(host)
                let target = try XCTUnwrap(store.selectedCoordinate)
                let bounds = scene.inspectedPlaceBoundsForTesting(at: target)
                let insets = ContentView.mapViewportInsets(windowSize: size,
                    compact: ContentView.isCompactLayout(size), chromeFrames: frames)
                XCTAssertTrue(frames.inspector.isEmpty)
                XCTAssertTrue(scene.inspectedPlaceViewportForTesting(insets).contains(bounds))
                XCTAssertGreaterThan(bounds.height / scene.cameraScaleForTesting, 120,
                    "Find must reveal a readable place, not retain the panel's tiny island: \(size), \(overlay)")
                XCTAssertLessThan(scene.cameraScaleForTesting, panelScale * 0.8)
                XCTAssertEqual(store.overlay, overlay)
                XCTAssertEqual(store.state, state)
                XCTAssertFalse(store.canUndo)

                scene.zoomCameraForTesting(by: 0.82, anchoredAt: scene.scenePointForTesting(at: target))
                let playerScale = scene.cameraScaleForTesting
                store.lastFeedback = "Diagnostic focus settled"
                settle(host)
                XCTAssertEqual(scene.cameraScaleForTesting, playerScale, accuracy: 0.000_001,
                    "Ordinary updates must not replay the explicit camera request")
                XCTAssertEqual(store.selectedCoordinate, target)
                XCTAssertTrue(map.cityAccessibilityValue.contains("\(overlay.title) overlay active"))
            }
        }
    }

    @MainActor
    func testExplicitRequestsAreOneShotAndOrdinarySelectionAndBlockedActionsDoNotRefocus() throws {
        let store = CityGameStore(state: .newCity(seed: 42), startsPaused: true)
        let coordinator = CitySceneView.Coordinator(store: store)
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        coordinator.scene = scene
        coordinator.viewportInsets = .init(top: 86, leading: 24, bottom: 110, trailing: 24)
        scene.updateViewportInsets(coordinator.viewportInsets)
        scene.render(state: store.state, overlay: .none, selection: nil, interactionMode: .inspect)
        let ordinary = try XCTUnwrap(store.state.tiles.first { $0.kind == .residential }?.coordinate)
        store.select(ordinary)
        XCTAssertFalse(coordinator.synchronizeDiagnosticFocusRequest(store.diagnosticFocusRequestGeneration))

        XCTAssertTrue(store.focusUtilityServiceGap(.power))
        scene.render(state: store.state, overlay: store.overlay,
            selection: store.selectedCoordinate, interactionMode: .inspect)
        XCTAssertTrue(coordinator.synchronizeDiagnosticFocusRequest(store.diagnosticFocusRequestGeneration))
        scene.zoomCameraForTesting(by: 0.82, anchoredAt: nil)
        let playerScale = scene.cameraScaleForTesting
        let playerPosition = scene.cameraPositionForTesting
        XCTAssertFalse(coordinator.synchronizeDiagnosticFocusRequest(store.diagnosticFocusRequestGeneration))
        XCTAssertEqual(scene.cameraScaleForTesting, playerScale)
        XCTAssertEqual(scene.cameraPositionForTesting, playerPosition)
        let generation = store.diagnosticFocusRequestGeneration
        XCTAssertTrue(store.focusUtilityServiceGap(.power), "The same Find action may be deliberately repeated")
        XCTAssertEqual(store.diagnosticFocusRequestGeneration, generation + 1)
        XCTAssertTrue(coordinator.synchronizeDiagnosticFocusRequest(store.diagnosticFocusRequestGeneration))
        XCTAssertEqual(scene.cameraScaleForTesting, playerScale, accuracy: 0.000_001,
            "Find preserves an already closer player zoom when the whole place fits")

        store.presentBlockingModal(.newRegionSetup)
        let blockedGeneration = store.diagnosticFocusRequestGeneration
        XCTAssertFalse(store.focusUtilityServiceGap(.water))
        XCTAssertEqual(store.diagnosticFocusRequestGeneration, blockedGeneration)
        XCTAssertFalse(coordinator.synchronizeDiagnosticFocusRequest(blockedGeneration))
    }

    @MainActor
    private func settle(_ host: NSView) {
        for _ in 0..<6 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }
    }

    @MainActor
    private func findMap(in view: NSView) -> CityMapSKView? {
        if let map = view as? CityMapSKView { return map }
        return view.subviews.lazy.compactMap { self.findMap(in: $0) }.first
    }
}
