import XCTest
import AppKit
import SpriteKit
import SwiftUI
@testable import CitySimNative

final class CitySimulationTests: XCTestCase {
    func testNewCityHasPlayableFoundation() {
        let state = CityGameState.newCity(seed: 42)
        XCTAssertEqual(state.tiles.count, state.gridWidth * state.gridHeight)
        XCTAssertTrue(state.tiles.contains { $0.kind == .cityHall })
        XCTAssertTrue(state.tiles.contains { $0.kind == .road })
        XCTAssertGreaterThan(state.treasury, 0)
    }

    func testSimulationIsDeterministic() {
        var lhs = CityGameState.newCity(seed: 1337)
        var rhs = CityGameState.newCity(seed: 1337)
        for _ in 0..<100 {
            CitySimulation.step(&lhs)
            CitySimulation.step(&rhs)
        }
        XCTAssertEqual(lhs, rhs)
    }

    func testProductionStoryCorpusBuildsAreByteIdentical() throws {
        let first = try ProductionStoryFixtureCorpus.build()
        let second = try ProductionStoryFixtureCorpus.build()

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.manifestData, second.manifestData)
        XCTAssertEqual(
            first.artifacts.map(\.bytes),
            second.artifacts.map(\.bytes)
        )
    }

    func testRoadAccessIsRequiredForZoning() {
        let state = CityGameState.newCity()
        let remote = GridCoordinate(x: 0, y: 0)
        guard case .failure(let rejection) = CitySimulation.validateBuild(.residential, at: remote, in: state) else {
            return XCTFail("Expected road access rejection")
        }
        XCTAssertEqual(rejection, .roadAccessRequired)
    }

    func testDevelopmentRequiresRoadConnectedToCompletedCityPlace() {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 100_000
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }

        let cityHall = GridCoordinate(x: 2, y: 2)
        let cityRoad = GridCoordinate(x: 3, y: 2)
        let isolatedRoad = GridCoordinate(x: 9, y: 10)
        let target = GridCoordinate(x: 10, y: 10)
        state.updateTile(at: cityHall) {
            $0 = CityTile(coordinate: cityHall, kind: .cityHall, constructionProgress: 1)
        }
        state.updateTile(at: cityRoad) {
            $0 = CityTile(coordinate: cityRoad, kind: .road, constructionProgress: 1)
        }
        state.updateTile(at: isolatedRoad) {
            $0 = CityTile(coordinate: isolatedRoad, kind: .road, constructionProgress: 1)
        }

        guard case .failure(let rejection) = CitySimulation.validateBuild(
            .commercial,
            at: target,
            in: state
        ) else {
            return XCTFail("Expected the isolated street to block development")
        }
        XCTAssertEqual(rejection, .cityRoadConnectionRequired)
        var commandState = state
        let commandBaseline = commandState
        XCTAssertEqual(
            CitySimulationCommandExecutor.apply(
                .build(kind: .commercial, coordinate: target),
                to: &commandState
            ),
            .rejected(.cityRoadConnectionRequired)
        )
        XCTAssertEqual(commandState, commandBaseline)

        for x in 4...9 {
            let coordinate = GridCoordinate(x: x, y: 2)
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .road, constructionProgress: 1)
            }
        }
        for y in 3...10 {
            let coordinate = GridCoordinate(x: 9, y: y)
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .road, constructionProgress: 1)
            }
        }

        guard case .success = CitySimulation.validateBuild(
            .commercial,
            at: target,
            in: state
        ) else {
            return XCTFail("Expected the connected street to support development")
        }
    }

    func testCompletedLegacyDistrictAnchorsItsOwnRoadComponent() {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 100_000
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        let cityHall = GridCoordinate(x: 2, y: 2)
        let cityRoad = GridCoordinate(x: 3, y: 2)
        let legacyHome = GridCoordinate(x: 9, y: 9)
        let legacyRoad = GridCoordinate(x: 9, y: 10)
        let target = GridCoordinate(x: 10, y: 10)
        state.updateTile(at: cityHall) {
            $0 = CityTile(coordinate: cityHall, kind: .cityHall, constructionProgress: 1)
        }
        state.updateTile(at: cityRoad) {
            $0 = CityTile(coordinate: cityRoad, kind: .road, constructionProgress: 1)
        }
        state.updateTile(at: legacyHome) {
            $0 = CityTile(
                coordinate: legacyHome,
                kind: .residential,
                occupancy: 120,
                constructionProgress: 1
            )
        }
        state.updateTile(at: legacyRoad) {
            $0 = CityTile(coordinate: legacyRoad, kind: .road, constructionProgress: 1)
        }

        guard case .success = CitySimulation.validateBuild(
            .commercial,
            at: target,
            in: state
        ) else {
            return XCTFail("Expected a completed legacy district to keep its own road component active")
        }
    }

    func testFirstDevelopmentCanBootstrapBesideRoadWhenCityHasNoCompletedPlace() {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 100_000
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        let road = GridCoordinate(x: 9, y: 10)
        let target = GridCoordinate(x: 10, y: 10)
        state.updateTile(at: road) {
            $0 = CityTile(coordinate: road, kind: .road, constructionProgress: 1)
        }

        guard case .success = CitySimulation.validateBuild(
            .residential,
            at: target,
            in: state
        ) else {
            return XCTFail("Expected the first city place to bootstrap beside a road")
        }
    }

    func testBuildingChargesTreasuryAndStartsConstruction() {
        var state = CityGameState.newCity()
        let coordinate = GridCoordinate(x: 4, y: 8)
        let startingTreasury = state.treasury
        guard case .success = CitySimulation.build(.residential, at: coordinate, in: &state) else {
            return XCTFail("Expected construction to succeed")
        }
        XCTAssertEqual(state.treasury, startingTreasury - BuildingKind.residential.buildCost)
        XCTAssertEqual(state.tile(at: coordinate)?.kind, .residential)
        XCTAssertEqual(state.tile(at: coordinate)?.constructionProgress, 0)
    }

    func testConstructionCompletesAndPopulationResponds() {
        var state = CityGameState.newCity()
        let coordinate = GridCoordinate(x: 4, y: 8)
        _ = CitySimulation.build(.residential, at: coordinate, in: &state)
        for _ in 0..<8 { CitySimulation.step(&state) }
        XCTAssertEqual(state.tile(at: coordinate)?.constructionProgress, 1)
        XCTAssertGreaterThanOrEqual(state.population, 180)
    }

    func testCompletedUtilityPostsCausalResponseAtFirstGovernedReviewAndReplays() throws {
        let coordinate = GridCoordinate(x: 5, y: 8)
        var lhs = CityGameState.newCity(seed: 120)
        var rhs = CityGameState.newCity(seed: 120)
        let initialPowerCapacity = lhs.powerCapacity

        guard case .success = CitySimulation.build(.powerPlant, at: coordinate, in: &lhs),
              case .success = CitySimulation.build(.powerPlant, at: coordinate, in: &rhs) else {
            return XCTFail("Expected road-connected power construction to succeed")
        }

        for expectedProgress in [0.25, 0.5, 0.75] {
            CitySimulation.step(&lhs)
            CitySimulation.step(&rhs)
            XCTAssertEqual(lhs, rhs, "The same construction command and ticks must replay identically")
            XCTAssertEqual(lhs.tile(at: coordinate)?.constructionProgress, expectedProgress)
            XCTAssertEqual(lhs.powerCapacity, initialPowerCapacity)
            XCTAssertFalse(lhs.messages.contains(where: { $0.title == "Construction Online" }))
        }

        CitySimulation.step(&lhs)
        CitySimulation.step(&rhs)

        XCTAssertEqual(lhs, rhs, "The governed completion response must replay byte-for-byte through CityGameState")
        XCTAssertEqual(lhs.tick, 4)
        XCTAssertEqual(lhs.tile(at: coordinate)?.constructionProgress, 1)
        XCTAssertEqual(lhs.powerCapacity, initialPowerCapacity + CitySimulation.powerCapacityPerPlant)
        XCTAssertGreaterThan(lhs.powerCapacity, lhs.powerUsed)

        let message = try XCTUnwrap(lhs.messages.first(where: { $0.title == "Construction Online" }))
        XCTAssertEqual(message.tick, lhs.tick)
        XCTAssertEqual(message.severity, .good)
        XCTAssertTrue(message.detail.contains("Power Plant at block 6, 9 came online."))
        XCTAssertTrue(message.detail.contains("Power capacity is \(lhs.powerCapacity) against \(lhs.powerUsed) current use"))
        XCTAssertTrue(message.detail.contains("protects growth at the next daily review"))
    }

    func testCurrentConsequenceMessagesPersistThroughSaveAndReplay() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play129-current-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        var construction = CityGameState.newCity(seed: 129)
        guard case .success = CitySimulation.build(.powerPlant, at: GridCoordinate(x: 5, y: 8), in: &construction) else {
            return XCTFail("Expected current utility construction to succeed")
        }
        for _ in 0..<4 { CitySimulation.step(&construction) }
        XCTAssertTrue(construction.messages.contains { $0.title == "Construction Online" })

        let service = SaveGameService(rootURL: root)
        let constructionWrite = try service.save(construction)
        let constructionLoad = try service.load()
        XCTAssertEqual(constructionLoad.state, construction)
        XCTAssertEqual(constructionLoad.fingerprint, constructionWrite.fingerprint)
        XCTAssertTrue(constructionLoad.state.messages.contains { $0.title == "Construction Online" })

        var taxRelief = CityGameState.newCity(seed: 130)
        taxRelief.taxRate = 0.09
        taxRelief.progression?.strategy = CityStrategyProgression(
            committedStrategy: .commercialStewardship,
            currentPhase: .recovery,
            nextScheduledTick: 128
        )
        for _ in 0..<4 { CitySimulation.step(&taxRelief) }
        XCTAssertTrue(taxRelief.messages.contains { $0.title == "Tax Relief Confirmed" })

        let taxReliefWrite = try service.save(taxRelief)
        let taxReliefLoad = try service.load()
        XCTAssertEqual(taxReliefLoad.state, taxRelief)
        XCTAssertEqual(taxReliefLoad.fingerprint, taxReliefWrite.fingerprint)
        XCTAssertEqual(
            taxReliefLoad.state.messages.filter { $0.title == "Tax Relief Confirmed" }.count,
            1
        )
        CitySimulation.step(&taxRelief)
        XCTAssertEqual(taxRelief.messages.filter { $0.title == "Tax Relief Confirmed" }.count, 1)
    }

    func testStateRoundTripsThroughJSON() throws {
        var state = CityGameState.newCity(seed: 99)
        for _ in 0..<12 { CitySimulation.step(&state) }
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(CityGameState.self, from: data)
        XCTAssertEqual(decoded, state)
    }

    func testDemolitionProtectsCityHall() {
        var state = CityGameState.newCity()
        XCTAssertFalse(CitySimulation.demolish(at: GridCoordinate(x: 11, y: 11), in: &state))
        XCTAssertEqual(state.tile(at: GridCoordinate(x: 11, y: 11))?.kind, .cityHall)
    }

    func testCityUsesDayOnlyPresentation() {
        var state = CityGameState.newCity()
        XCTAssertEqual(state.formattedDay, "Day 1")
        for _ in 0..<4 { CitySimulation.step(&state) }
        XCTAssertEqual(state.formattedDay, "Day 2")
    }

    func testSimulationSpeedControlsUseExplicitLabelsAndDeterministicTicks() {
        XCTAssertEqual(SimulationSpeed.allCases.map(\.rawValue), [0, 1, 2, 3])
        XCTAssertEqual(SimulationSpeed.allCases.map(\.controlLabel), ["Pause", "1x", "2x", "3x"])
        XCTAssertEqual(SimulationSpeed.allCases.map(\.ticksPerPulse), [0, 1, 2, 3])
    }

    func testBuildCategoriesCoverThePaletteExactlyOnce() {
        let categorizedKinds = BuildCategory.allCases.flatMap(\.buildingKinds)

        XCTAssertEqual(categorizedKinds.count, BuildingKind.buildPalette.count)
        XCTAssertEqual(Set(categorizedKinds), Set(BuildingKind.buildPalette))
        for kind in BuildingKind.buildPalette {
            XCTAssertEqual(categorizedKinds.filter { $0 == kind }.count, 1, "\(kind) should appear in exactly one category")
            XCTAssertEqual(kind.buildCategory.buildingKinds.filter { $0 == kind }.count, 1)
        }
    }

    @MainActor
    func testBuildCategorySelectionActivatesAVisibleToolFromThatCategory() {
        let store = CityGameStore(state: .newCity())

        store.selectBuildCategory(.zones)

        XCTAssertEqual(store.selectedBuildCategory, .zones)
        XCTAssertEqual(store.selectedTool, .residential)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertTrue(BuildCategory.zones.buildingKinds.contains(store.selectedTool))

        store.selectTool(.commercial)
        store.selectBuildCategory(.zones)
        XCTAssertEqual(store.selectedTool, .commercial, "Reopening the active category should preserve its visible tool")
        XCTAssertEqual(store.interactionMode, .build(.commercial))
    }

    func testWorldVisualSeedIsStableAndIndependentOfSimulationSeed() {
        let coordinate = GridCoordinate(x: 7, y: 11)
        var state = CityGameState.newCity(seed: 1)
        let first = WorldVisualSeed.value(for: coordinate, kind: .commercial)

        state.seed = UInt64.max
        let repeated = WorldVisualSeed.value(for: coordinate, kind: .commercial)

        XCTAssertEqual(first, 14_371_456_125_281_289_100)
        XCTAssertEqual(repeated, first)
        XCTAssertEqual(WorldVisualSeed.variant(count: 3, for: coordinate, kind: .commercial), 1)
        XCTAssertNotEqual(WorldVisualSeed.value(for: coordinate, kind: .commercial, salt: 1), first)
        XCTAssertEqual(state.seed, UInt64.max, "Visual sampling must not consume or rewrite simulation randomness")
    }

    func testCameraDetailThresholdsRespectRenderQuality() {
        XCTAssertEqual(CameraDetailLevel.blockMaximumCameraScale, 0.60)
        XCTAssertEqual(CameraDetailLevel.neighborhoodMaximumCameraScale, 0.70)

        XCTAssertEqual(CameraDetailLevel.resolve(cameraScale: 0.20), .block)
        XCTAssertEqual(CameraDetailLevel.resolve(cameraScale: 0.60), .block)
        XCTAssertEqual(CameraDetailLevel.resolve(cameraScale: 0.601), .neighborhood)
        XCTAssertEqual(CameraDetailLevel.resolve(cameraScale: 0.70), .neighborhood)
        XCTAssertEqual(CameraDetailLevel.resolve(cameraScale: 0.701), .city)

        XCTAssertEqual(CameraDetailLevel.resolve(cameraScale: 0.20, quality: .medium), .block)
        XCTAssertEqual(CameraDetailLevel.resolve(cameraScale: 0.20, quality: .low), .neighborhood)
        XCTAssertEqual(CameraDetailLevel.resolve(cameraScale: 0.70, quality: .low), .neighborhood)
        XCTAssertEqual(CameraDetailLevel.resolve(cameraScale: 1.40, quality: .low), .city)
    }

    func testRoadConnectionMasksPreserveEveryTopologyAndRotation() {
        let masks = RoadConnectionMask.allMasks
        XCTAssertEqual(masks.map(\.rawValue), Array(UInt8(0)...UInt8(15)))
        XCTAssertEqual(RoadConnectionMask(rawValue: 0xff), .all)

        let expectedClassifications: [RoadTopology.Classification] = [
            .isolated, .end, .end, .corner,
            .end, .straight, .corner, .tee,
            .end, .corner, .straight, .tee,
            .corner, .tee, .tee, .crossing
        ]
        let expectedQuarterTurns = [0, 0, 1, 0, 2, 0, 1, 0, 3, 3, 1, 3, 2, 2, 1, 0]

        for (index, mask) in masks.enumerated() {
            let rebuilt = mask.edges.reduce(into: RoadConnectionMask()) { result, edge in
                result.formUnion(edge)
            }
            let topology = RoadTopology(mask: mask)

            XCTAssertEqual(mask, rebuilt, "Mask \(index) lost a cardinal connection")
            XCTAssertEqual(mask.connectionCount, mask.edges.count)
            XCTAssertEqual(RoadConnectionMask(rawValue: mask.rawValue | 0xf0), mask)
            XCTAssertEqual(mask.rotatedClockwise(4), mask)
            XCTAssertEqual(mask.rotatedClockwise(-4), mask)
            XCTAssertEqual(mask.rotatedClockwise().rotatedClockwise(3), mask)
            XCTAssertEqual(topology.classification, expectedClassifications[index], "Unexpected topology for mask \(index)")
            XCTAssertEqual(topology.quarterTurns, expectedQuarterTurns[index], "Unexpected rotation for mask \(index)")
            XCTAssertEqual(topology.rotation, CGFloat(expectedQuarterTurns[index]) * .pi / 2, accuracy: 0.000_001)
            XCTAssertEqual(topology.isJunction, topology.classification == .tee || topology.classification == .crossing)
        }

        XCTAssertEqual(RoadConnectionMask.north.rotatedClockwise(), .east)
        XCTAssertEqual(RoadConnectionMask.east.rotatedClockwise(), .south)
        XCTAssertEqual(RoadConnectionMask.south.rotatedClockwise(), .west)
        XCTAssertEqual(RoadConnectionMask.west.rotatedClockwise(), .north)

        let classificationCounts = Dictionary(grouping: masks.map { RoadTopology(mask: $0).classification }, by: { $0 })
            .mapValues(\.count)
        XCTAssertEqual(classificationCounts[.isolated], 1)
        XCTAssertEqual(classificationCounts[.end], 4)
        XCTAssertEqual(classificationCounts[.straight], 2)
        XCTAssertEqual(classificationCounts[.corner], 4)
        XCTAssertEqual(classificationCounts[.tee], 4)
        XCTAssertEqual(classificationCounts[.crossing], 1)
    }

    func testRoadConnectionsResolveStarterDistrictJunctionsEdgesAndMutations() {
        var state = CityGameState.newCity(seed: 42)
        XCTAssertEqual(
            RoadConnectionMask.resolving(at: GridCoordinate(x: 12, y: 12), in: state),
            [.north, .east, .west]
        )
        XCTAssertEqual(
            RoadConnectionMask.resolving(at: GridCoordinate(x: 4, y: 12), in: state),
            [.north, .east]
        )
        XCTAssertEqual(
            RoadConnectionMask.resolving(at: GridCoordinate(x: 12, y: 9), in: state),
            [.east, .south, .west]
        )

        let southwestCorner = GridCoordinate(x: 4, y: 12)
        state.updateTile(at: GridCoordinate(x: 4, y: 13)) { $0.kind = .road }
        XCTAssertEqual(
            RoadConnectionMask.resolving(at: southwestCorner, in: state),
            [.north, .east, .south]
        )
        state.updateTile(at: GridCoordinate(x: 5, y: 12)) { $0.kind = .empty }
        XCTAssertEqual(RoadConnectionMask.resolving(at: southwestCorner, in: state), [.north, .south])

        var edgeState = CityGameState.newCity(seed: 42)
        edgeState.tiles = edgeState.tiles.map { CityTile(coordinate: $0.coordinate, kind: .empty) }
        edgeState.updateTile(at: GridCoordinate(x: 0, y: 0)) { $0.kind = .road }
        edgeState.updateTile(at: GridCoordinate(x: 1, y: 0)) { $0.kind = .road }
        edgeState.updateTile(at: GridCoordinate(x: 0, y: 1)) { $0.kind = .road }
        XCTAssertEqual(
            RoadConnectionMask.resolving(at: GridCoordinate(x: 0, y: 0), in: edgeState),
            [.east, .south],
            "Out-of-bounds north and west edges must not become phantom connections"
        )
    }

    @MainActor
    func testRendererInitialRenderAndPulsesInvalidateOnlyChangedSpatialTruth() throws {
        let state = CityGameState.newCity(seed: 42)
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)

        let initial = scene.diagnosticsSnapshot
        let initialIdentifiers = tileRootIdentifiers(in: scene, state: state)
        XCTAssertEqual(initial.totalTileCount, state.tiles.count)
        XCTAssertEqual(initial.createdTileCount, state.tiles.count)
        XCTAssertEqual(initial.updatedTileCount, 0)
        XCTAssertEqual(initial.reusedTileCount, 0)
        XCTAssertEqual(initial.removedTileCount, 0)
        XCTAssertEqual(initial.overlayUpdateCount, 0)
        XCTAssertGreaterThan(initial.nodeCount, initial.totalTileCount)
        XCTAssertEqual(initialIdentifiers.count, state.tiles.count)

        var pulsedState = state
        var totalReusedTiles = 0
        var totalUpdatedTiles = 0
        var changedAcrossPulses: Set<GridCoordinate> = []
        var renderMilliseconds = 0.0
        var worldUpdateMilliseconds = 0.0
        var preparationMilliseconds = 0.0
        var tileBuildMilliseconds = 0.0
        var treeMetricsMilliseconds = 0.0
        for pulseIndex in 1...10 {
            let previousSnapshot = try CityPresentationSnapshot(state: pulsedState)
            CitySimulation.step(&pulsedState)
            let currentSnapshot = try CityPresentationSnapshot(state: pulsedState)
            let expectedChanges = Set(zip(
                previousSnapshot.spatialConsequences.samples,
                currentSnapshot.spatialConsequences.samples
            ).compactMap { previous, current in
                SpatialConsequenceRenderSignature(previous) == SpatialConsequenceRenderSignature(current)
                    ? nil
                    : current.coordinate
            })
            let renderStarted = ProcessInfo.processInfo.systemUptime
            scene.render(
                snapshot: currentSnapshot,
                overlay: .none,
                selection: nil,
                interactionMode: .inspect
            )
            renderMilliseconds += (ProcessInfo.processInfo.systemUptime - renderStarted) * 1_000
            let diagnostics = scene.diagnosticsSnapshot
            worldUpdateMilliseconds += diagnostics.worldUpdateDurationMilliseconds
            preparationMilliseconds += diagnostics.renderPreparationDurationMilliseconds
            tileBuildMilliseconds += diagnostics.tileBuildDurationMilliseconds
            treeMetricsMilliseconds += diagnostics.runtimeTreeMetricsDurationMilliseconds
            XCTAssertEqual(
                diagnostics.updatedCoordinates,
                expectedChanges,
                "Pulse \(pulseIndex) must invalidate exactly the accepted spatial-band changes"
            )
            XCTAssertEqual(diagnostics.updatedTileCount, expectedChanges.count)
            XCTAssertEqual(diagnostics.reusedTileCount, state.tiles.count - expectedChanges.count)
            totalReusedTiles += diagnostics.reusedTileCount
            totalUpdatedTiles += diagnostics.updatedTileCount
            changedAcrossPulses.formUnion(expectedChanges)
        }
        let averageRenderMilliseconds = renderMilliseconds / 10
        let pulse = scene.diagnosticsSnapshot
        XCTAssertEqual(
            changedTileIdentifiers(
                before: initialIdentifiers,
                after: tileRootIdentifiers(in: scene, state: pulsedState)
            ),
            changedAcrossPulses
        )
        XCTAssertEqual(pulse.totalTileCount, state.tiles.count)
        XCTAssertEqual(pulse.createdTileCount, 0)
        XCTAssertEqual(pulse.updatedTileCount, pulse.updatedCoordinates.count)
        XCTAssertEqual(pulse.reusedTileCount, state.tiles.count - pulse.updatedTileCount)
        XCTAssertEqual(pulse.removedTileCount, 0)
        XCTAssertEqual(pulse.overlayUpdateCount, 0)
        XCTAssertGreaterThanOrEqual(pulse.nodeCount, initial.nodeCount)
        XCTAssertLessThanOrEqual(
            averageRenderMilliseconds,
            2.1,
            "State-changing render pulses must remain within the established 2.1 ms renderer budget"
        )
        print(
            "CITYSIM_RENDER_DIAGNOSTICS initial_tiles=\(initial.totalTileCount) " +
            "initial_nodes=\(initial.nodeCount) ten_pulses_reused=\(totalReusedTiles) " +
            "ten_pulses_updated=\(totalUpdatedTiles) render_ms=\(String(format: "%.3f", renderMilliseconds)) " +
            "average_render_ms=\(String(format: "%.3f", averageRenderMilliseconds)) " +
            "world_update_ms=\(String(format: "%.3f", worldUpdateMilliseconds)) " +
            "preparation_ms=\(String(format: "%.3f", preparationMilliseconds)) " +
            "tile_build_ms=\(String(format: "%.3f", tileBuildMilliseconds)) " +
            "tree_metrics_ms=\(String(format: "%.3f", treeMetricsMilliseconds)) " +
            "final_nodes=\(pulse.nodeCount)"
        )
    }

    @MainActor
    func testRendererInvalidatesOnlyOneChangedBuildingTile() {
        var state = CityGameState.newCity(seed: 42)
        let target = GridCoordinate(x: 2, y: 2)
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        let before = tileRootIdentifiers(in: scene, state: state)

        state.updateTile(at: target) {
            $0.kind = .residential
            $0.constructionProgress = 1
        }
        scene.render(state: state, overlay: .none, selection: target, interactionMode: .inspect)

        let after = tileRootIdentifiers(in: scene, state: state)
        let diagnostics = scene.diagnosticsSnapshot
        XCTAssertEqual(changedTileIdentifiers(before: before, after: after), [target])
        XCTAssertEqual(diagnostics.createdTileCount, 0)
        XCTAssertEqual(diagnostics.updatedTileCount, 1)
        XCTAssertEqual(diagnostics.reusedTileCount, state.tiles.count - 1)
        XCTAssertEqual(diagnostics.removedTileCount, 0)
        XCTAssertEqual(diagnostics.overlayUpdateCount, 0)
        XCTAssertEqual(diagnostics.updatedCoordinates, [target])
    }

    @MainActor
    func testRendererRoadMutationInvalidatesTargetConnectedRoadAndAdjacentFrontage() {
        var state = CityGameState.newCity(seed: 42)
        let target = GridCoordinate(x: 3, y: 11)
        let connectedRoad = GridCoordinate(x: 4, y: 11)
        let adjacentFrontage = GridCoordinate(x: 3, y: 10)
        let expectedUpdates: Set<GridCoordinate> = [target, connectedRoad, adjacentFrontage]
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        let before = tileRootIdentifiers(in: scene, state: state)

        state.updateTile(at: target) { $0.kind = .road }
        scene.render(state: state, overlay: .none, selection: target, interactionMode: .inspect)

        let after = tileRootIdentifiers(in: scene, state: state)
        let diagnostics = scene.diagnosticsSnapshot
        XCTAssertEqual(changedTileIdentifiers(before: before, after: after), expectedUpdates)
        XCTAssertEqual(diagnostics.createdTileCount, 0)
        XCTAssertEqual(diagnostics.updatedTileCount, expectedUpdates.count)
        XCTAssertEqual(diagnostics.reusedTileCount, state.tiles.count - expectedUpdates.count)
        XCTAssertEqual(diagnostics.removedTileCount, 0)
        XCTAssertEqual(diagnostics.updatedCoordinates, expectedUpdates)
    }

    @MainActor
    func testRendererOverlayAndCameraTransitionsPreserveBaseTileRoots() {
        let state = rendererNeighborhoodState()
        let center = GridCoordinate(x: 3, y: 3)
        let scene = CityScene(size: CGSize(width: 1_280, height: 800))
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        let initialIdentifiers = tileRootIdentifiers(in: scene, state: state)
        let initialNodeCount = scene.diagnosticsSnapshot.nodeCount

        scene.render(state: state, overlay: .landValue, selection: nil, interactionMode: .inspect)
        let overlayDiagnostics = scene.diagnosticsSnapshot
        XCTAssertEqual(tileRootIdentifiers(in: scene, state: state), initialIdentifiers)
        XCTAssertEqual(overlayDiagnostics.createdTileCount, 0)
        XCTAssertEqual(overlayDiagnostics.updatedTileCount, 0)
        XCTAssertEqual(overlayDiagnostics.reusedTileCount, state.tiles.count)
        XCTAssertEqual(overlayDiagnostics.overlayUpdateCount, state.tiles.count)
        XCTAssertGreaterThan(
            overlayDiagnostics.nodeCount,
            initialNodeCount,
            "Accepted coordinate-scoped Land Value truth must be visible without rebuilding base tiles"
        )
        XCTAssertLessThanOrEqual(
            overlayDiagnostics.nodeCount - initialNodeCount,
            state.tiles.count,
            "Sparse overlay presentation must remain bounded to at most one aggregate node per map tile"
        )

        scene.configureProofCamera(detail: .city, centeredOn: center)
        let cityDiagnostics = scene.diagnosticsSnapshot
        XCTAssertEqual(scene.currentCameraDetailLevel, .city)
        XCTAssertEqual(tileRootIdentifiers(in: scene, state: state), initialIdentifiers)
        XCTAssertEqual(cityDiagnostics.createdTileCount, 0)
        XCTAssertEqual(cityDiagnostics.updatedTileCount, 0)
        XCTAssertEqual(cityDiagnostics.reusedTileCount, state.tiles.count)
        XCTAssertEqual(cityDiagnostics.overlayUpdateCount, 0)

        scene.configureProofCamera(detail: .block, centeredOn: center)
        let blockDiagnostics = scene.diagnosticsSnapshot
        XCTAssertEqual(scene.currentCameraDetailLevel, .block)
        XCTAssertEqual(tileRootIdentifiers(in: scene, state: state), initialIdentifiers)
        XCTAssertEqual(blockDiagnostics.createdTileCount, 0)
        XCTAssertEqual(blockDiagnostics.updatedTileCount, 0)
        XCTAssertEqual(blockDiagnostics.reusedTileCount, state.tiles.count)
        XCTAssertGreaterThan(
            blockDiagnostics.nodeCount,
            cityDiagnostics.nodeCount,
            "Block LOD must reveal more typed overlay detail than the strategic city view"
        )
        XCTAssertLessThanOrEqual(
            blockDiagnostics.nodeCount - cityDiagnostics.nodeCount,
            state.tiles.count,
            "LOD overlay detail must remain bounded by the authoritative map"
        )
        print(
            "CITYSIM_OVERLAY_DIAGNOSTICS overlay_updates=\(overlayDiagnostics.overlayUpdateCount) " +
            "overlay_nodes=\(overlayDiagnostics.nodeCount) city_nodes=\(cityDiagnostics.nodeCount) " +
            "block_nodes=\(blockDiagnostics.nodeCount)"
        )
    }

    @MainActor
    func testRendererPublishesOneGroundedSelectionBoundaryWithoutFloatingCopy() {
        let state = rendererNeighborhoodState()
        let selectedCoordinate = GridCoordinate(x: 3, y: 3)
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.reducedMotion = true

        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertTrue(scene.selectionIsHiddenForTesting)
        XCTAssertFalse(descendantLabelTexts(in: scene).contains("SELECTED"))

        scene.render(state: state, overlay: .none, selection: selectedCoordinate, interactionMode: .inspect)
        XCTAssertFalse(scene.selectionIsHiddenForTesting)
        XCTAssertEqual(
            scene.interactionNamesForTesting.filter { $0 == "interaction.selection" }.count,
            1
        )
        XCTAssertEqual(
            scene.interactionNamesForTesting.filter { $0 == "interaction.selection.frontage-anchor" }.count,
            1
        )
        XCTAssertFalse(descendantLabelTexts(in: scene).contains("SELECTED"))

        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        XCTAssertTrue(scene.selectionIsHiddenForTesting)
        XCTAssertFalse(descendantLabelTexts(in: scene).contains("SELECTED"))
    }

    @MainActor
    func testRendererRoutesUnmodifiedKeyboardCommandsToCallbacks() throws {
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        var routedCommands: [CityCommandID] = []
        scene.onCommandAction = { routedCommands.append($0) }

        let commands: [(characters: String, keyCode: UInt16)] = [
            (" ", 49), ("1", 18), ("2", 19), ("3", 20), ("b", 11), ("v", 9)
        ]
        for command in commands {
            scene.keyDown(with: try keyEvent(characters: command.characters, keyCode: command.keyCode))
        }
        scene.keyDown(with: try keyEvent(characters: "\u{1b}", keyCode: 53))

        XCTAssertEqual(
            routedCommands,
            [.togglePause, .speedNormal, .speedFast, .speedFastest, .bulldozeMode, .inspectMode, .cancelInteraction]
        )

        scene.keyDown(with: try keyEvent(characters: "b", keyCode: 11, modifiers: .command))
        scene.keyDown(with: try keyEvent(characters: "v", keyCode: 9, modifiers: .option))
        scene.keyDown(with: try keyEvent(characters: "1", keyCode: 18, modifiers: .control))
        XCTAssertEqual(routedCommands.count, 7, "Modified keys must not double-route through the focused map")

        let state = rendererNeighborhoodState()
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        let roots = tileRootIdentifiers(in: scene, state: state)
        scene.configureProofCamera(detail: .city, centeredOn: GridCoordinate(x: 3, y: 3))
        XCTAssertEqual(scene.currentCameraDetailLevel, .city)

        scene.keyDown(with: try keyEvent(characters: "+", keyCode: 24, modifiers: .command))
        XCTAssertEqual(scene.currentCameraDetailLevel, .city, "Modified zoom commands belong to the app command system")
        for _ in 0..<5 {
            scene.keyDown(with: try keyEvent(characters: "+", keyCode: 24))
        }
        XCTAssertEqual(scene.currentCameraDetailLevel, .block)
        XCTAssertEqual(tileRootIdentifiers(in: scene, state: state), roots)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)
        XCTAssertEqual(scene.diagnosticsSnapshot.reusedTileCount, state.tiles.count)

        for _ in 0..<5 {
            scene.keyDown(with: try keyEvent(characters: "-", keyCode: 27))
        }
        XCTAssertEqual(scene.currentCameraDetailLevel, .city)
        XCTAssertEqual(tileRootIdentifiers(in: scene, state: state), roots)

        let expectedCityScaleLimit = scene.cityScaleLimitForTesting
        for _ in 0..<8 {
            scene.keyDown(with: try keyEvent(characters: "-", keyCode: 27))
        }
        XCTAssertEqual(scene.cameraScaleForTesting, expectedCityScaleLimit, accuracy: 0.001)
        XCTAssertLessThanOrEqual(scene.cameraScaleForTesting, 0.74)
        XCTAssertEqual(scene.currentCameraDetailLevel, .city)
        XCTAssertEqual(tileRootIdentifiers(in: scene, state: state), roots)

        scene.keyDown(with: try keyEvent(characters: "0", keyCode: 29))
        XCTAssertEqual(
            scene.currentCameraDetailLevel,
            .block,
            "Framing must retain block detail when the occupied-mass fit requires it at compact size"
        )
        XCTAssertEqual(tileRootIdentifiers(in: scene, state: state), roots)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)
        XCTAssertEqual(scene.diagnosticsSnapshot.reusedTileCount, state.tiles.count)
    }

    @MainActor
    func testPointerAnchoredZoomPreservesWorldPointAndClampsToStrategicRange() {
        let state = rendererNeighborhoodState()
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.reducedMotion = true
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        scene.configureProofCamera(
            detail: .city,
            centeredOn: GridCoordinate(x: 3, y: 3)
        )

        let anchor = scene.scenePointForTesting(at: GridCoordinate(x: 5, y: 4))
        let positionBefore = scene.cameraPositionForTesting
        let scaleBefore = scene.cameraScaleForTesting
        let normalizedAnchorBefore = CGPoint(
            x: (anchor.x - positionBefore.x) / scaleBefore,
            y: (anchor.y - positionBefore.y) / scaleBefore
        )

        scene.zoomCameraForTesting(by: 0.72, anchoredAt: anchor)

        let positionAfter = scene.cameraPositionForTesting
        let scaleAfter = scene.cameraScaleForTesting
        let normalizedAnchorAfter = CGPoint(
            x: (anchor.x - positionAfter.x) / scaleAfter,
            y: (anchor.y - positionAfter.y) / scaleAfter
        )
        XCTAssertLessThan(scaleAfter, scaleBefore)
        XCTAssertEqual(normalizedAnchorAfter.x, normalizedAnchorBefore.x, accuracy: 0.000_01)
        XCTAssertEqual(normalizedAnchorAfter.y, normalizedAnchorBefore.y, accuracy: 0.000_01)

        scene.zoomCameraForTesting(by: 0.000_1, anchoredAt: anchor)
        let minimumScale = scene.cameraScaleForTesting
        scene.zoomCameraForTesting(by: 0.000_1, anchoredAt: anchor)
        XCTAssertEqual(scene.cameraScaleForTesting, minimumScale, accuracy: 0.000_001)

        scene.zoomCameraForTesting(by: 10_000, anchoredAt: anchor)
        XCTAssertEqual(
            scene.cameraScaleForTesting,
            scene.cityScaleLimitForTesting,
            accuracy: 0.000_001
        )
    }

    @MainActor
    func testInteractionModesKeepPrimaryAndSecondaryActionsUnambiguous() {
        let occupied = GridCoordinate(x: 11, y: 11)
        let store = CityGameStore(state: .newCity(seed: 42))

        XCTAssertEqual(store.interactionMode, .inspect)
        store.activateInspectMode()
        store.primaryAction(at: occupied)
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertEqual(store.selectedCoordinate, occupied)
        XCTAssertTrue(store.showInspector)

        store.selectTool(.residential)
        store.showInspector = false
        store.selectedCoordinate = nil
        let beforeRejectedBuild = store.state
        store.primaryAction(at: occupied)
        XCTAssertEqual(store.state, beforeRejectedBuild)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertNil(store.selectedCoordinate, "An occupied build target must not silently become an inspection")
        XCTAssertFalse(store.showInspector)
        XCTAssertFalse(store.canUndo)

        store.toggleBulldozer()
        XCTAssertEqual(store.interactionMode, .bulldoze)
        store.cancelInteraction()
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertNil(store.selectedCoordinate)

        store.selectTool(.commercial)
        store.secondaryAction(at: occupied)
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertEqual(store.selectedCoordinate, occupied)
        XCTAssertTrue(store.showInspector)
    }

    @MainActor
    func testBuildAndBulldozeActionsRestoreExactStateThroughUndo() {
        let buildCoordinate = GridCoordinate(x: 4, y: 8)
        let demolitionCoordinate = GridCoordinate(x: 10, y: 11)
        let store = CityGameStore(state: .newCity(seed: 42))

        let beforeBuild = store.state
        store.selectTool(.residential)
        store.primaryAction(at: buildCoordinate)
        XCTAssertEqual(store.state.tile(at: buildCoordinate)?.kind, .residential)
        XCTAssertTrue(store.canUndo)
        store.undoLastAction()
        XCTAssertEqual(store.state, beforeBuild)

        let beforeDemolition = store.state
        store.toggleBulldozer()
        store.primaryAction(at: demolitionCoordinate)
        XCTAssertEqual(store.state.tile(at: demolitionCoordinate)?.kind, .empty)
        XCTAssertTrue(store.canUndo)
        store.undoLastAction()
        XCTAssertEqual(store.state, beforeDemolition)
    }

    @MainActor
    func testBulldozerModeActsOnMapAndSupportsUndo() {
        let coordinate = GridCoordinate(x: 10, y: 11)
        let store = CityGameStore(state: .newCity())
        XCTAssertEqual(store.state.tile(at: coordinate)?.kind, .residential)

        store.toggleBulldozer()
        store.primaryAction(at: coordinate)

        XCTAssertEqual(store.state.tile(at: coordinate)?.kind, .empty)
        XCTAssertTrue(store.canUndo)
        store.undoLastAction()
        XCTAssertEqual(store.state.tile(at: coordinate)?.kind, .residential)
    }

    @MainActor
    func testHUDRoutesMessagesAndSupportsDismissal() throws {
        let storm = CityMessage(
            tick: 8,
            severity: .warning,
            title: "Severe Storm",
            detail: "Utility crews are responding."
        )
        var state = CityGameState.newCity()
        state.messages = [storm]
        let store = CityGameStore(state: state)

        store.openMessage(storm)
        XCTAssertEqual(store.overlay, .utilities)
        XCTAssertEqual(store.inspectorSection, .utilities)
        XCTAssertTrue(store.showInspector)

        store.dismissMessage(storm.id)
        XCTAssertTrue(store.state.messages.isEmpty)

        let financeObjective = try XCTUnwrap(store.objectives.first { $0.id == "stabilize" })
        store.openObjective(financeObjective)
        XCTAssertEqual(store.inspectorSection, .finances)
    }

    @MainActor
    func testHUDContextDeckPreservesSelectionAcrossCityData() {
        let occupied = GridCoordinate(x: 10, y: 11)
        let store = CityGameStore(state: .newCity(seed: 42))

        store.select(occupied)
        XCTAssertEqual(store.selectedCoordinate, occupied)
        XCTAssertEqual(store.hudContextScope, .selection)
        XCTAssertTrue(store.showInspector)

        store.openInspector(.finances)
        XCTAssertEqual(store.inspectorSection, .finances)
        XCTAssertEqual(store.hudContextScope, .city)
        XCTAssertEqual(store.selectedCoordinate, occupied, "City data must not erase the map selection")
        XCTAssertTrue(store.showInspector)

        store.showSelectionContext()
        XCTAssertEqual(store.hudContextScope, .selection)
        XCTAssertEqual(store.selectedCoordinate, occupied)

        store.dismissInspector()
        XCTAssertFalse(store.showInspector)
        XCTAssertEqual(store.selectedCoordinate, occupied, "Closing details should preserve the selected block")

        store.toggleInspector()
        XCTAssertTrue(store.showInspector)
        XCTAssertEqual(store.hudContextScope, .selection)

        store.activateBuildMode()
        XCTAssertFalse(store.showInspector, "Build mode should reclaim the deck for project controls")
        XCTAssertEqual(store.interactionMode, .build(.road))

        store.cancelInteraction()
        XCTAssertFalse(store.showInspector)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertEqual(store.hudContextScope, .city)

        store.toggleInspector()
        XCTAssertTrue(store.showInspector)
        XCTAssertEqual(store.hudContextScope, .city)
    }

    func testHUDAnalyticsExposeDecisionReadyHeadroomAndRoadAccess() throws {
        let state = CityGameState.newCity(seed: 42)
        let analytics = CityAnalytics(state: state)
        let residential = try XCTUnwrap(state.tile(at: GridCoordinate(x: 10, y: 11)))

        XCTAssertEqual(analytics.housingHeadroom, max(0, analytics.housingCapacity - state.population))
        XCTAssertEqual(analytics.jobHeadroom, max(0, analytics.jobCapacity - state.jobs))
        XCTAssertEqual(analytics.powerHeadroom, max(0, state.powerCapacity - state.powerUsed))
        XCTAssertEqual(analytics.waterHeadroom, max(0, state.waterCapacity - state.waterUsed))
        XCTAssertEqual(analytics.housingUtilization, Double(state.population) / Double(analytics.housingCapacity), accuracy: 0.000_001)
        XCTAssertEqual(analytics.jobUtilization, Double(state.jobs) / Double(analytics.jobCapacity), accuracy: 0.000_001)
        XCTAssertTrue(analytics.hasRoadAccess(at: residential.coordinate))
        XCTAssertFalse(analytics.hasRoadAccess(at: GridCoordinate(x: 0, y: 0)))
        XCTAssertEqual(analytics.capacity(for: residential), 280 * residential.level)
        XCTAssertEqual(BuildingKind.road.demolitionCost, 50)
        XCTAssertEqual(BuildingKind.residential.demolitionCost, 144)
    }

    @MainActor
    func testMapFirstChromeDefaultsClosed() {
        let store = CityGameStore(state: .newCity())
        XCTAssertFalse(store.showInspector)
        XCTAssertFalse(store.showObjectives)
        XCTAssertFalse(ContentView.suppressesGameSurface(for: .enabled))
        XCTAssertTrue(ContentView.suppressesGameSurface(for: .blocked(.welcome)))
        XCTAssertTrue(ContentView.isCompactLayout(CGSize(width: 900, height: 600)))
        XCTAssertFalse(ContentView.isCompactLayout(CGSize(width: 1_200, height: 760)))
        XCTAssertEqual(
            ContentView.objectiveSurfacePresentation(compact: true, showObjectives: false, showInspector: true),
            .hidden
        )
        XCTAssertEqual(
            ContentView.objectiveSurfacePresentation(compact: true, showObjectives: true, showInspector: false),
            .expanded
        )
        XCTAssertEqual(
            ContentView.objectiveSurfacePresentation(compact: true, showObjectives: true, showInspector: true),
            .compactSummary
        )
        XCTAssertEqual(
            ContentView.objectiveSurfacePresentation(compact: false, showObjectives: true, showInspector: true),
            .expanded
        )
        XCTAssertLessThanOrEqual(TopHUDView.compactMaximumHeight, 104)
        XCTAssertLessThanOrEqual(TopHUDView.regularMaximumHeight, 118)
        XCTAssertLessThanOrEqual(BuildToolbarView.compactClosedMaximumHeight, 64)
        XCTAssertLessThanOrEqual(BuildToolbarView.regularSituationalMaximumHeight, 64)
        XCTAssertLessThanOrEqual(BuildToolbarView.regularClosedMaximumHeight, 108)
        XCTAssertLessThanOrEqual(BuildToolbarView.compactOpenMaximumHeight, 264)
        XCTAssertLessThanOrEqual(BuildToolbarView.regularOpenMaximumHeight, 208)
        XCTAssertLessThanOrEqual(BuildToolbarView.compactDetailsMaxHeight, 196)
        XCTAssertLessThanOrEqual(BuildToolbarView.regularDetailsMaxHeight, 144)
        XCTAssertEqual(BuildToolbarView.compactDetailsWidth, 720)
        XCTAssertEqual(BuildToolbarView.regularDetailsWidth, 840)
        XCTAssertEqual(BuildToolbarView.roadConnectionActionTitle(compact: true), "Build all")
        XCTAssertEqual(BuildToolbarView.roadConnectionActionTitle(compact: false), "Build route")
        XCTAssertLessThanOrEqual(StrategyCommandCenterView.compactMaximumHeight, 48)
        XCTAssertLessThanOrEqual(StrategyCommandCenterView.regularMaximumHeight, 52)
        XCTAssertEqual(BuildToolbarView.closedMaximumHeight(compact: true, isBuildMode: false), 60)
        XCTAssertEqual(BuildToolbarView.closedMaximumHeight(compact: false, isBuildMode: false), 60)
        XCTAssertEqual(BuildToolbarView.closedMaximumHeight(compact: false, isBuildMode: true), 60)
        XCTAssertLessThanOrEqual(FocusCityHUDView.compactMaximumHeight, 98)
        XCTAssertLessThanOrEqual(FocusCityHUDView.regularMaximumHeight, 68)
        XCTAssertGreaterThanOrEqual(GameTheme.hudCriticalTextSize, 11)
        XCTAssertGreaterThanOrEqual(GameTheme.hudSupportTextSize, 10)
        XCTAssertGreaterThanOrEqual(MetricCard.criticalTextSize, 11)
        XCTAssertGreaterThanOrEqual(MetricCard.supportTextSize, 10)
        XCTAssertGreaterThanOrEqual(TopHUDView.compactFinancePulseWidth, 160)
        XCTAssertLessThanOrEqual(TopHUDView.compactFinancePulseWidth, 170)
        XCTAssertEqual(InspectorView.compactColumnCount, 2)
        XCTAssertGreaterThanOrEqual(InspectorView.compactMinimumVisibleNoticeCount, 2)
        let compactClosedChrome = CityHUDChromeFrames(
            top: CGRect(x: 8, y: 8, width: 884, height: 64),
            bottom: CGRect(x: 8, y: 532, width: 884, height: 60)
        )
        XCTAssertGreaterThanOrEqual(
            ContentView.interactiveMapHeight(windowHeight: 600, chromeFrames: compactClosedChrome) / 600,
            0.68
        )
        let compactDetailsChrome = CityHUDChromeFrames(
            top: CGRect(x: 8, y: 8, width: 884, height: 64),
            bottom: CGRect(x: 8, y: 532, width: 884, height: 60)
        )
        XCTAssertGreaterThanOrEqual(
            ContentView.interactiveMapHeight(windowHeight: 600, chromeFrames: compactDetailsChrome) / 600,
            0.50
        )
        let compactFocusChrome = CityHUDChromeFrames(
            top: CGRect(x: 8, y: 8, width: 884, height: 98),
            bottom: .zero
        )
        XCTAssertGreaterThanOrEqual(
            ContentView.interactiveMapHeight(windowHeight: 600, chromeFrames: compactFocusChrome) / 600,
            0.80
        )
        let compactInsets = ContentView.mapViewportInsets(
            windowSize: CGSize(width: 900, height: 600),
            compact: true,
            chromeFrames: compactClosedChrome
        )
        XCTAssertEqual(compactInsets.top, 82)
        XCTAssertEqual(compactInsets.bottom, 78)
        let compactFocusInsets = ContentView.mapViewportInsets(
            windowSize: CGSize(width: 900, height: 600),
            compact: true,
            chromeFrames: compactFocusChrome
        )
        XCTAssertEqual(
            ContentView.resolvedMapViewportInsets(
                measured: compactFocusInsets,
                retainedForFocusCity: compactInsets,
                focusCity: true,
                bottomChromeIsVisible: false
            ),
            compactInsets,
            "Focus City must increase visible aperture without changing the renderer camera geometry"
        )
        XCTAssertEqual(
            ContentView.resolvedMapViewportInsets(
                measured: compactFocusInsets,
                retainedForFocusCity: compactInsets,
                focusCity: false,
                bottomChromeIsVisible: false
            ),
            compactInsets,
            "The exit transition must retain geometry until full chrome is measured again"
        )
        XCTAssertEqual(
            ContentView.resolvedMapViewportInsets(
                measured: compactInsets,
                retainedForFocusCity: compactInsets,
                focusCity: false,
                bottomChromeIsVisible: true
            ),
            compactInsets
        )
        XCTAssertNil(GameTheme.animation(reduceMotion: true))
        XCTAssertEqual(
            TopHUDView.simulationState(for: .paused),
            HUDSimulationStatePresentation(label: "PAUSED", symbol: "pause.fill", accessibilityValue: "Paused")
        )
        XCTAssertEqual(
            TopHUDView.simulationState(for: .fast),
            HUDSimulationStatePresentation(
                label: "RUNNING 2X",
                symbol: "play.fill",
                accessibilityValue: "Running at 2x speed"
            )
        )
        XCTAssertEqual(
            CityTrajectoryHUDPresentation.make(projectedBalance: -82),
            CityTrajectoryHUDPresentation(
                label: "-$82 / cycle",
                symbol: "arrow.down.right",
                accessibilityValue: "Losing $82 per cycle",
                isPositive: false
            )
        )
        XCTAssertEqual(
            CityTrajectoryHUDPresentation.make(projectedBalance: 93),
            CityTrajectoryHUDPresentation(
                label: "+$93 / cycle",
                symbol: "arrow.up.right",
                accessibilityValue: "Growing by $93 per cycle",
                isPositive: true
            )
        )
        XCTAssertEqual(
            CityTrajectoryHUDPresentation.make(projectedBalance: 0).accessibilityValue,
            "Holding steady"
        )
    }

    @MainActor
    func testFocusCityViewportInsetsPublishOnlyVisibleTopRail() {
        let regular = ContentView.focusCityViewportInsets(
            compact: false,
            chromeFrame: CGRect(x: 16, y: 16, width: 1_246, height: FocusCityHUDView.regularMaximumHeight)
        )
        XCTAssertEqual(regular.top, 94)
        XCTAssertEqual(regular.leading, 0)
        XCTAssertEqual(regular.bottom, 0)
        XCTAssertEqual(regular.trailing, 0)

        let compactFallback = ContentView.focusCityViewportInsets(
            compact: true,
            chromeFrame: .zero
        )
        XCTAssertEqual(compactFallback.top, 117)
        XCTAssertEqual(compactFallback.leading, 0)
        XCTAssertEqual(compactFallback.bottom, 0)
        XCTAssertEqual(compactFallback.trailing, 0)
    }

    @MainActor
    func testCompactSimulationLabelStaysVisibleWhileAccessibilityKeepsFullState() {
        XCTAssertEqual(TopHUDView.compactSimulationLabel(for: .normal), "1×")
        XCTAssertEqual(TopHUDView.compactSimulationLabel(for: .fast), "2×")
        XCTAssertEqual(TopHUDView.compactSimulationLabel(for: .fastest), "3×")
        XCTAssertEqual(TopHUDView.compactSimulationLabel(for: .paused), "Paused")
        XCTAssertEqual(TopHUDView.simulationState(for: .fast).label, "RUNNING 2X")
        XCTAssertEqual(
            TopHUDView.simulationState(for: .fast).accessibilityValue,
            "Running at 2x speed"
        )
        XCTAssertEqual(
            TopHUDView.simulationState(for: .paused).accessibilityValue,
            "Paused"
        )
        XCTAssertEqual(
            TopHUDView.simulationControlAccessibilityLabel(for: .paused),
            "Resume simulation"
        )
        XCTAssertEqual(
            TopHUDView.simulationControlAccessibilityLabel(for: .normal),
            "Pause simulation"
        )
        XCTAssertEqual(
            TopHUDView.simulationControlHelp(for: .paused),
            "Resume simulation · Space"
        )
        XCTAssertEqual(
            TopHUDView.simulationControlHelp(for: .fast),
            "Pause simulation · Space"
        )
    }

    @MainActor
    func testSelectedTargetBeaconPresentsInspectBuildBulldozeNilReadyAndBlockedTruth() throws {
        let state = CityGameState.newCity(seed: 42)
        let cityHall = try XCTUnwrap(state.tiles.first { $0.kind == .cityHall })
        let removable = try XCTUnwrap(state.tiles.first {
            $0.kind != .empty && $0.kind != .cityHall
        })
        let validRoad = try XCTUnwrap(state.tiles.first { tile in
            if case .success = CitySimulation.validateBuild(.road, at: tile.coordinate, in: state) {
                return true
            }
            return false
        })

        func presentation(_ store: CityGameStore) -> BuildToolbarView.TargetBeaconPresentation {
            BuildToolbarView.targetBeaconPresentation(
                interactionMode: store.interactionMode,
                selectedTile: store.selectedTile,
                target: store.activeMapActionTargetPresentation
            )
        }

        let inspectNil = presentation(CityGameStore(state: state))
        XCTAssertEqual(inspectNil.title, "No block selected")
        XCTAssertEqual(inspectNil.detail, "Choose a block")
        XCTAssertEqual(inspectNil.status, "INSPECT")
        XCTAssertEqual(inspectNil.accessibilityLabel, "Inspect mode")
        XCTAssertEqual(inspectNil.accessibilityValue, "No block selected")
        XCTAssertFalse(inspectNil.opensDetails)

        let inspectStore = CityGameStore(state: state)
        inspectStore.selectedCoordinate = cityHall.coordinate
        let inspect = presentation(inspectStore)
        XCTAssertEqual(inspect.title, "City Hall")
        XCTAssertEqual(
            inspect.detail,
            "Block \(cityHall.coordinate.x + 1), \(cityHall.coordinate.y + 1)"
        )
        XCTAssertEqual(inspect.status, "INSPECT")
        XCTAssertEqual(inspect.tone, .information)
        XCTAssertEqual(
            inspect.accessibilityLabel,
            "Open details for City Hall at block \(cityHall.coordinate.x + 1), \(cityHall.coordinate.y + 1)"
        )
        XCTAssertEqual(
            inspect.accessibilityValue,
            inspectStore.activeMapActionTargetPresentation?.primaryAction.disclosure
        )
        XCTAssertTrue(inspect.opensDetails)

        let buildNilStore = CityGameStore(state: state)
        buildNilStore.selectTool(.road)
        let buildNil = presentation(buildNilStore)
        XCTAssertEqual(buildNil.title, "Road")
        XCTAssertEqual(buildNil.status, "CHOOSE")
        XCTAssertEqual(buildNil.accessibilityLabel, "Build Road")
        XCTAssertTrue(buildNil.accessibilityValue.contains("Choose a block"))
        XCTAssertFalse(buildNil.opensDetails)

        let buildReadyStore = CityGameStore(state: state)
        buildReadyStore.selectTool(.road)
        buildReadyStore.selectedCoordinate = validRoad.coordinate
        let buildReady = presentation(buildReadyStore)
        XCTAssertEqual(buildReady.title, "Road")
        XCTAssertEqual(buildReady.status, "READY")
        XCTAssertEqual(buildReady.tone, .ready)
        XCTAssertEqual(
            buildReady.accessibilityLabel,
            "Open details for Road at block \(validRoad.coordinate.x + 1), \(validRoad.coordinate.y + 1)"
        )
        XCTAssertEqual(
            buildReady.accessibilityValue,
            buildReadyStore.activeMapActionTargetPresentation?.primaryAction.disclosure
        )
        XCTAssertTrue(buildReady.opensDetails)

        let buildBlockedStore = CityGameStore(state: state)
        buildBlockedStore.selectTool(.road)
        buildBlockedStore.selectedCoordinate = cityHall.coordinate
        let buildBlocked = presentation(buildBlockedStore)
        XCTAssertEqual(buildBlocked.title, "Road")
        XCTAssertEqual(buildBlocked.status, "BLOCKED")
        XCTAssertEqual(buildBlocked.tone, .blocked)
        XCTAssertEqual(
            buildBlocked.accessibilityLabel,
            "Open details for Road at block \(cityHall.coordinate.x + 1), \(cityHall.coordinate.y + 1)"
        )
        XCTAssertEqual(
            buildBlocked.accessibilityValue,
            buildBlockedStore.activeMapActionTargetPresentation?.primaryAction.disclosure
        )
        XCTAssertTrue(buildBlocked.opensDetails)

        let bulldozeNilStore = CityGameStore(state: state)
        bulldozeNilStore.interactionMode = .bulldoze
        let bulldozeNil = presentation(bulldozeNilStore)
        XCTAssertEqual(bulldozeNil.title, "No structure selected")
        XCTAssertEqual(bulldozeNil.status, "BULLDOZE")
        XCTAssertEqual(bulldozeNil.accessibilityLabel, "Bulldoze mode")
        XCTAssertTrue(bulldozeNil.accessibilityValue.contains("Choose a structure"))
        XCTAssertFalse(bulldozeNil.opensDetails)

        let bulldozeReadyStore = CityGameStore(state: state)
        bulldozeReadyStore.interactionMode = .bulldoze
        bulldozeReadyStore.selectedCoordinate = removable.coordinate
        let bulldozeReady = presentation(bulldozeReadyStore)
        XCTAssertEqual(bulldozeReady.title, removable.kind.title)
        XCTAssertEqual(bulldozeReady.status, "READY")
        XCTAssertEqual(bulldozeReady.tone, .ready)
        XCTAssertEqual(
            bulldozeReady.accessibilityLabel,
            "Open details for \(removable.kind.title) at block "
                + "\(removable.coordinate.x + 1), \(removable.coordinate.y + 1)"
        )
        XCTAssertEqual(
            bulldozeReady.accessibilityValue,
            bulldozeReadyStore.activeMapActionTargetPresentation?.primaryAction.disclosure
        )
        XCTAssertTrue(bulldozeReady.opensDetails)

        let bulldozeBlockedStore = CityGameStore(state: state)
        bulldozeBlockedStore.interactionMode = .bulldoze
        bulldozeBlockedStore.selectedCoordinate = cityHall.coordinate
        let bulldozeBlocked = presentation(bulldozeBlockedStore)
        XCTAssertEqual(bulldozeBlocked.title, "City Hall")
        XCTAssertEqual(bulldozeBlocked.status, "BLOCKED")
        XCTAssertEqual(bulldozeBlocked.tone, .blocked)
        XCTAssertEqual(
            bulldozeBlocked.accessibilityLabel,
            "Open details for City Hall at block "
                + "\(cityHall.coordinate.x + 1), \(cityHall.coordinate.y + 1)"
        )
        XCTAssertEqual(
            bulldozeBlocked.accessibilityValue,
            bulldozeBlockedStore.activeMapActionTargetPresentation?.primaryAction.disclosure
        )
        XCTAssertTrue(bulldozeBlocked.opensDetails)
    }

    @MainActor
    func testBuildSurfacePresentsLiveDevelopmentDemandWithoutInventingItForOtherTools() {
        var state = CityGameState.newCity(seed: 42)
        state.demand = DemandLevels(
            residential: 0.587,
            commercial: 0.756,
            industrial: 0.704
        )

        XCTAssertEqual(
            BuildToolbarView.buildCatalogItemTitle(for: .residential, in: state),
            "Residential · Steady demand 59% · $1,800 · forecast at block"
        )
        XCTAssertEqual(
            BuildToolbarView.buildCatalogItemTitle(for: .commercial, in: state),
            "Commercial · High demand 76% · $2,400 · forecast at block"
        )
        XCTAssertEqual(
            BuildToolbarView.buildCatalogItemTitle(for: .industrial, in: state),
            "Industrial · High demand 70% · $3,200 · forecast at block"
        )
        XCTAssertEqual(
            BuildToolbarView.buildCatalogItemTitle(for: .road, in: state),
            "Road · $120 · forecast at block"
        )
        XCTAssertNil(
            BuildToolbarView.developmentDemandPresentation(for: .park, in: state)
        )

        let demand = BuildToolbarView.developmentDemandPresentation(
            for: .commercial,
            in: state
        )
        let selected = BuildToolbarView.targetBeaconPresentation(
            interactionMode: .build(.commercial),
            selectedTile: nil,
            target: nil,
            demand: demand,
            buildOpportunities: CityBuildOpportunityInventory(
                totalCount: 40,
                outlinedCoordinates: (0..<6).map {
                    GridCoordinate(x: $0, y: 0)
                }
            )
        )
        XCTAssertEqual(selected.title, "Commercial · 6 nearby sites")
        XCTAssertEqual(selected.detail, "40 eligible · High demand 76% · $2,400")
        XCTAssertTrue(selected.accessibilityValue.contains("High demand, 76 percent"))
        XCTAssertTrue(selected.accessibilityValue.contains("Cost $2,400"))
        XCTAssertTrue(selected.accessibilityValue.contains("6 nearby eligible sites are outlined"))
        XCTAssertTrue(selected.accessibilityValue.contains("40 sites are eligible in total"))

        let actualOpportunities = CityBuildOpportunityInventory.make(
            kind: .commercial,
            in: state
        )
        let strengthened = BuildToolbarView.targetBeaconPresentation(
            interactionMode: .build(.commercial),
            selectedTile: nil,
            target: nil,
            demand: demand,
            buildOpportunities: actualOpportunities
        )
        XCTAssertEqual(strengthened.title, "Commercial · High 76% · $2.4K")
        XCTAssertEqual(
            strengthened.detail,
            "\(actualOpportunities?.detail ?? "") · ◆ Value · •• Util · ○ Air"
        )
        XCTAssertTrue(strengthened.accessibilityValue.contains("Strongest utilities"))
        XCTAssertTrue(strengthened.accessibilityValue.contains("Highest land value"))
        XCTAssertTrue(strengthened.accessibilityValue.contains("Lowest pollution"))

        let unlimited = BuildToolbarView.targetBeaconPresentation(
            interactionMode: .build(.commercial),
            selectedTile: nil,
            target: nil,
            unlimitedFunds: true,
            demand: demand,
            buildOpportunities: CityBuildOpportunityInventory(
                totalCount: 1,
                outlinedCoordinates: [GridCoordinate(x: 0, y: 0)]
            )
        )
        XCTAssertEqual(unlimited.title, "Commercial · 1 site")
        XCTAssertEqual(unlimited.detail, "All eligible sites outlined · High demand 76% · COST WAIVED")
        XCTAssertTrue(unlimited.accessibilityValue.contains("Spending is waived"))
        XCTAssertTrue(unlimited.accessibilityValue.contains("1 eligible site is outlined"))

        let blocked = BuildToolbarView.targetBeaconPresentation(
            interactionMode: .build(.commercial),
            selectedTile: nil,
            target: nil,
            demand: demand,
            buildOpportunities: CityBuildOpportunityInventory(
                totalCount: 0,
                outlinedCoordinates: []
            )
        )
        XCTAssertEqual(blocked.detail, "No eligible sites · High demand 76% · $2,400")
        XCTAssertTrue(blocked.accessibilityValue.contains("No eligible sites are available"))
    }

    @MainActor
    func testSelectedTargetBeaconActivatesDetailsExactlyOnceAndEscapeRestoresMapFocus() throws {
        let state = CityGameState.newCity(seed: 42)
        let cityHall = try XCTUnwrap(state.tiles.first { $0.kind == .cityHall })
        let store = CityGameStore(state: state)
        store.selectedCoordinate = cityHall.coordinate
        store.hudContextScope = .city

        let stateBefore = store.state
        let focusBefore = store.mapFocusRequestGeneration
        let selectedBefore = store.selectedCoordinate
        let modeBefore = store.interactionMode
        let undoBefore = store.canUndo

        XCTAssertTrue(BuildToolbarView.activateTargetBeacon(store: store))
        XCTAssertTrue(store.showInspector, "Exactly one toggle must leave Details open")
        XCTAssertEqual(store.hudContextScope, .selection)
        XCTAssertEqual(store.state, stateBefore)
        XCTAssertEqual(store.selectedCoordinate, selectedBefore)
        XCTAssertEqual(store.interactionMode, modeBefore)
        XCTAssertEqual(store.canUndo, undoBefore)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusBefore)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showInspector)
        XCTAssertEqual(store.state, stateBefore)
        XCTAssertEqual(store.selectedCoordinate, selectedBefore)
        XCTAssertEqual(store.interactionMode, modeBefore)
        XCTAssertEqual(store.canUndo, undoBefore)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusBefore + 1)

        let nilStore = CityGameStore(state: state)
        XCTAssertFalse(BuildToolbarView.activateTargetBeacon(store: nilStore))
        XCTAssertFalse(nilStore.showInspector)
        XCTAssertEqual(nilStore.mapFocusRequestGeneration, 0)
    }

    @MainActor
    func testSelectedTargetBeaconFitsClosedRegularAndCompactRailWithoutReducingAperture() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let cityHall = try XCTUnwrap(store.state.tiles.first { $0.kind == .cityHall })
        store.speed = .paused
        store.selectedCoordinate = cityHall.coordinate

        let compactSize = CGSize(width: 884, height: BuildToolbarView.compactClosedMaximumHeight)
        let compact = try toolbarBitmap(size: compactSize, store: store, compact: true)
        XCTAssertEqual(compact.size.width, compactSize.width, accuracy: 0.5)
        XCTAssertEqual(compact.size.height, compactSize.height, accuracy: 0.5)

        let regularWindowSize = CGSize(width: 1_278, height: 768)
        XCTAssertFalse(ContentView.isCompactLayout(regularWindowSize))
        let regularSize = CGSize(
            width: 1_120,
            height: BuildToolbarView.regularSituationalMaximumHeight
        )
        XCTAssertEqual(regularSize.width, 1_120, "Bind the real regular command-rail maximum")
        let regular = try toolbarBitmap(size: regularSize, store: store, compact: false)
        XCTAssertEqual(regular.size.width, regularSize.width, accuracy: 0.5)
        XCTAssertEqual(regular.size.height, regularSize.height, accuracy: 0.5)
        XCTAssertEqual(BuildToolbarView.compactClosedMaximumHeight, 60)
        XCTAssertEqual(BuildToolbarView.regularSituationalMaximumHeight, 60)

        let compactChrome = CityHUDChromeFrames(
            top: CGRect(x: 8, y: 8, width: 884, height: 64),
            bottom: CGRect(x: 8, y: 532, width: 884, height: 60)
        )
        XCTAssertEqual(
            ContentView.interactiveMapHeight(windowHeight: 600, chromeFrames: compactChrome),
            460
        )

        if let path = ProcessInfo.processInfo.environment["CITYSIM_PLAY082_COMPACT_BEACON_PROOF"] {
            let data = try XCTUnwrap(compact.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        if let path = ProcessInfo.processInfo.environment["CITYSIM_PLAY082_REGULAR_BEACON_PROOF"] {
            let data = try XCTUnwrap(regular.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @MainActor
    func testViewportInsetsTrackSettledChromeAcrossClosedDecisionDetailsAndPostCloseLayouts() {
        XCTAssertEqual(
            ContentView.mapViewportInsets(
                windowSize: CGSize(width: 900, height: 600),
                compact: true,
                chromeFrames: CityHUDChromeFrames()
            ),
            CityMapViewportInsets(top: 136, leading: 19, bottom: 116, trailing: 19),
            "Fallback protection applies only before SwiftUI publishes valid chrome geometry"
        )

        struct Scenario {
            let name: String
            let window: CGSize
            let compact: Bool
            let top: CGRect
            let closedBottom: CGRect
            let decisionBottom: CGRect
            let detailsBottom: CGRect
            let expectedTopInset: CGFloat
            let expectedClosedBottomInset: CGFloat
            let expectedDecisionBottomInset: CGFloat
            let expectedDetailsBottomInset: CGFloat
            let expectedClosedMapHeight: CGFloat
            let expectedDecisionMapHeight: CGFloat
            let expectedDetailsMapHeight: CGFloat
        }

        let scenarios = [
            Scenario(
                name: "compact",
                window: CGSize(width: 900, height: 600),
                compact: true,
                top: CGRect(x: 8, y: 8, width: 884, height: 64),
                closedBottom: CGRect(x: 8, y: 532, width: 884, height: 60),
                decisionBottom: CGRect(x: 8, y: 480, width: 884, height: 112),
                detailsBottom: CGRect(x: 8, y: 532, width: 884, height: 60),
                expectedTopInset: 82,
                expectedClosedBottomInset: 78,
                expectedDecisionBottomInset: 130,
                expectedDetailsBottomInset: 78,
                expectedClosedMapHeight: 460,
                expectedDecisionMapHeight: 408,
                expectedDetailsMapHeight: 460
            ),
            Scenario(
                name: "regular",
                window: CGSize(width: 1_278, height: 768),
                compact: false,
                top: CGRect(x: 8, y: 8, width: 1_262, height: 68),
                closedBottom: CGRect(x: 79, y: 700, width: 1_120, height: 60),
                decisionBottom: CGRect(x: 79, y: 648, width: 1_120, height: 112),
                detailsBottom: CGRect(x: 79, y: 700, width: 1_120, height: 60),
                expectedTopInset: 86,
                expectedClosedBottomInset: 78,
                expectedDecisionBottomInset: 130,
                expectedDetailsBottomInset: 78,
                expectedClosedMapHeight: 624,
                expectedDecisionMapHeight: 572,
                expectedDetailsMapHeight: 624
            )
        ]

        for scenario in scenarios {
            var settled = CityHUDChromeFrames(top: scenario.top, bottom: scenario.closedBottom)

            func assertLayout(
                _ name: String,
                bottomInset: CGFloat,
                mapHeight: CGFloat,
                file: StaticString = #filePath,
                line: UInt = #line
            ) {
                let insets = ContentView.mapViewportInsets(
                    windowSize: scenario.window,
                    compact: scenario.compact,
                    chromeFrames: settled
                )
                XCTAssertEqual(insets.top, scenario.expectedTopInset, "\(scenario.name) \(name)", file: file, line: line)
                XCTAssertEqual(insets.bottom, bottomInset, "\(scenario.name) \(name)", file: file, line: line)
                XCTAssertEqual(
                    ContentView.interactiveMapHeight(
                        windowHeight: scenario.window.height,
                        chromeFrames: settled
                    ),
                    mapHeight,
                    "\(scenario.name) \(name)",
                    file: file,
                    line: line
                )
            }

            assertLayout(
                "closed",
                bottomInset: scenario.expectedClosedBottomInset,
                mapHeight: scenario.expectedClosedMapHeight
            )

            settled.bottom = scenario.decisionBottom
            assertLayout(
                "active decision",
                bottomInset: scenario.expectedDecisionBottomInset,
                mapHeight: scenario.expectedDecisionMapHeight
            )

            settled.bottom = scenario.detailsBottom
            assertLayout(
                "details",
                bottomInset: scenario.expectedDetailsBottomInset,
                mapHeight: scenario.expectedDetailsMapHeight
            )

            settled.bottom = scenario.closedBottom
            assertLayout(
                "post-close settlement",
                bottomInset: scenario.expectedClosedBottomInset,
                mapHeight: scenario.expectedClosedMapHeight
            )
        }
    }

    @MainActor
    func testBlockingWelcomePreservesExactAuthoredStartUntilDismissed() {
        let defaults = UserDefaults.standard
        let priorWelcome = defaults.object(forKey: "hasSeenCitySimWelcome")
        defaults.set(false, forKey: "hasSeenCitySimWelcome")
        defer {
            if let priorWelcome { defaults.set(priorWelcome, forKey: "hasSeenCitySimWelcome") }
            else { defaults.removeObject(forKey: "hasSeenCitySimWelcome") }
        }

        let authoredStart = CityGameState.newCity(seed: 42)
        let store = CityGameStore(state: authoredStart, commandPolicy: .blocked(.welcome))
        let size = CGSize(width: 1_278, height: 768)
        let view = NSHostingView(rootView: ContentView(store: store).frame(width: size.width, height: size.height))
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.9))

        XCTAssertEqual(store.commandPolicy, .blocked(.welcome))
        XCTAssertEqual(store.state, authoredStart)
        XCTAssertEqual(store.state.day, authoredStart.day)
        XCTAssertEqual(store.state.messages, authoredStart.messages)
        XCTAssertEqual(store.state.progression, authoredStart.progression)
        XCTAssertEqual(store.state.treasury, authoredStart.treasury)
        XCTAssertEqual(store.state.population, authoredStart.population)
        XCTAssertEqual(store.state.powerUsed, authoredStart.powerUsed)
        XCTAssertEqual(store.state.waterUsed, authoredStart.waterUsed)

        defaults.set(true, forKey: "hasSeenCitySimWelcome")
        let resumedStore = CityGameStore(state: authoredStart)
        let resumedView = NSHostingView(rootView: ContentView(store: resumedStore).frame(width: size.width, height: size.height))
        resumedView.frame = CGRect(origin: .zero, size: size)
        resumedView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.9))

        XCTAssertEqual(resumedStore.commandPolicy, .enabled)
        XCTAssertGreaterThan(resumedStore.state.tick, authoredStart.tick)
    }

    @MainActor
    func testMessageSummariesGroupRepeatedEventsAndDismissTogether() throws {
        let newestStorm = CityMessage(tick: 12, severity: .warning, title: "Severe Storm", detail: "Newest storm")
        let earlierStorm = CityMessage(tick: 8, severity: .warning, title: "Severe Storm", detail: "Earlier storm")
        let grant = CityMessage(tick: 4, severity: .good, title: "State Growth Grant", detail: "Grant")
        var state = CityGameState.newCity()
        state.messages = [newestStorm, earlierStorm, grant]
        let store = CityGameStore(state: state)

        XCTAssertEqual(store.messageSummaries.map(\.message), [newestStorm, grant])
        XCTAssertEqual(store.messageSummaries.first?.count, 2)

        let initialPresentationID = try XCTUnwrap(store.messageSummaries.first?.presentationID)
        let latestStorm = CityMessage(tick: 16, severity: .warning, title: "Severe Storm", detail: "Latest storm")
        store.state.messages.insert(latestStorm, at: 0)
        XCTAssertEqual(store.messageSummaries.first?.id, "warning-Severe Storm")
        XCTAssertEqual(store.messageSummaries.first?.count, 3)
        XCTAssertNotEqual(store.messageSummaries.first?.presentationID, initialPresentationID)

        let summary = try XCTUnwrap(store.messageSummaries.first)
        store.dismissMessageSummary(summary)
        XCTAssertEqual(store.state.messages, [grant])
    }

    @MainActor
    func testObjectiveSummaryPrioritizesIncompleteMandate() {
        let store = CityGameStore(state: .newCity())

        XCTAssertEqual(store.completedObjectiveCount, 0)
        XCTAssertEqual(store.primaryObjective.id, "stabilize")
    }

    @MainActor
    func testCompactInterfaceProducesInspectableFrame() throws {
        let defaults = UserDefaults.standard
        let priorWelcome = defaults.object(forKey: "hasSeenCitySimWelcome")
        defaults.set(true, forKey: "hasSeenCitySimWelcome")
        defer {
            if let priorWelcome { defaults.set(priorWelcome, forKey: "hasSeenCitySimWelcome") }
            else { defaults.removeObject(forKey: "hasSeenCitySimWelcome") }
        }

        let store = CityGameStore(state: .newCity(seed: 42))
        store.speed = .fast
        let bitmap = try hudBitmap(size: CGSize(width: 900, height: 600), store: store)
        XCTAssertGreaterThan(bitmap.pixelsWide, 850)
        XCTAssertGreaterThan(bitmap.pixelsHigh, 550)

        if let path = ProcessInfo.processInfo.environment["CITYSIM_COMPACT_PROOF"] {
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @MainActor
    func testHUDCommandDeckProducesRegularAndCompactContextFrames() throws {
        let defaults = UserDefaults.standard
        let priorWelcome = defaults.object(forKey: "hasSeenCitySimWelcome")
        defaults.set(true, forKey: "hasSeenCitySimWelcome")
        defer {
            if let priorWelcome { defaults.set(priorWelcome, forKey: "hasSeenCitySimWelcome") }
            else { defaults.removeObject(forKey: "hasSeenCitySimWelcome") }
        }

        let regularStore = CityGameStore(state: .newCity(seed: 42))
        regularStore.speed = .paused
        regularStore.openInspector(.finances)
        let regular = try hudBitmap(size: CGSize(width: 1_278, height: 768), store: regularStore)
        XCTAssertGreaterThan(regular.pixelsWide, 1_200)
        XCTAssertGreaterThan(regular.pixelsHigh, 700)
        if let path = ProcessInfo.processInfo.environment["CITYSIM_HUD_REGULAR_CONTEXT_PROOF"] {
            let data = try XCTUnwrap(regular.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }

        let compactStore = CityGameStore(state: .newCity(seed: 42))
        compactStore.speed = .paused
        compactStore.select(GridCoordinate(x: 10, y: 11))
        let compact = try hudBitmap(size: CGSize(width: 900, height: 600), store: compactStore)
        XCTAssertGreaterThan(compact.pixelsWide, 850)
        XCTAssertGreaterThan(compact.pixelsHigh, 550)
        XCTAssertEqual(compactStore.hudContextScope, .selection)
        XCTAssertNotNil(compactStore.selectedTile)
        if let path = ProcessInfo.processInfo.environment["CITYSIM_HUD_COMPACT_CONTEXT_PROOF"] {
            let data = try XCTUnwrap(compact.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }

        let compactArbitratedStore = CityGameStore(state: .newCity(seed: 42))
        compactArbitratedStore.speed = .paused
        compactArbitratedStore.showObjectives = true
        compactArbitratedStore.openInspector(.utilities)
        let compactArbitrated = try hudBitmap(size: CGSize(width: 900, height: 600), store: compactArbitratedStore)
        XCTAssertTrue(compactArbitratedStore.showObjectives)
        XCTAssertTrue(compactArbitratedStore.showInspector)
        XCTAssertEqual(
            ContentView.objectiveSurfacePresentation(compact: true, showObjectives: true, showInspector: true),
            .compactSummary
        )
        XCTAssertGreaterThan(compactArbitrated.pixelsWide, 850)
        XCTAssertGreaterThan(compactArbitrated.pixelsHigh, 550)
        if let path = ProcessInfo.processInfo.environment["CITYSIM_HUD_COMPACT_ARBITRATED_PROOF"] {
            let data = try XCTUnwrap(compactArbitrated.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }

        var journalState = CityGameState.newCity(seed: 42)
        journalState.messages = (1...7).map { index in
            CityMessage(
                tick: index * 4,
                severity: index.isMultiple(of: 3) ? .warning : .information,
                title: "District update \(index)",
                detail: "A distinct city notice that remains available in the bounded command-center journal."
            )
        }
        let journalStore = CityGameStore(state: journalState)
        journalStore.speed = .paused
        journalStore.openInspector(.journal)
        XCTAssertEqual(journalStore.messageSummaries.count, 7)
        let journal = try hudBitmap(size: CGSize(width: 900, height: 600), store: journalStore)
        XCTAssertGreaterThan(journal.pixelsWide, 850)
        XCTAssertGreaterThan(journal.pixelsHigh, 550)
        if let path = ProcessInfo.processInfo.environment["CITYSIM_HUD_COMPACT_JOURNAL_PROOF"] {
            let data = try XCTUnwrap(journal.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }

        let buildStore = CityGameStore(state: .newCity(seed: 42))
        buildStore.speed = .paused
        buildStore.selectTool(.commercial)
        buildStore.selectedCoordinate = try XCTUnwrap(
            buildStore.state.tiles.first { tile in
                guard tile.kind == .empty else { return false }
                if case .success = CitySimulation.validateBuild(
                    .commercial,
                    at: tile.coordinate,
                    in: buildStore.state
                ) {
                    return true
                }
                return false
            }?.coordinate
        )
        XCTAssertEqual(buildStore.interactionMode, .build(.commercial))
        XCTAssertNotNil(buildStore.activeMapActionTargetPresentation?.primaryAction.buildDecision)
        let regularBuild = try hudBitmap(size: CGSize(width: 1_280, height: 800), store: buildStore)
        XCTAssertGreaterThan(regularBuild.pixelsWide, 1_200)
        XCTAssertGreaterThan(regularBuild.pixelsHigh, 700)
        if let path = ProcessInfo.processInfo.environment["CITYSIM_HUD_REGULAR_BUILD_PROOF"] {
            let data = try XCTUnwrap(regularBuild.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        let build = try hudBitmap(size: CGSize(width: 900, height: 600), store: buildStore)
        XCTAssertGreaterThan(build.pixelsWide, 850)
        XCTAssertGreaterThan(build.pixelsHigh, 550)
        if let path = ProcessInfo.processInfo.environment["CITYSIM_HUD_COMPACT_BUILD_PROOF"] {
            let data = try XCTUnwrap(build.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }

        var focusState = CityGameState.newCity(seed: 42)
        focusState.messages = [
            CityMessage(
                tick: focusState.tick,
                severity: .critical,
                title: "Severe Storm",
                detail: "A critical authored notice must remain visible in Focus City."
            )
        ]
        let focusStore = CityGameStore(state: focusState)
        focusStore.speed = .paused
        focusStore.selectTool(.commercial)
        focusStore.selectedCoordinate = GridCoordinate(x: 12, y: 12)
        focusStore.showObjectives = true
        focusStore.openInspector(.utilities)
        XCTAssertTrue(focusStore.perform(.toggleCityFocus))
        let focus = try hudBitmap(size: CGSize(width: 900, height: 600), store: focusStore)
        XCTAssertGreaterThan(focus.pixelsWide, 850)
        XCTAssertGreaterThan(focus.pixelsHigh, 550)
        XCTAssertTrue(focusStore.isCityFocusModeEnabled)
        XCTAssertTrue(focusStore.showObjectives)
        XCTAssertTrue(focusStore.showInspector)
        XCTAssertEqual(focusStore.inspectorSection, .utilities)
        XCTAssertEqual(focusStore.selectedCoordinate, GridCoordinate(x: 12, y: 12))
        XCTAssertEqual(focusStore.interactionMode, .build(.commercial))
        XCTAssertEqual(focusStore.alertCount, 1)
        XCTAssertEqual(focusStore.highestAlertSeverity, .critical)
        if let path = ProcessInfo.processInfo.environment["CITYSIM_FOCUS_CITY_COMPACT_PROOF"] {
            let data = try XCTUnwrap(focus.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }

        let regularFocusStore = CityGameStore(state: focusState)
        regularFocusStore.speed = .paused
        regularFocusStore.selectTool(.commercial)
        regularFocusStore.selectedCoordinate = GridCoordinate(x: 12, y: 12)
        XCTAssertTrue(regularFocusStore.perform(.toggleCityFocus))
        let regularFocus = try hudBitmap(
            size: CGSize(width: 1_278, height: 768),
            store: regularFocusStore
        )
        XCTAssertGreaterThan(regularFocus.pixelsWide, 1_200)
        XCTAssertGreaterThan(regularFocus.pixelsHigh, 700)
        XCTAssertEqual(regularFocusStore.alertCount, 1)
        XCTAssertEqual(regularFocusStore.highestAlertSeverity, .critical)
        if let path = ProcessInfo.processInfo.environment["CITYSIM_FOCUS_CITY_REGULAR_PROOF"] {
            let data = try XCTUnwrap(regularFocus.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @MainActor
    func testGrowthCapacityForecastProducesRegularAndCompactPlayerFrames() throws {
        let defaults = UserDefaults.standard
        let priorWelcome = defaults.object(forKey: "hasSeenCitySimWelcome")
        defaults.set(true, forKey: "hasSeenCitySimWelcome")
        defer {
            if let priorWelcome { defaults.set(priorWelcome, forKey: "hasSeenCitySimWelcome") }
            else { defaults.removeObject(forKey: "hasSeenCitySimWelcome") }
        }

        let regularStore = CityGameStore(state: .newCity(seed: 42))
        regularStore.setSpeed(.paused)
        regularStore.openInspector(.population)
        let regular = try hudBitmap(size: CGSize(width: 1_280, height: 800), store: regularStore)

        let compactStore = CityGameStore(state: .newCity(seed: 42))
        compactStore.setSpeed(.paused)
        compactStore.openInspector(.population)
        let compact = try hudBitmap(size: CGSize(width: 900, height: 600), store: compactStore)

        XCTAssertEqual(regular.size, CGSize(width: 1_280, height: 800))
        XCTAssertEqual(compact.size, CGSize(width: 900, height: 600))
        XCTAssertGreaterThanOrEqual(regular.pixelsWide, 1_280)
        XCTAssertGreaterThanOrEqual(regular.pixelsHigh, 800)
        XCTAssertGreaterThanOrEqual(compact.pixelsWide, 900)
        XCTAssertGreaterThanOrEqual(compact.pixelsHigh, 600)
        XCTAssertTrue(regularStore.showInspector)
        XCTAssertTrue(compactStore.showInspector)
        XCTAssertEqual(regularStore.inspectorSection, .population)
        XCTAssertEqual(compactStore.inspectorSection, .population)
        let starterForecast = CityGrowthCapacityPresentation.make(analytics: regularStore.analytics)
        XCTAssertEqual(starterForecast.decisionTitle, "Water limits +100")
        XCTAssertEqual(starterForecast.response.command, .buildWaterTower)

        if let path = ProcessInfo.processInfo.environment["CITYSIM_GROWTH_CAPACITY_1280_PROOF"] {
            let data = try XCTUnwrap(regular.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        if let path = ProcessInfo.processInfo.environment["CITYSIM_GROWTH_CAPACITY_900_PROOF"] {
            let data = try XCTUnwrap(compact.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    func testAnalyticsMatchSimulationEconomyContract() {
        let state = CityGameState.newCity()
        let analytics = CityAnalytics(state: state)
        XCTAssertGreaterThan(analytics.housingCapacity, 0)
        XCTAssertGreaterThan(analytics.jobCapacity, 0)
        XCTAssertEqual(analytics.projectedBalance, analytics.projectedRevenue - analytics.projectedUpkeep, accuracy: 0.001)
    }

    @MainActor
    func testRendererProducesInspectableFrame() throws {
        let size = CGSize(width: 1_280, height: 800)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = CityScene(size: size)
        view.presentScene(scene)
        scene.render(
            state: .newCity(seed: 42),
            overlay: .none,
            selection: GridCoordinate(x: 11, y: 11),
            selectedTool: .residential,
            bulldozeMode: false
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        let texture = try XCTUnwrap(view.texture(from: scene))
        let image = texture.cgImage()
        XCTAssertGreaterThan(image.width, 1_000)
        XCTAssertGreaterThan(image.height, 600)

        if let path = ProcessInfo.processInfo.environment["CITYSIM_RENDER_PROOF"] {
            let representation = NSBitmapImageRep(cgImage: image)
            let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @MainActor
    func testGoldenNeighborhoodRendererProofExports() throws {
        let proofKeys = [
            "CITYSIM_GOLDEN_DEFAULT_PROOF", "CITYSIM_GOLDEN_REGULAR_PROOF",
            "CITYSIM_GOLDEN_COMPACT_PROOF", "CITYSIM_GOLDEN_NEIGHBORHOOD_PROOF",
            "CITYSIM_GOLDEN_CITY_PROOF", "CITYSIM_GOLDEN_OVERLAY_PROOF",
            "CITYSIM_GOLDEN_ACTIVE_BUILD_PROOF", "CITYSIM_GOLDEN_BUILD_PROOF",
            "CITYSIM_GOLDEN_SELECTION_PROOF"
        ]
        guard proofKeys.contains(where: { ProcessInfo.processInfo.environment[$0] != nil }) else { return }

        let state = CityGameState.newCity(seed: 42)
        let core = GridCoordinate(x: 11, y: 11)
        let validBuildTarget = GridCoordinate(x: 8, y: 11)

        let defaultFrame = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: nil,
            centeredOn: nil,
            hover: nil
        )
        let compactFrame = try rendererProofFrame(
            size: CGSize(width: 900, height: 600),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .neighborhood,
            centeredOn: core,
            hover: nil
        )
        let neighborhoodFrame = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .neighborhood,
            centeredOn: core,
            hover: nil
        )
        let cityFrame = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: core,
            hover: nil
        )
        let overlayFrame = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .landValue,
            selection: core,
            interactionMode: .inspect,
            detail: .neighborhood,
            centeredOn: core,
            hover: nil
        )
        let buildFrame = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .build(.residential),
            detail: .neighborhood,
            centeredOn: validBuildTarget,
            hover: validBuildTarget
        )
        let selectionFrame = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: core,
            interactionMode: .inspect,
            detail: .block,
            centeredOn: core,
            hover: core
        )

        let frames = [
            defaultFrame, compactFrame, neighborhoodFrame, cityFrame,
            overlayFrame, buildFrame, selectionFrame
        ]
        for frame in frames {
            XCTAssertGreaterThan(frame.width, 600)
            XCTAssertGreaterThan(frame.height, 400)
            XCTAssertGreaterThan(frame.png.count, 40_000)
            XCTAssertEqual(frame.diagnostics.totalTileCount, state.tiles.count)
            XCTAssertGreaterThan(frame.diagnostics.nodeCount, state.tiles.count)
        }
        XCTAssertNotEqual(neighborhoodFrame.png, cityFrame.png)
        XCTAssertNotEqual(neighborhoodFrame.png, overlayFrame.png)
        XCTAssertNotEqual(neighborhoodFrame.png, buildFrame.png)
        XCTAssertNotEqual(neighborhoodFrame.png, selectionFrame.png)

        try export(defaultFrame, environmentKeys: [
            "CITYSIM_GOLDEN_DEFAULT_PROOF", "CITYSIM_GOLDEN_REGULAR_PROOF"
        ])
        try export(compactFrame, environmentKeys: ["CITYSIM_GOLDEN_COMPACT_PROOF"])
        try export(neighborhoodFrame, environmentKeys: ["CITYSIM_GOLDEN_NEIGHBORHOOD_PROOF"])
        try export(cityFrame, environmentKeys: ["CITYSIM_GOLDEN_CITY_PROOF"])
        try export(overlayFrame, environmentKeys: ["CITYSIM_GOLDEN_OVERLAY_PROOF"])
        try export(buildFrame, environmentKeys: [
            "CITYSIM_GOLDEN_ACTIVE_BUILD_PROOF", "CITYSIM_GOLDEN_BUILD_PROOF"
        ])
        try export(selectionFrame, environmentKeys: ["CITYSIM_GOLDEN_SELECTION_PROOF"])

        print(
            "CITYSIM_PROOF_DIAGNOSTICS default=\(defaultFrame.width)x\(defaultFrame.height)/" +
            "\(defaultFrame.diagnostics.nodeCount)nodes compact=\(compactFrame.width)x\(compactFrame.height)/" +
            "\(compactFrame.diagnostics.nodeCount)nodes neighborhood=\(neighborhoodFrame.diagnostics.detailLevel) " +
            "city=\(cityFrame.diagnostics.detailLevel) overlay_nodes=\(overlayFrame.diagnostics.nodeCount) " +
            "build_nodes=\(buildFrame.diagnostics.nodeCount)"
        )
    }

    @MainActor
    func testFourViewNativeRepresentativeBlockProofExports() throws {
        let proofKeys = [
            "CITYSIM_FOUR_VIEW_NATIVE_1280_PROOF",
            "CITYSIM_FOUR_VIEW_NATIVE_900_PROOF",
        ]
        guard proofKeys.contains(where: { ProcessInfo.processInfo.environment[$0] != nil }) else {
            return
        }

        var state = CityGameState.newCity(seed: 42)
        let serviceSites: [(GridCoordinate, BuildingKind)] = [
            (GridCoordinate(x: 5, y: 10), .fireStation),
            (GridCoordinate(x: 15, y: 10), .policeStation),
            (GridCoordinate(x: 10, y: 13), .school),
        ]
        for (coordinate, kind) in serviceSites {
            state.updateTile(at: coordinate) {
                $0 = CityTile(
                    coordinate: coordinate,
                    kind: kind,
                    condition: 1,
                    constructionProgress: 1
                )
            }
        }
        let originalDevelopedCount = state.tiles.filter {
            ![.empty, .road].contains($0.kind)
        }.count
        let catalog = FourViewWorldAssetCatalog()
        for coordinate in state.tiles.filter({ tile in
            ![.empty, .road].contains(tile.kind)
                && catalog.assetID(for: tile, variant: 1) == nil
        }).map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0.kind = .empty
                $0.level = 1
                $0.occupancy = 0
            }
        }
        if let apartment = state.tiles.first(where: { $0.kind == .residential })?.coordinate {
            state.updateTile(at: apartment) { $0.level = 3 }
        }

        let developed = state.tiles.filter { ![.empty, .road].contains($0.kind) }
        let core = GridCoordinate(x: 11, y: 11)
        let compactCore = GridCoordinate(x: 10, y: 10)
        XCTAssertGreaterThanOrEqual(developed.count, 7)
        XCTAssertEqual(developed.count, originalDevelopedCount)
        XCTAssertTrue(developed.allSatisfy { catalog.assetID(for: $0, variant: 1) != nil })

        let sourceScene = CityScene(size: CGSize(width: 1_280, height: 800))
        sourceScene.reducedMotion = true
        sourceScene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let sourceNames = sourceScene.children.flatMap(descendantNodeNames)
        for tile in developed {
            let variant = tile.kind == .residential
                ? ResidentialGeneratedAssetIdentity.liveVisualVariant(at: tile.coordinate)
                : WorldVisualSeed.variant(count: 3, for: tile.coordinate, kind: tile.kind)
            let assetID = try XCTUnwrap(catalog.assetID(for: tile, variant: variant))
            XCTAssertTrue(
                sourceNames.contains("lot.four-view.\(assetID).camNE"),
                "\(tile.kind.rawValue) at \(tile.coordinate.id) must use \(assetID)"
            )
        }
        XCTAssertFalse(sourceNames.contains { $0.contains("four-view.missing") })
        for kind in [
            BuildingKind.powerPlant, .fireStation, .policeStation, .school,
        ] {
            XCTAssertFalse(sourceNames.contains("lot.generated-role.\(kind.rawValue)"))
        }

        let regular = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: core,
            framingScale: 1.22,
            hover: nil,
            exactPixelDimensions: true
        )
        let compact = try rendererProofFrame(
            size: CGSize(width: 900, height: 600),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: compactCore,
            framingScale: 1.45,
            hover: nil,
            exactPixelDimensions: true
        )

        XCTAssertEqual(regular.width, 1_280)
        XCTAssertEqual(regular.height, 800)
        XCTAssertEqual(compact.width, 900)
        XCTAssertEqual(compact.height, 600)
        XCTAssertGreaterThan(regular.png.count, 40_000)
        XCTAssertGreaterThan(compact.png.count, 30_000)
        try export(regular, environmentKeys: ["CITYSIM_FOUR_VIEW_NATIVE_1280_PROOF"])
        try export(compact, environmentKeys: ["CITYSIM_FOUR_VIEW_NATIVE_900_PROOF"])
    }

    @MainActor
    func testFourViewNativeDensityProgressionProofExports() throws {
        let proofKeys = [
            "CITYSIM_FOUR_VIEW_DENSITY_1280_PROOF",
            "CITYSIM_FOUR_VIEW_DENSITY_900_PROOF",
        ]
        guard proofKeys.contains(where: { ProcessInfo.processInfo.environment[$0] != nil }) else {
            return
        }

        var state = CityGameState.newCity(seed: 42)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        for y in [9, 12, 15] {
            for x in 4...16 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }
        for x in [4, 8, 12, 16] {
            for y in 8...15 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }

        let densityLots: [(GridCoordinate, BuildingKind, Int)] = [
            (GridCoordinate(x: 5, y: 8), .residential, 1),
            (GridCoordinate(x: 9, y: 8), .residential, 2),
            (GridCoordinate(x: 13, y: 8), .residential, 3),
            (GridCoordinate(x: 5, y: 10), .commercial, 1),
            (GridCoordinate(x: 9, y: 10), .commercial, 2),
            (GridCoordinate(x: 13, y: 10), .commercial, 3),
            (GridCoordinate(x: 5, y: 13), .industrial, 1),
            (GridCoordinate(x: 9, y: 13), .industrial, 2),
            (GridCoordinate(x: 13, y: 13), .industrial, 3),
        ]
        for (coordinate, kind, level) in densityLots {
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

        let catalog = FourViewWorldAssetCatalog()
        let expectedAssets = Set(densityLots.compactMap { entry in
            let (coordinate, kind, level) = entry
            let variant = kind == .residential
                ? ResidentialGeneratedAssetIdentity.liveVisualVariant(at: coordinate)
                : 1
            return catalog.assetID(
                for: CityTile(coordinate: coordinate, kind: kind, level: level),
                variant: variant
            )
        })
        XCTAssertEqual(expectedAssets.count, 9)

        let sourceScene = CityScene(size: CGSize(width: 1_280, height: 800))
        sourceScene.reducedMotion = true
        sourceScene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let sourceNames = sourceScene.children.flatMap(descendantNodeNames)
        for assetID in expectedAssets {
            XCTAssertTrue(sourceNames.contains("lot.four-view.\(assetID).camNE"), assetID)
        }

        let center = GridCoordinate(x: 9, y: 11)
        let regular = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 0.92,
            hover: nil,
            exactPixelDimensions: true
        )
        let compact = try rendererProofFrame(
            size: CGSize(width: 900, height: 600),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 1.04,
            hover: nil,
            exactPixelDimensions: true
        )

        XCTAssertEqual(regular.width, 1_280)
        XCTAssertEqual(regular.height, 800)
        XCTAssertEqual(compact.width, 900)
        XCTAssertEqual(compact.height, 600)
        XCTAssertGreaterThan(regular.png.count, 40_000)
        XCTAssertGreaterThan(compact.png.count, 30_000)
        try export(regular, environmentKeys: ["CITYSIM_FOUR_VIEW_DENSITY_1280_PROOF"])
        try export(compact, environmentKeys: ["CITYSIM_FOUR_VIEW_DENSITY_900_PROOF"])
    }

    @MainActor
    func testFourViewNativeStreetscapeProofExports() throws {
        let proofKeys = [
            "CITYSIM_FOUR_VIEW_STREETSCAPE_1280_PROOF",
            "CITYSIM_FOUR_VIEW_STREETSCAPE_900_PROOF",
        ]
        guard proofKeys.contains(where: { ProcessInfo.processInfo.environment[$0] != nil }) else {
            return
        }

        var state = CityGameState.newCity(seed: 42)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        for y in [9, 12, 15] {
            for x in 4...16 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }
        for x in [4, 8, 12, 16] {
            for y in 8...16 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }
        let lots: [(GridCoordinate, BuildingKind, Int)] = [
            (GridCoordinate(x: 5, y: 8), .residential, 1),
            (GridCoordinate(x: 9, y: 8), .residential, 2),
            (GridCoordinate(x: 13, y: 8), .residential, 3),
            (GridCoordinate(x: 5, y: 10), .commercial, 1),
            (GridCoordinate(x: 9, y: 10), .commercial, 2),
            (GridCoordinate(x: 13, y: 10), .commercial, 3),
            (GridCoordinate(x: 5, y: 13), .industrial, 1),
            (GridCoordinate(x: 9, y: 13), .industrial, 2),
            (GridCoordinate(x: 13, y: 13), .industrial, 3),
            (GridCoordinate(x: 5, y: 16), .fireStation, 1),
            (GridCoordinate(x: 9, y: 16), .park, 1),
            (GridCoordinate(x: 13, y: 16), .waterTower, 1),
        ]
        for (coordinate, kind, level) in lots {
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

        let sourceScene = CityScene(size: CGSize(width: 1_280, height: 800))
        sourceScene.reducedMotion = true
        sourceScene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let sourceNames = sourceScene.children.flatMap(descendantNodeNames)
        let roadCount = state.tiles.filter { $0.kind == .road }.count
        XCTAssertEqual(
            sourceNames.filter { $0.hasPrefix("road.four-view.mask-") }.count,
            roadCount
        )
        XCTAssertTrue(sourceNames.contains { $0.hasPrefix("lot.four-view.") })
        XCTAssertFalse(sourceNames.contains { $0.hasPrefix("road.socket-seam-blend.") })

        let center = GridCoordinate(x: 10, y: 12)
        let regular = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 0.90,
            hover: nil,
            exactPixelDimensions: true
        )
        let compact = try rendererProofFrame(
            size: CGSize(width: 900, height: 600),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 1.02,
            hover: nil,
            exactPixelDimensions: true
        )

        XCTAssertEqual(regular.width, 1_280)
        XCTAssertEqual(regular.height, 800)
        XCTAssertEqual(compact.width, 900)
        XCTAssertEqual(compact.height, 600)
        XCTAssertGreaterThan(regular.png.count, 40_000)
        XCTAssertGreaterThan(compact.png.count, 30_000)
        try export(regular, environmentKeys: ["CITYSIM_FOUR_VIEW_STREETSCAPE_1280_PROOF"])
        try export(compact, environmentKeys: ["CITYSIM_FOUR_VIEW_STREETSCAPE_900_PROOF"])
    }

    @MainActor
    func testFourViewNativeGroundEcologyProofExports() throws {
        let proofKeys = [
            "CITYSIM_FOUR_VIEW_GROUND_ECOLOGY_1280_PROOF",
            "CITYSIM_FOUR_VIEW_GROUND_ECOLOGY_900_PROOF",
        ]
        guard proofKeys.contains(where: { ProcessInfo.processInfo.environment[$0] != nil }) else {
            return
        }

        var state = CityGameState.newCity(seed: 42)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        for y in [8, 12, 16] {
            for x in 4...18 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }
        for x in [4, 8, 12, 16, 18] {
            for y in 7...17 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }
        let lots: [(GridCoordinate, BuildingKind, Int)] = [
            (GridCoordinate(x: 5, y: 7), .residential, 1),
            (GridCoordinate(x: 9, y: 7), .residential, 2),
            (GridCoordinate(x: 13, y: 7), .residential, 3),
            (GridCoordinate(x: 5, y: 10), .commercial, 1),
            (GridCoordinate(x: 9, y: 10), .commercial, 2),
            (GridCoordinate(x: 13, y: 10), .commercial, 3),
            (GridCoordinate(x: 5, y: 14), .industrial, 1),
            (GridCoordinate(x: 9, y: 14), .industrial, 2),
            (GridCoordinate(x: 13, y: 14), .industrial, 3),
            (GridCoordinate(x: 5, y: 17), .fireStation, 1),
            (GridCoordinate(x: 9, y: 17), .park, 1),
            (GridCoordinate(x: 13, y: 17), .waterTower, 1),
        ]
        for (coordinate, kind, level) in lots {
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

        let sourceScene = CityScene(size: CGSize(width: 1_280, height: 800))
        sourceScene.reducedMotion = true
        sourceScene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let sourceNames = sourceScene.children.flatMap(descendantNodeNames)
        for assetID in FourViewGroundEcologyCatalog.requiredAssetIDs {
            XCTAssertTrue(
                sourceNames.contains("ground-ecology.four-view.\(assetID).camNE"),
                assetID
            )
        }
        XCTAssertFalse(sourceNames.contains { $0.hasPrefix("terrain.lot-surface.") })

        let center = GridCoordinate(x: 11, y: 12)
        let regular = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 0.90,
            hover: nil,
            exactPixelDimensions: true
        )
        let compact = try rendererProofFrame(
            size: CGSize(width: 900, height: 600),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 1.02,
            hover: nil,
            exactPixelDimensions: true
        )

        XCTAssertEqual(regular.width, 1_280)
        XCTAssertEqual(regular.height, 800)
        XCTAssertEqual(compact.width, 900)
        XCTAssertEqual(compact.height, 600)
        XCTAssertGreaterThan(regular.png.count, 40_000)
        XCTAssertGreaterThan(compact.png.count, 30_000)
        try export(regular, environmentKeys: ["CITYSIM_FOUR_VIEW_GROUND_ECOLOGY_1280_PROOF"])
        try export(compact, environmentKeys: ["CITYSIM_FOUR_VIEW_GROUND_ECOLOGY_900_PROOF"])
    }

    @MainActor
    func testFourViewNativeMainStreetCommerceProofExports() throws {
        let proofKeys = [
            "CITYSIM_FOUR_VIEW_MAIN_STREET_BASELINE_1280_PROOF",
            "CITYSIM_FOUR_VIEW_MAIN_STREET_BASELINE_900_PROOF",
            "CITYSIM_FOUR_VIEW_MAIN_STREET_1280_PROOF",
            "CITYSIM_FOUR_VIEW_MAIN_STREET_900_PROOF",
        ]
        guard proofKeys.contains(where: { ProcessInfo.processInfo.environment[$0] != nil }) else {
            return
        }
        let candidateRequested = [
            "CITYSIM_FOUR_VIEW_MAIN_STREET_1280_PROOF",
            "CITYSIM_FOUR_VIEW_MAIN_STREET_900_PROOF",
        ].contains(where: { ProcessInfo.processInfo.environment[$0] != nil })

        var state = CityGameState.newCity(seed: 42)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        for y in [8, 12, 16] {
            for x in 4...18 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }
        for x in [4, 8, 12, 16, 18] {
            for y in 7...17 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }

        let commercialCandidates = state.tiles
            .filter { tile in
                guard tile.kind == .empty,
                      (7...17).contains(tile.coordinate.y),
                      (4...18).contains(tile.coordinate.x) else { return false }
                return !RoadConnectionMask.resolving(
                    at: tile.coordinate,
                    in: state
                ).isEmpty
            }
            .sorted { ($0.coordinate.y, $0.coordinate.x) < ($1.coordinate.y, $1.coordinate.x) }
        var commercialCoordinates: [GridCoordinate] = []
        for variant in 0..<3 {
            commercialCoordinates.append(contentsOf: commercialCandidates
                .filter {
                    WorldVisualSeed.variant(
                        count: 3,
                        for: $0.coordinate,
                        kind: .commercial
                    ) == variant
                }
                .prefix(4)
                .map(\.coordinate))
        }
        XCTAssertEqual(commercialCoordinates.count, 12)
        for coordinate in commercialCoordinates {
            state.updateTile(at: coordinate) {
                $0 = CityTile(
                    coordinate: coordinate,
                    kind: .commercial,
                    level: 1,
                    condition: 1,
                    constructionProgress: 1
                )
            }
        }
        let supportingLots: [(GridCoordinate, BuildingKind, Int)] = [
            (GridCoordinate(x: 5, y: 10), .residential, 2),
            (GridCoordinate(x: 13, y: 10), .residential, 3),
            (GridCoordinate(x: 9, y: 14), .park, 1),
            (GridCoordinate(x: 17, y: 14), .fireStation, 1),
        ]
        for (coordinate, kind, level) in supportingLots {
            guard state.tile(at: coordinate)?.kind == .empty else { continue }
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

        let sourceScene = CityScene(size: CGSize(width: 1_280, height: 800))
        sourceScene.reducedMotion = true
        sourceScene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let sourceNames = sourceScene.children.flatMap(descendantNodeNames)
        XCTAssertTrue(sourceNames.contains("lot.four-view.harbor_corner_storefront.camNE"))
        if candidateRequested {
            for assetID in ["lantern_row_bakery", "ironwood_hardware_shop"] {
                XCTAssertTrue(
                    sourceNames.contains("lot.four-view.\(assetID).camNE"),
                    assetID
                )
            }
        }

        let center = GridCoordinate(x: 11, y: 12)
        let regular = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 0.90,
            hover: nil,
            exactPixelDimensions: true
        )
        let compact = try rendererProofFrame(
            size: CGSize(width: 900, height: 600),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 1.02,
            hover: nil,
            exactPixelDimensions: true
        )

        XCTAssertEqual(regular.width, 1_280)
        XCTAssertEqual(regular.height, 800)
        XCTAssertEqual(compact.width, 900)
        XCTAssertEqual(compact.height, 600)
        XCTAssertGreaterThan(regular.png.count, 40_000)
        XCTAssertGreaterThan(compact.png.count, 30_000)
        try export(regular, environmentKeys: [
            "CITYSIM_FOUR_VIEW_MAIN_STREET_BASELINE_1280_PROOF",
            "CITYSIM_FOUR_VIEW_MAIN_STREET_1280_PROOF",
        ])
        try export(compact, environmentKeys: [
            "CITYSIM_FOUR_VIEW_MAIN_STREET_BASELINE_900_PROOF",
            "CITYSIM_FOUR_VIEW_MAIN_STREET_900_PROOF",
        ])
    }

    @MainActor
    func testFourViewNativeIndustrialEdgeProofExports() throws {
        let proofKeys = [
            "CITYSIM_FOUR_VIEW_INDUSTRIAL_EDGE_BASELINE_1280_PROOF",
            "CITYSIM_FOUR_VIEW_INDUSTRIAL_EDGE_BASELINE_900_PROOF",
            "CITYSIM_FOUR_VIEW_INDUSTRIAL_EDGE_1280_PROOF",
            "CITYSIM_FOUR_VIEW_INDUSTRIAL_EDGE_900_PROOF",
        ]
        guard proofKeys.contains(where: { ProcessInfo.processInfo.environment[$0] != nil }) else {
            return
        }
        let candidateRequested = [
            "CITYSIM_FOUR_VIEW_INDUSTRIAL_EDGE_1280_PROOF",
            "CITYSIM_FOUR_VIEW_INDUSTRIAL_EDGE_900_PROOF",
        ].contains(where: { ProcessInfo.processInfo.environment[$0] != nil })

        var state = CityGameState.newCity(seed: 42)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        for y in [8, 12, 16] {
            for x in 4...20 {
                state.updateTile(at: GridCoordinate(x: x, y: y)) {
                    $0 = CityTile(coordinate: GridCoordinate(x: x, y: y), kind: .road)
                }
            }
        }
        for x in [4, 8, 12, 16, 20] {
            for y in 7...17 {
                state.updateTile(at: GridCoordinate(x: x, y: y)) {
                    $0 = CityTile(coordinate: GridCoordinate(x: x, y: y), kind: .road)
                }
            }
        }

        let industrialCandidates = state.tiles
            .filter { tile in
                guard tile.kind == .empty,
                      (9...15).contains(tile.coordinate.y),
                      (5...19).contains(tile.coordinate.x) else { return false }
                return !RoadConnectionMask.resolving(
                    at: tile.coordinate,
                    in: state
                ).isEmpty
            }
            .sorted { ($0.coordinate.y, $0.coordinate.x) < ($1.coordinate.y, $1.coordinate.x) }
        var industrialCoordinates: [GridCoordinate] = []
        for variant in 0..<2 {
            industrialCoordinates.append(contentsOf: industrialCandidates
                .filter {
                    WorldVisualSeed.variant(
                        count: 3,
                        for: $0.coordinate,
                        kind: .industrial
                    ) == variant
                }
                .prefix(6)
                .map(\.coordinate))
        }
        XCTAssertEqual(industrialCoordinates.count, 12)
        for coordinate in industrialCoordinates {
            state.updateTile(at: coordinate) {
                $0 = CityTile(
                    coordinate: coordinate,
                    kind: .industrial,
                    level: 1,
                    condition: 1,
                    constructionProgress: 1
                )
            }
        }

        let supportingLots: [(GridCoordinate, BuildingKind, Int)] = [
            (GridCoordinate(x: 5, y: 14), .industrial, 2),
            (GridCoordinate(x: 9, y: 14), .industrial, 3),
            (GridCoordinate(x: 13, y: 14), .commercial, 1),
            (GridCoordinate(x: 17, y: 14), .residential, 2),
            (GridCoordinate(x: 10, y: 10), .park, 1),
        ]
        for (coordinate, kind, level) in supportingLots {
            guard state.tile(at: coordinate)?.kind == .empty else { continue }
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

        let sourceScene = CityScene(size: CGSize(width: 1_280, height: 800))
        sourceScene.reducedMotion = true
        sourceScene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let sourceNames = sourceScene.children.flatMap(descendantNodeNames)
        XCTAssertTrue(sourceNames.contains("lot.four-view.ironleaf_service_workshop.camNE"))
        if candidateRequested {
            XCTAssertTrue(sourceNames.contains("lot.four-view.copperline_machine_shop.camNE"))
        }

        let center = GridCoordinate(x: 12, y: 12)
        let regular = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 0.90,
            hover: nil,
            exactPixelDimensions: true
        )
        let compact = try rendererProofFrame(
            size: CGSize(width: 900, height: 600),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 1.02,
            hover: nil,
            exactPixelDimensions: true
        )

        XCTAssertEqual(regular.width, 1_280)
        XCTAssertEqual(regular.height, 800)
        XCTAssertEqual(compact.width, 900)
        XCTAssertEqual(compact.height, 600)
        XCTAssertGreaterThan(regular.png.count, 40_000)
        XCTAssertGreaterThan(compact.png.count, 30_000)
        try export(regular, environmentKeys: [
            "CITYSIM_FOUR_VIEW_INDUSTRIAL_EDGE_BASELINE_1280_PROOF",
            "CITYSIM_FOUR_VIEW_INDUSTRIAL_EDGE_1280_PROOF",
        ])
        try export(compact, environmentKeys: [
            "CITYSIM_FOUR_VIEW_INDUSTRIAL_EDGE_BASELINE_900_PROOF",
            "CITYSIM_FOUR_VIEW_INDUSTRIAL_EDGE_900_PROOF",
        ])
    }

    @MainActor
    func testFourViewNativeParkCorridorProofExports() throws {
        let proofKeys = [
            "CITYSIM_FOUR_VIEW_PARK_CORRIDOR_BASELINE_1280_PROOF",
            "CITYSIM_FOUR_VIEW_PARK_CORRIDOR_BASELINE_900_PROOF",
            "CITYSIM_FOUR_VIEW_PARK_CORRIDOR_1280_PROOF",
            "CITYSIM_FOUR_VIEW_PARK_CORRIDOR_900_PROOF",
        ]
        guard proofKeys.contains(where: { ProcessInfo.processInfo.environment[$0] != nil }) else {
            return
        }
        let candidateRequested = [
            "CITYSIM_FOUR_VIEW_PARK_CORRIDOR_1280_PROOF",
            "CITYSIM_FOUR_VIEW_PARK_CORRIDOR_900_PROOF",
        ].contains(where: { ProcessInfo.processInfo.environment[$0] != nil })

        var state = CityGameState.newCity(seed: 42)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        for y in [8, 12, 16] {
            for x in 4...20 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }
        for x in [4, 8, 12, 16, 20] {
            for y in 7...17 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }

        let parkCandidates = state.tiles
            .filter { tile in
                guard tile.kind == .empty,
                      (9...15).contains(tile.coordinate.y),
                      (5...19).contains(tile.coordinate.x) else { return false }
                return !RoadConnectionMask.resolving(
                    at: tile.coordinate,
                    in: state
                ).isEmpty
            }
            .sorted { ($0.coordinate.y, $0.coordinate.x) < ($1.coordinate.y, $1.coordinate.x) }
        var parkCoordinates: [GridCoordinate] = []
        for variant in 0..<2 {
            parkCoordinates.append(contentsOf: parkCandidates
                .filter {
                    WorldVisualSeed.variant(
                        count: 3,
                        for: $0.coordinate,
                        kind: .park
                    ) == variant
                }
                .prefix(5)
                .map(\.coordinate))
        }
        XCTAssertEqual(parkCoordinates.count, 10)
        for coordinate in parkCoordinates {
            state.updateTile(at: coordinate) {
                $0 = CityTile(
                    coordinate: coordinate,
                    kind: .park,
                    level: 1,
                    condition: 1,
                    constructionProgress: 1
                )
            }
        }

        let supportingLots: [(GridCoordinate, BuildingKind, Int)] = [
            (GridCoordinate(x: 5, y: 14), .cityHall, 1),
            (GridCoordinate(x: 9, y: 14), .school, 1),
            (GridCoordinate(x: 13, y: 14), .commercial, 1),
            (GridCoordinate(x: 17, y: 14), .residential, 2),
            (GridCoordinate(x: 18, y: 10), .residential, 1),
        ]
        for (coordinate, kind, level) in supportingLots {
            guard state.tile(at: coordinate)?.kind == .empty else { continue }
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

        let sourceScene = CityScene(size: CGSize(width: 1_280, height: 800))
        sourceScene.reducedMotion = true
        sourceScene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let sourceNames = sourceScene.children.flatMap(descendantNodeNames)
        XCTAssertTrue(sourceNames.contains("lot.four-view.pocket_grove_park.camNE"))
        if candidateRequested {
            XCTAssertTrue(sourceNames.contains("lot.four-view.canal_lantern_park.camNE"))
        }

        let center = GridCoordinate(x: 12, y: 12)
        let regular = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 0.90,
            hover: nil,
            exactPixelDimensions: true
        )
        let compact = try rendererProofFrame(
            size: CGSize(width: 900, height: 600),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 1.02,
            hover: nil,
            exactPixelDimensions: true
        )

        XCTAssertEqual(regular.width, 1_280)
        XCTAssertEqual(regular.height, 800)
        XCTAssertEqual(compact.width, 900)
        XCTAssertEqual(compact.height, 600)
        XCTAssertGreaterThan(regular.png.count, 40_000)
        XCTAssertGreaterThan(compact.png.count, 30_000)
        try export(regular, environmentKeys: [
            "CITYSIM_FOUR_VIEW_PARK_CORRIDOR_BASELINE_1280_PROOF",
            "CITYSIM_FOUR_VIEW_PARK_CORRIDOR_1280_PROOF",
        ])
        try export(compact, environmentKeys: [
            "CITYSIM_FOUR_VIEW_PARK_CORRIDOR_BASELINE_900_PROOF",
            "CITYSIM_FOUR_VIEW_PARK_CORRIDOR_900_PROOF",
        ])
    }

    @MainActor
    func testFourViewNativeUnifiedNeighborhoodProofExportsEveryAdmittedAsset() throws {
        let regularKey = "CITYSIM_FOUR_VIEW_UNIFIED_NEIGHBORHOOD_1280_PROOF"
        let compactKey = "CITYSIM_FOUR_VIEW_UNIFIED_NEIGHBORHOOD_900_PROOF"
        guard ProcessInfo.processInfo.environment[regularKey] != nil
                || ProcessInfo.processInfo.environment[compactKey] != nil else {
            return
        }

        var state = CityGameState.newCity(seed: 42)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        // Four generous urban blocks keep the road network legible and give
        // the admitted building silhouettes room to read at game scale.
        for y in [6, 11, 16, 21] {
            for x in 3...23 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }
        for x in [4, 10, 16, 22] {
            for y in 5...22 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }

        var used: Set<GridCoordinate> = []
        func place(
            _ kind: BuildingKind,
            level: Int = 1,
            near target: GridCoordinate,
            where matches: (GridCoordinate) -> Bool = { _ in true }
        ) throws -> GridCoordinate {
            let candidates = state.tiles
                .filter { tile in
                    guard tile.kind == .empty,
                          (5...21).contains(tile.coordinate.x),
                          (7...20).contains(tile.coordinate.y),
                          !used.contains(tile.coordinate),
                          matches(tile.coordinate) else { return false }
                    return !RoadConnectionMask.resolving(
                        at: tile.coordinate,
                        in: state
                    ).isEmpty
                }
                .sorted { lhs, rhs in
                    let lhsDistance = abs(lhs.coordinate.x - target.x)
                        + abs(lhs.coordinate.y - target.y)
                    let rhsDistance = abs(rhs.coordinate.x - target.x)
                        + abs(rhs.coordinate.y - target.y)
                    return (lhsDistance, lhs.coordinate.y, lhs.coordinate.x)
                        < (rhsDistance, rhs.coordinate.y, rhs.coordinate.x)
                }
            let coordinate = try XCTUnwrap(candidates.first?.coordinate, kind.rawValue)
            used.insert(coordinate)
            state.updateTile(at: coordinate) {
                $0 = CityTile(
                    coordinate: coordinate,
                    kind: kind,
                    level: level,
                    condition: 1,
                    constructionProgress: 1
                )
            }
            return coordinate
        }

        _ = try place(.residential, near: GridCoordinate(x: 5, y: 8)) {
            ResidentialGeneratedAssetIdentity.liveVisualVariant(at: $0) == 1
        }
        _ = try place(.residential, near: GridCoordinate(x: 8, y: 8)) {
            ResidentialGeneratedAssetIdentity.liveVisualVariant(at: $0) == 2
        }
        for (variant, targetX) in zip([2, 1], [11, 14]) {
            _ = try place(.residential, level: 2, near: GridCoordinate(x: targetX, y: 8)) {
                ResidentialGeneratedAssetIdentity.liveVisualVariant(at: $0) == variant
            }
        }
        for (variant, targetX) in zip([2, 1], [17, 20]) {
            _ = try place(.residential, level: 3, near: GridCoordinate(x: targetX, y: 8)) {
                ResidentialGeneratedAssetIdentity.liveVisualVariant(at: $0) == variant
            }
        }
        for (variant, targetY) in zip(0..<2, [9, 10]) {
            _ = try place(.policeStation, near: GridCoordinate(x: 20, y: targetY)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .policeStation) == variant
            }
        }

        for (variant, targetX) in zip(0..<3, [5, 8, 11]) {
            _ = try place(.commercial, near: GridCoordinate(x: targetX, y: 11)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .commercial) == variant
            }
        }
        for (variant, targetX) in zip(0..<2, [14, 17]) {
            _ = try place(.commercial, level: 2, near: GridCoordinate(x: targetX, y: 11)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .commercial) == variant
            }
        }
        for (variant, targetX) in zip(0..<2, [20, 20]) {
            _ = try place(.commercial, level: 3, near: GridCoordinate(x: targetX, y: 12 + variant)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .commercial) == variant
            }
        }

        for (variant, targetX) in zip(0..<2, [5, 8]) {
            _ = try place(.industrial, near: GridCoordinate(x: targetX, y: 14)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .industrial) == variant
            }
        }
        for (variant, targetX) in zip(0..<2, [11, 14]) {
            _ = try place(.industrial, level: 2, near: GridCoordinate(x: targetX, y: 14)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .industrial) == variant
            }
        }
        for (variant, targetX) in zip(0..<2, [17, 20]) {
            _ = try place(.industrial, level: 3, near: GridCoordinate(x: targetX, y: 14)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .industrial) == variant
            }
        }

        for (variant, targetX) in zip(0..<2, [17, 20]) {
            _ = try place(.cityHall, near: GridCoordinate(x: targetX, y: 14)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .cityHall) == variant
            }
        }
        for (variant, targetX) in zip(0..<2, [5, 8]) {
            _ = try place(.park, near: GridCoordinate(x: targetX, y: 17)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .park) == variant
            }
        }
        for (variant, targetX) in zip(0..<2, [11, 12]) {
            _ = try place(.powerPlant, near: GridCoordinate(x: targetX, y: 17)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .powerPlant) == variant
            }
        }
        for (variant, targetX) in zip(0..<2, [14, 15]) {
            _ = try place(.waterTower, near: GridCoordinate(x: targetX, y: 17)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .waterTower) == variant
            }
        }
        for (variant, targetX) in zip(0..<2, [17, 18]) {
            _ = try place(.school, near: GridCoordinate(x: targetX, y: 17)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .school) == variant
            }
        }
        for (variant, targetX) in zip(0..<2, [11, 12]) {
            _ = try place(.fireStation, near: GridCoordinate(x: targetX, y: 20)) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: .fireStation) == variant
            }
        }

        let infill: [(BuildingKind, Int, GridCoordinate)] = [
            (.residential, 1, GridCoordinate(x: 20, y: 8)),
            (.residential, 1, GridCoordinate(x: 20, y: 11)),
            (.commercial, 1, GridCoordinate(x: 20, y: 14)),
            (.commercial, 1, GridCoordinate(x: 20, y: 17)),
            (.industrial, 1, GridCoordinate(x: 20, y: 20)),
            (.residential, 1, GridCoordinate(x: 6, y: 20)),
            (.residential, 2, GridCoordinate(x: 9, y: 20)),
            (.commercial, 1, GridCoordinate(x: 12, y: 20)),
            (.commercial, 2, GridCoordinate(x: 15, y: 20)),
            (.park, 1, GridCoordinate(x: 18, y: 20)),
            (.residential, 1, GridCoordinate(x: 20, y: 10)),
            (.commercial, 1, GridCoordinate(x: 20, y: 16)),
        ]
        for (kind, level, target) in infill {
            _ = try place(kind, level: level, near: target)
        }

        let sourceScene = CityScene(size: CGSize(width: 1_280, height: 800))
        sourceScene.reducedMotion = true
        sourceScene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let sourceNames = Set(sourceScene.children.flatMap(descendantNodeNames))
        let admittedAssetIDs = try XCTUnwrap(
            FourViewWorldAssetCatalog().manifest
        ).assets.map(\.assetID)
        XCTAssertEqual(admittedAssetIDs.count, 33)
        for assetID in admittedAssetIDs {
            XCTAssertTrue(
                sourceNames.contains("lot.four-view.\(assetID).camNE"),
                assetID
            )
        }

        let center = GridCoordinate(x: 13, y: 14)
        let regular = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 0.92,
            hover: nil,
            exactPixelDimensions: true
        )
        let compact = try rendererProofFrame(
            size: CGSize(width: 900, height: 600),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 0.60,
            hover: nil,
            exactPixelDimensions: true
        )

        XCTAssertEqual(regular.width, 1_280)
        XCTAssertEqual(regular.height, 800)
        XCTAssertEqual(compact.width, 900)
        XCTAssertEqual(compact.height, 600)
        XCTAssertGreaterThan(regular.png.count, 50_000)
        XCTAssertGreaterThan(compact.png.count, 35_000)
        try export(regular, environmentKeys: [regularKey])
        try export(compact, environmentKeys: [compactKey])
    }

    @MainActor
    func testFourViewNativeBuildingVarietyProofExports() throws {
        let regularKey = "CITYSIM_FOUR_VIEW_BUILDING_VARIETY_1280_PROOF"
        let compactKey = "CITYSIM_FOUR_VIEW_BUILDING_VARIETY_900_PROOF"
        guard ProcessInfo.processInfo.environment[regularKey] != nil
                || ProcessInfo.processInfo.environment[compactKey] != nil else {
            return
        }

        var state = CityGameState.newCity(seed: 73)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        for y in [6, 11, 16, 21] {
            for x in 3...24 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }
        for x in [4, 10, 16, 22] {
            for y in 5...22 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }

        var used: Set<GridCoordinate> = []
        func place(
            _ kind: BuildingKind,
            level: Int,
            near target: GridCoordinate,
            where matches: (GridCoordinate) -> Bool
        ) throws {
            let candidates = state.tiles
                .filter { tile in
                    tile.kind == .empty
                        && (5...21).contains(tile.coordinate.x)
                        && (7...20).contains(tile.coordinate.y)
                        && !used.contains(tile.coordinate)
                        && matches(tile.coordinate)
                        && !RoadConnectionMask.resolving(
                            at: tile.coordinate,
                            in: state
                        ).isEmpty
                }
                .sorted { lhs, rhs in
                    let left = abs(lhs.coordinate.x - target.x)
                        + abs(lhs.coordinate.y - target.y)
                    let right = abs(rhs.coordinate.x - target.x)
                        + abs(rhs.coordinate.y - target.y)
                    return (left, lhs.coordinate.y, lhs.coordinate.x)
                        < (right, rhs.coordinate.y, rhs.coordinate.x)
                }
            let coordinate = try XCTUnwrap(candidates.first?.coordinate, kind.rawValue)
            used.insert(coordinate)
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

        // Residential uses its established one-based live visual variant.
        for (level, visualVariant, target) in [
            (2, 2, GridCoordinate(x: 5, y: 8)),
            (2, 1, GridCoordinate(x: 8, y: 8)),
            (3, 2, GridCoordinate(x: 11, y: 8)),
            (3, 1, GridCoordinate(x: 14, y: 8)),
        ] {
            try place(.residential, level: level, near: target) {
                ResidentialGeneratedAssetIdentity.liveVisualVariant(at: $0) == visualVariant
            }
        }
        // Commercial and industrial use the same deterministic three-way seed
        // as live LotRenderer selection; variants 0 and 1 show old/new siblings.
        for (kind, level, visualVariant, target) in [
            (BuildingKind.commercial, 2, 0, GridCoordinate(x: 5, y: 13)),
            (.commercial, 2, 1, GridCoordinate(x: 8, y: 13)),
            (.commercial, 3, 0, GridCoordinate(x: 11, y: 13)),
            (.commercial, 3, 1, GridCoordinate(x: 14, y: 13)),
            (.industrial, 2, 0, GridCoordinate(x: 5, y: 18)),
            (.industrial, 2, 1, GridCoordinate(x: 8, y: 18)),
            (.industrial, 3, 0, GridCoordinate(x: 11, y: 18)),
            (.industrial, 3, 1, GridCoordinate(x: 14, y: 18)),
        ] {
            try place(kind, level: level, near: target) {
                WorldVisualSeed.variant(count: 3, for: $0, kind: kind) == visualVariant
            }
        }

        // Supporting low-rise fabric keeps this an actual neighborhood rather
        // than an isolated sprite sheet.
        let infill: [(BuildingKind, Int, GridCoordinate)] = [
            (.residential, 1, GridCoordinate(x: 18, y: 8)),
            (.commercial, 1, GridCoordinate(x: 18, y: 13)),
            (.industrial, 1, GridCoordinate(x: 18, y: 18)),
            (.park, 1, GridCoordinate(x: 20, y: 8)),
            (.school, 1, GridCoordinate(x: 20, y: 13)),
            (.fireStation, 1, GridCoordinate(x: 20, y: 18)),
        ]
        for (kind, level, target) in infill {
            try place(kind, level: level, near: target) { _ in true }
        }

        let sourceScene = CityScene(size: CGSize(width: 1_280, height: 800))
        sourceScene.reducedMotion = true
        sourceScene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let sourceNames = Set(sourceScene.children.flatMap(descendantNodeNames))
        let expectedPairs = [
            "brickline_rowhouse_apartments", "maple_courtyard_apartments",
            "foundry_crown_apartments", "juniper_terrace_tower",
            "market_arcade_midrise", "sunbrick_market_lofts",
            "aurora_exchange_tower", "copperglass_exchange_annex",
            "canalworks_factory", "riverbend_textile_works",
            "foundry_peak_plant", "ember_rail_foundry",
        ]
        for assetID in expectedPairs {
            XCTAssertTrue(
                sourceNames.contains("lot.four-view.\(assetID).camNE"),
                assetID
            )
        }

        let center = GridCoordinate(x: 12, y: 14)
        let regular = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 1.06,
            hover: nil,
            exactPixelDimensions: true
        )
        let compact = try rendererProofFrame(
            size: CGSize(width: 900, height: 600),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 1.30,
            hover: nil,
            exactPixelDimensions: true
        )
        XCTAssertEqual(regular.width, 1_280)
        XCTAssertEqual(regular.height, 800)
        XCTAssertEqual(compact.width, 900)
        XCTAssertEqual(compact.height, 600)
        XCTAssertGreaterThan(regular.png.count, 50_000)
        XCTAssertGreaterThan(compact.png.count, 35_000)
        try export(regular, environmentKeys: [regularKey])
        try export(compact, environmentKeys: [compactKey])
    }

    @MainActor
    func testFourViewCivicServiceUtilityVarietyProofExports() throws {
        let regularKey = "CITYSIM_FOUR_VIEW_CIVIC_SERVICE_VARIETY_1280_PROOF"
        let compactKey = "CITYSIM_FOUR_VIEW_CIVIC_SERVICE_VARIETY_900_PROOF"
        guard ProcessInfo.processInfo.environment[regularKey] != nil
                || ProcessInfo.processInfo.environment[compactKey] != nil else {
            return
        }

        var state = CityGameState.newCity(seed: 91)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        for y in [6, 11, 16, 21] {
            for x in 3...23 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }
        for x in [4, 10, 16, 22] {
            for y in 5...22 {
                let coordinate = GridCoordinate(x: x, y: y)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(coordinate: coordinate, kind: .road)
                }
            }
        }

        var used: Set<GridCoordinate> = []
        func place(
            _ kind: BuildingKind,
            level: Int = 1,
            near target: GridCoordinate,
            variant: Int? = nil
        ) throws {
            let candidates = state.tiles
                .filter { tile in
                    guard tile.kind == .empty,
                          (5...21).contains(tile.coordinate.x),
                          (7...20).contains(tile.coordinate.y),
                          !used.contains(tile.coordinate),
                          !RoadConnectionMask.resolving(
                            at: tile.coordinate,
                            in: state
                          ).isEmpty else { return false }
                    return variant == nil || WorldVisualSeed.variant(
                        count: 3,
                        for: tile.coordinate,
                        kind: kind
                    ) == variant
                }
                .sorted { lhs, rhs in
                    let left = abs(lhs.coordinate.x - target.x)
                        + abs(lhs.coordinate.y - target.y)
                    let right = abs(rhs.coordinate.x - target.x)
                        + abs(rhs.coordinate.y - target.y)
                    return (left, lhs.coordinate.y, lhs.coordinate.x)
                        < (right, rhs.coordinate.y, rhs.coordinate.x)
                }
            let coordinate = try XCTUnwrap(candidates.first?.coordinate, kind.rawValue)
            used.insert(coordinate)
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

        let pairedRoles: [(BuildingKind, GridCoordinate, GridCoordinate)] = [
            (.cityHall, GridCoordinate(x: 5, y: 8), GridCoordinate(x: 8, y: 8)),
            (.policeStation, GridCoordinate(x: 11, y: 8), GridCoordinate(x: 14, y: 8)),
            (.fireStation, GridCoordinate(x: 17, y: 8), GridCoordinate(x: 20, y: 8)),
            (.school, GridCoordinate(x: 5, y: 13), GridCoordinate(x: 8, y: 13)),
            (.powerPlant, GridCoordinate(x: 11, y: 13), GridCoordinate(x: 14, y: 13)),
            (.waterTower, GridCoordinate(x: 17, y: 13), GridCoordinate(x: 20, y: 13)),
        ]
        for (kind, originalTarget, newTarget) in pairedRoles {
            try place(kind, near: originalTarget, variant: 0)
            try place(kind, near: newTarget, variant: 1)
        }

        let neighborhoodFabric: [(BuildingKind, Int, GridCoordinate)] = [
            (.residential, 2, GridCoordinate(x: 5, y: 18)),
            (.residential, 3, GridCoordinate(x: 8, y: 18)),
            (.commercial, 2, GridCoordinate(x: 11, y: 18)),
            (.commercial, 3, GridCoordinate(x: 14, y: 18)),
            (.industrial, 2, GridCoordinate(x: 17, y: 18)),
            (.industrial, 3, GridCoordinate(x: 20, y: 18)),
            (.park, 1, GridCoordinate(x: 7, y: 20)),
            (.park, 1, GridCoordinate(x: 19, y: 20)),
        ]
        for (kind, level, target) in neighborhoodFabric {
            try place(kind, level: level, near: target)
        }

        let sourceScene = CityScene(size: CGSize(width: 1_280, height: 800))
        sourceScene.reducedMotion = true
        sourceScene.render(
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let sourceNames = Set(sourceScene.children.flatMap(descendantNodeNames))
        let expectedPairs = [
            "hearthside_council_hall", "cedar_arch_council_hall",
            "bluecrest_police_station", "harborwatch_police_precinct",
            "emberline_fire_station", "lantern_gate_fire_house",
            "maplewood_neighborhood_school", "oakridge_courtyard_school",
            "brick_grid_substation", "copper_arc_powerhouse",
            "municipal_water_tower", "rivermark_standpipe_waterworks",
        ]
        for assetID in expectedPairs {
            XCTAssertTrue(
                sourceNames.contains("lot.four-view.\(assetID).camNE"),
                assetID
            )
        }

        let center = GridCoordinate(x: 13, y: 14)
        let regular = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 0.98,
            hover: nil,
            exactPixelDimensions: true
        )
        let compact = try rendererProofFrame(
            size: CGSize(width: 900, height: 600),
            state: state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .city,
            centeredOn: center,
            framingScale: 1.30,
            hover: nil,
            exactPixelDimensions: true
        )
        XCTAssertEqual(regular.width, 1_280)
        XCTAssertEqual(regular.height, 800)
        XCTAssertEqual(compact.width, 900)
        XCTAssertEqual(compact.height, 600)
        XCTAssertGreaterThan(regular.png.count, 50_000)
        XCTAssertGreaterThan(compact.png.count, 35_000)
        try export(regular, environmentKeys: [regularKey])
        try export(compact, environmentKeys: [compactKey])
    }

    @MainActor
    private func descendantNodeNames(in node: SKNode) -> [String] {
        (node.name.map { [$0] } ?? []) + node.children.flatMap(descendantNodeNames)
    }

    @MainActor
    private func hudBitmap(size: CGSize, store: CityGameStore) throws -> NSBitmapImageRep {
        let view = NSHostingView(rootView: ContentView(store: store).frame(width: size.width, height: size.height))
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25))

        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: representation)
        return representation
    }

    @MainActor
    private func toolbarBitmap(
        size: CGSize,
        store: CityGameStore,
        compact: Bool
    ) throws -> NSBitmapImageRep {
        let view = NSHostingView(
            rootView: BuildToolbarView(
                store: store,
                compact: compact,
                pointerTransitionGate: CityMapPointerTransitionGate()
            )
            .frame(width: size.width, height: size.height)
        )
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: representation)
        return representation
    }

    @MainActor
    private func tileRootIdentifiers(
        in scene: CityScene,
        state: CityGameState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> [GridCoordinate: ObjectIdentifier] {
        let identifiers = Dictionary(uniqueKeysWithValues: state.tiles.compactMap { tile in
            scene.tileRootIdentifier(at: tile.coordinate).map { (tile.coordinate, $0) }
        })
        XCTAssertEqual(identifiers.count, state.tiles.count, "Every tile needs a stable root", file: file, line: line)
        return identifiers
    }

    private func changedTileIdentifiers(
        before: [GridCoordinate: ObjectIdentifier],
        after: [GridCoordinate: ObjectIdentifier]
    ) -> Set<GridCoordinate> {
        Set(before.keys.filter { before[$0] != after[$0] })
    }

    private func rendererNeighborhoodState() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.gridWidth = 8
        state.gridHeight = 8
        state.tiles = (0..<64).map { index in
            CityTile(
                coordinate: GridCoordinate(x: index % state.gridWidth, y: index / state.gridWidth),
                kind: .empty
            )
        }
        for x in 1...6 { state.updateTile(at: GridCoordinate(x: x, y: 4)) { $0.kind = .road } }
        for y in 1...6 { state.updateTile(at: GridCoordinate(x: 4, y: y)) { $0.kind = .road } }
        state.updateTile(at: GridCoordinate(x: 3, y: 3)) { $0.kind = .cityHall }
        state.updateTile(at: GridCoordinate(x: 2, y: 3)) { $0.kind = .residential }
        state.updateTile(at: GridCoordinate(x: 5, y: 3)) { $0.kind = .commercial }
        state.updateTile(at: GridCoordinate(x: 3, y: 5)) { $0.kind = .park }
        return state
    }

    @MainActor
    func testResidentialQualityFamilySavedCityProofExportsExactNativeSurfaces() throws {
        let regularKey = "CITYSIM_RESIDENTIAL_QUALITY_1280_PROOF"
        let compactKey = "CITYSIM_RESIDENTIAL_QUALITY_900_PROOF"
        guard ProcessInfo.processInfo.environment[regularKey] != nil
                || ProcessInfo.processInfo.environment[compactKey] != nil else {
            return
        }

        var state = CityGameState.newCity(seed: 20_260_824)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        for y in [5, 11, 17] {
            for x in 2...21 {
                state.updateTile(at: GridCoordinate(x: x, y: y)) {
                    $0 = CityTile(coordinate: $0.coordinate, kind: .road)
                }
            }
        }
        for x in [5, 11, 17] {
            for y in 2...20 {
                state.updateTile(at: GridCoordinate(x: x, y: y)) {
                    $0 = CityTile(coordinate: $0.coordinate, kind: .road)
                }
            }
        }

        let catalog = FourViewWorldAssetCatalog()
        let family = [
            "alder_gable_cottage",
            "birch_lane_bungalow",
            "rosewood_turret_house",
            "stonebridge_duplex",
        ]
        let orientations: [(RoadConnectionMask, FourViewWorldAssetCatalog.Camera)] = [
            (.south, .camNE),
            (.west, .camSE),
            (.north, .camSW),
            (.east, .camNW),
        ]
        var used: Set<GridCoordinate> = []
        for (assetIndex, assetID) in family.enumerated() {
            for (orientationIndex, orientation) in orientations.enumerated() {
                let target = GridCoordinate(
                    x: 7 + assetIndex * 3,
                    y: 7 + orientationIndex * 3
                )
                let coordinate = try XCTUnwrap(state.tiles
                    .filter { tile in
                        tile.kind == .empty
                            && !used.contains(tile.coordinate)
                            && (3...20).contains(tile.coordinate.x)
                            && (3...19).contains(tile.coordinate.y)
                            && RoadConnectionMask.resolving(
                                at: tile.coordinate,
                                in: state
                            ).connectionCount == 1
                            && ResidentialGeneratedAssetIdentity.authoritativeFrontagePriority.first(
                                where: RoadConnectionMask.resolving(
                                    at: tile.coordinate,
                                    in: state
                                ).contains
                            ) == orientation.0
                            && catalog.assetID(
                                for: CityTile(
                                    coordinate: tile.coordinate,
                                    kind: .residential,
                                    level: 1
                                ),
                                variant: 1
                            ) == assetID
                    }
                    .map(\.coordinate)
                    .sorted { lhs, rhs in
                        let left = abs(lhs.x - target.x) + abs(lhs.y - target.y)
                        let right = abs(rhs.x - target.x) + abs(rhs.y - target.y)
                        return (left, lhs.y, lhs.x) < (right, rhs.y, rhs.x)
                    }
                    .first, "\(assetID).\(orientation.1.rawValue)")
                used.insert(coordinate)
                state.updateTile(at: coordinate) {
                    $0 = CityTile(
                        coordinate: coordinate,
                        kind: .residential,
                        level: 1,
                        condition: 1,
                        constructionProgress: 1
                    )
                }
            }
        }
        XCTAssertEqual(used.count, family.count * orientations.count)

        let saveRoot = FileManager.default.temporaryDirectory
            .appending(path: "citysim-residential-quality-\(UUID().uuidString)")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: saveRoot)
        }
        let saves = SaveGameService(rootURL: saveRoot)
        _ = try saves.save(state)
        let loaded = try saves.load()
        XCTAssertEqual(loaded.source, .primary)
        XCTAssertEqual(loaded.state, state)

        let sourceScene = CityScene(size: CGSize(width: 1_280, height: 800))
        sourceScene.reducedMotion = true
        sourceScene.render(
            state: loaded.state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect
        )
        let sourceNames = Set(sourceScene.children.flatMap(descendantNodeNames))
        for assetID in family {
            for (_, camera) in orientations {
                XCTAssertTrue(
                    sourceNames.contains("lot.four-view.\(assetID).\(camera.rawValue)"),
                    "\(assetID).\(camera.rawValue)"
                )
            }
        }

        let center = GridCoordinate(x: 11, y: 11)
        let regular = try rendererProofFrame(
            size: CGSize(width: 1_280, height: 800),
            state: loaded.state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .neighborhood,
            centeredOn: center,
            framingScale: 1.05,
            hover: nil,
            exactPixelDimensions: true
        )
        let compact = try rendererProofFrame(
            size: CGSize(width: 900, height: 600),
            state: loaded.state,
            overlay: .none,
            selection: nil,
            interactionMode: .inspect,
            detail: .neighborhood,
            centeredOn: center,
            framingScale: 1.16,
            hover: nil,
            exactPixelDimensions: true
        )
        XCTAssertEqual(regular.width, 1_280)
        XCTAssertEqual(regular.height, 800)
        XCTAssertEqual(compact.width, 900)
        XCTAssertEqual(compact.height, 600)
        XCTAssertGreaterThan(regular.png.count, 45_000)
        XCTAssertGreaterThan(compact.png.count, 32_000)
        try export(regular, environmentKeys: [regularKey])
        try export(compact, environmentKeys: [compactKey])
    }

    private func keyEvent(
        characters: String,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        ))
    }

    @MainActor
    private func descendantLabelTexts(in node: SKNode) -> [String] {
        var texts: [String] = []
        if let label = node as? SKLabelNode, let text = label.text { texts.append(text) }
        for child in node.children { texts.append(contentsOf: descendantLabelTexts(in: child)) }
        return texts
    }

    @MainActor
    private func rendererProofFrame(
        size: CGSize,
        state: CityGameState,
        overlay: DataOverlay,
        selection: GridCoordinate?,
        interactionMode: CityInteractionMode,
        detail: CameraDetailLevel?,
        centeredOn coordinate: GridCoordinate?,
        framingScale: CGFloat = 1,
        hover: GridCoordinate?,
        exactPixelDimensions: Bool = false
    ) throws -> RendererProofFrame {
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        let scene = CityScene(size: size)
        scene.reducedMotion = true
        view.presentScene(scene)
        scene.render(
            state: state,
            overlay: overlay,
            selection: selection,
            interactionMode: interactionMode
        )
        if let detail {
            scene.configureProofCamera(
                detail: detail,
                centeredOn: coordinate,
                framingScale: framingScale
            )
        }
        if let hover { scene.configureProofInteraction(at: hover) }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let texture = try XCTUnwrap(view.texture(from: scene))
        let sourceImage = texture.cgImage()
        let representation: NSBitmapImageRep
        if exactPixelDimensions,
           (sourceImage.width != Int(size.width) || sourceImage.height != Int(size.height)) {
            representation = try XCTUnwrap(NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width),
                pixelsHigh: Int(size.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ))
            representation.size = size
            let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: representation))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            context.imageInterpolation = .high
            NSImage(cgImage: sourceImage, size: size).draw(
                in: CGRect(origin: .zero, size: size),
                from: .zero,
                operation: .copy,
                fraction: 1
            )
            NSGraphicsContext.restoreGraphicsState()
        } else {
            representation = NSBitmapImageRep(cgImage: sourceImage)
        }
        let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        return RendererProofFrame(
            png: data,
            width: representation.pixelsWide,
            height: representation.pixelsHigh,
            diagnostics: scene.diagnosticsSnapshot
        )
    }

    private func export(_ frame: RendererProofFrame, environmentKeys: [String]) throws {
        for key in environmentKeys {
            guard let path = ProcessInfo.processInfo.environment[key], !path.isEmpty else { continue }
            try frame.png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
}

private struct RendererProofFrame {
    let png: Data
    let width: Int
    let height: Int
    let diagnostics: RendererDiagnosticsSnapshot
}
