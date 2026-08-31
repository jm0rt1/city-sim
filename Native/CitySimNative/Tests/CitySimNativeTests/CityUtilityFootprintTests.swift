import AppKit
import SpriteKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityUtilityFootprintTests: XCTestCase {
    func testEveryMapMarkerMatchesAuthoritativeCompletedServiceWithoutChangingTheCity() throws {
        for kind in [BuildingKind.powerPlant, .waterTower] {
            var state = CityGameState.newCity(seed: 42)
            let target = try validTile(for: kind, in: state).coordinate
            state.treasury = 0
            let fingerprint = try CityStateFingerprinter.fingerprint(state)
            let forecast = try XCTUnwrap(CityUtilityPlacementForecast.make(kind: kind, at: target, in: state))
            var completed = state
            completed.treasury = kind.buildCost
            guard case .success = CitySimulation.build(kind, at: target, in: &completed) else {
                return XCTFail("Expected a physically valid utility site")
            }
            completed.updateTile(at: target) { $0.constructionProgress = 1 }
            let active = CitySimulation.activeTiles(in: completed)
            completed.powerCapacity = active.filter { $0.kind == .powerPlant }.count * CitySimulation.powerCapacityPerPlant
            completed.waterCapacity = active.filter { $0.kind == .waterTower }.count * CitySimulation.waterCapacityPerTower
            let before = CitySpatialConsequenceMap(state: state)
            let after = CitySpatialConsequenceMap(state: completed)
            var expected: [CityUtilityPlacementForecast.BlockGain] = []
            for current in before.samples where current.vitality != .notApplicable {
                let next = try XCTUnwrap(after[current.coordinate])
                let gain = kind == .powerPlant ? next.utility.power - current.utility.power
                    : next.utility.water - current.utility.water
                guard gain > 0.000_000_001 else { continue }
                let restored = kind == .powerPlant
                    ? current.utility.powerBand != .healthy && next.utility.powerBand == .healthy
                    : current.utility.waterBand != .healthy && next.utility.waterBand == .healthy
                expected.append(.init(coordinate: current.coordinate, serviceGain: gain, reachesHealthy: restored))
            }
            XCTAssertFalse(expected.isEmpty)
            XCTAssertEqual(forecast.blockGains, expected)
            XCTAssertEqual(forecast.improvedDevelopedBlocks, expected.count)
            XCTAssertEqual(forecast.restoredHealthyBlocks, expected.filter(\.reachesHealthy).count)
            XCTAssertFalse(forecast.blockGains.contains { $0.coordinate == target })
            XCTAssertTrue(try XCTUnwrap(forecast.mapAccessibilitySummary).contains("after funded construction completes"))
            for gain in expected {
                XCTAssertTrue(try XCTUnwrap(forecast.mapAccessibilitySummary)
                    .contains("Block \(gain.coordinate.x + 1), \(gain.coordinate.y + 1)"))
            }
            XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), fingerprint)
        }
    }

    @MainActor
    func testSceneMovesAndClearsOnlyForecastMarksWithoutRebuildingWorldArt() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.reducedMotion = true
        func render() {
            scene.render(state: store.state, overlay: store.overlay, selection: store.selectedCoordinate,
                interactionMode: store.interactionMode, activeActionTarget: store.activeMapActionTargetPresentation)
        }
        render()
        let original = store.state
        let tile = try validTile(for: .waterTower, in: store.state)
        let root = scene.tileRootIdentifier(at: tile.coordinate)
        for kind in [BuildingKind.waterTower, .powerPlant] {
            store.selectTool(kind)
            let sites = store.state.tiles.filter {
                if case .success = CitySimulation.validateBuild(kind, at: $0.coordinate, in: store.state) { return true }
                return false
            }
            for target in try [XCTUnwrap(sites.first), XCTUnwrap(sites.last)] {
                store.selectedCoordinate = target.coordinate
                render()
                let forecast = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.utilityForecast)
                XCTAssertEqual(scene.utilityGainBlocksForTesting, forecast.blockGains)
                XCTAssertEqual(scene.interactionNamesForTesting.filter { $0.hasPrefix("interaction.utility-gain.") }.count,
                    forecast.improvedDevelopedBlocks)
                XCTAssertEqual(scene.interactionNamesForTesting.filter { $0 == "utility-gain.healthy" }.count,
                    forecast.restoredHealthyBlocks)
                XCTAssertEqual(scene.diagnosticsSnapshot.createdTileCount, 0)
                XCTAssertEqual(scene.tileRootIdentifier(at: tile.coordinate), root)
                XCTAssertEqual(store.state, original)
            }
        }
        store.cancelBuildDecision()
        render()
        XCTAssertTrue(scene.utilityGainBlocksForTesting.isEmpty)
        XCTAssertFalse(scene.interactionNamesForTesting.contains { $0.hasPrefix("interaction.utility-gain.") })
        store.selectTool(.commercial)
        store.selectedCoordinate = tile.coordinate
        render()
        XCTAssertTrue(scene.utilityGainBlocksForTesting.isEmpty)
        XCTAssertEqual(store.state, original)
    }

    @MainActor
    func testComposedPreviewKeepsTargetStateAndAccessibleLocationsAtBothSizes() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            var state = CityGameState.newCity(seed: 42)
            state.treasury = 0
            let store = CityGameStore(state: state)
            var frames = CityHUDChromeFrames()
            let host = NSHostingView(rootView: ContentView(store: store) { frames = $0 }
                .transaction { $0.disablesAnimations = true }
                .frame(width: size.width, height: size.height))
            host.frame = CGRect(origin: .zero, size: size)
            XCTAssertTrue(CityUtilityDecisionView(store: store).beginConstruction(.waterTower))
            settle(host)
            let map = try XCTUnwrap(findMap(in: host))
            let scene = try XCTUnwrap(map.scene as? CityScene)
            let decision = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction.buildDecision)
            let forecast = try XCTUnwrap(decision.utilityForecast)
            XCTAssertFalse(forecast.blockGains.isEmpty)
            XCTAssertEqual(scene.utilityGainBlocksForTesting, forecast.blockGains)
            XCTAssertTrue(map.cityAccessibilityHelp.contains(try XCTUnwrap(forecast.mapAccessibilitySummary)))
            XCTAssertTrue(map.cityAccessibilityHelp.contains("cannot fund"))
            XCTAssertLessThanOrEqual(frames.bottom.height, 112)
            XCTAssertEqual(store.state, state)
            store.cancelBuildDecision()
            settle(host)
            XCTAssertTrue(scene.utilityGainBlocksForTesting.isEmpty)
            XCTAssertFalse(map.cityAccessibilityHelp.contains("Planned service map"))
            XCTAssertEqual(store.state, state)
        }
    }

    private func validTile(for kind: BuildingKind, in state: CityGameState) throws -> CityTile {
        try XCTUnwrap(state.tiles.first {
            if case .success = CitySimulation.validateBuild(kind, at: $0.coordinate, in: state) { return true }
            return false
        })
    }

    @MainActor private func settle(_ host: NSView) {
        for _ in 0..<4 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        }
    }

    @MainActor private func findMap(in view: NSView) -> CityMapSKView? {
        if let map = view as? CityMapSKView { return map }
        return view.subviews.lazy.compactMap { self.findMap(in: $0) }.first
    }
}
