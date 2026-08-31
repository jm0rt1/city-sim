import XCTest
@testable import CitySimNative

final class CitySelectionVisibilityTests: XCTestCase {
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
