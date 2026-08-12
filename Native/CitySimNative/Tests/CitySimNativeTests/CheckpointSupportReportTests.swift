import Foundation
import XCTest
@testable import CitySimNative

final class CheckpointSupportReportTests: XCTestCase {
    func testCatalogExplainsUnsupportedFingerprintDigestAndUnreadableFiles() throws {
        let root = temporaryRoot(named: "classification")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let unsupported = try JSONSerialization.data(
            withJSONObject: ["schemaVersion": SaveGameEnvelope.currentSchemaVersion + 4],
            options: [.sortedKeys]
        )
        try unsupported.write(to: service.saveURL, options: .atomic)

        var state = CityGameState.newCity(seed: 801)
        state.cityName = "Diagnostic Harbor"
        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        let incompatibleFingerprint = try encodedEnvelope(
            state: state,
            fingerprintVersion: CityStateFingerprint.currentVersion + 2,
            digest: fingerprint.digest
        )
        try incompatibleFingerprint.write(to: service.backupURL, options: .atomic)

        let mismatched = try encodedEnvelope(
            state: state,
            fingerprintVersion: CityStateFingerprint.currentVersion,
            digest: "recorded-digest-does-not-match"
        )
        try mismatched.write(to: service.autosaveURLs[0], options: .atomic)

        try FileManager.default.createDirectory(
            at: service.branchDirectoryURL,
            withIntermediateDirectories: true
        )
        let unreadableURL = service.branchDirectoryURL.appending(path: "branch-unreadable.json")
        let unreadable = Data("not json".utf8)
        try unreadable.write(to: unreadableURL, options: .atomic)

        let catalog = service.checkpointCatalog()
        let byFile = Dictionary(uniqueKeysWithValues: catalog.map { ($0.fileName, $0) })
        XCTAssertEqual(
            byFile[service.saveURL.lastPathComponent]?.issue,
            .unsupportedSchema(
                expected: SaveGameEnvelope.currentSchemaVersion,
                actual: SaveGameEnvelope.currentSchemaVersion + 4
            )
        )
        XCTAssertEqual(
            byFile[service.backupURL.lastPathComponent]?.issue,
            .fingerprintVersionMismatch(
                expected: CityStateFingerprint.currentVersion,
                actual: CityStateFingerprint.currentVersion + 2
            )
        )
        XCTAssertEqual(
            byFile[service.autosaveURLs[0].lastPathComponent]?.issue,
            .integrityMismatch
        )
        XCTAssertEqual(byFile[unreadableURL.lastPathComponent]?.issue, .unreadable)
        XCTAssertTrue(catalog.allSatisfy { !$0.isLoadable && $0.byteCount != nil })
        XCTAssertEqual(try Data(contentsOf: service.saveURL), unsupported)
        XCTAssertEqual(try Data(contentsOf: service.backupURL), incompatibleFingerprint)
        XCTAssertEqual(try Data(contentsOf: service.autosaveURLs[0]), mismatched)
        XCTAssertEqual(try Data(contentsOf: unreadableURL), unreadable)

        let cards = CityCheckpointLibraryPresentation.make(catalog).cards
        XCTAssertTrue(cards.contains {
            $0.title == "Newer Save Version"
                && $0.detail.contains("save format v5")
                && $0.canExportSupportReport
        })
        XCTAssertTrue(cards.contains {
            $0.title == "Incompatible Integrity Version"
                && $0.detail.contains("integrity format v3")
        })
        XCTAssertTrue(cards.contains {
            $0.title == "Integrity Check Failed"
                && $0.detail.contains("integrity fingerprint")
        })
        XCTAssertTrue(cards.contains { $0.title == "Unreadable Recovery File" })
    }

    func testSupportReportIsSanitizedAndLeavesTheRecoveryFileUntouched() throws {
        let root = temporaryRoot(named: "privacy")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let secret = "SECRET-CITY-CONTENT /Users/James/private-city"
        let originalBytes = Data(secret.utf8)
        try originalBytes.write(to: service.autosaveURLs[0], options: .atomic)
        let entry = try XCTUnwrap(service.checkpointCatalog().first)
        let generatedAt = Date(timeIntervalSince1970: 1_720_000_000)

        let reportURL = try service.exportSupportReport(
            for: entry,
            generatedAt: generatedAt
        )

        XCTAssertEqual(reportURL.deletingLastPathComponent(), service.supportReportDirectoryURL)
        XCTAssertTrue(reportURL.lastPathComponent.hasPrefix("save-diagnostic-"))
        XCTAssertEqual(try Data(contentsOf: service.autosaveURLs[0]), originalBytes)
        let reportData = try Data(contentsOf: reportURL)
        let reportText = try XCTUnwrap(String(data: reportData, encoding: .utf8))
        XCTAssertFalse(reportText.contains(secret))
        XCTAssertFalse(reportText.contains(root.path))
        XCTAssertFalse(reportText.contains("private-city"))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(SaveGameSupportReport.self, from: reportData)
        XCTAssertEqual(report.reportVersion, SaveGameSupportReport.currentVersion)
        XCTAssertEqual(report.generatedAt, generatedAt)
        XCTAssertEqual(report.checkpointSource, SaveGameSource.autosave.rawValue)
        XCTAssertEqual(report.checkpointFileName, service.autosaveURLs[0].lastPathComponent)
        XCTAssertEqual(report.checkpointByteCount, originalBytes.count)
        XCTAssertEqual(report.issueCode, "unreadable")
        XCTAssertEqual(report.issueSummary, SaveGameCheckpointIssue.unreadable.explanation)
        XCTAssertNil(report.expectedVersion)
        XCTAssertNil(report.actualVersion)
    }

    func testValidCheckpointCannotProduceAnIntegrityFailureReport() throws {
        let root = temporaryRoot(named: "valid")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        try service.saveAutosave(.newCity(seed: 802))
        let entry = try XCTUnwrap(service.checkpointCatalog().first)

        XCTAssertThrowsError(try service.exportSupportReport(for: entry)) {
            XCTAssertEqual($0 as? SaveGameError, .invalidSupportReportTarget)
        }
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: service.supportReportDirectoryURL.path)
        )
    }

    @MainActor
    func testPlayerExportsFromLibraryWithoutClosingOrChangingTheCity() throws {
        let root = temporaryRoot(named: "store")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let invalidBytes = Data("damaged checkpoint".utf8)
        try invalidBytes.write(to: service.autosaveURLs[0], options: .atomic)
        var current = CityGameState.newCity(seed: 803)
        current.cityName = "Current Harbor"
        current.tick = 36
        var revealed: [URL] = []
        let store = CityGameStore(
            state: current,
            saveService: service,
            revealSupportReport: { revealed.append($0) }
        )
        store.setSpeed(.fastest)

        XCTAssertTrue(store.perform(.loadCity))
        let card = try XCTUnwrap(store.checkpointLibrary?.cards.first)
        XCTAssertEqual(card.title, "Unreadable Recovery File")
        XCTAssertTrue(card.canExportSupportReport)
        XCTAssertTrue(store.exportCheckpointSupportReport(for: card.id))

        XCTAssertEqual(store.commandPolicy, .blocked(.checkpointLibrary))
        XCTAssertNotNil(store.checkpointLibrary)
        XCTAssertEqual(store.state, current)
        XCTAssertEqual(store.speed, .paused)
        XCTAssertEqual(revealed.count, 1)
        let revealedURL = try XCTUnwrap(revealed.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: revealedURL.path))
        XCTAssertEqual(
            store.checkpointSupportFeedback?.isError,
            false
        )
        XCTAssertTrue(
            store.checkpointSupportFeedback?.message.contains("Original recovery file unchanged")
                == true
        )
        XCTAssertEqual(try Data(contentsOf: service.autosaveURLs[0]), invalidBytes)

        XCTAssertTrue(store.cancelCheckpointLibrary())
        XCTAssertEqual(store.speed, .fastest)
        XCTAssertNil(store.checkpointSupportFeedback)
    }

    @MainActor
    func testExportFailureStaysInLibraryAndDoesNotRevealOrMutate() throws {
        let root = temporaryRoot(named: "failure")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let invalidBytes = Data("preserve this".utf8)
        try invalidBytes.write(to: service.autosaveURLs[0], options: .atomic)
        try Data("blocks directory creation".utf8).write(
            to: service.supportReportDirectoryURL,
            options: .atomic
        )
        var revealed = false
        let store = CityGameStore(
            saveService: service,
            revealSupportReport: { _ in revealed = true }
        )

        XCTAssertTrue(store.perform(.loadCity))
        let card = try XCTUnwrap(store.checkpointLibrary?.cards.first)
        XCTAssertFalse(store.exportCheckpointSupportReport(for: card.id))

        XCTAssertFalse(revealed)
        XCTAssertEqual(store.commandPolicy, .blocked(.checkpointLibrary))
        XCTAssertEqual(store.checkpointSupportFeedback?.isError, true)
        XCTAssertTrue(
            store.checkpointSupportFeedback?.message.hasPrefix("Support report failed") == true
        )
        XCTAssertEqual(try Data(contentsOf: service.autosaveURLs[0]), invalidBytes)
    }

    private func encodedEnvelope(
        state: CityGameState,
        fingerprintVersion: Int,
        digest: String
    ) throws -> Data {
        let envelope = SaveGameEnvelope(
            schemaVersion: SaveGameEnvelope.currentSchemaVersion,
            fingerprintVersion: fingerprintVersion,
            state: state,
            digest: digest
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    private func temporaryRoot(named name: String) -> URL {
        FileManager.default.temporaryDirectory.appending(
            path: "citysim-support-report-\(name)-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
    }
}
