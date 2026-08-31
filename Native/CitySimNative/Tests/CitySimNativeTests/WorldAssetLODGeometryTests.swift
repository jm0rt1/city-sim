import SpriteKit
import XCTest
@testable import CitySimNative

final class WorldAssetLODGeometryTests: XCTestCase {
    @MainActor
    func testEveryAdmittedAssetKeepsOneWorldGeometryAcrossTextureDetails() throws {
        let manifest = try XCTUnwrap(WorldAssetCatalog().generatedManifest)
        for asset in manifest.assets {
            let reference = try XCTUnwrap(asset.lods[CameraDetailLevel.block.assetSuffix])
            for detail in CameraDetailLevel.allCases {
                let lod = try XCTUnwrap(asset.lods[detail.assetSuffix])
                XCTAssertEqual(lod.worldSize, reference.worldSize, asset.logicalID)
                XCTAssertEqual(lod.anchor, reference.anchor, asset.logicalID)
            }
        }
    }

    @MainActor
    func testIndustrialBuildingKeepsItsWorldGeometryAcrossTextureDetails() throws {
        let state = CityGameState.newCity(seed: 42)
        let tile = try XCTUnwrap(state.tiles.first { $0.kind == .industrial })
        let roads = RoadConnectionMask.resolving(at: tile.coordinate, in: state)
        let identity = try XCTUnwrap(IndustrialGeneratedAssetIdentity(level: tile.level, adjacentRoads: roads))
        let catalog = WorldAssetCatalog()
        let renderer = LotRenderer(style: WorldVisualStyle(), assets: catalog, fourViewAssets: .shared)
        let lot = renderer.makeLot(for: tile, adjacentRoads: roads, detail: .block, reducedMotion: true)
        let sprite = try XCTUnwrap(findSprite(in: lot, prefix: "lot.generated-v4.\(identity.logicalID)."))
        let initialSize = sprite.size
        let initialScale = CGPoint(x: sprite.xScale, y: sprite.yScale)
        let initialFrame = sprite.frame
        let initialPosition = sprite.position
        let initialAnchor = sprite.anchorPoint

        for detail in [CameraDetailLevel.city, .neighborhood, .block, .city] {
            XCTAssertTrue(catalog.applyGeneratedLOD(
                to: sprite,
                logicalID: identity.logicalID,
                detail: detail,
                semanticName: "lot.generated-v4.\(identity.logicalID).\(detail.assetSuffix)"
            ))
            XCTAssertEqual(sprite.size, initialSize, "\(detail): texture resolution must not resize a placed building")
            XCTAssertEqual(CGPoint(x: sprite.xScale, y: sprite.yScale), initialScale)
            XCTAssertEqual(sprite.frame, initialFrame)
            XCTAssertEqual(sprite.position, initialPosition)
            XCTAssertEqual(sprite.anchorPoint, initialAnchor)
        }
    }

    @MainActor
    func testComposedCityKeepsIndustrialGeometryAndInspectionBoundsAcrossZoom() throws {
        let state = CityGameState.newCity(seed: 42)
        let tile = try XCTUnwrap(state.tiles.first { $0.kind == .industrial })
        let roads = RoadConnectionMask.resolving(at: tile.coordinate, in: state)
        let identity = try XCTUnwrap(IndustrialGeneratedAssetIdentity(level: tile.level, adjacentRoads: roads))
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            let scene = CityScene(size: size)
            scene.reducedMotion = true
            scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
            let sprite = try XCTUnwrap(findSprite(in: scene, prefix: "lot.generated-v4.\(identity.logicalID)."))
            let frame = sprite.frame
            let bounds = scene.inspectedPlaceBoundsForTesting(at: tile.coordinate)
            let root = scene.tileRootIdentifier(at: tile.coordinate)
            for detail in [CameraDetailLevel.block, .neighborhood, .city, .block] {
                scene.configureProofCamera(detail: detail, centeredOn: tile.coordinate)
                XCTAssertEqual(scene.currentCameraDetailLevel, detail)
                XCTAssertEqual(sprite.frame, frame, "\(size) \(detail)")
                XCTAssertEqual(scene.inspectedPlaceBoundsForTesting(at: tile.coordinate), bounds)
                XCTAssertEqual(scene.tileRootIdentifier(at: tile.coordinate), root)
                XCTAssertEqual(sprite.name, "lot.generated-v4.\(identity.logicalID).\(detail.assetSuffix)")
            }
        }
    }

    @MainActor
    private func findSprite(in node: SKNode, prefix: String) -> SKSpriteNode? {
        if let sprite = node as? SKSpriteNode, sprite.name?.hasPrefix(prefix) == true {
            return sprite
        }
        return node.children.lazy.compactMap { self.findSprite(in: $0, prefix: prefix) }.first
    }
}
