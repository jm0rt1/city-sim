import AppKit
import SpriteKit
import XCTest
@testable import CitySimNative

final class CityBuildingInspectionTests: XCTestCase {
    func testAlphaMaskMapsSourceRowsAndRejectsPaddingShadowsAndInvalidPoints() throws {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let bytes = try XCTUnwrap(bitmap.bitmapData)
        for y in 0..<2 {
            for x in 0..<2 {
                let offset = y * bitmap.bytesPerRow + x * 4
                for channel in 0..<3 { bytes[offset + channel] = 0 }
                bytes[offset + 3] = [[UInt8(255), 0], [51, 255]][y][x]
            }
        }
        let mask = try XCTUnwrap(CitySpriteAlphaMask(bitmap: bitmap))
        XCTAssertTrue(mask.containsOpaquePixel(at: .init(x: 0.25, y: 0.75)))
        XCTAssertFalse(mask.containsOpaquePixel(at: .init(x: 0.75, y: 0.75)))
        XCTAssertFalse(mask.containsOpaquePixel(at: .init(x: 0.25, y: 0.25)))
        XCTAssertTrue(mask.containsOpaquePixel(at: .init(x: 0.75, y: 0.25)))
        for point in [CGPoint(x: -0.01, y: 0.5), .init(x: 1, y: 0.5), .init(x: 0.5, y: 1), .init(x: CGFloat.infinity, y: 0)] {
            XCTAssertFalse(mask.containsOpaquePixel(at: point))
        }
    }

    @MainActor
    func testOpaqueRoofInspectsItsBuildingAtBothSizesAndEveryLODWithoutChangingState() throws {
        let target = GridCoordinate(x: 12, y: 12)
        let state = district(buildings: [target])
        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            let scene = CityScene(size: size)
            scene.reducedMotion = true
            scene.render(state: state, overlay: .water, selection: nil, interactionMode: .inspect)
            let sprite = try inspectionSprite(in: scene, at: target)
            XCTAssertNotNil(sprite.inspectionMask)
            let roof = try sourceOpaquePoint(on: sprite, in: scene) { ground($0, in: scene, state: state) != target }
            XCTAssertTrue(sprite.containsOpaquePixel(at: sprite.convert(roof, from: scene)))
            for detail in CameraDetailLevel.allCases {
                scene.configureProofCamera(detail: detail, centeredOn: target)
                XCTAssertEqual(scene.resolvedCoordinateForTesting(at: roof), target, "\(size) \(detail)")
                var activated: GridCoordinate?
                scene.onPrimaryAction = { activated = $0 }
                scene.activatePrimaryActionForTesting(at: try XCTUnwrap(scene.resolvedCoordinateForTesting(at: roof)))
                XCTAssertEqual(activated, target)
            }
            XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), fingerprint)
        }
    }

    @MainActor
    func testVisibleBuildingPixelsDoNotRetargetConstructionOrBulldozeTools() throws {
        let target = GridCoordinate(x: 12, y: 12)
        let state = district(buildings: [target])
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        let sprite = try inspectionSprite(in: scene, at: target)
        let roof = try sourceOpaquePoint(on: sprite, in: scene) { ground($0, in: scene, state: state) != target }
        let groundTarget = try XCTUnwrap(ground(roof, in: scene, state: state))
        XCTAssertNotEqual(groundTarget, target)
        for mode in [CityInteractionMode.build(.road), .build(.commercial), .bulldoze] {
            scene.render(state: state, overlay: .none, selection: nil, interactionMode: mode)
            XCTAssertEqual(scene.resolvedCoordinateForTesting(at: roof), groundTarget)
        }
    }

    @MainActor
    func testTransparentCanvasAndHiddenBuildingStillResolveTheGround() throws {
        let target = GridCoordinate(x: 12, y: 12)
        let state = district(buildings: [target])
        let scene = CityScene(size: CGSize(width: 1280, height: 800))
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        let sprite = try inspectionSprite(in: scene, at: target)
        let transparent = sourcePoint(x: 1, y: 1, on: sprite, in: scene)
        XCTAssertFalse(sprite.containsOpaquePixel(at: sprite.convert(transparent, from: scene)))
        XCTAssertEqual(scene.resolvedCoordinateForTesting(at: transparent), ground(transparent, in: scene, state: state))
        let roof = try sourceOpaquePoint(on: sprite, in: scene) { ground($0, in: scene, state: state) != target }
        sprite.isHidden = true
        XCTAssertEqual(scene.resolvedCoordinateForTesting(at: roof), ground(roof, in: scene, state: state))
    }

    @MainActor
    func testOverlappingOpaqueBuildingsChooseTheFrontmostVisibleSource() throws {
        let back = GridCoordinate(x: 12, y: 12)
        let front = GridCoordinate(x: 13, y: 13)
        let state = district(buildings: [back, front])
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        let backSprite = try inspectionSprite(in: scene, at: back)
        let frontSprite = try inspectionSprite(in: scene, at: front)
        let overlap = try sourceOpaquePoint(on: frontSprite, in: scene) {
            backSprite.containsOpaquePixel(at: backSprite.convert($0, from: scene))
        }
        XCTAssertEqual(scene.resolvedCoordinateForTesting(at: overlap), front)
        frontSprite.isHidden = true
        XCTAssertEqual(scene.resolvedCoordinateForTesting(at: overlap), back)
    }

    private func district(buildings: [GridCoordinate]) -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for index in state.tiles.indices {
            state.tiles[index] = CityTile(coordinate: state.tiles[index].coordinate, kind: .empty)
        }
        for coordinate in buildings {
            state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: .powerPlant) }
        }
        return state
    }

    @MainActor
    private func inspectionSprite(in scene: CityScene, at coordinate: GridCoordinate) throws -> FourViewInspectionSprite {
        let root = try XCTUnwrap(scene.childNode(withName: "//tile:\(coordinate.x):\(coordinate.y)"))
        func find(in node: SKNode) -> FourViewInspectionSprite? {
            if let sprite = node as? FourViewInspectionSprite { return sprite }
            return node.children.lazy.compactMap { find(in: $0) }.first
        }
        return try XCTUnwrap(find(in: root))
    }

    @MainActor
    private func sourcePoint(x: Int, y: Int, on sprite: FourViewInspectionSprite, in scene: CityScene) -> CGPoint {
        let canvas = FourViewWorldAssetCatalog.sourceCanvasSize
        return sprite.convert(CGPoint(
            x: CGFloat(x) + 0.5 - sprite.anchorPoint.x * canvas.width,
            y: canvas.height - (CGFloat(y) + 0.5) - sprite.anchorPoint.y * canvas.height
        ), to: scene)
    }

    @MainActor
    private func sourceOpaquePoint(on sprite: FourViewInspectionSprite, in scene: CityScene, matching predicate: (CGPoint) -> Bool) throws -> CGPoint {
        let identity = try XCTUnwrap(sprite.children.compactMap(\.name).first { $0.hasPrefix("lot.four-view.") })
        let components = identity.dropFirst("lot.four-view.".count).split(separator: ".")
        let camera = try XCTUnwrap(FourViewWorldAssetCatalog.Camera(rawValue: String(components.last!)))
        let assetID = components.dropLast().joined(separator: ".")
        let url = try XCTUnwrap(FourViewWorldAssetCatalog.shared.resourceURL(for: assetID, camera: camera))
        let image = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
        var result: CGPoint?
        for y in stride(from: 24, to: 280, by: 3) {
            for x in stride(from: 60, to: 324, by: 3) where (image.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.9 {
                let point = sourcePoint(x: x, y: y, on: sprite, in: scene)
                if predicate(point) { result = point; break }
            }
            if result != nil { break }
        }
        return try XCTUnwrap(result, "Authored source must provide an opaque roof/overlap regression pixel")
    }

    @MainActor
    private func ground(_ point: CGPoint, in scene: CityScene, state: CityGameState) -> GridCoordinate? {
        let style = WorldVisualStyle()
        return IsometricGridCoordinateResolver(tileWidth: style.tileWidth, tileHeight: style.tileHeight)
            .coordinate(at: point, gridWidth: state.gridWidth, gridHeight: state.gridHeight)
    }
}
