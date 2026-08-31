import AppKit
import SwiftUI
import Vision
import XCTest
@testable import CitySimNative

final class CityUtilityBudgetPreviewTests: XCTestCase {
    func testUnderfundedUtilityForecastMatchesFundedCompletionWithoutChangingCity() throws {
        for kind in [BuildingKind.powerPlant, .waterTower] {
            for economy in [CitySandboxEconomy.standard, .demanding] {
                var funded = CityGameState.newCity(seed: 42)
                funded.sandboxRules = CitySandboxRules(economy: economy, incidentsEnabled: true, unlimitedFunds: false)
                let tile = try validTile(for: kind, in: funded)
                let expected = try XCTUnwrap(CityBuildOperatingForecast.make(kind: kind, tile: tile, state: funded))
                var state = funded
                state.treasury = 6_178.45
                let fingerprint = try CityStateFingerprinter.fingerprint(state)
                let action = CityMapPrimaryActionPresentation.make(interactionMode: .build(kind), tile: tile, state: state)
                let decision = try XCTUnwrap(action.buildDecision)

                XCTAssertFalse(action.isAvailable)
                XCTAssertEqual(decision.availability, "Blocked")
                XCTAssertEqual(decision.disabledReason, BuildRejection.insufficientFunds.message)
                XCTAssertEqual(decision.recovery?.command, .inspectorFinances)
                XCTAssertEqual(decision.operatingForecast, expected)
                XCTAssertEqual(expected.currentBalance, CitySimulation.projectedBalance(in: state))
                XCTAssertEqual(try XCTUnwrap(decision.fundingShortfall), kind.buildCost - state.treasury, accuracy: 0.000_001)
                XCTAssertEqual(decision.fundingStatus, "\((kind.buildCost - state.treasury).rounded(.up).currencyText) short · Blocked")
                XCTAssertTrue(decision.operatingImpact.hasPrefix("If funded: net"))
                XCTAssertTrue(decision.accessibilitySummary.contains("completed construction"))
                XCTAssertTrue(decision.accessibilitySummary.contains("New financing costs are not included"))
                XCTAssertTrue(decision.accessibilitySummary.contains(decision.operatingImpact))
                XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), fingerprint)
                guard case .failure(.insufficientFunds) = CitySimulation.validateBuild(kind, at: tile.coordinate, in: state) else {
                    return XCTFail("A forecast must not make actual construction affordable")
                }
            }
        }
    }

    func testMissingSiteRequirementsNeverBecomeAConditionalPromise() throws {
        var funded = CityGameState.newCity(seed: 42)
        let occupied = try XCTUnwrap(funded.tiles.first { $0.kind == .powerPlant })
        let isolated = GridCoordinate(x: 0, y: 0)
        funded.updateTile(at: .init(x: 1, y: 0)) { $0.kind = .road }
        let roadless = try XCTUnwrap(funded.tiles.first { tile in
            if case .failure(.roadAccessRequired) = CitySimulation.validateBuild(.waterTower, at: tile.coordinate, in: funded) { return true }
            return false
        })
        for kind in [BuildingKind.powerPlant, .waterTower] {
            for tile in [occupied, roadless, try XCTUnwrap(funded.tile(at: isolated))] {
                var state = funded
                state.treasury = 0
                let decision = try XCTUnwrap(CityMapPrimaryActionPresentation.make(
                    interactionMode: .build(kind), tile: tile, state: state).buildDecision)
                XCTAssertNil(decision.operatingForecast)
                XCTAssertNil(decision.fundingShortfall)
                XCTAssertNil(decision.fundingAssumption)
                XCTAssertEqual(decision.operatingImpact, "Net forecast available when ready")
            }
        }
    }

    func testFundedUnlimitedAndNonutilityDecisionsRetainTheirExistingContract() throws {
        for kind in [BuildingKind.powerPlant, .waterTower] {
            for unlimited in [false, true] {
                var state = CityGameState.newCity(seed: 42)
                state.sandboxRules = CitySandboxRules(economy: .standard, incidentsEnabled: true, unlimitedFunds: unlimited)
                if unlimited { state.treasury = 0 }
                let tile = try validTile(for: kind, in: state)
                let action = CityMapPrimaryActionPresentation.make(interactionMode: .build(kind), tile: tile, state: state)
                let decision = try XCTUnwrap(action.buildDecision)
                XCTAssertTrue(action.isAvailable)
                XCTAssertNil(decision.fundingShortfall)
                XCTAssertNil(decision.fundingAssumption)
                XCTAssertTrue(decision.operatingImpact.hasPrefix(unlimited ? "Tracked net" : "Net on completion"))
            }
        }
        var state = CityGameState.newCity(seed: 42)
        let tile = try validTile(for: .residential, in: state)
        state.treasury = 0
        let decision = try XCTUnwrap(CityMapPrimaryActionPresentation.make(
            interactionMode: .build(.residential), tile: tile, state: state).buildDecision)
        XCTAssertNil(decision.operatingForecast)
        XCTAssertNil(decision.fundingShortfall)
    }

    @MainActor
    func testBudgetPreviewIsVisibleInTheBoundedDecisionAtBothNativeSizes() throws {
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1280, height: 800)] {
            for kind in [BuildingKind.powerPlant, .waterTower] {
                var state = CityGameState.newCity(seed: 42)
                state.treasury = 6_178.45
                let store = CityGameStore(state: state)
                XCTAssertTrue(CityUtilityDecisionView(store: store).beginConstruction(kind))
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
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["en-US"]
                try VNImageRequestHandler(cgImage: XCTUnwrap(bitmap.cgImage)).perform([request])
                let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ").lowercased()
                for expected in ["if funded", "short", "blocked", "review finances", "cancel", "cycle"] {
                    XCTAssertTrue(text.contains(expected), "\(size), \(kind): missing \(expected): \(text)")
                }
                XCTAssertFalse(text.contains("build here"))
                XCTAssertLessThanOrEqual(frames.bottom.height, 112)
                XCTAssertEqual(store.state, state)
                XCTAssertFalse(store.canUndo)
            }
        }
    }

    private func validTile(for kind: BuildingKind, in state: CityGameState) throws -> CityTile {
        try XCTUnwrap(state.tiles.first {
            if case .success = CitySimulation.validateBuild(kind, at: $0.coordinate, in: state) { return true }
            return false
        })
    }
}
