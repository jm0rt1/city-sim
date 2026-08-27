import AppKit
import Foundation
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityFoundationsGuideTests: XCTestCase {
    func testCurriculumPresentsConcreteActionsAndAlternateValidSolutions() {
        let lessons = CityFoundationsLesson.curriculum

        XCTAssertEqual(lessons.map(\.id), CityFoundationsLessonID.allCases)
        XCTAssertEqual(Set(lessons.map(\.id)).count, lessons.count)
        XCTAssertTrue(lessons.first { $0.id == .zoning }?.completionRule.contains("Any residential") == true)
        XCTAssertTrue(lessons.first { $0.id == .services }?.completionRule.contains("or school") == true)
        XCTAssertTrue(lessons.allSatisfy { !$0.actionTitle.isEmpty && !$0.detail.isEmpty })
    }

    @MainActor
    func testProgressPersistsOutsideCityStateAndLegacyFixturesDoNotOptIn() throws {
        let defaults = try isolatedDefaults()
        let state = CityGameState.newTrackedCity(seed: 2_026_081_213)
        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        let store = CityGameStore(state: state, startsPaused: true, playerDefaults: defaults)

        XCTAssertEqual(store.foundationsGuidePresentation?.currentLesson?.id, .observe)
        XCTAssertTrue(store.perform(.inspectorOverview))
        XCTAssertTrue(store.foundationsGuideProgress.completedLessonIDs.contains(.observe))
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)

        let resumed = CityGameStore(state: state, startsPaused: true, playerDefaults: defaults)
        XCTAssertTrue(resumed.foundationsGuideProgress.completedLessonIDs.contains(.observe))
        XCTAssertEqual(resumed.foundationsGuidePresentation?.currentLesson?.id, .roads)

        let legacy = CityGameStore(
            state: .newCity(seed: 2_026_081_213),
            startsPaused: true,
            playerDefaults: defaults
        )
        XCTAssertNil(legacy.foundationsGuidePresentation)
    }

    @MainActor
    func testRealMapActionsAdvanceRoadZoneAndAlternateServiceLessons() throws {
        let defaults = try isolatedDefaults()
        let store = CityGameStore(
            state: .newTrackedCity(seed: 7_017),
            startsPaused: true,
            playerDefaults: defaults
        )

        let roadsBefore = store.state.tiles.filter { $0.kind == .road }.count
        XCTAssertTrue(store.performMapFocused(.buildRoad))
        XCTAssertTrue(store.performMapAction(primary: true))
        XCTAssertGreaterThan(store.state.tiles.filter { $0.kind == .road }.count, roadsBefore)
        XCTAssertTrue(store.foundationsGuideProgress.completedLessonIDs.contains(.roads))

        let commercialBefore = store.state.tiles.filter { $0.kind == .commercial }.count
        XCTAssertTrue(store.performMapFocused(.buildCommercial))
        XCTAssertTrue(store.performMapAction(primary: true))
        XCTAssertGreaterThan(store.state.tiles.filter { $0.kind == .commercial }.count, commercialBefore)
        XCTAssertTrue(store.foundationsGuideProgress.completedLessonIDs.contains(.zoning))

        let parksBefore = store.state.tiles.filter { $0.kind == .park }.count
        XCTAssertTrue(store.performMapFocused(.buildPark))
        XCTAssertTrue(store.performMapAction(primary: true))
        XCTAssertGreaterThan(store.state.tiles.filter { $0.kind == .park }.count, parksBefore)
        XCTAssertTrue(store.foundationsGuideProgress.completedLessonIDs.contains(.services))
    }

    @MainActor
    func testGuideActionsExtendTheStreetGridAndLeaveAReadyZoneTarget() throws {
        let defaults = try isolatedDefaults()
        let store = CityGameStore(
            state: .newTrackedCity(seed: 7_020),
            startsPaused: true,
            playerDefaults: defaults
        )

        XCTAssertTrue(store.performFoundationsGuideAction())
        XCTAssertEqual(store.foundationsGuidePresentation?.currentLesson?.id, .roads)

        let disconnectedRoadTarget = try XCTUnwrap(store.state.tiles.first { tile in
            tile.kind == .empty
                && !store.state.neighbors(of: tile.coordinate).contains { $0.kind == .road }
        })
        store.selectedCoordinate = disconnectedRoadTarget.coordinate
        XCTAssertTrue(store.performFoundationsGuideAction())
        let roadTarget = try XCTUnwrap(store.selectedCoordinate)
        XCTAssertNotEqual(roadTarget, disconnectedRoadTarget.coordinate)
        XCTAssertEqual(store.interactionMode, .build(.road))
        XCTAssertTrue(store.state.neighbors(of: roadTarget).contains { $0.kind == .road })
        if case .failure(let rejection) = CitySimulation.validateBuild(
            .road,
            at: roadTarget,
            in: store.state
        ) {
            XCTFail("The guide must select a valid street extension, got \(rejection)")
        }
        XCTAssertTrue(store.performMapCommand(.mapPrimaryAction))
        XCTAssertEqual(store.state.tile(at: roadTarget)?.kind, .road)

        XCTAssertEqual(store.foundationsGuidePresentation?.currentLesson?.id, .zoning)
        XCTAssertTrue(store.performFoundationsGuideAction())
        let zoneTarget = try XCTUnwrap(store.selectedCoordinate)
        XCTAssertNotEqual(zoneTarget, roadTarget)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertTrue(store.state.neighbors(of: zoneTarget).contains { $0.kind == .road })
        if case .failure(let rejection) = CitySimulation.validateBuild(
            .residential,
            at: zoneTarget,
            in: store.state
        ) {
            XCTFail("The guide must recover from the occupied road and select a ready zone, got \(rejection)")
        }
    }

    @MainActor
    func testFullGuidedJourneyCompletesFromPlayerActionsAndOneElapsedDay() throws {
        let defaults = try isolatedDefaults()
        let store = CityGameStore(
            state: .newTrackedCity(seed: 7_018),
            startsPaused: true,
            playerDefaults: defaults
        )

        XCTAssertTrue(store.performFoundationsGuideAction())
        XCTAssertEqual(store.foundationsGuidePresentation?.currentLesson?.id, .roads)

        XCTAssertTrue(store.performMapFocused(.buildRoad))
        XCTAssertTrue(store.performMapAction(primary: true))
        XCTAssertTrue(store.performMapFocused(.buildIndustrial))
        XCTAssertTrue(store.performMapAction(primary: true))
        XCTAssertTrue(store.perform(.inspectorUtilities))
        XCTAssertTrue(store.perform(.inspectorFinances))
        XCTAssertTrue(store.perform(.openNotices))

        XCTAssertEqual(store.foundationsGuidePresentation?.currentLesson?.id, .runCity)
        XCTAssertTrue(store.performFoundationsGuideAction())
        for _ in 0..<4 { store.pulse() }

        let presentation = try XCTUnwrap(store.foundationsGuidePresentation)
        XCTAssertTrue(presentation.isComplete)
        XCTAssertEqual(presentation.completedCount, presentation.totalCount)
        XCTAssertTrue(store.foundationsGuideProgress.isComplete)
    }

    @MainActor
    func testNewPlayerJourneyRecoversSavesQuitsAndResumesPausedAtShippingSizes() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-outcome-one-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = try isolatedDefaults()
        let service = SaveGameService(rootURL: root)
        let store = CityGameStore(
            state: .newTrackedCity(seed: 7_021),
            saveService: service,
            startsPaused: true,
            playerDefaults: defaults
        )

        XCTAssertTrue(store.performFoundationsGuideAction())
        XCTAssertEqual(store.foundationsGuidePresentation?.currentLesson?.id, .roads)
        XCTAssertTrue(store.performFoundationsGuideAction())

        let occupied = try XCTUnwrap(store.state.tiles.first { $0.kind != .empty })
        store.selectedCoordinate = occupied.coordinate
        store.clearFeedback()
        let beforeBlockedAttempt = store.state
        XCTAssertTrue(store.performMapAction(primary: true))
        XCTAssertEqual(store.state, beforeBlockedAttempt)
        guard case .caution = store.lastFeedbackTone else {
            return XCTFail("The rejected action must publish caution feedback")
        }
        XCTAssertNotNil(store.lastFeedback)

        XCTAssertTrue(store.performFoundationsGuideAction())
        let roadTarget = try XCTUnwrap(store.selectedCoordinate)
        XCTAssertTrue(store.state.neighbors(of: roadTarget).contains { $0.kind == .road })
        XCTAssertTrue(store.performMapCommand(.mapPrimaryAction))

        XCTAssertTrue(store.performFoundationsGuideAction())
        let zoneTarget = try XCTUnwrap(store.selectedCoordinate)
        XCTAssertNotEqual(zoneTarget, roadTarget)
        XCTAssertTrue(store.performMapCommand(.mapPrimaryAction))
        XCTAssertEqual(store.state.tile(at: zoneTarget)?.kind, .residential)

        store.setSpeed(.normal)
        for _ in 0..<4 { store.pulse() }
        XCTAssertGreaterThan(store.state.tick, 0)
        let savedCity = store.state
        let savedFingerprint = try CityStateFingerprinter.fingerprint(savedCity)
        XCTAssertTrue(store.save())
        XCTAssertFalse(store.hasUnsavedProgress)

        let delegate = CitySimAppDelegate()
        delegate.bind(store: store)
        XCTAssertEqual(delegate.applicationShouldTerminate(.shared), .terminateNow)

        let resumed = CityGameStore(
            state: .newTrackedCity(seed: 99),
            saveService: service,
            startsPaused: false,
            playerDefaults: defaults
        )
        resumed.prepareStartupResumeOffer()
        XCTAssertEqual(resumed.commandPolicy, .blocked(.startupResume))
        XCTAssertTrue(resumed.resumeStartupCity())
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(resumed.state), savedFingerprint)
        XCTAssertEqual(resumed.state, savedCity)
        XCTAssertEqual(resumed.speed, .paused)
        XCTAssertEqual(resumed.persistenceStatus.kind, .saved)
    }

    @MainActor
    func testSkipAndSettingsRestartDoNotReplaceOrMutateTheCity() throws {
        let defaults = try isolatedDefaults()
        var state = CityGameState.newTrackedCity(seed: 7_019)
        state.tick = 12
        state.treasury -= 430
        let store = CityGameStore(state: state, startsPaused: true, playerDefaults: defaults)

        store.dismissFoundationsGuide()
        XCTAssertNil(store.foundationsGuidePresentation)
        XCTAssertEqual(store.state, state)

        let revisionBefore = defaults.integer(forKey: CityPlayerPreferenceKey.foundationsGuideRevision)
        CitySettingsActions.restartFoundationsGuide(in: defaults)
        store.reloadFoundationsGuideProgress()

        XCTAssertEqual(
            defaults.integer(forKey: CityPlayerPreferenceKey.foundationsGuideRevision),
            revisionBefore + 1
        )
        XCTAssertEqual(store.foundationsGuidePresentation?.currentLesson?.id, .observe)
        XCTAssertEqual(store.state, state)
    }

    @MainActor
    func testGuidanceSurfaceWinsOverActivityButYieldsToObjectivesAndInspector() {
        XCTAssertEqual(
            ContentView.contextualGuidancePresentation(
                showObjectives: false,
                showInspector: false,
                hasActivity: true,
                hasFoundationsGuide: true
            ),
            .foundations
        )
        XCTAssertEqual(
            ContentView.contextualGuidancePresentation(
                showObjectives: true,
                showInspector: false,
                hasActivity: true,
                hasFoundationsGuide: true
            ),
            .objectives
        )
        XCTAssertEqual(
            ContentView.contextualGuidancePresentation(
                showObjectives: false,
                showInspector: true,
                hasActivity: true,
                hasFoundationsGuide: true
            ),
            .hidden
        )
    }

    @MainActor
    func testActiveGuideLayoutFitsEveryLessonAtShippingWidths() throws {
        for (index, lesson) in CityFoundationsLesson.curriculum.enumerated() {
            let defaults = try isolatedDefaults()
            let completed = Set(CityFoundationsLesson.curriculum.prefix(index).map(\.id))
            CityFoundationsGuidePersistence.write(
                CityFoundationsGuideProgress(completedLessonIDs: completed, isDismissed: false),
                to: defaults
            )
            let store = CityGameStore(
                state: .newTrackedCity(seed: 7_023 + UInt64(index)),
                startsPaused: true,
                playerDefaults: defaults
            )
            let presentation = try XCTUnwrap(store.foundationsGuidePresentation)

            XCTAssertEqual(presentation.currentLesson?.id, lesson.id)
            XCTAssertTrue(presentation.accessibilitySummary.contains(lesson.title))
            XCTAssertTrue(presentation.accessibilitySummary.contains(lesson.detail))
            XCTAssertTrue(presentation.accessibilitySummary.contains(lesson.completionRule))

            let compactView = NSHostingView(
                rootView: FoundationsGuideView(store: store, compact: true).fixedSize()
            )
            compactView.layoutSubtreeIfNeeded()
            let compactSize = compactView.fittingSize

            let regularView = NSHostingView(
                rootView: FoundationsGuideView(store: store, compact: false).fixedSize()
            )
            regularView.layoutSubtreeIfNeeded()
            let regularSize = regularView.fittingSize

            XCTAssertEqual(compactSize.width, GameTheme.compactContextCardWidth, accuracy: 1)
            XCTAssertLessThanOrEqual(compactSize.height, 160)
            XCTAssertEqual(regularSize.width, 258, accuracy: 1)
            XCTAssertLessThan(
                compactSize.width * compactSize.height,
                regularSize.width * regularSize.height
            )
        }
    }

    @MainActor
    func testCompletedGuideCollapsesOnlyAtCompactSizeAndKeepsReplayMeaning() throws {
        let defaults = try isolatedDefaults()
        let progress = CityFoundationsGuideProgress(
            completedLessonIDs: Set(CityFoundationsLessonID.allCases),
            isDismissed: false
        )
        CityFoundationsGuidePersistence.write(progress, to: defaults)
        let store = CityGameStore(
            state: .newTrackedCity(seed: 7_022),
            startsPaused: true,
            playerDefaults: defaults
        )
        let presentation = try XCTUnwrap(store.foundationsGuidePresentation)

        XCTAssertTrue(presentation.isComplete)
        XCTAssertEqual(
            presentation.accessibilitySummary,
            "Foundations Guide complete. All 7 lessons finished."
        )

        let compactView = NSHostingView(
            rootView: FoundationsGuideView(store: store, compact: true).fixedSize()
        )
        compactView.layoutSubtreeIfNeeded()
        let compactSize = compactView.fittingSize

        let regularView = NSHostingView(
            rootView: FoundationsGuideView(store: store, compact: false).fixedSize()
        )
        regularView.layoutSubtreeIfNeeded()
        let regularSize = regularView.fittingSize

        XCTAssertEqual(
            compactSize.width,
            FoundationsGuideView.compactCompletionWidth,
            accuracy: 1
        )
        XCTAssertLessThanOrEqual(compactSize.height, 52)
        XCTAssertEqual(regularSize.width, 258, accuracy: 1)
        XCTAssertGreaterThan(regularSize.height, compactSize.height + 48)
    }

    @MainActor
    func testFoundationsGuideRendersOverCurrentCityAtRegularWindowSize() throws {
        let defaults = try isolatedDefaults()
        let store = CityGameStore(
            state: .newTrackedCity(seed: 42),
            startsPaused: true,
            playerDefaults: defaults
        )
        let size = CGSize(width: 1_280, height: 800)
        let pointerGate = CityMapPointerTransitionGate()
        let content = ZStack(alignment: .topLeading) {
            CitySceneView(
                store: store,
                viewportInsets: CityMapViewportInsets(top: 120, leading: 24, bottom: 80, trailing: 24),
                pointerTransitionGate: pointerGate
            )
            FoundationsGuideView(store: store)
                .padding(12)
        }
        .frame(width: size.width, height: size.height)

        let view = NSHostingView(rootView: content)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))

        XCTAssertEqual(bitmap.size, size)
        XCTAssertGreaterThan(png.count, 40_000)
        XCTAssertEqual(store.foundationsGuidePresentation?.currentLesson?.id, .observe)
        if let path = ProcessInfo.processInfo.environment["CITYSIM_FOUNDATIONS_PROOF"] {
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suite = "CityFoundationsGuideTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        return defaults
    }
}
