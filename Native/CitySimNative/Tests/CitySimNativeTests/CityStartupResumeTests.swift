import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityStartupResumeTests: XCTestCase {
    func testPresentationIdentifiesPrimaryAndRecoveredCheckpointsExactly() throws {
        var state = CityGameState.newCity(seed: 42)
        state.cityName = "Harbor Point"
        state.tick = 44
        state.population = 512
        let fingerprint = try CityStateFingerprinter.fingerprint(state)

        XCTAssertEqual(
            CityStartupResumePresentation.make(SaveGameLoadResult(
                state: state,
                schemaVersion: 1,
                fingerprint: fingerprint,
                source: .primary
            )),
            CityStartupResumePresentation(
                title: "Resume Harbor Point?",
                checkpoint: "Harbor Point · Day 12 · 512 residents",
                detail: "Continue from this verified quicksave; the simulation will remain paused while you review the city's active pressures.",
                resumeActionTitle: "Resume Harbor Point",
                startFreshActionTitle: "Start Fresh",
                recoveredFromBackup: false
            )
        )
        let recovered = CityStartupResumePresentation.make(SaveGameLoadResult(
            state: state,
            schemaVersion: 1,
            fingerprint: fingerprint,
            source: .backup
        ))
        XCTAssertEqual(recovered.title, "Recover Harbor Point?")
        XCTAssertEqual(recovered.resumeActionTitle, "Recover Harbor Point")
        XCTAssertTrue(recovered.detail.contains("last known-good backup"))
        XCTAssertTrue(recovered.recoveredFromBackup)
    }

    @MainActor
    func testVerifiedSaveOffersExplicitPausedResumeAndLoadsThePreparedState() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-startup-resume-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var saved = CityGameState.newCity(seed: 91)
        saved.cityName = "Saved Harbor"
        saved.tick = 20
        saved.population = 411
        try service.save(saved)
        let store = CityGameStore(saveService: service)
        store.setSpeed(.fastest)

        store.prepareStartupResumeOffer()

        XCTAssertEqual(store.commandPolicy, .blocked(.startupResume))
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.startupResumeOffer?.checkpoint, "Saved Harbor · Day 6 · 411 residents")
        XCTAssertFalse(store.canPerform(.newRegion))
        XCTAssertEqual(
            store.disabledReason(for: .newRegion),
            "Choose whether to resume the saved city or start fresh"
        )
        XCTAssertFalse(store.canRouteMapCommand(.mapMoveEast))
        XCTAssertEqual(store.state, .newCity(seed: store.state.seed))
        let focusGeneration = store.mapFocusRequestGeneration

        XCTAssertTrue(store.resumeStartupCity())
        XCTAssertNil(store.startupResumeOffer)
        XCTAssertEqual(store.commandPolicy, .enabled)
        XCTAssertEqual(store.state, saved)
        XCTAssertEqual(store.persistenceStatus.kind, .saved)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertGreaterThan(store.mapFocusRequestGeneration, focusGeneration)
        XCTAssertEqual(
            store.lastFeedback,
            CityPersistenceFeedbackPresentation.loaded(saved, recoveredFromBackup: false).message
        )
    }

    @MainActor
    func testStartFreshPreservesTheVerifiedSaveAndPriorSimulationSpeed() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-startup-fresh-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var saved = CityGameState.newCity(seed: 17)
        saved.cityName = "Old Harbor"
        saved.tick = 8
        try service.save(saved)
        let store = CityGameStore(saveService: service)
        store.setSpeed(.fast)
        let fresh = store.state

        store.prepareStartupResumeOffer()
        let focusGeneration = store.mapFocusRequestGeneration
        XCTAssertTrue(store.startFreshFromStartupOffer())

        XCTAssertEqual(store.state, fresh)
        XCTAssertEqual(store.speed, .fast)
        XCTAssertEqual(store.commandPolicy, .enabled)
        XCTAssertNil(store.startupResumeOffer)
        XCTAssertGreaterThan(store.mapFocusRequestGeneration, focusGeneration)
        XCTAssertEqual(try service.load().state, saved)
        XCTAssertTrue(store.lastFeedback?.contains("Old Harbor · Day 3") == true)
        XCTAssertTrue(store.lastFeedback?.contains("remains available from Load City") == true)
    }

    @MainActor
    func testCorruptPrimaryOffersAndResumesTheLastKnownGoodBackup() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-startup-backup-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var backup = CityGameState.newCity(seed: 31)
        backup.cityName = "Backup Harbor"
        backup.tick = 12
        try service.save(backup)
        var primary = backup
        primary.cityName = "Primary Harbor"
        primary.tick = 16
        try service.save(primary)
        try Data("corrupt primary".utf8).write(to: service.saveURL)
        let store = CityGameStore(saveService: service)

        store.prepareStartupResumeOffer()

        XCTAssertEqual(store.startupResumeOffer?.title, "Recover Backup Harbor?")
        XCTAssertTrue(store.startupResumeOffer?.recoveredFromBackup == true)
        XCTAssertTrue(store.resumeStartupCity())
        XCTAssertEqual(store.state, backup)
        XCTAssertEqual(store.persistenceStatus.kind, .saved)
        XCTAssertEqual(
            store.lastFeedback,
            CityPersistenceFeedbackPresentation.loaded(backup, recoveredFromBackup: true).message
        )
    }

    @MainActor
    func testInvalidCandidateKeepsFreshCityAndUsesPersistentIntegrityWarning() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-startup-invalid-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let service = SaveGameService(rootURL: root)
        try Data("invalid quicksave".utf8).write(to: service.saveURL)
        let store = CityGameStore(saveService: service)
        let fresh = store.state

        store.prepareStartupResumeOffer()

        XCTAssertNil(store.startupResumeOffer)
        XCTAssertEqual(store.commandPolicy, .enabled)
        XCTAssertEqual(store.state, fresh)
        XCTAssertEqual(
            store.lastFeedback,
            "Quicksave could not be verified · Original save files were preserved"
        )
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).contains {
            $0.hasPrefix("quicksave.corrupt-")
        })
    }

    @MainActor
    func testStartupOfferRendersWithinCompactAndDefaultBounds() throws {
        var state = CityGameState.newCity(seed: 42)
        state.cityName = "Harbor Point"
        state.tick = 44
        state.population = 512
        let presentation = CityStartupResumePresentation.make(SaveGameLoadResult(
            state: state,
            schemaVersion: 1,
            fingerprint: try CityStateFingerprinter.fingerprint(state),
            source: .backup
        ))
        for size in [CGSize(width: 900, height: 600), CGSize(width: 1_278, height: 768)] {
            let image = try bitmap(
                of: StartupResumeView(
                    presentation: presentation,
                    resumeAction: {},
                    startFreshAction: {}
                ).frame(width: size.width, height: size.height),
                size: size
            )
            XCTAssertEqual(image.size.width, size.width, accuracy: 0.5)
            XCTAssertEqual(image.size.height, size.height, accuracy: 0.5)
        }
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
