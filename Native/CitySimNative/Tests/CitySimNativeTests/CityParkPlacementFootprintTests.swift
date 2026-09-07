import AppKit
import SpriteKit
import SwiftUI
import Vision
import XCTest
@testable import CitySimNative

final class CityParkPlacementFootprintTests: XCTestCase {
    private let target = GridCoordinate(x: 3, y: 8)

    func testEveryBenefitMatchesCompletedSpatialConsequencesWithoutMutation() throws {
        var state = postInvestmentCity()
        state.treasury = 0
        let original = state
        let forecast = try XCTUnwrap(CityParkPlacementForecast.make(at: target, in: state))
        var completed = state
        completed.treasury = BuildingKind.park.buildCost
        guard case .success = CitySimulation.build(.park, at: target, in: &completed) else {
            return XCTFail("Expected valid park site")
        }
        completed.updateTile(at: target) { $0.constructionProgress = 1 }
        let before = CitySpatialConsequenceMap(state: state)
        let after = CitySpatialConsequenceMap(state: completed)
        let expected = before.samples.compactMap { current -> CityParkPlacementForecast.BlockBenefit? in
            guard current.vitality != .notApplicable, let next = after[current.coordinate] else { return nil }
            let reduction = current.pollutionExposure - next.pollutionExposure
            guard reduction > 0.000_000_001
                || (next.landValueIndex ?? 0) - (current.landValueIndex ?? 0) > 0.000_000_001
                || (next.localHappinessIndex ?? 0) - (current.localHappinessIndex ?? 0) > 0.000_000_001
                || next.vitalityScore - current.vitalityScore > 0.000_000_001 else { return nil }
            return .init(coordinate: current.coordinate, pollutionReduction: max(0, reduction))
        }
        XCTAssertFalse(expected.isEmpty)
        XCTAssertEqual(forecast.blockBenefits, expected)
        XCTAssertEqual(forecast.benefitedDevelopedBlocks, expected.count)
        XCTAssertEqual(forecast.pollutionRelievedBlocks, expected.filter(\.reducesPollution).count)
        XCTAssertFalse(expected.contains { $0.coordinate == target })
        let tower = try XCTUnwrap(expected.first { $0.coordinate == .init(x: 3, y: 9) })
        XCTAssertEqual(tower.pollutionReduction, 0.16 * 2 / 3, accuracy: 0.000_001)
        XCTAssertTrue(forecast.mapAccessibilitySummary.contains("Block 4, 10 has pollution 11 points lower"))
        XCTAssertTrue(forecast.mapAccessibilitySummary.contains("after funded construction completes"))
        for benefit in expected {
            XCTAssertTrue(forecast.mapAccessibilitySummary.contains("Block \(benefit.coordinate.x + 1), \(benefit.coordinate.y + 1)"))
        }
        XCTAssertEqual(state, original)
        XCTAssertEqual(try JSONDecoder().decode(CityGameState.self, from: JSONEncoder().encode(state)), original)
    }

    func testValueOnlyNoBenefitAndInvalidSitesDoNotPromisePollutionRelief() throws {
        var state = postInvestmentCity()
        for index in state.tiles.indices { state.tiles[index] = CityTile(coordinate: state.tiles[index].coordinate, kind: .empty) }
        let empty = try XCTUnwrap(CityParkPlacementForecast.make(at: target, in: state))
        XCTAssertTrue(empty.blockBenefits.isEmpty)
        XCTAssertEqual(empty.mapKey, "Map: no existing block benefits")
        state.updateTile(at: .init(x: 3, y: 9)) { $0.kind = .residential; $0.occupancy = 180 }
        let valueOnly = try XCTUnwrap(CityParkPlacementForecast.make(at: target, in: state))
        XCTAssertEqual(valueOnly.blockBenefits.count, 1)
        XCTAssertFalse(try XCTUnwrap(valueOnly.blockBenefits.first).reducesPollution)
        XCTAssertEqual(valueOnly.mapKey, "Map: + 1 local benefit")
        XCTAssertFalse(valueOnly.mapAccessibilitySummary.contains("has pollution"))
        XCTAssertNil(CityParkPlacementForecast.make(at: .init(x: 3, y: 9), in: state))
        state.updateTile(at: .init(x: 3, y: 9)) { $0.constructionProgress = 0.5 }
        XCTAssertTrue(try XCTUnwrap(CityParkPlacementForecast.make(at: target, in: state)).blockBenefits.isEmpty)
    }

    @MainActor
    func testMarkersMoveRefreshAndClearWithoutChangingWorldArtOrCity() throws {
        let store = CityGameStore(state: postInvestmentCity(), startsPaused: true)
        let original = store.state
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        func render() {
            scene.render(state: store.state, overlay: store.overlay, selection: store.selectedCoordinate,
                interactionMode: store.interactionMode, activeActionTarget: store.activeMapActionTargetPresentation)
        }
        render()
        let root = scene.tileRootIdentifier(at: target)
        store.selectTool(.park)
        for site in [target, GridCoordinate(x: 0, y: 0), target] {
            store.selectedCoordinate = site
            render()
            let forecast = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.parkForecast)
            XCTAssertEqual(scene.parkBenefitBlocksForTesting, forecast.blockBenefits)
            XCTAssertEqual(scene.interactionNamesForTesting.filter { $0.hasPrefix("interaction.park-benefit.") }.count,
                forecast.benefitedDevelopedBlocks)
            XCTAssertEqual(scene.interactionNamesForTesting.filter { $0 == "park-benefit.less-pollution" }.count,
                forecast.pollutionRelievedBlocks)
            XCTAssertEqual(scene.tileRootIdentifier(at: target), root)
            XCTAssertEqual(scene.diagnosticsSnapshot.createdTileCount, 0)
            XCTAssertTrue(scene.utilityGainBlocksForTesting.isEmpty)
            XCTAssertTrue(scene.civicGainBlocksForTesting.isEmpty)
        }
        store.state.updateTile(at: .init(x: 4, y: 8)) { $0.kind = .empty }
        render()
        let refreshed = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.parkForecast)
        XCTAssertEqual(scene.parkBenefitBlocksForTesting, refreshed.blockBenefits)
        XCTAssertEqual(refreshed.pollutionRelievedBlocks, 0)
        XCTAssertTrue(scene.interactionNamesForTesting.contains("park-benefit.local-benefit"))
        store.state = original
        render()
        store.selectedCoordinate = .init(x: 3, y: 9)
        render()
        XCTAssertTrue(scene.parkBenefitBlocksForTesting.isEmpty)
        store.selectedCoordinate = target
        render()
        store.cancelBuildDecision()
        render()
        XCTAssertTrue(scene.parkBenefitBlocksForTesting.isEmpty)
        store.selectTool(.waterTower)
        store.selectedCoordinate = target
        render()
        XCTAssertTrue(scene.parkBenefitBlocksForTesting.isEmpty)
        XCTAssertEqual(store.state, original)
        XCTAssertFalse(store.canUndo)
    }

    @MainActor
    func testComposedDecisionKeepsCostsBenefitsMapLegendAndAXAtBothSizes() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            for funded in [true, false] {
                var state = postInvestmentCity()
                if !funded { state.treasury = 0 }
                let store = CityGameStore(state: state, startsPaused: true)
                store.selectTool(.park)
                store.selectedCoordinate = target
                var frames = CityHUDChromeFrames()
                let host = NSHostingView(rootView: ContentView(store: store) { frames = $0 }
                    .transaction { $0.disablesAnimations = true }.preferredColorScheme(.dark)
                    .frame(width: size.width, height: size.height))
                host.frame = CGRect(origin: .zero, size: size)
                for _ in 0..<4 {
                    host.layoutSubtreeIfNeeded()
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
                }
                let map = try XCTUnwrap(findMap(in: host))
                let scene = try XCTUnwrap(map.scene as? CityScene)
                let decision = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction.buildDecision)
                let forecast = try XCTUnwrap(decision.parkForecast)
                XCTAssertEqual(scene.parkBenefitBlocksForTesting, forecast.blockBenefits)
                XCTAssertTrue(map.cityAccessibilityHelp.contains(forecast.mapAccessibilitySummary))
                XCTAssertTrue(decision.accessibilitySummary.contains(forecast.mapAccessibilitySummary))
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                try VNImageRequestHandler(cgImage: XCTUnwrap(bitmap.cgImage)).perform([request])
                let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ").lowercased()
                for expected in ["park", "$900", "benefits", "11 pts lower", "map:", "less polluted", "cancel", funded ? "build here" : "blocked"] {
                    XCTAssertTrue(text.contains(expected), "\(size) funded=\(funded), missing \(expected): \(text)")
                }
                XCTAssertLessThanOrEqual(frames.bottom.height, 112)
                XCTAssertEqual(store.state, state)
                XCTAssertFalse(store.canUndo)
            }
        }
    }

    private func postInvestmentCity() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.updateTile(at: .init(x: 3, y: 9)) { $0.kind = .waterTower }
        state.updateTile(at: .init(x: 4, y: 8)) { $0.kind = .powerPlant }
        state.powerCapacity = 600
        state.waterCapacity = 540
        return state
    }

    @MainActor private func findMap(in view: NSView) -> CityMapSKView? {
        if let map = view as? CityMapSKView { return map }
        return view.subviews.lazy.compactMap { self.findMap(in: $0) }.first
    }
}
