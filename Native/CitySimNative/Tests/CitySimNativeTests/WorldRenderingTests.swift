import AppKit
import SpriteKit
import XCTest
@testable import CitySimNative

final class WorldRenderingTests: XCTestCase {
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
        XCTAssertTrue(distressedNames.contains("lot.lifecycle.growth.tier.2"))
        XCTAssertTrue(descendantLabels(in: distressedRoot).contains("DECLINE"))

        var recovered = distressed
        recovered.condition = 1
        recovered.occupancy = 100
        let recoveredRoot = renderer.makeLot(for: recovered, detail: .block, reducedMotion: true)
        let recoveredNames = descendantNames(in: recoveredRoot)
        XCTAssertFalse(recoveredNames.contains("lot.lifecycle.condition.distressed"))
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
    func testLifecycleProofFramesDistinguishConstructionDeclineAndRecovery() throws {
        let before = try lifecycleFrame(state: lifecycleProofState(recovered: false))
        let after = try lifecycleFrame(state: lifecycleProofState(recovered: true))

        XCTAssertGreaterThan(before.png.count, 40_000)
        XCTAssertGreaterThan(after.png.count, 40_000)
        XCTAssertNotEqual(before.png, after.png)
        XCTAssertEqual(before.diagnostics.totalTileCount, 64)
        XCTAssertEqual(after.diagnostics.totalTileCount, 64)

        try export(before.png, environmentKey: "CITYSIM_PLAY020_LIFECYCLE_PROOF")
        try export(after.png, environmentKey: "CITYSIM_PLAY020_RECOVERY_PROOF")
        print(
            "CITYSIM_PLAY020_DIAGNOSTICS lifecycle_nodes=\(before.diagnostics.nodeCount) " +
            "lifecycle_drawables=\(before.diagnostics.drawableNodeCount) " +
            "lifecycle_actions=\(before.diagnostics.activeActionCount) " +
            "lifecycle_update_ms=\(String(format: "%.3f", before.diagnostics.updateDurationMilliseconds)) " +
            "recovery_nodes=\(after.diagnostics.nodeCount) " +
            "recovery_drawables=\(after.diagnostics.drawableNodeCount) " +
            "recovery_actions=\(after.diagnostics.activeActionCount) " +
            "recovery_update_ms=\(String(format: "%.3f", after.diagnostics.updateDurationMilliseconds)) " +
            "detail=\(after.diagnostics.detailLevel)"
        )
    }

    private func lifecycleProofState(recovered: Bool) -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.gridWidth = 8
        state.gridHeight = 8
        state.tiles = (0..<64).map { index in
            CityTile(
                coordinate: GridCoordinate(x: index % 8, y: index / 8),
                kind: .empty
            )
        }
        for x in 0..<8 {
            state.updateTile(at: GridCoordinate(x: x, y: 4)) { $0.kind = .road }
        }

        let construction: [(Int, Double)] = [(1, 0), (2, 0.25), (3, 0.50), (4, 0.75)]
        for (x, progress) in construction {
            state.updateTile(at: GridCoordinate(x: x, y: 3)) {
                $0.kind = .residential
                $0.constructionProgress = progress
            }
        }
        state.updateTile(at: GridCoordinate(x: 5, y: 3)) {
            $0.kind = .commercial
            $0.level = 3
            $0.occupancy = 220
        }
        state.updateTile(at: GridCoordinate(x: 6, y: 3)) {
            $0.kind = .industrial
            $0.occupancy = recovered ? 180 : 0
            $0.condition = recovered ? 1 : 0.58
        }
        state.updateTile(at: GridCoordinate(x: 7, y: 3)) {
            $0.kind = .residential
            $0.occupancy = recovered ? 190 : 0
            $0.condition = recovered ? 1 : 0.24
        }
        state.updateTile(at: GridCoordinate(x: 2, y: 5)) { $0.kind = .park }
        state.updateTile(at: GridCoordinate(x: 4, y: 5)) { $0.kind = .cityHall }
        return state
    }

    @MainActor
    private func lifecycleFrame(
        state: CityGameState
    ) throws -> (png: Data, diagnostics: RendererDiagnosticsSnapshot) {
        let size = CGSize(width: 1_280, height: 800)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = CityScene(size: size)
        scene.reducedMotion = true
        view.presentScene(scene)
        scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
        scene.configureProofCamera(detail: .neighborhood, centeredOn: GridCoordinate(x: 4, y: 4))
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
}
