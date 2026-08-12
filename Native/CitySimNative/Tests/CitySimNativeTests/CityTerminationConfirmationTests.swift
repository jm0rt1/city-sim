import AppKit
import XCTest
@testable import CitySimNative

final class CityTerminationConfirmationTests: XCTestCase {
    func testPresentationIdentifiesTheExactUnsavedCheckpoint() {
        var state = CityGameState.newCity(seed: 42)
        state.cityName = "Harbor Point"
        state.tick = 44
        state.population = 512
        let notSaved = CityPersistenceStatusPresentation.make(current: state, lastPersisted: nil)
        var older = state
        older.tick = 40
        let changed = CityPersistenceStatusPresentation.make(current: state, lastPersisted: older)

        XCTAssertEqual(
            CityTerminationConfirmationPresentation.make(
                state: state,
                persistenceStatus: notSaved
            ),
            CityTerminationConfirmationPresentation(
                title: "Save Harbor Point Before Quitting?",
                message: "Harbor Point · Day 12 · 512 residents has never been saved. "
                    + "Save before quitting to keep this checkpoint.",
                saveActionTitle: "Save and Quit",
                discardActionTitle: "Quit Without Saving",
                cancelActionTitle: "Cancel"
            )
        )
        XCTAssertEqual(
            CityTerminationConfirmationPresentation.make(
                state: state,
                persistenceStatus: changed
            ).message,
            "Harbor Point · Day 12 · 512 residents has changes newer than its last successful save. "
                + "Save before quitting to keep this checkpoint."
        )
    }

    @MainActor
    func testPristineAndExactlySavedCitiesQuitWithoutPrompting() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-termination-saved-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CityGameStore(saveService: SaveGameService(rootURL: root))
        let delegate = CitySimAppDelegate()
        var promptCount = 0
        delegate.terminationConfirmationHandler = { _ in
            promptCount += 1
            return .cancel
        }
        delegate.bind(store: store)

        XCTAssertFalse(store.hasUnsavedProgress)
        XCTAssertEqual(delegate.applicationShouldTerminate(.shared), .terminateNow)
        XCTAssertEqual(promptCount, 0)

        store.state.cityName = "Harbor Point"
        XCTAssertTrue(store.hasUnsavedProgress)
        XCTAssertTrue(store.save())
        XCTAssertFalse(store.hasUnsavedProgress)
        XCTAssertEqual(delegate.applicationShouldTerminate(.shared), .terminateNow)
        XCTAssertEqual(promptCount, 0)
    }

    @MainActor
    func testCancelKeepsTheUnsavedCityAndRestoresSimulationSpeed() {
        var state = CityGameState.newCity(seed: 42)
        state.cityName = "Harbor Point"
        state.tick = 44
        state.population = 512
        let store = CityGameStore(state: state)
        store.setSpeed(.fastest)
        let delegate = CitySimAppDelegate()
        var presented: CityTerminationConfirmationPresentation?
        delegate.terminationConfirmationHandler = {
            presented = $0
            return .cancel
        }
        delegate.bind(store: store)

        XCTAssertEqual(delegate.applicationShouldTerminate(.shared), .terminateCancel)

        XCTAssertEqual(presented?.title, "Save Harbor Point Before Quitting?")
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(store.speed, .fastest)
        XCTAssertTrue(store.hasUnsavedProgress)
    }

    @MainActor
    func testSaveAndQuitPersistsTheExactCityBeforeTerminating() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-termination-save-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var state = CityGameState.newCity(seed: 91)
        state.cityName = "Saved Harbor"
        state.tick = 20
        let store = CityGameStore(state: state, saveService: service)
        store.setSpeed(.fast)
        let delegate = CitySimAppDelegate()
        delegate.terminationConfirmationHandler = { _ in .saveAndQuit }
        delegate.bind(store: store)

        XCTAssertEqual(delegate.applicationShouldTerminate(.shared), .terminateNow)

        XCTAssertEqual(try service.load().state, state)
        XCTAssertEqual(store.persistenceStatus.kind, .saved)
        XCTAssertEqual(store.speed, .paused)
    }

    @MainActor
    func testFailedSaveCancelsQuitAndRestoresSimulationSpeed() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-termination-failure-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("not a directory".utf8).write(to: root)
        var state = CityGameState.newCity(seed: 17)
        state.tick = 4
        let store = CityGameStore(
            state: state,
            saveService: SaveGameService(rootURL: root.appending(path: "blocked"))
        )
        store.setSpeed(.fastest)
        let delegate = CitySimAppDelegate()
        delegate.terminationConfirmationHandler = { _ in .saveAndQuit }
        delegate.bind(store: store)

        XCTAssertEqual(delegate.applicationShouldTerminate(.shared), .terminateCancel)

        XCTAssertEqual(store.speed, .fastest)
        XCTAssertTrue(store.hasUnsavedProgress)
        XCTAssertTrue(store.lastFeedback?.hasPrefix("Save failed") == true)
    }

    @MainActor
    func testExplicitQuitWithoutSavingTerminatesWithoutWriting() {
        var state = CityGameState.newCity(seed: 73)
        state.tick = 8
        let store = CityGameStore(state: state)
        store.setSpeed(.fast)
        let delegate = CitySimAppDelegate()
        delegate.terminationConfirmationHandler = { _ in .quitWithoutSaving }
        delegate.bind(store: store)

        XCTAssertEqual(delegate.applicationShouldTerminate(.shared), .terminateNow)
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(store.speed, .paused)
    }
}
