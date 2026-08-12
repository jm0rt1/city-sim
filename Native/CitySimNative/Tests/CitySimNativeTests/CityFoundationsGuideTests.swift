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
