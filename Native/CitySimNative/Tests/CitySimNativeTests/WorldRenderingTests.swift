import AppKit
import SpriteKit
import XCTest
@testable import CitySimNative

final class WorldRenderingTests: XCTestCase {
    @MainActor
    func testGoldenNeighborhoodTerrainAtlasLoadsEveryAuthoredMaterial() {
        let catalog = WorldAssetCatalog()
        let names = (0..<6).map { "terrain_grass_\($0)" } + [
            "terrain_lawn",
            "terrain_park",
            "terrain_plaza",
            "terrain_yard"
        ]

        for name in names {
            let texture = catalog.texture(named: name)
            XCTAssertNotNil(texture, "Missing world atlas texture \(name)")
            XCTAssertEqual(texture?.filteringMode, .linear)
        }
    }

    @MainActor
    func testAuthoredRoadAtlasCoversEveryMaskAndFrontagesFaceConnectedRoads() {
        let catalog = WorldAssetCatalog()
        let style = WorldVisualStyle()
        let roads = RoadRenderer(style: style, assets: catalog)

        for mask in RoadConnectionMask.allMasks {
            let assetName = String(format: "road_mask_%02d", mask.rawValue)
            XCTAssertNotNil(catalog.texture(named: assetName))
            let root = roads.makeRoad(
                at: GridCoordinate(x: 4, y: 4),
                connections: mask,
                detail: .block,
                reducedMotion: true
            )
            XCTAssertTrue(descendantNames(in: root).contains("asset.\(assetName)"))
        }

        let lot = LotRenderer(style: style, assets: catalog).makeLot(
            for: CityTile(coordinate: GridCoordinate(x: 5, y: 5), kind: .residential),
            adjacentRoads: .north,
            detail: .block,
            reducedMotion: true
        )
        XCTAssertTrue(descendantNames(in: lot).contains("lot.frontage.residential.1"))
        for family in ["residential", "commercial", "industrial", "park", "civic"] {
            XCTAssertNotNil(catalog.texture(named: "frontage_\(family)"))
        }
    }

    @MainActor
    func testFiveAuthoredPlaceFamiliesLoadThreeStableSeededVariants() {
        let catalog = WorldAssetCatalog()
        let renderer = LotRenderer(style: WorldVisualStyle(), assets: catalog)
        let families: [(String, BuildingKind)] = [
            ("residential", .residential),
            ("commercial", .commercial),
            ("industrial", .industrial),
            ("park", .park),
            ("civic", .cityHall)
        ]

        for (family, kind) in families {
            for variant in 0..<3 {
                XCTAssertNotNil(catalog.texture(named: "place_\(family)_\(variant)"))
            }
            let coordinate = GridCoordinate(x: family.count, y: kind.rawValue.count)
            let expectedVariant = WorldVisualSeed.variant(count: 3, for: coordinate, kind: kind)
            let tile = CityTile(coordinate: coordinate, kind: kind, constructionProgress: 1)
            let first = renderer.makeLot(for: tile, adjacentRoads: .south, detail: .block, reducedMotion: true)
            let second = renderer.makeLot(for: tile, adjacentRoads: .south, detail: .block, reducedMotion: true)
            let expectedName = "lot.place.\(family).variant.\(expectedVariant)"
            XCTAssertTrue(descendantNames(in: first).contains(expectedName))
            XCTAssertTrue(descendantNames(in: second).contains(expectedName))
        }
    }

    @MainActor
    func testVacantGrovesAreSparseDeterministicAndTruthSafe() {
        let renderer = TerrainRenderer(style: WorldVisualStyle())
        var groveCoordinates: [GridCoordinate] = []

        for y in 0..<16 {
            for x in 0..<16 {
                let coordinate = GridCoordinate(x: x, y: y)
                let vacant = renderer.makeGround(
                    for: CityTile(coordinate: coordinate, kind: .empty),
                    detail: .block
                )
                if descendantNames(in: vacant).contains("terrain.vacant.grove") {
                    groveCoordinates.append(coordinate)
                    XCTAssertEqual(recursiveActiveActionCount(vacant), 0)
                }

                let road = renderer.makeGround(
                    for: CityTile(coordinate: coordinate, kind: .road),
                    detail: .block
                )
                XCTAssertFalse(descendantNames(in: road).contains("terrain.vacant.grove"))
            }
        }

        XCTAssertGreaterThan(groveCoordinates.count, 20)
        XCTAssertLessThan(groveCoordinates.count, 45)
        for coordinate in groveCoordinates {
            let repeatRender = renderer.makeGround(
                for: CityTile(coordinate: coordinate, kind: .empty),
                detail: .block
            )
            XCTAssertTrue(descendantNames(in: repeatRender).contains("terrain.vacant.grove"))
        }
    }

    @MainActor
    func testStartingCameraFramesTheDevelopedCoreAtDefaultAndCompactBlockDetail() {
        let state = CityGameState.newCity(seed: 42)
        let defaultScene = CityScene(size: CGSize(width: 1_280, height: 800))
        defaultScene.reducedMotion = true
        defaultScene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(defaultScene.cameraScaleForTesting, 0.35, accuracy: 0.001)
        XCTAssertEqual(defaultScene.currentCameraDetailLevel, .block)

        let compactScene = CityScene(size: CGSize(width: 900, height: 600))
        compactScene.reducedMotion = true
        compactScene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(compactScene.cameraScaleForTesting, 0.46, accuracy: 0.001)
        XCTAssertEqual(compactScene.currentCameraDetailLevel, .block)

        let developed = state.tiles.filter { ![.empty, .road].contains($0.kind) }
        let style = WorldVisualStyle()
        let expectedCenter = CGPoint(
            x: developed.map { style.isoPosition($0.coordinate).x }.reduce(0, +) / CGFloat(developed.count),
            y: developed.map { style.isoPosition($0.coordinate).y }.reduce(0, +) / CGFloat(developed.count) + 30
        )
        XCTAssertEqual(defaultScene.cameraPositionForTesting.x, expectedCenter.x, accuracy: 0.001)
        XCTAssertEqual(defaultScene.cameraPositionForTesting.y, expectedCenter.y, accuracy: 0.001)
    }

    func testLotConsequencePresentationMapsOnlyAuthoritativeTileFields() {
        var tile = CityTile(
            coordinate: GridCoordinate(x: 4, y: 7),
            kind: .residential,
            level: 1,
            occupancy: 0,
            condition: 1,
            constructionProgress: 0
        )

        XCTAssertEqual(LotConsequencePresentation(tile: tile).construction, .site)
        tile.constructionProgress = 0.25
        XCTAssertEqual(LotConsequencePresentation(tile: tile).construction, .foundation)
        tile.constructionProgress = 0.50
        XCTAssertEqual(LotConsequencePresentation(tile: tile).construction, .structure)
        tile.constructionProgress = 0.75
        XCTAssertEqual(LotConsequencePresentation(tile: tile).construction, .finishing)
        tile.constructionProgress = 1
        XCTAssertEqual(LotConsequencePresentation(tile: tile).construction, .complete)

        let beforeOccupancyChange = LotConsequencePresentation(tile: tile)
        tile.occupancy = 1
        XCTAssertEqual(
            LotConsequencePresentation(tile: tile),
            beforeOccupancyChange,
            "Raw occupancy must not become a prosperity or vacancy claim without an approved presentation contract"
        )
        tile.level = 3
        XCTAssertEqual(LotConsequencePresentation(tile: tile).growthTier, 3)

        tile.condition = 0.74
        XCTAssertEqual(LotConsequencePresentation(tile: tile).condition, .weathered)
        tile.condition = 0.39
        XCTAssertEqual(LotConsequencePresentation(tile: tile).condition, .distressed)
    }

    @MainActor
    func testLotRendererPublishesDistinctConstructionConditionAndRecoveryStates() {
        let renderer = LotRenderer(style: WorldVisualStyle())
        let coordinate = GridCoordinate(x: 3, y: 3)

        for (progress, expectedName) in [
            (0.0, "lot.lifecycle.construction.site"),
            (0.25, "lot.lifecycle.construction.foundation"),
            (0.50, "lot.lifecycle.construction.frame"),
            (0.75, "lot.lifecycle.construction.finishing")
        ] {
            let tile = CityTile(
                coordinate: coordinate,
                kind: .residential,
                level: 1,
                occupancy: 0,
                condition: 1,
                constructionProgress: progress
            )
            let root = renderer.makeLot(for: tile, detail: .neighborhood, reducedMotion: true)
            XCTAssertTrue(descendantNames(in: root).contains(expectedName))
        }

        let distressed = CityTile(
            coordinate: coordinate,
            kind: .commercial,
            level: 2,
            occupancy: 0,
            condition: 0.25,
            constructionProgress: 1
        )
        let distressedRoot = renderer.makeLot(for: distressed, detail: .block, reducedMotion: true)
        let distressedNames = descendantNames(in: distressedRoot)
        XCTAssertTrue(distressedNames.contains("lot.lifecycle.condition.distressed"))
        XCTAssertFalse(distressedNames.contains("lot.lifecycle.growth.tier.2"))
        XCTAssertTrue(distressedNames.contains("lot.condition.boarding"))
        XCTAssertTrue(distressedNames.contains("lot.condition.rubble"))
        XCTAssertFalse(descendantNames(in: distressedRoot).contains("lot.condition.badge"))
        XCTAssertTrue(descendantLabels(in: distressedRoot).isEmpty)

        var recovered = distressed
        recovered.condition = 1
        recovered.occupancy = 100
        let recoveredRoot = renderer.makeLot(for: recovered, detail: .block, reducedMotion: true)
        let recoveredNames = descendantNames(in: recoveredRoot)
        XCTAssertFalse(recoveredNames.contains("lot.lifecycle.condition.distressed"))
        XCTAssertTrue(recoveredNames.contains("lot.lifecycle.condition.maintained"))
        XCTAssertTrue(recoveredNames.contains("lot.lifecycle.growth.tier.2"))
        XCTAssertTrue(descendantNames(in: recoveredRoot).contains("lot.growth.freshFacade"))
        XCTAssertFalse(descendantNames(in: recoveredRoot).contains("lot.growth.badge"))
        XCTAssertTrue(descendantLabels(in: recoveredRoot).isEmpty)
    }

    @MainActor
    func testLifecycleSilhouettesMotionAndReducedMotionFallbacksStayDistinct() {
        let renderer = LotRenderer(style: WorldVisualStyle())
        let coordinate = GridCoordinate(x: 6, y: 4)
        let expectedStageProp: [(Double, String)] = [
            (0.0, "lot.construction.excavation"),
            (0.25, "lot.construction.rebar"),
            (0.50, "lot.construction.crane"),
            (0.75, "lot.construction.scaffoldSilhouette")
        ]

        for (progress, expectedName) in expectedStageProp {
            let tile = CityTile(
                coordinate: coordinate,
                kind: .residential,
                condition: 1,
                constructionProgress: progress
            )
            let animated = renderer.makeLot(for: tile, detail: .block, reducedMotion: false)
            let staticFallback = renderer.makeLot(for: tile, detail: .block, reducedMotion: true)
            XCTAssertTrue(descendantNames(in: animated).contains(expectedName))
            XCTAssertTrue(descendantNames(in: staticFallback).contains(expectedName))
            XCTAssertGreaterThan(recursiveActiveActionCount(animated), 0)
            XCTAssertEqual(recursiveActiveActionCount(staticFallback), 0)
        }

        let healthyGrowth = CityTile(
            coordinate: coordinate,
            kind: .commercial,
            level: 3,
            occupancy: 0,
            condition: 1,
            constructionProgress: 1
        )
        let growthRoot = renderer.makeLot(for: healthyGrowth, detail: .block, reducedMotion: false)
        XCTAssertTrue(descendantNames(in: growthRoot).contains("lot.lifecycle.growth.tier.3"))
        XCTAssertTrue(descendantNames(in: growthRoot).contains("lot.growth.pennants"))
        XCTAssertGreaterThan(recursiveActiveActionCount(growthRoot), 0)

        var stressed = healthyGrowth
        stressed.condition = 0.58
        let stressedRoot = renderer.makeLot(for: stressed, detail: .block, reducedMotion: false)
        XCTAssertTrue(descendantNames(in: stressedRoot).contains("lot.condition.patchwork"))
        XCTAssertFalse(descendantNames(in: stressedRoot).contains("lot.lifecycle.growth.tier.3"))
        XCTAssertGreaterThan(recursiveActiveActionCount(stressedRoot), 0)

        let park = CityTile(
            coordinate: GridCoordinate(x: 8, y: 9),
            kind: .park,
            constructionProgress: 1
        )
        let ambient = renderer.makeLot(for: park, detail: .neighborhood, reducedMotion: false)
        let staticAmbient = renderer.makeLot(for: park, detail: .neighborhood, reducedMotion: true)
        XCTAssertTrue(descendantNames(in: ambient).contains("lot.ambient.vegetation"))
        XCTAssertGreaterThan(recursiveActiveActionCount(ambient), 0)
        XCTAssertEqual(recursiveActiveActionCount(staticAmbient), 0)
    }

    @MainActor
    func testAnimatedLifecycleNodesReuseAcrossUnchangedPulsesWithoutAccumulation() throws {
        var state = CityGameState.newCity(seed: 42)
        let construction = GridCoordinate(x: 10, y: 11)
        let growth = GridCoordinate(x: 12, y: 15)
        state.updateTile(at: construction) {
            $0.kind = .residential
            $0.constructionProgress = 0.50
        }
        state.updateTile(at: growth) {
            $0.kind = .commercial
            $0.level = 3
            $0.condition = 1
            $0.constructionProgress = 1
        }

        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = false
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        let constructionRoot = try XCTUnwrap(scene.tileRootIdentifier(at: construction))
        let initialActions = scene.diagnosticsSnapshot.activeActionCount
        XCTAssertGreaterThan(initialActions, 0)

        for _ in 0..<12 {
            scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
            XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)
            XCTAssertEqual(scene.tileRootIdentifier(at: construction), constructionRoot)
            XCTAssertEqual(scene.diagnosticsSnapshot.activeActionCount, initialActions)
        }

        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(scene.diagnosticsSnapshot.activeActionCount, 0)
        XCTAssertNotEqual(scene.tileRootIdentifier(at: construction), constructionRoot)
        print(
            "CITYSIM_PLAY020_MOTION_DIAGNOSTICS " +
            "active_actions=\(initialActions) " +
            "unchanged_pulses=12 unchanged_updates=0 " +
            "reduced_motion_actions=\(scene.diagnosticsSnapshot.activeActionCount)"
        )
    }

    @MainActor
    func testThirtyMinuteEquivalentUnchangedPulseSoakPreservesWorldIdentity() throws {
        let state = CityGameState.newCity(seed: 42)
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = false
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)

        let developed = GridCoordinate(x: 11, y: 11)
        let initialRoot = try XCTUnwrap(scene.tileRootIdentifier(at: developed))
        let initialNodes = scene.diagnosticsSnapshot.nodeCount
        let initialDrawables = scene.diagnosticsSnapshot.drawableNodeCount
        let initialActions = scene.diagnosticsSnapshot.activeActionCount
        let pulseCount = 4_286 // 30 minutes at the shipping 420 ms app pulse.
        let started = ProcessInfo.processInfo.systemUptime

        for _ in 0..<pulseCount {
            scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        }

        let elapsedMilliseconds = (ProcessInfo.processInfo.systemUptime - started) * 1_000
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)
        XCTAssertEqual(scene.tileRootIdentifier(at: developed), initialRoot)
        XCTAssertEqual(scene.diagnosticsSnapshot.nodeCount, initialNodes)
        XCTAssertEqual(scene.diagnosticsSnapshot.drawableNodeCount, initialDrawables)
        XCTAssertEqual(scene.diagnosticsSnapshot.activeActionCount, initialActions)
        print(
            "CITYSIM_PLAY021_SOAK_DIAGNOSTICS " +
            "equivalent_minutes=30 pulses=\(pulseCount) " +
            "nodes=\(initialNodes) drawables=\(initialDrawables) actions=\(initialActions) " +
            "total_ms=\(String(format: "%.3f", elapsedMilliseconds)) " +
            "average_ms=\(String(format: "%.4f", elapsedMilliseconds / Double(pulseCount)))"
        )
    }

    @MainActor
    func testCitySceneInvalidatesOnlyVisibleLifecycleBandChanges() throws {
        var state = CityGameState.newCity(seed: 42)
        let target = GridCoordinate(x: 10, y: 11)
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: target, interactionMode: .inspect)
        let originalRoot = try XCTUnwrap(scene.tileRootIdentifier(at: target))
        XCTAssertGreaterThan(scene.diagnosticsSnapshot.drawableNodeCount, state.tiles.count)
        XCTAssertEqual(scene.diagnosticsSnapshot.activeActionCount, 0)
        XCTAssertGreaterThanOrEqual(scene.diagnosticsSnapshot.updateDurationMilliseconds, 0)

        state.updateTile(at: target) { $0.condition = 0.90 }
        scene.render(state: state, overlay: .none, selection: target, interactionMode: .inspect)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)
        XCTAssertEqual(scene.tileRootIdentifier(at: target), originalRoot)

        state.updateTile(at: target) { $0.condition = 0.60 }
        scene.render(state: state, overlay: .none, selection: target, interactionMode: .inspect)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 1)
        let weatheredRoot = try XCTUnwrap(scene.tileRootIdentifier(at: target))
        XCTAssertNotEqual(weatheredRoot, originalRoot)

        state.updateTile(at: target) { $0.condition = 0.55 }
        scene.render(state: state, overlay: .none, selection: target, interactionMode: .inspect)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)
        XCTAssertEqual(scene.tileRootIdentifier(at: target), weatheredRoot)

        state.updateTile(at: target) {
            $0.condition = 1
            $0.occupancy = 80
        }
        scene.render(state: state, overlay: .none, selection: target, interactionMode: .inspect)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 1)
        XCTAssertNotEqual(scene.tileRootIdentifier(at: target), weatheredRoot)
    }

    @MainActor
    func testGoldenNeighborhoodShippingRendererExportsThreeLODsAndCompact() throws {
        let state = goldenNeighborhoodState()
        let city = try lifecycleFrame(
            state: state,
            size: CGSize(width: 1_280, height: 800),
            detail: .city,
            centeredOn: GridCoordinate(x: 3, y: 3)
        )
        let neighborhood = try lifecycleFrame(
            state: state,
            size: CGSize(width: 1_280, height: 800),
            detail: .neighborhood,
            centeredOn: GridCoordinate(x: 3, y: 3)
        )
        let block = try lifecycleFrame(
            state: state,
            size: CGSize(width: 1_280, height: 800),
            detail: .block,
            centeredOn: GridCoordinate(x: 3, y: 3)
        )
        let compact = try lifecycleFrame(
            state: state,
            size: CGSize(width: 900, height: 600),
            detail: .neighborhood,
            centeredOn: GridCoordinate(x: 3, y: 3)
        )

        for proof in [city, neighborhood, block, compact] {
            XCTAssertGreaterThan(proof.png.count, 40_000)
            XCTAssertEqual(proof.diagnostics.totalTileCount, 64)
            XCTAssertEqual(proof.diagnostics.activeActionCount, 0)
        }
        XCTAssertNotEqual(city.png, neighborhood.png)
        XCTAssertNotEqual(neighborhood.png, block.png)
        try export(city.png, environmentKey: "CITYSIM_PLAY021_GOLDEN_CITY_PROOF")
        try export(neighborhood.png, environmentKey: "CITYSIM_PLAY021_GOLDEN_NEIGHBORHOOD_PROOF")
        try export(block.png, environmentKey: "CITYSIM_PLAY021_GOLDEN_BLOCK_PROOF")
        try export(compact.png, environmentKey: "CITYSIM_PLAY021_GOLDEN_COMPACT_PROOF")
        print(
            "CITYSIM_PLAY021_GOLDEN_DIAGNOSTICS " +
            "nodes=\(block.diagnostics.nodeCount) drawables=\(block.diagnostics.drawableNodeCount) " +
            "actions=\(block.diagnostics.activeActionCount) " +
            "update_ms=\(String(format: "%.3f", block.diagnostics.updateDurationMilliseconds))"
        )
    }

    @MainActor
    func testLifecycleProofFramesDistinguishConstructionDeclineAndRecovery() throws {
        let before = try lifecycleFrame(
            state: lifecycleProofState(recovered: false),
            size: CGSize(width: 1_280, height: 800),
            detail: .neighborhood
        )
        let after = try lifecycleFrame(
            state: lifecycleProofState(recovered: true),
            size: CGSize(width: 1_280, height: 800),
            detail: .neighborhood
        )
        let compact = try lifecycleFrame(
            state: lifecycleProofState(recovered: false),
            size: CGSize(width: 900, height: 600),
            detail: .neighborhood
        )
        let city = try lifecycleFrame(
            state: lifecycleProofState(recovered: false),
            size: CGSize(width: 1_280, height: 800),
            detail: .city
        )
        let block = try lifecycleFrame(
            state: lifecycleProofState(recovered: false),
            size: CGSize(width: 1_280, height: 800),
            detail: .block
        )

        XCTAssertGreaterThan(before.png.count, 40_000)
        XCTAssertGreaterThan(after.png.count, 40_000)
        XCTAssertGreaterThan(compact.png.count, 40_000)
        XCTAssertGreaterThan(city.png.count, 40_000)
        XCTAssertGreaterThan(block.png.count, 40_000)
        XCTAssertNotEqual(before.png, after.png)
        XCTAssertNotEqual(city.png, block.png)
        XCTAssertEqual(before.diagnostics.totalTileCount, 80)
        XCTAssertEqual(after.diagnostics.totalTileCount, 80)
        XCTAssertEqual(before.diagnostics.activeActionCount, 0)
        XCTAssertEqual(compact.diagnostics.activeActionCount, 0)

        try export(before.png, environmentKey: "CITYSIM_PLAY020_LIFECYCLE_PROOF")
        try export(after.png, environmentKey: "CITYSIM_PLAY020_RECOVERY_PROOF")
        try export(compact.png, environmentKey: "CITYSIM_PLAY020_COMPACT_PROOF")
        try export(city.png, environmentKey: "CITYSIM_PLAY020_CITY_PROOF")
        try export(block.png, environmentKey: "CITYSIM_PLAY020_BLOCK_PROOF")
        print(
            "CITYSIM_PLAY020_DIAGNOSTICS lifecycle_nodes=\(before.diagnostics.nodeCount) " +
            "lifecycle_drawables=\(before.diagnostics.drawableNodeCount) " +
            "lifecycle_actions=\(before.diagnostics.activeActionCount) " +
            "lifecycle_update_ms=\(String(format: "%.3f", before.diagnostics.updateDurationMilliseconds)) " +
            "recovery_nodes=\(after.diagnostics.nodeCount) " +
            "recovery_drawables=\(after.diagnostics.drawableNodeCount) " +
            "recovery_actions=\(after.diagnostics.activeActionCount) " +
            "recovery_update_ms=\(String(format: "%.3f", after.diagnostics.updateDurationMilliseconds)) " +
            "compact_nodes=\(compact.diagnostics.nodeCount) " +
            "city_nodes=\(city.diagnostics.nodeCount) " +
            "block_nodes=\(block.diagnostics.nodeCount) " +
            "detail=\(after.diagnostics.detailLevel)"
        )
    }

    private func lifecycleProofState(recovered: Bool) -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.gridWidth = 10
        state.gridHeight = 8
        state.tiles = (0..<80).map { index in
            CityTile(
                coordinate: GridCoordinate(x: index % 10, y: index / 10),
                kind: .empty
            )
        }
        for x in 0..<10 {
            state.updateTile(at: GridCoordinate(x: x, y: 4)) { $0.kind = .road }
        }

        let construction: [(Int, Double)] = [(1, 0), (3, 0.25), (5, 0.50), (7, 0.75)]
        for (x, progress) in construction {
            state.updateTile(at: GridCoordinate(x: x, y: 3)) {
                $0.kind = .residential
                $0.constructionProgress = progress
            }
        }
        state.updateTile(at: GridCoordinate(x: 6, y: 5)) {
            $0.kind = .commercial
            $0.level = 3
            $0.occupancy = 220
        }
        state.updateTile(at: GridCoordinate(x: 2, y: 5)) {
            $0.kind = .industrial
            $0.level = 2
            $0.occupancy = recovered ? 180 : 0
            $0.condition = recovered ? 1 : 0.58
        }
        state.updateTile(at: GridCoordinate(x: 4, y: 5)) {
            $0.kind = .residential
            $0.level = 2
            $0.occupancy = recovered ? 190 : 0
            $0.condition = recovered ? 1 : 0.24
        }
        state.updateTile(at: GridCoordinate(x: 8, y: 5)) { $0.kind = .park }
        state.updateTile(at: GridCoordinate(x: 9, y: 3)) { $0.kind = .cityHall }
        return state
    }

    private func goldenNeighborhoodState() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.gridWidth = 8
        state.gridHeight = 8
        state.tiles = (0..<64).map { index in
            CityTile(coordinate: GridCoordinate(x: index % 8, y: index / 8), kind: .empty)
        }
        for index in 0..<8 {
            state.updateTile(at: GridCoordinate(x: index, y: 3)) { $0.kind = .road }
            state.updateTile(at: GridCoordinate(x: 3, y: index)) { $0.kind = .road }
        }
        let places: [(GridCoordinate, BuildingKind, Int)] = [
            (GridCoordinate(x: 2, y: 2), .cityHall, 1),
            (GridCoordinate(x: 1, y: 2), .residential, 2),
            (GridCoordinate(x: 2, y: 4), .residential, 1),
            (GridCoordinate(x: 4, y: 2), .commercial, 2),
            (GridCoordinate(x: 5, y: 2), .commercial, 1),
            (GridCoordinate(x: 4, y: 4), .industrial, 2),
            (GridCoordinate(x: 5, y: 4), .industrial, 1),
            (GridCoordinate(x: 2, y: 5), .park, 1),
            (GridCoordinate(x: 4, y: 5), .park, 1)
        ]
        for (coordinate, kind, level) in places {
            state.updateTile(at: coordinate) {
                $0.kind = kind
                $0.level = level
                $0.condition = 1
                $0.constructionProgress = 1
            }
        }
        return state
    }

    @MainActor
    private func lifecycleFrame(
        state: CityGameState,
        size: CGSize,
        detail: CameraDetailLevel,
        centeredOn coordinate: GridCoordinate = GridCoordinate(x: 5, y: 4)
    ) throws -> (png: Data, diagnostics: RendererDiagnosticsSnapshot) {
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = CityScene(size: size)
        scene.reducedMotion = true
        view.presentScene(scene)
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        scene.configureProofCamera(detail: detail, centeredOn: coordinate)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.12))

        let texture = try XCTUnwrap(view.texture(from: scene))
        let representation = NSBitmapImageRep(cgImage: texture.cgImage())
        let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        return (png, scene.diagnosticsSnapshot)
    }

    private func export(_ data: Data, environmentKey: String) throws {
        guard let path = ProcessInfo.processInfo.environment[environmentKey] else { return }
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    @MainActor
    private func descendantNames(in node: SKNode) -> [String] {
        var result = node.name.map { [$0] } ?? []
        for child in node.children { result.append(contentsOf: descendantNames(in: child)) }
        return result
    }

    @MainActor
    private func descendantLabels(in node: SKNode) -> [String] {
        var result: [String] = []
        if let label = node as? SKLabelNode, let text = label.text { result.append(text) }
        for child in node.children { result.append(contentsOf: descendantLabels(in: child)) }
        return result
    }

    @MainActor
    private func recursiveActiveActionCount(_ node: SKNode) -> Int {
        let localCount = node.hasActions() ? 1 : 0
        return node.children.reduce(localCount) { $0 + recursiveActiveActionCount($1) }
    }
}
