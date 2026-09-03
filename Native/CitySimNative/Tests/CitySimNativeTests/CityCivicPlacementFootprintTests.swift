import AppKit
import SpriteKit
import SwiftUI
import Vision
import XCTest
@testable import CitySimNative

final class CityCivicPlacementFootprintTests: XCTestCase {
    private let kinds: [BuildingKind] = [.fireStation, .policeStation, .school]
    private let target = GridCoordinate(x: 4, y: 4)

    func testEveryRoleAndFundingPolicyMatchesAuthoritativeCompletedCoverageWithoutMutation() throws {
        for kind in kinds {
            for policy in CityCivicServiceFundingPolicy.allCases {
                var state = district()
                state.civicServiceFundingPolicy = policy
                put(.fireStation, at: .init(x: 12, y: 4), in: &state)
                put(.policeStation, at: .init(x: 7, y: 6), in: &state)
                put(.school, at: .init(x: 10, y: 6), in: &state)
                state.updateTile(at: .init(x: 7, y: 6)) { $0.condition = 0.4 }
                let original = state
                let forecast = try XCTUnwrap(CityCivicServicePlacementForecast.make(kind: kind, at: target, in: state))
                var completed = state
                guard case .success = CitySimulation.build(kind, at: target, in: &completed) else {
                    return XCTFail("Fixture must permit construction")
                }
                completed.updateTile(at: target) { $0.constructionProgress = 1 }
                let current = CityCivicServiceAnalysis(state: state)
                let projected = CityCivicServiceAnalysis(state: completed)
                let expected = state.tiles.compactMap { tile -> CityCivicServicePlacementForecast.BlockGain? in
                    guard let before = current[tile.coordinate]?.coverage(for: kind),
                          let after = projected[tile.coordinate]?.coverage(for: kind),
                          after - before > 0.000_000_001 else { return nil }
                    return .init(coordinate: tile.coordinate, coverageGain: after - before,
                        completedCoverage: after, reachesHealthy: before < 0.75 && after >= 0.75)
                }.sorted { $0.coordinate.y == $1.coordinate.y ? $0.coordinate.x < $1.coordinate.x
                    : $0.coordinate.y < $1.coordinate.y }
                XCTAssertFalse(expected.isEmpty, "\(kind) \(policy)")
                XCTAssertEqual(forecast.blockGains, expected)
                XCTAssertEqual(forecast.healthyBlocks, expected.filter(\.reachesHealthy).count)
                for gain in forecast.blockGains {
                    let tile = try XCTUnwrap(state.tile(at: gain.coordinate))
                    XCTAssertNotEqual(tile.kind, .empty)
                    XCTAssertNotEqual(tile.kind, .road)
                    XCTAssertEqual(tile.constructionProgress, 1)
                    XCTAssertNotEqual(gain.coordinate, target)
                    XCTAssertTrue(forecast.mapAccessibilitySummary.contains("Block \(gain.coordinate.x + 1), \(gain.coordinate.y + 1)"))
                }
                XCTAssertEqual(state, original)
            }
        }
    }

    func testDisconnectedCappedUnfinishedAndUnaffordableSitesNeverPromiseFalseCoverage() throws {
        var state = district()
        let connected = GridCoordinate(x: 8, y: 4)
        let disconnected = GridCoordinate(x: 4, y: 8)
        let unfinished = GridCoordinate(x: 6, y: 4)
        let before = try XCTUnwrap(CityCivicServicePlacementForecast.make(kind: .fireStation, at: target, in: state))
        XCTAssertTrue(before.blockGains.contains { $0.coordinate == connected })
        XCTAssertFalse(before.blockGains.contains { $0.coordinate == disconnected || $0.coordinate == unfinished })
        put(.empty, at: .init(x: 6, y: 5), in: &state)
        state.treasury = 0
        let original = state
        let after = try XCTUnwrap(CityCivicServicePlacementForecast.make(kind: .fireStation, at: target, in: state))
        XCTAssertFalse(after.blockGains.contains { $0.coordinate == connected })
        XCTAssertLessThan(after.blockGains.count, before.blockGains.count)
        XCTAssertTrue(after.mapAccessibilitySummary.contains("after funded construction completes"))
        guard case .failure(.insufficientFunds) = CitySimulation.validateBuild(.fireStation, at: target, in: state) else {
            return XCTFail("Forecast must not fund construction")
        }
        XCTAssertEqual(state, original)
        XCTAssertNil(CityCivicServicePlacementForecast.make(kind: .fireStation, at: connected, in: state))
        XCTAssertNil(CityCivicServicePlacementForecast.make(kind: .fireStation, at: .init(x: 0, y: 0), in: state))
        XCTAssertNil(CityCivicServicePlacementForecast.make(kind: .waterTower, at: target, in: state))
        for kind in kinds {
            var capped = district()
            put(kind, at: .init(x: 4, y: 6), in: &capped)
            let forecast = try XCTUnwrap(CityCivicServicePlacementForecast.make(kind: kind, at: target, in: capped))
            XCTAssertTrue(forecast.blockGains.isEmpty)
            XCTAssertTrue(forecast.mapKey.contains("no existing block improves"))
        }
    }

    @MainActor
    func testCivicMarkersSwitchRolesAndClearWithoutChangingWorldArt() throws {
        let store = CityGameStore(state: district(), startsPaused: true)
        let original = store.state
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        func render() {
            scene.render(state: store.state, overlay: store.overlay, selection: store.selectedCoordinate,
                interactionMode: store.interactionMode, activeActionTarget: store.activeMapActionTargetPresentation)
        }
        render()
        let root = scene.tileRootIdentifier(at: target)
        for kind in kinds {
            store.selectTool(kind)
            store.selectedCoordinate = target
            render()
            let forecast = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.civicForecast)
            XCTAssertEqual(scene.civicGainBlocksForTesting, forecast.blockGains)
            XCTAssertEqual(scene.interactionNamesForTesting.filter { $0.hasPrefix("interaction.civic-gain.") }.count,
                forecast.blockGains.count)
            XCTAssertEqual(scene.interactionNamesForTesting.filter { $0 == "civic-gain.healthy" }.count,
                forecast.healthyBlocks)
            XCTAssertTrue(scene.utilityGainBlocksForTesting.isEmpty)
            XCTAssertTrue(scene.utilityPollutionBlocksForTesting.isEmpty)
            XCTAssertEqual(scene.diagnosticsSnapshot.createdTileCount, 0)
            XCTAssertEqual(scene.tileRootIdentifier(at: target), root)
            XCTAssertEqual(store.state, original)
        }
        store.selectTool(.waterTower)
        store.selectedCoordinate = target
        render()
        XCTAssertTrue(scene.civicGainBlocksForTesting.isEmpty)
        store.selectTool(.fireStation)
        store.selectedCoordinate = target
        render()
        XCTAssertFalse(scene.civicGainBlocksForTesting.isEmpty)
        store.selectedCoordinate = .init(x: 8, y: 4)
        render()
        XCTAssertTrue(scene.civicGainBlocksForTesting.isEmpty)
        store.selectedCoordinate = target
        render()
        store.cancelBuildDecision()
        render()
        XCTAssertTrue(scene.civicGainBlocksForTesting.isEmpty)
        XCTAssertEqual(store.state, original)
        XCTAssertFalse(store.canUndo)
    }

    @MainActor
    func testFundingChangeRefreshesCoverageAtTheSameTarget() throws {
        var state = district()
        state.civicServiceFundingPolicy = .expanded
        let store = CityGameStore(state: state, startsPaused: true)
        store.selectTool(.fireStation)
        store.selectedCoordinate = target
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        func render() {
            scene.render(state: store.state, overlay: store.overlay, selection: store.selectedCoordinate,
                interactionMode: store.interactionMode, activeActionTarget: store.activeMapActionTargetPresentation)
        }
        render()
        let expanded = scene.civicGainBlocksForTesting
        store.state.civicServiceFundingPolicy = .reduced
        render()
        let reduced = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.civicForecast)
        XCTAssertEqual(scene.civicGainBlocksForTesting, reduced.blockGains)
        XCTAssertLessThan(reduced.blockGains.count, expanded.count)
        XCTAssertEqual(store.selectedCoordinate, target)
        XCTAssertEqual(scene.diagnosticsSnapshot.createdTileCount, 0)
    }

    @MainActor
    func testCivicDecisionRetainsCostsPayoffsMapKeyAndAccessibilityAtBothSizes() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            for kind in kinds {
                for funded in [true, false] {
                    var state = CityGameState.newCity(seed: 42)
                    if !funded { state.treasury = 0 }
                    let store = CityGameStore(state: state, startsPaused: true)
                    store.selectTool(kind)
                    store.selectedCoordinate = .init(x: 10, y: 10)
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
                    let forecast = try XCTUnwrap(decision.civicForecast)
                    XCTAssertFalse(forecast.blockGains.isEmpty)
                    XCTAssertEqual(scene.civicGainBlocksForTesting, forecast.blockGains)
                    XCTAssertTrue(map.cityAccessibilityHelp.contains(forecast.mapAccessibilitySummary))
                    XCTAssertTrue(map.cityAccessibilityHelp.contains("75 percent"))
                    XCTAssertEqual(decision.disabledReason == nil, funded)
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.recognitionLanguages = ["en-US"]
                    try VNImageRequestHandler(cgImage: XCTUnwrap(bitmap.cgImage)).perform([request])
                    let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: " ").lowercased()
                    let payoff = kind == .fireStation ? "storm damage" : kind == .policeStation ? "commercial demand" : "residential demand"
                    for expected in [kind.title.lowercased(), "improve", "healthy", payoff, "cancel", funded ? "build here" : "blocked"] {
                        XCTAssertTrue(text.contains(expected), "\(size) \(kind) funded=\(funded): missing \(expected): \(text)")
                    }
                    XCTAssertLessThanOrEqual(frames.bottom.height, 112)
                    XCTAssertTrue(store.state == state, "Placement preview changed the paused city")
                    XCTAssertFalse(store.canUndo)
                }
            }
        }
    }

    @MainActor
    func testBuildConfirmationRemainsReadableThroughLiveCivicRoleSwitches() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            let state = CityGameState.newCity(seed: 42)
            let store = CityGameStore(state: state, startsPaused: true)
            let host = NSHostingView(rootView: ContentView(store: store)
                .transaction { $0.disablesAnimations = true }.preferredColorScheme(.dark)
                .frame(width: size.width, height: size.height))
            host.frame = CGRect(origin: .zero, size: size)
            for kind in kinds {
                store.selectTool(kind)
                store.selectedCoordinate = .init(x: 10, y: 10)
                for _ in 0..<4 {
                    host.layoutSubtreeIfNeeded()
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
                }
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                try VNImageRequestHandler(cgImage: XCTUnwrap(bitmap.cgImage)).perform([request])
                let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ").lowercased()
                XCTAssertTrue(text.contains("build here"), "\(size) \(kind): \(text)")
                XCTAssertTrue(store.canPerformMapCommand(.mapPrimaryAction))
                XCTAssertTrue(store.state == state)
            }
        }
    }

    private func district() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for index in state.tiles.indices { state.tiles[index] = CityTile(coordinate: state.tiles[index].coordinate, kind: .empty) }
        state.treasury = 100_000
        for x in 2...15 { put(.road, at: .init(x: x, y: 5), in: &state) }
        put(.residential, at: .init(x: 5, y: 4), in: &state)
        put(.commercial, at: .init(x: 8, y: 4), in: &state)
        put(.industrial, at: .init(x: 14, y: 4), in: &state)
        put(.park, at: .init(x: 15, y: 4), in: &state)
        put(.residential, at: .init(x: 6, y: 4), in: &state)
        state.updateTile(at: .init(x: 6, y: 4)) { $0.constructionProgress = 0.5 }
        put(.residential, at: .init(x: 4, y: 8), in: &state)
        put(.road, at: .init(x: 4, y: 9), in: &state)
        return state
    }

    private func put(_ kind: BuildingKind, at coordinate: GridCoordinate, in state: inout CityGameState) {
        state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: kind) }
    }

    @MainActor private func findMap(in view: NSView) -> CityMapSKView? {
        if let map = view as? CityMapSKView { return map }
        return view.subviews.lazy.compactMap { self.findMap(in: $0) }.first
    }
}
