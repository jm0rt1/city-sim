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

        XCTAssertEqual(manifest.schema, "citysim.native-four-view-assets.v2")
        XCTAssertEqual(manifest.camera, "camNE")
        XCTAssertEqual(manifest.cameraAzimuthDegrees, 45)
        XCTAssertEqual(manifest.cameraElevationDegrees, 30)
        XCTAssertEqual(manifest.projectedTilePixels, [88, 44])
        XCTAssertEqual(manifest.canvas.width, 384)
        XCTAssertEqual(manifest.canvas.height, 384)
        XCTAssertEqual(manifest.canvas.footprintPivotPixel, [192, 300])
        XCTAssertEqual(manifest.postRenderCompensation, "none")
        XCTAssertEqual(manifest.assets.count, 77)
        XCTAssertEqual(Set(manifest.assets.map(\.assetID)).count, manifest.assets.count)
        XCTAssertEqual(Set(manifest.assets.map(\.file)).count, manifest.assets.count)
        XCTAssertEqual(
            Dictionary(grouping: manifest.assets, by: \.family).mapValues(\.count),
            [
                "residential": 24,
                "commercial": 17,
                "industrial": 14,
                "civic-service": 12,
                "utility": 6,
                "park-landmark": 4,
            ]
        )
        XCTAssertEqual(manifest.assets.filter { $0.views.count == 4 }.count, 44)
        let admittedRoles = Set(manifest.assets.flatMap(\.roles))
        XCTAssertTrue(Set([
            "residential-low", "residential-quality", "residential-medium", "residential-high",
            "commercial-low", "commercial-medium", "commercial-high",
            "industrial-low", "industrial-medium", "industrial-high",
            "city-hall", "park", "power-plant", "water-tower",
            "fire-station", "police-station", "school",
        ]).isSubset(of: admittedRoles))

        for asset in manifest.assets {
            for view in asset.views {
                let identity = "\(asset.assetID).\(view.camera)"
                let camera = try XCTUnwrap(
                    FourViewWorldAssetCatalog.Camera(rawValue: view.camera),
                    identity
                )
                let url = try XCTUnwrap(
                    catalog.resourceURL(for: asset.assetID, camera: camera),
                    identity
                )
                let data = try Data(contentsOf: url)
                let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data), identity)
                XCTAssertEqual(bitmap.pixelsWide, 384, identity)
                XCTAssertEqual(bitmap.pixelsHigh, 384, identity)
                XCTAssertEqual(
                    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                    view.sha256,
                    identity
                )
            }
        }
    }

    @MainActor
    func testDeterministicLiveRoleMappingReachesEverySelectedAsset() throws {
        let catalog = FourViewWorldAssetCatalog()
        let roleCases: [(role: String, kind: BuildingKind, level: Int)] = [
            ("residential-quality", .residential, 1),
            ("residential-medium", .residential, 2),
            ("residential-high", .residential, 3),
            ("commercial-medium", .commercial, 2),
            ("commercial-high", .commercial, 3),
            ("industrial-medium", .industrial, 2),
            ("industrial-high", .industrial, 3),
            ("park", .park, 1),
            ("power-plant", .powerPlant, 1),
            ("water-tower", .waterTower, 1),
            ("fire-station", .fireStation, 1),
            ("police-station", .policeStation, 1),
            ("school", .school, 1),
        ]

        for roleCase in roleCases {
            let expected = Set(catalog.assetIDs(forRole: roleCase.role))
            var reached: Set<String> = []
            for y in 0..<96 {
                for x in 0..<96 {
                    let coordinate = GridCoordinate(x: x, y: y)
                    let tile = CityTile(
                        coordinate: coordinate,
                        kind: roleCase.kind,
                        level: roleCase.level
                    )
                    let variant = roleCase.kind == .residential
                        ? ResidentialGeneratedAssetIdentity.liveVisualVariant(at: coordinate)
                        : WorldVisualSeed.variant(
                            count: 3,
                            for: coordinate,
                            kind: roleCase.kind
                        )
                    reached.insert(try XCTUnwrap(catalog.assetID(for: tile, variant: variant)))
                }
            }
            XCTAssertEqual(reached, expected, roleCase.role)
        }
    }

    @MainActor
    func testResidentialQualityFamilySelectsAllFourAndLoadsEveryAuthoredOrientation() throws {
        let style = WorldVisualStyle()
        let catalog = FourViewWorldAssetCatalog()
        let renderer = LotRenderer(
            style: style,
            assets: WorldAssetCatalog(),
            fourViewAssets: catalog
        )
        let family = [
            "alder_gable_cottage",
            "birch_lane_bungalow",
            "rosewood_turret_house",
            "stonebridge_duplex",
        ]
        let descriptors = try XCTUnwrap(catalog.manifest).assets.filter {
            $0.roles.contains("residential-quality")
        }
        XCTAssertEqual(descriptors.map(\.assetID), family)

        var coordinateByAssetID: [String: GridCoordinate] = [:]
        for y in 0..<32 {
            for x in 0..<32 {
                let coordinate = GridCoordinate(x: x, y: y)
                let tile = CityTile(coordinate: coordinate, kind: .residential, level: 1)
                let visualVariant = ResidentialGeneratedAssetIdentity.liveVisualVariant(
                    at: coordinate
                )
                let assetID = try XCTUnwrap(
                    catalog.assetID(for: tile, variant: visualVariant)
                )
                XCTAssertTrue(
                    family.contains(assetID),
                    "Live level-one residential selected non-quality asset \(assetID)"
                )
                coordinateByAssetID[assetID] = coordinate
            }
        }
        XCTAssertEqual(Set(coordinateByAssetID.keys), Set(family))
        let frontageCameras: [(RoadConnectionMask, FourViewWorldAssetCatalog.Camera)] = [
            (.south, .camNE),
            (.west, .camSE),
            (.north, .camSW),
            (.east, .camNW),
        ]

        for descriptor in descriptors {
            let coordinate = try XCTUnwrap(coordinateByAssetID[descriptor.assetID])
            let tile = CityTile(coordinate: coordinate, kind: .residential, level: 1)
            let visualVariant = ResidentialGeneratedAssetIdentity.liveVisualVariant(
                at: coordinate
            )
            let views = descriptor.views
            XCTAssertEqual(views.count, 4)
            for camera in FourViewWorldAssetCatalog.Camera.allCases {
                let view = try XCTUnwrap(views.first { $0.camera == camera.rawValue })
                let url = try XCTUnwrap(
                    catalog.resourceURL(for: descriptor.assetID, camera: camera)
                )
                let data = try Data(contentsOf: url)
                XCTAssertEqual(
                    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                    view.sha256
                )
                let sprite = try XCTUnwrap(catalog.makeSprite(
                    for: tile,
                    variant: visualVariant,
                    worldTileWidth: style.tileWidth,
                    camera: camera
                ))
                XCTAssertNotNil(
                    sprite.childNode(withName: "lot.four-view.\(descriptor.assetID).\(camera.rawValue)")
                )
                XCTAssertEqual(sprite.anchorPoint, FourViewWorldAssetCatalog.spriteAnchor)
                XCTAssertEqual(sprite.xScale, style.tileWidth / 176, accuracy: 0.000_001)
                XCTAssertEqual(sprite.yScale, style.tileWidth / 176, accuracy: 0.000_001)
                XCTAssertEqual(sprite.zRotation, 0, accuracy: 0.000_001)
                XCTAssertEqual(sprite.position, .zero)
            }
            for (frontage, camera) in frontageCameras {
                let lot = renderer.makeLot(
                    for: tile,
                    adjacentRoads: frontage,
                    detail: .block,
                    reducedMotion: true
                )
                XCTAssertNotNil(
                    lot.childNode(
                        withName: "//lot.four-view.\(descriptor.assetID).\(camera.rawValue)"
                    ),
                    "\(descriptor.assetID).\(camera.rawValue)"
                )
            }
        }
    }

    @MainActor
    func testLowCommercialUsesAdmittedGeneratedDirectionalFamily() throws {
        let catalog = FourViewWorldAssetCatalog()
        let renderer = LotRenderer(
            style: WorldVisualStyle(),
            assets: WorldAssetCatalog(),
            fourViewAssets: catalog
        )
        let frontages: [RoadConnectionMask] = [.north, .east, .south, .west]
        for (index, frontage) in frontages.enumerated() {
            let identity = try XCTUnwrap(
                CommercialGeneratedAssetIdentity(level: 1, adjacentRoads: frontage)
            )
            let tile = CityTile(
                coordinate: GridCoordinate(x: index + 3, y: index + 5),
                kind: .commercial,
                level: 1,
                condition: 1,
                constructionProgress: 1
            )
            XCTAssertNil(catalog.assetID(for: tile, variant: index))
            let lot = renderer.makeLot(
                for: tile,
                adjacentRoads: frontage,
                detail: .block,
                reducedMotion: true
            )
            let sprite = try XCTUnwrap(
                lot.childNode(withName: "//lot.generated-v4.\(identity.logicalID).block")
                    as? SKSpriteNode
            )
            XCTAssertEqual(sprite.name, "lot.generated-v4.\(identity.logicalID).block")
            XCTAssertNil(lot.childNode(withName: "//lot.four-view.*"))
            XCTAssertNil(lot.childNode(withName: "//lot.four-view.missing.*"))
        }
    }

    @MainActor
    func testLowIndustrialUsesAdmittedGeneratedDirectionalFamily() throws {
        let catalog = FourViewWorldAssetCatalog()
        let renderer = LotRenderer(
            style: WorldVisualStyle(),
            assets: WorldAssetCatalog(),
            fourViewAssets: catalog
        )
        let frontages: [RoadConnectionMask] = [.north, .east, .south, .west]
        for (index, frontage) in frontages.enumerated() {
            let identity = try XCTUnwrap(
                IndustrialGeneratedAssetIdentity(level: 1, adjacentRoads: frontage)
            )
            let tile = CityTile(
                coordinate: GridCoordinate(x: index + 7, y: index + 9),
                kind: .industrial,
                level: 1,
                condition: 1,
                constructionProgress: 1
            )
            XCTAssertNil(catalog.assetID(for: tile, variant: index))
            let lot = renderer.makeLot(
                for: tile,
                adjacentRoads: frontage,
                detail: .block,
                reducedMotion: true
            )
            let sprite = try XCTUnwrap(
                lot.childNode(withName: "//lot.generated-v4.\(identity.logicalID).block")
                    as? SKSpriteNode
            )
            XCTAssertEqual(sprite.name, "lot.generated-v4.\(identity.logicalID).block")
            XCTAssertNil(lot.childNode(withName: "//lot.four-view.*"))
            XCTAssertNil(lot.childNode(withName: "//lot.four-view.missing.*"))
        }
    }

    @MainActor
    func testCityHallUsesAdmittedGeneratedDirectionalFamily() throws {
        let catalog = FourViewWorldAssetCatalog()
        let renderer = LotRenderer(
            style: WorldVisualStyle(),
            assets: WorldAssetCatalog(),
            fourViewAssets: catalog
        )
        let frontages: [RoadConnectionMask] = [.north, .east, .south, .west]
        for (index, frontage) in frontages.enumerated() {
            let identity = try XCTUnwrap(
                CivicGeneratedAssetIdentity(adjacentRoads: frontage)
            )
            let tile = CityTile(
                coordinate: GridCoordinate(x: index + 11, y: index + 13),
                kind: .cityHall,
                level: 1,
                condition: 1,
                constructionProgress: 1
            )
            XCTAssertNil(catalog.assetID(for: tile, variant: index))
            let lot = renderer.makeLot(
                for: tile,
                adjacentRoads: frontage,
                detail: .block,
                reducedMotion: true
            )
            let sprite = try XCTUnwrap(
                lot.childNode(withName: "//lot.generated-v4.\(identity.logicalID).block")
                    as? SKSpriteNode
            )
            XCTAssertEqual(sprite.name, "lot.generated-v4.\(identity.logicalID).block")
            XCTAssertNil(lot.childNode(withName: "//lot.four-view.*"))
            XCTAssertNil(lot.childNode(withName: "//lot.four-view.missing.*"))
        }
    }

    @MainActor
    func testParkVariantsUseFixedTransformWithoutChangingGameplayIdentity() throws {
        let style = WorldVisualStyle()
        let catalog = FourViewWorldAssetCatalog()
        let renderer = LotRenderer(
            style: style,
            assets: WorldAssetCatalog(),
            fourViewAssets: catalog
        )
        for variant in 0..<2 {
            let coordinate = try XCTUnwrap((0..<32).lazy
                .flatMap { y in (0..<32).map { GridCoordinate(x: $0, y: y) } }
                .first {
                    WorldVisualSeed.variant(
                        count: 3,
                        for: $0,
                        kind: .park
                    ) == variant
                })
            let tile = CityTile(
                coordinate: coordinate,
                kind: .park,
                level: 1,
                condition: 1,
                constructionProgress: 1
            )
            let assetID = try XCTUnwrap(catalog.assetID(for: tile, variant: variant))
            let lot = renderer.makeLot(
                for: tile,
                adjacentRoads: .south,
                detail: .block,
                reducedMotion: true
            )
            let marker = try XCTUnwrap(
                lot.childNode(withName: "//lot.four-view.\(assetID).camNE")
            )
            let sprite = try XCTUnwrap(marker.parent as? SKSpriteNode)
            XCTAssertEqual(sprite.anchorPoint, FourViewWorldAssetCatalog.spriteAnchor)
            XCTAssertEqual(sprite.xScale, style.tileWidth / 176, accuracy: 0.000_001)
            XCTAssertEqual(sprite.yScale, style.tileWidth / 176, accuracy: 0.000_001)
            XCTAssertEqual(sprite.zRotation, 0, accuracy: 0.000_001)
            XCTAssertEqual(sprite.position, .zero)
            XCTAssertEqual(sprite.colorBlendFactor, 0, accuracy: 0.000_001)
            XCTAssertEqual(sprite.name, "lot.generated-v4.park_l01.block")
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
        let cases: [(BuildingKind, String)] = [
            (.powerPlant, "industrial_l01"),
            (.waterTower, "water_tower_l01"),
            (.fireStation, "civic_l01_v0_south"),
            (.policeStation, "civic_l01_v0_south"),
            (.school, "civic_l01_v0_south"),
        ]

        for entry in cases {
            let (kind, logicalID) = entry
            let coordinate = try XCTUnwrap((0..<32).lazy
                .flatMap { y in (0..<32).map { GridCoordinate(x: $0, y: y) } }
                .first {
                    WorldVisualSeed.variant(
                        count: 3,
                        for: $0,
                        kind: kind
                    ) == 0
                })
            let tile = CityTile(
                coordinate: coordinate,
                kind: kind,
                condition: 1,
                constructionProgress: 1
            )
            let assetID = try XCTUnwrap(catalog.assetID(for: tile, variant: 0))
            let lot = renderer.makeLot(
                for: tile,
                adjacentRoads: .south,
                detail: .block,
                reducedMotion: true
            )
            let marker = try XCTUnwrap(
                lot.childNode(withName: "//lot.four-view.\(assetID).camNE")
            )
            let sprite = try XCTUnwrap(marker.parent as? SKSpriteNode)
            XCTAssertEqual(sprite.anchorPoint, FourViewWorldAssetCatalog.spriteAnchor)
            XCTAssertEqual(sprite.xScale, style.tileWidth / 176, accuracy: 0.000_001)
            XCTAssertEqual(sprite.yScale, style.tileWidth / 176, accuracy: 0.000_001)
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

        let visualVariant = WorldVisualSeed.variant(
            count: 3,
            for: tile.coordinate,
            kind: tile.kind
        )
        let assetID = try XCTUnwrap(catalog.assetID(for: tile, variant: visualVariant))
        let marker = try XCTUnwrap(
            lot.childNode(withName: "//lot.four-view.\(assetID).camNE")
        )
        let sprite = try XCTUnwrap(marker.parent as? SKSpriteNode)
        let canonicalWorldScale = 72.0 / 176.0
        XCTAssertEqual(sprite.anchorPoint.x, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(sprite.anchorPoint.y, 84.0 / 384.0, accuracy: 0.000_001)
        XCTAssertEqual(sprite.size.width, 384 * canonicalWorldScale, accuracy: 0.000_01)
        XCTAssertEqual(sprite.size.height, 384 * canonicalWorldScale, accuracy: 0.000_01)
        XCTAssertEqual(sprite.xScale, canonicalWorldScale, accuracy: 0.000_001)
        XCTAssertEqual(sprite.yScale, canonicalWorldScale, accuracy: 0.000_001)
        XCTAssertEqual(sprite.zRotation, 0, accuracy: 0.000_001)
        XCTAssertEqual(sprite.position, .zero)
        XCTAssertEqual(
            FourViewWorldAssetCatalog.sourceFootprintSize.width * sprite.xScale,
            style.tileWidth,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            FourViewWorldAssetCatalog.sourceFootprintSize.height * sprite.yScale,
            style.tileHeight,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            sprite.name,
            "lot.generated-v4.commercial_l02_v0_south.block"
        )
    }

    @MainActor
    func testLiveSceneLODChangesNeverReplaceFourViewTexture() throws {
        var state = CityGameState.newCity(seed: 42)
        let commercialCoordinate = try XCTUnwrap(
            state.tiles.first { $0.kind == .commercial }?.coordinate
        )
        state.updateTile(at: commercialCoordinate) {
            $0 = CityTile(
                coordinate: commercialCoordinate,
                kind: .commercial,
                level: 2,
                condition: 1,
                constructionProgress: 1
            )
        }
        let commercial = try XCTUnwrap(state.tile(at: commercialCoordinate))
        let visualVariant = WorldVisualSeed.variant(
            count: 3,
            for: commercial.coordinate,
            kind: .commercial
        )
        let assetID = try XCTUnwrap(
            FourViewWorldAssetCatalog().assetID(
                for: commercial,
                variant: visualVariant
            )
        )
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )

        let marker = try XCTUnwrap(
            scene.childNode(withName: "//lot.four-view.\(assetID).camNE")
        )
        let sprite = try XCTUnwrap(marker.parent as? SKSpriteNode)
        let texture = try XCTUnwrap(sprite.texture)

        scene.configureProofCamera(detail: .city, centeredOn: commercial.coordinate)

        let updatedMarker = try XCTUnwrap(
            scene.childNode(withName: "//lot.four-view.\(assetID).camNE")
        )
        let updatedSprite = try XCTUnwrap(updatedMarker.parent as? SKSpriteNode)
        XCTAssertTrue(updatedSprite.texture === texture)
        XCTAssertTrue(updatedSprite.name?.hasSuffix(".city") == true)
        XCTAssertEqual(updatedSprite.anchorPoint, FourViewWorldAssetCatalog.spriteAnchor)
        XCTAssertEqual(updatedSprite.zRotation, 0, accuracy: 0.000_001)
    }

    @MainActor
    func testExpansionWaveSavedCityDisplaysEveryNewAsset() throws {
        let catalog = FourViewWorldAssetCatalog()
        let manifest = try XCTUnwrap(catalog.manifest)
        let expansionAssets = manifest.assets.filter {
            $0.views.count == 4 && !$0.roles.contains("residential-quality")
                && !($0.family == "residential" && $0.roles.contains("residential-low"))
                && !($0.family == "commercial" && $0.roles.contains("commercial-low"))
                && !($0.family == "industrial" && $0.roles.contains("industrial-low"))
                && !$0.roles.contains("city-hall")
        }
        XCTAssertEqual(expansionAssets.count, 26)
        XCTAssertEqual(
            Dictionary(grouping: expansionAssets, by: \.family).mapValues(\.count),
            [
                "residential": 9,
                "commercial": 6,
                "industrial": 5,
                "civic-service": 3,
                "utility": 2,
                "park-landmark": 1,
            ]
        )

        var state = CityGameState.newCity(seed: 4_040)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        for axis in [4, 9, 14, 19, 24, 29] {
            for offset in 2...29 {
                state.updateTile(at: GridCoordinate(x: axis, y: offset)) {
                    $0 = CityTile(coordinate: $0.coordinate, kind: .road)
                }
                state.updateTile(at: GridCoordinate(x: offset, y: axis)) {
                    $0 = CityTile(coordinate: $0.coordinate, kind: .road)
                }
            }
        }

        func placement(for asset: FourViewWorldAssetManifest.Asset) throws -> (BuildingKind, Int) {
            let roles = Set(asset.roles)
            if roles.contains("residential-low") { return (.residential, 1) }
            if roles.contains("residential-medium") { return (.residential, 2) }
            if roles.contains("residential-high") { return (.residential, 3) }
            if roles.contains("commercial-low") { return (.commercial, 1) }
            if roles.contains("commercial-medium") { return (.commercial, 2) }
            if roles.contains("commercial-high") { return (.commercial, 3) }
            if roles.contains("industrial-low") { return (.industrial, 1) }
            if roles.contains("industrial-medium") { return (.industrial, 2) }
            if roles.contains("industrial-high") { return (.industrial, 3) }
            if roles.contains("city-hall") { return (.cityHall, 1) }
            if roles.contains("park") { return (.park, 1) }
            if roles.contains("power-plant") { return (.powerPlant, 1) }
            if roles.contains("water-tower") { return (.waterTower, 1) }
            if roles.contains("fire-station") { return (.fireStation, 1) }
            if roles.contains("police-station") { return (.policeStation, 1) }
            if roles.contains("school") { return (.school, 1) }
            throw XCTSkip("No playable role for \(asset.assetID)")
        }

        var used: Set<GridCoordinate> = []
        var placedIDs: Set<String> = []
        let preferredX = [6, 11, 16, 21, 26]
        let preferredY = [6, 8, 11, 13, 16, 18, 21, 23]
        for (index, asset) in expansionAssets.enumerated() {
            let (kind, level) = try placement(for: asset)
            let preferred = GridCoordinate(
                x: preferredX[index % preferredX.count],
                y: preferredY[index / preferredX.count]
            )
            let coordinate = try XCTUnwrap(
                state.tiles
                    .filter { tile in
                        guard tile.kind == .empty,
                              !used.contains(tile.coordinate),
                              !RoadConnectionMask.resolving(
                                  at: tile.coordinate,
                                  in: state
                              ).isEmpty else { return false }
                        let candidate = CityTile(
                            coordinate: tile.coordinate,
                            kind: kind,
                            level: level
                        )
                        let variant = kind == .residential
                            ? ResidentialGeneratedAssetIdentity.liveVisualVariant(
                                at: tile.coordinate
                            )
                            : WorldVisualSeed.variant(
                                count: 3,
                                for: tile.coordinate,
                                kind: kind
                            )
                        return catalog.assetID(for: candidate, variant: variant) == asset.assetID
                    }
                    .min { lhs, rhs in
                        let left = abs(lhs.coordinate.x - preferred.x)
                            + abs(lhs.coordinate.y - preferred.y)
                        let right = abs(rhs.coordinate.x - preferred.x)
                            + abs(rhs.coordinate.y - preferred.y)
                        return (left, lhs.coordinate.y, lhs.coordinate.x)
                            < (right, rhs.coordinate.y, rhs.coordinate.x)
                    }?.coordinate,
                asset.assetID
            )
            used.insert(coordinate)
            placedIDs.insert(asset.assetID)
            state.updateTile(at: coordinate) {
                $0 = CityTile(
                    coordinate: coordinate,
                    kind: kind,
                    level: level,
                    condition: 1,
                    constructionProgress: 1
                )
            }
        }
        XCTAssertEqual(placedIDs, Set(expansionAssets.map(\.assetID)))

        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        func names(in node: SKNode) -> [String] {
            (node.name.map { [$0] } ?? []) + node.children.flatMap(names)
        }
        let sourceNames = Set(names(in: scene))
        for asset in expansionAssets {
            XCTAssertTrue(
                asset.views.contains { view in
                    sourceNames.contains("lot.four-view.\(asset.assetID).\(view.camera)")
                },
                asset.assetID
            )
        }

        if let rootPath = ProcessInfo.processInfo.environment["CITYSIM_EXPANSION_SAVE_ROOT"] {
            let service = SaveGameService(
                rootURL: URL(fileURLWithPath: rootPath, isDirectory: true)
            )
            _ = try service.save(state)
            XCTAssertEqual(try service.load().state, state)
        }
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
