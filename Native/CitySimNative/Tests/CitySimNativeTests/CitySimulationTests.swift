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

    func testRoadAccessIsRequiredForZoning() {
        let state = CityGameState.newCity()
        let remote = GridCoordinate(x: 0, y: 0)
        guard case .failure(let rejection) = CitySimulation.validateBuild(.residential, at: remote, in: state) else {
            return XCTFail("Expected road access rejection")
        }
        XCTAssertEqual(rejection, .roadAccessRequired)
    }

    func testBuildingChargesTreasuryAndStartsConstruction() {
        var state = CityGameState.newCity()
        let coordinate = GridCoordinate(x: 8, y: 11)
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
        let coordinate = GridCoordinate(x: 8, y: 11)
        _ = CitySimulation.build(.residential, at: coordinate, in: &state)
        for _ in 0..<8 { CitySimulation.step(&state) }
        XCTAssertEqual(state.tile(at: coordinate)?.constructionProgress, 1)
        XCTAssertGreaterThanOrEqual(state.population, 180)
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
            "final_nodes=\(pulse.nodeCount)"
        )
    }

    @MainActor
    func testRendererInvalidatesOnlyOneChangedBuildingTile() {
        var state = CityGameState.newCity(seed: 42)
        let target = GridCoordinate(x: 8, y: 11)
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
        let target = GridCoordinate(x: 8, y: 11)
        let connectedRoad = GridCoordinate(x: 8, y: 12)
        let adjacentFrontage = GridCoordinate(x: 9, y: 11)
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
        XCTAssertEqual(
            overlayDiagnostics.nodeCount,
            initialNodeCount,
            "Land value must abstain until coordinate-scoped analytics are approved"
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
        XCTAssertEqual(blockDiagnostics.nodeCount, cityDiagnostics.nodeCount)
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
            .neighborhood,
            "Framing a compact city should preserve the neighborhood LOD and its tighter texture budget"
        )
        XCTAssertEqual(tileRootIdentifiers(in: scene, state: state), roots)
        XCTAssertEqual(scene.diagnosticsSnapshot.updatedTileCount, 0)
        XCTAssertEqual(scene.diagnosticsSnapshot.reusedTileCount, state.tiles.count)
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
        let buildCoordinate = GridCoordinate(x: 8, y: 11)
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
        XCTAssertLessThanOrEqual(TopHUDView.compactMaximumHeight, 116)
        XCTAssertLessThanOrEqual(TopHUDView.regularMaximumHeight, 136)
        XCTAssertLessThanOrEqual(BuildToolbarView.compactClosedMaximumHeight, 108)
        XCTAssertLessThanOrEqual(BuildToolbarView.regularClosedMaximumHeight, 108)
        XCTAssertLessThanOrEqual(BuildToolbarView.compactOpenMaximumHeight, 198)
        XCTAssertLessThanOrEqual(BuildToolbarView.regularOpenMaximumHeight, 238)
        XCTAssertLessThanOrEqual(BuildToolbarView.compactDetailsMaxHeight, 132)
        XCTAssertLessThanOrEqual(BuildToolbarView.regularDetailsMaxHeight, 168)
        XCTAssertLessThanOrEqual(StrategyCommandCenterView.compactMaximumHeight, 54)
        XCTAssertLessThanOrEqual(StrategyCommandCenterView.regularMaximumHeight, 64)
        XCTAssertGreaterThanOrEqual(GameTheme.hudCriticalTextSize, 11)
        XCTAssertGreaterThanOrEqual(GameTheme.hudSupportTextSize, 10)
        XCTAssertGreaterThanOrEqual(MetricCard.criticalTextSize, 11)
        XCTAssertGreaterThanOrEqual(MetricCard.supportTextSize, 10)
        XCTAssertEqual(InspectorView.compactColumnCount, 2)
        XCTAssertGreaterThanOrEqual(InspectorView.compactMinimumVisibleNoticeCount, 2)
        let compactClosedChrome = CityHUDChromeFrames(
            top: CGRect(x: 8, y: 8, width: 884, height: 116),
            bottom: CGRect(x: 8, y: 484, width: 884, height: 108)
        )
        XCTAssertGreaterThanOrEqual(
            ContentView.interactiveMapHeight(windowHeight: 600, chromeFrames: compactClosedChrome) / 600,
            0.58
        )
        let compactDetailsChrome = CityHUDChromeFrames(
            top: CGRect(x: 8, y: 8, width: 884, height: 116),
            bottom: CGRect(x: 8, y: 394, width: 884, height: 198)
        )
        XCTAssertGreaterThanOrEqual(
            ContentView.interactiveMapHeight(windowHeight: 600, chromeFrames: compactDetailsChrome) / 600,
            0.45
        )
        let compactInsets = ContentView.mapViewportInsets(
            windowSize: CGSize(width: 900, height: 600),
            compact: true,
            chromeFrames: compactClosedChrome
        )
        XCTAssertEqual(compactInsets.top, 136)
        XCTAssertEqual(compactInsets.bottom, 126)
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
        let store = CityGameStore(state: authoredStart)
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
        store.speed = .paused
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
        XCTAssertEqual(buildStore.interactionMode, .build(.commercial))
        let build = try hudBitmap(size: CGSize(width: 900, height: 600), store: buildStore)
        XCTAssertGreaterThan(build.pixelsWide, 850)
        XCTAssertGreaterThan(build.pixelsHigh, 550)
        if let path = ProcessInfo.processInfo.environment["CITYSIM_HUD_COMPACT_BUILD_PROOF"] {
            let data = try XCTUnwrap(build.representation(using: .png, properties: [:]))
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
        hover: GridCoordinate?
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
        if let detail { scene.configureProofCamera(detail: detail, centeredOn: coordinate) }
        if let hover { scene.configureProofInteraction(at: hover) }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let texture = try XCTUnwrap(view.texture(from: scene))
        let image = texture.cgImage()
        let representation = NSBitmapImageRep(cgImage: image)
        let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        return RendererProofFrame(
            png: data,
            width: image.width,
            height: image.height,
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
