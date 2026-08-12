import Foundation
import XCTest
@testable import CitySimNative

final class StrategyResolutionPlatformTests: XCTestCase {
    private let resolutions: [CityStrategyRecoveryResolution] = [
        .commercialTaxRelief,
        .commercialPublicRealmInvestment,
        .industrialUtilityExpansion,
        .industrialGreenBuffer,
    ]

    func testFourResolutionFingerprintsRoundTripAndMeetPersistenceBudgets() throws {
        let expectedDigests: [CityStrategyRecoveryResolution: String] = [
            .commercialTaxRelief: "613780971c7e85bf0a29f74de0181cb935abaca659d340ae692eb7913ea86dec",
            .commercialPublicRealmInvestment: "1e4a84ea324ef21861a42dd395919532f50a83d231dfa047b55e8c5a5a403e78",
            .industrialUtilityExpansion: "ccb2f59677e2b213813540cbb8a4212941179aad185cd539be6f408f3774a7cb",
            .industrialGreenBuffer: "c28a670503a57d91da03e4670c60d4905c48a6a8976cd1b5cde4508a974b6f83",
        ]

        for resolution in resolutions {
            var state = try preparedSetback(for: resolution)
            advanceTicks(128, state: &state)
            let analytics = CityAnalytics(state: state)

            XCTAssertEqual(state.tick, 260, resolution.rawValue)
            XCTAssertEqual(state.progression?.strategy?.currentPhase, .completed, resolution.rawValue)
            XCTAssertEqual(state.progression?.strategy?.recoveryResolution, resolution, resolution.rawValue)
            XCTAssertEqual(analytics.strategyRecoveryResolution, resolution, resolution.rawValue)

            let fingerprintStart = ProcessInfo.processInfo.systemUptime
            let fingerprint = try CityStateFingerprinter.fingerprint(state)
            let fingerprintMilliseconds = elapsedMilliseconds(since: fingerprintStart)
            print("PLAY044_DIGEST resolution=\(resolution.rawValue) digest=\(fingerprint.digest)")
            XCTAssertEqual(fingerprint.version, 1, resolution.rawValue)
            XCTAssertEqual(fingerprint.digest, expectedDigests[resolution], resolution.rawValue)
            XCTAssertEqual(
                Set(try (0..<5).map { _ in try CityStateFingerprinter.fingerprint(state).digest }),
                Set([try XCTUnwrap(expectedDigests[resolution])]),
                resolution.rawValue
            )

            let snapshotStart = ProcessInfo.processInfo.systemUptime
            let snapshot = try CityPresentationSnapshot(state: state)
            let snapshotMilliseconds = elapsedMilliseconds(since: snapshotStart)

            try withTemporaryRoot { root in
                let service = SaveGameService(rootURL: root)
                let saveStart = ProcessInfo.processInfo.systemUptime
                let write = try service.save(state)
                let saveMilliseconds = elapsedMilliseconds(since: saveStart)
                let loadStart = ProcessInfo.processInfo.systemUptime
                let load = try service.load()
                let loadMilliseconds = elapsedMilliseconds(since: loadStart)

                XCTAssertEqual(write.schemaVersion, 1, resolution.rawValue)
                XCTAssertEqual(write.fingerprint, fingerprint, resolution.rawValue)
                XCTAssertEqual(load.schemaVersion, 1, resolution.rawValue)
                XCTAssertEqual(load.state, state, resolution.rawValue)
                XCTAssertEqual(load.fingerprint, fingerprint, resolution.rawValue)
                XCTAssertEqual(load.state.progression?.strategy?.recoveryResolution, resolution)

                let envelope = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: Data(contentsOf: service.saveURL)) as? [String: Any]
                )
                XCTAssertEqual(envelope["schemaVersion"] as? Int, 1, resolution.rawValue)
                let encodedState = try XCTUnwrap(envelope["state"] as? [String: Any])
                let progression = try XCTUnwrap(encodedState["progression"] as? [String: Any])
                let strategy = try XCTUnwrap(progression["strategy"] as? [String: Any])
                XCTAssertEqual(strategy["recoveryResolution"] as? String, resolution.rawValue)

                XCTAssertLessThan(fingerprintMilliseconds, 500, resolution.rawValue)
                XCTAssertLessThan(snapshotMilliseconds, 500, resolution.rawValue)
                XCTAssertLessThan(saveMilliseconds, 1_500, resolution.rawValue)
                XCTAssertLessThan(loadMilliseconds, 1_500, resolution.rawValue)
                XCTAssertLessThan(write.byteCount, 2_000_000, resolution.rawValue)

                print(
                    "CITYSIM_RESOLUTION_PERFORMANCE resolution=\(resolution.rawValue) " +
                    "fingerprint_ms=\(metric(fingerprintMilliseconds)) " +
                    "snapshot_ms=\(metric(snapshotMilliseconds)) " +
                    "save_ms=\(metric(saveMilliseconds)) " +
                    "load_ms=\(metric(loadMilliseconds)) bytes=\(write.byteCount) " +
                    "digest=\(fingerprint.digest)"
                )
            }

            XCTAssertEqual(snapshot.state, state, resolution.rawValue)
            XCTAssertEqual(snapshot.fingerprint, fingerprint, resolution.rawValue)
            XCTAssertEqual(snapshot.analytics.strategyRecoveryResolution, resolution, resolution.rawValue)
        }
    }

    func testMissingResolutionKeyPreservesNilAndVersionOneDigest() throws {
        for strategy in [CityStrategy.commercialStewardship, .industrialExpansion] {
            let state = try strategyAtSetback(strategy)
            let fingerprint = try CityStateFingerprinter.fingerprint(state)
            XCTAssertNil(state.progression?.strategy?.recoveryResolution)
            XCTAssertNil(CityAnalytics(state: state).strategyRecoveryResolution)

            try withTemporaryRoot { root in
                let service = SaveGameService(rootURL: root)
                let write = try service.save(state)
                let envelope = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: Data(contentsOf: service.saveURL)) as? [String: Any]
                )
                let encodedState = try XCTUnwrap(envelope["state"] as? [String: Any])
                let progression = try XCTUnwrap(encodedState["progression"] as? [String: Any])
                let encodedStrategy = try XCTUnwrap(progression["strategy"] as? [String: Any])
                XCTAssertNil(encodedStrategy["recoveryResolution"], strategy.rawValue)

                let load = try service.load()
                XCTAssertEqual(write.schemaVersion, 1, strategy.rawValue)
                XCTAssertEqual(write.fingerprint.version, 1, strategy.rawValue)
                XCTAssertEqual(load.state, state, strategy.rawValue)
                XCTAssertNil(load.state.progression?.strategy?.recoveryResolution, strategy.rawValue)
                XCTAssertEqual(load.fingerprint, fingerprint, strategy.rawValue)
            }
        }
    }

    func testResolvedOutcomesAgreeAcrossSpeedReplayAndSaveResume() throws {
        for resolution in resolutions {
            let firstStart = try preparedSetback(for: resolution)
            let secondStart = try preparedSetback(for: resolution)
            XCTAssertEqual(firstStart, secondStart, resolution.rawValue)

            var uninterrupted = firstStart
            advanceTicks(128, state: &uninterrupted)

            var replay = secondStart
            advanceTicks(128, state: &replay)
            XCTAssertEqual(replay, uninterrupted, resolution.rawValue)
            XCTAssertEqual(
                try CityStateFingerprinter.fingerprint(replay),
                try CityStateFingerprinter.fingerprint(uninterrupted),
                resolution.rawValue
            )

            let grouped = SimulationSpeed.allCases.filter { $0 != .paused }.map { speed in
                var state = firstStart
                var remaining = 128
                while remaining > 0 {
                    let group = min(speed.ticksPerPulse, remaining)
                    advanceTicks(group, state: &state)
                    remaining -= group
                }
                return state
            }
            XCTAssertTrue(grouped.allSatisfy { $0 == uninterrupted }, resolution.rawValue)

            try withTemporaryRoot { root in
                let service = SaveGameService(rootURL: root)
                var resumed = firstStart
                advanceTicks(64, state: &resumed)
                XCTAssertEqual(resumed.progression?.strategy?.recoveryResolution, resolution)
                let write = try service.save(resumed)
                let load = try service.load()
                XCTAssertEqual(load.state, resumed, resolution.rawValue)
                XCTAssertEqual(load.fingerprint, write.fingerprint, resolution.rawValue)
                resumed = load.state
                advanceTicks(64, state: &resumed)
                XCTAssertEqual(resumed, uninterrupted, resolution.rawValue)
            }
        }
    }

    func testCorruptPrimaryRecoversEveryResolvedBackupWithoutMutation() throws {
        for resolution in resolutions {
            try withTemporaryRoot { root in
                let service = SaveGameService(rootURL: root)
                var knownGood = try preparedSetback(for: resolution)
                advanceTicks(64, state: &knownGood)
                var latest = knownGood
                advanceTicks(64, state: &latest)

                try service.save(knownGood)
                try service.save(latest)
                var envelope = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: Data(contentsOf: service.saveURL)) as? [String: Any]
                )
                envelope["digest"] = String(repeating: "0", count: 64)
                let corruptBytes = try JSONSerialization.data(
                    withJSONObject: envelope,
                    options: [.prettyPrinted, .sortedKeys]
                )
                try corruptBytes.write(to: service.saveURL, options: .atomic)

                let load = try service.load()
                XCTAssertTrue(load.recoveredFromBackup, resolution.rawValue)
                XCTAssertEqual(load.source, .backup, resolution.rawValue)
                XCTAssertEqual(load.state, knownGood, resolution.rawValue)
                XCTAssertEqual(load.state.progression?.strategy?.recoveryResolution, resolution)
                XCTAssertEqual(load.fingerprint, try CityStateFingerprinter.fingerprint(knownGood))
                XCTAssertEqual(try Data(contentsOf: service.saveURL), corruptBytes, resolution.rawValue)

                let preserved = try FileManager.default.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: nil
                ).filter { $0.lastPathComponent.hasPrefix("quicksave.corrupt-") }
                XCTAssertEqual(preserved.count, 1, resolution.rawValue)
                XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(preserved.first)), corruptBytes)
            }
        }
    }

    @MainActor
    func testBackupOnlyResolvedOutcomesLoadPausedClearUndoAndContinueExactly() throws {
        for resolution in resolutions {
            var saved = try preparedSetback(for: resolution)
            advanceTicks(64, state: &saved)
            XCTAssertEqual(saved.progression?.strategy?.currentPhase, .recovery)
            XCTAssertEqual(saved.progression?.strategy?.recoveryResolution, resolution)
            let savedFingerprint = try CityStateFingerprinter.fingerprint(saved)

            var uninterrupted = saved
            advanceTicks(64, state: &uninterrupted)

            try withTemporaryRoot { root in
                let service = SaveGameService(rootURL: root)
                let write = try service.save(saved)
                let backupBytes = try Data(contentsOf: service.saveURL)
                try FileManager.default.moveItem(at: service.saveURL, to: service.backupURL)

                let store = CityGameStore(state: .newCity(seed: 42), saveService: service)
                store.selectTool(.commercial)
                store.primaryAction(at: GridCoordinate(x: 4, y: 8))
                XCTAssertTrue(store.canUndo, resolution.rawValue)
                store.speed = .fastest

                XCTAssertTrue(store.canPerform(.loadCity), resolution.rawValue)
                XCTAssertTrue(store.perform(.loadCity), resolution.rawValue)
                XCTAssertEqual(store.state, saved, resolution.rawValue)
                XCTAssertEqual(store.speed, .paused, resolution.rawValue)
                XCTAssertFalse(store.canUndo, resolution.rawValue)
                XCTAssertEqual(
                    store.lastFeedback,
                    "Recovered last known-good city · Simulation paused",
                    resolution.rawValue
                )
                XCTAssertEqual(write.schemaVersion, 1, resolution.rawValue)
                XCTAssertEqual(write.fingerprint, savedFingerprint, resolution.rawValue)
                XCTAssertEqual(
                    try CityStateFingerprinter.fingerprint(store.state),
                    savedFingerprint,
                    resolution.rawValue
                )
                XCTAssertEqual(
                    CityAnalytics(state: store.state).strategyRecoveryResolution,
                    resolution,
                    resolution.rawValue
                )

                let snapshot = try CityPresentationSnapshot(state: store.state)
                XCTAssertEqual(snapshot.state, saved, resolution.rawValue)
                XCTAssertEqual(snapshot.fingerprint, savedFingerprint, resolution.rawValue)
                XCTAssertEqual(
                    snapshot.analytics.strategyRecoveryResolution,
                    resolution,
                    resolution.rawValue
                )

                var continued = store.state
                advanceTicks(64, state: &continued)
                XCTAssertEqual(continued, uninterrupted, resolution.rawValue)
                XCTAssertEqual(
                    try CityStateFingerprinter.fingerprint(continued),
                    try CityStateFingerprinter.fingerprint(uninterrupted),
                    resolution.rawValue
                )
                XCTAssertFalse(FileManager.default.fileExists(atPath: service.saveURL.path))
                XCTAssertEqual(try Data(contentsOf: service.backupURL), backupBytes)
            }
        }
    }

    @MainActor
    func testResolutionUndoAndPresentationSnapshotRemainExact() throws {
        let setback = try strategyAtSetback(.commercialStewardship)
        let beforeInvestment = setback
        let beforeFingerprint = try CityStateFingerprinter.fingerprint(beforeInvestment)
        let store = CityGameStore(state: setback)

        store.selectTool(.park)
        store.primaryAction(at: GridCoordinate(x: 6, y: 8))
        XCTAssertTrue(store.canUndo)
        advanceTicks(64, state: &store.state)
        XCTAssertEqual(
            store.state.progression?.strategy?.recoveryResolution,
            .commercialPublicRealmInvestment
        )

        let snapshot = try CityPresentationSnapshot(state: store.state)
        let snapshotState = snapshot.state
        let snapshotFingerprint = snapshot.fingerprint
        advanceTicks(64, state: &store.state)
        XCTAssertEqual(store.state.progression?.strategy?.currentPhase, .completed)
        XCTAssertEqual(snapshot.state, snapshotState)
        XCTAssertEqual(snapshot.fingerprint, snapshotFingerprint)
        XCTAssertEqual(snapshot.analytics.strategyRecoveryResolution, .commercialPublicRealmInvestment)
        XCTAssertEqual(snapshot.analytics.strategyPhase, .recovery)

        store.undoLastAction()
        XCTAssertEqual(store.state, beforeInvestment)
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), beforeFingerprint)
        XCTAssertNil(store.state.progression?.strategy?.recoveryResolution)
        XCTAssertNil(CityAnalytics(state: store.state).strategyRecoveryResolution)
    }

    private func preparedSetback(
        for resolution: CityStrategyRecoveryResolution
    ) throws -> CityGameState {
        let strategy: CityStrategy = switch resolution {
        case .commercialTaxRelief, .commercialPublicRealmInvestment: .commercialStewardship
        case .industrialUtilityExpansion, .industrialGreenBuffer: .industrialExpansion
        }
        var state = try strategyAtSetback(strategy)
        switch resolution {
        case .commercialTaxRelief:
            try apply(.setTaxRate(0.09), to: &state)
        case .commercialPublicRealmInvestment, .industrialGreenBuffer:
            try apply(.build(kind: .park, coordinate: GridCoordinate(x: 6, y: 8)), to: &state)
        case .industrialUtilityExpansion:
            try apply(.build(kind: .powerPlant, coordinate: GridCoordinate(x: 6, y: 8)), to: &state)
            try apply(.build(kind: .waterTower, coordinate: GridCoordinate(x: 7, y: 8)), to: &state)
        }
        XCTAssertNil(state.progression?.strategy?.recoveryResolution)
        return state
    }

    private func strategyAtSetback(_ strategy: CityStrategy) throws -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        let kind: BuildingKind = strategy == .commercialStewardship ? .commercial : .industrial
        try apply(.build(kind: kind, coordinate: GridCoordinate(x: 4, y: 8)), to: &state)
        try apply(.build(kind: kind, coordinate: GridCoordinate(x: 5, y: 8)), to: &state)
        advanceTicks(4, state: &state)
        XCTAssertEqual(state.progression?.strategy?.committedStrategy, strategy)
        advanceTicks(64, state: &state)
        XCTAssertEqual(state.progression?.strategy?.currentPhase, .complication)
        advanceTicks(64, state: &state)
        XCTAssertEqual(state.progression?.strategy?.currentPhase, .setback)
        XCTAssertEqual(state.tick, 132)
        return state
    }

    private func apply(_ command: CitySimulationCommand, to state: inout CityGameState) throws {
        let result = CitySimulationCommandExecutor.apply(command, to: &state)
        guard result == .applied else {
            XCTFail("Fixture command rejected: \(command) -> \(result)")
            throw FixtureError.commandRejected
        }
    }

    private func advanceTicks(_ count: Int, state: inout CityGameState) {
        for _ in 0..<count { CitySimulation.step(&state) }
    }

    private func withTemporaryRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play044-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func elapsedMilliseconds(since start: TimeInterval) -> Double {
        (ProcessInfo.processInfo.systemUptime - start) * 1_000
    }

    private func metric(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private enum FixtureError: Error {
        case commandRejected
    }
}
