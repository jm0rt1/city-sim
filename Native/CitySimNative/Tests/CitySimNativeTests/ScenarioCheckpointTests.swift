import Foundation
import XCTest
@testable import CitySimNative

final class ScenarioCheckpointTests: XCTestCase {
    func testDetectorNamesEachAuthoredProgressionTransition() {
        let base = CityGameState.newCity(seed: 101)

        var strategyChosen = base
        strategyChosen.progression = CityProgressionState(
            strategy: CityStrategyProgression(
                committedStrategy: .industrialExpansion,
                currentPhase: .opportunity,
                nextScheduledTick: 64
            )
        )
        XCTAssertEqual(
            CityScenarioCheckpointDetector.newlyReached(from: base, to: strategyChosen),
            [
                CityScenarioCheckpoint(
                    id: "industrial-expansion-chosen",
                    title: "Industrial Expansion Chosen"
                )
            ]
        )

        var recoveryPending = strategyChosen
        recoveryPending.progression?.strategy?.currentPhase = .recovery
        var recoveryComplete = recoveryPending
        recoveryComplete.progression?.strategy?.currentPhase = .completed
        recoveryComplete.progression?.strategy?.nextScheduledTick = nil
        XCTAssertEqual(
            CityScenarioCheckpointDetector.newlyReached(
                from: recoveryPending,
                to: recoveryComplete
            ),
            [
                CityScenarioCheckpoint(
                    id: "industrial-recovery-secured",
                    title: "Freight Recovery Secured"
                )
            ]
        )

        var chartered = recoveryComplete
        chartered.progression?.townCharterAwarded = true
        chartered.progression?.secondAct = CitySecondActProgression(
            phase: .mandate,
            nextScheduledTick: 128
        )
        XCTAssertEqual(
            CityScenarioCheckpointDetector.newlyReached(from: recoveryComplete, to: chartered),
            [CityScenarioCheckpoint(id: "town-charter", title: "Town Charter Secured")]
        )

        var regionalCapital = chartered
        regionalCapital.progression?.secondAct?.phase = .completed
        regionalCapital.progression?.secondAct?.regionalCapitalAwarded = true
        XCTAssertEqual(
            CityScenarioCheckpointDetector.newlyReached(from: chartered, to: regionalCapital),
            [
                CityScenarioCheckpoint(
                    id: "regional-capital",
                    title: "Regional Capital Recognized"
                )
            ]
        )
    }

    func testServiceKeepsFirstScenarioCheckpointImmutablePerCityAndRestarts() throws {
        let root = temporaryRoot(named: "service")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var first = CityGameState.newCity(seed: 202)
        first.cityName = "Milestone Harbor"
        first.tick = 64
        first.population = 540

        let write = try XCTUnwrap(
            service.saveScenarioCheckpoint(
                first,
                id: "town-charter",
                title: " Town Charter Secured "
            )
        )
        let url = service.scenarioCheckpointURL(seed: first.seed, id: "town-charter")
        let firstBytes = try Data(contentsOf: url)

        var replayed = first
        replayed.tick = 80
        replayed.population = 575
        XCTAssertNil(
            try service.saveScenarioCheckpoint(
                replayed,
                id: "town-charter",
                title: "Town Charter Secured"
            )
        )
        XCTAssertEqual(try Data(contentsOf: url), firstBytes)
        XCTAssertEqual(service.scenarioCheckpointURLs.count, 1)
        XCTAssertTrue(service.hasResumeCandidate)

        let relaunched = SaveGameService(rootURL: root)
        let entry = try XCTUnwrap(relaunched.checkpointCatalog().first)
        XCTAssertEqual(entry.source, .scenario)
        XCTAssertEqual(entry.scenarioCheckpointTitle, "Town Charter Secured")
        XCTAssertEqual(entry.loadResult?.scenarioCheckpointID, "town-charter")
        XCTAssertEqual(entry.loadResult?.state, first)
        XCTAssertEqual(entry.loadResult?.fingerprint, write.fingerprint)
        XCTAssertEqual(try relaunched.loadLatestResumeCandidate().state, first)

        var otherCity = first
        otherCity.seed = 203
        otherCity.cityName = "Second Harbor"
        XCTAssertNotNil(
            try relaunched.saveScenarioCheckpoint(
                otherCity,
                id: "town-charter",
                title: "Town Charter Secured"
            )
        )
        XCTAssertEqual(relaunched.scenarioCheckpointURLs.count, 2)
    }

    func testInvalidScenarioCheckpointIsVisibleAndNeverOverwritten() throws {
        let root = temporaryRoot(named: "corrupt")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        let state = CityGameState.newCity(seed: 303)
        try FileManager.default.createDirectory(
            at: service.scenarioCheckpointDirectoryURL,
            withIntermediateDirectories: true
        )
        let url = service.scenarioCheckpointURL(
            seed: state.seed,
            id: "industrial-expansion-chosen"
        )
        let invalidBytes = Data("broken scenario checkpoint".utf8)
        try invalidBytes.write(to: url, options: .atomic)

        XCTAssertThrowsError(
            try service.saveScenarioCheckpoint(
                state,
                id: "industrial-expansion-chosen",
                title: "Industrial Expansion Chosen"
            )
        ) {
            XCTAssertEqual(
                $0 as? SaveGameError,
                .scenarioCheckpointConflict("Industrial Expansion Chosen")
            )
        }
        XCTAssertEqual(try Data(contentsOf: url), invalidBytes)
        let entry = try XCTUnwrap(service.checkpointCatalog().first)
        XCTAssertEqual(entry.source, .scenario)
        XCTAssertEqual(entry.integrity, .invalid)
        XCTAssertFalse(entry.isLoadable)

        XCTAssertThrowsError(
            try service.saveScenarioCheckpoint(state, id: "../unsafe", title: "Unsafe")
        ) {
            XCTAssertEqual($0 as? SaveGameError, .invalidScenarioCheckpoint)
        }
    }

    @MainActor
    func testPulseCapturesStrategyChoiceWithoutCreatingAnAutosave() throws {
        let root = temporaryRoot(named: "pulse")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        let state = industrialStrategyReadyState(seed: 404)
        let store = CityGameStore(
            state: state,
            saveService: service,
            capturesScenarioCheckpoints: true
        )
        store.setSpeed(.normal)

        store.pulse()

        XCTAssertEqual(store.state.tick, 4)
        XCTAssertEqual(
            store.state.progression?.strategy?.committedStrategy,
            .industrialExpansion
        )
        XCTAssertEqual(service.scenarioCheckpointURLs.count, 1)
        XCTAssertTrue(service.autosaveURLs.allSatisfy {
            !FileManager.default.fileExists(atPath: $0.path)
        })
        let entry = try XCTUnwrap(service.checkpointCatalog().first)
        XCTAssertEqual(entry.source, .scenario)
        XCTAssertEqual(entry.scenarioCheckpointTitle, "Industrial Expansion Chosen")
        XCTAssertEqual(entry.loadResult?.state, store.state)
        XCTAssertEqual(store.persistenceStatus.label, "Checkpointed")
        XCTAssertFalse(store.hasUnsavedProgress)
        XCTAssertEqual(
            store.lastFeedback,
            "Scenario checkpoint “Industrial Expansion Chosen” secured · Day 2 · "
                + "\(store.state.population.formatted()) residents"
        )

        let bytes = try Data(contentsOf: try XCTUnwrap(service.scenarioCheckpointURLs.first))
        store.pulse()
        XCTAssertEqual(service.scenarioCheckpointURLs.count, 1)
        XCTAssertEqual(
            try Data(contentsOf: try XCTUnwrap(service.scenarioCheckpointURLs.first)),
            bytes
        )
    }

    @MainActor
    func testHeadlessStoreRequiresExplicitScenarioPersistenceLifecycle() {
        let root = temporaryRoot(named: "headless")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        let store = CityGameStore(
            state: industrialStrategyReadyState(seed: 405),
            saveService: service
        )
        store.setSpeed(.normal)

        store.pulse()

        XCTAssertEqual(
            store.state.progression?.strategy?.committedStrategy,
            .industrialExpansion
        )
        XCTAssertTrue(service.scenarioCheckpointURLs.isEmpty)
        XCTAssertEqual(store.persistenceStatus.label, "Not saved")
    }

    @MainActor
    func testFastestSpeedCapturesTheExactMilestoneTickBeforeLaterSteps() throws {
        let root = temporaryRoot(named: "fastest")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        let store = CityGameStore(
            state: industrialStrategyReadyState(seed: 406),
            saveService: service,
            capturesScenarioCheckpoints: true
        )
        store.setSpeed(.fastest)

        store.pulse()

        XCTAssertEqual(store.state.tick, 6)
        let checkpoint = try XCTUnwrap(service.checkpointCatalog().first?.loadResult?.state)
        XCTAssertEqual(checkpoint.tick, 4)
        XCTAssertEqual(
            checkpoint.progression?.strategy?.committedStrategy,
            .industrialExpansion
        )
        XCTAssertEqual(store.persistenceStatus.label, "Unsaved changes")
        XCTAssertTrue(store.hasUnsavedProgress)
    }

    @MainActor
    func testReplayKeepsOriginalMilestoneAndExplainsHowToPreserveThisTimeline() throws {
        let root = temporaryRoot(named: "replay")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        let state = industrialStrategyReadyState(seed: 407)
        try service.saveScenarioCheckpoint(
            state,
            id: "industrial-expansion-chosen",
            title: "Industrial Expansion Chosen"
        )
        let url = service.scenarioCheckpointURL(
            seed: state.seed,
            id: "industrial-expansion-chosen"
        )
        let originalBytes = try Data(contentsOf: url)
        let store = CityGameStore(
            state: state,
            saveService: service,
            capturesScenarioCheckpoints: true
        )
        store.setSpeed(.normal)

        store.pulse()

        XCTAssertEqual(try Data(contentsOf: url), originalBytes)
        XCTAssertEqual(service.scenarioCheckpointURLs.count, 1)
        XCTAssertEqual(store.persistenceStatus.label, "Not saved")
        XCTAssertEqual(
            store.lastFeedback,
            "Scenario checkpoint “Industrial Expansion Chosen” is already preserved · "
                + "Create a named branch to keep this timeline"
        )
    }

    @MainActor
    func testScenarioCheckpointSupportsStartupLoadAndBranching() throws {
        let root = temporaryRoot(named: "journey")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var saved = CityGameState.newCity(seed: 505)
        saved.cityName = "Charter Harbor"
        saved.tick = 72
        saved.population = 552
        try service.saveScenarioCheckpoint(
            saved,
            id: "town-charter",
            title: "Town Charter Secured"
        )
        let store = CityGameStore(saveService: service)

        store.prepareStartupResumeOffer()
        XCTAssertEqual(
            store.startupResumeOffer?.sourceLabel,
            "Scenario checkpoint · Town Charter Secured"
        )
        XCTAssertEqual(store.startupResumeOffer?.sourceSymbol, "flag.checkered")
        XCTAssertTrue(store.resumeStartupCity())
        XCTAssertEqual(store.state, saved)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.persistenceStatus.label, "Checkpointed")
        XCTAssertEqual(
            store.lastFeedback,
            "Resumed scenario “Town Charter Secured” · Day 19 · 552 residents · "
                + "Simulation paused"
        )

        XCTAssertTrue(store.perform(.loadCity))
        let card = try XCTUnwrap(store.checkpointLibrary?.cards.first)
        XCTAssertEqual(card.title, "Town Charter Secured")
        XCTAssertEqual(card.sourceLabel, "Authored scenario checkpoint")
        XCTAssertTrue(card.checkpoint.contains("Charter Harbor"))
        XCTAssertTrue(card.canBranch)
        XCTAssertTrue(store.beginBranchNaming(for: card.id))
        XCTAssertEqual(store.branchNaming?.sourceLabel, "Branch from scenario checkpoint")
        XCTAssertTrue(store.cancelBranchNaming())
        XCTAssertTrue(store.cancelCheckpointLibrary())
    }

    @MainActor
    func testCorruptMilestoneFileLeavesCityOpenWithPersistentWarning() throws {
        let root = temporaryRoot(named: "failure")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        let state = industrialStrategyReadyState(seed: 606)
        try FileManager.default.createDirectory(
            at: service.scenarioCheckpointDirectoryURL,
            withIntermediateDirectories: true
        )
        let url = service.scenarioCheckpointURL(
            seed: state.seed,
            id: "industrial-expansion-chosen"
        )
        let invalidBytes = Data("do not replace".utf8)
        try invalidBytes.write(to: url, options: .atomic)
        let store = CityGameStore(
            state: state,
            saveService: service,
            capturesScenarioCheckpoints: true
        )
        store.setSpeed(.normal)

        store.pulse()

        XCTAssertEqual(store.state.tick, 4)
        XCTAssertEqual(try Data(contentsOf: url), invalidBytes)
        XCTAssertEqual(store.persistenceStatus.label, "Not saved")
        XCTAssertTrue(store.hasUnsavedProgress)
        XCTAssertTrue(store.lastFeedback?.hasPrefix("Scenario checkpoint failed") == true)
        XCTAssertEqual(store.lastFeedbackTone, .caution)
    }

    @MainActor
    func testScenarioFailureAtTerminalBoundaryKeepsWarningAfterFallbackAutosave() throws {
        let root = temporaryRoot(named: "terminal-failure")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var state = industrialStrategyReadyState(seed: 707)
        state.treasury = -80_000
        try FileManager.default.createDirectory(
            at: service.scenarioCheckpointDirectoryURL,
            withIntermediateDirectories: true
        )
        let scenarioURL = service.scenarioCheckpointURL(
            seed: state.seed,
            id: "industrial-expansion-chosen"
        )
        try Data("conflicting milestone".utf8).write(to: scenarioURL, options: .atomic)
        let store = CityGameStore(
            state: state,
            saveService: service,
            capturesScenarioCheckpoints: true
        )
        store.setSpeed(.normal)

        store.pulse()

        XCTAssertEqual(store.state.status, .lost)
        XCTAssertTrue(service.autosaveURLs.contains {
            FileManager.default.fileExists(atPath: $0.path)
        })
        XCTAssertEqual(store.persistenceStatus.label, "Autosaved")
        XCTAssertTrue(store.lastFeedback?.hasPrefix("Scenario checkpoint failed") == true)
        XCTAssertEqual(store.lastFeedbackTone, .caution)
    }

    private func industrialStrategyReadyState(seed: UInt64) -> CityGameState {
        var state = CityGameState.newCity(seed: seed)
        state.tick = 3
        let commercialCount = state.tiles.filter { $0.kind == .commercial }.count
        let industrialCount = state.tiles.filter { $0.kind == .industrial }.count
        let required = max(1, commercialCount - industrialCount + 1)
        let emptyIndices = state.tiles.indices.filter { state.tiles[$0].kind == .empty }
        for index in emptyIndices.prefix(required) {
            state.tiles[index].kind = .industrial
            state.tiles[index].level = 1
            state.tiles[index].occupancy = 0
            state.tiles[index].condition = 1
            state.tiles[index].constructionProgress = 1
        }
        return state
    }

    private func temporaryRoot(named name: String) -> URL {
        FileManager.default.temporaryDirectory.appending(
            path: "citysim-scenario-\(name)-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
    }
}
