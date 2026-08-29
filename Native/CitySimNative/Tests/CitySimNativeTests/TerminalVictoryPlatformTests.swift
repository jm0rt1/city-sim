import Foundation
import XCTest
@testable import CitySimNative

final class TerminalVictoryPlatformTests: XCTestCase {
    private let resolutions: [CityStrategyRecoveryResolution] = [
        .commercialTaxRelief,
        .commercialPublicRealmInvestment,
        .industrialUtilityExpansion,
        .industrialGreenBuffer,
    ]

    @MainActor
    func testFourTerminalRoutesFreezeCommandsPersistenceBackupUndoAndSnapshots() throws {
        let expectedDigests: [CityStrategyRecoveryResolution: String] = [
            .commercialTaxRelief:
                "62276e05fbac97fe8090c4ebf5b4d58812433f1aa9723036d5857bf6844bc62a",
            .commercialPublicRealmInvestment:
                "abba22582caad1682dbdaef25a0560d76ff5de60b11eda6316b3006ceaa49423",
            .industrialUtilityExpansion:
                "c92a70627a66b63131e50b342bc3ba022870790c3e5fd04015e48f0cc125bfb4",
            .industrialGreenBuffer:
                "297ac66dedc8c9f1b4dec0cb1aed1e652328027299d09cfd213633cd11ee8619",
        ]
        let expectedTicks: [CityStrategyRecoveryResolution: Int] = [
            .commercialTaxRelief: 1_024,
            .commercialPublicRealmInvestment: 1_024,
            .industrialUtilityExpansion: 1_064,
            .industrialGreenBuffer: 1_040,
        ]
        let builder = ProductionStoryStateBuilder()

        for resolution in resolutions {
            let recovery = try builder.regionalRecovery(resolvedBy: resolution)
            let groupedRecoveryStates = [1, 2, 4].map { pulse in
                var grouped = recovery
                var remaining = 64
                while remaining > 0 {
                    let group = min(pulse, remaining)
                    for _ in 0..<group { CitySimulation.step(&grouped) }
                    remaining -= group
                }
                return grouped
            }
            XCTAssertEqual(groupedRecoveryStates[0], groupedRecoveryStates[1])
            XCTAssertEqual(groupedRecoveryStates[1], groupedRecoveryStates[2])
            XCTAssertEqual(
                try CityStateFingerprinter.fingerprint(groupedRecoveryStates[0]),
                try CityStateFingerprinter.fingerprint(groupedRecoveryStates[2]),
                resolution.rawValue
            )
            let recoveryStore = CityGameStore(state: recovery)
            let recoveryFingerprint = try CityStateFingerprinter.fingerprint(recovery)
            let (undoKind, undoCoordinate) = try undoableBuild(in: recovery)
            recoveryStore.selectTool(undoKind)
            recoveryStore.primaryAction(at: undoCoordinate)
            XCTAssertTrue(recoveryStore.canUndo, resolution.rawValue)
            XCTAssertNotEqual(recoveryStore.state, recovery, resolution.rawValue)
            recoveryStore.undoLastAction()
            XCTAssertEqual(recoveryStore.state, recovery, resolution.rawValue)
            XCTAssertEqual(
                try CityStateFingerprinter.fingerprint(recoveryStore.state),
                recoveryFingerprint,
                resolution.rawValue
            )
            XCTAssertEqual(
                recoveryStore.state.progression?.secondAct?.phase,
                .recovery,
                resolution.rawValue
            )

            let terminal = try builder.regionalCapitalTerminal(resolvedBy: resolution)
            let replay = try builder.regionalCapitalTerminal(resolvedBy: resolution)
            let fingerprintStart = ProcessInfo.processInfo.systemUptime
            let fingerprint = try CityStateFingerprinter.fingerprint(terminal)
            let fingerprintMilliseconds = elapsedMilliseconds(since: fingerprintStart)

            XCTAssertEqual(terminal, replay, resolution.rawValue)
            XCTAssertEqual(terminal.tick, expectedTicks[resolution], resolution.rawValue)
            XCTAssertEqual(terminal.status, .won, resolution.rawValue)
            XCTAssertEqual(terminal.progression?.townCharterQualifyingCycles, 12)
            XCTAssertTrue(terminal.progression?.townCharterAwarded ?? false)
            XCTAssertEqual(terminal.progression?.secondAct?.phase, .completed)
            XCTAssertEqual(terminal.progression?.secondAct?.qualifyingCycles, 12)
            XCTAssertTrue(terminal.progression?.secondAct?.regionalCapitalAwarded ?? false)
            XCTAssertEqual(
                terminal.progression?.strategy?.recoveryResolution,
                resolution,
                resolution.rawValue
            )
            XCTAssertEqual(
                CityAnalytics(state: terminal).strategyRecoveryResolution,
                resolution,
                resolution.rawValue
            )
            XCTAssertEqual(
                terminal.messages.filter { $0.title == "Regional Capital Recognized" }.count,
                1,
                resolution.rawValue
            )
            XCTAssertEqual(
                try CityStateFingerprinter.fingerprint(replay),
                fingerprint,
                resolution.rawValue
            )
            XCTAssertEqual(
                fingerprint.digest,
                expectedDigests[resolution],
                resolution.rawValue
            )
            XCTAssertEqual(
                Set(try (0..<5).map { _ in
                    try CityStateFingerprinter.fingerprint(terminal).digest
                }),
                Set([try XCTUnwrap(expectedDigests[resolution])]),
                resolution.rawValue
            )
            try exportTerminalSaveIfRequested(
                terminal,
                fingerprint: fingerprint,
                resolution: resolution
            )

            let terminalCommands: [CitySimulationCommand] = [
                .advanceOneDailyBoundary,
                .setTaxRate(0.04),
                .build(kind: .road, coordinate: GridCoordinate(x: 0, y: 0)),
                .demolish(coordinate: GridCoordinate(x: 11, y: 11)),
            ]
            for command in terminalCommands {
                var attempted = terminal
                XCTAssertEqual(
                    CitySimulationCommandExecutor.apply(command, to: &attempted),
                    .rejected(.simulationNotPlaying),
                    "\(resolution.rawValue): \(command)"
                )
                XCTAssertEqual(attempted, terminal, "\(resolution.rawValue): \(command)")
            }

            var stepped = terminal
            for _ in 0..<128 { CitySimulation.step(&stepped) }
            XCTAssertEqual(stepped, terminal, resolution.rawValue)

            let snapshotStart = ProcessInfo.processInfo.systemUptime
            let snapshot = try CityPresentationSnapshot(state: terminal)
            let snapshotMilliseconds = elapsedMilliseconds(since: snapshotStart)
            XCTAssertEqual(snapshot.state, terminal, resolution.rawValue)
            XCTAssertEqual(snapshot.fingerprint, fingerprint, resolution.rawValue)
            XCTAssertEqual(
                snapshot.analytics.strategyRecoveryResolution,
                resolution,
                resolution.rawValue
            )

            try withTemporaryRoot { root in
                let service = SaveGameService(rootURL: root)
                let saveStart = ProcessInfo.processInfo.systemUptime
                let write = try service.save(terminal)
                let saveMilliseconds = elapsedMilliseconds(since: saveStart)
                let loadStart = ProcessInfo.processInfo.systemUptime
                let primaryLoad = try service.load()
                let loadMilliseconds = elapsedMilliseconds(since: loadStart)

                XCTAssertEqual(write.schemaVersion, 1, resolution.rawValue)
                XCTAssertEqual(write.fingerprint, fingerprint, resolution.rawValue)
                XCTAssertEqual(primaryLoad.schemaVersion, 1, resolution.rawValue)
                XCTAssertEqual(primaryLoad.source, .primary, resolution.rawValue)
                XCTAssertEqual(primaryLoad.state, terminal, resolution.rawValue)
                XCTAssertEqual(primaryLoad.fingerprint, fingerprint, resolution.rawValue)

                try service.save(terminal)
                var corruptEnvelope = try XCTUnwrap(
                    JSONSerialization.jsonObject(
                        with: Data(contentsOf: service.saveURL)
                    ) as? [String: Any]
                )
                corruptEnvelope["digest"] = String(repeating: "0", count: 64)
                let corruptBytes = try JSONSerialization.data(
                    withJSONObject: corruptEnvelope,
                    options: [.prettyPrinted, .sortedKeys]
                )
                try corruptBytes.write(to: service.saveURL, options: .atomic)

                let store = CityGameStore(state: .newCity(seed: 42), saveService: service)
                store.selectTool(.commercial)
                store.primaryAction(at: GridCoordinate(x: 4, y: 8))
                XCTAssertTrue(store.canUndo, resolution.rawValue)
                store.speed = .fastest
                XCTAssertTrue(store.perform(.loadCity), resolution.rawValue)
                try store.selectNewestCheckpointForTesting()
                XCTAssertEqual(
                    store.sessionReplacementConfirmation?.action,
                    .loadQuicksave,
                    resolution.rawValue
                )
                XCTAssertTrue(store.confirmSessionReplacement(), resolution.rawValue)
                XCTAssertEqual(store.state, terminal, resolution.rawValue)
                XCTAssertEqual(store.speed, .paused, resolution.rawValue)
                XCTAssertFalse(store.canUndo, resolution.rawValue)
                XCTAssertFalse(store.perform(.undo), resolution.rawValue)
                XCTAssertEqual(store.state, terminal, resolution.rawValue)
                XCTAssertEqual(
                    store.lastFeedback,
                    CityPersistenceFeedbackPresentation.loaded(
                        terminal,
                        recoveredFromBackup: true
                    ).message,
                    resolution.rawValue
                )
                XCTAssertEqual(
                    try CityPresentationSnapshot(state: store.state),
                    snapshot,
                    resolution.rawValue
                )
                XCTAssertEqual(try Data(contentsOf: service.saveURL), corruptBytes)

                XCTAssertEqual(fingerprint.version, 1, resolution.rawValue)
                XCTAssertLessThan(fingerprintMilliseconds, 500, resolution.rawValue)
                XCTAssertLessThan(snapshotMilliseconds, 500, resolution.rawValue)
                XCTAssertLessThan(saveMilliseconds, 1_500, resolution.rawValue)
                XCTAssertLessThan(loadMilliseconds, 1_500, resolution.rawValue)
                XCTAssertLessThan(write.byteCount, 2_000_000, resolution.rawValue)

                print(
                    "PLAY069_TERMINAL resolution=\(resolution.rawValue) tick=\(terminal.tick) " +
                    "digest=\(fingerprint.digest) bytes=\(write.byteCount) " +
                    "fingerprint_ms=\(metric(fingerprintMilliseconds)) " +
                    "snapshot_ms=\(metric(snapshotMilliseconds)) " +
                    "save_ms=\(metric(saveMilliseconds)) " +
                    "load_ms=\(metric(loadMilliseconds))"
                )
            }
        }
    }

    func testLegacyAwardedPlayingSchemaZeroAndOneNormalizeOnlyAfterLoadedBoundary() throws {
        var legacy = CityGameState.newCity(seed: 42)
        legacy.progression = CityProgressionState(
            townCharterQualifyingCycles: 12,
            townCharterAwarded: true
        )
        legacy.messages.insert(
            CityMessage(
                tick: legacy.tick,
                severity: .good,
                title: "Town Charter Awarded",
                detail: "Existing legacy award"
            ),
            at: 0
        )
        let legacyFingerprint = try CityStateFingerprinter.fingerprint(legacy)

        for schema in [0, 1] {
            try withTemporaryRoot { root in
                let service = SaveGameService(rootURL: root)
                if schema == 0 {
                    try FileManager.default.createDirectory(
                        at: root,
                        withIntermediateDirectories: true
                    )
                    try JSONEncoder().encode(legacy).write(to: service.saveURL, options: .atomic)
                } else {
                    try service.save(legacy)
                }
                let originalBytes = try Data(contentsOf: service.saveURL)

                let load = try service.load()
                XCTAssertEqual(load.schemaVersion, schema)
                XCTAssertEqual(load.state, legacy)
                XCTAssertEqual(load.state.status, .playing)
                XCTAssertEqual(load.fingerprint, legacyFingerprint)
                XCTAssertEqual(try Data(contentsOf: service.saveURL), originalBytes)

                let preBoundarySnapshot = try CityPresentationSnapshot(state: load.state)
                XCTAssertEqual(preBoundarySnapshot.state.status, .playing)
                XCTAssertEqual(preBoundarySnapshot.fingerprint, legacyFingerprint)

                var normalized = load.state
                for expectedTick in 1...3 {
                    CitySimulation.step(&normalized)
                    XCTAssertEqual(normalized.tick, expectedTick)
                    XCTAssertEqual(normalized.status, .playing)
                    XCTAssertEqual(
                        normalized.messages.filter { $0.title == "Town Charter Awarded" }.count,
                        1
                    )
                }
                CitySimulation.step(&normalized)
                XCTAssertEqual(normalized.tick, 4)
                XCTAssertEqual(normalized.status, .won)
                XCTAssertEqual(normalized.progression?.townCharterQualifyingCycles, 12)
                XCTAssertTrue(normalized.progression?.townCharterAwarded ?? false)
                XCTAssertEqual(
                    normalized.messages.filter { $0.title == "Town Charter Awarded" }.count,
                    1
                )

                var replay = load.state
                for _ in 0..<4 { CitySimulation.step(&replay) }
                XCTAssertEqual(replay, normalized)
                XCTAssertEqual(
                    try CityStateFingerprinter.fingerprint(replay),
                    try CityStateFingerprinter.fingerprint(normalized)
                )

                let normalizedWrite = try service.save(normalized)
                let normalizedLoad = try service.load()
                XCTAssertEqual(normalizedWrite.schemaVersion, 1)
                XCTAssertEqual(normalizedWrite.fingerprint.version, 1)
                XCTAssertEqual(normalizedLoad.state, normalized)
                XCTAssertEqual(normalizedLoad.state.status, .won)
                XCTAssertEqual(normalizedLoad.fingerprint, normalizedWrite.fingerprint)
            }
        }
    }

    private func undoableBuild(
        in state: CityGameState
    ) throws -> (BuildingKind, GridCoordinate) {
        for kind in [
            BuildingKind.road,
            .commercial,
            .industrial,
            .residential,
            .park,
        ] where state.treasury >= kind.buildCost {
            for tile in state.tiles where tile.kind == .empty {
                if case .success = CitySimulation.validateBuild(
                    kind,
                    at: tile.coordinate,
                    in: state
                ) {
                    return (kind, tile.coordinate)
                }
            }
        }
        throw FixtureError.commandRejected
    }

    private func withTemporaryRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play069-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func exportTerminalSaveIfRequested(
        _ state: CityGameState,
        fingerprint: CityStateFingerprint,
        resolution: CityStrategyRecoveryResolution
    ) throws {
        guard resolution == .commercialTaxRelief,
              let rootPath = ProcessInfo.processInfo.environment[
                  "CITYSIM_PLAY069_EXPORT_ROOT"
              ],
              !rootPath.isEmpty else {
            return
        }

        let service = SaveGameService(
            rootURL: URL(filePath: rootPath, directoryHint: .isDirectory)
        )
        let firstWrite = try service.save(state)
        let secondWrite = try service.save(state)
        XCTAssertEqual(firstWrite.fingerprint, fingerprint)
        XCTAssertEqual(secondWrite.fingerprint, fingerprint)
        XCTAssertEqual(
            try Data(contentsOf: service.saveURL),
            try Data(contentsOf: service.backupURL)
        )
        print(
            "PLAY069_STAGED_EXPORT root=\(rootPath) " +
            "resolution=\(resolution.rawValue) digest=\(fingerprint.digest) " +
            "bytes=\(secondWrite.byteCount)"
        )
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
