import AppKit
import SwiftUI
import Vision
import XCTest
@testable import CitySimNative

final class CityTaxPolicyPreviewTests: XCTestCase {
    func testEveryRateUsesAuthoritativeBudgetWithoutMutatingTheCity() throws {
        for economy in CitySandboxEconomy.allCases {
            var state = CityGameState.newCity(seed: 42)
            state.treasury = -6_000
            state.sandboxRules = CitySandboxRules(economy: economy, incidentsEnabled: true, unlimitedFunds: false)
            let before = try CityStateFingerprinter.fingerprint(state)
            for percent in 4...18 {
                let rate = Double(percent) / 100
                let preview = CityTaxPolicyPreview.make(in: state, proposedRate: rate)
                var applied = state
                XCTAssertEqual(CitySimulationCommandExecutor.apply(.setTaxRate(rate), to: &applied), .applied)
                XCTAssertEqual(preview.proposedRevenue, CitySimulation.projectedRevenue(in: applied))
                XCTAssertEqual(preview.proposedBalance, CitySimulation.projectedBalance(in: applied))
                XCTAssertEqual(preview.upkeep, CitySimulation.projectedUpkeep(in: applied))
                XCTAssertEqual(preview.currentBalance, CitySimulation.projectedBalance(in: state))
                XCTAssertEqual(preview.balanceChange, preview.proposedRevenue - preview.currentRevenue, accuracy: 0.000_001)
                XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), before)
            }
        }
    }

    func testPreviewClampsRatesAndRejectsNonFiniteOrUnchangedProposals() {
        let state = CityGameState.newCity(seed: 42)
        XCTAssertEqual(CityTaxPolicyPreview.make(in: state, proposedRate: -1).proposedRate, 0.04)
        XCTAssertEqual(CityTaxPolicyPreview.make(in: state, proposedRate: 2).proposedRate, 0.18)
        for value in [Double.nan, .infinity, -.infinity, state.taxRate] {
            let preview = CityTaxPolicyPreview.make(in: state, proposedRate: value)
            XCTAssertFalse(preview.canApply)
            XCTAssertTrue(preview.proposedBalance.isFinite)
        }
        var terminal = state
        terminal.status = .won
        XCTAssertFalse(CityTaxPolicyPreview.make(in: terminal, proposedRate: 0.09).canApply)
    }

    func testMainStreetTradeoffNamesTheActualOpenTaxThreshold() {
        var state = CityGameState.newCity(seed: 42)
        state.progression?.strategy = CityStrategyProgression(
            committedStrategy: .commercialStewardship, currentPhase: .complication, nextScheduledTick: 68
        )
        XCTAssertTrue(CityTaxPolicyPreview.make(in: state, proposedRate: 0.09).tradeoff.contains("9% tax-relief threshold"))
        state.taxRate = 0.09
        XCTAssertTrue(CityTaxPolicyPreview.make(in: state, proposedRate: 0.10).tradeoff.contains("Ends Main Street"))
        state.progression?.strategy?.recoveryResolution = .commercialTaxRelief
        XCTAssertFalse(CityTaxPolicyPreview.make(in: state, proposedRate: 0.10).tradeoff.contains("Ends Main Street"))
    }

    @MainActor
    func testApplyingOnePolicyIsUndoableAndDoesNotSpendOrAdvanceTheCity() {
        let store = CityGameStore(state: .newCity(seed: 42))
        store.speed = .paused
        let before = store.state
        store.setTaxRate(0.09)
        XCTAssertEqual(store.state.taxRate, 0.09)
        XCTAssertEqual(store.state.treasury, before.treasury)
        XCTAssertEqual(store.state.tick, before.tick)
        XCTAssertTrue(store.canUndo)
        XCTAssertTrue(store.lastFeedback?.contains("Undo is available") == true)
        store.setTaxRate(0.09)
        store.undoLastAction()
        XCTAssertEqual(store.state, before)
        XCTAssertFalse(store.canUndo, "No-op reapplication must not create another undo action")
    }

    @MainActor
    func testInvalidAndTerminalTaxChangesDoNotMutateOrCreateUndo() {
        let store = CityGameStore(state: .newCity(seed: 42))
        let before = store.state
        store.setTaxRate(.nan)
        store.setTaxRate(.infinity)
        XCTAssertEqual(store.state, before)
        XCTAssertFalse(store.canUndo)
        store.state.status = .lost
        let terminal = store.state
        store.setTaxRate(0.09)
        XCTAssertEqual(store.state, terminal)
        XCTAssertFalse(store.canUndo)
    }

    @MainActor
    func testTaxPreviewFitsExistingPanelsAndShowsTheCompleteDecision() throws {
        for compact in [true, false] {
            var state = CityGameState.newCity(seed: 42)
            state.progression?.strategy = CityStrategyProgression(
                committedStrategy: .commercialStewardship, currentPhase: .complication, nextScheduledTick: 68
            )
            let store = CityGameStore(state: state)
            let before = store.state
            let width = compact ? BuildToolbarView.compactDetailsWidth : BuildToolbarView.regularDetailsWidth
            let host = NSHostingView(rootView: CityTaxPolicyEditor(
                store: store, compact: compact, initialRate: 0.09, onClose: {}
            ).preferredColorScheme(.dark).frame(width: width - 6))
            host.layoutSubtreeIfNeeded()
            let height = host.fittingSize.height
            XCTAssertLessThanOrEqual(height + (compact ? 59 : 63),
                BuildToolbarView.detailsHeight(compact: compact, selectedBlock: false, finances: true))
            host.frame = CGRect(x: 0, y: 0, width: width - 6, height: height)
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: XCTUnwrap(bitmap.cgImage)).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ").lowercased()
            for required in ["tax preview", "not applied", "revenue", "upkeep", "net", "cancel", "apply 9%", "change", "main street"] {
                XCTAssertTrue(text.contains(required), "\(compact): Missing \(required): \(text)")
            }
            XCTAssertEqual(store.state, before, "A visible proposal is not saved city state")
            XCTAssertFalse(store.canUndo)
        }
    }
}
