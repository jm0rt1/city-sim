import AppKit
import CryptoKit
import SpriteKit
import XCTest
@testable import CitySimNative

final class FourViewWorldAssetCatalogTests: XCTestCase {
    @MainActor
    func testManifestAndBundledPNGsPreserveCanonicalRegistration() throws {
        let catalog = FourViewWorldAssetCatalog()
        let manifest = try XCTUnwrap(catalog.manifest)

        XCTAssertEqual(manifest.schema, "citysim.native-four-view-assets.v1")
        XCTAssertEqual(manifest.camera, "camNE")
        XCTAssertEqual(manifest.cameraAzimuthDegrees, 45)
        XCTAssertEqual(manifest.cameraElevationDegrees, 30)
        XCTAssertEqual(manifest.projectedTilePixels, [88, 44])
        XCTAssertEqual(manifest.canvas.width, 384)
        XCTAssertEqual(manifest.canvas.height, 384)
        XCTAssertEqual(manifest.canvas.footprintPivotPixel, [192, 300])
        XCTAssertEqual(manifest.postRenderCompensation, "none")
        XCTAssertGreaterThanOrEqual(manifest.assets.count, 7)
        XCTAssertEqual(Set(manifest.assets.map(\.assetID)).count, manifest.assets.count)
        XCTAssertEqual(Set(manifest.assets.map(\.file)).count, manifest.assets.count)
        let admittedRoles = Set(manifest.assets.flatMap(\.roles))
        XCTAssertTrue(Set([
            "residential-low", "residential-high", "commercial",
            "industrial", "city-hall", "park", "power-plant", "water-tower",
            "fire-station", "police-station", "school",
        ]).isSubset(of: admittedRoles))

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
    func testDeterministicRoleMappingUsesOnlyAcceptedFourViewFamily() {
        let catalog = FourViewWorldAssetCatalog()
        let coordinate = GridCoordinate(x: 4, y: 7)

        XCTAssertEqual(catalog.assetID(
            for: CityTile(coordinate: coordinate, kind: .residential, level: 1),
            variant: 1
        ), "copper_finch_house")
        XCTAssertEqual(catalog.assetID(
            for: CityTile(coordinate: coordinate, kind: .residential, level: 1),
            variant: 2
        ), "marigold_court_house")
        XCTAssertEqual(catalog.assetID(
            for: CityTile(coordinate: coordinate, kind: .residential, level: 3),
            variant: 1
        ), "brickline_rowhouse_apartments")

        let expected: [(BuildingKind, String?)] = [
            (.commercial, "harbor_corner_storefront"),
            (.industrial, "ironleaf_service_workshop"),
            (.park, "pocket_grove_park"),
            (.cityHall, "hearthside_council_hall"),
            (.powerPlant, "brick_grid_substation"),
            (.waterTower, "municipal_water_tower"),
            (.fireStation, "emberline_fire_station"),
            (.policeStation, "bluecrest_police_station"),
            (.school, "maplewood_neighborhood_school"),
        ]
        for (kind, assetID) in expected {
            XCTAssertEqual(
                catalog.assetID(for: CityTile(coordinate: coordinate, kind: kind), variant: 0),
                assetID,
                kind.rawValue
            )
        }
    }

    @MainActor
    func testUtilityAndServiceLotsUseCanonicalTransformAndNoLegacyRoleDecoration() throws {
        let style = WorldVisualStyle()
        let catalog = FourViewWorldAssetCatalog()
        let renderer = LotRenderer(
            style: style,
            assets: WorldAssetCatalog(),
            fourViewAssets: catalog
        )
        let cases: [(BuildingKind, String, String)] = [
            (.powerPlant, "brick_grid_substation", "industrial_l01"),
            (.waterTower, "municipal_water_tower", "water_tower_l01"),
            (.fireStation, "emberline_fire_station", "civic_l01_v0_south"),
            (.policeStation, "bluecrest_police_station", "civic_l01_v0_south"),
            (.school, "maplewood_neighborhood_school", "civic_l01_v0_south"),
        ]

        for (index, entry) in cases.enumerated() {
            let (kind, assetID, logicalID) = entry
            let lot = renderer.makeLot(
                for: CityTile(
                    coordinate: GridCoordinate(x: 10 + index, y: 12),
                    kind: kind,
                    condition: 1,
                    constructionProgress: 1
                ),
                adjacentRoads: .south,
                detail: .block,
                reducedMotion: true
            )
            let marker = try XCTUnwrap(
                lot.childNode(withName: "//lot.four-view.\(assetID).camNE")
            )
            let sprite = try XCTUnwrap(marker.parent as? SKSpriteNode)
            XCTAssertEqual(sprite.anchorPoint, FourViewWorldAssetCatalog.spriteAnchor)
            XCTAssertEqual(sprite.xScale, style.tileWidth / 88, accuracy: 0.000_001)
            XCTAssertEqual(sprite.yScale, style.tileWidth / 88, accuracy: 0.000_001)
            XCTAssertEqual(sprite.zRotation, 0, accuracy: 0.000_001)
            XCTAssertEqual(sprite.position, .zero)
            XCTAssertEqual(sprite.colorBlendFactor, 0, accuracy: 0.000_001)
            XCTAssertEqual(sprite.name, "lot.generated-v4.\(logicalID).block")
            XCTAssertNil(lot.childNode(withName: "//lot.generated-role.\(kind.rawValue)"))
        }
    }

    @MainActor
    func testLiveLotUsesOneUniformWorldScaleAndFixedPivotWithoutTransformHacks() throws {
        let style = WorldVisualStyle()
        let catalog = FourViewWorldAssetCatalog()
        let renderer = LotRenderer(
            style: style,
            assets: WorldAssetCatalog(),
            fourViewAssets: catalog
        )
        let tile = CityTile(
            coordinate: GridCoordinate(x: 6, y: 8),
            kind: .commercial,
            level: 2,
            condition: 1,
            constructionProgress: 1
        )
        let lot = renderer.makeLot(
            for: tile,
            adjacentRoads: .south,
            detail: .block,
            reducedMotion: true
        )

        let marker = try XCTUnwrap(
            lot.childNode(withName: "//lot.four-view.harbor_corner_storefront.camNE")
        )
        let sprite = try XCTUnwrap(marker.parent as? SKSpriteNode)
        let canonicalWorldScale = 72.0 / 88.0
        XCTAssertEqual(sprite.anchorPoint.x, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(sprite.anchorPoint.y, 84.0 / 384.0, accuracy: 0.000_001)
        XCTAssertEqual(sprite.size.width, 384 * canonicalWorldScale, accuracy: 0.000_01)
        XCTAssertEqual(sprite.size.height, 384 * canonicalWorldScale, accuracy: 0.000_01)
        XCTAssertEqual(sprite.xScale, canonicalWorldScale, accuracy: 0.000_001)
        XCTAssertEqual(sprite.yScale, canonicalWorldScale, accuracy: 0.000_001)
        XCTAssertEqual(sprite.zRotation, 0, accuracy: 0.000_001)
        XCTAssertEqual(sprite.position, .zero)
        XCTAssertEqual(
            sprite.name,
            "lot.generated-v4.commercial_l02_v0_south.block"
        )
    }

    @MainActor
    func testLiveSceneLODChangesNeverReplaceFourViewTexture() throws {
        let state = CityGameState.newCity(seed: 42)
        let commercial = try XCTUnwrap(state.tiles.first { $0.kind == .commercial })
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )

        let marker = try XCTUnwrap(
            scene.childNode(withName: "//lot.four-view.harbor_corner_storefront.camNE")
        )
        let sprite = try XCTUnwrap(marker.parent as? SKSpriteNode)
        let texture = try XCTUnwrap(sprite.texture)

        scene.configureProofCamera(detail: .city, centeredOn: commercial.coordinate)

        let updatedMarker = try XCTUnwrap(
            scene.childNode(withName: "//lot.four-view.harbor_corner_storefront.camNE")
        )
        let updatedSprite = try XCTUnwrap(updatedMarker.parent as? SKSpriteNode)
        XCTAssertTrue(updatedSprite.texture === texture)
        XCTAssertTrue(updatedSprite.name?.hasSuffix(".city") == true)
        XCTAssertEqual(updatedSprite.anchorPoint, FourViewWorldAssetCatalog.spriteAnchor)
        XCTAssertEqual(updatedSprite.zRotation, 0, accuracy: 0.000_001)
    }

    @MainActor
    func testTransparentFourViewCanvasCannotStealGroundGridSelection() {
        let state = CityGameState.newCity(seed: 42)
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )

        for tile in state.tiles where ![.empty, .road].contains(tile.kind) {
            let point = scene.scenePointForTesting(at: tile.coordinate)
            XCTAssertEqual(
                scene.resolvedCoordinateForTesting(at: point),
                tile.coordinate,
                tile.coordinate.id
            )
        }
    }
}
