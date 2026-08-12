import XCTest
@testable import CitySimNative

final class CityPersistenceFeedbackTests: XCTestCase {
    func testPersistenceStatusDistinguishesNeverSavedSavedAndNewerChanges() {
        let original = CityGameState.newCity(seed: 42)
        var changed = original
        changed.tick += 1

        XCTAssertEqual(
            CityPersistenceStatusPresentation.make(current: original, lastPersisted: nil),
            CityPersistenceStatusPresentation(
                kind: .notSaved,
                label: "Not saved",
                symbol: "icloud.slash",
                help: "This city has not been saved yet"
            )
        )
        XCTAssertEqual(
            CityPersistenceStatusPresentation.make(current: original, lastPersisted: original),
            CityPersistenceStatusPresentation(
                kind: .saved,
                label: "Saved",
                symbol: "checkmark.circle.fill",
                help: "This city matches its last successful save"
            )
        )
        XCTAssertEqual(
            CityPersistenceStatusPresentation.make(
                current: original,
                lastPersisted: original,
                checkpointKind: .autosave
            ),
            CityPersistenceStatusPresentation(
                kind: .saved,
                label: "Autosaved",
                symbol: "checkmark.icloud.fill",
                help: "This city matches its latest rotating autosave"
            )
        )
        XCTAssertEqual(
            CityPersistenceStatusPresentation.make(current: changed, lastPersisted: original),
            CityPersistenceStatusPresentation(
                kind: .unsavedChanges,
                label: "Unsaved changes",
                symbol: "circle.fill",
                help: "This city has changes newer than its last save"
            )
        )
    }

    func testFeedbackIdentifiesTheExactCityCheckpoint() {
        var state = CityGameState.newCity(seed: 42)
        state.cityName = "Harbor Point"
        state.tick = 44
        state.population = 512

        XCTAssertEqual(
            CityPersistenceFeedbackPresentation.saved(state).message,
            "Harbor Point saved · Day 12 · 512 residents"
        )
        XCTAssertEqual(
            CityPersistenceFeedbackPresentation.autosaved(state).message,
            "Harbor Point autosaved · Day 12 · 512 residents"
        )
        XCTAssertEqual(
            CityPersistenceFeedbackPresentation.loaded(
                state,
                recoveredFromBackup: false
            ).message,
            "Harbor Point loaded · Day 12 · 512 residents · Simulation paused"
        )
        XCTAssertEqual(
            CityPersistenceFeedbackPresentation.loaded(
                state,
                recoveredFromBackup: true
            ).message,
            "Recovered Harbor Point from last known-good save · Day 12 · 512 residents · Simulation paused"
        )
        XCTAssertEqual(
            CityPersistenceFeedbackPresentation.loadedAutosave(state).message,
            "Harbor Point resumed from autosave · Day 12 · 512 residents · Simulation paused"
        )
    }

    @MainActor
    func testSavingThroughTheStorePublishesTheExactCheckpoint() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-persistence-feedback-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        var state = CityGameState.newCity(seed: 7)
        state.cityName = "Harbor Point"
        state.tick = 44
        state.population = 512
        let service = SaveGameService(rootURL: root)
        let store = CityGameStore(state: state, saveService: service)

        store.save()

        XCTAssertEqual(store.lastFeedback, "Harbor Point saved · Day 12 · 512 residents")
        XCTAssertEqual(store.persistenceStatus.label, "Saved")
        XCTAssertTrue(service.hasLoadCandidate)
        XCTAssertEqual(try service.load().state, state)

        store.state.tick += 1
        XCTAssertEqual(store.persistenceStatus.label, "Unsaved changes")

        store.state = state
        XCTAssertEqual(store.persistenceStatus.label, "Saved")
    }

    @MainActor
    func testLoadingEstablishesSavedBaselineAndNewRegionClearsIt() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-persistence-status-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        var saved = CityGameState.newCity(seed: 91)
        saved.cityName = "Saved Harbor"
        saved.tick = 12
        let service = SaveGameService(rootURL: root)
        try service.save(saved)
        let store = CityGameStore(saveService: service)

        XCTAssertEqual(store.persistenceStatus.label, "Not saved")
        store.load()
        XCTAssertEqual(store.state, saved)
        XCTAssertEqual(store.persistenceStatus.label, "Saved")

        store.state.population += 1
        XCTAssertEqual(store.persistenceStatus.label, "Unsaved changes")

        store.newCity()
        XCTAssertEqual(store.persistenceStatus.label, "Not saved")
    }

    @MainActor
    func testFailedSaveDoesNotClaimTheCityWasPersisted() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-persistence-failure-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("not a directory".utf8).write(to: root)
        let service = SaveGameService(rootURL: root.appending(path: "blocked"))
        let store = CityGameStore(saveService: service)

        store.save()

        XCTAssertEqual(store.persistenceStatus.label, "Not saved")
        XCTAssertTrue(store.lastFeedback?.hasPrefix("Save failed") == true)
    }
}
