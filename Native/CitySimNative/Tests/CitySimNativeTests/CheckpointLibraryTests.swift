import AppKit
import Foundation
import SwiftUI
import XCTest
@testable import CitySimNative

final class CheckpointLibraryTests: XCTestCase {
    func testCatalogListsEveryCopyNewestFirstWithoutMutatingInvalidFiles() throws {
        let root = temporaryRoot(named: "catalog")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)

        var backup = CityGameState.newCity(seed: 1)
        backup.cityName = "Old Manual"
        backup.tick = 10
        try service.save(backup)

        var manual = CityGameState.newCity(seed: 2)
        manual.cityName = "Current Manual"
        manual.tick = 20
        try service.save(manual)

        var firstAutosave = CityGameState.newCity(seed: 3)
        firstAutosave.cityName = "Earlier Autosave"
        firstAutosave.tick = 30
        try service.saveAutosave(firstAutosave)

        var newestAutosave = CityGameState.newCity(seed: 4)
        newestAutosave.cityName = "Latest Autosave"
        newestAutosave.tick = 40
        try service.saveAutosave(newestAutosave)

        let invalidBytes = Data("not a city checkpoint".utf8)
        try invalidBytes.write(to: service.autosaveURLs[2], options: .atomic)
        try setModificationDate(1, for: service.backupURL)
        try setModificationDate(2, for: service.autosaveURLs[0])
        try setModificationDate(3, for: service.saveURL)
        try setModificationDate(4, for: service.autosaveURLs[2])
        try setModificationDate(5, for: service.autosaveURLs[1])
        let namesBefore = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()

        let catalog = service.checkpointCatalog()

        XCTAssertEqual(catalog.count, 5)
        XCTAssertEqual(catalog.map(\.loadResult?.state.cityName), [
            "Latest Autosave", nil, "Current Manual", "Earlier Autosave", "Old Manual"
        ])
        XCTAssertEqual(catalog.map(\.source), [.autosave, .autosave, .primary, .autosave, .backup])
        XCTAssertEqual(catalog[1].integrity, .invalid)
        XCTAssertFalse(catalog[1].isLoadable)
        XCTAssertEqual(try Data(contentsOf: service.autosaveURLs[2]), invalidBytes)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: root.path).sorted(),
            namesBefore,
            "Browsing must not rename, repair, or duplicate an invalid recovery copy"
        )

        let presentation = CityCheckpointLibraryPresentation.make(catalog)
        XCTAssertEqual(presentation.verifiedCount, 4)
        XCTAssertEqual(presentation.invalidCount, 1)
        XCTAssertEqual(presentation.cards[0].title, "Latest Autosave")
        XCTAssertEqual(presentation.cards[0].sourceLabel, "Rotating autosave")
        XCTAssertEqual(presentation.cards[0].integrityLabel, "Verified")
        XCTAssertEqual(presentation.cards[1].title, "Recovery File Unavailable")
        XCTAssertEqual(presentation.cards[1].checkpoint, "Unavailable checkpoint")
        XCTAssertTrue(presentation.cards[1].detail.contains("left untouched"))
    }

    @MainActor
    func testProgressedCityChoosesCheckpointBeforeReplacementConfirmation() throws {
        let root = temporaryRoot(named: "selection")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var saved = CityGameState.newCity(seed: 7)
        saved.cityName = "Saved Harbor"
        saved.tick = 24
        try service.save(saved)

        var current = CityGameState.newCity(seed: 8)
        current.cityName = "Live Harbor"
        current.tick = 44
        current.population = 512
        let store = CityGameStore(state: current, saveService: service)
        store.setSpeed(.fastest)
        let currentFingerprint = try CityStateFingerprinter.fingerprint(current)

        XCTAssertTrue(store.perform(.loadCity))
        XCTAssertEqual(store.commandPolicy, .blocked(.checkpointLibrary))
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.checkpointLibrary?.verifiedCount, 1)
        XCTAssertNil(store.sessionReplacementConfirmation)
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), currentFingerprint)

        let checkpointID = try XCTUnwrap(
            store.checkpointLibrary?.cards.first(where: \.isLoadable)?.id
        )
        XCTAssertTrue(store.selectCheckpoint(checkpointID))
        XCTAssertNil(store.checkpointLibrary)
        XCTAssertEqual(store.commandPolicy, .enabled)
        XCTAssertEqual(store.sessionReplacementConfirmation?.title, "Load Saved Harbor?")
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), currentFingerprint)
        XCTAssertEqual(store.speed, .paused)

        XCTAssertTrue(store.cancelSessionReplacement())
        XCTAssertEqual(store.state, current)
        XCTAssertEqual(store.speed, .fastest)

        XCTAssertTrue(store.perform(.loadCity))
        let secondID = try XCTUnwrap(
            store.checkpointLibrary?.cards.first(where: \.isLoadable)?.id
        )
        XCTAssertTrue(store.selectCheckpoint(secondID))
        XCTAssertTrue(store.confirmSessionReplacement())
        XCTAssertEqual(store.state, saved)
        XCTAssertEqual(store.speed, .paused)
    }

    @MainActor
    func testCancelAndInvalidSelectionKeepCurrentCityAndRestoreSpeed() throws {
        let root = temporaryRoot(named: "cancel")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: service.autosaveURLs[0], options: .atomic)
        var current = CityGameState.newCity(seed: 12)
        current.cityName = "Keep Me"
        current.tick = 18
        let store = CityGameStore(state: current, saveService: service)
        store.setSpeed(.fast)

        XCTAssertTrue(store.perform(.loadCity))
        let invalidID = try XCTUnwrap(store.checkpointLibrary?.cards.first?.id)
        XCTAssertEqual(store.checkpointLibrary?.invalidCount, 1)
        XCTAssertFalse(store.selectCheckpoint(invalidID))
        XCTAssertEqual(store.commandPolicy, .blocked(.checkpointLibrary))
        XCTAssertEqual(store.state, current)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertNil(store.checkpointLibrary)
        XCTAssertEqual(store.commandPolicy, .enabled)
        XCTAssertEqual(store.state, current)
        XCTAssertEqual(store.speed, .fast)
        XCTAssertEqual(store.lastFeedback, "Keep Me kept · No checkpoint loaded")
    }

    @MainActor
    func testPristineCityLoadsSelectedCheckpointDirectlyAndPaused() throws {
        let root = temporaryRoot(named: "pristine")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        var saved = CityGameState.newCity(seed: 22)
        saved.cityName = "Direct Harbor"
        saved.tick = 16
        try service.saveAutosave(saved)
        let store = CityGameStore(state: .newCity(seed: 44), saveService: service)

        XCTAssertTrue(store.perform(.loadCity))
        let id = try XCTUnwrap(store.checkpointLibrary?.cards.first(where: \.isLoadable)?.id)
        XCTAssertTrue(store.selectCheckpoint(id))

        XCTAssertNil(store.sessionReplacementConfirmation)
        XCTAssertNil(store.checkpointLibrary)
        XCTAssertEqual(store.state, saved)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.persistenceStatus.label, "Autosaved")
    }

    @MainActor
    func testCheckpointLibraryRendersAtCompactAndDefaultWindowSizes() throws {
        let root = temporaryRoot(named: "layout")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        for index in 0..<3 {
            var state = CityGameState.newCity(seed: UInt64(index + 50))
            state.cityName = "Harbor Checkpoint \(index + 1)"
            state.tick = 20 * (index + 1)
            try service.saveAutosave(state)
        }
        try Data("invalid".utf8).write(to: service.saveURL, options: .atomic)
        let presentation = CityCheckpointLibraryPresentation.make(service.checkpointCatalog())

        for size in [CGSize(width: 900, height: 600), CGSize(width: 1_278, height: 768)] {
            let image = try bitmap(
                of: CheckpointLibraryView(
                    presentation: presentation,
                    selectAction: { _ in },
                    cancelAction: {}
                ).frame(width: size.width, height: size.height),
                size: size
            )
            XCTAssertEqual(image.size.width, size.width, accuracy: 0.5)
            XCTAssertEqual(image.size.height, size.height, accuracy: 0.5)
            if size.width > 1_000,
               let path = ProcessInfo.processInfo.environment["CITYSIM_CHECKPOINT_LIBRARY_PROOF"] {
                let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
    }

    private func temporaryRoot(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "citysim-checkpoints-\(name)-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private func setModificationDate(_ offset: TimeInterval, for url: URL) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_700_000_000 + offset)],
            ofItemAtPath: url.path
        )
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
