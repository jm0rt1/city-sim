import CryptoKit
import Foundation
import XCTest
@testable import CitySimNative

final class BackupLoadAvailabilityTests: XCTestCase {
    func testAvailabilityAlwaysUsesTwoReadOnlyExistenceProbesWithinBudget() {
        let root = URL(fileURLWithPath: "/private/tmp/citysim-play045-probe-root", isDirectory: true)
        let fileManager = RecordingFileManager()
        let service = SaveGameService(rootURL: root, fileManager: fileManager)

        let scenarios: [(Set<String>, Bool)] = [
            ([], false),
            ([service.saveURL.path], true),
            ([service.backupURL.path], true),
            ([service.saveURL.path, service.backupURL.path], true),
        ]

        for (existingPaths, expected) in scenarios {
            fileManager.existingPaths = existingPaths
            fileManager.requestedPaths.removeAll(keepingCapacity: true)

            var availableCount = 0
            let start = ProcessInfo.processInfo.systemUptime
            for _ in 0..<1_000 where service.hasLoadCandidate {
                availableCount += 1
            }
            let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1_000

            XCTAssertEqual(availableCount, expected ? 1_000 : 0)
            XCTAssertEqual(fileManager.requestedPaths.count, 2_000)
            XCTAssertEqual(
                Array(fileManager.requestedPaths.prefix(2)),
                [service.saveURL.path, service.backupURL.path]
            )
            XCTAssertEqual(
                fileManager.requestedPaths.filter { $0 == service.saveURL.path }.count,
                1_000
            )
            XCTAssertEqual(
                fileManager.requestedPaths.filter { $0 == service.backupURL.path }.count,
                1_000
            )
            XCTAssertLessThan(milliseconds, 100)
            print(
                "PLAY045_AVAILABILITY existing=\(existingPaths.count) " +
                "checks=1000 probes=\(fileManager.requestedPaths.count) " +
                "milliseconds=\(String(format: "%.3f", milliseconds))"
            )
        }
    }

    @MainActor
    func testEmptyAndPrimaryOnlyRootsPreserveExistingCommandBehavior() throws {
        try withTemporaryRoot { root in
            let service = SaveGameService(rootURL: root)
            let emptyStore = CityGameStore(state: .newCity(seed: 7), saveService: service)

            XCTAssertFalse(service.hasLoadCandidate)
            XCTAssertFalse(emptyStore.canPerform(.loadCity))
            XCTAssertEqual(emptyStore.disabledReason(for: .loadCity), "No quicksave is available")

            let saved = CityGameState.newCity(seed: 42)
            let write = try service.save(saved)
            let primaryBytes = try Data(contentsOf: service.saveURL)
            let primaryStore = CityGameStore(state: .newCity(seed: 7), saveService: service)
            primaryStore.speed = .fastest

            XCTAssertTrue(service.hasLoadCandidate)
            XCTAssertTrue(primaryStore.canPerform(.loadCity))
            XCTAssertTrue(primaryStore.perform(.loadCity))
            XCTAssertEqual(primaryStore.state, saved)
            XCTAssertEqual(
                try CityStateFingerprinter.fingerprint(primaryStore.state),
                write.fingerprint
            )
            XCTAssertEqual(primaryStore.speed, .paused)
            XCTAssertFalse(primaryStore.canUndo)
            XCTAssertEqual(
                primaryStore.lastFeedback,
                CityPersistenceFeedbackPresentation.loaded(
                    saved,
                    recoveredFromBackup: false
                ).message
            )
            XCTAssertEqual(try Data(contentsOf: service.saveURL), primaryBytes)
            XCTAssertFalse(FileManager.default.fileExists(atPath: service.backupURL.path))
        }
    }

    @MainActor
    func testAuthenticSchemaZeroAndOneBackupsLoadPausedAndContinueExactly() throws {
        let fixtures: [(name: String, sha256: String, schema: Int, digest: String)] = [
            (
                "strategy-legacy-schema0-v1",
                "28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908",
                0,
                "b7608f0aa748f5b40086d59ffeba746908599780f791b6483d6c613e80dedeb5"
            ),
            (
                "strategy-legacy-schema1-envelope-v1",
                "56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9",
                1,
                "947b383684145d6d18738f313fec4f648861680165134f33b4f65ad42e5c0e3f"
            ),
        ]

        for fixture in fixtures {
            try withTemporaryRoot { root in
                let service = SaveGameService(rootURL: root)
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                let bytes = try fixtureData(named: fixture.name)
                XCTAssertEqual(sha256(bytes), fixture.sha256)
                try bytes.write(to: service.backupURL, options: .atomic)

                let directLoad = try service.load()
                XCTAssertEqual(directLoad.source, .backup)
                XCTAssertEqual(directLoad.schemaVersion, fixture.schema)
                XCTAssertEqual(directLoad.fingerprint.version, 1)
                XCTAssertEqual(directLoad.fingerprint.digest, fixture.digest)

                let store = CityGameStore(state: .newCity(seed: 7), saveService: service)
                store.speed = .fastest
                XCTAssertTrue(store.canPerform(.loadCity), fixture.name)
                XCTAssertTrue(store.perform(.loadCity), fixture.name)
                XCTAssertEqual(store.state, directLoad.state, fixture.name)
                XCTAssertEqual(store.speed, .paused, fixture.name)
                XCTAssertFalse(store.canUndo, fixture.name)
                XCTAssertEqual(
                    store.lastFeedback,
                    CityPersistenceFeedbackPresentation.loaded(
                        directLoad.state,
                        recoveredFromBackup: true
                    ).message,
                    fixture.name
                )
                XCTAssertEqual(
                    try CityStateFingerprinter.fingerprint(store.state).digest,
                    fixture.digest,
                    fixture.name
                )
                XCTAssertFalse(FileManager.default.fileExists(atPath: service.saveURL.path))
                XCTAssertEqual(try Data(contentsOf: service.backupURL), bytes)

                let snapshot = try CityPresentationSnapshot(state: store.state)
                var continued = store.state
                for _ in 0..<4 { CitySimulation.step(&continued) }
                XCTAssertEqual(snapshot.authoritativeTick, 0)
                XCTAssertEqual(snapshot.fingerprint.digest, fixture.digest)
                XCTAssertEqual(snapshot.state, directLoad.state)
                XCTAssertEqual(continued.tick, 4)
                XCTAssertEqual(continued.progression, CityProgressionState())
            }
        }
    }

    @MainActor
    func testInvalidBackupAvailabilityPreservesStateFilesAndPersistentWarning() throws {
        try withTemporaryRoot { root in
            let service = SaveGameService(rootURL: root)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let invalidBytes = Data(#"{"schemaVersion":1,"digest":"invalid"}"#.utf8)
            try invalidBytes.write(to: service.backupURL, options: .atomic)
            let filesBeforeAvailability = try rootFileNames(root)

            XCTAssertTrue(service.hasLoadCandidate)
            XCTAssertEqual(try rootFileNames(root), filesBeforeAvailability)
            XCTAssertEqual(try Data(contentsOf: service.backupURL), invalidBytes)

            let initial = CityGameState.newCity(seed: 7)
            let store = CityGameStore(state: initial, saveService: service)
            XCTAssertTrue(store.canPerform(.loadCity))
            XCTAssertTrue(store.perform(.loadCity))
            XCTAssertEqual(store.state, initial)
            XCTAssertEqual(store.speed, .normal)
            XCTAssertFalse(store.canUndo)
            XCTAssertEqual(
                store.lastFeedback,
                "Quicksave could not be verified · Original save files were preserved"
            )
            XCTAssertEqual(store.lastFeedbackTone, .caution)
            XCTAssertEqual(try Data(contentsOf: service.backupURL), invalidBytes)
            XCTAssertFalse(FileManager.default.fileExists(atPath: service.saveURL.path))

            let preserved = try rootFileNames(root).filter {
                $0.hasPrefix("quicksave.backup.corrupt-")
            }
            XCTAssertEqual(preserved.count, 1)

            RunLoop.main.run(until: Date(timeIntervalSinceNow: 3.3))
            XCTAssertEqual(
                store.lastFeedback,
                "Quicksave could not be verified · Original save files were preserved",
                "Data-integrity warnings must remain until the player dismisses them"
            )
            XCTAssertTrue(store.perform(.dismissFeedback))
            XCTAssertNil(store.lastFeedback)
        }
    }

    @MainActor
    func testSaveFailureKeepsTheLiveCityAndPersistentWarning() throws {
        try withTemporaryRoot { temporaryRoot in
            try FileManager.default.createDirectory(
                at: temporaryRoot,
                withIntermediateDirectories: true
            )
            let blockedRoot = temporaryRoot.appending(path: "not-a-directory")
            try Data("occupied".utf8).write(to: blockedRoot)
            let service = SaveGameService(rootURL: blockedRoot)
            let initial = CityGameState.newCity(seed: 77)
            let store = CityGameStore(state: initial, saveService: service)

            XCTAssertTrue(store.perform(.saveCity))
            XCTAssertEqual(store.state, initial)
            XCTAssertTrue(
                store.lastFeedback?.hasPrefix("Save failed · Your current city is still open:") == true
            )
            XCTAssertEqual(store.lastFeedbackTone, .caution)

            RunLoop.main.run(until: Date(timeIntervalSinceNow: 3.3))
            XCTAssertTrue(
                store.lastFeedback?.hasPrefix("Save failed · Your current city is still open:") == true,
                "Save failures must remain until the player dismisses them"
            )
            XCTAssertTrue(store.perform(.dismissFeedback))
            XCTAssertNil(store.lastFeedback)
        }
    }

    private func withTemporaryRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play045-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
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

    private func rootFileNames(_ root: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ).map(\.lastPathComponent).sorted()
    }
}

private final class RecordingFileManager: FileManager, @unchecked Sendable {
    var existingPaths: Set<String> = []
    var requestedPaths: [String] = []

    override func fileExists(atPath path: String) -> Bool {
        requestedPaths.append(path)
        return existingPaths.contains(path)
    }
}
