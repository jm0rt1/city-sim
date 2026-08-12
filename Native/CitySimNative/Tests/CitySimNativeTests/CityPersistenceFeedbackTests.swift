import XCTest
@testable import CitySimNative

final class CityPersistenceFeedbackTests: XCTestCase {
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
        XCTAssertTrue(service.hasLoadCandidate)
        XCTAssertEqual(try service.load().state, state)
    }
}
