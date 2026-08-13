import Foundation
import XCTest
@testable import CitySimNative

@MainActor
final class CitySoundFeedbackTests: XCTestCase {
    func testApprovedConstructionPlaysAfterAuthoritativeStateChangeAtPersistedLevel() throws {
        let defaults = try isolatedDefaults()
        CityPlayerPreferenceSnapshot(
            soundEffects: true,
            effectsVolume: 0.35,
            reduceMotion: false,
            reduceTransparency: false,
            increaseContrast: false,
            differentiateWithoutColor: false
        ).write(to: defaults)
        let player = RecordingCitySoundPlayer()
        let coordinate = GridCoordinate(x: 4, y: 8)
        let store = CityGameStore(
            state: .newCity(seed: 42),
            playerDefaults: defaults,
            soundPlayer: player
        )
        player.onPlay = { cue in
            if cue == .constructionApproved {
                XCTAssertEqual(store.state.tile(at: coordinate)?.kind, .residential)
                XCTAssertEqual(store.lastFeedback, "Residential construction approved")
            }
        }

        store.selectTool(.residential)
        store.primaryAction(at: coordinate)

        XCTAssertEqual(player.events, [RecordedCitySound(cue: .constructionApproved, volume: 0.35)])
    }

    func testRejectedPlacementUsesWarningCueWithoutChangingCity() throws {
        let defaults = try isolatedDefaults()
        let player = RecordingCitySoundPlayer()
        let store = CityGameStore(
            state: .newCity(seed: 42),
            playerDefaults: defaults,
            soundPlayer: player
        )
        let occupied = try XCTUnwrap(store.state.tiles.first { $0.kind != .empty })
        let stateBefore = store.state

        store.selectTool(.commercial)
        store.primaryAction(at: occupied.coordinate)

        XCTAssertEqual(store.state, stateBefore)
        XCTAssertEqual(player.events.map(\.cue), [.actionRejected])
        XCTAssertEqual(store.lastFeedbackTone, .caution)
    }

    func testMutedPreferenceSuppressesCuesWithoutBlockingSuccessfulAction() throws {
        let defaults = try isolatedDefaults()
        CityPlayerPreferenceSnapshot(
            soundEffects: false,
            effectsVolume: 1,
            reduceMotion: false,
            reduceTransparency: false,
            increaseContrast: false,
            differentiateWithoutColor: false
        ).write(to: defaults)
        let player = RecordingCitySoundPlayer()
        let coordinate = GridCoordinate(x: 4, y: 8)
        let store = CityGameStore(
            state: .newCity(seed: 42),
            playerDefaults: defaults,
            soundPlayer: player
        )

        store.selectTool(.residential)
        store.primaryAction(at: coordinate)

        XCTAssertEqual(store.state.tile(at: coordinate)?.kind, .residential)
        XCTAssertTrue(player.events.isEmpty)
    }

    func testSuccessfulAndFailedSavesProduceDistinctPostOutcomeCues() throws {
        let defaults = try isolatedDefaults()
        let successfulPlayer = RecordingCitySoundPlayer()
        let successfulRoot = FileManager.default.temporaryDirectory
            .appending(path: "citysim-sound-save-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: successfulRoot) }
        let successfulStore = CityGameStore(
            saveService: SaveGameService(rootURL: successfulRoot),
            playerDefaults: defaults,
            soundPlayer: successfulPlayer
        )
        successfulPlayer.onPlay = { cue in
            if cue == .persistenceSucceeded {
                XCTAssertEqual(successfulStore.persistenceStatus.label, "Saved")
            }
        }

        XCTAssertTrue(successfulStore.save())
        XCTAssertEqual(successfulPlayer.events.map(\.cue), [.persistenceSucceeded])

        let failedPlayer = RecordingCitySoundPlayer()
        let blocker = FileManager.default.temporaryDirectory
            .appending(path: "citysim-sound-save-blocker-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: blocker) }
        try Data("blocked".utf8).write(to: blocker)
        let failedStore = CityGameStore(
            saveService: SaveGameService(rootURL: blocker.appending(path: "saves")),
            playerDefaults: defaults,
            soundPlayer: failedPlayer
        )

        XCTAssertFalse(failedStore.save())
        XCTAssertEqual(failedPlayer.events.map(\.cue), [.actionRejected])
        XCTAssertEqual(failedStore.persistenceStatus.label, "Not saved")
    }

    func testVerifiedLoadPlaysOnlyAfterLoadedStateBecomesAuthoritative() throws {
        let defaults = try isolatedDefaults()
        let player = RecordingCitySoundPlayer()
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-sound-load-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        var saved = CityGameState.newCity(seed: 99)
        saved.cityName = "Sound Harbor"
        saved.population = 321
        let service = SaveGameService(rootURL: root)
        try service.save(saved)
        let store = CityGameStore(
            saveService: service,
            playerDefaults: defaults,
            soundPlayer: player
        )
        player.onPlay = { cue in
            if cue == .persistenceSucceeded {
                XCTAssertEqual(store.state, saved)
                XCTAssertEqual(store.persistenceStatus.label, "Saved")
            }
        }

        store.load()

        XCTAssertEqual(player.events.map(\.cue), [.persistenceSucceeded])
    }

    func testSimulationTransitionPrioritizesOneCriticalCueOverWarningAndObjective() {
        let beforeObjectives = [objective(id: "budget", progress: 0.9)]
        let afterObjectives = [objective(id: "budget", progress: 1)]
        let afterMessages = [
            CityMessage(tick: 4, severity: .warning, title: "Utility Reserve Tight", detail: "Build reserve."),
            CityMessage(tick: 4, severity: .critical, title: "Utility Shortfall", detail: "Restore service."),
        ]

        XCTAssertEqual(
            CitySimulationSoundTransition.resolve(
                messagesBefore: [],
                messagesAfter: afterMessages,
                objectivesBefore: beforeObjectives,
                objectivesAfter: afterObjectives
            ),
            .criticalAlertRaised
        )
    }

    func testSimulationTransitionEmitsWarningAndObjectiveOnlyWhenNew() {
        let warning = CityMessage(
            tick: 8,
            severity: .warning,
            title: "Hiring Bottleneck",
            detail: "Add jobs."
        )
        XCTAssertEqual(
            CitySimulationSoundTransition.resolve(
                messagesBefore: [],
                messagesAfter: [warning],
                objectivesBefore: [objective(id: "capacity", progress: 0.8)],
                objectivesAfter: [objective(id: "capacity", progress: 0.8)]
            ),
            .warningRaised
        )
        XCTAssertNil(
            CitySimulationSoundTransition.resolve(
                messagesBefore: [warning],
                messagesAfter: [warning],
                objectivesBefore: [objective(id: "capacity", progress: 1)],
                objectivesAfter: [objective(id: "capacity", progress: 1)]
            )
        )
        XCTAssertEqual(
            CitySimulationSoundTransition.resolve(
                messagesBefore: [],
                messagesAfter: [],
                objectivesBefore: [objective(id: "capacity", progress: 0.8)],
                objectivesAfter: [objective(id: "capacity", progress: 1)]
            ),
            .objectiveCompleted
        )
    }

    func testLivePulsePlaysObjectiveCueAfterTownCharterIsAwarded() throws {
        let defaults = try isolatedDefaults()
        let player = RecordingCitySoundPlayer()
        var state = try qualifyingTown()
        state.progression?.townCharterQualifyingCycles = 11
        state.progression?.townCharterAwarded = false
        state.progression?.secondAct = nil
        state.messages.removeAll()
        let store = CityGameStore(
            state: state,
            playerDefaults: defaults,
            soundPlayer: player
        )
        player.onPlay = { cue in
            if cue == .objectiveCompleted {
                XCTAssertTrue(store.state.progression?.townCharterAwarded == true)
                XCTAssertTrue(store.state.messages.contains { $0.title == "Town Charter Awarded" })
            }
        }

        for _ in 0..<4 { store.pulse() }

        XCTAssertEqual(player.events.map(\.cue), [.objectiveCompleted])
    }

    private func objective(id: String, progress: Double) -> CityObjective {
        CityObjective(
            id: id,
            title: id,
            detail: "",
            progress: progress,
            remaining: ""
        )
    }

    private func qualifyingTown() throws -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 50_000
        for kind in [BuildingKind.industrial, .industrial, .powerPlant, .waterTower] {
            let coordinate = try XCTUnwrap(state.tiles.first { tile in
                guard tile.kind == .empty else { return false }
                if case .success = CitySimulation.validateBuild(kind, at: tile.coordinate, in: state) {
                    return true
                }
                return false
            }?.coordinate)
            if case .failure(let rejection) = CitySimulation.build(kind, at: coordinate, in: &state) {
                throw rejection
            }
        }
        state.population = 500
        state.treasury = 50_000
        state.happiness = 60
        for _ in 0..<4 { CitySimulation.step(&state) }
        XCTAssertTrue(CitySimulation.meetsTownCharterStandards(in: state))
        return state
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suite = "CitySoundFeedbackTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        return defaults
    }
}

private struct RecordedCitySound: Equatable {
    let cue: CitySoundCue
    let volume: Float
}

@MainActor
private final class RecordingCitySoundPlayer: CitySoundPlaying {
    var events: [RecordedCitySound] = []
    var onPlay: ((CitySoundCue) -> Void)?

    func play(_ cue: CitySoundCue, volume: Float) {
        events.append(RecordedCitySound(cue: cue, volume: volume))
        onPlay?(cue)
    }
}
