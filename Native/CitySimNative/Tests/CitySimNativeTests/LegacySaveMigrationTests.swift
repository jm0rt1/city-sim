import AppKit
import CryptoKit
import Foundation
import SwiftUI
import XCTest
@testable import CitySimNative

final class LegacySaveMigrationTests: XCTestCase {
    func testEveryLegacyCheckpointSourceMigratesOnACopyAndPreservesExactOriginalBytes() throws {
        let legacyBytes = try fixtureData(named: "strategy-legacy-schema0-v1")
        XCTAssertEqual(
            sha256(legacyBytes),
            "28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908"
        )

        for source in [
            SaveGameSource.primary,
            .backup,
            .autosave,
            .branch,
            .scenario,
        ] {
            let root = temporaryRoot(named: source.rawValue)
            defer { try? FileManager.default.removeItem(at: root) }
            let service = SaveGameService(rootURL: root)
            let originalURL = try legacyURL(for: source, service: service)
            try FileManager.default.createDirectory(
                at: originalURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try legacyBytes.write(to: originalURL, options: .atomic)
            let entry = try XCTUnwrap(service.checkpointCatalog().first {
                $0.source == source && $0.fileName == originalURL.lastPathComponent
            })
            let legacy = try XCTUnwrap(entry.loadResult)

            let migration = try service.migrateLegacyCheckpoint(legacy)

            XCTAssertTrue(migration.createdCopy, source.rawValue)
            XCTAssertEqual(migration.originalFileName, originalURL.lastPathComponent)
            XCTAssertEqual(migration.fingerprint, legacy.fingerprint)
            XCTAssertEqual(try Data(contentsOf: originalURL), legacyBytes, source.rawValue)
            let migratedURL = service.migrationDirectoryURL.appending(
                path: migration.migratedFileName
            )
            let migrated = try XCTUnwrap(service.checkpointCatalog().first {
                $0.source == .migration && $0.fileName == migratedURL.lastPathComponent
            }.flatMap(\.loadResult))
            XCTAssertEqual(migrated.schemaVersion, SaveGameEnvelope.currentSchemaVersion)
            XCTAssertEqual(migrated.state, legacy.state)
            XCTAssertEqual(migrated.fingerprint, legacy.fingerprint)
            XCTAssertEqual(migrated.source, .migration)

            let repeated = try service.migrateLegacyCheckpoint(legacy)
            XCTAssertFalse(repeated.createdCopy, source.rawValue)
            XCTAssertEqual(repeated.migratedFileName, migration.migratedFileName)
            XCTAssertEqual(service.migrationURLs.count, 1)
            XCTAssertEqual(service.migrationURLs.first?.lastPathComponent, migratedURL.lastPathComponent)
            XCTAssertEqual(try Data(contentsOf: originalURL), legacyBytes, source.rawValue)

            let latest = try service.loadLatestResumeCandidate()
            XCTAssertEqual(latest.source, .migration)
            XCTAssertEqual(latest.schemaVersion, SaveGameEnvelope.currentSchemaVersion)
            XCTAssertEqual(latest.state, legacy.state)
        }
    }

    @MainActor
    func testPlayerLoadsLegacySavePausedWithExactUpgradeAndPreservationFeedback() throws {
        let root = temporaryRoot(named: "store-success")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let legacyBytes = try fixtureData(named: "strategy-legacy-schema0-v1")
        try legacyBytes.write(to: service.backupURL, options: .atomic)
        let legacy = try service.load()
        let store = CityGameStore(state: .newCity(seed: 904), saveService: service)
        store.setSpeed(.fastest)

        XCTAssertTrue(store.perform(.loadCity))
        let card = try XCTUnwrap(store.checkpointLibrary?.cards.first)
        XCTAssertTrue(card.detail.contains("Legacy save format"))
        XCTAssertTrue(card.detail.contains("preserved v1 upgrade copy"))
        XCTAssertTrue(store.selectCheckpoint(card.id))

        XCTAssertEqual(store.state, legacy.state)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.persistenceStatus.label, "Upgraded")
        XCTAssertEqual(store.lastFeedbackTone, .positive)
        XCTAssertTrue(store.lastFeedback?.hasPrefix("Legacy save upgraded to format v1") == true)
        XCTAssertTrue(store.lastFeedback?.contains("Original quicksave.backup.json preserved") == true)
        XCTAssertTrue(store.lastFeedback?.hasSuffix("Simulation paused") == true)
        XCTAssertEqual(try Data(contentsOf: service.backupURL), legacyBytes)
        XCTAssertEqual(service.migrationURLs.count, 1)

        let currentCopy = try service.loadLatestResumeCandidate()
        XCTAssertEqual(currentCopy.source, .migration)
        XCTAssertEqual(currentCopy.schemaVersion, 1)
        XCTAssertEqual(currentCopy.state, legacy.state)

        store.openCheckpointLibrary()
        XCTAssertEqual(store.checkpointLibrary?.verifiedCount, 2)
        XCTAssertTrue(store.checkpointLibrary?.cards.contains {
            $0.sourceLabel == "Upgraded legacy copy" && $0.detail.contains("Save format v1")
        } == true)
        XCTAssertTrue(store.cancelCheckpointLibrary())
    }

    @MainActor
    func testMigrationWriteFailureLoadsCityButNeverReportsUpgradeSuccess() throws {
        let root = temporaryRoot(named: "store-failure")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let legacyBytes = try fixtureData(named: "strategy-legacy-schema0-v1")
        try legacyBytes.write(to: service.saveURL, options: .atomic)
        try Data("blocks migration directory".utf8).write(
            to: service.migrationDirectoryURL,
            options: .atomic
        )
        let legacy = try service.load()
        let store = CityGameStore(state: .newCity(seed: 905), saveService: service)

        XCTAssertTrue(store.perform(.loadCity))
        let id = try XCTUnwrap(store.checkpointLibrary?.cards.first?.id)
        XCTAssertTrue(store.selectCheckpoint(id))

        XCTAssertEqual(store.state, legacy.state)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(store.persistenceStatus.label, "Saved")
        XCTAssertEqual(store.lastFeedbackTone, .caution)
        XCTAssertTrue(store.lastFeedback?.contains("loaded from legacy save") == true)
        XCTAssertTrue(store.lastFeedback?.contains("Upgrade copy failed") == true)
        XCTAssertTrue(store.lastFeedback?.contains("CitySim did not change quicksave.json") == true)
        XCTAssertFalse(store.lastFeedback?.contains("upgraded to format") == true)
        XCTAssertEqual(try Data(contentsOf: service.saveURL), legacyBytes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.migrationDirectoryURL.path))

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 3.3))
        XCTAssertTrue(store.lastFeedback?.contains("Upgrade copy failed") == true)
    }

    func testCurrentFormatAndDetachedResultsCannotCreateMigrationCopies() throws {
        let root = temporaryRoot(named: "invalid-targets")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        try service.save(.newCity(seed: 906))
        let current = try service.load()
        XCTAssertThrowsError(try service.migrateLegacyCheckpoint(current)) {
            XCTAssertEqual($0 as? SaveGameError, .invalidMigrationTarget)
        }

        let legacyBytes = try fixtureData(named: "strategy-legacy-schema0-v1")
        let detachedState = try JSONDecoder().decode(CityGameState.self, from: legacyBytes)
        let detached = SaveGameLoadResult(
            state: detachedState,
            schemaVersion: 0,
            fingerprint: try CityStateFingerprinter.fingerprint(detachedState),
            source: .primary
        )
        XCTAssertThrowsError(try service.migrateLegacyCheckpoint(detached)) {
            XCTAssertEqual($0 as? SaveGameError, .invalidMigrationTarget)
        }
        XCTAssertTrue(service.migrationURLs.isEmpty)
    }

    func testConflictingMigrationCopyAndLegacyOriginalAreBothLeftUntouched() throws {
        let root = temporaryRoot(named: "conflict")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let legacyBytes = try fixtureData(named: "strategy-legacy-schema0-v1")
        try legacyBytes.write(to: service.saveURL, options: .atomic)
        let legacy = try service.load()
        try FileManager.default.createDirectory(
            at: service.migrationDirectoryURL,
            withIntermediateDirectories: true
        )
        let conflictURL = service.migrationDirectoryURL.appending(
            path: "migration-\(legacy.fingerprint.digest).json"
        )
        let conflictBytes = Data("not the expected migration".utf8)
        try conflictBytes.write(to: conflictURL, options: .atomic)

        XCTAssertThrowsError(try service.migrateLegacyCheckpoint(legacy)) {
            XCTAssertEqual(
                $0 as? SaveGameError,
                .migrationConflict(conflictURL.lastPathComponent)
            )
        }
        XCTAssertEqual(try Data(contentsOf: service.saveURL), legacyBytes)
        XCTAssertEqual(try Data(contentsOf: conflictURL), conflictBytes)
    }

    func testLegacyStartupOfferPromisesACopyAndNamesThePreservedOriginal() throws {
        let root = temporaryRoot(named: "startup")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try fixtureData(named: "strategy-legacy-schema0-v1").write(
            to: service.saveURL,
            options: .atomic
        )

        let legacy = try service.load()
        let presentation = CityStartupResumePresentation.make(legacy)

        XCTAssertTrue(presentation.detail.contains("verified save-format v1 copy"))
        XCTAssertTrue(presentation.detail.contains("keep quicksave.json unchanged"))
        XCTAssertTrue(presentation.detail.contains("pause the simulation"))
        let replacement = CitySessionReplacementConfirmationPresentation.make(
            state: .newCity(seed: 999),
            action: .loadQuicksave,
            loadResult: legacy
        )
        XCTAssertTrue(replacement.message.contains("create or reuse a verified current-format copy"))
        XCTAssertTrue(replacement.message.contains("leave the legacy file unchanged"))

        _ = try service.migrateLegacyCheckpoint(legacy)
        let migrated = try service.loadLatestResumeCandidate()
        let migratedPresentation = CityStartupResumePresentation.make(migrated)
        XCTAssertEqual(migratedPresentation.sourceLabel, "Upgraded legacy copy")
        XCTAssertTrue(migratedPresentation.detail.contains("original legacy checkpoint remains available"))
        XCTAssertEqual(
            CityPersistenceFeedbackPresentation.loadedMigration(migrated.state).message,
            "Resumed upgraded legacy copy · Day 1 · 300 residents · Simulation paused"
        )
    }

    @MainActor
    func testLegacyAndUpgradedCopiesRenderTogetherAtSupportedWindowSizes() throws {
        let root = temporaryRoot(named: "layout")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try fixtureData(named: "strategy-legacy-schema0-v1").write(
            to: service.backupURL,
            options: .atomic
        )
        let legacy = try service.load()
        let migration = try service.migrateLegacyCheckpoint(legacy)
        let migratedURL = service.migrationDirectoryURL.appending(
            path: migration.migratedFileName
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)],
            ofItemAtPath: service.backupURL.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_700_000_060)],
            ofItemAtPath: migratedURL.path
        )
        let presentation = CityCheckpointLibraryPresentation.make(service.checkpointCatalog())
        XCTAssertEqual(presentation.cards.count, 2)
        XCTAssertEqual(presentation.cards[0].sourceLabel, "Upgraded legacy copy")
        XCTAssertTrue(presentation.cards[0].detail.contains("Save format v1"))
        XCTAssertEqual(presentation.cards[1].sourceLabel, "Known-good backup")
        XCTAssertTrue(presentation.cards[1].detail.contains("preserved v1 upgrade copy"))

        for size in [CGSize(width: 900, height: 600), CGSize(width: 1_280, height: 800)] {
            let image = try bitmap(
                of: CheckpointLibraryView(
                    presentation: presentation,
                    supportFeedback: nil,
                    selectAction: { _ in },
                    branchAction: { _ in },
                    exportSupportReportAction: { _ in },
                    cancelAction: {}
                ).frame(width: size.width, height: size.height),
                size: size
            )
            XCTAssertEqual(image.size.width, size.width, accuracy: 0.5)
            XCTAssertEqual(image.size.height, size.height, accuracy: 0.5)
            if size.width > 1_000,
               let path = ProcessInfo.processInfo.environment["CITYSIM_LEGACY_MIGRATION_PROOF"] {
                let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
    }

    private func legacyURL(for source: SaveGameSource, service: SaveGameService) throws -> URL {
        switch source {
        case .primary:
            service.saveURL
        case .backup:
            service.backupURL
        case .autosave:
            service.autosaveURLs[1]
        case .branch:
            service.branchDirectoryURL.appending(path: "branch-legacy.json")
        case .scenario:
            service.scenarioCheckpointDirectoryURL.appending(path: "scenario-legacy.json")
        case .migration:
            throw SaveGameError.invalidMigrationTarget
        }
    }

    private func fixtureData(named name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func temporaryRoot(named name: String) -> URL {
        FileManager.default.temporaryDirectory.appending(
            path: "citysim-legacy-migration-\(name)-\(UUID().uuidString)",
            directoryHint: .isDirectory
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
