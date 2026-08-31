import AppKit
import CryptoKit
import SpriteKit
import XCTest
@testable import CitySimNative

final class FourViewGroundEcologyCatalogTests: XCTestCase {
    @MainActor
    func testManifestAndBundledPNGsPreserveCanonicalRegistration() throws {
        let catalog = FourViewGroundEcologyCatalog()
        let manifest = try XCTUnwrap(catalog.manifest)

        XCTAssertEqual(manifest.schema, "citysim.native-four-view-ground-ecology.v1")
        XCTAssertEqual(manifest.camera, "camNE")
        XCTAssertEqual(manifest.cameraAzimuthDegrees, 45)
        XCTAssertEqual(manifest.cameraElevationDegrees, 30)
        XCTAssertEqual(manifest.projectedTilePixels, [88, 44])
        XCTAssertEqual(manifest.canvas.width, 384)
        XCTAssertEqual(manifest.canvas.height, 384)
        XCTAssertEqual(manifest.canvas.footprintPivotPixel, [192, 300])
        XCTAssertEqual(manifest.postRenderCompensation, "none")
        XCTAssertEqual(Set(manifest.assets.map(\.assetID)), FourViewGroundEcologyCatalog.requiredAssetIDs)
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: manifest.assets.map { ($0.assetID, $0.role) }),
            FourViewGroundEcologyCatalog.requiredRolesByAssetID
        )

        for asset in manifest.assets {
            let url = try XCTUnwrap(catalog.resourceURL(for: asset.assetID), asset.assetID)
            let data = try Data(contentsOf: url)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data), asset.assetID)
            XCTAssertEqual(bitmap.pixelsWide, 384, asset.assetID)
            XCTAssertEqual(bitmap.pixelsHigh, 384, asset.assetID)
            XCTAssertEqual(
                SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                asset.sha256,
                asset.assetID
            )
        }
    }

    @MainActor
    func testEveryAssetUsesOneFixedTransformAndGroundRole() throws {
        let style = WorldVisualStyle()
        let catalog = FourViewGroundEcologyCatalog()

        for assetID in FourViewGroundEcologyCatalog.requiredAssetIDs {
            let sprite = try XCTUnwrap(
                catalog.makeSprite(assetID: assetID, worldTileWidth: style.tileWidth),
                assetID
            )
            XCTAssertEqual(sprite.anchorPoint, FourViewGroundEcologyCatalog.spriteAnchor)
            XCTAssertEqual(sprite.xScale, style.tileWidth / 88, accuracy: 0.000_001)
            XCTAssertEqual(sprite.yScale, style.tileWidth / 88, accuracy: 0.000_001)
            XCTAssertEqual(sprite.zRotation, 0, accuracy: 0.000_001)
            XCTAssertEqual(sprite.position, .zero)
            XCTAssertEqual(sprite.colorBlendFactor, 0, accuracy: 0.000_001)
            XCTAssertNotNil(
                sprite.childNode(withName: "ground-ecology.four-view.\(assetID).camNE")
            )
        }

        let kinds: [(BuildingKind, String?)] = [
            (.residential, "worn_neighborhood_ground"),
            (.commercial, "worn_neighborhood_ground"),
            (.cityHall, "worn_neighborhood_ground"),
            (.industrial, "utility_service_ground"),
            (.powerPlant, "utility_service_ground"),
            (.waterTower, "utility_service_ground"),
            (.park, "park_grove_ground"),
            (.empty, "civic_meadow_ground"),
            (.road, nil),
        ]
        for (kind, expectedAssetID) in kinds {
            let tile = CityTile(coordinate: GridCoordinate(x: 2, y: 2), kind: kind)
            XCTAssertEqual(catalog.groundAssetID(for: tile), expectedAssetID)
        }
    }

    @MainActor
    func testCompletedLotUsesAuthoredGroundWithoutProceduralLotDecoration() throws {
        let style = WorldVisualStyle()
        let catalog = FourViewGroundEcologyCatalog()
        let renderer = TerrainRenderer(
            style: style,
            assets: WorldAssetCatalog(),
            groundEcologyAssets: catalog
        )
        let tile = CityTile(
            coordinate: GridCoordinate(x: 4, y: 4),
            kind: .park,
            constructionProgress: 1
        )
        let ground = renderer.makeGround(for: tile, detail: .block)
        let names = descendantNames(in: ground)

        XCTAssertTrue(names.contains("terrain.ground-ecology.park_grove_ground.block"))
        XCTAssertTrue(names.contains("ground-ecology.four-view.park_grove_ground.camNE"))
        XCTAssertFalse(names.contains { $0.hasPrefix("terrain.lot-surface.") })
        XCTAssertFalse(names.contains { $0.hasPrefix("terrain.stable-breakup.") })
        XCTAssertFalse(names.contains { $0.hasPrefix("terrain.close-detail.") })
    }

    @MainActor
    func testLiveSceneLODNeverReplacesGroundEcologyTexture() throws {
        let state = CityGameState.newCity(seed: 42)
        let tile = try XCTUnwrap(state.tiles.first {
            $0.kind == .residential && $0.constructionProgress >= 1
        })
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )

        let markerName = "//ground-ecology.four-view.worn_neighborhood_ground.camNE"
        let marker = try XCTUnwrap(scene.childNode(withName: markerName))
        let sprite = try XCTUnwrap(marker.parent as? SKSpriteNode)
        let texture = try XCTUnwrap(sprite.texture)

        scene.configureProofCamera(detail: .city, centeredOn: tile.coordinate)

        let updatedMarker = try XCTUnwrap(scene.childNode(withName: markerName))
        let updatedSprite = try XCTUnwrap(updatedMarker.parent as? SKSpriteNode)
        XCTAssertTrue(updatedSprite.texture === texture)
        XCTAssertEqual(
            updatedSprite.name,
            "terrain.ground-ecology.worn_neighborhood_ground.city"
        )
        XCTAssertEqual(updatedSprite.anchorPoint, FourViewGroundEcologyCatalog.spriteAnchor)
        XCTAssertEqual(updatedSprite.zRotation, 0, accuracy: 0.000_001)
    }

    @MainActor
    func testGroundAndVegetationCanvasesCannotStealConstructionGridSelection() {
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
        for tile in state.tiles {
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
