import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityAuthoredScenarioTests: XCTestCase {
    func testHarborRecoveryDefinitionProvidesCompleteAuthoredContract() {
        let scenario = CityAuthoredScenarioCatalog.harborRecovery

        XCTAssertEqual(scenario.id, "harbor-recovery")
        XCTAssertEqual(scenario.cityName, "Harbor Point")
        XCTAssertFalse(scenario.briefing.isEmpty)
        XCTAssertFalse(scenario.objective.isEmpty)
        XCTAssertEqual(scenario.constraints.count, 3)
        XCTAssertEqual(scenario.targetTiers.map(\.medal), [.bronze, .silver, .gold])
        XCTAssertEqual(scenario.targetTiers.map(\.deadline), [
            "Before Day 41", "By Day 28", "By Day 22"
        ])
        XCTAssertEqual(scenario.estimatedDuration, "15–25 minutes")
    }

    func testScenarioStartIsDeterministicPressuredAndSeparateFromCampaignProgression() throws {
        let scenario = CityAuthoredScenarioCatalog.harborRecovery
        let first = scenario.makeState()
        let second = scenario.makeState()
        let evaluation = try XCTUnwrap(CityAuthoredScenarioEvaluation.make(state: first))

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.cityName, "Harbor Point")
        XCTAssertEqual(first.seed, scenario.seed)
        XCTAssertEqual(first.authoredScenario?.scenarioID, scenario.id)
        XCTAssertEqual(first.authoredScenario?.deadlineTick, 160)
        XCTAssertEqual(first.authoredScenario?.result, .active)
        XCTAssertNil(first.progression)
        XCTAssertEqual(first.population, 360)
        XCTAssertEqual(first.treasury, 16_000)
        XCTAssertFalse(evaluation.mandatoryComplete)
        XCTAssertLessThan(evaluation.projectedBalance, 0)
        XCTAssertTrue(evaluation.adaptiveHint.contains("Utility") || evaluation.adaptiveHint.contains("Operations"))
        XCTAssertEqual(evaluation.objectives.map(\.id), [
            "scenario-stability", "scenario-reserve", "scenario-population"
        ])

        let priority = CityStrategyHUDPresentation.make(state: first)
        XCTAssertEqual(priority.eyebrow, "HARBOR RECOVERY")
        XCTAssertEqual(priority.title, "Stabilize Harbor Point")
        XCTAssertEqual(priority.status, "40 DAYS LEFT")
        XCTAssertEqual(priority.diagnostic?.command, .inspectorUtilities)
        XCTAssertFalse(priority.accessibilityValue.contains("growth engine"))
        XCTAssertFalse(priority.actions.contains { $0.command == priority.diagnostic?.command })
    }

    func testScenarioEngineAwardsGoldAndExplainsBothFailurePaths() throws {
        var gold = CityAuthoredScenarioCatalog.harborRecovery.makeState()
        gold.population = 450
        gold.treasury = 30_000
        gold.happiness = 60
        gold.powerUsed = 240
        gold.powerCapacity = 300
        gold.waterUsed = 216
        gold.waterCapacity = 270
        gold.taxRate = 0.18
        XCTAssertGreaterThanOrEqual(CitySimulation.projectedBalance(in: gold), 0)

        CityAuthoredScenarioEngine.evaluate(&gold)

        XCTAssertEqual(gold.authoredScenario?.result, .gold)
        XCTAssertEqual(gold.status, .won)
        XCTAssertEqual(gold.messages.first?.title, "Harbor Recovery Complete")
        let goldDebrief = try XCTUnwrap(CityScenarioDebriefPresentation.make(state: gold))
        XCTAssertTrue(goldDebrief.succeeded)
        XCTAssertTrue(goldDebrief.eyebrow.contains("Gold"))
        XCTAssertTrue(goldDebrief.accessibilityLabel.contains("Gold medal"))

        var deadline = CityAuthoredScenarioCatalog.harborRecovery.makeState()
        deadline.tick = 160
        CityAuthoredScenarioEngine.evaluate(&deadline)
        XCTAssertEqual(deadline.authoredScenario?.result, .failedDeadline)
        XCTAssertEqual(deadline.status, .lost)
        XCTAssertTrue(
            try XCTUnwrap(CityScenarioDebriefPresentation.make(state: deadline)).title
                .contains("Deadline")
        )

        var crisis = CityAuthoredScenarioCatalog.harborRecovery.makeState()
        crisis.status = .lost
        CityAuthoredScenarioEngine.evaluate(&crisis)
        XCTAssertEqual(crisis.authoredScenario?.result, .failedCityCrisis)
        XCTAssertEqual(crisis.messages.first?.title, "Harbor Recovery Ended")
    }

    func testDailySimulationOwnsScenarioDeadlineAndDoesNotStartCampaignStory() {
        var state = CityAuthoredScenarioCatalog.harborRecovery.makeState()
        state.tick = 159

        CitySimulation.step(&state)

        XCTAssertEqual(state.tick, 160)
        XCTAssertEqual(state.authoredScenario?.result, .failedDeadline)
        XCTAssertEqual(state.status, .lost)
        XCTAssertNil(state.progression)
        XCTAssertFalse(state.messages.contains { $0.title == "Choose a Growth Engine" })
        XCTAssertFalse(state.messages.contains { $0.title == "Town Charter Standards" })
    }

    func testScenarioIdentityAndOutcomeRoundTripThroughVerifiedSave() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-authored-scenario-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var state = CityAuthoredScenarioCatalog.harborRecovery.makeState()
        state.tick = 44
        state.treasury = 17_250

        _ = try service.save(state)
        let loaded = try service.load().state

        XCTAssertEqual(loaded, state)
        XCTAssertEqual(loaded.authoredScenario?.scenarioID, "harbor-recovery")
        XCTAssertEqual(loaded.authoredScenario?.result, .active)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(loaded),
            try CityStateFingerprinter.fingerprint(state)
        )
    }

    @MainActor
    func testNewRegionJourneyStartsAndResumesScenarioWithLiveObjectives() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-scenario-journey-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        let store = CityGameStore(
            state: .newCity(seed: 42),
            saveService: service,
            startsPaused: true
        )

        XCTAssertTrue(store.perform(.newRegion))
        store.updateNewRegionExperience(.authoredScenario)
        XCTAssertTrue(store.createNewRegion())

        XCTAssertEqual(store.state.authoredScenario?.scenarioID, "harbor-recovery")
        XCTAssertEqual(store.speed, .paused)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.objectivePresentations.map(\.id), [
            "scenario-stability", "scenario-reserve", "scenario-population"
        ])
        XCTAssertTrue(store.lastFeedback?.contains("40 city days") == true)
        XCTAssertTrue(store.save())

        let resumed = CityGameStore(
            state: .newCity(seed: 99),
            saveService: service,
            startsPaused: true
        )
        XCTAssertTrue(resumed.perform(.loadCity))
        try resumed.selectNewestCheckpointForTesting()
        XCTAssertEqual(resumed.state.authoredScenario?.scenarioID, "harbor-recovery")
        XCTAssertTrue(resumed.showObjectives)
        XCTAssertTrue(resumed.lastFeedback?.contains("Harbor Recovery") == true)
        XCTAssertTrue(resumed.lastFeedback?.contains("days remaining") == true)
    }

    @MainActor
    func testScenarioDebriefRendersAtCompactAndDefaultSizes() throws {
        var state = CityAuthoredScenarioCatalog.harborRecovery.makeState()
        state.population = 450
        state.treasury = 30_000
        state.happiness = 60
        state.powerUsed = 240
        state.powerCapacity = 300
        state.waterUsed = 216
        state.waterCapacity = 270
        state.taxRate = 0.18
        CityAuthoredScenarioEngine.evaluate(&state)
        let store = CityGameStore(state: state, startsPaused: true)

        for size in [CGSize(width: 900, height: 600), CGSize(width: 1_280, height: 800)] {
            let image = try bitmap(
                of: GameStatusOverlay(store: store)
                    .frame(width: size.width, height: size.height),
                size: size
            )
            XCTAssertEqual(image.size.width, size.width, accuracy: 0.5)
            XCTAssertEqual(image.size.height, size.height, accuracy: 0.5)
            if size.width > 1_000,
               let path = ProcessInfo.processInfo.environment["CITYSIM_SCENARIO_DEBRIEF_PROOF"] {
                let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
    }

    @MainActor
    func testScenarioSelectionAndLiveObjectivesRenderAtAcceptanceSizes() throws {
        var draft = CityNewRegionDraft.initial(seed: 42)
        draft.experience = .authoredScenario
        let defaults = try isolatedDefaults()
        defaults.set(true, forKey: CityPlayerPreferenceKey.hasSeenWelcome)
        defaults.set(true, forKey: CityPlayerPreferenceKey.reduceMotion)
        let store = CityGameStore(
            state: CityAuthoredScenarioCatalog.harborRecovery.makeState(),
            startsPaused: true
        )
        store.showObjectives = true

        for size in [CGSize(width: 900, height: 600), CGSize(width: 1_280, height: 800)] {
            let setup = try bitmap(
                of: NewRegionSetupView(
                    presentation: .standard,
                    draft: draft,
                    updateExperience: { _ in },
                    updateCityName: { _ in },
                    updateSeed: { _ in },
                    updateStartingResources: { _ in },
                    createAction: {},
                    cancelAction: {}
                )
                .frame(width: size.width, height: size.height),
                size: size
            )
            let live = try bitmap(
                of: ZStack {
                    Color.black
                    ContentView(store: store)
                        .defaultAppStorage(defaults)
                }
                .frame(width: size.width, height: size.height),
                size: size
            )
            XCTAssertEqual(setup.size.width, size.width, accuracy: 0.5)
            XCTAssertEqual(setup.size.height, size.height, accuracy: 0.5)
            XCTAssertEqual(live.size.width, size.width, accuracy: 0.5)
            XCTAssertEqual(live.size.height, size.height, accuracy: 0.5)
            if size.width > 1_000 {
                try export(setup, environmentKey: "CITYSIM_SCENARIO_SETUP_PROOF")
                try export(live, environmentKey: "CITYSIM_SCENARIO_HUD_PROOF")
            }
        }
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suite = "CityAuthoredScenarioTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        return defaults
    }

    private func export(_ image: NSBitmapImageRep, environmentKey: String) throws {
        guard let path = ProcessInfo.processInfo.environment[environmentKey], !path.isEmpty else {
            return
        }
        let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    @MainActor
    private func bitmap<Content: View>(of content: Content, size: CGSize) throws -> NSBitmapImageRep {
        let view = NSHostingView(rootView: content)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: representation)
        return representation
    }
}
