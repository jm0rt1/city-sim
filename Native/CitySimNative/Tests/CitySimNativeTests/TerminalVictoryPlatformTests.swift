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
                "53658735f410722d3b123f2d68bc4d85c4c4ae93847ae213e44577d101ea7b7c",
            .commercialPublicRealmInvestment:
                "157001094cf3fe9209cc47faef265ab627e3833b2a33ff180e0ffc9bb05f8e8f",
            .industrialUtilityExpansion:
                "6c15af94cd9430e78e4fb09894ca4592c322daf90d0622b550b474f379683b34",
            .industrialGreenBuffer:
                "66432973b84648ee55f8051564de8de53180ce48485316117fa34509376e1653",
        ]

        for resolution in resolutions {
            let terminal = try charterCity(resolvedBy: resolution)
            let replay = try charterCity(resolvedBy: resolution)
            let fingerprintStart = ProcessInfo.processInfo.systemUptime
            let fingerprint = try CityStateFingerprinter.fingerprint(terminal)
            let fingerprintMilliseconds = elapsedMilliseconds(since: fingerprintStart)

            XCTAssertEqual(terminal, replay, resolution.rawValue)
            XCTAssertEqual(terminal.tick, 844, resolution.rawValue)
            XCTAssertEqual(terminal.status, .won, resolution.rawValue)
            XCTAssertEqual(terminal.progression?.townCharterQualifyingCycles, 12)
            XCTAssertTrue(terminal.progression?.townCharterAwarded ?? false)
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
                terminal.messages.filter { $0.title == "Town Charter Awarded" }.count,
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
                store.primaryAction(at: GridCoordinate(x: 8, y: 11))
                XCTAssertTrue(store.canUndo, resolution.rawValue)
                store.speed = .fastest
                XCTAssertTrue(store.perform(.loadCity), resolution.rawValue)
                XCTAssertEqual(store.state, terminal, resolution.rawValue)
                XCTAssertEqual(store.speed, .paused, resolution.rawValue)
                XCTAssertFalse(store.canUndo, resolution.rawValue)
                XCTAssertFalse(store.perform(.undo), resolution.rawValue)
                XCTAssertEqual(store.state, terminal, resolution.rawValue)
                XCTAssertEqual(
                    store.lastFeedback,
                    "Recovered last known-good city · Simulation paused",
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
                    "PLAY046_TERMINAL resolution=\(resolution.rawValue) " +
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

    private func charterCity(
        resolvedBy resolution: CityStrategyRecoveryResolution
    ) throws -> CityGameState {
        let strategy: CityStrategy
        let jobs: BuildingKind
        switch resolution {
        case .commercialTaxRelief, .commercialPublicRealmInvestment:
            strategy = .commercialStewardship
            jobs = .commercial
        case .industrialUtilityExpansion, .industrialGreenBuffer:
            strategy = .industrialExpansion
            jobs = .industrial
        }

        var state = CityGameState.newCity(seed: 42)
        try advanceToTick(&state, tick: 60)
        try buildFirstValid(jobs, in: &state)
        try advanceToTick(&state, tick: 64)
        guard state.progression?.strategy?.committedStrategy == strategy else {
            throw FixtureError.unexpectedState
        }
        try advanceThroughStrategyPhase(&state, phase: .opportunity)
        try advanceThroughStrategyPhase(&state, phase: .complication)
        try advanceThroughStrategyPhase(&state, phase: .setback)
        guard state.progression?.strategy?.recoveryResolution == nil else {
            throw FixtureError.unexpectedState
        }

        switch resolution {
        case .commercialTaxRelief:
            state.taxRate = 0.09
        case .commercialPublicRealmInvestment, .industrialGreenBuffer:
            try buildFirstValid(.park, in: &state)
        case .industrialUtilityExpansion:
            try prepareReserveUtilities(in: &state)
        }

        try advanceThroughStrategyPhase(&state, phase: .recovery)
        guard state.progression?.strategy?.recoveryResolution == resolution else {
            throw FixtureError.unexpectedState
        }

        if resolution == .commercialTaxRelief {
            state.taxRate = 0.10
        }
        try prepareCharterCapacity(in: &state, jobs: jobs)
        state.taxRate = 0.10
        try advanceUntil(&state, maximumCycles: 430) {
            $0.progression?.townCharterAwarded == true
        }
        return state
    }

    private func prepareReserveUtilities(in state: inout CityGameState) throws {
        for kind in [BuildingKind.powerPlant, .waterTower] {
            while CityAnalytics(state: state).count(kind) < 2 {
                try advanceUntil(&state, maximumCycles: 160) {
                    $0.treasury >= kind.buildCost
                }
                guard state.status == .playing, state.treasury >= kind.buildCost else {
                    throw FixtureError.unexpectedState
                }
                try buildFirstValid(kind, in: &state)
                advanceOneCycle(&state)
            }
        }
    }

    private func prepareCharterCapacity(
        in state: inout CityGameState,
        jobs: BuildingKind
    ) throws {
        try prepareReserveUtilities(in: &state)
        while CityAnalytics(state: state).jobCapacity < 350 {
            try advanceUntil(&state, maximumCycles: 160) {
                $0.treasury >= jobs.buildCost
            }
            guard state.status == .playing, state.treasury >= jobs.buildCost else {
                throw FixtureError.unexpectedState
            }
            try buildFirstValid(jobs, in: &state)
            advanceOneCycle(&state)
        }
    }

    private func buildFirstValid(
        _ kind: BuildingKind,
        in state: inout CityGameState
    ) throws {
        for tile in state.tiles where tile.kind == .empty {
            if case .success = CitySimulation.validateBuild(kind, at: tile.coordinate, in: state) {
                guard case .success = CitySimulation.build(kind, at: tile.coordinate, in: &state) else {
                    throw FixtureError.commandRejected
                }
                return
            }
        }
        throw FixtureError.commandRejected
    }

    private func advanceThroughStrategyPhase(
        _ state: inout CityGameState,
        phase: CityStrategyPhase
    ) throws {
        guard state.progression?.strategy?.currentPhase == phase,
              let scheduledTick = state.progression?.strategy?.nextScheduledTick else {
            throw FixtureError.unexpectedState
        }
        try advanceToTick(&state, tick: scheduledTick)
    }

    private func advanceToTick(
        _ state: inout CityGameState,
        tick: Int
    ) throws {
        guard state.tick <= tick else { throw FixtureError.unexpectedState }
        while state.tick < tick {
            guard state.status == .playing else { throw FixtureError.unexpectedState }
            CitySimulation.step(&state)
        }
    }

    private func advanceUntil(
        _ state: inout CityGameState,
        maximumCycles: Int,
        condition: (CityGameState) -> Bool
    ) throws {
        for _ in 0..<maximumCycles {
            advanceOneCycle(&state)
            if condition(state) { return }
        }
        throw FixtureError.conditionNotReached
    }

    private func advanceOneCycle(_ state: inout CityGameState) {
        for _ in 0..<4 { CitySimulation.step(&state) }
    }

    private func withTemporaryRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play046-\(UUID().uuidString)", directoryHint: .isDirectory)
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
                  "CITYSIM_PLAY046_EXPORT_ROOT"
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
            "PLAY046_STAGED_EXPORT root=\(rootPath) " +
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
        case conditionNotReached
        case unexpectedState
    }
}
