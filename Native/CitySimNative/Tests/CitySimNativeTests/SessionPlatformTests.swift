import XCTest
@testable import CitySimNative

final class SessionPlatformTests: XCTestCase {
    func testVersionOneFingerprintFixturesAreFrozen() throws {
        let explicitProgression = CityGameState.newCity(seed: 42)
        var legacyNilProgression = explicitProgression
        legacyNilProgression.progression = nil

        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(explicitProgression),
            CityStateFingerprint(digest: "947b383684145d6d18738f313fec4f648861680165134f33b4f65ad42e5c0e3f")
        )
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(legacyNilProgression),
            CityStateFingerprint(digest: "b7608f0aa748f5b40086d59ffeba746908599780f791b6483d6c613e80dedeb5")
        )
    }

    func testVersionOneFingerprintIsRepeatableAndPreservesNilProgressionDistinction() throws {
        let explicitProgression = CityGameState.newCity(seed: 42)
        var legacyNilProgression = explicitProgression
        legacyNilProgression.progression = nil

        let repeated = try (0..<100).map { _ in
            try CityStateFingerprinter.fingerprint(explicitProgression)
        }

        XCTAssertEqual(Set(repeated.map(\.digest)).count, 1)
        XCTAssertNotEqual(
            try CityStateFingerprinter.fingerprint(explicitProgression),
            try CityStateFingerprinter.fingerprint(legacyNilProgression)
        )
    }

    func testFingerprintRejectsUnknownCanonicalVersion() {
        XCTAssertThrowsError(try CityStateFingerprinter.fingerprint(.newCity(seed: 42), version: 2)) { error in
            XCTAssertEqual(error as? CityStateFingerprintError, .unsupportedVersion(2))
        }
    }

    func testSchemaOneSaveRoundTripsExactStateAndDigest() throws {
        try withTemporaryRoot { root in
            let service = SaveGameService(rootURL: root)
            var state = CityGameState.newCity(seed: 42)
            state.progression = CityProgressionState(
                townCharterQualifyingCycles: 7,
                townCharterAwarded: false
            )

            let write = try service.save(state)
            let load = try service.load()

            XCTAssertEqual(write.schemaVersion, 1)
            XCTAssertEqual(load.schemaVersion, 1)
            XCTAssertEqual(load.source, .primary)
            XCTAssertFalse(load.recoveredFromBackup)
            XCTAssertEqual(load.state, state)
            XCTAssertEqual(load.fingerprint, write.fingerprint)
            XCTAssertEqual(load.fingerprint, try CityStateFingerprinter.fingerprint(state))

            let envelope = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: service.saveURL)) as? [String: Any]
            )
            XCTAssertEqual(Set(envelope.keys), ["digest", "fingerprintVersion", "schemaVersion", "state"])
        }
    }

    func testSchemaZeroBareStatePreservesLegacyNilUntilTickFour() throws {
        try withTemporaryRoot { root in
            let service = SaveGameService(rootURL: root)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var legacy = CityGameState.newCity(seed: 42)
            legacy.progression = nil
            try JSONEncoder().encode(legacy).write(to: service.saveURL, options: .atomic)

            let load = try service.load()
            XCTAssertEqual(load.schemaVersion, 0)
            XCTAssertNil(load.state.progression)

            var resumed = load.state
            for expectedTick in 1...3 {
                CitySimulation.step(&resumed)
                XCTAssertEqual(resumed.tick, expectedTick)
                XCTAssertNil(resumed.progression)
            }
            CitySimulation.step(&resumed)
            XCTAssertEqual(resumed.tick, 4)
            XCTAssertEqual(resumed.progression, CityProgressionState())
        }
    }

    func testDigestMismatchPreservesCorruptPrimaryAndRecoversBackup() throws {
        try withTemporaryRoot { root in
            let service = SaveGameService(rootURL: root)
            let knownGood = CityGameState.newCity(seed: 42)
            var latest = knownGood
            for _ in 0..<8 { CitySimulation.step(&latest) }

            try service.save(knownGood)
            try service.save(latest)
            XCTAssertTrue(FileManager.default.fileExists(atPath: service.backupURL.path))

            var envelope = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: service.saveURL)) as? [String: Any]
            )
            envelope["digest"] = String(repeating: "0", count: 64)
            let corruptBytes = try JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted, .sortedKeys])
            try corruptBytes.write(to: service.saveURL, options: .atomic)

            let load = try service.load()

            XCTAssertTrue(load.recoveredFromBackup)
            XCTAssertEqual(load.source, .backup)
            XCTAssertEqual(load.state, knownGood)
            XCTAssertEqual(try Data(contentsOf: service.saveURL), corruptBytes)

            let preserved = try FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil
            ).filter { $0.lastPathComponent.hasPrefix("quicksave.corrupt-") }
            XCTAssertEqual(preserved.count, 1)
            XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(preserved.first)), corruptBytes)
        }
    }

    func testInterruptedReplacementLeavesKnownGoodPrimaryReadable() throws {
        enum InjectedFailure: Error { case beforeReplace }

        try withTemporaryRoot { root in
            let stableService = SaveGameService(rootURL: root)
            let knownGood = CityGameState.newCity(seed: 42)
            var interruptedState = knownGood
            for _ in 0..<12 { CitySimulation.step(&interruptedState) }
            try stableService.save(knownGood)

            let interruptedService = SaveGameService(
                rootURL: root,
                beforePrimaryReplacement: { throw InjectedFailure.beforeReplace }
            )
            XCTAssertThrowsError(try interruptedService.save(interruptedState))

            let load = try stableService.load()
            XCTAssertEqual(load.source, .primary)
            XCTAssertEqual(load.state, knownGood)
            XCTAssertEqual(load.fingerprint, try CityStateFingerprinter.fingerprint(knownGood))
        }
    }

    func testEnvironmentOverrideKeepsAllSaveArtifactsInsideInjectedRoot() throws {
        try withTemporaryRoot { root in
            let service = SaveGameService(
                environment: [SaveGameService.dataRootEnvironmentKey: root.path]
            )
            try service.save(.newCity(seed: 42))

            XCTAssertEqual(service.rootURL, root.standardizedFileURL)
            XCTAssertEqual(service.saveURL.deletingLastPathComponent(), root.standardizedFileURL)
            XCTAssertTrue(FileManager.default.fileExists(atPath: service.saveURL.path))
        }
    }

    @MainActor
    func testUndoRestoresExactAuthoritativeStateAndFingerprint() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let before = store.state
        let beforeFingerprint = try CityStateFingerprinter.fingerprint(before)

        store.selectTool(.residential)
        store.primaryAction(at: GridCoordinate(x: 8, y: 11))
        XCTAssertNotEqual(try CityStateFingerprinter.fingerprint(store.state), beforeFingerprint)

        store.undoLastAction()
        XCTAssertEqual(store.state, before)
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), beforeFingerprint)
    }

    private func withTemporaryRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play040-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}
