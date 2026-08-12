import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class GameStatusOverlayTests: XCTestCase {
    func testLossPresentationNamesRenamedCityAndExplainsInsolvency() {
        var state = CityGameState.newCity(seed: 0x1055)
        state.cityName = "Harbor Light"
        state.treasury = -75_001
        state.happiness = 64
        state.status = .lost

        let presentation = CityLossPresentation.make(state: state)

        XCTAssertEqual(presentation.cause, .insolvency)
        XCTAssertEqual(presentation.title, "Harbor Light Became Insolvent")
        XCTAssertEqual(presentation.accessibilityLabel, "Harbor Light loss: insolvency")
        XCTAssertTrue(presentation.summary.contains("Harbor Light's treasury"))
        XCTAssertTrue(presentation.summary.contains("-$75,001"))
        XCTAssertTrue(presentation.recoveryGuidance.contains("cash reserve"))
        XCTAssertTrue(presentation.recoveryGuidance.contains("service upkeep"))
        XCTAssertEqual(presentation.metrics.map(\.label), ["Residents", "Treasury", "Cashflow", "Happiness"])
        XCTAssertEqual(presentation.metrics[1].value, "-$75,001")
        XCTAssertTrue(presentation.accessibilitySummary.contains("Treasury: -$75,001"))
        XCTAssertTrue(presentation.accessibilitySummary.hasSuffix(presentation.recoveryGuidance))
        XCTAssertFalse(presentation.accessibilitySummary.contains(".."))
        XCTAssertNil(presentation.strategy)
        XCTAssertNil(presentation.recovery)
        XCTAssertFalse(presentation.accessibilitySummary.contains("New Arcadia"))
    }

    func testLossPresentationExplainsHappinessCollapseAfterGracePeriod() {
        var state = CityGameState.newCity(seed: 0x1056)
        state.tick = 41
        state.treasury = 12_000
        state.happiness = 9
        state.status = .lost

        let presentation = CityLossPresentation.make(state: state)

        XCTAssertEqual(presentation.cause, .happinessCollapse)
        XCTAssertEqual(presentation.title, "New Arcadia Lost Public Confidence")
        XCTAssertEqual(presentation.accessibilityLabel, "New Arcadia loss: happiness collapse")
        XCTAssertTrue(presentation.summary.contains("happiness fell to 9%"))
        XCTAssertTrue(presentation.summary.contains("after the first 10 days"))
        XCTAssertTrue(presentation.recoveryGuidance.contains("utility coverage and parks"))
        XCTAssertTrue(presentation.recoveryGuidance.contains("below 10%"))
        XCTAssertEqual(presentation.metrics.last?.value, "9%")
        XCTAssertTrue(presentation.accessibilitySummary.contains("Happiness: 9%"))
        XCTAssertTrue(presentation.accessibilitySummary.hasSuffix(presentation.recoveryGuidance))
        XCTAssertFalse(presentation.accessibilitySummary.contains(".."))
        XCTAssertFalse(presentation.accessibilitySummary.localizedCaseInsensitiveContains("insolven"))
    }

    func testLossDebriefPreservesTheChosenStrategyAndRecoveryStory() throws {
        var state = CityGameState.newCity(seed: 0x1058)
        state.cityName = "Foundry Bay"
        state.treasury = -80_000
        state.happiness = 38
        state.status = .lost
        state.progression = CityProgressionState(
            strategy: CityStrategyProgression(
                committedStrategy: .industrialExpansion,
                currentPhase: .completed,
                nextScheduledTick: nil,
                recoveryResolution: .industrialGreenBuffer
            )
        )

        let presentation = CityLossPresentation.make(state: state)

        XCTAssertEqual(presentation.strategy?.title, "Industrial Expansion")
        XCTAssertEqual(presentation.recovery?.title, "Recovery · Green Buffer")
        XCTAssertTrue(presentation.accessibilitySummary.contains("Industrial Expansion"))
        XCTAssertTrue(presentation.accessibilitySummary.contains("Green Buffer"))
        XCTAssertFalse(presentation.accessibilitySummary.contains("New Arcadia"))
    }

    @MainActor
    func testVictoryPresentationPreservesAuthenticLegacyCharterIdentity() throws {
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
            XCTAssertEqual(presentation.storyHeading, "Your Charter Story")
            XCTAssertEqual(presentation.accessibilityLabel, "Town Charter victory")
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
    func testVictoryPresentationUsesDurableRegionalCapitalIdentity() throws {
        let resolutions: [CityStrategyRecoveryResolution] = [
            .commercialTaxRelief,
            .commercialPublicRealmInvestment,
            .industrialUtilityExpansion,
            .industrialGreenBuffer,
        ]
        for resolution in resolutions {
            let state = wonFixture(resolution: resolution, regionalCapital: true)
            let presentation = CityVictoryPresentation.make(
                state: state,
                analytics: CityAnalytics(state: state)
            )

            XCTAssertEqual(presentation.eyebrow, "Regional Capital Recognized")
            XCTAssertEqual(presentation.title, "New Arcadia Became a Regional Capital")
            XCTAssertEqual(presentation.storyHeading, "Your Regional Capital Story")
            XCTAssertEqual(presentation.accessibilityLabel, "Regional Capital victory")
            XCTAssertTrue(presentation.summary.contains("Regional Capital"))
            XCTAssertTrue(presentation.accessibilitySummary.contains("Regional Capital"))
            XCTAssertFalse(presentation.accessibilitySummary.contains(".."))
            XCTAssertTrue(presentation.accessibilitySummary.hasSuffix("."))
        }
    }

    @MainActor
    func testTerminalStorePausesAndQuarantinesGameplayUntilExistingReplayRouteRuns() {
        let won = wonFixture(
            resolution: .commercialPublicRealmInvestment,
            regionalCapital: true
        )
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

        let focusGeneration = store.mapFocusRequestGeneration
        XCTAssertTrue(store.perform(.newRegion))
        XCTAssertEqual(store.state.status, .playing)
        XCTAssertEqual(store.state.tick, 0)
        XCTAssertEqual(store.state.formattedDay, "Day 1")
        XCTAssertEqual(store.state.population, 300)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 1)
        XCTAssertEqual(store.lastFeedback, "A fresh region is ready")
        XCTAssertTrue(store.perform(.togglePause))
        XCTAssertEqual(store.speed, .normal)
        XCTAssertEqual(store.speed.controlLabel, "1x")
    }

    @MainActor
    func testLostStoreExplainsCrisisInsteadOfClaimingTheMandateWasCompleted() {
        var lost = CityGameState.newCity(seed: 0x1057)
        lost.cityName = "Harbor Light"
        lost.treasury = -75_001
        lost.status = .lost
        let store = CityGameStore(state: lost)

        XCTAssertEqual(store.speed, .paused)
        XCTAssertFalse(store.canPerform(.togglePause))
        XCTAssertFalse(store.canPerform(.openCommandGuide))
        XCTAssertEqual(
            store.disabledReason(for: .togglePause),
            "This city session ended in crisis; start a new region or load a city"
        )
        XCTAssertFalse(
            store.disabledReason(for: .togglePause)?.contains("mandate is complete") == true
        )
        XCTAssertTrue(store.canPerform(.newRegion))
        XCTAssertTrue(store.canPerform(.saveCity))
    }

    @MainActor
    func testPausedAppStartupKeepsFreshRootAtDayOneUntilUserExplicitlyLoadsItsSave() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play051-startup-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = SaveGameService(rootURL: root)
        let fresh = CityGameStore(saveService: service, startsPaused: true)

        XCTAssertFalse(service.hasLoadCandidate)
        XCTAssertEqual(fresh.state.tick, 0)
        XCTAssertEqual(fresh.state.formattedDay, "Day 1")
        XCTAssertEqual(fresh.speed, .paused)
        XCTAssertTrue(fresh.perform(.togglePause))
        XCTAssertEqual(fresh.speed, .normal)

        var saved = CityGameState.newCity(seed: 0x051)
        for _ in 0..<20 { CitySimulation.step(&saved) }
        try service.save(saved)

        let relaunched = CityGameStore(saveService: service, startsPaused: true)
        XCTAssertTrue(service.hasLoadCandidate)
        XCTAssertEqual(relaunched.state.tick, 0, "Startup must not restore a save without the Load command")
        XCTAssertEqual(relaunched.speed, .paused)
        XCTAssertTrue(relaunched.perform(.loadCity))
        try relaunched.selectNewestCheckpointForTesting()
        XCTAssertEqual(relaunched.state, saved)
        XCTAssertEqual(relaunched.speed, .paused)
    }

    @MainActor
    func testAppDelegateLeavesCityRestoreToTheExplicitSaveRoot() {
        let delegate = CitySimAppDelegate()

        XCTAssertFalse(delegate.applicationShouldRestoreSecureState(NSApplication.shared))
        XCTAssertFalse(delegate.applicationShouldSaveSecureState(NSApplication.shared))
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
        let compactSize = CGSize(width: 900, height: 600)
        let defaultSize = CGSize(width: 1_278, height: 768)
        for regionalCapital in [false, true] {
            let store = CityGameStore(state: wonFixture(
                resolution: .industrialGreenBuffer,
                regionalCapital: regionalCapital
            ))
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

            if regionalCapital {
                try export(compact, environmentKey: "CITYSIM_PLAY070_COMPACT_PROOF")
                try export(regular, environmentKey: "CITYSIM_PLAY070_DEFAULT_PROOF")
            }
        }
    }

    @MainActor
    func testWonFixtureSaveAndLoadRemainsTruthfulAndPaused() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play038-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        let won = wonFixture(
            resolution: .industrialUtilityExpansion,
            regionalCapital: true
        )

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
        resolution: CityStrategyRecoveryResolution,
        regionalCapital: Bool = false
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
            ),
            secondAct: regionalCapital
                ? CitySecondActProgression(
                    phase: .completed,
                    nextScheduledTick: nil,
                    qualifyingCycles: CitySimulation.regionalCapitalQualificationCycles,
                    regionalCapitalAwarded: true
                )
                : nil
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
