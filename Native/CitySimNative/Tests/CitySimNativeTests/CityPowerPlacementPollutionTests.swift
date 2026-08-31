import AppKit
import SpriteKit
import SwiftUI
import Vision
import XCTest
@testable import CitySimNative

final class CityPowerPlacementPollutionTests: XCTestCase {
    func testPowerDecisionShowsServiceBenefitAndExactCompletedNeighborhoodPollutionWithoutMutation() throws {
        var state = fixture()
        put(.residential, at: .init(x: 10, y: 9), in: &state)
        put(.commercial, at: .init(x: 12, y: 10), in: &state)
        put(.residential, at: .init(x: 10, y: 13), in: &state)
        put(.residential, at: .init(x: 11, y: 10), progress: 0.5, in: &state)
        let before = state
        let target = GridCoordinate(x: 10, y: 10)
        let forecast = try XCTUnwrap(CityUtilityPlacementForecast.make(kind: .powerPlant, at: target, in: state))
        let impact = try XCTUnwrap(forecast.pollutionImpact)
        XCTAssertEqual(forecast.improvedDevelopedBlocks, 3)
        XCTAssertEqual(impact.affectedBlocks, 3, "Exclude roads, empty land, construction and the new plant")
        XCTAssertEqual(impact.affectedHomes, 2)
        XCTAssertEqual(impact.greatestIncrease, 0.7175, accuracy: 0.000_001)
        XCTAssertEqual(impact.summary, "Pollution: 3 blocks · max +72 pts")

        let decision = CityBuildDecisionPresentation.make(kind: .powerPlant, tile: try XCTUnwrap(state.tile(at: target)), rejection: nil, state: state)
        XCTAssertEqual(decision.pollutionImpact, impact)
        XCTAssertEqual(decision.likelyConsequence, forecast.summary)
        XCTAssertTrue(decision.accessibilitySummary.contains("including 2 residential blocks"))
        XCTAssertTrue(decision.accessibilitySummary.contains("72 percentage points"))
        XCTAssertTrue(decision.accessibilitySummary.contains("Escape cancels without changing the city"))

        var completed = state
        guard case .success = CitySimulation.build(.powerPlant, at: target, in: &completed) else {
            return XCTFail("Fixture must permit actual construction")
        }
        completed.updateTile(at: target) { $0.constructionProgress = 1 }
        let oldMap = CitySpatialConsequenceMap(state: state)
        let newMap = CitySpatialConsequenceMap(state: completed)
        let increases = oldMap.samples.filter { $0.vitality != .notApplicable }.compactMap { old -> Double? in
            guard let new = newMap[old.coordinate] else { return nil }
            let increase = new.pollutionExposure - old.pollutionExposure
            return increase > 0.000_000_001 ? increase : nil
        }
        XCTAssertEqual(impact.affectedBlocks, increases.count)
        XCTAssertEqual(impact.greatestIncrease, try XCTUnwrap(increases.max()), accuracy: 0.000_001)
        XCTAssertEqual(impact.blockImpacts.count, impact.affectedBlocks)
        XCTAssertEqual(impact.blockImpacts.filter(\.isResidential).count, impact.affectedHomes)
        for block in impact.blockImpacts {
            XCTAssertEqual(block.increase,
                try XCTUnwrap(newMap[block.coordinate]).pollutionExposure
                    - XCTUnwrap(oldMap[block.coordinate]).pollutionExposure, accuracy: 0.000_001)
            XCTAssertTrue(block.increase > 0)
            XCTAssertNotEqual(block.coordinate, target)
            XCTAssertEqual(state.tile(at: block.coordinate)?.constructionProgress, 1)
        }
        XCTAssertEqual(state, before)
    }

    func testMovingAwayFromDevelopmentRemovesCurrentExposureButDoesNotPromiseFutureSafety() throws {
        var state = fixture()
        put(.residential, at: .init(x: 10, y: 9), in: &state)
        for x in 2...9 { put(.road, at: .init(x: x, y: 1), in: &state) }
        for y in 2...9 { put(.road, at: .init(x: 9, y: y), in: &state) }
        let near = try XCTUnwrap(CityUtilityPlacementForecast.make(kind: .powerPlant, at: .init(x: 10, y: 10), in: state)?.pollutionImpact)
        let far = try XCTUnwrap(CityUtilityPlacementForecast.make(kind: .powerPlant, at: .init(x: 1, y: 1), in: state)?.pollutionImpact)
        XCTAssertGreaterThan(near.affectedBlocks, far.affectedBlocks)
        XCTAssertEqual(far.affectedBlocks, 0)
        XCTAssertEqual(far.greatestIncrease, 0)
        XCTAssertEqual(far.summary, "Pollution: no existing block worsens")
        XCTAssertTrue(far.accessibilitySummary.contains("Future development may still be exposed"))
        XCTAssertNil(CityUtilityPlacementForecast.make(kind: .waterTower, at: .init(x: 10, y: 10), in: state)?.pollutionImpact)
        XCTAssertNil(CityUtilityPlacementForecast.make(kind: .powerPlant, at: .init(x: 10, y: 9), in: state))
    }

    func testSeverePowerShortageStillDisclosesPollutionWithoutHealthyRecovery() throws {
        var state = fixture()
        put(.powerPlant, at: .init(x: 9, y: 10), in: &state)
        put(.residential, at: .init(x: 11, y: 10), in: &state)
        put(.road, at: .init(x: 10, y: 9), in: &state)
        put(.road, at: .init(x: 10, y: 11), in: &state)
        state.powerCapacity = CitySimulation.powerCapacityPerPlant
        state.powerUsed = 10_000
        let forecast = try XCTUnwrap(CityUtilityPlacementForecast.make(kind: .powerPlant, at: .init(x: 10, y: 10), in: state))
        XCTAssertEqual(forecast.restoredHealthyBlocks, 0)
        XCTAssertGreaterThan(try XCTUnwrap(forecast.pollutionImpact).affectedHomes, 0)
    }

    func testParkReliefAndExistingPollutionUseCappedAuthoritativeExposure() throws {
        var state = fixture()
        put(.residential, at: .init(x: 10, y: 9), in: &state)
        put(.industrial, at: .init(x: 11, y: 9), in: &state)
        put(.park, at: .init(x: 10, y: 8), in: &state)
        let target = GridCoordinate(x: 10, y: 10)
        let before = CitySpatialConsequenceMap(state: state)
        let forecast = try XCTUnwrap(CityUtilityPlacementForecast.make(kind: .powerPlant, at: target, in: state))
        var completed = state
        put(.powerPlant, at: target, in: &completed)
        let after = CitySpatialConsequenceMap(state: completed)
        let expected = before.samples.filter { $0.vitality != .notApplicable }.map { old in
            after[old.coordinate]!.pollutionExposure - old.pollutionExposure
        }
        XCTAssertEqual(forecast.pollutionImpact?.affectedBlocks, expected.filter { $0 > 0.000_000_001 }.count)
        XCTAssertEqual(try XCTUnwrap(forecast.pollutionImpact).greatestIncrease, try XCTUnwrap(expected.max()), accuracy: 0.000_001)
        XCTAssertEqual(CityPlacementPollutionImpact(affectedBlocks: 1, affectedHomes: 1, greatestIncrease: 0.004).summary,
                       "Pollution: 1 block · max under +1 pt")
    }

    func testConditionalPollutionAndIndependentMapSummaryDoNotFundConstruction() throws {
        var state = fixture()
        let target = GridCoordinate(x: 10, y: 10)
        let existingHome = GridCoordinate(x: 11, y: 10)
        put(.powerPlant, at: .init(x: 9, y: 10), in: &state)
        put(.road, at: .init(x: 10, y: 9), in: &state)
        put(.road, at: .init(x: 10, y: 11), in: &state)
        put(.residential, at: existingHome, in: &state)
        state.powerCapacity = CitySimulation.powerCapacityPerPlant
        state.treasury = 0
        let original = state
        let forecast = try XCTUnwrap(CityUtilityPlacementForecast.make(kind: .powerPlant, at: target, in: state))
        XCTAssertTrue(forecast.blockGains.contains { $0.coordinate == existingHome })
        let impact = try XCTUnwrap(forecast.pollutionImpact)
        XCTAssertTrue(impact.blockImpacts.contains { $0.coordinate == existingHome && $0.increase > 0 })
        XCTAssertTrue(try XCTUnwrap(forecast.mapAccessibilitySummary).contains("Residential block 12, 11"))
        XCTAssertTrue(try XCTUnwrap(forecast.mapAccessibilitySummary).contains("warning triangles"))
        XCTAssertTrue(impact.mapSummary.hasPrefix("⚠ Pollution"))
        XCTAssertTrue(forecast.fundingMapKey.contains("polluted"))
        // The presentation must retain harm information independently of its
        // service-gain list, not filter it through the positive map channel.
        let pollutionOnly = CityUtilityPlacementForecast(kind: .powerPlant,
            improvedDevelopedBlocks: 0, restoredHealthyBlocks: 0, greatestServiceGain: 0,
            pollutionImpact: impact)
        XCTAssertEqual(pollutionOnly.mapAccessibilitySummary, impact.mapAccessibilitySummary)
        guard case .failure(.insufficientFunds) = CitySimulation.validateBuild(.powerPlant, at: target, in: state) else {
            return XCTFail("A conditional footprint must not fund actual construction")
        }
        XCTAssertEqual(state, original)
    }

    @MainActor
    func testPollutionAndServiceCuesCoexistAndClearAcrossUtilityAndTargetChanges() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let original = store.state
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        func render() {
            scene.render(state: store.state, overlay: store.overlay, selection: store.selectedCoordinate,
                interactionMode: store.interactionMode, activeActionTarget: store.activeMapActionTargetPresentation)
        }
        render()
        XCTAssertTrue(CityUtilityDecisionView(store: store).beginConstruction(.powerPlant))
        render()
        let target = try XCTUnwrap(store.selectedCoordinate)
        let forecast = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.utilityForecast)
        let impacts = try XCTUnwrap(forecast.pollutionImpact).blockImpacts
        XCTAssertFalse(impacts.isEmpty)
        XCTAssertEqual(scene.utilityPollutionBlocksForTesting, impacts)
        XCTAssertEqual(scene.utilityGainBlocksForTesting, forecast.blockGains)
        var overlap = 0
        for impact in impacts {
            let suffix = "\(impact.coordinate.x).\(impact.coordinate.y)"
            let warning = try XCTUnwrap(scene.childNode(withName: "//interaction.utility-pollution.\(suffix)"))
            if forecast.blockGains.contains(where: { $0.coordinate == impact.coordinate }) {
                let benefit = try XCTUnwrap(scene.childNode(withName: "//interaction.utility-gain.\(suffix)"))
                XCTAssertEqual(warning.position.x - benefit.position.x, 18, accuracy: 0.000_001)
                XCTAssertEqual(warning.position.y, benefit.position.y)
                overlap += 1
            }
        }
        XCTAssertGreaterThan(overlap, 0)
        XCTAssertEqual(scene.diagnosticsSnapshot.createdTileCount, 0)
        store.selectTool(.waterTower)
        store.selectedCoordinate = target
        render()
        XCTAssertTrue(scene.utilityPollutionBlocksForTesting.isEmpty)
        XCTAssertFalse(scene.interactionNamesForTesting.contains { $0.hasPrefix("interaction.utility-pollution.") })
        store.selectTool(.powerPlant)
        store.selectedCoordinate = target
        render()
        XCTAssertFalse(scene.utilityPollutionBlocksForTesting.isEmpty)
        store.selectedCoordinate = try XCTUnwrap(store.state.tiles.first { $0.kind == .powerPlant }?.coordinate)
        render()
        XCTAssertTrue(scene.utilityPollutionBlocksForTesting.isEmpty)
        XCTAssertTrue(scene.utilityGainBlocksForTesting.isEmpty)
        store.selectedCoordinate = target
        render()
        store.cancelBuildDecision()
        render()
        XCTAssertTrue(scene.utilityPollutionBlocksForTesting.isEmpty)
        XCTAssertEqual(store.state, original)
    }

    @MainActor
    func testUnderfundedPowerKeepsBothMapEffectsReadableAndAccessibleAtBothSizes() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            var state = CityGameState.newCity(seed: 42)
            state.treasury = 0
            let store = CityGameStore(state: state)
            XCTAssertTrue(CityUtilityDecisionView(store: store).beginConstruction(.powerPlant))
            var frames = CityHUDChromeFrames()
            let host = NSHostingView(rootView: ContentView(store: store) { frames = $0 }
                .transaction { $0.disablesAnimations = true }
                .preferredColorScheme(.dark)
                .frame(width: size.width, height: size.height))
            host.frame = CGRect(origin: .zero, size: size)
            for _ in 0..<4 {
                host.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
            }
            func findMap(_ view: NSView) -> CityMapSKView? {
                if let map = view as? CityMapSKView { return map }
                return view.subviews.compactMap(findMap).first
            }
            let map = try XCTUnwrap(findMap(host))
            XCTAssertTrue(map.cityAccessibilityHelp.contains("warning triangles"))
            XCTAssertTrue(map.cityAccessibilityHelp.contains("after funded construction completes"))
            XCTAssertTrue(map.cityAccessibilityHelp.contains("cannot fund"))
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            try VNImageRequestHandler(cgImage: XCTUnwrap(bitmap.cgImage)).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ").lowercased()
            for expected in ["improve", "healthy", "polluted", "short", "if funded", "review finances", "cancel"] {
                XCTAssertTrue(text.contains(expected), "\(size): missing \(expected): \(text)")
            }
            XCTAssertLessThanOrEqual(frames.bottom.height, 112)
            XCTAssertEqual(store.state, state)
            XCTAssertFalse(store.canUndo)
        }
    }

    private func fixture() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for index in state.tiles.indices { state.tiles[index] = CityTile(coordinate: state.tiles[index].coordinate, kind: .empty) }
        state.treasury = 100_000
        state.powerCapacity = 0
        state.powerUsed = 150
        state.waterCapacity = 0
        state.waterUsed = 135
        put(.road, at: .init(x: 9, y: 10), in: &state)
        put(.road, at: .init(x: 9, y: 9), in: &state)
        return state
    }

    private func put(_ kind: BuildingKind, at coordinate: GridCoordinate, progress: Double = 1, in state: inout CityGameState) {
        state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: kind, constructionProgress: progress) }
    }
}
