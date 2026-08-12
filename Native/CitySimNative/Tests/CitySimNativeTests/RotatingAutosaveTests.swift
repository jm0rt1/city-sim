import Foundation
import XCTest
@testable import CitySimNative

final class RotatingAutosaveTests: XCTestCase {
    func testServiceRotatesThreeVerifiedSlotsAndLoadsNewest() throws {
        let root = temporaryRoot(named: "rotation")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)

        for index in 0..<3 {
            var state = CityGameState.newCity(seed: UInt64(index + 1))
            state.cityName = "Checkpoint \(index + 1)"
            state.tick = (index + 1) * 20
            try service.saveAutosave(state)
        }
        for (index, url) in service.autosaveURLs.enumerated() {
            try setModificationDate(TimeInterval(index + 1), for: url)
        }

        var newest = CityGameState.newCity(seed: 99)
        newest.cityName = "Rotated Harbor"
        newest.tick = 88
        newest.population = 544
        try service.saveAutosave(newest)

        XCTAssertEqual(
            service.autosaveURLs.filter { FileManager.default.fileExists(atPath: $0.path) }.count,
            SaveGameService.autosaveSlotCount
        )
        XCTAssertFalse(service.hasLoadCandidate)
        XCTAssertTrue(service.hasResumeCandidate)
        let loaded = try service.loadLatestResumeCandidate()
        XCTAssertEqual(loaded.state, newest)
        XCTAssertEqual(loaded.source, .autosave)
        XCTAssertEqual(loaded.fingerprint, try CityStateFingerprinter.fingerprint(newest))
    }

    func testNewestCheckpointSelectionComparesManualAndAutosaveDates() throws {
        let root = temporaryRoot(named: "selection")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)

        var manual = CityGameState.newCity(seed: 1)
        manual.cityName = "Manual Harbor"
        try service.save(manual)
        try setModificationDate(1, for: service.saveURL)

        var automatic = CityGameState.newCity(seed: 2)
        automatic.cityName = "Automatic Harbor"
        automatic.tick = 40
        try service.saveAutosave(automatic)
        try setModificationDate(2, for: service.autosaveURLs[0])

        var loaded = try service.loadLatestResumeCandidate()
        XCTAssertEqual(loaded.state, automatic)
        XCTAssertEqual(loaded.source, .autosave)

        var newerManual = CityGameState.newCity(seed: 3)
        newerManual.cityName = "Newest Manual Harbor"
        newerManual.tick = 60
        try service.save(newerManual)
        try setModificationDate(4, for: service.saveURL)
        try setModificationDate(1, for: service.backupURL)
        try setModificationDate(2, for: service.autosaveURLs[0])

        loaded = try service.loadLatestResumeCandidate()
        XCTAssertEqual(loaded.state, newerManual)
        XCTAssertEqual(loaded.source, .primary)
    }

    @MainActor
    func testStoreAutosavesAtIntervalAndResumesThatCheckpointPaused() throws {
        let root = temporaryRoot(named: "store")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        let store = CityGameStore(saveService: service)
        store.state.cityName = "Interval Harbor"
        store.state.tick = CityGameStore.autosaveIntervalTicks - 1
        store.setSpeed(.normal)

        store.pulse()

        XCTAssertEqual(store.state.tick, CityGameStore.autosaveIntervalTicks)
        XCTAssertEqual(store.persistenceStatus.label, "Autosaved")
        XCTAssertFalse(store.hasUnsavedProgress)
        XCTAssertEqual(
            store.lastFeedback,
            "Interval Harbor autosaved · \(store.state.formattedDay) · "
                + "\(store.state.population.formatted()) residents"
        )
        XCTAssertFalse(service.hasLoadCandidate)
        XCTAssertTrue(service.hasResumeCandidate)
        let autosavedState = store.state

        store.state.tick += 1
        XCTAssertEqual(store.persistenceStatus.label, "Unsaved changes")

        let resumed = CityGameStore(saveService: service)
        resumed.load()
        XCTAssertEqual(resumed.state, autosavedState)
        XCTAssertEqual(resumed.speed, .paused)
        XCTAssertEqual(resumed.persistenceStatus.label, "Autosaved")
        XCTAssertEqual(
            resumed.lastFeedback,
            "Interval Harbor resumed from autosave · \(autosavedState.formattedDay) · "
                + "\(autosavedState.population.formatted()) residents · Simulation paused"
        )
    }

    @MainActor
    func testAutosaveFailureKeepsProgressUnsavedAndShowsPersistentWarning() throws {
        let blocker = temporaryRoot(named: "blocked")
        defer { try? FileManager.default.removeItem(at: blocker) }
        try Data("not a directory".utf8).write(to: blocker)
        let service = SaveGameService(rootURL: blocker.appending(path: "saves"))
        let store = CityGameStore(saveService: service)
        store.state.tick = CityGameStore.autosaveIntervalTicks - 1
        store.setSpeed(.normal)

        store.pulse()

        XCTAssertTrue(store.hasUnsavedProgress)
        XCTAssertNotEqual(store.persistenceStatus.label, "Autosaved")
        XCTAssertTrue(store.lastFeedback?.hasPrefix(
            "Autosave failed · Keep playing or save manually:"
        ) == true)
        XCTAssertFalse(service.hasResumeCandidate)
    }

    @MainActor
    func testStartupOfferIdentifiesAndResumesAutosave() throws {
        let root = temporaryRoot(named: "startup")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var saved = CityGameState.newCity(seed: 77)
        saved.cityName = "Night Watch"
        saved.tick = 28
        saved.population = 388
        try service.saveAutosave(saved)
        let store = CityGameStore(saveService: service)

        store.prepareStartupResumeOffer()

        XCTAssertEqual(store.startupResumeOffer?.sourceLabel, "Latest rotating autosave")
        XCTAssertEqual(store.startupResumeOffer?.sourceSymbol, "clock.arrow.circlepath")
        XCTAssertTrue(store.resumeStartupCity())
        XCTAssertEqual(store.state, saved)
        XCTAssertEqual(store.persistenceStatus.label, "Autosaved")
        XCTAssertEqual(store.speed, .paused)
    }

    private func temporaryRoot(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "citysim-autosave-\(name)-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private func setModificationDate(_ offset: TimeInterval, for url: URL) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_700_000_000 + offset)],
            ofItemAtPath: url.path
        )
    }
}
