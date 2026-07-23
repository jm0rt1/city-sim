import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class GameStatusOverlayTests: XCTestCase {
    @MainActor
    func testVictoryPresentationUsesOnlyCharterStrategyAndRecoveryTruth() throws {
        let expectations: [(CityStrategyRecoveryResolution, String, String)] = [
            (.commercialTaxRelief, "Commercial Stewardship", "Temporary Tax Relief"),
            (.commercialPublicRealmInvestment, "Commercial Stewardship", "Public Realm Investment"),
            (.industrialUtilityExpansion, "Industrial Expansion", "Utility Expansion"),
            (.industrialGreenBuffer, "Industrial Expansion", "Green Buffer")
        ]

        for (resolution, strategyTitle, recoveryTitle) in expectations {
            let state = wonFixture(resolution: resolution)
            let presentation = CityVictoryPresentation.make(
                state: state,
                analytics: CityAnalytics(state: state)
            )

            XCTAssertEqual(presentation.eyebrow, "Town Charter Secured")
            XCTAssertEqual(presentation.title, "New Arcadia Earned Its Town Charter")
            XCTAssertTrue(presentation.summary.contains("612 residents"))
            XCTAssertTrue(presentation.summary.contains("Charter"))
            XCTAssertFalse(presentation.accessibilitySummary.localizedCaseInsensitiveContains("metropolis"))
            XCTAssertFalse(presentation.accessibilitySummary.contains(".."))
            XCTAssertTrue(presentation.accessibilitySummary.hasSuffix("."))
            XCTAssertEqual(presentation.strategy?.title, strategyTitle)
            XCTAssertTrue(presentation.recovery?.title.contains(recoveryTitle) == true)
            XCTAssertEqual(presentation.metrics.first?.value, "612")
            XCTAssertEqual(presentation.metrics[1].value, "$18,750")
        }
    }

    @MainActor
    func testTerminalStorePausesAndQuarantinesGameplayUntilExistingReplayRouteRuns() {
        let won = wonFixture(resolution: .commercialPublicRealmInvestment)
        let store = CityGameStore(state: won)

        XCTAssertEqual(store.state.status, .won)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertTrue(store.canPerform(.newRegion))
        XCTAssertTrue(store.canPerform(.saveCity))
        XCTAssertFalse(store.canPerform(.togglePause))
        XCTAssertFalse(store.canPerform(.openCommandGuide))
        XCTAssertFalse(store.canPerform(.cancelInteraction))
        XCTAssertFalse(store.canRouteMapCommand(.mapMoveEast))
        XCTAssertEqual(
            store.disabledReason(for: .togglePause),
            "The mayoral mandate is complete; start a new region or load a city"
        )

        let wonFingerprint = try? CityStateFingerprinter.fingerprint(store.state)
        XCTAssertFalse(store.perform(.togglePause))
        XCTAssertFalse(store.perform(.openCommandGuide))
        XCTAssertEqual(try? CityStateFingerprinter.fingerprint(store.state), wonFingerprint)

        XCTAssertTrue(store.perform(.newRegion))
        XCTAssertEqual(store.state.status, .playing)
        XCTAssertEqual(store.state.population, 300)
        XCTAssertEqual(store.speed, .normal)
        XCTAssertEqual(store.lastFeedback, "A fresh region is ready")
    }

    @MainActor
    func testTerminalStatusSuppressesUnderlyingGameSurfaceWithoutChangingWelcomePolicy() {
        XCTAssertFalse(ContentView.suppressesGameSurface(for: .enabled, status: .playing))
        XCTAssertTrue(ContentView.suppressesGameSurface(for: .enabled, status: .won))
        XCTAssertTrue(ContentView.suppressesGameSurface(for: .enabled, status: .lost))
        XCTAssertTrue(ContentView.suppressesGameSurface(for: .blocked(.welcome), status: .playing))
    }

    @MainActor
    func testVictoryOverlayRendersWithinDefaultAndExactCompactBounds() throws {
        let store = CityGameStore(state: wonFixture(resolution: .industrialGreenBuffer))
        let compactSize = CGSize(width: 900, height: 600)
        let defaultSize = CGSize(width: 1_278, height: 768)
        let compact = try bitmap(
            of: GameStatusOverlay(store: store).frame(width: compactSize.width, height: compactSize.height),
            size: compactSize
        )
        let regular = try bitmap(
            of: GameStatusOverlay(store: store).frame(width: defaultSize.width, height: defaultSize.height),
            size: defaultSize
        )

        XCTAssertEqual(compact.size.width, compactSize.width, accuracy: 0.5)
        XCTAssertEqual(compact.size.height, compactSize.height, accuracy: 0.5)
        XCTAssertEqual(regular.size.width, defaultSize.width, accuracy: 0.5)
        XCTAssertEqual(regular.size.height, defaultSize.height, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(compact.pixelsWide, 900)
        XCTAssertGreaterThanOrEqual(compact.pixelsHigh, 600)

        try export(compact, environmentKey: "CITYSIM_PLAY038_COMPACT_PROOF")
        try export(regular, environmentKey: "CITYSIM_PLAY038_DEFAULT_PROOF")
    }

    @MainActor
    func testWonFixtureSaveAndLoadRemainsTruthfulAndPaused() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play038-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        let won = wonFixture(resolution: .industrialUtilityExpansion)

        _ = try service.save(won)
        let loaded = try service.load().state
        let store = CityGameStore(state: loaded)

        XCTAssertEqual(loaded, won)
        XCTAssertEqual(store.state.status, .won)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.analytics.committedStrategy, .industrialExpansion)
        XCTAssertEqual(store.analytics.strategyRecoveryResolution, .industrialUtilityExpansion)
    }

    @MainActor
    func testExportDeterministicWonSaveForStagedProofWhenRequested() throws {
        guard let rootPath = ProcessInfo.processInfo.environment["CITYSIM_PLAY038_WON_DATA_ROOT"],
              !rootPath.isEmpty else { return }
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        let service = SaveGameService(rootURL: root)
        _ = try service.save(wonFixture(resolution: .industrialGreenBuffer))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.saveURL.path))
    }

    private func wonFixture(
        resolution: CityStrategyRecoveryResolution
    ) -> CityGameState {
        let strategy: CityStrategy = switch resolution {
        case .commercialTaxRelief, .commercialPublicRealmInvestment:
            .commercialStewardship
        case .industrialUtilityExpansion, .industrialGreenBuffer:
            .industrialExpansion
        }
        var state = CityGameState.newCity(seed: 0x38)
        state.population = 612
        state.jobs = 440
        state.treasury = 18_750
        state.happiness = 67
        state.powerUsed = 320
        state.powerCapacity = 430
        state.waterUsed = 292
        state.waterCapacity = 390
        state.progression = CityProgressionState(
            townCharterQualifyingCycles: CitySimulation.townCharterQualificationCycles,
            townCharterAwarded: true,
            strategy: CityStrategyProgression(
                committedStrategy: strategy,
                currentPhase: .completed,
                nextScheduledTick: nil,
                recoveryResolution: resolution
            )
        )
        state.status = .won
        return state
    }

    @MainActor
    private func bitmap<Content: View>(
        of content: Content,
        size: CGSize
    ) throws -> NSBitmapImageRep {
        let view = NSHostingView(rootView: content)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: representation)
        return representation
    }

    private func export(_ image: NSBitmapImageRep, environmentKey: String) throws {
        guard let path = ProcessInfo.processInfo.environment[environmentKey], !path.isEmpty else {
            return
        }
        let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

}
