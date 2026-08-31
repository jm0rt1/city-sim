import AppKit
import CryptoKit
import SpriteKit
import XCTest
@testable import CitySimNative

final class FourViewRoadAssetCatalogTests: XCTestCase {
    @MainActor
    func testManifestAndBundledRoadPNGsPreserveCanonicalRegistration() throws {
        let catalog = FourViewRoadAssetCatalog()
        let manifest = try XCTUnwrap(catalog.manifest)

        XCTAssertEqual(manifest.schema, "citysim.native-four-view-roads.v1")
        XCTAssertEqual(manifest.camera, "camNE")
        XCTAssertEqual(manifest.cameraAzimuthDegrees, 45)
        XCTAssertEqual(manifest.cameraElevationDegrees, 30)
        XCTAssertEqual(manifest.projectedTilePixels, [88, 44])
        XCTAssertEqual(manifest.directionRegistration, "CityScene.GridCoordinate.camNE.v1")
        XCTAssertEqual(
            manifest.projectedBoundaryPixels,
            [
                "north": [214, 289],
                "east": [214, 311],
                "south": [170, 311],
                "west": [170, 289],
            ]
        )
        XCTAssertEqual(manifest.canvas.width, 384)
        XCTAssertEqual(manifest.canvas.height, 384)
        XCTAssertEqual(manifest.canvas.footprintPivotPixel, [192, 300])
        XCTAssertEqual(manifest.postRenderCompensation, "none")
        XCTAssertEqual(manifest.roads.map(\.connectionMask), Array(UInt8(0)..<16))
        XCTAssertEqual(Set(manifest.roads.map(\.assetID)).count, 16)
        XCTAssertEqual(Set(manifest.roads.map(\.file)).count, 16)

        for road in manifest.roads {
            let url = try XCTUnwrap(
                catalog.resourceURL(for: road.connectionMask),
                road.assetID
            )
            let data = try Data(contentsOf: url)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data), road.assetID)
            XCTAssertEqual(bitmap.pixelsWide, 384, road.assetID)
            XCTAssertEqual(bitmap.pixelsHigh, 384, road.assetID)
            XCTAssertEqual(
                SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                road.sha256,
                road.assetID
            )
        }
    }

    @MainActor
    func testProjectedRoadSocketsMatchLiveGridDirections() throws {
        let manifest = try XCTUnwrap(FourViewRoadAssetCatalog().manifest)
        let style = WorldVisualStyle()
        let pivot = CGPoint(
            x: FourViewRoadAssetCatalog.footprintPivotTopOrigin.x,
            y: FourViewRoadAssetCatalog.footprintPivotTopOrigin.y
        )
        let edges: [(String, RoadConnectionMask)] = [
            ("north", .north),
            ("east", .east),
            ("south", .south),
            ("west", .west),
        ]

        for (name, edge) in edges {
            let pixels = try XCTUnwrap(manifest.projectedBoundaryPixels[name])
            XCTAssertEqual(pixels.count, 2)
            let sourceOffset = CGPoint(
                x: CGFloat(pixels[0]) - pivot.x,
                y: pivot.y - CGFloat(pixels[1])
            )
            let liveScale = style.tileWidth / FourViewRoadAssetCatalog.sourceTileSize.width
            let liveOffset = style.roadSocket(for: edge)
            XCTAssertEqual(sourceOffset.x * liveScale, liveOffset.x, accuracy: 0.001, name)
            XCTAssertEqual(sourceOffset.y * liveScale, liveOffset.y, accuracy: 0.001, name)
        }
    }

    @MainActor
    func testEveryMaskUsesOneFixedTransformWithoutLegacyDecoration() throws {
        let style = WorldVisualStyle()
        let catalog = FourViewRoadAssetCatalog()
        let renderer = RoadRenderer(
            style: style,
            assets: WorldAssetCatalog(),
            fourViewRoadAssets: catalog
        )

        for mask in RoadConnectionMask.allMasks {
            let road = renderer.makeRoad(
                at: GridCoordinate(x: 4, y: 4),
                connections: mask,
                detail: .block,
                reducedMotion: true
            )
            let marker = try XCTUnwrap(
                road.childNode(withName: String(format: "//road.four-view.mask-%02d.camNE", mask.rawValue))
            )
            let sprite = try XCTUnwrap(marker.parent as? SKSpriteNode)
            XCTAssertEqual(sprite.anchorPoint, FourViewRoadAssetCatalog.spriteAnchor)
            XCTAssertEqual(sprite.xScale, style.tileWidth / 88, accuracy: 0.000_001)
            XCTAssertEqual(sprite.yScale, style.tileWidth / 88, accuracy: 0.000_001)
            XCTAssertEqual(sprite.zRotation, 0, accuracy: 0.000_001)
            XCTAssertEqual(sprite.position, .zero)
            XCTAssertEqual(sprite.colorBlendFactor, 0, accuracy: 0.000_001)
            XCTAssertEqual(sprite.name, "road.generated-v4.\(mask.rawValue).block")

            let names = descendantNames(in: road)
            XCTAssertFalse(names.contains { $0.hasPrefix("road.socket-seam-blend.") })
            XCTAssertFalse(names.contains { $0.hasPrefix("road.terminus.") })
            XCTAssertFalse(names.contains { $0.hasPrefix("road.fabric.") })
            XCTAssertFalse(names.contains { $0.hasPrefix("road.street-furniture.") })
        }
    }

    @MainActor
    func testEveryConnectedMaskCarriesVisibleLanePaint() throws {
        let catalog = FourViewRoadAssetCatalog()
        let manifest = try XCTUnwrap(catalog.manifest)

        for road in manifest.roads where road.connectionMask != 0 {
            let url = try XCTUnwrap(
                catalog.resourceURL(for: road.connectionMask),
                road.assetID
            )
            let data = try Data(contentsOf: url)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data), road.assetID)
            var lanePaintPixels = 0

            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                          color.alphaComponent > 0.1 else { continue }
                    if color.redComponent > color.greenComponent * 1.12,
                       color.greenComponent > color.blueComponent * 1.15,
                       color.redComponent > 0.25 {
                        lanePaintPixels += 1
                    }
                }
            }

            XCTAssertGreaterThan(
                lanePaintPixels,
                24,
                "\(road.assetID) must carry visible warm lane paint at game scale"
            )
        }
    }

    @MainActor
    func testLiveSceneLODChangesNeverReplaceFourViewRoadTexture() throws {
        let state = CityGameState.newCity(seed: 42)
        let roadTile = try XCTUnwrap(state.tiles.first { $0.kind == .road })
        let mask = RoadConnectionMask.resolving(at: roadTile.coordinate, in: state)
        let markerName = String(format: "//road.four-view.mask-%02d.camNE", mask.rawValue)
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )

        let marker = try XCTUnwrap(scene.childNode(withName: markerName))
        let sprite = try XCTUnwrap(marker.parent as? SKSpriteNode)
        let texture = try XCTUnwrap(sprite.texture)

        scene.configureProofCamera(detail: .city, centeredOn: roadTile.coordinate)

        let updatedMarker = try XCTUnwrap(scene.childNode(withName: markerName))
        let updatedSprite = try XCTUnwrap(updatedMarker.parent as? SKSpriteNode)
        XCTAssertTrue(updatedSprite.texture === texture)
        XCTAssertEqual(updatedSprite.name, "road.generated-v4.\(mask.rawValue).city")
        XCTAssertEqual(updatedSprite.anchorPoint, FourViewRoadAssetCatalog.spriteAnchor)
        XCTAssertEqual(updatedSprite.zRotation, 0, accuracy: 0.000_001)
    }

    @MainActor
    func testRoadCanvasCannotStealConstructionGridSelection() {
        let state = CityGameState.newCity(seed: 42)
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )

        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .build(.road))
        for tile in state.tiles where tile.kind == .road {
            XCTAssertEqual(
                scene.resolvedCoordinateForTesting(
                    at: scene.scenePointForTesting(at: tile.coordinate)
                ),
                tile.coordinate,
                tile.coordinate.id
            )
        }
    }

    @MainActor
    private func descendantNames(in node: SKNode) -> [String] {
        (node.name.map { [$0] } ?? []) + node.children.flatMap(descendantNames)
    }
}
