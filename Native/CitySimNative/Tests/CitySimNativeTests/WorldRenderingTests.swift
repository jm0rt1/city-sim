import AppKit
import Foundation
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

        let reducedNames = descendantNames(in: reduced)
        XCTAssertTrue(reducedNames.contains("spatial.event.mark.recovery"))
        XCTAssertTrue(reducedNames.contains("spatial.event.frontage-bracket.recovery"))
        XCTAssertFalse(reducedNames.contains { $0.hasPrefix("spatial.event.ring.") })
        let reducedBounds = reduced.calculateAccumulatedFrame()
        XCTAssertLessThanOrEqual(reducedBounds.width, 20)
        XCTAssertLessThanOrEqual(reducedBounds.height, 12)
        XCTAssertLessThan(reducedBounds.maxY, 0)
        XCTAssertEqual(recursiveActiveActionCount(animated), 1)
        XCTAssertEqual(recursiveActiveActionCount(reduced), 0)
    }

    @MainActor
    func testFiveOverlaysUseOnlyApprovedSpatialSamplesAndRespectTypedDomains() throws {
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
            vitality: .notApplicable,
            landValueIndex: 0.62,
            localHappinessIndex: 0.44
        )
        let road = CityTile(coordinate: GridCoordinate(x: 2, y: 4), kind: .road)
        let roadConsequence = CitySpatialConsequence(
            coordinate: road.coordinate,
            utility: consequence.utility,
            pollutionExposure: consequence.pollutionExposure,
            pollutionBand: consequence.pollutionBand,
            vitalityScore: 0,
            vitality: .notApplicable,
            trafficPressure: 0.73
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
        let landValue = renderer.sample(
            for: tile,
            state: contradictoryState,
            consequence: consequence,
            overlay: .landValue
        )
        let happiness = renderer.sample(
            for: tile,
            state: contradictoryState,
            consequence: consequence,
            overlay: .happiness
        )
        let traffic = renderer.sample(
            for: road,
            state: contradictoryState,
            consequence: roadConsequence,
            overlay: .traffic
        )
        XCTAssertEqual(try XCTUnwrap(utility).value, 0.33, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(pollution).value, 0.36, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(landValue).value, 0.62, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(happiness).value, 0.44, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(traffic).value, 0.27, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(utility).pattern.rawValue, "utilityEdge")
        XCTAssertEqual(try XCTUnwrap(pollution).pattern.rawValue, "pollutionHatch")
        XCTAssertEqual(try XCTUnwrap(landValue).pattern.rawValue, "landValueContour")
        XCTAssertEqual(try XCTUnwrap(happiness).pattern.rawValue, "happinessRipples")
        XCTAssertEqual(try XCTUnwrap(traffic).pattern.rawValue, "trafficPressureTicks")
        XCTAssertNil(renderer.sample(
            for: tile,
            state: contradictoryState,
            consequence: nil,
            overlay: .utilities
        ))
        let nilDomain = CitySpatialConsequence(
            coordinate: tile.coordinate,
            utility: consequence.utility,
            pollutionExposure: consequence.pollutionExposure,
            pollutionBand: consequence.pollutionBand,
            vitalityScore: 0,
            vitality: .notApplicable
        )
        for overlay in [DataOverlay.landValue, .traffic, .happiness] {
            XCTAssertNil(renderer.sample(
                for: tile,
                state: contradictoryState,
                consequence: nilDomain,
                overlay: overlay
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
        var underConstruction = tile
        underConstruction.constructionProgress = 0.99
        for overlay in [DataOverlay.landValue, .happiness] {
            XCTAssertNil(renderer.sample(
                for: underConstruction,
                state: contradictoryState,
                consequence: consequence,
                overlay: overlay
            ))
        }
        XCTAssertNil(renderer.sample(
            for: road,
            state: contradictoryState,
            consequence: roadConsequence,
            overlay: .landValue
        ))
        XCTAssertNil(renderer.sample(
            for: tile,
            state: contradictoryState,
            consequence: consequence,
            overlay: .traffic
        ))
        XCTAssertNil(renderer.sample(
            for: CityTile(coordinate: GridCoordinate(x: 3, y: 3), kind: .residential),
            state: contradictoryState,
            consequence: consequence,
            overlay: .utilities
        ))
    }

    @MainActor
    func testFiveOverlaysUseDistinctSparseNonColorMarksWithoutTileWashOrLabels() {
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
            vitality: .notApplicable,
            landValueIndex: 0.20,
            localHappinessIndex: 0.20
        )
        let road = CityTile(coordinate: tile.coordinate, kind: .road)
        let trafficConsequence = CitySpatialConsequence(
            coordinate: tile.coordinate,
            utility: severe.utility,
            pollutionExposure: severe.pollutionExposure,
            pollutionBand: severe.pollutionBand,
            vitalityScore: 0,
            vitality: .notApplicable,
            trafficPressure: 0.80
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
        let landValue = renderer.makeOverlay(
            for: tile,
            state: state,
            consequence: severe,
            overlay: .landValue,
            detail: .block
        )
        let traffic = renderer.makeOverlay(
            for: road,
            state: state,
            consequence: trafficConsequence,
            overlay: .traffic,
            detail: .block
        )
        let happiness = renderer.makeOverlay(
            for: tile,
            state: state,
            consequence: severe,
            overlay: .happiness,
            detail: .block
        )

        let utilityNames = descendantNames(in: utility)
        let pollutionNames = descendantNames(in: pollution)
        let landValueNames = descendantNames(in: landValue)
        let trafficNames = descendantNames(in: traffic)
        let happinessNames = descendantNames(in: happiness)
        for names in [utilityNames, pollutionNames, landValueNames, trafficNames, happinessNames] {
            XCTAssertFalse(names.contains("overlay.base"))
        }
        XCTAssertTrue(utilityNames.contains("overlay.utility.status-edge"))
        XCTAssertEqual(utilityNames.filter { $0 == "overlay.utility.severity-notch" }.count, 3)
        XCTAssertEqual(pollutionNames.filter { $0 == "overlay.pollution.exposure-hatch" }.count, 3)
        XCTAssertEqual(landValueNames.filter { $0 == "overlay.land-value.ground-contour" }.count, 3)
        XCTAssertEqual(trafficNames.filter { $0 == "overlay.traffic.pressure-tick" }.count, 6)
        XCTAssertEqual(happinessNames.filter { $0 == "overlay.happiness.ground-ripple" }.count, 3)
        for overlay in [utility, pollution, landValue, traffic, happiness] {
            XCTAssertTrue(descendantLabels(in: overlay).isEmpty)
            XCTAssertEqual(recursiveActiveActionCount(overlay), 0)
        }

        let utilityBounds = utility.calculateAccumulatedFrame()
        let pollutionBounds = pollution.calculateAccumulatedFrame()
        let landValueBounds = landValue.calculateAccumulatedFrame()
        let trafficBounds = traffic.calculateAccumulatedFrame()
        let happinessBounds = happiness.calculateAccumulatedFrame()
        XCTAssertLessThan(utilityBounds.width, style.tileWidth * 0.60)
        XCTAssertLessThan(utilityBounds.height, style.tileHeight * 0.50)
        XCTAssertLessThan(pollutionBounds.width, style.tileWidth * 0.40)
        XCTAssertLessThan(pollutionBounds.height, style.tileHeight * 0.20)
        for (name, bounds) in [
            ("pollution", pollutionBounds),
            ("land-value", landValueBounds),
            ("traffic-pressure", trafficBounds),
            ("happiness", happinessBounds),
        ] {
            XCTAssertLessThan(
                bounds.maxY,
                -style.tileHeight * 0.12,
                "\(name) marks must stay on the ground/frontage plane instead of crossing facades"
            )
            XCTAssertLessThan(bounds.width, style.tileWidth * 0.55, "\(name) width")
            XCTAssertLessThan(bounds.height, style.tileHeight * 0.25, "\(name) height")
        }

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

        for detail in CameraDetailLevel.allCases {
            let landAtDetail = renderer.makeOverlay(
                for: tile,
                state: state,
                consequence: severe,
                overlay: .landValue,
                detail: detail
            )
            let trafficAtDetail = renderer.makeOverlay(
                for: road,
                state: state,
                consequence: trafficConsequence,
                overlay: .traffic,
                detail: detail
            )
            let happinessAtDetail = renderer.makeOverlay(
                for: tile,
                state: state,
                consequence: severe,
                overlay: .happiness,
                detail: detail
            )
            for overlay in [landAtDetail, trafficAtDetail, happinessAtDetail] {
                XCTAssertEqual(overlay.childNode(withName: "//detail.city")?.isHidden, false)
                XCTAssertEqual(recursiveActiveActionCount(overlay), 0)
            }
        }
    }

    @MainActor
    func testTruthOverlaysDoNotRevealCompoundFacadeGlyphs() throws {
        let state = spatialProofState(recovered: false)
        let snapshot = try CityPresentationSnapshot(state: state)
        let focus = GridCoordinate(x: 13, y: 11)
        XCTAssertNotNil(snapshot.spatialConsequences[focus])

        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        for overlay in [
            DataOverlay.landValue,
            .traffic,
            .utilities,
            .happiness,
            .pollution,
        ] {
            scene.render(
                snapshot: snapshot,
                overlay: overlay,
                selection: nil,
                interactionMode: .inspect
            )
            XCTAssertEqual(
                scene.persistentConsequenceAlphaForTesting(at: focus),
                0,
                "The chosen sparse overlay pattern must have exclusive priority over compound facade glyphs"
            )
        }
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
        let focus = GridCoordinate(x: 13, y: 11)
        let strainedSample = try XCTUnwrap(strainedSnapshot.spatialConsequences[focus])
        let recoveredSample = try XCTUnwrap(recoveredSnapshot.spatialConsequences[focus])
        let focusEvents = recoveredSnapshot.consequenceEvents(since: strainedSnapshot)
            .filter { $0.coordinate == focus }
        let focusEventIDs = focusEvents.map(\.id)
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
        XCTAssertEqual(focusEvents.map(\.dimension), [.utility, .pollution, .vitality])
        XCTAssertTrue(focusEvents.allSatisfy { $0.direction == .recovery })
        XCTAssertEqual(defaultProof.actions, 0)
        XCTAssertEqual(compactProof.actions, 0)

        try export(strainedProof.png, environmentKey: "CITYSIM_PLAY022_SPATIAL_STRAINED_PROOF")
        try export(defaultProof.png, environmentKey: "CITYSIM_PLAY022_SPATIAL_RECOVERY_PROOF")
        try export(compactProof.png, environmentKey: "CITYSIM_PLAY022_SPATIAL_COMPACT_PROOF")
        print(
            "CITYSIM_PLAY022_SPATIAL_PROOF focus=\(focus.x),\(focus.y) " +
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
        XCTAssertEqual(manifest?.assets.count, 48)
        for asset in manifest?.assets ?? [] {
            for detail in CameraDetailLevel.allCases {
                XCTAssertNotNil(catalog.generatedSprite(logicalID: asset.logicalID, detail: detail))
            }
        }
    }

    @MainActor
    func testDirectionalResidentialProductionSelectionCoversEveryLevelAndAuthoritativeFrontage() throws {
        let catalog = WorldAssetCatalog()
        let renderer = LotRenderer(style: WorldVisualStyle(), assets: catalog)
        let expectedSockets: [RoadConnectionMask: [Double]] = [
            .north: [18, 9],
            .east: [18, -9],
            .south: [-18, -9],
            .west: [-18, 9],
        ]
        var logicalIDs: Set<String> = []
        var sourceKeys: Set<String> = []
        var sourceHashes: Set<String> = []
        var normalizedHashes: Set<String> = []

        for level in 1...4 {
            for edge in RoadConnectionMask.cardinalEdges {
                let identity = try XCTUnwrap(
                    ResidentialGeneratedAssetIdentity(level: level, adjacentRoads: edge)
                )
                logicalIDs.insert(identity.logicalID)
                let asset = try XCTUnwrap(catalog.generatedAsset(logicalID: identity.logicalID))
                XCTAssertEqual(asset.family, "residential")
                XCTAssertEqual(asset.level, level)
                XCTAssertEqual(asset.variant, 0)
                XCTAssertEqual(asset.frontageEdge, identity.direction)
                XCTAssertEqual(asset.viewDirection, identity.direction)
                XCTAssertEqual(asset.entranceSocketWorld, expectedSockets[edge])
                XCTAssertEqual(asset.supportedOrientation, "\(identity.direction)-facing-authored")
                XCTAssertEqual(asset.roadSetbackPoints, 0)
                XCTAssertEqual(asset.allowedOverhangWorld.count, 4)
                XCTAssertLessThanOrEqual(asset.allowedOverhangWorld[2], 0.51)
                XCTAssertEqual(asset.propExclusionRectsWorld.count, 1)
                let exclusion = try XCTUnwrap(asset.propExclusionRectsWorld.first)
                XCTAssertEqual(exclusion.count, 4)
                XCTAssertGreaterThanOrEqual(asset.entranceSocketWorld[0], exclusion[0])
                XCTAssertLessThanOrEqual(
                    asset.entranceSocketWorld[0],
                    exclusion[0] + exclusion[2]
                )
                XCTAssertGreaterThanOrEqual(asset.entranceSocketWorld[1], exclusion[1])
                XCTAssertLessThanOrEqual(
                    asset.entranceSocketWorld[1],
                    exclusion[1] + exclusion[3]
                )
                sourceKeys.insert(try XCTUnwrap(asset.sourceKey))
                sourceHashes.insert(try XCTUnwrap(asset.sourceSHA256))

                for detail in CameraDetailLevel.allCases {
                    let lod = try XCTUnwrap(asset.lods[detail.assetSuffix])
                    normalizedHashes.insert(try XCTUnwrap(lod.normalizedSHA256))
                    let tile = CityTile(
                        coordinate: GridCoordinate(x: level + 4, y: Int(edge.rawValue) + 5),
                        kind: .residential,
                        level: level,
                        condition: 1,
                        constructionProgress: 1
                    )
                    let lot = renderer.makeLot(
                        for: tile,
                        adjacentRoads: edge,
                        detail: detail,
                        reducedMotion: true
                    )
                    let names = descendantNames(in: lot)
                    XCTAssertEqual(
                        names.filter {
                            $0 == "lot.generated-v4.\(identity.logicalID).\(detail.assetSuffix)"
                        }.count,
                        1
                    )
                    XCTAssertTrue(
                        names.contains("lot.frontage.residential.\(edge.rawValue)")
                    )
                    XCTAssertFalse(names.contains { $0 == "lot.generated-v4.residential_l01.\(detail.assetSuffix)" })
                    XCTAssertFalse(names.contains { $0.hasPrefix("lot.place.") })
                }
            }
        }

        XCTAssertEqual(logicalIDs.count, 16)
        XCTAssertEqual(sourceKeys.count, 16)
        XCTAssertEqual(sourceHashes.count, 16)
        XCTAssertEqual(normalizedHashes.count, 48)
        XCTAssertEqual(catalog.residencySnapshot().fallbackCount, 0)
    }

    @MainActor
    func testDirectionalCommercialProductionSelectionCoversEveryLevelAndAuthoritativeFrontage() throws {
        let catalog = WorldAssetCatalog()
        let renderer = LotRenderer(style: WorldVisualStyle(), assets: catalog)
        let expectedSockets: [RoadConnectionMask: [Double]] = [
            .north: [18, 9],
            .east: [18, -9],
            .south: [-18, -9],
            .west: [-18, 9],
        ]
        let residentialHashes = Set(
            (catalog.generatedManifest?.assets ?? [])
                .filter { $0.family == "residential" && $0.viewDirection != nil }
                .compactMap(\.sourceSHA256)
        )
        var logicalIDs: Set<String> = []
        var sourceKeys: Set<String> = []
        var sourceHashes: Set<String> = []
        var normalizedHashes: Set<String> = []

        for level in 1...4 {
            for edge in RoadConnectionMask.cardinalEdges {
                let identity = try XCTUnwrap(
                    CommercialGeneratedAssetIdentity(level: level, adjacentRoads: edge)
                )
                logicalIDs.insert(identity.logicalID)
                let asset = try XCTUnwrap(catalog.generatedAsset(logicalID: identity.logicalID))
                XCTAssertEqual(asset.family, "commercial")
                XCTAssertEqual(asset.level, level)
                XCTAssertEqual(asset.variant, 0)
                XCTAssertEqual(asset.frontageEdge, identity.direction)
                XCTAssertEqual(asset.viewDirection, identity.direction)
                XCTAssertEqual(asset.entranceSocketWorld, expectedSockets[edge])
                XCTAssertEqual(asset.supportedOrientation, "\(identity.direction)-facing-authored")
                XCTAssertEqual(asset.roadSetbackPoints, 0)
                XCTAssertEqual(asset.allowedOverhangWorld.count, 4)
                XCTAssertLessThanOrEqual(asset.allowedOverhangWorld[2], 0.51)
                XCTAssertEqual(asset.propExclusionRectsWorld.count, 1)
                let exclusion = try XCTUnwrap(asset.propExclusionRectsWorld.first)
                XCTAssertEqual(exclusion.count, 4)
                XCTAssertGreaterThanOrEqual(asset.entranceSocketWorld[0], exclusion[0])
                XCTAssertLessThanOrEqual(
                    asset.entranceSocketWorld[0],
                    exclusion[0] + exclusion[2]
                )
                XCTAssertGreaterThanOrEqual(asset.entranceSocketWorld[1], exclusion[1])
                XCTAssertLessThanOrEqual(
                    asset.entranceSocketWorld[1],
                    exclusion[1] + exclusion[3]
                )
                sourceKeys.insert(try XCTUnwrap(asset.sourceKey))
                sourceHashes.insert(try XCTUnwrap(asset.sourceSHA256))

                for detail in CameraDetailLevel.allCases {
                    let lod = try XCTUnwrap(asset.lods[detail.assetSuffix])
                    normalizedHashes.insert(try XCTUnwrap(lod.normalizedSHA256))
                    let tile = CityTile(
                        coordinate: GridCoordinate(x: level + 4, y: Int(edge.rawValue) + 5),
                        kind: .commercial,
                        level: level,
                        condition: 1,
                        constructionProgress: 1
                    )
                    let lot = renderer.makeLot(
                        for: tile,
                        adjacentRoads: edge,
                        detail: detail,
                        reducedMotion: true
                    )
                    let names = descendantNames(in: lot)
                    XCTAssertEqual(
                        names.filter {
                            $0 == "lot.generated-v4.\(identity.logicalID).\(detail.assetSuffix)"
                        }.count,
                        1
                    )
                    XCTAssertTrue(
                        names.contains("lot.frontage.commercial.\(edge.rawValue)")
                    )
                    XCTAssertFalse(
                        names.contains {
                            $0 == "lot.generated-v4.commercial_l01.\(detail.assetSuffix)"
                        }
                    )
                    XCTAssertFalse(names.contains { $0.hasPrefix("lot.place.") })
                }
            }
        }

        XCTAssertEqual(logicalIDs.count, 16)
        XCTAssertEqual(sourceKeys.count, 16)
        XCTAssertEqual(sourceHashes.count, 16)
        XCTAssertEqual(normalizedHashes.count, 48)
        XCTAssertTrue(sourceHashes.isDisjoint(with: residentialHashes))
        XCTAssertEqual(catalog.residencySnapshot().fallbackCount, 0)
    }

    @MainActor
    func testDirectionalIndustrialL1ProductionSelectionCoversEveryAuthoritativeFrontageAndLOD() throws {
        let catalog = WorldAssetCatalog()
        let renderer = LotRenderer(style: WorldVisualStyle(), assets: catalog)
        let expectedSockets: [RoadConnectionMask: [Double]] = [
            .north: [18, 9],
            .east: [18, -9],
            .south: [-18, -9],
            .west: [-18, 9],
        ]
        let otherFamilyHashes = Set(
            (catalog.generatedManifest?.assets ?? [])
                .filter {
                    ($0.family == "residential" || $0.family == "commercial")
                        && $0.viewDirection != nil
                }
                .compactMap(\.sourceSHA256)
        )
        var logicalIDs: Set<String> = []
        var sourceKeys: Set<String> = []
        var sourceHashes: Set<String> = []
        var normalizedHashes: Set<String> = []

        for edge in RoadConnectionMask.cardinalEdges {
            let identity = try XCTUnwrap(
                IndustrialL1GeneratedAssetIdentity(level: 1, adjacentRoads: edge)
            )
            logicalIDs.insert(identity.logicalID)
            let asset = try XCTUnwrap(catalog.generatedAsset(logicalID: identity.logicalID))
            XCTAssertEqual(asset.family, "industrial")
            XCTAssertEqual(asset.level, 1)
            XCTAssertEqual(asset.variant, 0)
            XCTAssertEqual(asset.sourceRevision, "source-v05")
            XCTAssertEqual(asset.frontageEdge, identity.direction)
            XCTAssertEqual(asset.viewDirection, identity.direction)
            XCTAssertEqual(asset.entranceSocketWorld, expectedSockets[edge])
            XCTAssertEqual(asset.supportedOrientation, "\(identity.direction)-facing-authored")
            XCTAssertEqual(asset.roadSetbackPoints, 0)
            XCTAssertEqual(asset.allowedOverhangWorld.count, 4)
            XCTAssertLessThanOrEqual(asset.allowedOverhangWorld[2], 0.51)
            XCTAssertEqual(asset.propExclusionRectsWorld.count, 1)
            let exclusion = try XCTUnwrap(asset.propExclusionRectsWorld.first)
            XCTAssertEqual(exclusion.count, 4)
            XCTAssertGreaterThanOrEqual(asset.entranceSocketWorld[0], exclusion[0])
            XCTAssertLessThanOrEqual(
                asset.entranceSocketWorld[0],
                exclusion[0] + exclusion[2]
            )
            XCTAssertGreaterThanOrEqual(asset.entranceSocketWorld[1], exclusion[1])
            XCTAssertLessThanOrEqual(
                asset.entranceSocketWorld[1],
                exclusion[1] + exclusion[3]
            )
            sourceKeys.insert(try XCTUnwrap(asset.sourceKey))
            sourceHashes.insert(try XCTUnwrap(asset.sourceSHA256))

            for detail in CameraDetailLevel.allCases {
                let lod = try XCTUnwrap(asset.lods[detail.assetSuffix])
                normalizedHashes.insert(try XCTUnwrap(lod.normalizedSHA256))
                let tile = CityTile(
                    coordinate: GridCoordinate(x: 7, y: Int(edge.rawValue) + 5),
                    kind: .industrial,
                    level: 1,
                    condition: 1,
                    constructionProgress: 1
                )
                let lot = renderer.makeLot(
                    for: tile,
                    adjacentRoads: edge,
                    detail: detail,
                    reducedMotion: true
                )
                let names = descendantNames(in: lot)
                XCTAssertEqual(
                    names.filter {
                        $0 == "lot.generated-v4.\(identity.logicalID).\(detail.assetSuffix)"
                    }.count,
                    1
                )
                XCTAssertTrue(names.contains("lot.frontage.industrial.\(edge.rawValue)"))
                XCTAssertFalse(
                    names.contains {
                        $0 == "lot.generated-v4.industrial_l01.\(detail.assetSuffix)"
                    }
                )
                XCTAssertFalse(names.contains { $0.hasPrefix("lot.place.") })
            }
        }

        XCTAssertEqual(logicalIDs.count, 4)
        XCTAssertEqual(sourceKeys.count, 4)
        XCTAssertEqual(sourceHashes.count, 4)
        XCTAssertEqual(normalizedHashes.count, 12)
        XCTAssertTrue(sourceHashes.isDisjoint(with: otherFamilyHashes))
        XCTAssertEqual(catalog.residencySnapshot().fallbackCount, 0)
    }

    @MainActor
    func testDirectionalResidentialRuntimeMatrixExportsPreIngestionAndProductionSelection() throws {
        let catalog = WorldAssetCatalog()
        let renderer = LotRenderer(style: WorldVisualStyle(), assets: catalog)
        let size = CGSize(width: 1_400, height: 1_100)
        let directions: [(String, RoadConnectionMask)] = [
            ("N", .north), ("E", .east), ("S", .south), ("W", .west),
        ]

        func frame(directional: Bool) throws -> Data {
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            let scene = SKScene(size: size)
            scene.backgroundColor = NSColor(
                calibratedRed: 0.24,
                green: 0.34,
                blue: 0.25,
                alpha: 1
            )
            view.presentScene(scene)

            for (column, entry) in directions.enumerated() {
                let label = SKLabelNode(
                    fontNamed: "AvenirNext-DemiBold"
                )
                label.text = entry.0
                label.fontSize = 24
                label.fontColor = .white
                label.position = CGPoint(x: 230 + column * 310, y: 1_045)
                scene.addChild(label)
            }
            for level in 1...4 {
                let row = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
                row.text = "L\(level)"
                row.fontSize = 24
                row.fontColor = .white
                row.horizontalAlignmentMode = .right
                row.position = CGPoint(x: 78, y: 925 - (level - 1) * 235)
                scene.addChild(row)

                for (column, entry) in directions.enumerated() {
                    let node: SKNode
                    if directional {
                        node = renderer.makeLot(
                            for: CityTile(
                                coordinate: GridCoordinate(x: level, y: column),
                                kind: .residential,
                                level: level,
                                condition: 1,
                                constructionProgress: 1
                            ),
                            adjacentRoads: entry.1,
                            detail: .block,
                            reducedMotion: true
                        )
                    } else {
                        node = try XCTUnwrap(
                            catalog.generatedSprite(
                                logicalID: "residential_l01",
                                detail: .block
                            )
                        )
                    }
                    node.position = CGPoint(
                        x: 230 + column * 310,
                        y: 880 - (level - 1) * 235
                    )
                    node.setScale(2.7)
                    scene.addChild(node)
                }
            }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
            let texture = try XCTUnwrap(view.texture(from: scene))
            let representation = NSBitmapImageRep(cgImage: texture.cgImage())
            return try XCTUnwrap(
                representation.representation(using: .png, properties: [:])
            )
        }

        let before = try frame(directional: false)
        let after = try frame(directional: true)
        XCTAssertNotEqual(before, after)
        XCTAssertGreaterThan(before.count, 100_000)
        XCTAssertGreaterThan(after.count, 100_000)
        XCTAssertEqual(catalog.residencySnapshot().fallbackCount, 0)
        try export(
            before,
            environmentKey: "CITYSIM_PLAY028_DIRECTIONAL_MATRIX_BEFORE"
        )
        try export(
            after,
            environmentKey: "CITYSIM_PLAY028_DIRECTIONAL_MATRIX_AFTER"
        )
    }

    @MainActor
    func testDirectionalCommercialRuntimeMatrixExportsPreIngestionAndProductionSelection() throws {
        let catalog = WorldAssetCatalog()
        let renderer = LotRenderer(style: WorldVisualStyle(), assets: catalog)
        let size = CGSize(width: 1_400, height: 1_100)
        let directions: [(String, RoadConnectionMask)] = [
            ("N", .north), ("E", .east), ("S", .south), ("W", .west),
        ]

        func frame(directional: Bool) throws -> Data {
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            let scene = SKScene(size: size)
            scene.backgroundColor = NSColor(
                calibratedRed: 0.24,
                green: 0.34,
                blue: 0.25,
                alpha: 1
            )
            view.presentScene(scene)

            for (column, entry) in directions.enumerated() {
                let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
                label.text = entry.0
                label.fontSize = 24
                label.fontColor = .white
                label.position = CGPoint(x: 230 + column * 310, y: 1_045)
                scene.addChild(label)
            }
            for level in 1...4 {
                let row = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
                row.text = "L\(level)"
                row.fontSize = 24
                row.fontColor = .white
                row.horizontalAlignmentMode = .right
                row.position = CGPoint(x: 78, y: 925 - (level - 1) * 235)
                scene.addChild(row)

                for (column, entry) in directions.enumerated() {
                    let node: SKNode
                    if directional {
                        node = renderer.makeLot(
                            for: CityTile(
                                coordinate: GridCoordinate(x: level, y: column),
                                kind: .commercial,
                                level: level,
                                condition: 1,
                                constructionProgress: 1
                            ),
                            adjacentRoads: entry.1,
                            detail: .block,
                            reducedMotion: true
                        )
                    } else {
                        node = try XCTUnwrap(
                            catalog.generatedSprite(
                                logicalID: "commercial_l01",
                                detail: .block
                            )
                        )
                    }
                    node.position = CGPoint(
                        x: 230 + column * 310,
                        y: 880 - (level - 1) * 235
                    )
                    node.setScale(2.7)
                    scene.addChild(node)
                }
            }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
            let texture = try XCTUnwrap(view.texture(from: scene))
            let representation = NSBitmapImageRep(cgImage: texture.cgImage())
            return try XCTUnwrap(
                representation.representation(using: .png, properties: [:])
            )
        }

        let before = try frame(directional: false)
        let after = try frame(directional: true)
        XCTAssertNotEqual(before, after)
        XCTAssertGreaterThan(before.count, 100_000)
        XCTAssertGreaterThan(after.count, 100_000)
        XCTAssertEqual(catalog.residencySnapshot().fallbackCount, 0)
        try export(
            before,
            environmentKey: "CITYSIM_PLAY060_DIRECTIONAL_MATRIX_BEFORE"
        )
        try export(
            after,
            environmentKey: "CITYSIM_PLAY060_DIRECTIONAL_MATRIX_AFTER"
        )
    }

    @MainActor
    func testResidentialFrontagePriorityIsStableAndRoadlessLotsFailExplicitly() throws {
        let all = try XCTUnwrap(
            ResidentialGeneratedAssetIdentity(level: 9, adjacentRoads: .all)
        )
        XCTAssertEqual(all.level, 4)
        XCTAssertEqual(all.frontage, .south)
        XCTAssertEqual(all.logicalID, "residential_l04_v0_south")
        XCTAssertEqual(
            ResidentialGeneratedAssetIdentity(
                level: 1,
                adjacentRoads: [.north, .east, .west]
            )?.frontage,
            .north
        )
        XCTAssertEqual(
            ResidentialGeneratedAssetIdentity(
                level: 1,
                adjacentRoads: [.east, .west]
            )?.frontage,
            .east
        )
        XCTAssertNil(ResidentialGeneratedAssetIdentity(level: 1, adjacentRoads: []))

        let catalog = WorldAssetCatalog()
        XCTAssertNil(catalog.generatedResidentialPresentation(
            level: 2,
            adjacentRoads: [],
            detail: .block
        ))
        XCTAssertEqual(catalog.residencySnapshot().fallbackCount, 1)
        XCTAssertEqual(
            catalog.residencySnapshot().fallbackDiagnostics,
            ["residential level 2 has no authoritative adjacent road"]
        )
    }

    @MainActor
    func testCommercialFrontagePriorityIsStableAndRoadlessLotsFailExplicitly() throws {
        let all = try XCTUnwrap(
            CommercialGeneratedAssetIdentity(level: 9, adjacentRoads: .all)
        )
        XCTAssertEqual(all.level, 4)
        XCTAssertEqual(all.frontage, .south)
        XCTAssertEqual(all.logicalID, "commercial_l04_v0_south")
        XCTAssertEqual(
            CommercialGeneratedAssetIdentity(
                level: 1,
                adjacentRoads: [.north, .east, .west]
            )?.frontage,
            .north
        )
        XCTAssertEqual(
            CommercialGeneratedAssetIdentity(
                level: 1,
                adjacentRoads: [.east, .west]
            )?.frontage,
            .east
        )
        XCTAssertNil(CommercialGeneratedAssetIdentity(level: 1, adjacentRoads: []))

        let catalog = WorldAssetCatalog()
        XCTAssertNil(catalog.generatedCommercialPresentation(
            level: 2,
            adjacentRoads: [],
            detail: .block
        ))
        XCTAssertEqual(catalog.residencySnapshot().fallbackCount, 1)
        XCTAssertEqual(
            catalog.residencySnapshot().fallbackDiagnostics,
            ["commercial level 2 has no authoritative adjacent road"]
        )
    }

    @MainActor
    func testIndustrialL1FrontagePriorityIsStableAndRoadlessOrHigherLevelsFailExplicitly() throws {
        let all = try XCTUnwrap(
            IndustrialL1GeneratedAssetIdentity(level: 1, adjacentRoads: .all)
        )
        XCTAssertEqual(all.level, 1)
        XCTAssertEqual(all.frontage, .south)
        XCTAssertEqual(all.logicalID, "industrial_l01_v0_south")
        XCTAssertEqual(
            IndustrialL1GeneratedAssetIdentity(
                level: 1,
                adjacentRoads: [.north, .east, .west]
            )?.frontage,
            .north
        )
        XCTAssertEqual(
            IndustrialL1GeneratedAssetIdentity(
                level: 1,
                adjacentRoads: [.east, .west]
            )?.frontage,
            .east
        )
        XCTAssertNil(IndustrialL1GeneratedAssetIdentity(level: 1, adjacentRoads: []))
        XCTAssertNil(IndustrialL1GeneratedAssetIdentity(level: 2, adjacentRoads: .south))

        let catalog = WorldAssetCatalog()
        XCTAssertNil(catalog.generatedIndustrialL1Presentation(
            level: 1,
            adjacentRoads: [],
            detail: .block
        ))
        XCTAssertEqual(catalog.residencySnapshot().fallbackCount, 1)
        XCTAssertEqual(
            catalog.residencySnapshot().fallbackDiagnostics,
            ["industrial L1 has no authoritative adjacent road or requested level is not L1"]
        )
    }

    @MainActor
    func testDirectionalResidentialIdentitySurvivesPulseSaveLoadUndoCameraAndLOD() throws {
        let original = CityGameState.newCity(seed: 42)
        let tile = try XCTUnwrap(original.tiles.first {
            $0.kind == .residential
                && !RoadConnectionMask.resolving(at: $0.coordinate, in: original).isEmpty
        })
        let roads = RoadConnectionMask.resolving(at: tile.coordinate, in: original)
        let originalIdentity = try XCTUnwrap(
            ResidentialGeneratedAssetIdentity(level: tile.level, adjacentRoads: roads)
        )
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: original,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        let initialRoot = scene.tileRootIdentifier(at: tile.coordinate)
        XCTAssertTrue(
            scene.tileDescendantNamesForTesting(at: tile.coordinate).contains(
                "lot.generated-v4.\(originalIdentity.logicalID).\(scene.currentCameraDetailLevel.assetSuffix)"
            )
        )

        scene.render(
            state: original,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        XCTAssertEqual(scene.tileRootIdentifier(at: tile.coordinate), initialRoot)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)

        for detail in CameraDetailLevel.allCases {
            scene.configureProofCamera(detail: detail, centeredOn: tile.coordinate)
            XCTAssertEqual(scene.tileRootIdentifier(at: tile.coordinate), initialRoot)
            XCTAssertTrue(
                scene.tileDescendantNamesForTesting(at: tile.coordinate).contains(
                    "lot.generated-v4.\(originalIdentity.logicalID).\(detail.assetSuffix)"
                )
            )
        }

        let encoded = try JSONEncoder().encode(original)
        let loaded = try JSONDecoder().decode(CityGameState.self, from: encoded)
        scene.render(
            state: loaded,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        XCTAssertEqual(scene.tileRootIdentifier(at: tile.coordinate), initialRoot)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)

        var advanced = original
        advanced.updateTile(at: tile.coordinate) {
            $0.level = min(4, max(1, tile.level + 1))
        }
        let advancedTile = try XCTUnwrap(advanced.tile(at: tile.coordinate))
        let advancedIdentity = try XCTUnwrap(
            ResidentialGeneratedAssetIdentity(level: advancedTile.level, adjacentRoads: roads)
        )
        scene.render(
            state: advanced,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        let advancedRoot = scene.tileRootIdentifier(at: tile.coordinate)
        XCTAssertNotEqual(advancedRoot, initialRoot)
        XCTAssertTrue(scene.diagnosticsSnapshot.updatedCoordinates.contains(tile.coordinate))
        XCTAssertTrue(
            scene.tileDescendantNamesForTesting(at: tile.coordinate).contains(
                "lot.generated-v4.\(advancedIdentity.logicalID).\(scene.currentCameraDetailLevel.assetSuffix)"
            )
        )

        scene.render(
            state: original,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        XCTAssertNotEqual(scene.tileRootIdentifier(at: tile.coordinate), advancedRoot)
        XCTAssertTrue(
            scene.tileDescendantNamesForTesting(at: tile.coordinate).contains(
                "lot.generated-v4.\(originalIdentity.logicalID).\(scene.currentCameraDetailLevel.assetSuffix)"
            )
        )
    }

    @MainActor
    func testDirectionalCommercialIdentitySurvivesPulseSaveLoadUndoCameraAndLOD() throws {
        let original = CityGameState.newCity(seed: 42)
        let tile = try XCTUnwrap(original.tiles.first {
            $0.kind == .commercial
                && !RoadConnectionMask.resolving(at: $0.coordinate, in: original).isEmpty
        })
        let roads = RoadConnectionMask.resolving(at: tile.coordinate, in: original)
        let originalIdentity = try XCTUnwrap(
            CommercialGeneratedAssetIdentity(level: tile.level, adjacentRoads: roads)
        )
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: original,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        let initialRoot = scene.tileRootIdentifier(at: tile.coordinate)
        XCTAssertTrue(
            scene.tileDescendantNamesForTesting(at: tile.coordinate).contains(
                "lot.generated-v4.\(originalIdentity.logicalID).\(scene.currentCameraDetailLevel.assetSuffix)"
            )
        )

        scene.render(
            state: original,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        XCTAssertEqual(scene.tileRootIdentifier(at: tile.coordinate), initialRoot)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)

        for detail in CameraDetailLevel.allCases {
            scene.configureProofCamera(detail: detail, centeredOn: tile.coordinate)
            XCTAssertEqual(scene.tileRootIdentifier(at: tile.coordinate), initialRoot)
            XCTAssertTrue(
                scene.tileDescendantNamesForTesting(at: tile.coordinate).contains(
                    "lot.generated-v4.\(originalIdentity.logicalID).\(detail.assetSuffix)"
                )
            )
        }

        let encoded = try JSONEncoder().encode(original)
        let loaded = try JSONDecoder().decode(CityGameState.self, from: encoded)
        scene.render(
            state: loaded,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        XCTAssertEqual(scene.tileRootIdentifier(at: tile.coordinate), initialRoot)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)

        var advanced = original
        advanced.updateTile(at: tile.coordinate) {
            $0.level = min(4, max(1, tile.level + 1))
        }
        let advancedTile = try XCTUnwrap(advanced.tile(at: tile.coordinate))
        let advancedIdentity = try XCTUnwrap(
            CommercialGeneratedAssetIdentity(level: advancedTile.level, adjacentRoads: roads)
        )
        scene.render(
            state: advanced,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        let advancedRoot = scene.tileRootIdentifier(at: tile.coordinate)
        XCTAssertNotEqual(advancedRoot, initialRoot)
        XCTAssertTrue(scene.diagnosticsSnapshot.updatedCoordinates.contains(tile.coordinate))
        XCTAssertTrue(
            scene.tileDescendantNamesForTesting(at: tile.coordinate).contains(
                "lot.generated-v4.\(advancedIdentity.logicalID).\(scene.currentCameraDetailLevel.assetSuffix)"
            )
        )

        scene.render(
            state: original,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        XCTAssertNotEqual(scene.tileRootIdentifier(at: tile.coordinate), advancedRoot)
        XCTAssertTrue(
            scene.tileDescendantNamesForTesting(at: tile.coordinate).contains(
                "lot.generated-v4.\(originalIdentity.logicalID).\(scene.currentCameraDetailLevel.assetSuffix)"
            )
        )
    }

    @MainActor
    func testDirectionalIndustrialL1IdentitySurvivesPulseSaveLoadUndoCameraAndLOD() throws {
        let original = CityGameState.newCity(seed: 42)
        let tile = try XCTUnwrap(original.tiles.first {
            $0.kind == .industrial
                && $0.level == 1
                && !RoadConnectionMask.resolving(at: $0.coordinate, in: original).isEmpty
        })
        let roads = RoadConnectionMask.resolving(at: tile.coordinate, in: original)
        let identity = try XCTUnwrap(
            IndustrialL1GeneratedAssetIdentity(level: tile.level, adjacentRoads: roads)
        )
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: original,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        let initialRoot = scene.tileRootIdentifier(at: tile.coordinate)
        XCTAssertTrue(
            scene.tileDescendantNamesForTesting(at: tile.coordinate).contains(
                "lot.generated-v4.\(identity.logicalID).\(scene.currentCameraDetailLevel.assetSuffix)"
            )
        )

        scene.render(
            state: original,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        XCTAssertEqual(scene.tileRootIdentifier(at: tile.coordinate), initialRoot)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)

        for detail in CameraDetailLevel.allCases {
            scene.configureProofCamera(detail: detail, centeredOn: tile.coordinate)
            XCTAssertEqual(scene.tileRootIdentifier(at: tile.coordinate), initialRoot)
            XCTAssertTrue(
                scene.tileDescendantNamesForTesting(at: tile.coordinate).contains(
                    "lot.generated-v4.\(identity.logicalID).\(detail.assetSuffix)"
                )
            )
        }

        let encoded = try JSONEncoder().encode(original)
        let loaded = try JSONDecoder().decode(CityGameState.self, from: encoded)
        scene.render(
            state: loaded,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        XCTAssertEqual(scene.tileRootIdentifier(at: tile.coordinate), initialRoot)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)

        var changed = original
        changed.updateTile(at: tile.coordinate) {
            $0.condition = max(0, tile.condition - 0.5)
        }
        scene.render(
            state: changed,
            overlay: .pollution,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        let changedRoot = scene.tileRootIdentifier(at: tile.coordinate)
        XCTAssertNotEqual(changedRoot, initialRoot)
        XCTAssertTrue(scene.diagnosticsSnapshot.updatedCoordinates.contains(tile.coordinate))
        XCTAssertTrue(
            scene.tileDescendantNamesForTesting(at: tile.coordinate).contains {
                $0.hasPrefix("lot.generated-v4.\(identity.logicalID).")
            }
        )

        scene.render(
            state: original,
            overlay: .none,
            selection: tile.coordinate,
            interactionMode: .inspect
        )
        XCTAssertNotEqual(scene.tileRootIdentifier(at: tile.coordinate), changedRoot)
        XCTAssertTrue(
            scene.tileDescendantNamesForTesting(at: tile.coordinate).contains {
                $0.hasPrefix("lot.generated-v4.\(identity.logicalID).")
            }
        )
    }

    @MainActor
    func testGeneratedWorldDescriptorsRegisterPhysicalGeometryWithoutInventingGameplayCells() throws {
        let catalog = WorldAssetCatalog()
        let manifest = try XCTUnwrap(catalog.generatedManifest)

        XCTAssertEqual(catalog.manifestValidationIssues(), [])
        XCTAssertEqual(manifest.pages.count, 4)
        XCTAssertEqual(manifest.inventory.count, 4)
        XCTAssertEqual(manifest.compiledNetwork.connectionMasks, 16)
        XCTAssertEqual(Set(manifest.pages.map(\.file)), Set(manifest.inventory.map(\.file)))

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
                XCTAssertEqual(lod.textureRectPixels[2], lod.pixels[0], asset.logicalID)
                XCTAssertEqual(lod.textureRectPixels[3], lod.pixels[1], asset.logicalID)
                XCTAssertGreaterThanOrEqual(lod.paddingPixels, 4, asset.logicalID)
                XCTAssertGreaterThanOrEqual(lod.extrusionPixels, 2, asset.logicalID)
                XCTAssertTrue(manifest.pages.contains { $0.id == lod.page && $0.lod == detail.assetSuffix })
                let presentation = try XCTUnwrap(
                    catalog.generatedPresentation(logicalID: asset.logicalID, detail: detail)
                )
                let presentationTexture = try XCTUnwrap(presentation.sprite.texture)
                XCTAssertEqual(
                    presentationTexture.size().width,
                    CGFloat(lod.pixels[0]),
                    accuracy: 0.001,
                    asset.logicalID
                )
                XCTAssertEqual(
                    presentationTexture.size().height,
                    CGFloat(lod.pixels[1]),
                    accuracy: 0.001,
                    asset.logicalID
                )
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
        let before = catalog.residencySnapshot()

        XCTAssertNotNil(catalog.generatedPresentation(logicalID: asset.logicalID, detail: .block))
        let loaded = catalog.residencySnapshot()
        XCTAssertEqual(loaded.textureDecodeLoadCount, before.textureDecodeLoadCount + 1)
        XCTAssertGreaterThan(
            loaded.textureDecodeLoadDurationMilliseconds,
            before.textureDecodeLoadDurationMilliseconds
        )

        XCTAssertNotNil(catalog.generatedPresentation(logicalID: asset.logicalID, detail: .block))
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
    func testGeneratedResidencyPreloadTracksOnlyAssetIdentityTopologyAndLOD() {
        var state = CityGameState.newCity(seed: 42)
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        XCTAssertEqual(scene.generatedResidencyPreloadCountForTesting, 1)

        state.updateTile(at: GridCoordinate(x: 11, y: 11)) {
            $0.occupancy += 1
            $0.condition = 0.58
        }
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        XCTAssertEqual(
            scene.generatedResidencyPreloadCountForTesting,
            1,
            "Occupancy, condition, and spatial-only pulses must not rescan generated-v4 residency"
        )

        state.updateTile(at: GridCoordinate(x: 11, y: 11)) {
            $0.level = 2
        }
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        XCTAssertEqual(scene.generatedResidencyPreloadCountForTesting, 2)

        scene.configureProofCamera(
            detail: scene.currentCameraDetailLevel == .city ? .block : .city,
            centeredOn: GridCoordinate(x: 11, y: 11)
        )
        XCTAssertEqual(scene.generatedResidencyPreloadCountForTesting, 3)
    }

    @MainActor
    func testGeneratedWorldPreloadsOneAdjacentLODWithinPageBudget() throws {
        let catalog = WorldAssetCatalog()
        let manifest = try XCTUnwrap(catalog.generatedManifest)
        let logicalIDs = Set(manifest.assets.map(\.logicalID))
        let roadMasks = Set(UInt8(0)..<UInt8(16))

        catalog.preloadGeneratedResidency(
            for: .block,
            logicalIDs: logicalIDs,
            roadMasks: roadMasks
        )

        let snapshot = catalog.residencySnapshot()
        let expectedPages = manifest.pages.filter {
            $0.lod == CameraDetailLevel.block.assetSuffix
                || $0.lod == CameraDetailLevel.neighborhood.assetSuffix
        }
        XCTAssertEqual(snapshot.packID, "generated-v4-calibration")
        XCTAssertNotNil(snapshot.manifestSHA256)
        XCTAssertEqual(snapshot.activeDetail, .block)
        XCTAssertEqual(snapshot.prefetchedDetail, .neighborhood)
        XCTAssertEqual(snapshot.residentTextureCount, expectedPages.count)
        XCTAssertEqual(
            snapshot.residentDecodedBytes,
            expectedPages.reduce(0) { $0 + $1.decodedByteEstimate }
        )
        XCTAssertLessThanOrEqual(snapshot.residentTextureCount, 4)
        XCTAssertLessThanOrEqual(snapshot.highWaterDecodedBytes, 128 * 1_024 * 1_024)
        XCTAssertEqual(snapshot.fallbackCount, 0)
        XCTAssertEqual(snapshot.fallbackDiagnostics, [])
    }

    @MainActor
    func testGeneratedWorldMissingLogicalAssetEmitsBoundedExplicitDiagnostic() {
        let catalog = WorldAssetCatalog()

        XCTAssertNil(catalog.generatedSprite(logicalID: "missing-production-asset", detail: .block))
        XCTAssertNil(catalog.generatedSprite(logicalID: "missing-production-asset", detail: .block))

        let snapshot = catalog.residencySnapshot()
        XCTAssertEqual(snapshot.fallbackCount, 2)
        XCTAssertEqual(snapshot.fallbackDiagnostics, ["unknown logical asset missing-production-asset"])
        XCTAssertLessThanOrEqual(snapshot.fallbackDiagnostics.count, 32)
    }

    @MainActor
    func testGeneratedWorldLegacyRollbackIsExplicitAndDoesNotChangeStateContracts() {
        let catalog = WorldAssetCatalog(
            packOverride: "legacy-v2",
            environment: [:]
        )

        XCTAssertEqual(catalog.selectedPackID, "legacy-v2")
        XCTAssertNil(catalog.generatedManifest)
        XCTAssertNil(catalog.generatedSprite(logicalID: "residential_l01", detail: .block))
        XCTAssertNotNil(catalog.texture(named: "terrain_grass_0"))
        XCTAssertEqual(catalog.residencySnapshot().fallbackCount, 0)
    }

    @MainActor
    func testGeneratedWorldUnknownPackOverrideFailsExplicitly() {
        let catalog = WorldAssetCatalog(
            packOverride: "unknown-pack",
            environment: [:]
        )

        XCTAssertNil(catalog.generatedManifest)
        let snapshot = catalog.residencySnapshot()
        XCTAssertEqual(snapshot.packID, "generated-v4-calibration")
        XCTAssertEqual(snapshot.fallbackCount, 1)
        XCTAssertEqual(snapshot.fallbackDiagnostics, ["unknown pack override unknown-pack"])
    }

    @MainActor
    func testGeneratedWorldProductionBundleLoadsPagesInsteadOfUnpackedPayloads() throws {
        let catalog = WorldAssetCatalog()
        let manifest = try XCTUnwrap(catalog.generatedManifest)
        XCTAssertEqual(manifest.pages.count, 4)
        XCTAssertNil(catalog.texture(named: "generated_v4_residential_l01_block"))
        XCTAssertNotNil(catalog.generatedPresentation(logicalID: "residential_l01", detail: .block))
        let snapshot = catalog.residencySnapshot()
        XCTAssertEqual(snapshot.residentTextureCount, 1)
        XCTAssertEqual(snapshot.textureDecodeLoadCount, 2)
        XCTAssertEqual(snapshot.fallbackCount, 0)
    }

    @MainActor
    func testAuthoredRoadAtlasCoversEveryMaskAndFrontagesFaceConnectedRoads() {
        let catalog = WorldAssetCatalog()
        let style = WorldVisualStyle()
        let roads = RoadRenderer(style: style, assets: catalog)

        for mask in RoadConnectionMask.allMasks {
            XCTAssertNotNil(catalog.generatedRoadSprite(connectionMask: mask.rawValue, detail: .block))
            let root = roads.makeRoad(
                at: GridCoordinate(x: 4, y: 4),
                connections: mask,
                detail: .block,
                reducedMotion: true
            )
            let names = descendantNames(in: root)
            XCTAssertTrue(names.contains("road.production-corridor.developed.\(mask.rawValue)"))
            XCTAssertTrue(names.contains("road.generated-v4.\(mask.rawValue).block"))
            if mask.isEmpty {
                XCTAssertFalse(names.contains { $0.hasPrefix("road.socket-seam-blend.") })
            } else {
                XCTAssertTrue(
                    names.contains("road.socket-seam-blend.\(mask.rawValue)"),
                    "One batched node may cover only the reciprocal socket seams"
                )
            }
            if mask.edges.count == 1 {
                XCTAssertTrue(names.contains("road.terminus.paved-apron"))
                XCTAssertTrue(names.contains("road.terminus.authenticated-barrier"))
                XCTAssertEqual(
                    names.filter { $0 == "road.terminus.authenticated-bollard" }.count,
                    2
                )
            } else {
                XCTAssertFalse(names.contains { $0.hasPrefix("road.terminus.") })
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
    func testEntireAuthoritativeRoadNetworkStaysPhysicalWithoutChangingHitGeometry() {
        let state = CityGameState.newCity(seed: 42)
        let renderer = RoadRenderer(style: WorldVisualStyle())
        let roads = state.tiles.filter { $0.kind == .road }
        let developedCoordinates = state.tiles.compactMap { tile in
            ![.empty, .road].contains(tile.kind) ? tile.coordinate : nil
        }
        var observedMasks: Set<UInt8> = []

        XCTAssertEqual(roads.count, 32)
        for roadTile in roads {
            let coordinate = roadTile.coordinate
            let mask = RoadConnectionMask.resolving(at: coordinate, in: state)
            let road = renderer.makeRoad(
                at: coordinate,
                in: state,
                detail: .block,
                reducedMotion: true
            )
            observedMasks.insert(mask.rawValue)

            XCTAssertGreaterThanOrEqual(
                mask.connectionCount,
                2,
                "Authoritative starter roads must not expose a dead end at \(coordinate)"
            )
            XCTAssertEqual(road.alpha, 1, accuracy: 0.001)
            XCTAssertEqual(
                road.childNode(withName: CameraDetailLevel.neighborhood.layerName)?.alpha ?? -1,
                1,
                accuracy: 0.001
            )

            let isDevelopedContext = developedCoordinates.contains { developed in
                max(
                    abs(developed.x - coordinate.x),
                    abs(developed.y - coordinate.y)
                ) <= 1
            }
            let emphasis = isDevelopedContext ? "developed" : "network"
            let names = descendantNames(in: road)
            XCTAssertTrue(names.contains(
                "road.production-corridor.\(emphasis).\(mask.rawValue)"
            ))
            XCTAssertTrue(names.contains(
                "road.generated-v4.\(mask.rawValue).block"
            ))
            XCTAssertFalse(names.contains { $0.hasPrefix("road.terminus.") })

            let sprite = road.childNode(
                withName: "//road.generated-v4.\(mask.rawValue).block"
            ) as? SKSpriteNode
            XCTAssertEqual(
                sprite?.alpha ?? -1,
                1,
                accuracy: 0.001
            )
            XCTAssertEqual(
                sprite?.colorBlendFactor ?? -1,
                isDevelopedContext ? 0.16 : 0.18,
                accuracy: 0.001
            )
            XCTAssertFalse(
                names.contains { $0.hasPrefix("road.material.") },
                "The generated-v4 road is the only visible road material layer"
            )
            XCTAssertEqual(
                names.filter { $0.hasPrefix("road.socket-seam-blend.") }.count,
                1
            )

            let terrain = TerrainRenderer(style: WorldVisualStyle()).makeGround(
                for: roadTile,
                detail: .block
            )
            XCTAssertFalse(descendantNames(in: terrain).contains("terrain.hit-surface"))
        }
        XCTAssertEqual(
            observedMasks,
            Set([UInt8(3), 5, 6, 9, 10, 11, 12, 14])
        )
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
                // CityScene cancels the renderer's coordinate depth at the tile
                // root so all reciprocal material sockets share one road plane.
                // Recreate that parent transform in this isolated atlas proof.
                road.zPosition += style.depth(for: coordinate)
                road.position = center
                road.setScale(1.08)
                scene.addChild(road)
                let names = descendantNames(in: road)
                XCTAssertTrue(names.contains("road.production-corridor.developed.\(maskValue)"))
                XCTAssertTrue(names.contains("road.generated-v4.\(maskValue).\(detail.assetSuffix)"))
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
            let priority = scene.cameraPriorityViewportOccupancyForTesting()
            XCTAssertGreaterThanOrEqual(occupied.width, 0.60)
            XCTAssertLessThanOrEqual(occupied.width, 0.61)
            XCTAssertGreaterThanOrEqual(priority.width, 1.04)
            XCTAssertLessThanOrEqual(priority.width, 1.06)
            XCTAssertGreaterThan(priority.width, occupied.width)
            XCTAssertGreaterThan(priority.height, occupied.height)
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
            (.park, "park_l01"),
            (.powerPlant, "industrial_l01"),
            (.waterTower, "water_tower_l01"),
            (.fireStation, "commercial_l01"),
            (.policeStation, "city_hall_l01"),
            (.school, "residential_l01"),
            (.cityHall, "city_hall_l01"),
        ]

        for tier in 1...4 {
            let tile = CityTile(
                coordinate: GridCoordinate(x: tier + 1, y: tier + 3),
                kind: .residential,
                level: tier,
                condition: 1,
                constructionProgress: 1
            )
            let root = renderer.makeLot(
                for: tile,
                adjacentRoads: .south,
                detail: .block,
                reducedMotion: true
            )
            let expectedName = "lot.generated-v4.residential_l0\(tier)_v0_south.block"
            XCTAssertEqual(descendantNames(in: root).filter { $0 == expectedName }.count, 1)
        }

        let industrialL1 = CityTile(
            coordinate: GridCoordinate(x: 6, y: 6),
            kind: .industrial,
            level: 1,
            condition: 1,
            constructionProgress: 1
        )
        let industrialL1Names = descendantNames(in: renderer.makeLot(
            for: industrialL1,
            adjacentRoads: .south,
            detail: .block,
            reducedMotion: true
        ))
        XCTAssertTrue(
            industrialL1Names.contains("lot.generated-v4.industrial_l01_v0_south.block")
        )
        XCTAssertFalse(industrialL1Names.contains("lot.generated-v4.industrial_l01.block"))

        for tier in 1...4 {
            let tile = CityTile(
                coordinate: GridCoordinate(x: tier + 6, y: tier + 2),
                kind: .commercial,
                level: tier,
                condition: 1,
                constructionProgress: 1
            )
            let root = renderer.makeLot(
                for: tile,
                adjacentRoads: .south,
                detail: .block,
                reducedMotion: true
            )
            let expectedName = "lot.generated-v4.commercial_l0\(tier)_v0_south.block"
            XCTAssertEqual(descendantNames(in: root).filter { $0 == expectedName }.count, 1)
        }

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

        let powerPlantRoot = renderer.makeLot(
            for: powerPlant,
            adjacentRoads: .south,
            detail: .block,
            reducedMotion: true
        )
        let powerPlantSprite = powerPlantRoot.childNode(
            withName: "//lot.generated-v4.industrial_l01.block"
        ) as? SKSpriteNode
        XCTAssertEqual(powerPlantSprite?.xScale ?? -1, 0.88, accuracy: 0.001)
        XCTAssertEqual(powerPlantSprite?.yScale ?? -1, 0.88, accuracy: 0.001)

        let waterTower = CityTile(
            coordinate: GridCoordinate(x: 11, y: 14),
            kind: .waterTower,
            constructionProgress: 1
        )
        let waterTowerRoot = renderer.makeLot(
            for: waterTower,
            adjacentRoads: .north,
            detail: .block,
            reducedMotion: true
        )
        let waterTowerSprite = waterTowerRoot.childNode(
            withName: "//lot.generated-v4.water_tower_l01.block"
        ) as? SKSpriteNode
        XCTAssertEqual(waterTowerSprite?.xScale ?? -1, 0.64, accuracy: 0.001)
        XCTAssertEqual(waterTowerSprite?.yScale ?? -1, 0.64, accuracy: 0.001)
    }

    @MainActor
    func testAuthoredParkCompositionRendersAboveItsGroundingFoundation() throws {
        let renderer = LotRenderer(style: WorldVisualStyle(), assets: WorldAssetCatalog())
        let park = CityTile(
            coordinate: GridCoordinate(x: 8, y: 8),
            kind: .park,
            condition: 1,
            constructionProgress: 1
        )
        let root = renderer.makeLot(
            for: park,
            adjacentRoads: .south,
            detail: .block,
            reducedMotion: true
        )
        let authored = try XCTUnwrap(
            root.childNode(withName: "//lot.generated-v4.park_l01.block") as? SKSpriteNode
        )
        let foundation = try XCTUnwrap(
            root.childNode(withName: "//lot.lod.city.mass.park") as? SKShapeNode
        )

        XCTAssertGreaterThan(authored.zPosition, foundation.zPosition)
        XCTAssertNotNil(authored.texture)
        XCTAssertGreaterThan(authored.frame.width, 60)
        XCTAssertGreaterThan(authored.frame.height, 31)
        XCTAssertEqual(authored.xScale, 0.96, accuracy: 0.001)
        XCTAssertEqual(authored.yScale, 0.96, accuracy: 0.001)
        let fullTextureSize = try XCTUnwrap(authored.texture?.size())
        XCTAssertGreaterThan(fullTextureSize.width, 60)
        XCTAssertGreaterThan(fullTextureSize.height, 32)
        XCTAssertGreaterThan(authored.size.width, 60)
        XCTAssertGreaterThan(authored.size.height, 32)
        XCTAssertGreaterThanOrEqual(
            authored.frame.width,
            authored.size.width * authored.xScale
        )
        XCTAssertGreaterThanOrEqual(
            authored.frame.height,
            authored.size.height * authored.yScale
        )
        XCTAssertFalse(containsCropNode(in: root))
        XCTAssertNil(root.childNode(withName: "//lot.park.source-edge-mask"))
        XCTAssertNil(root.childNode(withName: "//lot.park.source-edge-ground-blend"))
        XCTAssertFalse(descendantNames(in: root).contains { $0.hasPrefix("lot.place.") })
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
    func testCorridorAmbientLifeHasBoundedConnectedContextAndIsReduceMotionSafe() {
        let style = WorldVisualStyle()
        let renderer = AmbientLifeRenderer(style: style, assets: WorldAssetCatalog())
        let state = CityGameState.newCity(seed: 42)
        let snapshot = try! CityPresentationSnapshot(state: state)
        let animated = renderer.makeCorridorLife(
            in: state,
            consequences: snapshot.spatialConsequences,
            detail: .block,
            reducedMotion: false
        )
        let reduced = renderer.makeCorridorLife(
            in: state,
            consequences: snapshot.spatialConsequences,
            detail: .block,
            reducedMotion: true
        )
        let repeated = renderer.makeCorridorLife(
            in: state,
            consequences: snapshot.spatialConsequences,
            detail: .block,
            reducedMotion: true
        )
        let city = renderer.makeCorridorLife(
            in: state,
            consequences: snapshot.spatialConsequences,
            detail: .city,
            reducedMotion: true
        )

        let animatedNames = descendantNames(in: animated)
        let reducedNames = descendantNames(in: reduced)
        XCTAssertEqual(reducedNames, descendantNames(in: repeated))
        for names in [animatedNames, reducedNames] {
            XCTAssertEqual(names.filter { $0.hasPrefix("world.ambient.vignette.") }.count, 3)
            XCTAssertEqual(names.filter {
                let components = $0.split(separator: ".")
                return components.count == 6
                    && $0.hasPrefix("world.activity.street.local-activity.")
            }.count, 2)
            XCTAssertEqual(names.filter {
                let components = $0.split(separator: ".")
                return components.count == 6
                    && $0.hasPrefix("world.activity.place.local-activity.")
            }.count, 1)
            XCTAssertEqual(
                names.filter {
                    $0 == "world.ambient.vegetation-cluster.0"
                        || $0 == "world.ambient.vegetation-cluster.4"
                }.count,
                2
            )
            let furniture = names.filter {
                let components = $0.split(separator: ".")
                return components.count == 6
                    && components[0] == "world"
                    && components[1] == "public-realm"
                    && components[2] == "street-furniture"
            }
            XCTAssertEqual(furniture.count, 3)
            XCTAssertEqual(
                Set(furniture.map { $0.split(separator: ".")[3] }),
                Set(["wood-bench", "stone-planter", "cycle-rack"])
            )
            for name in furniture {
                let components = name.split(separator: ".")
                let x = Int(components[components.count - 2])
                let y = Int(components[components.count - 1])
                let coordinate = GridCoordinate(x: try! XCTUnwrap(x), y: try! XCTUnwrap(y))
                XCTAssertEqual(state.tile(at: coordinate)?.kind, .road)
            }
            let vacantCompositions = names.filter {
                let components = $0.split(separator: ".")
                return components.count == 6
                    && components[0] == "world"
                    && components[1] == "environment"
                    && components[2] == "vacant-composition"
            }
            XCTAssertEqual(vacantCompositions.count, 8)
            let vacantIdentities = Set(vacantCompositions.map {
                $0.split(separator: ".")[3]
            })
            XCTAssertEqual(
                vacantIdentities,
                Set(["meadow", "shrub-patch", "single-grove", "asymmetric-copse"])
            )
            let generatedGroveCompositions = vacantCompositions.filter {
                let identity = $0.split(separator: ".")[3]
                return identity == "single-grove" || identity == "asymmetric-copse"
            }
            XCTAssertLessThanOrEqual(generatedGroveCompositions.count, 2)
            XCTAssertEqual(
                names.filter {
                    $0.hasPrefix("world.environment.vacant-composition.")
                        && $0.hasSuffix(".ground-contact")
                }.count,
                generatedGroveCompositions.count
            )
            XCTAssertEqual(
                names.filter { $0.hasSuffix(".undeveloped-meadow") }.count,
                vacantCompositions.count
            )
            var identityByCoordinate: [GridCoordinate: Substring] = [:]
            for name in vacantCompositions {
                let components = name.split(separator: ".")
                let x = Int(components[components.count - 2])
                let y = Int(components[components.count - 1])
                let coordinate = GridCoordinate(x: try! XCTUnwrap(x), y: try! XCTUnwrap(y))
                identityByCoordinate[coordinate] = components[3]
                XCTAssertEqual(state.tile(at: coordinate)?.kind, .empty)
                let roadDistance = state.tiles.filter { $0.kind == .road }.map {
                    abs($0.coordinate.x - coordinate.x) + abs($0.coordinate.y - coordinate.y)
                }.min()
                XCTAssertGreaterThanOrEqual(roadDistance ?? 0, 2)
            }
            for first in identityByCoordinate {
                for second in identityByCoordinate
                where first.key != second.key && first.value == second.value {
                    let distance = abs(first.key.x - second.key.x)
                        + abs(first.key.y - second.key.y)
                    XCTAssertGreaterThan(distance, 3)
                }
            }
        }
        XCTAssertFalse(
            descendantNames(in: city).contains {
                $0.hasPrefix("world.public-realm.street-furniture.")
            }
        )
        let landscape = try! XCTUnwrap(
            reduced.childNode(withName: "//world.environment.vacant-landscape")
        )
        for composition in landscape.children {
            guard let name = composition.name else {
                XCTFail("Vacant landscape composition must retain its coordinate identity")
                continue
            }
            let components = name.split(separator: ".")
            let coordinate = GridCoordinate(
                x: try! XCTUnwrap(Int(components[components.count - 2])),
                y: try! XCTUnwrap(Int(components[components.count - 1]))
            )
            let center = style.isoPosition(coordinate)
            XCTAssertNotEqual(composition.position, center)
            XCTAssertLessThanOrEqual(abs(composition.position.x - center.x), 8)
            XCTAssertLessThanOrEqual(abs(composition.position.y - center.y), 3)
        }
        let furnitureNames = reducedNames.filter {
            let components = $0.split(separator: ".")
            return components.count == 6
                && components[0] == "world"
                && components[1] == "public-realm"
                && components[2] == "street-furniture"
        }
        var furnitureFootprints: [CGRect] = []
        for name in furnitureNames {
            let components = name.split(separator: ".")
            let coordinate = GridCoordinate(
                x: try! XCTUnwrap(Int(components[components.count - 2])),
                y: try! XCTUnwrap(Int(components[components.count - 1]))
            )
            let furniture = try! XCTUnwrap(reduced.childNode(withName: "//\(name)"))
            let roadCenter = style.isoPosition(coordinate)
            let direction = CGPoint(x: cos(furniture.zRotation), y: sin(furniture.zRotation))
            let perpendicular = CGPoint(x: -direction.y, y: direction.x)
            let alongOffsets: [CGFloat] = [-6, 6]
            let acrossOffsets: [CGFloat] = [-1.25, 1.25]
            var corners: [CGPoint] = []
            for along in alongOffsets {
                for across in acrossOffsets {
                    let alongPoint = CGPoint(
                        x: direction.x * along,
                        y: direction.y * along
                    )
                    let acrossPoint = CGPoint(
                        x: perpendicular.x * across,
                        y: perpendicular.y * across
                    )
                    corners.append(CGPoint(
                        x: furniture.position.x + alongPoint.x + acrossPoint.x,
                        y: furniture.position.y + alongPoint.y + acrossPoint.y
                    ))
                }
            }
            let connections = RoadConnectionMask.resolving(at: coordinate, in: state)
            XCTAssertFalse(connections.isEmpty)
            for point in corners {
                let local = CGPoint(x: point.x - roadCenter.x, y: point.y - roadCenter.y)
                let coreDistances = connections.edges.map {
                    pointSegmentDistanceForTesting(local, end: style.roadSocket(for: $0))
                }
                XCTAssertGreaterThanOrEqual(coreDistances.min() ?? 0, 9.1)
                XCTAssertLessThanOrEqual(coreDistances.min() ?? .infinity, 13.5)
                let normalizedX = abs(local.x) / (style.tileWidth / 2)
                let normalizedY = abs(local.y) / (style.tileHeight / 2)
                XCTAssertLessThanOrEqual(
                    normalizedX + normalizedY,
                    0.96
                )
                for edge in connections.edges {
                    let socket = style.roadSocket(for: edge)
                    XCTAssertGreaterThanOrEqual(
                        hypot(local.x - socket.x, local.y - socket.y),
                        3.0
                    )
                }
                for tile in state.tiles
                where tile.kind != .empty && tile.kind != .road {
                    let buildingCenter = style.isoPosition(tile.coordinate)
                    let buildingLocal = CGPoint(
                        x: point.x - buildingCenter.x,
                        y: point.y - buildingCenter.y
                    )
                    XCTAssertGreaterThan(
                        abs(buildingLocal.x) / 34 + abs(buildingLocal.y) / 17,
                        1.0
                    )
                }
            }
            let xs = corners.map(\.x)
            let ys = corners.map(\.y)
            furnitureFootprints.append(CGRect(
                x: xs.min() ?? 0,
                y: ys.min() ?? 0,
                width: (xs.max() ?? 0) - (xs.min() ?? 0),
                height: (ys.max() ?? 0) - (ys.min() ?? 0)
            ))
        }
        for index in furnitureFootprints.indices {
            for sibling in furnitureFootprints.indices where sibling > index {
                XCTAssertFalse(furnitureFootprints[index].intersects(furnitureFootprints[sibling]))
            }
        }
        XCTAssertFalse(animatedNames.contains { $0.hasPrefix("lot.ambient.") })
        XCTAssertFalse(animatedNames.contains { $0.contains(".banner") || $0.contains(".windsock") })
        XCTAssertLessThanOrEqual(recursiveActiveActionCount(animated), 2)
        let pedestrian = animated.childNode(withName: "//world.activity.street.local-activity.*")
        let stroll = pedestrian?.action(forKey: "ambient.local-activity")
        XCTAssertNotNil(stroll)
        XCTAssertGreaterThanOrEqual(stroll?.duration ?? 0, 14.4)
        XCTAssertLessThanOrEqual(stroll?.duration ?? .infinity, 15.2)
        XCTAssertEqual(recursiveActiveActionCount(reduced), 0)
        XCTAssertTrue(descendantLabels(in: animated).isEmpty)
        XCTAssertTrue(descendantLabels(in: reduced).isEmpty)
    }

    @MainActor
    func testTypedLocalActivityIsDeterministicBoundedTruthSafeAndSuppressesNilOrZero() {
        let style = WorldVisualStyle()
        let renderer = AmbientLifeRenderer(style: style, assets: WorldAssetCatalog())
        let state = CityGameState.newCity(seed: 42)
        let snapshot = try! CityPresentationSnapshot(state: state)
        let block = renderer.activityPlacements(
            in: state,
            consequences: snapshot.spatialConsequences,
            detail: .block
        )
        let repeated = renderer.activityPlacements(
            in: state,
            consequences: snapshot.spatialConsequences,
            detail: .block
        )
        let city = renderer.activityPlacements(
            in: state,
            consequences: snapshot.spatialConsequences,
            detail: .city
        )

        XCTAssertEqual(block, repeated)
        XCTAssertLessThanOrEqual(block.count, 3)
        XCTAssertLessThanOrEqual(city.count, 2)
        XCTAssertEqual(block.filter { $0.domain == .street }.count, 2)
        XCTAssertEqual(block.filter { $0.domain == .place }.count, 1)
        XCTAssertEqual(Set(block.map(\.surfaceCoordinate)).count, block.count)
        for placement in block {
            XCTAssertGreaterThan(placement.intensity, 0)
            XCTAssertLessThanOrEqual(placement.intensity, 1)
            XCTAssertEqual(state.tile(at: placement.surfaceCoordinate)?.kind, .road)
            let roadCenter = style.isoPosition(placement.surfaceCoordinate)
            let local = CGPoint(
                x: placement.position.x - roadCenter.x,
                y: placement.position.y - roadCenter.y
            )
            let normalizedX = abs(local.x) / (style.tileWidth / 2)
            let normalizedY = abs(local.y) / (style.tileHeight / 2)
            XCTAssertLessThanOrEqual(normalizedX + normalizedY, 0.96)
            let connections = RoadConnectionMask.resolving(
                at: placement.surfaceCoordinate,
                in: state
            )
            XCTAssertFalse(connections.isEmpty)
            XCTAssertGreaterThanOrEqual(
                connections.edges.map {
                    pointSegmentDistanceForTesting(local, end: style.roadSocket(for: $0))
                }.min() ?? 0,
                9.1
            )
            if placement.domain == .place {
                let source = try! XCTUnwrap(state.tile(at: placement.sourceCoordinate))
                XCTAssertNotEqual(source.kind, .empty)
                XCTAssertNotEqual(source.kind, .road)
                XCTAssertGreaterThanOrEqual(source.constructionProgress, 1)
            }
        }

        for value: Double? in [nil, 0] {
            let suppressed = renderer.activityPlacements(
                in: state,
                detail: .block,
                streetActivityIndex: { _ in value },
                placeActivityIndex: { _ in value }
            )
            XCTAssertTrue(suppressed.isEmpty)
        }
    }

    @MainActor
    func testTypedLocalActivityReusesAmbientTreeUntilItsVisibleBandChanges() {
        var state = CityGameState.newCity(seed: 42)
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        let initialRebuildCount = scene.ambientRebuildCountForTesting

        for _ in 0..<10 {
            CitySimulation.step(&state)
            scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        }

        XCTAssertLessThanOrEqual(
            scene.ambientRebuildCountForTesting - initialRebuildCount,
            1,
            "Raw activity-index drift must not rebuild the bounded ambient tree"
        )
    }

    @MainActor
    func testTypedLocalActivitySwitchesToCurrentHighestBandSourceExactlyOnce() throws {
        let state = CityGameState.newCity(seed: 42)
        let snapshot = try CityPresentationSnapshot(state: state)
        let renderer = AmbientLifeRenderer(
            style: WorldVisualStyle(),
            assets: WorldAssetCatalog()
        )
        let eligible = renderer.activityPlacements(
            in: state,
            detail: .block,
            streetActivityIndex: { coordinate in
                state.tile(at: coordinate)?.kind == .road ? 0.5 : nil
            },
            placeActivityIndex: { _ in nil }
        )
        let firstSource = try XCTUnwrap(eligible.first?.sourceCoordinate)
        let secondSource = try XCTUnwrap(
            eligible.first(where: { $0.sourceCoordinate != firstSource })?.sourceCoordinate
        )
        let initial = renderer.activityPlacements(
            in: state,
            detail: .city,
            streetActivityIndex: { coordinate in
                if coordinate == firstSource { return 0.9 }
                if coordinate == secondSource { return 0.5 }
                return nil
            },
            placeActivityIndex: { _ in nil }
        )
        let switched = renderer.activityPlacements(
            in: state,
            detail: .city,
            streetActivityIndex: { coordinate in
                if coordinate == firstSource { return 0.5 }
                if coordinate == secondSource { return 0.9 }
                return nil
            },
            placeActivityIndex: { _ in nil }
        )
        XCTAssertEqual(initial.map(\.sourceCoordinate), [firstSource])
        XCTAssertEqual(switched.map(\.sourceCoordinate), [secondSource])

        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        XCTAssertTrue(scene.reconcileAmbientActivityForTesting(
            snapshot: snapshot,
            placements: initial
        ))
        let initialRebuildCount = scene.ambientRebuildCountForTesting
        let initialGroundRebuildCount = scene.ambientGroundRebuildCountForTesting
        let initialName = "world.activity.street.local-activity."
            + "\(firstSource.x).\(firstSource.y)"
        XCTAssertEqual(scene.renderedActivityNamesForTesting, [initialName])

        XCTAssertFalse(scene.reconcileAmbientActivityForTesting(
            snapshot: snapshot,
            placements: initial
        ))
        XCTAssertTrue(scene.reconcileAmbientActivityForTesting(
            snapshot: snapshot,
            placements: switched
        ))
        XCTAssertFalse(scene.reconcileAmbientActivityForTesting(
            snapshot: snapshot,
            placements: switched
        ))
        let switchedName = "world.activity.street.local-activity."
            + "\(secondSource.x).\(secondSource.y)"
        XCTAssertEqual(scene.renderedActivityNamesForTesting, [switchedName])
        XCTAssertEqual(
            scene.ambientRebuildCountForTesting - initialRebuildCount,
            1,
            "A changed authoritative highest-band source must replace the rendered actor once"
        )
        XCTAssertEqual(
            scene.ambientGroundRebuildCountForTesting,
            initialGroundRebuildCount,
            "Activity-only changes must reuse the identical developed-ground tree"
        )
    }

    @MainActor
    func testLotContextIsDeterministicTruthBoundedAndProtectsFrontage() {
        let style = WorldVisualStyle()
        let renderer = LotContextRenderer(style: style)
        let cases: [(BuildingKind, RoadConnectionMask, Set<LotContextRenderer.PlacementRole>)] = [
            (.residential, .north, [.plantingBed, .lamp]),
            (.commercial, .east, [.parkingBay, .wayfinding]),
            (.industrial, .south, [.serviceYard, .serviceProp, .lamp]),
            (.cityHall, .west, [.civicForecourt, .lamp, .wayfinding]),
            (.park, .south, [.parkTerrace, .bench, .wayfinding]),
        ]

        for (index, entry) in cases.enumerated() {
            let tile = CityTile(
                coordinate: GridCoordinate(x: 8 + index, y: 10 + index),
                kind: entry.0,
                level: 1
            )
            let first = renderer.placementLedger(
                for: tile,
                adjacentRoads: entry.1,
                selectedFrontage: entry.1
            )
            let repeated = renderer.placementLedger(
                for: tile,
                adjacentRoads: entry.1,
                selectedFrontage: entry.1
            )
            XCTAssertEqual(first, repeated)
            XCTAssertEqual(Set(first.map(\.role)), entry.2)

            let socket = style.roadSocket(for: entry.1)
            let entrance = CGPoint(x: 0, y: -13.5)
            for placement in first {
                XCTAssertLessThanOrEqual(
                    abs(placement.center.x) / (style.tileWidth / 2)
                        + abs(placement.center.y) / (style.tileHeight / 2),
                    0.93,
                    "\(entry.0) \(placement.role) must remain inside the authoritative lot"
                )
                XCTAssertLessThanOrEqual(placement.size.width, 29)
                XCTAssertLessThanOrEqual(placement.size.height, 9)
                if !placement.groundOnly {
                    XCTAssertGreaterThanOrEqual(
                        pointSegmentDistanceForTesting(
                            CGPoint(
                                x: placement.center.x - entrance.x,
                                y: placement.center.y - entrance.y
                            ),
                            end: CGPoint(
                                x: socket.x - entrance.x,
                                y: socket.y - entrance.y
                            )
                        ),
                        4.5,
                        "\(entry.0) \(placement.role) must not obstruct the entrance/frontage path"
                    )
                }
            }

            let roadless = renderer.placementLedger(
                for: tile,
                adjacentRoads: [],
                selectedFrontage: nil
            )
            XCTAssertTrue(
                roadless.isEmpty,
                "Road-facing parking, yards, lamps, and signage must not invent a frontage"
            )
        }

        let tile = CityTile(
            coordinate: GridCoordinate(x: 15, y: 12),
            kind: .industrial,
            level: 1,
            constructionProgress: 1
        )
        let beforeCount = LotContextRenderer.cachedTemplateCountForTesting
        let firstCity = SKNode()
        let firstNeighborhood = SKNode()
        let firstBlock = SKNode()
        renderer.addContext(
            for: tile,
            adjacentRoads: [.south],
            selectedFrontage: .south,
            city: firstCity,
            neighborhood: firstNeighborhood,
            block: firstBlock
        )
        let afterFirstCount = LotContextRenderer.cachedTemplateCountForTesting

        let secondCity = SKNode()
        let secondNeighborhood = SKNode()
        let secondBlock = SKNode()
        renderer.addContext(
            for: tile,
            adjacentRoads: [.south],
            selectedFrontage: .south,
            city: secondCity,
            neighborhood: secondNeighborhood,
            block: secondBlock
        )

        XCTAssertGreaterThanOrEqual(afterFirstCount, beforeCount)
        XCTAssertLessThanOrEqual(afterFirstCount - beforeCount, 1)
        XCTAssertEqual(LotContextRenderer.cachedTemplateCountForTesting, afterFirstCount)
        XCTAssertEqual(firstCity.children.map(\.name), secondCity.children.map(\.name))
        XCTAssertEqual(
            firstNeighborhood.children.map(\.name),
            secondNeighborhood.children.map(\.name)
        )
        XCTAssertEqual(firstBlock.children.map(\.name), secondBlock.children.map(\.name))
        XCTAssertFalse(firstCity.children.isEmpty)
        XCTAssertFalse(firstNeighborhood.children.isEmpty)
        XCTAssertFalse(firstBlock.children.isEmpty)
        XCTAssertFalse(firstCity.children[0] === secondCity.children[0])
        firstCity.children[0].alpha = 0
        XCTAssertEqual(secondCity.children[0].alpha, 1)
        XCTAssertLessThanOrEqual(
            LotContextRenderer.cachedTemplateCountForTesting,
            5 * 4 * 5
        )
    }

    @MainActor
    func testCompletedLotsExposeDistinctCityNeighborhoodAndBlockContextWithoutLabelsOrActions() {
        let style = WorldVisualStyle()
        let renderer = LotRenderer(style: style, assets: WorldAssetCatalog())
        let cases: [(BuildingKind, String, String)] = [
            (.residential, "residential", "planting-bed"),
            (.commercial, "commercial", "parking-bay"),
            (.industrial, "industrial", "service-yard"),
            (.cityHall, "civic", "civic-forecourt"),
            (.park, "park", "park-terrace"),
        ]

        for (index, entry) in cases.enumerated() {
            let tile = CityTile(
                coordinate: GridCoordinate(x: 6 + index, y: 8),
                kind: entry.0,
                level: 1,
                constructionProgress: 1
            )
            let block = renderer.makeLot(
                for: tile,
                adjacentRoads: .south,
                detail: .block,
                reducedMotion: true
            )
            let repeated = renderer.makeLot(
                for: tile,
                adjacentRoads: .south,
                detail: .block,
                reducedMotion: true
            )
            let city = renderer.makeLot(
                for: tile,
                adjacentRoads: .south,
                detail: .city,
                reducedMotion: true
            )
            let blockNames = descendantNames(in: block)
            XCTAssertEqual(blockNames, descendantNames(in: repeated))
            XCTAssertTrue(
                blockNames.contains {
                    $0.hasPrefix("lot.context.city.\(entry.1).material.")
                }
            )
            XCTAssertTrue(
                blockNames.contains {
                    $0 == "lot.lod.neighborhood.public-realm.\(entry.1)"
                }
            )
            XCTAssertTrue(
                blockNames.contains {
                    $0.contains("lot.context.\(entry.1).\(entry.2)")
                }
            )
            XCTAssertTrue(
                descendantNames(in: city).contains {
                    $0.hasPrefix("lot.context.city.\(entry.1).material.")
                }
            )
            XCTAssertTrue(descendantLabels(in: block).isEmpty)
            XCTAssertEqual(recursiveActiveActionCount(block), 0)
        }

        let underConstruction = renderer.makeLot(
            for: CityTile(
                coordinate: GridCoordinate(x: 4, y: 5),
                kind: .industrial,
                constructionProgress: 0.5
            ),
            adjacentRoads: .south,
            detail: .block,
            reducedMotion: true
        )
        XCTAssertFalse(
            descendantNames(in: underConstruction).contains {
                $0.hasPrefix("lot.context.")
            },
            "Completed-lot parking and service context must not appear during active construction"
        )
    }

    @MainActor
    func testCompactSceneKeepsAmbientMeaningWithoutMotionResidency() {
        let state = CityGameState.newCity(seed: 42)
        let regular = CityScene(size: CGSize(width: 1_280, height: 800))
        regular.reducedMotion = false
        regular.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertTrue(regular.ambientMotionEnabledForTesting)
        XCTAssertEqual(regular.ambientActionCountForTesting, 2)

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
        XCTAssertEqual(scene.tileRootIsAttachedForTesting(at: GridCoordinate(x: 20, y: 20)), false)
        XCTAssertEqual(scene.tileRootIsAttachedForTesting(at: GridCoordinate(x: 0, y: 0)), true)
        XCTAssertEqual(scene.tileRootIsAttachedForTesting(at: GridCoordinate(x: 10, y: 11)), true)
        for coordinate in [GridCoordinate(x: 0, y: 0), GridCoordinate(x: 4, y: 12), GridCoordinate(x: 20, y: 20)] {
            XCTAssertEqual(
                scene.resolvedCoordinateForTesting(at: scene.scenePointForTesting(at: coordinate)),
                coordinate
            )
        }

        let backdrop = renderer.makeBackdrop(gridWidth: 24, gridHeight: 24)
        let backdropNames = descendantNames(in: backdrop)
        XCTAssertTrue(backdropNames.contains("terrain.macro.turf"))
        XCTAssertEqual(
            backdropNames.filter { $0.hasPrefix("terrain.macro.material.patch.") }.count,
            121
        )
        XCTAssertGreaterThan(
            backdropNames.filter { $0.hasPrefix("terrain.macro.meadow.patch.") }.count,
            15
        )
        XCTAssertGreaterThan(
            backdropNames.filter { $0.hasPrefix("terrain.macro.furrows.") }.count,
            10
        )
        var maximumMaterialPatchSize = CGSize.zero
        backdrop.enumerateChildNodes(withName: "//terrain.macro.material.patch.*") { node, _ in
            guard let shape = node as? SKShapeNode,
                  let bounds = shape.path?.boundingBoxOfPath else { return }
            maximumMaterialPatchSize.width = max(maximumMaterialPatchSize.width, bounds.width)
            maximumMaterialPatchSize.height = max(maximumMaterialPatchSize.height, bounds.height)
        }
        XCTAssertLessThanOrEqual(maximumMaterialPatchSize.width, 72 * 3.2)
        XCTAssertLessThanOrEqual(maximumMaterialPatchSize.height, 36 * 2.1)
        var furrowNodes: [SKShapeNode] = []
        backdrop.enumerateChildNodes(withName: "//terrain.macro.furrows.*") { node, _ in
            if let shape = node as? SKShapeNode { furrowNodes.append(shape) }
        }
        XCTAssertFalse(furrowNodes.isEmpty)
        var maximumFurrowSegmentLength: CGFloat = 0
        for node in furrowNodes {
            var lastMove: CGPoint?
            node.path?.applyWithBlock { elementPointer in
                let element = elementPointer.pointee
                switch element.type {
                case .moveToPoint:
                    lastMove = element.points[0]
                case .addLineToPoint:
                    if let lastMove {
                        maximumFurrowSegmentLength = max(
                            maximumFurrowSegmentLength,
                            hypot(
                                element.points[0].x - lastMove.x,
                                element.points[0].y - lastMove.y
                            )
                        )
                    }
                default:
                    break
                }
            }
        }
        XCTAssertLessThanOrEqual(maximumFurrowSegmentLength, 45)
        XCTAssertFalse(backdropNames.contains { $0.hasPrefix("terrain.macro.parcel.") })
        XCTAssertFalse(backdropNames.contains { $0.hasPrefix("terrain.macro.boundary.") })
        XCTAssertFalse(backdrop.children.contains { $0 is SKCropNode })
        XCTAssertEqual(recursiveActiveActionCount(backdrop), 0)

        let districtGround = renderer.makeDevelopedDistrictGround(in: state)
        let districtNames = descendantNames(in: districtGround)
        XCTAssertTrue(districtNames.contains("district.ground.shared-contact"))
        XCTAssertTrue(districtNames.contains("district.ground.authoritative-public-realm"))
        XCTAssertTrue(districtNames.contains("district.ground.frontage-links.contact"))
        XCTAssertTrue(districtNames.contains("district.ground.frontage-links.material"))
        XCTAssertTrue(districtNames.contains("district.ground.park-access.contact"))
        XCTAssertTrue(districtNames.contains("district.ground.park-access.material"))
        XCTAssertTrue(districtNames.contains("district.ground.service-access.contact"))
        XCTAssertTrue(districtNames.contains("district.ground.service-access.material"))
        XCTAssertTrue(districtNames.contains { $0.hasPrefix("district.ground.authoritative-parcels.") })
        XCTAssertTrue(
            districtNames.contains {
                $0.hasPrefix(
                    "district.ground.authoritative-parcels.park.internal-material."
                )
            }
        )
        XCTAssertTrue(
            districtNames.contains {
                $0.hasPrefix(
                    "district.ground.authoritative-parcels.park.surrounding-ground."
                )
            }
        )
        XCTAssertTrue(
            districtNames.contains {
                $0.hasPrefix(
                    "district.ground.service-campus.internal-material"
                )
            }
        )
        XCTAssertTrue(districtNames.contains("district.ground.service-campus.contact"))
        XCTAssertTrue(districtNames.contains("district.ground.service-campus.material"))
        XCTAssertEqual(recursiveActiveActionCount(districtGround), 0)
        XCTAssertTrue(
            scene.ambientEnvironmentNamesForTesting.contains(
                "world.environment.developed-district-ground"
            )
        )
    }

    @MainActor
    func testRoadEnclosedCommonsStayVacantAndJoinTheAuthoritativeFrontageNetwork() {
        let state = CityGameState.newCity(seed: 42)
        let renderer = TerrainRenderer(style: WorldVisualStyle())
        let authoritativeRoads = Set(
            state.tiles.filter { $0.kind == .road }.map(\.coordinate)
        )
        let frontageRoads = renderer.connectedFrontageRoadCoordinatesForTesting(in: state)
        XCTAssertEqual(frontageRoads, authoritativeRoads)
        XCTAssertEqual(frontageRoads.count, 32)

        let commons = renderer.enclosedVacantCoordinatesForTesting(in: state)
        XCTAssertEqual(commons.count, 15)
        XCTAssertTrue(commons.allSatisfy { state.tile(at: $0)?.kind == .empty })
        XCTAssertFalse(commons.contains(GridCoordinate(x: 11, y: 11)))
        XCTAssertFalse(commons.contains(GridCoordinate(x: 13, y: 11)))

        let city = renderer.makeDevelopedDistrictGround(in: state, detail: .city)
        let cityNames = descendantNames(in: city)
        XCTAssertEqual(
            cityNames.filter { $0.hasPrefix("district.commons.natural-meadow.") }.count,
            2
        )
        XCTAssertEqual(
            cityNames.filter { $0.hasPrefix("district.commons.natural-texture.") }.count,
            3
        )
        XCTAssertEqual(
            cityNames.filter { $0.hasPrefix("district.commons.existing-foliage.") }.count,
            1
        )
        XCTAssertFalse(cityNames.contains { $0.contains("plaza") })
        XCTAssertFalse(cityNames.contains { $0.contains("path") })
        XCTAssertFalse(cityNames.contains { $0.contains("bench") })
        XCTAssertFalse(cityNames.contains { $0.contains("road") })
        XCTAssertFalse(cityNames.contains { $0.contains("building") })
        XCTAssertTrue(city.childNode(withName: "detail.city")?.isHidden == false)
        XCTAssertTrue(city.childNode(withName: "detail.neighborhood")?.isHidden == true)
        XCTAssertTrue(city.childNode(withName: "detail.block")?.isHidden == true)

        let neighborhood = renderer.makeDevelopedDistrictGround(
            in: state,
            detail: .neighborhood
        )
        XCTAssertTrue(
            descendantNames(in: neighborhood).contains {
                $0.hasPrefix("district.commons.natural-texture.")
            }
        )
        XCTAssertTrue(neighborhood.childNode(withName: "detail.city")?.isHidden == false)
        XCTAssertTrue(neighborhood.childNode(withName: "detail.neighborhood")?.isHidden == false)
        XCTAssertTrue(neighborhood.childNode(withName: "detail.block")?.isHidden == true)

        let block = renderer.makeDevelopedDistrictGround(in: state, detail: .block)
        XCTAssertEqual(recursiveActiveActionCount(block), 0)
        XCTAssertTrue(descendantLabels(in: block).isEmpty)
        XCTAssertLessThan(block.calculateAccumulatedFrame().width, 1_000)
        XCTAssertLessThan(block.calculateAccumulatedFrame().height, 600)

        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let buildableCoordinate = try? XCTUnwrap(
            commons.sorted { ($0.y, $0.x) < ($1.y, $1.x) }.first {
                guard case .success = CitySimulation.validateBuild(
                    .residential,
                    at: $0,
                    in: state
                ) else {
                    return false
                }
                return scene.resolvedCoordinateForTesting(
                    at: scene.scenePointForTesting(at: $0)
                ) == $0
            }
        )
        XCTAssertNotNil(buildableCoordinate)
        if let buildableCoordinate,
           let tile = state.tile(at: buildableCoordinate) {
            let originalRoot = scene.tileRootIdentifier(at: buildableCoordinate)
            XCTAssertEqual(
                scene.resolvedCoordinateForTesting(
                    at: scene.scenePointForTesting(at: buildableCoordinate)
                ),
                buildableCoordinate
            )

            scene.render(
                state: state,
                overlay: .pollution,
                selection: buildableCoordinate,
                interactionMode: .inspect
            )
            XCTAssertEqual(scene.tileRootIdentifier(at: buildableCoordinate), originalRoot)
            XCTAssertFalse(scene.selectionIsHiddenForTesting)

            let target = CityMapActionTargetPresentation(
                coordinate: buildableCoordinate,
                primaryAction: CityMapPrimaryActionPresentation.make(
                    interactionMode: .build(.residential),
                    tile: tile,
                    state: state
                )
            )
            scene.render(
                state: state,
                overlay: .none,
                selection: buildableCoordinate,
                interactionMode: .build(.residential),
                activeActionTarget: target
            )
            XCTAssertEqual(scene.tileRootIdentifier(at: buildableCoordinate), originalRoot)
            XCTAssertEqual(
                scene.interactionNamesForTesting.filter {
                    $0 == "interaction.placementGhost"
                }.count,
                1
            )
        }
    }

    @MainActor
    func testStarterUtilityCampusGroundBridgesRealAnchorsAndAccessWithoutChangingBuildTruth() {
        let state = CityGameState.newCity(seed: 42)
        let renderer = TerrainRenderer(style: WorldVisualStyle())
        let campus = renderer.serviceCampusGroundCoordinatesForTesting(in: state)
        XCTAssertEqual(campus, Set([
            GridCoordinate(x: 14, y: 11),
            GridCoordinate(x: 13, y: 12),
            GridCoordinate(x: 14, y: 12),
            GridCoordinate(x: 15, y: 12),
            GridCoordinate(x: 13, y: 13),
            GridCoordinate(x: 14, y: 13),
            GridCoordinate(x: 15, y: 13),
        ]))

        var visited = Set<GridCoordinate>()
        var pending = [GridCoordinate(x: 13, y: 13)]
        while let coordinate = pending.popLast() {
            guard campus.contains(coordinate),
                  visited.insert(coordinate).inserted else { continue }
            pending.append(contentsOf: [
                GridCoordinate(x: coordinate.x + 1, y: coordinate.y),
                GridCoordinate(x: coordinate.x - 1, y: coordinate.y),
                GridCoordinate(x: coordinate.x, y: coordinate.y + 1),
                GridCoordinate(x: coordinate.x, y: coordinate.y - 1),
            ])
        }
        XCTAssertEqual(visited, campus)

        let bridge = GridCoordinate(x: 14, y: 13)
        XCTAssertEqual(state.tile(at: bridge)?.kind, .empty)
        if case .failure(let reason) = CitySimulation.validateBuild(
            .residential,
            at: bridge,
            in: state
        ) {
            XCTFail("Renderer-only campus bridge must preserve buildability: \(reason)")
        }

        let ground = renderer.makeDevelopedDistrictGround(in: state)
        let names = descendantNames(in: ground)
        XCTAssertTrue(names.contains("district.ground.service-campus.contact"))
        XCTAssertTrue(names.contains("district.ground.service-campus.material"))
        XCTAssertTrue(names.contains("district.ground.service-campus.internal-material"))
        XCTAssertEqual(recursiveActiveActionCount(ground), 0)
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
        let defaultPriorityOccupancy = defaultScene.cameraPriorityViewportOccupancyForTesting()
        XCTAssertGreaterThanOrEqual(defaultOccupancy.width, 0.60)
        XCTAssertLessThanOrEqual(defaultOccupancy.width, 0.61)
        XCTAssertGreaterThanOrEqual(defaultPriorityOccupancy.width, 1.04)
        XCTAssertLessThanOrEqual(defaultPriorityOccupancy.width, 1.06)
        XCTAssertEqual(defaultScene.occupiedDevelopedVisualBoundsForTesting.width, 288, accuracy: 0.001)
        XCTAssertEqual(defaultScene.occupiedDevelopedVisualBoundsForTesting.height, 192.43652344, accuracy: 0.001)
        XCTAssertEqual(defaultScene.networkOpportunityVisualBoundsForTesting.width, 684, accuracy: 0.001)
        XCTAssertEqual(defaultScene.networkOpportunityVisualBoundsForTesting.height, 342, accuracy: 0.001)

        let compactInsets = CityMapViewportInsets(top: 138, leading: 19, bottom: 236, trailing: 19)
        let compactScene = CityScene(size: CGSize(width: 900, height: 600))
        compactScene.reducedMotion = true
        compactScene.updateViewportInsets(compactInsets)
        compactScene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(compactScene.currentCameraDetailLevel, .block)
        let compactOccupancy = compactScene.occupiedDevelopedViewportOccupancyForTesting()
        let compactPriorityOccupancy = compactScene.cameraPriorityViewportOccupancyForTesting()
        XCTAssertGreaterThanOrEqual(compactOccupancy.width, 0.60)
        XCTAssertLessThanOrEqual(compactOccupancy.width, 0.61)
        XCTAssertGreaterThanOrEqual(compactPriorityOccupancy.width, 1.04)
        XCTAssertLessThanOrEqual(compactPriorityOccupancy.width, 1.06)

        let defaultOffset = CGPoint(
            x: (defaultInsets.leading - defaultInsets.trailing) * defaultScene.cameraScaleForTesting / 2,
            y: (defaultInsets.bottom - defaultInsets.top) * defaultScene.cameraScaleForTesting / 2
        )
        XCTAssertEqual(
            defaultScene.cameraPositionForTesting.x,
            defaultScene.cameraPriorityVisualBoundsForTesting.midX - defaultOffset.x,
            accuracy: 0.001
        )
        XCTAssertEqual(
            defaultScene.cameraPositionForTesting.y,
            defaultScene.cameraPriorityVisualBoundsForTesting.midY - defaultOffset.y,
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
        let cityHallRoad = GridCoordinate(x: 12, y: 12)
        let cityHallRoadMask = RoadConnectionMask.resolving(at: cityHallRoad, in: state).rawValue
        XCTAssertEqual(cityHallRoadMask, 11)
        let defaultCityHallRoot = defaultScene.tileRootIdentifier(at: cityHall)
        XCTAssertTrue(defaultScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.block"))

        defaultScene.configureProofCamera(detail: .city, centeredOn: cityHall)
        let defaultCityScale = defaultScene.cameraScaleForTesting
        XCTAssertEqual(defaultScene.currentCameraDetailLevel, .city)
        XCTAssertGreaterThanOrEqual(
            defaultScene.cameraPriorityViewportOccupancyForTesting().width,
            0.67
        )
        XCTAssertTrue(defaultScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.city"))
        XCTAssertFalse(defaultScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.block"))
        let cityVisible = defaultScene.tileVisibleDescendantNamesForTesting(at: cityHall)
        XCTAssertTrue(cityVisible.contains("lot.lod.city.mass.cityHall"))
        XCTAssertFalse(cityVisible.contains { $0.hasPrefix("lot.frontage.") })
        XCTAssertFalse(cityVisible.contains { $0.hasPrefix("lot.lod.neighborhood.public-realm.") })
        XCTAssertFalse(cityVisible.contains { $0.hasPrefix("lot.lod.block.entrance.") })
        XCTAssertTrue(cityVisible.contains("lot.generated-v4.city_hall_l01.city"))
        XCTAssertTrue(defaultScene.tileVisibleDescendantNamesForTesting(
            at: cityHallRoad
        ).contains("road.generated-v4.\(cityHallRoadMask).city"))
        XCTAssertEqual(defaultScene.resolvedCoordinateForTesting(at: defaultScene.scenePointForTesting(at: cityHall)), cityHall)
        XCTAssertEqual(defaultScene.tileRootIdentifier(at: cityHall), defaultCityHallRoot)

        defaultScene.configureProofCamera(detail: .neighborhood, centeredOn: cityHall)
        let defaultNeighborhoodScale = defaultScene.cameraScaleForTesting
        XCTAssertEqual(defaultScene.currentCameraDetailLevel, .neighborhood)
        XCTAssertLessThan(defaultNeighborhoodScale, defaultCityScale)
        XCTAssertTrue(defaultScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.neighborhood"))
        let neighborhoodVisible = defaultScene.tileVisibleDescendantNamesForTesting(at: cityHall)
        XCTAssertTrue(neighborhoodVisible.contains { $0.hasPrefix("lot.frontage.") })
        XCTAssertTrue(neighborhoodVisible.contains("lot.lod.neighborhood.public-realm.civic"))
        XCTAssertFalse(neighborhoodVisible.contains { $0.hasPrefix("lot.lod.block.entrance.") })
        XCTAssertTrue(neighborhoodVisible.contains("lot.generated-v4.city_hall_l01.neighborhood"))
        XCTAssertTrue(defaultScene.tileVisibleDescendantNamesForTesting(
            at: cityHallRoad
        ).contains("road.generated-v4.\(cityHallRoadMask).neighborhood"))
        XCTAssertEqual(defaultScene.resolvedCoordinateForTesting(at: defaultScene.scenePointForTesting(at: cityHall)), cityHall)
        XCTAssertEqual(defaultScene.tileRootIdentifier(at: cityHall), defaultCityHallRoot)

        defaultScene.configureProofCamera(detail: .block, centeredOn: cityHall)
        XCTAssertEqual(defaultScene.currentCameraDetailLevel, .block)
        XCTAssertLessThan(defaultScene.cameraScaleForTesting, defaultNeighborhoodScale)
        XCTAssertTrue(defaultScene.tileDescendantNamesForTesting(at: cityHall)
            .contains("lot.generated-v4.city_hall_l01.block"))
        let blockVisible = defaultScene.tileVisibleDescendantNamesForTesting(at: cityHall)
        XCTAssertTrue(blockVisible.contains { $0.hasPrefix("lot.frontage.") })
        XCTAssertTrue(blockVisible.contains("lot.lod.neighborhood.public-realm.civic"))
        XCTAssertTrue(blockVisible.contains("lot.lod.block.entrance.cityHall"))
        XCTAssertTrue(blockVisible.contains("lot.generated-v4.city_hall_l01.block"))
        XCTAssertTrue(defaultScene.tileVisibleDescendantNamesForTesting(
            at: cityHallRoad
        ).contains("road.generated-v4.\(cityHallRoadMask).block"))
        XCTAssertEqual(defaultScene.resolvedCoordinateForTesting(at: defaultScene.scenePointForTesting(at: cityHall)), cityHall)
        XCTAssertEqual(defaultScene.tileRootIdentifier(at: cityHall), defaultCityHallRoot)

        let compactCityHallRoot = compactScene.tileRootIdentifier(at: cityHall)
        compactScene.configureProofCamera(detail: .city, centeredOn: cityHall)
        XCTAssertEqual(compactScene.currentCameraDetailLevel, .city)
        XCTAssertGreaterThanOrEqual(
            compactScene.cameraPriorityViewportOccupancyForTesting().width,
            0.78
        )
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
            defaultScene.cameraPriorityVisualBoundsForTesting.midX - defaultOffset.x,
            accuracy: 0.001
        )
        XCTAssertEqual(
            defaultScene.cameraPositionForTesting.y,
            defaultScene.cameraPriorityVisualBoundsForTesting.midY - defaultOffset.y,
            accuracy: 0.001
        )
    }

    @MainActor
    func testOpeningCameraRefitsOnceAfterTheShippingViewportSettles() {
        let insets = CityMapViewportInsets(top: 104, leading: 24, bottom: 160, trailing: 24)
        let scene = CityScene(size: CGSize(width: 420, height: 260))
        scene.reducedMotion = true
        scene.updateViewportInsets(insets)
        let opening = CityGameState.newCity(seed: 42)
        scene.render(state: opening, overlay: .none, selection: nil, interactionMode: .inspect)
        let provisionalScale = scene.cameraScaleForTesting

        // Model AppKit settling the SpriteKit viewport after the first
        // representable update without routing a player camera gesture.
        scene.size = CGSize(width: 1_280, height: 800)
        var firstPulse = opening
        firstPulse.updateTile(at: GridCoordinate(x: 10, y: 11)) {
            $0.occupancy += 1
        }
        scene.render(state: firstPulse, overlay: .none, selection: nil, interactionMode: .inspect)
        let settledScale = scene.cameraScaleForTesting
        XCTAssertLessThan(settledScale, provisionalScale)
        XCTAssertEqual(settledScale, 0.3896103799343109, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(
            scene.occupiedDevelopedViewportOccupancyForTesting().width,
            0.60
        )

        var secondPulse = firstPulse
        secondPulse.updateTile(at: GridCoordinate(x: 10, y: 11)) {
            $0.occupancy += 1
        }
        scene.render(state: secondPulse, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(scene.cameraScaleForTesting, settledScale, accuracy: 0.001)
    }

    @MainActor
    func testIndustrialStrainCameraPrioritizesTheDominantDistrictWithoutHidingRemoteTruth() throws {
        let fixture = try XCTUnwrap(
            try ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .industrialExpansion
                    && $0.definition.moment == .complication
            }
        )
        let state = fixture.state
        let remoteIndustry = GridCoordinate(x: 4, y: 8)
        let centralResidential = GridCoordinate(x: 9, y: 11)
        let centralWaterTower = GridCoordinate(x: 15, y: 13)
        XCTAssertEqual(state.tile(at: remoteIndustry)?.kind, .industrial)

        for (size, insets, expectedScale, expectedPriorityOccupancy) in [
            (
                CGSize(width: 1_280, height: 800),
                CityMapViewportInsets(top: 104, leading: 24, bottom: 160, trailing: 24),
                CGFloat(0.48701298236846924),
                CGSize(width: 0.8400000080108644, height: 0.8964179189966687)
            ),
            (
                CGSize(width: 900, height: 600),
                CityMapViewportInsets(top: 138, leading: 19, bottom: 236, trailing: 19),
                CGFloat(0.6549999713897705),
                CGSize(width: 0.8926516037877291, height: 1.5807607256708744)
            ),
        ] {
            let scene = CityScene(size: size)
            scene.reducedMotion = true
            scene.updateViewportInsets(insets)
            scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)

            XCTAssertEqual(scene.cameraPriorityCoordinatesForTesting.count, 8)
            XCTAssertFalse(scene.cameraPriorityCoordinatesForTesting.contains(remoteIndustry))
            XCTAssertTrue(scene.cameraPriorityCoordinatesForTesting.contains(centralResidential))
            XCTAssertTrue(scene.cameraPriorityCoordinatesForTesting.contains(centralWaterTower))
            XCTAssertGreaterThan(
                scene.cameraPriorityVisualBoundsForTesting.width,
                scene.occupiedDevelopedVisualBoundsForTesting.width
            )
            let priorityOccupancy = scene.cameraPriorityViewportOccupancyForTesting()
            XCTAssertEqual(scene.cameraScaleForTesting, expectedScale, accuracy: 0.000_001)
            XCTAssertEqual(
                priorityOccupancy.width,
                expectedPriorityOccupancy.width,
                accuracy: 0.000_001
            )
            XCTAssertEqual(
                priorityOccupancy.height,
                expectedPriorityOccupancy.height,
                accuracy: 0.000_001
            )
            // The remote authoritative industrial lot remains a normal
            // semantic object and an exact inverse-isometric hit target. The
            // camera prioritization changes no world geometry.
            XCTAssertEqual(scene.tileRootIsAttachedForTesting(at: remoteIndustry), true)
            XCTAssertEqual(
                scene.resolvedCoordinateForTesting(
                    at: scene.scenePointForTesting(at: remoteIndustry)
                ),
                remoteIndustry
            )
        }
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
        // Real development changes the truthful occupied bounds, so the
        // developed-mass fit deliberately retunes while remote opportunity
        // and numeric occupancy remain camera-neutral above.
        XCTAssertGreaterThan(developed.scale, baseline.scale)
        XCTAssertLessThan(developed.position.x, baseline.position.x)
        XCTAssertGreaterThan(developed.position.y, baseline.position.y)
    }

    @MainActor
    func testRejectedGoldenDistrictReferenceStaysIneligibleAndRetainsExplicitLODAssets() throws {
        let renderer = GoldenDistrictRenderer(style: WorldVisualStyle())
        XCTAssertFalse(renderer.canPresent(state: CityGameState.newCity(seed: 42)))
        XCTAssertTrue(renderer.canPresent(state: retiredGoldenDistrictReferenceState()))

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

        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        scene.configureProofInteraction(at: validCoordinate)
        var names = scene.interactionNamesForTesting
        XCTAssertFalse(scene.hoverIsHiddenForTesting)
        XCTAssertTrue(names.contains("interaction.hover.frontage-brackets"))
        XCTAssertTrue(scene.selectionIsHiddenForTesting)
        XCTAssertLessThanOrEqual(scene.hoverVisualBoundsForTesting.width, 32)
        XCTAssertLessThanOrEqual(scene.hoverVisualBoundsForTesting.height, 8)
        XCTAssertLessThan(scene.hoverVisualBoundsForTesting.maxY, 0)

        let validTile = try XCTUnwrap(state.tile(at: validCoordinate))
        let validTarget = CityMapActionTargetPresentation(
            coordinate: validCoordinate,
            primaryAction: CityMapPrimaryActionPresentation.make(
                interactionMode: .build(.residential),
                tile: validTile,
                state: state
            )
        )
        scene.render(
            state: state,
            overlay: .none,
            selection: validCoordinate,
            interactionMode: .build(.residential),
            activeActionTarget: validTarget
        )
        names = scene.interactionNamesForTesting
        XCTAssertFalse(scene.hoverIsHiddenForTesting)
        XCTAssertEqual(names.filter { $0 == "interaction.placementGhost" }.count, 1)
        XCTAssertFalse(names.contains("interaction.invalidHatch"))
        XCTAssertFalse(names.contains("interaction.hover.frontage-brackets"))
        XCTAssertFalse(names.contains { $0.hasPrefix("interaction.preview.") })
        XCTAssertTrue(descendantLabels(in: scene).isEmpty)

        let invalidTile = try XCTUnwrap(state.tile(at: invalidCoordinate))
        let invalidTarget = CityMapActionTargetPresentation(
            coordinate: invalidCoordinate,
            primaryAction: CityMapPrimaryActionPresentation.make(
                interactionMode: .build(.residential),
                tile: invalidTile,
                state: state
            )
        )
        scene.render(
            state: state,
            overlay: .none,
            selection: invalidCoordinate,
            interactionMode: .build(.residential),
            activeActionTarget: invalidTarget
        )
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

    @MainActor
    func testTypedPlacementTargetKeepsMeaningfulDistrictAndRoadContextAtBothShippingSizes() throws {
        let state = CityGameState.newCity(seed: 42)
        let targetCoordinate = GridCoordinate(x: 19, y: 17)
        let targetTile = try XCTUnwrap(state.tile(at: targetCoordinate))
        XCTAssertEqual(targetTile.kind, .empty)
        let blockedCommercial = CityMapActionTargetPresentation(
            coordinate: targetCoordinate,
            primaryAction: CityMapPrimaryActionPresentation.make(
                interactionMode: .build(.commercial),
                tile: targetTile,
                state: state
            )
        )
        XCTAssertFalse(blockedCommercial.primaryAction.isAvailable)
        XCTAssertTrue(
            blockedCommercial.primaryAction.disclosure.contains(
                BuildRejection.roadAccessRequired.message
            )
        )
        let roadRecovery = CityMapActionTargetPresentation(
            coordinate: targetCoordinate,
            primaryAction: CityMapPrimaryActionPresentation.make(
                interactionMode: .build(.road),
                tile: targetTile,
                state: state
            )
        )

        for (label, size, insets, expectedDistrictWidthRatio, expectedDistrictHeightRatio) in [
            (
                "regular",
                CGSize(width: 1_280, height: 800),
                CityMapViewportInsets(top: 104, leading: 24, bottom: 160, trailing: 24),
                CGFloat(0.5175330893191646),
                CGFloat(0.6223404050116202)
            ),
            (
                "compact",
                CGSize(width: 900, height: 600),
                CityMapViewportInsets(top: 138, leading: 19, bottom: 236, trailing: 19),
                CGFloat(0.2966171419591169),
                CGFloat(0.6381585861569213)
            ),
        ] {
            let scene = CityScene(size: size)
            scene.reducedMotion = true
            scene.updateViewportInsets(insets)
            scene.render(
                state: state,
                overlay: .none,
                selection: nil,
                interactionMode: .inspect
            )
            let openingScale = scene.cameraScaleForTesting
            let openingPosition = scene.cameraPositionForTesting
            XCTAssertGreaterThanOrEqual(
                scene.occupiedDevelopedViewportOccupancyForTesting().width,
                0.60
            )

            // Selecting a build tool alone carries no coordinate intent.
            // Renderer state and camera remain exact until the store publishes
            // a typed active target.
            scene.render(
                state: state,
                overlay: .none,
                selection: nil,
                interactionMode: .build(.commercial)
            )
            XCTAssertEqual(scene.cameraScaleForTesting, openingScale, accuracy: 0.000_001)
            XCTAssertEqual(scene.cameraPositionForTesting.x, openingPosition.x, accuracy: 0.000_001)
            XCTAssertEqual(scene.cameraPositionForTesting.y, openingPosition.y, accuracy: 0.000_001)
            XCTAssertTrue(scene.activeTargetContextBoundsForTesting.isNull)
            XCTAssertTrue(scene.selectionIsHiddenForTesting)
            XCTAssertTrue(scene.hoverIsHiddenForTesting)

            // A nearby intended target in the regular aperture already fits
            // the composed district and must not trigger the remote-target
            // zoom-out path. The compact aperture is intentionally too shallow
            // to fully contain any authoritative road center at its opening
            // fit, so its typed target correctly exercises the contextual fit.
            if label == "regular" {
                let openingSafeRect = scene.safeViewportRectForTesting(insets)
                let roadCoordinates = state.tiles
                    .filter { $0.kind == .road }
                    .map(\.coordinate)
                func nearestRoad(to coordinate: GridCoordinate) -> GridCoordinate? {
                    roadCoordinates.min { lhs, rhs in
                        let lhsDistance = abs(lhs.x - coordinate.x)
                            + abs(lhs.y - coordinate.y)
                        let rhsDistance = abs(rhs.x - coordinate.x)
                            + abs(rhs.y - coordinate.y)
                        if lhsDistance != rhsDistance {
                            return lhsDistance < rhsDistance
                        }
                        if lhs.y != rhs.y { return lhs.y < rhs.y }
                        return lhs.x < rhs.x
                    }
                }
                let orderedTiles = state.tiles.sorted {
                    if $0.coordinate.y != $1.coordinate.y {
                        return $0.coordinate.y < $1.coordinate.y
                    }
                    return $0.coordinate.x < $1.coordinate.x
                }
                let normalChoice = try XCTUnwrap(
                    [BuildingKind.commercial, .road].lazy.compactMap { kind in
                        orderedTiles.first { tile in
                            guard tile.kind == .empty,
                                  case .success = CitySimulation.validateBuild(
                                    kind,
                                    at: tile.coordinate,
                                    in: state
                                  ),
                                  let nearestRoad = nearestRoad(to: tile.coordinate) else {
                                return false
                            }
                            return openingSafeRect.contains(
                                scene.tileGroundBoundsForTesting(at: tile.coordinate)
                            ) && openingSafeRect.contains(
                                scene.tileGroundBoundsForTesting(at: nearestRoad)
                            )
                        }.map { (kind: kind, tile: $0) }
                    }.first,
                    "Regular opening must expose at least one fully visible valid Commercial or Road target"
                )
                XCTAssertEqual(normalChoice.tile.kind, .empty)
                let normalTarget = CityMapActionTargetPresentation(
                    coordinate: normalChoice.tile.coordinate,
                    primaryAction: CityMapPrimaryActionPresentation.make(
                        interactionMode: .build(normalChoice.kind),
                        tile: normalChoice.tile,
                        state: state
                    )
                )
                XCTAssertTrue(normalTarget.primaryAction.isAvailable)
                let normalRoad = try XCTUnwrap(
                    nearestRoad(to: normalChoice.tile.coordinate)
                )
                XCTAssertTrue(
                    openingSafeRect.contains(
                        scene.tileGroundBoundsForTesting(at: normalChoice.tile.coordinate)
                    )
                )
                XCTAssertTrue(
                    openingSafeRect.contains(
                        scene.tileGroundBoundsForTesting(at: normalRoad)
                    )
                )
                scene.render(
                    state: state,
                    overlay: .none,
                    selection: normalChoice.tile.coordinate,
                    interactionMode: .build(normalChoice.kind),
                    activeActionTarget: normalTarget
                )
                XCTAssertEqual(scene.cameraScaleForTesting, openingScale, accuracy: 0.000_001)
                XCTAssertEqual(scene.cameraPositionForTesting.x, openingPosition.x, accuracy: 0.000_001)
                XCTAssertEqual(scene.cameraPositionForTesting.y, openingPosition.y, accuracy: 0.000_001)

                // A center-only containment check is insufficient: a target
                // close to the safe edge can have both centers visible while
                // clipping one of the two authoritative ground diamonds.
                scene.frameCity()
                let clippedChoice = try XCTUnwrap(
                    [BuildingKind.commercial, .road].lazy.compactMap { kind in
                        orderedTiles.first { tile in
                            guard tile.kind == .empty,
                                  case .success = CitySimulation.validateBuild(
                                    kind,
                                    at: tile.coordinate,
                                    in: state
                                  ),
                                  let nearestRoad = nearestRoad(to: tile.coordinate) else {
                                return false
                            }
                            let targetCenterIsVisible = openingSafeRect.contains(
                                scene.scenePointForTesting(at: tile.coordinate)
                            )
                            let roadCenterIsVisible = openingSafeRect.contains(
                                scene.scenePointForTesting(at: nearestRoad)
                            )
                            let targetGroundIsVisible = openingSafeRect.contains(
                                scene.tileGroundBoundsForTesting(at: tile.coordinate)
                            )
                            let roadGroundIsVisible = openingSafeRect.contains(
                                scene.tileGroundBoundsForTesting(at: nearestRoad)
                            )
                            return targetCenterIsVisible
                                && roadCenterIsVisible
                                && (!targetGroundIsVisible || !roadGroundIsVisible)
                        }.map { (kind: kind, tile: $0) }
                    }.first,
                    "Regular opening must retain a center-visible clipped-edge regression target"
                )
                let clippedRoad = try XCTUnwrap(
                    nearestRoad(to: clippedChoice.tile.coordinate)
                )
                XCTAssertTrue(
                    openingSafeRect.contains(
                        scene.scenePointForTesting(at: clippedChoice.tile.coordinate)
                    )
                )
                XCTAssertTrue(
                    openingSafeRect.contains(scene.scenePointForTesting(at: clippedRoad))
                )
                XCTAssertFalse(
                    openingSafeRect.contains(
                        scene.tileGroundBoundsForTesting(at: clippedChoice.tile.coordinate)
                    ) && openingSafeRect.contains(
                        scene.tileGroundBoundsForTesting(at: clippedRoad)
                    )
                )
                let clippedTarget = CityMapActionTargetPresentation(
                    coordinate: clippedChoice.tile.coordinate,
                    primaryAction: CityMapPrimaryActionPresentation.make(
                        interactionMode: .build(clippedChoice.kind),
                        tile: clippedChoice.tile,
                        state: state
                    )
                )
                XCTAssertTrue(clippedTarget.primaryAction.isAvailable)
                scene.render(
                    state: state,
                    overlay: .none,
                    selection: clippedChoice.tile.coordinate,
                    interactionMode: .build(clippedChoice.kind),
                    activeActionTarget: clippedTarget
                )
                XCTAssertGreaterThan(scene.cameraScaleForTesting, openingScale)
                let reframedSafeRect = scene.safeViewportRectForTesting(insets)
                XCTAssertTrue(
                    reframedSafeRect.contains(
                        scene.tileGroundBoundsForTesting(at: clippedChoice.tile.coordinate)
                    )
                )
                XCTAssertTrue(
                    reframedSafeRect.contains(
                        scene.tileGroundBoundsForTesting(at: clippedRoad)
                    )
                )
            }

            // Re-establish a no-target opening camera before proving the remote
            // but legitimate player target.
            scene.frameCity()
            scene.render(
                state: state,
                overlay: .none,
                selection: targetCoordinate,
                interactionMode: .build(.commercial),
                activeActionTarget: blockedCommercial
            )

            let safeRect = scene.safeViewportRectForTesting(insets)
            let targetBounds = scene.tileGroundBoundsForTesting(at: targetCoordinate)
            let roadFrontier = try XCTUnwrap(scene.activeTargetRoadFrontierForTesting)
            let roadBounds = scene.tileGroundBoundsForTesting(at: roadFrontier)
            XCTAssertEqual(state.tile(at: roadFrontier)?.kind, .road)
            XCTAssertFalse(RoadConnectionMask.resolving(at: roadFrontier, in: state).isEmpty)
            XCTAssertTrue(
                safeRect.contains(targetBounds),
                "\(label) target=\(targetBounds) safe=\(safeRect) scale=\(scene.cameraScaleForTesting)"
            )
            XCTAssertTrue(
                safeRect.contains(roadBounds),
                "\(label) road=\(roadBounds) safe=\(safeRect) scale=\(scene.cameraScaleForTesting)"
            )

            let visibleDistrict = safeRect.intersection(
                scene.cameraPriorityVisualBoundsForTesting
            )
            let districtSafeWidthRatio = visibleDistrict.width / safeRect.width
            let districtSafeHeightRatio = visibleDistrict.height / safeRect.height
            XCTAssertEqual(
                districtSafeWidthRatio,
                expectedDistrictWidthRatio,
                accuracy: 0.000_001,
                "\(label) district safe-width occupancy drifted"
            )
            XCTAssertEqual(
                districtSafeHeightRatio,
                expectedDistrictHeightRatio,
                accuracy: 0.000_001,
                "\(label) district safe-height occupancy drifted"
            )
            XCTAssertGreaterThanOrEqual(
                districtSafeWidthRatio,
                0.25,
                "\(label) district safe-width ratio=\(districtSafeWidthRatio)"
            )
            XCTAssertGreaterThanOrEqual(
                districtSafeHeightRatio,
                0.25,
                "\(label) district safe-height ratio=\(districtSafeHeightRatio)"
            )
            XCTAssertLessThan(
                scene.cameraScaleForTesting,
                2.2,
                "\(label) remote target must retain readable district context"
            )
            XCTAssertTrue(scene.activeTargetContextBoundsForTesting.contains(targetBounds))
            XCTAssertTrue(scene.activeTargetContextBoundsForTesting.contains(roadBounds))
            XCTAssertGreaterThan(scene.cameraScaleForTesting, openingScale)
            XCTAssertFalse(scene.selectionIsHiddenForTesting)
            XCTAssertFalse(scene.hoverIsHiddenForTesting)
            XCTAssertTrue(scene.interactionNamesForTesting.contains("interaction.placementGhost"))
            XCTAssertTrue(scene.interactionNamesForTesting.contains("interaction.invalidHatch"))

            let contextScale = scene.cameraScaleForTesting
            let contextPosition = scene.cameraPositionForTesting
            scene.render(
                state: state,
                overlay: .none,
                selection: targetCoordinate,
                interactionMode: .build(.road),
                activeActionTarget: roadRecovery
            )
            XCTAssertEqual(scene.cameraScaleForTesting, contextScale, accuracy: 0.000_001)
            XCTAssertEqual(scene.cameraPositionForTesting.x, contextPosition.x, accuracy: 0.000_001)
            XCTAssertEqual(scene.cameraPositionForTesting.y, contextPosition.y, accuracy: 0.000_001)
            XCTAssertTrue(scene.safeViewportRectForTesting(insets).contains(targetBounds))
            XCTAssertTrue(scene.safeViewportRectForTesting(insets).contains(roadBounds))
            XCTAssertTrue(scene.interactionNamesForTesting.contains("interaction.placementGhost"))
        }
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
        XCTAssertTrue(recoveredNames.contains("lot.growth.improvedFrontage"))
        XCTAssertFalse(recoveredNames.contains("lot.growth.freshFacade"))
        XCTAssertTrue(recoveredNames.contains("lot.growth.entrance-canopy"))
        XCTAssertFalse(recoveredNames.contains("lot.growth.badge"))
        XCTAssertFalse(recoveredNames.contains { $0.contains("pennant") || $0.contains("chevron") })
        XCTAssertTrue(descendantLabels(in: recoveredRoot).isEmpty)
    }

    @MainActor
    func testConstructionProofExportsSameCoordinateAcrossFiveStages() throws {
        let coordinate = GridCoordinate(x: 1, y: 2)
        let stages: [(progress: Double, environmentKey: String)] = [
            (0.00, "CITYSIM_PLAY022_CONSTRUCTION_00_PROOF"),
            (0.25, "CITYSIM_PLAY022_CONSTRUCTION_25_PROOF"),
            (0.50, "CITYSIM_PLAY022_CONSTRUCTION_50_PROOF"),
            (0.75, "CITYSIM_PLAY022_CONSTRUCTION_75_PROOF"),
            (1.00, "CITYSIM_PLAY022_CONSTRUCTION_100_PROOF")
        ]
        var frames: [Data] = []

        for stage in stages {
            var state = goldenNeighborhoodState()
            state.updateTile(at: coordinate) {
                $0.kind = .residential
                $0.level = 1
                $0.occupancy = stage.progress >= 1 ? 40 : 0
                $0.condition = 1
                $0.constructionProgress = stage.progress
            }
            let frame = try lifecycleFrame(
                state: state,
                size: CGSize(width: 1_280, height: 800),
                detail: .block,
                centeredOn: coordinate
            )
            XCTAssertGreaterThan(frame.png.count, 40_000)
            XCTAssertEqual(frame.diagnostics.activeActionCount, 0)
            frames.append(frame.png)
            try export(frame.png, environmentKey: stage.environmentKey)
        }

        XCTAssertEqual(Set(frames).count, stages.count)
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
            if progress == 0.75 {
                let animatedScaffold = animated.childNode(
                    withName: "//lot.construction.scaffoldSilhouette"
                )
                XCTAssertNotNil(animatedScaffold)
                XCTAssertLessThanOrEqual(animatedScaffold?.calculateAccumulatedFrame().width ?? 0, 50)
                XCTAssertLessThanOrEqual(animatedScaffold?.calculateAccumulatedFrame().height ?? 0, 30)
                XCTAssertTrue(animatedNames.contains("lot.construction.scaffoldBrace"))
                XCTAssertFalse(animatedNames.contains("lot.construction.finishWrap"))
            }
            let expectedActions = progress == 0.50 ? 1 : 0
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
        XCTAssertTrue(growthNames.contains("lot.growth.improvedFrontage"))
        XCTAssertTrue(growthNames.contains("lot.growth.entrance-canopy"))
        XCTAssertFalse(growthNames.contains {
            $0.contains("pennant")
                || $0.contains("chevron")
                || $0.contains("freshFacade")
                || $0.contains("cautionRibbon")
        })
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
        XCTAssertGreaterThanOrEqual(cold.backdropUpdateDurationMilliseconds, 0)
        XCTAssertGreaterThanOrEqual(cold.renderPreparationDurationMilliseconds, 0)
        XCTAssertGreaterThanOrEqual(cold.tileBuildDurationMilliseconds, 0)
        XCTAssertGreaterThanOrEqual(cold.runtimeTreeMetricsDurationMilliseconds, 0)
        XCTAssertLessThanOrEqual(
            cold.backdropUpdateDurationMilliseconds
                + cold.renderPreparationDurationMilliseconds
                + cold.tileBuildDurationMilliseconds,
            cold.worldUpdateDurationMilliseconds
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
            "PLAY022_ROUND1C_COLD_PROFILE " +
            "backdrop_ms=\(String(format: "%.3f", cold.backdropUpdateDurationMilliseconds)) " +
            "preparation_ms=\(String(format: "%.3f", cold.renderPreparationDurationMilliseconds)) " +
            "tile_build_ms=\(String(format: "%.3f", cold.tileBuildDurationMilliseconds)) " +
            "tree_metrics_ms=\(String(format: "%.3f", cold.runtimeTreeMetricsDurationMilliseconds)) " +
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
        XCTAssertGreaterThan(scene.diagnosticsSnapshot.drawableNodeCount, 300)
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
        scene.configureProofCamera(detail: .block, centeredOn: GridCoordinate(x: 12, y: 11))
        scene.render(
            snapshot: try CityPresentationSnapshot(state: state),
            overlay: .none,
            selection: GridCoordinate(x: 10, y: 11),
            interactionMode: .inspect
        )
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
        state.updateTile(at: GridCoordinate(x: 13, y: 11)) {
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

    private func retiredGoldenDistrictReferenceState() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for tile in state.tiles where tile.kind == .road {
            state.updateTile(at: tile.coordinate) { $0.kind = .empty }
        }
        for x in 4..<20 {
            state.updateTile(at: GridCoordinate(x: x, y: 12)) { $0.kind = .road }
        }
        for y in 8..<17 {
            state.updateTile(at: GridCoordinate(x: 12, y: y)) { $0.kind = .road }
        }
        state.updateTile(at: GridCoordinate(x: 15, y: 13)) { $0.kind = .empty }
        state.updateTile(at: GridCoordinate(x: 11, y: 14)) { $0.kind = .waterTower }
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

    @MainActor
    private func containsCropNode(in node: SKNode) -> Bool {
        node is SKCropNode || node.children.contains(where: containsCropNode(in:))
    }

    private func pointSegmentDistanceForTesting(_ point: CGPoint, end: CGPoint) -> CGFloat {
        let lengthSquared = end.x * end.x + end.y * end.y
        guard lengthSquared > 0 else { return hypot(point.x, point.y) }
        let projection = min(1, max(0, (point.x * end.x + point.y * end.y) / lengthSquared))
        let closest = CGPoint(x: end.x * projection, y: end.y * projection)
        return hypot(point.x - closest.x, point.y - closest.y)
    }
}
