import AppKit
import SpriteKit
import XCTest
@testable import CitySimNative

final class WorldRenderingTests: XCTestCase {
    @MainActor
    func testSpatialConsequencesPublishNonColorUtilityPollutionAndVitalityCues() {
        let renderer = SpatialConsequenceRenderer(style: WorldVisualStyle())
        let consequence = CitySpatialConsequence(
            coordinate: GridCoordinate(x: 4, y: 5),
            utility: CityLocationUtilityService(
                power: 0.2,
                water: 0.7,
                combined: 0.2,
                powerBand: .severe,
                waterBand: .strained,
                combinedBand: .severe
            ),
            pollutionExposure: 0.8,
            pollutionBand: .severe,
            vitalityScore: 0.3,
            vitality: .strained
        )

        let root = renderer.makePersistentCues(for: consequence, detail: .block)
        let names = descendantNames(in: root)
        XCTAssertTrue(names.contains("spatial.utility.severe.brackets"))
        XCTAssertTrue(names.contains("spatial.utility.power.severe.broken-bolt"))
        XCTAssertTrue(names.contains("spatial.utility.water.strained.dry-drop"))
        XCTAssertTrue(names.contains("spatial.pollution.severe.particulate"))
        XCTAssertTrue(names.contains("spatial.vitality.strained.patchwork"))
        XCTAssertTrue(descendantLabels(in: root).isEmpty)
    }

    @MainActor
    func testSpatialTransitionEventsHaveStaticReduceMotionMeaningAndBoundedAnimation() {
        let renderer = SpatialConsequenceRenderer(style: WorldVisualStyle())
        let event = CitySpatialConsequenceEvent(
            id: "stable-event",
            authoritativeTick: 8,
            coordinate: GridCoordinate(x: 10, y: 11),
            dimension: .utility,
            direction: .recovery,
            fromBand: .severe,
            toBand: .healthy
        )
        let animated = renderer.makeEventCue(for: event, reducedMotion: false)
        let reduced = renderer.makeEventCue(for: event, reducedMotion: true)

        XCTAssertTrue(descendantNames(in: reduced).contains("spatial.event.mark.recovery"))
        XCTAssertEqual(recursiveActiveActionCount(animated), 1)
        XCTAssertEqual(recursiveActiveActionCount(reduced), 0)
    }

    @MainActor
    func testUtilityAndPollutionOverlaysUseApprovedSpatialSampleInsteadOfStateInference() throws {
        let renderer = WorldOverlayRenderer(style: WorldVisualStyle())
        let tile = CityTile(coordinate: GridCoordinate(x: 2, y: 3), kind: .residential)
        let consequence = CitySpatialConsequence(
            coordinate: tile.coordinate,
            utility: CityLocationUtilityService(
                power: 0.33,
                water: 0.71,
                combined: 0.33,
                powerBand: .severe,
                waterBand: .strained,
                combinedBand: .severe
            ),
            pollutionExposure: 0.64,
            pollutionBand: .severe,
            vitalityScore: 0,
            vitality: .notApplicable
        )
        var contradictoryState = CityGameState.newCity(seed: 42)
        contradictoryState.powerCapacity = 99_999
        contradictoryState.waterCapacity = 99_999
        contradictoryState.tiles = contradictoryState.tiles.map {
            var value = $0
            if value.kind == .industrial || value.kind == .powerPlant { value.kind = .empty }
            return value
        }

        let utility = renderer.sample(
            for: tile,
            state: contradictoryState,
            consequence: consequence,
            overlay: .utilities
        )
        let pollution = renderer.sample(
            for: tile,
            state: contradictoryState,
            consequence: consequence,
            overlay: .pollution
        )
        XCTAssertEqual(try XCTUnwrap(utility).value, 0.33, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(pollution).value, 0.36, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(utility).pattern.rawValue, "utilityEdge")
        XCTAssertEqual(try XCTUnwrap(pollution).pattern.rawValue, "pollutionHatch")
        XCTAssertNil(renderer.sample(
            for: tile,
            state: contradictoryState,
            consequence: nil,
            overlay: .utilities
        ))
        for unsupportedOverlay in [DataOverlay.landValue, .traffic, .happiness] {
            XCTAssertNil(renderer.sample(
                for: tile,
                state: contradictoryState,
                consequence: consequence,
                overlay: unsupportedOverlay
            ))
        }
        for undevelopedKind in [BuildingKind.empty, .road] {
            XCTAssertNil(renderer.sample(
                for: CityTile(coordinate: tile.coordinate, kind: undevelopedKind),
                state: contradictoryState,
                consequence: consequence,
                overlay: .pollution
            ))
        }
        XCTAssertNil(renderer.sample(
            for: CityTile(coordinate: GridCoordinate(x: 3, y: 3), kind: .residential),
            state: contradictoryState,
            consequence: consequence,
            overlay: .utilities
        ))
    }

    @MainActor
    func testApprovedOverlaysUseSparseNonColorSeverityMarksWithoutTileWashOrLabels() {
        let style = WorldVisualStyle()
        let renderer = WorldOverlayRenderer(style: style)
        let tile = CityTile(coordinate: GridCoordinate(x: 2, y: 3), kind: .residential)
        let severe = CitySpatialConsequence(
            coordinate: tile.coordinate,
            utility: CityLocationUtilityService(
                power: 0.20,
                water: 0.72,
                combined: 0.20,
                powerBand: .severe,
                waterBand: .strained,
                combinedBand: .severe
            ),
            pollutionExposure: 0.80,
            pollutionBand: .severe,
            vitalityScore: 0,
            vitality: .notApplicable
        )
        let state = CityGameState.newCity(seed: 42)

        let utility = renderer.makeOverlay(
            for: tile,
            state: state,
            consequence: severe,
            overlay: .utilities,
            detail: .block
        )
        let pollution = renderer.makeOverlay(
            for: tile,
            state: state,
            consequence: severe,
            overlay: .pollution,
            detail: .block
        )

        let utilityNames = descendantNames(in: utility)
        let pollutionNames = descendantNames(in: pollution)
        XCTAssertFalse(utilityNames.contains("overlay.base"))
        XCTAssertFalse(pollutionNames.contains("overlay.base"))
        XCTAssertTrue(utilityNames.contains("overlay.utility.status-edge"))
        XCTAssertEqual(utilityNames.filter { $0 == "overlay.utility.severity-notch" }.count, 3)
        XCTAssertEqual(pollutionNames.filter { $0 == "overlay.pollution.exposure-hatch" }.count, 3)
        XCTAssertTrue(descendantLabels(in: utility).isEmpty)
        XCTAssertTrue(descendantLabels(in: pollution).isEmpty)

        let utilityBounds = utility.calculateAccumulatedFrame()
        let pollutionBounds = pollution.calculateAccumulatedFrame()
        XCTAssertLessThan(utilityBounds.width, style.tileWidth * 0.60)
        XCTAssertLessThan(utilityBounds.height, style.tileHeight * 0.50)
        XCTAssertLessThan(pollutionBounds.width, style.tileWidth * 0.60)
        XCTAssertLessThan(pollutionBounds.height, style.tileHeight * 0.50)

        let mild = CitySpatialConsequence(
            coordinate: tile.coordinate,
            utility: CityLocationUtilityService(
                power: 0.60,
                water: 0.92,
                combined: 0.60,
                powerBand: .strained,
                waterBand: .healthy,
                combinedBand: .strained
            ),
            pollutionExposure: 0.40,
            pollutionBand: .strained,
            vitalityScore: 0,
            vitality: .notApplicable
        )
        let mildAtCity = renderer.makeOverlay(
            for: tile,
            state: state,
            consequence: mild,
            overlay: .utilities,
            detail: .city
        )
        let neighborhoodLayer = mildAtCity.childNode(withName: "//detail.neighborhood")
        XCTAssertEqual(neighborhoodLayer?.isHidden, true)
        style.updateDetailVisibility(in: mildAtCity, detail: .block)
        XCTAssertEqual(neighborhoodLayer?.isHidden, false)
    }

    @MainActor
    func testReducedMotionEventsExpireBoundedlyAndSuppressSaveLoadUndoReplayDuplicates() throws {
        var strained = CityGameState.newCity(seed: 42)
        strained.tick = 4
        strained.powerCapacity = 0
        strained.waterCapacity = 0
        let strainedSnapshot = try CityPresentationSnapshot(state: strained)

        var recovered = strained
        recovered.tick = 8
        recovered.powerCapacity = 300
        recovered.waterCapacity = 270
        let recoveredSnapshot = try CityPresentationSnapshot(state: recovered)

        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(snapshot: strainedSnapshot, overlay: .none, selection: nil, interactionMode: .inspect)
        let strainedNodeCount = scene.diagnosticsSnapshot.nodeCount
        scene.render(snapshot: recoveredSnapshot, overlay: .none, selection: nil, interactionMode: .inspect)
        let firstCount = scene.consumedConsequenceEventIDCountForTesting
        XCTAssertGreaterThan(firstCount, 0)
        XCTAssertGreaterThan(scene.diagnosticsSnapshot.consumedConsequenceEventCount, 0)
        XCTAssertGreaterThan(scene.diagnosticsSnapshot.displayedConsequenceCueCount, 0)
        XCTAssertLessThan(
            scene.diagnosticsSnapshot.displayedConsequenceCueCount,
            scene.diagnosticsSnapshot.consumedConsequenceEventCount,
            "Many accepted events are grouped into one developed-place cue per coordinate"
        )
        XCTAssertLessThanOrEqual(scene.tileConsequenceEventNodeCountForTesting(at: GridCoordinate(x: 10, y: 11)), 1)
        XCTAssertEqual(scene.diagnosticsSnapshot.activeActionCount, 0)
        XCTAssertGreaterThan(scene.diagnosticsSnapshot.nodeCount, strainedNodeCount)
        let insertedRecount = scene.recountedRuntimeMetricsForTesting()
        XCTAssertEqual(scene.diagnosticsSnapshot.nodeCount, insertedRecount.nodes)
        XCTAssertEqual(scene.diagnosticsSnapshot.drawableNodeCount, insertedRecount.drawables)
        XCTAssertEqual(scene.diagnosticsSnapshot.activeActionCount, insertedRecount.actions)
        let recoveryNodeCount = scene.diagnosticsSnapshot.nodeCount
        let recoveryDrawableCount = scene.diagnosticsSnapshot.drawableNodeCount

        scene.render(snapshot: recoveredSnapshot, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(scene.consumedConsequenceEventIDCountForTesting, firstCount)
        XCTAssertEqual(scene.diagnosticsSnapshot.consumedConsequenceEventCount, 0)
        XCTAssertGreaterThan(scene.diagnosticsSnapshot.displayedConsequenceCueCount, 0)
        XCTAssertEqual(scene.diagnosticsSnapshot.nodeCount, recoveryNodeCount)
        XCTAssertEqual(scene.diagnosticsSnapshot.drawableNodeCount, recoveryDrawableCount)
        XCTAssertLessThanOrEqual(scene.tileConsequenceEventNodeCountForTesting(at: GridCoordinate(x: 10, y: 11)), 1)

        scene.render(snapshot: strainedSnapshot, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(scene.consumedConsequenceEventIDCountForTesting, firstCount)
        XCTAssertEqual(scene.tileConsequenceEventNodeCountForTesting(at: GridCoordinate(x: 10, y: 11)), 0)

        scene.render(snapshot: recoveredSnapshot, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(
            scene.consumedConsequenceEventIDCountForTesting,
            firstCount,
            "Forward deterministic replay must not re-present stable event IDs"
        )
        XCTAssertEqual(scene.tileConsequenceEventNodeCountForTesting(at: GridCoordinate(x: 10, y: 11)), 0)

        let expiryScene = CityScene(size: CGSize(width: 1_280, height: 800))
        expiryScene.reducedMotion = true
        expiryScene.render(snapshot: strainedSnapshot, overlay: .none, selection: nil, interactionMode: .inspect)
        expiryScene.render(snapshot: recoveredSnapshot, overlay: .none, selection: nil, interactionMode: .inspect)
        let beforeExpiryNodeCount = expiryScene.diagnosticsSnapshot.nodeCount
        expiryScene.render(snapshot: recoveredSnapshot, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(expiryScene.diagnosticsSnapshot.nodeCount, beforeExpiryNodeCount)
        var elapsed = recovered
        elapsed.tick = 12
        expiryScene.render(
            snapshot: try CityPresentationSnapshot(state: elapsed),
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        XCTAssertEqual(expiryScene.diagnosticsSnapshot.consumedConsequenceEventCount, 0)
        XCTAssertEqual(expiryScene.diagnosticsSnapshot.displayedConsequenceCueCount, 0)
        XCTAssertEqual(expiryScene.diagnosticsSnapshot.updatedTileCount, 0)
        XCTAssertEqual(expiryScene.diagnosticsSnapshot.reusedTileCount, elapsed.tiles.count)
        XCTAssertLessThan(expiryScene.diagnosticsSnapshot.nodeCount, beforeExpiryNodeCount)
        XCTAssertEqual(expiryScene.diagnosticsSnapshot.activeActionCount, 0)
        let expiredRecount = expiryScene.recountedRuntimeMetricsForTesting()
        XCTAssertEqual(expiryScene.diagnosticsSnapshot.nodeCount, expiredRecount.nodes)
        XCTAssertEqual(expiryScene.diagnosticsSnapshot.drawableNodeCount, expiredRecount.drawables)
        XCTAssertEqual(expiryScene.diagnosticsSnapshot.activeActionCount, expiredRecount.actions)

        let loaded = try JSONDecoder().decode(CityGameState.self, from: JSONEncoder().encode(recovered))
        let loadedScene = CityScene(size: CGSize(width: 1_280, height: 800))
        loadedScene.reducedMotion = true
        loadedScene.render(
            snapshot: try CityPresentationSnapshot(state: loaded),
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        XCTAssertEqual(loadedScene.diagnosticsSnapshot.consumedConsequenceEventCount, 0)
        XCTAssertEqual(loadedScene.diagnosticsSnapshot.displayedConsequenceCueCount, 0)
        XCTAssertEqual(loadedScene.diagnosticsSnapshot.activeActionCount, 0)

        var newlyStrained = strained
        newlyStrained.tick = 12
        scene.render(
            snapshot: try CityPresentationSnapshot(state: newlyStrained),
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        XCTAssertLessThanOrEqual(scene.tileConsequenceEventNodeCountForTesting(at: GridCoordinate(x: 10, y: 11)), 1)
        XCTAssertEqual(scene.diagnosticsSnapshot.activeActionCount, 0)
    }

    @MainActor
    func testCityLODUsesOnePersistentNonColorAggregatePerDevelopedPlace() {
        let style = WorldVisualStyle()
        let renderer = SpatialConsequenceRenderer(style: style)
        let consequence = CitySpatialConsequence(
            coordinate: GridCoordinate(x: 4, y: 5),
            utility: CityLocationUtilityService(
                power: 0.2,
                water: 0.7,
                combined: 0.2,
                powerBand: .severe,
                waterBand: .strained,
                combinedBand: .severe
            ),
            pollutionExposure: 0.8,
            pollutionBand: .severe,
            vitalityScore: 0.3,
            vitality: .strained
        )
        let root = renderer.makePersistentCues(for: consequence, detail: .city)
        let city = root.childNode(withName: "//detail.city")
        let neighborhood = root.childNode(withName: "//detail.neighborhood")
        let block = root.childNode(withName: "//detail.block")

        XCTAssertEqual(city?.isHidden, false)
        XCTAssertEqual(neighborhood?.isHidden, true)
        XCTAssertEqual(block?.isHidden, true)
        XCTAssertEqual(
            descendantNames(in: root).filter { $0.hasPrefix("spatial.city.aggregate.") },
            ["spatial.city.aggregate.severe.cross"]
        )
        XCTAssertTrue(descendantLabels(in: root).isEmpty)

        style.updateDetailVisibility(in: root, detail: .block)
        XCTAssertEqual(city?.isHidden, false)
        XCTAssertEqual(neighborhood?.isHidden, false)
        XCTAssertEqual(block?.isHidden, false)
        XCTAssertEqual(
            descendantNames(in: root).filter { $0.hasPrefix("spatial.city.aggregate.") }.count,
            1
        )
    }

    @MainActor
    func testSpatialConsequenceProofExportsSameCityWorseningRecoveryAndCompact() throws {
        let strained = spatialProofState(recovered: false)
        let recovered = spatialProofState(recovered: true)
        let strainedSnapshot = try CityPresentationSnapshot(state: strained)
        let recoveredSnapshot = try CityPresentationSnapshot(state: recovered)
        let focus = GridCoordinate(x: 10, y: 11)
        let strainedSample = try XCTUnwrap(strainedSnapshot.spatialConsequences[focus])
        let recoveredSample = try XCTUnwrap(recoveredSnapshot.spatialConsequences[focus])
        let focusEventIDs = recoveredSnapshot.consequenceEvents(since: strainedSnapshot)
            .filter { $0.coordinate == focus }
            .map(\.id)
        let defaultProof = try spatialTransitionFrame(
            from: strained,
            to: recovered,
            size: CGSize(width: 1_280, height: 800)
        )
        let compactProof = try spatialTransitionFrame(
            from: strained,
            to: recovered,
            size: CGSize(width: 900, height: 600)
        )
        let strainedProof = try lifecycleFrame(
            state: strained,
            size: CGSize(width: 1_280, height: 800),
            detail: .block,
            centeredOn: GridCoordinate(x: 12, y: 11)
        )

        XCTAssertNotEqual(strainedProof.png, defaultProof.png)
        XCTAssertNotEqual(defaultProof.png, compactProof.png)
        XCTAssertGreaterThan(defaultProof.png.count, 40_000)
        XCTAssertGreaterThan(compactProof.png.count, 40_000)
        XCTAssertGreaterThan(defaultProof.consumedEventCount, 0)
        XCTAssertGreaterThan(defaultProof.displayedCueCount, 0)
        XCTAssertLessThan(defaultProof.displayedCueCount, defaultProof.consumedEventCount)
        XCTAssertEqual(strainedSample.utility.combinedBand, .severe)
        XCTAssertEqual(strainedSample.vitality, .strained)
        XCTAssertEqual(recoveredSample.utility.combinedBand, .strained)
        XCTAssertEqual(recoveredSample.vitality, .prosperous)
        XCTAssertEqual(focusEventIDs.count, 2)
        XCTAssertEqual(defaultProof.actions, 0)
        XCTAssertEqual(compactProof.actions, 0)

        try export(strainedProof.png, environmentKey: "CITYSIM_PLAY022_SPATIAL_STRAINED_PROOF")
        try export(defaultProof.png, environmentKey: "CITYSIM_PLAY022_SPATIAL_RECOVERY_PROOF")
        try export(compactProof.png, environmentKey: "CITYSIM_PLAY022_SPATIAL_COMPACT_PROOF")
        print(
            "CITYSIM_PLAY022_SPATIAL_PROOF focus=10,11 " +
            "strained_utility=\(strainedSample.utility.combinedBand) " +
            "strained_pollution=\(strainedSample.pollutionBand) " +
            "strained_vitality=\(strainedSample.vitality) " +
            "recovered_utility=\(recoveredSample.utility.combinedBand) " +
            "recovered_pollution=\(recoveredSample.pollutionBand) " +
            "recovered_vitality=\(recoveredSample.vitality) " +
            "event_ids=\(focusEventIDs.joined(separator: ","))"
        )
    }

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

        let manifest = catalog.generatedManifest
        XCTAssertEqual(manifest?.schema, 4)
        XCTAssertEqual(manifest?.packID, "generated-v4-calibration")
        XCTAssertEqual(manifest?.productionSelection, true)
        XCTAssertEqual(manifest?.assets.count, 12)
        for asset in manifest?.assets ?? [] {
            for detail in CameraDetailLevel.allCases {
                XCTAssertNotNil(catalog.generatedSprite(logicalID: asset.logicalID, detail: detail))
            }
        }
    }

    @MainActor
    func testGeneratedWorldDescriptorsRegisterPhysicalGeometryWithoutInventingGameplayCells() throws {
        let catalog = WorldAssetCatalog()
        let manifest = try XCTUnwrap(catalog.generatedManifest)

        XCTAssertEqual(catalog.manifestValidationIssues(), [])
        XCTAssertEqual(manifest.inventory.count, 84)
        XCTAssertEqual(manifest.compiledNetwork.connectionMasks, 16)

        for asset in manifest.assets {
            XCTAssertEqual(asset.footprintTiles, [1, 1], asset.logicalID)
            XCTAssertEqual(asset.sourceCanvasPixels, [1_536, 1_024], asset.logicalID)
            XCTAssertEqual(asset.placementOffsetWorld, [0, -18], asset.logicalID)
            XCTAssertEqual(asset.groundContactPolygonWorld.count, 4, asset.logicalID)
            XCTAssertEqual(asset.opaqueBoundsWorld.count, 4, asset.logicalID)
            XCTAssertEqual(asset.shadowBoundsWorld.count, 4, asset.logicalID)
            XCTAssertFalse(asset.depthRoles.isEmpty, asset.logicalID)

            let worldSizes = try CameraDetailLevel.allCases.map { detail in
                let lod = try XCTUnwrap(asset.lods[detail.assetSuffix])
                XCTAssertEqual(lod.trimRectPixels, [0, 0, lod.pixels[0], lod.pixels[1]], asset.logicalID)
                XCTAssertEqual(lod.sourceTrimRectPixels[2], lod.pixels[0], asset.logicalID)
                XCTAssertEqual(lod.sourceTrimRectPixels[3], lod.pixels[1], asset.logicalID)
                XCTAssertLessThanOrEqual(
                    lod.sourceTrimRectPixels[0] + lod.sourceTrimRectPixels[2],
                    lod.sourcePixels[0],
                    asset.logicalID
                )
                XCTAssertLessThanOrEqual(
                    lod.sourceTrimRectPixels[1] + lod.sourceTrimRectPixels[3],
                    lod.sourcePixels[1],
                    asset.logicalID
                )
                XCTAssertEqual(lod.decodedByteEstimate, lod.pixels[0] * lod.pixels[1] * 4, asset.logicalID)
                let textureName = (lod.file as NSString).deletingPathExtension
                let physicalTexture = try XCTUnwrap(catalog.texture(named: textureName))
                let presentation = try XCTUnwrap(
                    catalog.generatedPresentation(logicalID: asset.logicalID, detail: detail)
                )
                XCTAssertTrue(presentation.sprite.texture === physicalTexture, asset.logicalID)
                XCTAssertEqual(presentation.sprite.position.x, asset.placementOffsetWorld[0], accuracy: 0.001)
                XCTAssertEqual(presentation.sprite.position.y, asset.placementOffsetWorld[1], accuracy: 0.001)
                XCTAssertEqual(presentation.sprite.anchorPoint.x, lod.anchor[0], accuracy: 0.000_001)
                XCTAssertEqual(presentation.sprite.anchorPoint.y, lod.anchor[1], accuracy: 0.000_001)
                return lod.worldSize
            }
            XCTAssertEqual(worldSizes[0], worldSizes[1], "\(asset.logicalID) drifts between city and neighborhood")
            XCTAssertEqual(worldSizes[1], worldSizes[2], "\(asset.logicalID) drifts between neighborhood and block")
        }

        let grass = try XCTUnwrap(catalog.generatedAsset(logicalID: "grass_material"))
        XCTAssertEqual(grass.opaqueBoundsWorld, [-36, -18, 36, 18])
        XCTAssertLessThanOrEqual(try XCTUnwrap(grass.lods["block"]).worldSize[0], 72.5)
        XCTAssertLessThanOrEqual(try XCTUnwrap(grass.lods["block"]).worldSize[1], 36.5)
    }

    @MainActor
    func testGeneratedWorldCatalogMeasuresDecodeLoadWithoutChargingCacheHits() throws {
        let catalog = WorldAssetCatalog()
        let manifest = try XCTUnwrap(catalog.generatedManifest)
        let asset = try XCTUnwrap(manifest.assets.first)
        let lod = try XCTUnwrap(asset.lods[CameraDetailLevel.block.assetSuffix])
        let textureName = (lod.file as NSString).deletingPathExtension
        let before = catalog.residencySnapshot()

        XCTAssertNotNil(catalog.texture(named: textureName))
        let loaded = catalog.residencySnapshot()
        XCTAssertEqual(loaded.textureDecodeLoadCount, before.textureDecodeLoadCount + 1)
        XCTAssertGreaterThan(
            loaded.textureDecodeLoadDurationMilliseconds,
            before.textureDecodeLoadDurationMilliseconds
        )

        XCTAssertNotNil(catalog.texture(named: textureName))
        let cached = catalog.residencySnapshot()
        XCTAssertEqual(cached.textureDecodeLoadCount, loaded.textureDecodeLoadCount)
        XCTAssertEqual(
            cached.textureDecodeLoadDurationMilliseconds,
            loaded.textureDecodeLoadDurationMilliseconds,
            accuracy: 0.000_001
        )
        XCTAssertEqual(cached.cacheHits, loaded.cacheHits + 1)
    }

    @MainActor
    func testGeneratedWorldResidencyIsBoundedAcrossRepeatedRealLODTransitions() throws {
        let catalog = WorldAssetCatalog()
        let manifest = try XCTUnwrap(catalog.generatedManifest)
        let details: [CameraDetailLevel] = [.block, .neighborhood, .city, .neighborhood, .block]
        var firstCycleHighWater = 0

        for cycle in 0..<3 {
            for detail in details {
                for asset in manifest.assets {
                    XCTAssertNotNil(catalog.generatedSprite(logicalID: asset.logicalID, detail: detail))
                }
                for mask in UInt8(0)..<16 {
                    XCTAssertNotNil(catalog.generatedRoadSprite(connectionMask: mask, detail: detail))
                }
                let snapshot = catalog.residencySnapshot()
                XCTAssertEqual(snapshot.activeDetail, detail)
                XCTAssertLessThanOrEqual(snapshot.residentDecodedBytes, 96 * 1_024 * 1_024)
                XCTAssertLessThanOrEqual(snapshot.highWaterDecodedBytes, 96 * 1_024 * 1_024)
                XCTAssertEqual(snapshot.fallbackCount, 0)
            }
            if cycle == 0 {
                firstCycleHighWater = catalog.residencySnapshot().highWaterDecodedBytes
            } else {
                XCTAssertEqual(catalog.residencySnapshot().highWaterDecodedBytes, firstCycleHighWater)
            }
        }
        let final = catalog.residencySnapshot()
        XCTAssertGreaterThan(final.evictions, 0)
        print(
            "PLAY022_M3_RESIDENCY active=\(final.activeDetail?.assetSuffix ?? "none") " +
            "resident_textures=\(final.residentTextureCount) resident_bytes=\(final.residentDecodedBytes) " +
            "high_water_bytes=\(final.highWaterDecodedBytes) hits=\(final.cacheHits) " +
            "misses=\(final.cacheMisses) evictions=\(final.evictions) fallbacks=\(final.fallbackCount)"
        )
    }

    @MainActor
    func testAuthoredRoadAtlasCoversEveryMaskAndFrontagesFaceConnectedRoads() {
        let catalog = WorldAssetCatalog()
        let style = WorldVisualStyle()
        let roads = RoadRenderer(style: style, assets: catalog)

        for mask in RoadConnectionMask.allMasks {
            let assetName = String(format: "generated_v4_road_mask_%02d_block", mask.rawValue)
            XCTAssertNotNil(catalog.texture(named: assetName))
            let root = roads.makeRoad(
                at: GridCoordinate(x: 4, y: 4),
                connections: mask,
                detail: .block,
                reducedMotion: true
            )
            let names = descendantNames(in: root)
            XCTAssertTrue(names.contains("road.production-corridor.developed.\(mask.rawValue)"))
            if mask.connectionCount == 1 {
                XCTAssertTrue(names.contains("road.terminus.turning-bulb"))
                XCTAssertTrue(names.contains("road.terminus.center-mark"))
            }
        }

        let coordinate = GridCoordinate(x: 4, y: 4)
        for edge in RoadConnectionMask.cardinalEdges {
            let delta = edge.coordinateDelta
            let neighbor = GridCoordinate(x: coordinate.x + delta.x, y: coordinate.y + delta.y)
            let coordinatePosition = style.isoPosition(coordinate)
            let neighborPosition = style.isoPosition(neighbor)
            let outgoingSocket = style.roadSocket(for: edge)
            let incomingSocket = style.roadSocket(for: edge.opposite)
            XCTAssertEqual(
                coordinatePosition.x + outgoingSocket.x,
                neighborPosition.x + incomingSocket.x,
                accuracy: 0.001
            )
            XCTAssertEqual(
                coordinatePosition.y + outgoingSocket.y,
                neighborPosition.y + incomingSocket.y,
                accuracy: 0.001
            )
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
    func testRemoteRoadOpportunityRecedesWithoutChangingTopologyOrHitGeometry() {
        let state = CityGameState.newCity(seed: 42)
        let renderer = RoadRenderer(style: WorldVisualStyle())
        let frontage = renderer.makeRoad(
            at: GridCoordinate(x: 12, y: 12),
            in: state,
            detail: .block,
            reducedMotion: true
        )
        let frontierCoordinate = GridCoordinate(x: 4, y: 12)
        let frontier = renderer.makeRoad(
            at: frontierCoordinate,
            in: state,
            detail: .block,
            reducedMotion: true
        )

        XCTAssertEqual(frontage.alpha, 1, accuracy: 0.001)
        XCTAssertEqual(frontier.alpha, 1, accuracy: 0.001)
        XCTAssertEqual(
            frontage.childNode(withName: CameraDetailLevel.neighborhood.layerName)?.alpha ?? -1,
            1,
            accuracy: 0.001
        )
        XCTAssertEqual(
            frontier.childNode(withName: CameraDetailLevel.neighborhood.layerName)?.alpha ?? -1,
            0,
            accuracy: 0.001
        )
        XCTAssertTrue(descendantNames(in: frontage).contains("road.production-corridor.developed.15"))
        XCTAssertTrue(descendantNames(in: frontier).contains("road.production-corridor.opportunity.2"))

        guard let roadTile = state.tile(at: frontierCoordinate) else {
            return XCTFail("Expected authoritative frontier road tile")
        }
        let terrain = TerrainRenderer(style: WorldVisualStyle()).makeGround(
            for: roadTile,
            detail: .block
        )
        XCTAssertFalse(descendantNames(in: terrain).contains("terrain.hit-surface"))
    }

    @MainActor
    func testProductionCorridorExportsAllTopologySeamMosaicAcrossSemanticLODs() throws {
        let size = CGSize(width: 1_200, height: 340)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = SKScene(size: size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = NSColor(calibratedRed: 0.04, green: 0.075, blue: 0.08, alpha: 1)
        view.presentScene(scene)

        let style = WorldVisualStyle()
        let renderer = RoadRenderer(style: style)
        for (detailIndex, detail) in CameraDetailLevel.allCases.enumerated() {
            let panelX = CGFloat(detailIndex) * 390 + 45
            let title = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
            title.text = detail.assetSuffix.uppercased()
            title.fontSize = 14
            title.fontColor = .white
            title.horizontalAlignmentMode = .left
            title.position = CGPoint(x: panelX, y: 315)
            scene.addChild(title)

            for maskValue in 0..<16 {
                let column = maskValue % 4
                let row = maskValue / 4
                let center = CGPoint(
                    x: panelX + CGFloat(column) * 88 + 38,
                    y: 265 - CGFloat(row) * 65
                )
                let parcel = SKShapeNode(path: style.diamondPath())
                parcel.fillColor = NSColor(calibratedRed: 0.22, green: 0.39, blue: 0.24, alpha: 1)
                parcel.strokeColor = .clear
                parcel.position = center
                scene.addChild(parcel)

                let coordinate = GridCoordinate(x: column, y: row)
                let road = renderer.makeRoad(
                    at: coordinate,
                    connections: RoadConnectionMask(rawValue: UInt8(maskValue)),
                    detail: detail,
                    reducedMotion: true
                )
                // CityScene places this node below a tile root whose depth exactly
                // cancels the renderer's network-level z adjustment. Restore that
                // parent depth in this isolated topology proof.
                road.zPosition += style.depth(for: coordinate)
                road.position = center
                road.setScale(1.08)
                scene.addChild(road)
                let names = descendantNames(in: road)
                XCTAssertTrue(names.contains("road.production-corridor.developed.\(maskValue)"))
                XCTAssertFalse(names.contains { $0.hasPrefix("road.generated-v4") })
            }
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        let texture = try XCTUnwrap(view.texture(from: scene))
        let representation = NSBitmapImageRep(cgImage: texture.cgImage())
        let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        try export(png, environmentKey: "CITYSIM_PLAY022_ROAD_SEAM_MOSAIC")
        XCTAssertEqual(recursiveActiveActionCount(scene), 0)
    }

    @MainActor
    func testRoundOneShippingStartExportsDevelopedBoundsDefaultAndCompact() throws {
        let state = CityGameState.newCity(seed: 42)
        for (size, insets, environmentKey) in [
            (
                CGSize(width: 1_280, height: 800),
                CityMapViewportInsets(top: 104, leading: 24, bottom: 160, trailing: 24),
                "CITYSIM_PLAY022_M2_DEFAULT"
            ),
            (
                CGSize(width: 900, height: 600),
                CityMapViewportInsets(top: 138, leading: 19, bottom: 236, trailing: 19),
                "CITYSIM_PLAY022_M2_COMPACT"
            ),
        ] {
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            let scene = CityScene(size: size)
            scene.reducedMotion = true
            view.presentScene(scene)
            scene.updateViewportInsets(insets)
            scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
            let occupied = scene.occupiedDevelopedViewportOccupancyForTesting()
            let network = scene.networkOpportunityViewportOccupancyForTesting()
            if size.width <= 900 {
                XCTAssertGreaterThanOrEqual(occupied.width, 0.52)
                XCTAssertLessThanOrEqual(occupied.width, 0.58)
            } else {
                XCTAssertGreaterThanOrEqual(occupied.width, 0.60)
                XCTAssertLessThanOrEqual(occupied.width, 0.68)
            }
            XCTAssertGreaterThan(max(network.width, network.height), max(occupied.width, occupied.height))
            XCTAssertNotEqual(
                scene.occupiedDevelopedVisualBoundsForTesting,
                scene.networkOpportunityVisualBoundsForTesting
            )
            XCTAssertLessThanOrEqual(scene.diagnosticsSnapshot.nodeCount, 4_000)
            XCTAssertLessThanOrEqual(scene.diagnosticsSnapshot.drawableNodeCount, 1_500)
            XCTAssertEqual(scene.diagnosticsSnapshot.activeActionCount, 0)
            let texture = try XCTUnwrap(view.texture(from: scene))
            let representation = NSBitmapImageRep(cgImage: texture.cgImage())
            let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
            try export(png, environmentKey: environmentKey)
            print(
                "PLAY022_M2_FRAME size=\(Int(size.width))x\(Int(size.height)) " +
                "scale=\(scene.cameraScaleForTesting) detail=\(scene.currentCameraDetailLevel) " +
                "occupied=\(occupied.width),\(occupied.height) " +
                "network=\(network.width),\(network.height) " +
                "nodes=\(scene.diagnosticsSnapshot.nodeCount) drawables=\(scene.diagnosticsSnapshot.drawableNodeCount)"
            )
        }
    }

    @MainActor
    func testCompletedVisibleSetUsesGeneratedV4AcrossKindsAndLevelsWithoutLegacyFallback() {
        let catalog = WorldAssetCatalog()
        let renderer = LotRenderer(style: WorldVisualStyle(), assets: catalog)
        let visibleSet: [(BuildingKind, String)] = [
            (.residential, "residential_l01"),
            (.commercial, "commercial_l01"),
            (.industrial, "industrial_l01"),
            (.park, "park_l01"),
            (.powerPlant, "industrial_l01"),
            (.waterTower, "water_tower_l01"),
            (.fireStation, "commercial_l01"),
            (.policeStation, "city_hall_l01"),
            (.school, "residential_l01"),
            (.cityHall, "city_hall_l01"),
        ]

        for (index, entry) in visibleSet.enumerated() {
            let (kind, generatedID) = entry
            for tier in 1...3 {
                let tile = CityTile(
                    coordinate: GridCoordinate(x: index + 2, y: tier + 3),
                    kind: kind,
                    level: tier,
                    condition: 1,
                    constructionProgress: 1
                )
                let first = renderer.makeLot(
                    for: tile,
                    adjacentRoads: .south,
                    detail: .block,
                    reducedMotion: true
                )
                let second = renderer.makeLot(
                    for: tile,
                    adjacentRoads: .south,
                    detail: .block,
                    reducedMotion: true
                )
                let expectedName = "lot.generated-v4.\(generatedID).block"
                for root in [first, second] {
                    let names = descendantNames(in: root)
                    XCTAssertEqual(names.filter { $0 == expectedName }.count, 1)
                    XCTAssertFalse(names.contains { $0.hasPrefix("lot.place.") })
                    XCTAssertFalse(names.contains { $0.hasPrefix("lot.strategyGround.") })
                    XCTAssertFalse(names.contains { $0.contains(".banner") || $0.contains(".windsock") })
                    XCTAssertTrue(descendantLabels(in: root).isEmpty)
                }
            }
        }

        let powerPlant = CityTile(
            coordinate: GridCoordinate(x: 15, y: 9),
            kind: .powerPlant,
            constructionProgress: 1
        )
        let powerPlantNames = descendantNames(in: renderer.makeLot(
            for: powerPlant,
            adjacentRoads: .south,
            detail: .block,
            reducedMotion: true
        ))
        XCTAssertTrue(powerPlantNames.contains("lot.generated-v4.industrial_l01.block"))
        XCTAssertTrue(powerPlantNames.contains("lot.generated-role.powerPlant"))
    }

    func testStrategyDistrictIdentityIsStableClampedAndTruthLimited() {
        let coordinate = GridCoordinate(x: 14, y: 9)
        let low = StrategyDistrictVisualIdentity(tile: CityTile(
            coordinate: coordinate,
            kind: .commercial,
            level: 0
        ))
        let repeated = StrategyDistrictVisualIdentity(tile: CityTile(
            coordinate: coordinate,
            kind: .commercial,
            level: 1,
            occupancy: 999,
            condition: 0.1
        ))
        XCTAssertEqual(low, repeated)
        XCTAssertEqual(low?.densityTier, 1)
        XCTAssertEqual(low?.architecturalCue, "main-street shop row")

        let high = StrategyDistrictVisualIdentity(tile: CityTile(
            coordinate: coordinate,
            kind: .industrial,
            level: 99
        ))
        XCTAssertEqual(high?.densityTier, 3)
        XCTAssertEqual(high?.architecturalCue, "process campus and pipe gantries")
        XCTAssertNil(StrategyDistrictVisualIdentity(tile: CityTile(
            coordinate: coordinate,
            kind: .residential
        )))
    }

    @MainActor
    func testCorridorAmbientLifeHasOneSemanticSetAndIsReduceMotionSafe() {
        let renderer = AmbientLifeRenderer(style: WorldVisualStyle(), assets: WorldAssetCatalog())
        let state = CityGameState.newCity(seed: 42)
        let animated = renderer.makeCorridorLife(
            in: state,
            detail: .block,
            reducedMotion: false
        )
        let reduced = renderer.makeCorridorLife(
            in: state,
            detail: .block,
            reducedMotion: true
        )

        let semanticSet = [
            "world.ambient.pedestrian-pair",
            "world.ambient.parked-service-object",
            "world.ambient.vegetation-cluster",
        ]
        let animatedNames = descendantNames(in: animated)
        let reducedNames = descendantNames(in: reduced)
        for name in semanticSet {
            XCTAssertEqual(animatedNames.filter { $0 == name }.count, 1)
            XCTAssertEqual(reducedNames.filter { $0 == name }.count, 1)
        }
        XCTAssertFalse(animatedNames.contains { $0.hasPrefix("lot.ambient.") })
        XCTAssertFalse(animatedNames.contains { $0.contains(".banner") || $0.contains(".windsock") })
        XCTAssertLessThanOrEqual(recursiveActiveActionCount(animated), 1)
        let pedestrian = animated.childNode(withName: "//world.ambient.pedestrian-pair")
        let stroll = pedestrian?.action(forKey: "ambient.corridor.walk")
        XCTAssertNotNil(stroll)
        XCTAssertGreaterThanOrEqual(stroll?.duration ?? 0, 14.4)
        XCTAssertLessThanOrEqual(stroll?.duration ?? .infinity, 15.2)
        XCTAssertEqual(recursiveActiveActionCount(reduced), 0)
        XCTAssertTrue(descendantLabels(in: animated).isEmpty)
        XCTAssertTrue(descendantLabels(in: reduced).isEmpty)
    }

    @MainActor
    func testCompactSceneKeepsAmbientMeaningWithoutMotionResidency() {
        let state = CityGameState.newCity(seed: 42)
        let regular = CityScene(size: CGSize(width: 1_280, height: 800))
        regular.reducedMotion = false
        regular.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertTrue(regular.ambientMotionEnabledForTesting)
        XCTAssertEqual(regular.ambientActionCountForTesting, 1)

        let compact = CityScene(size: CGSize(width: 900, height: 600))
        compact.reducedMotion = false
        compact.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertFalse(compact.ambientMotionEnabledForTesting)
        XCTAssertEqual(compact.ambientActionCountForTesting, 0)

        regular.resize(to: CGSize(width: 900, height: 600))
        XCTAssertFalse(regular.ambientMotionEnabledForTesting)
        XCTAssertEqual(regular.ambientActionCountForTesting, 0)
    }

    @MainActor
    func testMacroTerrainReplacesTheRepeatedCellPlateAndKeepsEmptyLotsInteractive() {
        let renderer = TerrainRenderer(style: WorldVisualStyle())
        let vacant = renderer.makeGround(
            for: CityTile(coordinate: GridCoordinate(x: 4, y: 7), kind: .empty),
            detail: .block
        )
        let names = descendantNames(in: vacant)
        XCTAssertFalse(names.contains("terrain.hit-surface"))
        XCTAssertFalse(names.contains { $0.contains("generated-v4.grass") })
        XCTAssertFalse(names.contains("terrain.vacant.grove"))
        XCTAssertEqual(recursiveActiveActionCount(vacant), 0)

        let state = CityGameState.newCity(seed: 42)
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        for coordinate in [GridCoordinate(x: 0, y: 0), GridCoordinate(x: 4, y: 12), GridCoordinate(x: 20, y: 20)] {
            XCTAssertEqual(
                scene.resolvedCoordinateForTesting(at: scene.scenePointForTesting(at: coordinate)),
                coordinate
            )
        }

        let backdrop = renderer.makeBackdrop(gridWidth: 24, gridHeight: 24)
        let backdropNames = descendantNames(in: backdrop)
        XCTAssertTrue(backdropNames.contains("terrain.macro.turf"))
        XCTAssertEqual(backdropNames.filter { $0.hasPrefix("terrain.macro.patch.") }.count, 9)
        XCTAssertEqual(recursiveActiveActionCount(backdrop), 0)
    }

    @MainActor
    func testStartingCameraFramesTheDevelopedCoreAtDefaultAndCompactLODs() {
        let state = CityGameState.newCity(seed: 42)
        let defaultInsets = CityMapViewportInsets(top: 104, leading: 24, bottom: 160, trailing: 24)
        let defaultScene = CityScene(size: CGSize(width: 1_280, height: 800))
        defaultScene.reducedMotion = true
        defaultScene.updateViewportInsets(defaultInsets)
        defaultScene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(defaultScene.currentCameraDetailLevel, .block)
        let defaultOccupancy = defaultScene.occupiedDevelopedViewportOccupancyForTesting()
        XCTAssertGreaterThanOrEqual(defaultOccupancy.width, 0.60)
        XCTAssertLessThanOrEqual(defaultOccupancy.width, 0.68)
        XCTAssertEqual(defaultScene.occupiedDevelopedVisualBoundsForTesting.width, 288, accuracy: 0.001)
        XCTAssertEqual(defaultScene.occupiedDevelopedVisualBoundsForTesting.height, 170.7188, accuracy: 0.001)
        XCTAssertEqual(defaultScene.networkOpportunityVisualBoundsForTesting.width, 684, accuracy: 0.001)
        XCTAssertEqual(defaultScene.networkOpportunityVisualBoundsForTesting.height, 342, accuracy: 0.001)

        let compactInsets = CityMapViewportInsets(top: 138, leading: 19, bottom: 236, trailing: 19)
        let compactScene = CityScene(size: CGSize(width: 900, height: 600))
        compactScene.reducedMotion = true
        compactScene.updateViewportInsets(compactInsets)
        compactScene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(compactScene.currentCameraDetailLevel, .neighborhood)
        let compactOccupancy = compactScene.occupiedDevelopedViewportOccupancyForTesting()
        XCTAssertGreaterThanOrEqual(compactOccupancy.width, 0.52)
        XCTAssertLessThanOrEqual(compactOccupancy.width, 0.58)

        let defaultOffset = CGPoint(
            x: (defaultInsets.leading - defaultInsets.trailing) * defaultScene.cameraScaleForTesting / 2,
            y: (defaultInsets.bottom - defaultInsets.top) * defaultScene.cameraScaleForTesting / 2
        )
        XCTAssertEqual(
            defaultScene.cameraPositionForTesting.x,
            defaultScene.occupiedDevelopedVisualBoundsForTesting.midX - defaultOffset.x,
            accuracy: 0.001
        )
        XCTAssertEqual(
            defaultScene.cameraPositionForTesting.y,
            defaultScene.occupiedDevelopedVisualBoundsForTesting.midY - defaultOffset.y,
            accuracy: 0.001
        )
        XCTAssertGreaterThan(
            max(
                defaultScene.networkOpportunityViewportOccupancyForTesting().width,
                defaultScene.networkOpportunityViewportOccupancyForTesting().height
            ),
            max(defaultOccupancy.width, defaultOccupancy.height)
        )
        let cityHall = GridCoordinate(x: 11, y: 11)
        let defaultCityHallRoot = defaultScene.tileRootIdentifier(at: cityHall)
        XCTAssertTrue(defaultScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.block"))

        defaultScene.configureProofCamera(detail: .city, centeredOn: cityHall)
        let defaultCityScale = defaultScene.cameraScaleForTesting
        XCTAssertEqual(defaultScene.currentCameraDetailLevel, .city)
        XCTAssertGreaterThanOrEqual(defaultScene.occupiedDevelopedViewportOccupancyForTesting().width, 0.47)
        XCTAssertTrue(defaultScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.city"))
        XCTAssertFalse(defaultScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.block"))
        XCTAssertEqual(defaultScene.resolvedCoordinateForTesting(at: defaultScene.scenePointForTesting(at: cityHall)), cityHall)
        XCTAssertEqual(defaultScene.tileRootIdentifier(at: cityHall), defaultCityHallRoot)

        defaultScene.configureProofCamera(detail: .neighborhood, centeredOn: cityHall)
        let defaultNeighborhoodScale = defaultScene.cameraScaleForTesting
        XCTAssertEqual(defaultScene.currentCameraDetailLevel, .neighborhood)
        XCTAssertLessThan(defaultNeighborhoodScale, defaultCityScale)
        XCTAssertTrue(defaultScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.neighborhood"))
        XCTAssertEqual(defaultScene.resolvedCoordinateForTesting(at: defaultScene.scenePointForTesting(at: cityHall)), cityHall)
        XCTAssertEqual(defaultScene.tileRootIdentifier(at: cityHall), defaultCityHallRoot)

        defaultScene.configureProofCamera(detail: .block, centeredOn: cityHall)
        XCTAssertEqual(defaultScene.currentCameraDetailLevel, .block)
        XCTAssertLessThan(defaultScene.cameraScaleForTesting, defaultNeighborhoodScale)
        XCTAssertTrue(defaultScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.block"))
        XCTAssertEqual(defaultScene.resolvedCoordinateForTesting(at: defaultScene.scenePointForTesting(at: cityHall)), cityHall)
        XCTAssertEqual(defaultScene.tileRootIdentifier(at: cityHall), defaultCityHallRoot)

        let compactCityHallRoot = compactScene.tileRootIdentifier(at: cityHall)
        compactScene.configureProofCamera(detail: .city, centeredOn: cityHall)
        XCTAssertEqual(compactScene.currentCameraDetailLevel, .city)
        XCTAssertGreaterThanOrEqual(compactScene.occupiedDevelopedViewportOccupancyForTesting().width, 0.47)
        XCTAssertTrue(compactScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.city"))
        XCTAssertEqual(compactScene.resolvedCoordinateForTesting(at: compactScene.scenePointForTesting(at: cityHall)), cityHall)
        XCTAssertEqual(compactScene.tileRootIdentifier(at: cityHall), compactCityHallRoot)

        compactScene.configureProofCamera(detail: .neighborhood, centeredOn: cityHall)
        XCTAssertEqual(compactScene.currentCameraDetailLevel, .neighborhood)
        XCTAssertTrue(compactScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.neighborhood"))
        XCTAssertEqual(compactScene.tileRootIdentifier(at: cityHall), compactCityHallRoot)

        compactScene.configureProofCamera(detail: .block, centeredOn: cityHall)
        XCTAssertEqual(compactScene.currentCameraDetailLevel, .block)
        XCTAssertTrue(compactScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.block"))
        XCTAssertEqual(compactScene.resolvedCoordinateForTesting(at: compactScene.scenePointForTesting(at: cityHall)), cityHall)
        XCTAssertEqual(compactScene.tileRootIdentifier(at: cityHall), compactCityHallRoot)

        defaultScene.configureProofCamera(detail: .city, centeredOn: GridCoordinate(x: 0, y: 0))
        defaultScene.frameCity()
        XCTAssertEqual(defaultScene.currentCameraDetailLevel, .block)
        XCTAssertEqual(
            defaultScene.cameraPositionForTesting.x,
            defaultScene.occupiedDevelopedVisualBoundsForTesting.midX - defaultOffset.x,
            accuracy: 0.001
        )
        XCTAssertEqual(
            defaultScene.cameraPositionForTesting.y,
            defaultScene.occupiedDevelopedVisualBoundsForTesting.midY - defaultOffset.y,
            accuracy: 0.001
        )
    }

    @MainActor
    func testDevelopedMassCameraIgnoresRemoteOpportunityAndNumericOccupancy() {
        let size = CGSize(width: 1_280, height: 800)
        let insets = CityMapViewportInsets(top: 104, leading: 24, bottom: 160, trailing: 24)
        func metrics(for state: CityGameState) -> (occupied: CGRect, network: CGRect, scale: CGFloat, position: CGPoint) {
            let scene = CityScene(size: size)
            scene.reducedMotion = true
            scene.updateViewportInsets(insets)
            scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
            return (
                scene.occupiedDevelopedVisualBoundsForTesting,
                scene.networkOpportunityVisualBoundsForTesting,
                scene.cameraScaleForTesting,
                scene.cameraPositionForTesting
            )
        }

        let start = CityGameState.newCity(seed: 42)
        let baseline = metrics(for: start)

        var remoteOpportunity = start
        remoteOpportunity.updateTile(at: GridCoordinate(x: 0, y: 0)) { $0.kind = .road }
        let opportunity = metrics(for: remoteOpportunity)
        XCTAssertEqual(opportunity.occupied, baseline.occupied)
        XCTAssertNotEqual(opportunity.network, baseline.network)
        XCTAssertEqual(opportunity.scale, baseline.scale, accuracy: 0.001)
        XCTAssertEqual(opportunity.position.x, baseline.position.x, accuracy: 0.001)
        XCTAssertEqual(opportunity.position.y, baseline.position.y, accuracy: 0.001)

        var numericOccupancy = start
        numericOccupancy.updateTile(at: GridCoordinate(x: 10, y: 11)) { $0.occupancy = 9_999 }
        let numeric = metrics(for: numericOccupancy)
        XCTAssertEqual(numeric.occupied, baseline.occupied)
        XCTAssertEqual(numeric.scale, baseline.scale, accuracy: 0.001)
        XCTAssertEqual(numeric.position.x, baseline.position.x, accuracy: 0.001)
        XCTAssertEqual(numeric.position.y, baseline.position.y, accuracy: 0.001)

        var realDevelopment = start
        realDevelopment.updateTile(at: GridCoordinate(x: 8, y: 11)) { $0.kind = .residential }
        let developed = metrics(for: realDevelopment)
        XCTAssertNotEqual(developed.occupied, baseline.occupied)
        XCTAssertNotEqual(developed.scale, baseline.scale)
        XCTAssertNotEqual(developed.position, baseline.position)
    }

    @MainActor
    func testRejectedGoldenDistrictReferenceRetainsExplicitLODAssets() throws {
        let renderer = GoldenDistrictRenderer(style: WorldVisualStyle())
        XCTAssertTrue(renderer.canPresent(state: CityGameState.newCity(seed: 42)))

        for (detail, expectedAsset) in [
            (CameraDetailLevel.city, "world.goldenDistrict.asset.city"),
            (.neighborhood, "world.goldenDistrict.asset.neighborhood"),
            (.block, "world.goldenDistrict.asset.block")
        ] {
            let animated = try XCTUnwrap(renderer.makeDistrict(detail: detail, reducedMotion: false))
            let reduced = try XCTUnwrap(renderer.makeDistrict(detail: detail, reducedMotion: true))
            XCTAssertTrue(descendantNames(in: animated).contains(expectedAsset))
            XCTAssertEqual(recursiveActiveActionCount(animated), 1)
            XCTAssertEqual(recursiveActiveActionCount(reduced), 0)
        }
    }

    @MainActor
    func testShippingSceneNeverPresentsRejectedGoldenDistrictPlate() {
        var changed = CityGameState.newCity(seed: 42)
        changed.updateTile(at: GridCoordinate(x: 10, y: 11)) { $0.condition = 0.45 }
        XCTAssertFalse(GoldenDistrictRenderer(style: WorldVisualStyle()).canPresent(state: changed))

        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        let start = CityGameState.newCity(seed: 42)
        scene.render(state: start, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertFalse(descendantNames(in: scene).contains("world.goldenDistrict.asset.block"))
        XCTAssertEqual(scene.tileRootIsHiddenForTesting(at: GridCoordinate(x: 10, y: 11)), false)
        XCTAssertEqual(scene.tileRootIsHiddenForTesting(at: GridCoordinate(x: 4, y: 12)), false)

        scene.render(state: start, overlay: .utilities, selection: nil, interactionMode: .inspect)
        XCTAssertFalse(descendantNames(in: scene).contains("world.goldenDistrict.asset.block"))
        XCTAssertEqual(scene.tileRootIsHiddenForTesting(at: GridCoordinate(x: 10, y: 11)), false)

        scene.render(state: start, overlay: .none, selection: nil, interactionMode: .build(.residential))
        XCTAssertFalse(descendantNames(in: scene).contains("world.goldenDistrict.asset.block"))

        scene.render(state: changed, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertFalse(descendantNames(in: scene).contains("world.goldenDistrict.asset.block"))
    }

    @MainActor
    func testInteractionPriorityUsesGroundedBoundariesWithoutBillboardClutter() throws {
        let state = CityGameState.newCity(seed: 42)
        let validCoordinate = try XCTUnwrap(state.tiles.first { tile in
            if case .success = CitySimulation.validateBuild(.residential, at: tile.coordinate, in: state) {
                return true
            }
            return false
        }?.coordinate)
        let invalidCoordinate = GridCoordinate(x: 11, y: 11)
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.reducedMotion = true

        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .build(.residential))
        scene.configureProofInteraction(at: validCoordinate)
        var names = scene.interactionNamesForTesting
        XCTAssertFalse(scene.hoverIsHiddenForTesting)
        XCTAssertEqual(names.filter { $0 == "interaction.placementGhost" }.count, 1)
        XCTAssertFalse(names.contains("interaction.invalidHatch"))
        XCTAssertFalse(names.contains { $0.hasPrefix("interaction.preview.") })
        XCTAssertTrue(descendantLabels(in: scene).isEmpty)

        scene.configureProofInteraction(at: invalidCoordinate)
        names = scene.interactionNamesForTesting
        XCTAssertFalse(scene.hoverIsHiddenForTesting)
        XCTAssertEqual(names.filter { $0 == "interaction.placementGhost" }.count, 1)
        XCTAssertEqual(names.filter { $0 == "interaction.invalidHatch" }.count, 3)
        XCTAssertFalse(names.contains { $0.hasPrefix("interaction.preview.") })
        XCTAssertTrue(descendantLabels(in: scene).isEmpty)

        scene.render(
            state: state,
            overlay: .none,
            selection: invalidCoordinate,
            interactionMode: .inspect
        )
        scene.configureProofInteraction(at: invalidCoordinate)
        names = scene.interactionNamesForTesting
        XCTAssertTrue(scene.hoverIsHiddenForTesting)
        XCTAssertFalse(scene.selectionIsHiddenForTesting)
        XCTAssertEqual(names.filter { $0 == "interaction.selection" }.count, 1)
        XCTAssertEqual(names.filter { $0 == "interaction.selection.frontage-anchor" }.count, 1)
        XCTAssertFalse(names.contains { $0.hasPrefix("interaction.preview.") })
        XCTAssertTrue(descendantLabels(in: scene).isEmpty)
    }

    @MainActor
    func testExactCompactActiveCoordinateRemainsInsideSafeWorldViewport() {
        let state = CityGameState.newCity(seed: 42)
        let active = GridCoordinate(x: 23, y: 23)
        let insets = CityMapViewportInsets(top: 76, leading: 278, bottom: 64, trailing: 12)
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.reducedMotion = true
        scene.updateViewportInsets(insets)
        scene.render(state: state, overlay: .none, selection: active, interactionMode: .inspect)

        XCTAssertTrue(scene.safeViewportRectForTesting(insets).contains(scene.scenePointForTesting(at: active)))
        XCTAssertFalse(scene.selectionIsHiddenForTesting)
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
        XCTAssertFalse(recoveredNames.contains("lot.lifecycle.condition.maintained"))
        XCTAssertTrue(recoveredNames.contains("lot.lifecycle.growth.tier.2"))
        XCTAssertTrue(recoveredNames.contains("lot.growth.freshFacade"))
        XCTAssertTrue(recoveredNames.contains("lot.growth.entrance-canopy"))
        XCTAssertFalse(recoveredNames.contains("lot.growth.badge"))
        XCTAssertFalse(recoveredNames.contains { $0.contains("pennant") || $0.contains("chevron") })
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
            let animatedNames = descendantNames(in: animated)
            let staticNames = descendantNames(in: staticFallback)
            XCTAssertTrue(animatedNames.contains(expectedName))
            XCTAssertTrue(staticNames.contains(expectedName))
            XCTAssertFalse(animatedNames.contains { $0.hasPrefix("lot.construction.progress") })
            XCTAssertFalse(staticNames.contains { $0.hasPrefix("lot.construction.progress") })
            let expectedActions = progress >= 0.50 ? 1 : 0
            XCTAssertEqual(recursiveActiveActionCount(animated), expectedActions)
            XCTAssertEqual(recursiveActiveActionCount(staticFallback), 0)
            XCTAssertTrue(descendantLabels(in: animated).isEmpty)
            XCTAssertTrue(descendantLabels(in: staticFallback).isEmpty)
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
        let growthNames = descendantNames(in: growthRoot)
        XCTAssertTrue(growthNames.contains("lot.lifecycle.growth.tier.3"))
        XCTAssertTrue(growthNames.contains("lot.growth.entrance-canopy"))
        XCTAssertFalse(growthNames.contains { $0.contains("pennant") || $0.contains("chevron") })
        XCTAssertEqual(recursiveActiveActionCount(growthRoot), 0)
        XCTAssertTrue(descendantLabels(in: growthRoot).isEmpty)

        var stressed = healthyGrowth
        stressed.condition = 0.58
        let stressedRoot = renderer.makeLot(for: stressed, detail: .block, reducedMotion: false)
        let stressedNames = descendantNames(in: stressedRoot)
        XCTAssertTrue(stressedNames.contains("lot.lifecycle.condition.weathered"))
        XCTAssertFalse(stressedNames.contains("lot.condition.patchwork"))
        XCTAssertFalse(stressedNames.contains("lot.lifecycle.motion.cautionRibbon"))
        XCTAssertFalse(stressedNames.contains("lot.lifecycle.growth.tier.3"))
        XCTAssertEqual(recursiveActiveActionCount(stressedRoot), 0)
        XCTAssertTrue(descendantLabels(in: stressedRoot).isEmpty)

        let park = CityTile(
            coordinate: GridCoordinate(x: 8, y: 9),
            kind: .park,
            constructionProgress: 1
        )
        let ambient = renderer.makeLot(for: park, detail: .neighborhood, reducedMotion: false)
        let staticAmbient = renderer.makeLot(for: park, detail: .neighborhood, reducedMotion: true)
        XCTAssertFalse(descendantNames(in: ambient).contains { $0.hasPrefix("lot.ambient.") })
        XCTAssertEqual(recursiveActiveActionCount(ambient), 0)
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
        let averageMilliseconds = elapsedMilliseconds / Double(pulseCount)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)
        XCTAssertEqual(scene.tileRootIdentifier(at: developed), initialRoot)
        XCTAssertEqual(scene.diagnosticsSnapshot.nodeCount, initialNodes)
        XCTAssertEqual(scene.diagnosticsSnapshot.drawableNodeCount, initialDrawables)
        XCTAssertEqual(scene.diagnosticsSnapshot.activeActionCount, initialActions)
        XCTAssertLessThanOrEqual(
            averageMilliseconds,
            2.1,
            "Unchanged-pulse renderer telemetry must remain within the established 2.1 ms budget"
        )
        print(
            "CITYSIM_PLAY021_SOAK_DIAGNOSTICS " +
            "equivalent_minutes=30 pulses=\(pulseCount) " +
            "nodes=\(initialNodes) drawables=\(initialDrawables) actions=\(initialActions) " +
            "total_ms=\(String(format: "%.3f", elapsedMilliseconds)) " +
            "average_ms=\(String(format: "%.4f", averageMilliseconds))"
        )
    }

    @MainActor
    func testRendererDiagnosticsSeparateWorldUpdateTotalRenderAndAssetDecode() throws {
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        let snapshot = try CityPresentationSnapshot(state: goldenNeighborhoodState())

        scene.render(
            snapshot: snapshot,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let cold = scene.diagnosticsSnapshot
        XCTAssertEqual(cold.updateDurationMilliseconds, cold.worldUpdateDurationMilliseconds)
        XCTAssertGreaterThan(cold.worldUpdateDurationMilliseconds, 0)
        XCTAssertGreaterThanOrEqual(cold.totalRenderDurationMilliseconds, cold.worldUpdateDurationMilliseconds)
        XCTAssertGreaterThanOrEqual(
            cold.totalRenderDurationMilliseconds,
            cold.assetDecodeLoadDurationMilliseconds
        )
        scene.render(
            snapshot: snapshot,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let unchanged = scene.diagnosticsSnapshot
        XCTAssertEqual(unchanged.worldUpdateDurationMilliseconds, 0)
        XCTAssertGreaterThan(unchanged.totalRenderDurationMilliseconds, 0)
        XCTAssertEqual(unchanged.assetDecodeLoadCount, 0)
        XCTAssertEqual(unchanged.assetDecodeLoadDurationMilliseconds, 0, accuracy: 0.000_001)
        print(
            "PLAY022_ROUND1B_COLD_RENDER " +
            "world_update_ms=\(String(format: "%.3f", cold.worldUpdateDurationMilliseconds)) " +
            "asset_decode_loads=\(cold.assetDecodeLoadCount) " +
            "asset_decode_ms=\(String(format: "%.3f", cold.assetDecodeLoadDurationMilliseconds)) " +
            "total_render_ms=\(String(format: "%.3f", cold.totalRenderDurationMilliseconds))"
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
        XCTAssertLessThanOrEqual(
            block.diagnostics.worldUpdateDurationMilliseconds,
            6.03,
            "The exact historical golden-fixture method must remain within the accepted cold-update gate"
        )
        try export(city.png, environmentKey: "CITYSIM_PLAY021_GOLDEN_CITY_PROOF")
        try export(neighborhood.png, environmentKey: "CITYSIM_PLAY021_GOLDEN_NEIGHBORHOOD_PROOF")
        try export(block.png, environmentKey: "CITYSIM_PLAY021_GOLDEN_BLOCK_PROOF")
        try export(compact.png, environmentKey: "CITYSIM_PLAY021_GOLDEN_COMPACT_PROOF")
        print(
            "CITYSIM_PLAY021_GOLDEN_DIAGNOSTICS " +
            "nodes=\(block.diagnostics.nodeCount) drawables=\(block.diagnostics.drawableNodeCount) " +
            "actions=\(block.diagnostics.activeActionCount) " +
            "world_update_ms=\(String(format: "%.3f", block.diagnostics.worldUpdateDurationMilliseconds)) " +
            "asset_decode_loads=\(block.diagnostics.assetDecodeLoadCount) " +
            "asset_decode_ms=\(String(format: "%.3f", block.diagnostics.assetDecodeLoadDurationMilliseconds)) " +
            "total_render_ms=\(String(format: "%.3f", block.diagnostics.totalRenderDurationMilliseconds))"
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

    @MainActor
    private func spatialTransitionFrame(
        from previousState: CityGameState,
        to state: CityGameState,
        size: CGSize
    ) throws -> (png: Data, consumedEventCount: Int, displayedCueCount: Int, actions: Int) {
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = CityScene(size: size)
        scene.reducedMotion = true
        view.presentScene(scene)
        scene.render(
            snapshot: try CityPresentationSnapshot(state: previousState),
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        scene.render(
            snapshot: try CityPresentationSnapshot(state: state),
            overlay: .none,
            selection: GridCoordinate(x: 10, y: 11),
            interactionMode: .inspect
        )
        scene.configureProofCamera(detail: .block, centeredOn: GridCoordinate(x: 12, y: 11))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.12))
        let texture = try XCTUnwrap(view.texture(from: scene))
        let representation = NSBitmapImageRep(cgImage: texture.cgImage())
        let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        return (
            png,
            scene.diagnosticsSnapshot.consumedConsequenceEventCount,
            scene.diagnosticsSnapshot.displayedConsequenceCueCount,
            scene.diagnosticsSnapshot.activeActionCount
        )
    }

    private func spatialProofState(recovered: Bool) -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.tick = recovered ? 8 : 4
        state.happiness = recovered ? 82 : 20
        state.powerCapacity = recovered ? 300 : 0
        state.waterCapacity = recovered ? 270 : 0
        state.updateTile(at: GridCoordinate(x: 10, y: 11)) {
            $0.condition = recovered ? 1 : 0.2
            $0.occupancy = recovered ? 280 : 0
        }
        if recovered {
            state.updateTile(at: GridCoordinate(x: 14, y: 11)) {
                $0.kind = .park
                $0.condition = 1
                $0.occupancy = 0
            }
        }
        return state
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
