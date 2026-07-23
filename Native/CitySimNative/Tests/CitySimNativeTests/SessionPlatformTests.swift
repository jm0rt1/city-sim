import CryptoKit
import XCTest
@testable import CitySimNative

final class SessionPlatformTests: XCTestCase {
    private static let play013DenseTerminalFixtureName = "dense-24x24-terminal-wave4-strategy-v5"
    private static let play013DenseTerminalFixtureDigest =
        "149e0da1d33ed30c1077b99d55be875782c14914c21b20cbe50145f9b9473246"

    func testVersionOneFingerprintFixturesAreFrozen() throws {
        let explicitProgression = CityGameState.newCity(seed: 42)
        var legacyNilProgression = explicitProgression
        legacyNilProgression.progression = nil

        XCTAssertTrue(CityAnalytics(state: explicitProgression).awaitingStrategyChoice)

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
            let state = try XCTUnwrap(
                strategyPhaseFixtures(for: .commercialStewardship).first?.1
            )

            let write = try service.save(state)
            let load = try service.load()

            XCTAssertEqual(write.schemaVersion, 1)
            XCTAssertEqual(load.schemaVersion, 1)
            XCTAssertEqual(load.source, .primary)
            XCTAssertFalse(load.recoveredFromBackup)
            XCTAssertEqual(load.state, state)
            XCTAssertEqual(load.state.progression?.strategy?.currentPhase, .opportunity)
            XCTAssertEqual(load.fingerprint, write.fingerprint)
            XCTAssertEqual(load.fingerprint, try CityStateFingerprinter.fingerprint(state))

            let envelope = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: service.saveURL)) as? [String: Any]
            )
            XCTAssertEqual(Set(envelope.keys), ["digest", "fingerprintVersion", "schemaVersion", "state"])
        }
    }

    func testAuthenticPreStrategySaveBytesAndDigestsRemainFrozen() throws {
        let fixtures: [(file: String, sha256: String, schema: Int, digest: String)] = [
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
            )
        ]

        for fixture in fixtures {
            let bytes = try fixtureData(named: fixture.file)
            XCTAssertEqual(sha256(bytes), fixture.sha256, fixture.file)

            try withTemporaryRoot { root in
                let service = SaveGameService(rootURL: root)
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                try bytes.write(to: service.saveURL, options: .atomic)

                let load = try service.load()
                XCTAssertEqual(load.schemaVersion, fixture.schema, fixture.file)
                XCTAssertEqual(load.fingerprint.version, 1, fixture.file)
                XCTAssertEqual(load.fingerprint.digest, fixture.digest, fixture.file)
                XCTAssertNil(load.state.progression?.strategy, fixture.file)

                if fixture.schema == 0 {
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
                } else {
                    XCTAssertEqual(load.state.progression, CityProgressionState())
                }
            }
        }
    }

    func testDigestMismatchPreservesCorruptPrimaryAndRecoversBackup() throws {
        try withTemporaryRoot { root in
            let service = SaveGameService(rootURL: root)
            let phases = try strategyPhaseFixtures(for: .industrialExpansion)
            let knownGood = try XCTUnwrap(phases.first { $0.0 == .setback }?.1)
            let latest = try XCTUnwrap(phases.first { $0.0 == .recovery }?.1)

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
            XCTAssertEqual(load.state.progression?.strategy?.committedStrategy, .industrialExpansion)
            XCTAssertEqual(load.state.progression?.strategy?.currentPhase, .setback)
            XCTAssertEqual(load.fingerprint, try CityStateFingerprinter.fingerprint(knownGood))
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
        let opportunity = try XCTUnwrap(
            strategyPhaseFixtures(for: .commercialStewardship).first?.1
        )
        let store = CityGameStore(state: opportunity)
        let before = store.state
        let beforeFingerprint = try CityStateFingerprinter.fingerprint(before)
        let beforeAnalytics = CityAnalytics(state: before)

        store.selectTool(.residential)
        store.primaryAction(at: GridCoordinate(x: 6, y: 11))
        XCTAssertNotEqual(try CityStateFingerprinter.fingerprint(store.state), beforeFingerprint)

        store.undoLastAction()
        XCTAssertEqual(store.state, before)
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), beforeFingerprint)
        XCTAssertEqual(CityAnalytics(state: store.state).committedStrategy, beforeAnalytics.committedStrategy)
        XCTAssertEqual(CityAnalytics(state: store.state).strategyPhase, beforeAnalytics.strategyPhase)
        XCTAssertEqual(
            CityAnalytics(state: store.state).strategyDaysUntilConsequence,
            beforeAnalytics.strategyDaysUntilConsequence
        )
    }

    func testPresentationSnapshotOwnsAnImmutableAuthoritativeValue() throws {
        var state = try XCTUnwrap(
            strategyPhaseFixtures(for: .industrialExpansion).first?.1
        )
        let snapshot = try CityPresentationSnapshot(state: state)
        let originalTreasury = snapshot.state.treasury
        let originalFingerprint = snapshot.fingerprint

        while state.tick < 68 { CitySimulation.step(&state) }

        XCTAssertEqual(snapshot.authoritativeTick, 4)
        XCTAssertEqual(snapshot.state.treasury, originalTreasury)
        XCTAssertEqual(snapshot.fingerprint, originalFingerprint)
        XCTAssertEqual(snapshot.analytics.projectedBalance, CityAnalytics(state: snapshot.state).projectedBalance)
        XCTAssertEqual(snapshot.analytics.committedStrategy, .industrialExpansion)
        XCTAssertEqual(snapshot.analytics.strategyPhase, .opportunity)
        XCTAssertEqual(snapshot.analytics.strategyDaysUntilConsequence, 16)
        XCTAssertEqual(CityAnalytics(state: state).strategyPhase, .complication)
        XCTAssertNotEqual(try CityStateFingerprinter.fingerprint(state), snapshot.fingerprint)
    }

    func testFixtureCommandsAreTypedBoundedAndCodable() throws {
        let commands: [CitySimulationCommand] = [
            .setTaxRate(0.14),
            .build(kind: .commercial, coordinate: GridCoordinate(x: 8, y: 11)),
            .advanceOneDailyBoundary,
            .demolish(coordinate: GridCoordinate(x: 8, y: 11))
        ]

        let roundTrip = try JSONDecoder().decode(
            [CitySimulationCommand].self,
            from: JSONEncoder().encode(commands)
        )
        XCTAssertEqual(roundTrip, commands)

        var state = CityGameState.newCity(seed: 42)
        for command in commands {
            XCTAssertEqual(CitySimulationCommandExecutor.apply(command, to: &state), .applied)
        }
        XCTAssertEqual(state.tick, 4)
        XCTAssertEqual(state.taxRate, 0.14)
        XCTAssertEqual(state.tile(at: GridCoordinate(x: 8, y: 11))?.kind, .empty)

        XCTAssertEqual(
            CitySimulationCommandExecutor.apply(
                .demolish(coordinate: GridCoordinate(x: 11, y: 11)),
                to: &state
            ),
            .rejected(.demolitionNotAllowed)
        )
    }

    func testEquivalentSpeedGroupingsProduceTheSameLogicalOutcome() throws {
        let commands: [CitySimulationCommand] = [
            .build(kind: .industrial, coordinate: GridCoordinate(x: 8, y: 11)),
            .build(kind: .industrial, coordinate: GridCoordinate(x: 7, y: 11)),
            .advanceOneDailyBoundary
        ]
        var firstReplay = CityGameState.newCity(seed: 42)
        var secondReplay = CityGameState.newCity(seed: 42)
        apply(commands, to: &firstReplay)
        apply(commands, to: &secondReplay)
        XCTAssertEqual(firstReplay, secondReplay)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(firstReplay),
            try CityStateFingerprinter.fingerprint(secondReplay)
        )

        let states = SimulationSpeed.allCases.filter { $0 != .paused }.map { speed in
            var state = firstReplay
            var remaining = 256
            while remaining > 0 {
                let group = min(speed.ticksPerPulse, remaining)
                for _ in 0..<group {
                    CitySimulation.step(&state)
                }
                remaining -= group
            }
            return state
        }

        XCTAssertEqual(states[0], states[1])
        XCTAssertEqual(states[1], states[2])
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(states[0]),
            try CityStateFingerprinter.fingerprint(states[2])
        )
        XCTAssertEqual(states[0].progression?.strategy?.currentPhase, .completed)
    }

    func testUninterruptedReplayAndSaveResumeProduceExactStrategyState() throws {
        let start = try XCTUnwrap(
            strategyPhaseFixtures(for: .commercialStewardship).first?.1
        )
        var uninterrupted = start
        advanceTicks(256, state: &uninterrupted)

        try withTemporaryRoot { root in
            let service = SaveGameService(rootURL: root)
            var resumed = start
            advanceTicks(128, state: &resumed)
            let beforeSave = resumed
            let write = try service.save(resumed)
            let load = try service.load()
            XCTAssertEqual(load.state, beforeSave)
            XCTAssertEqual(load.fingerprint, write.fingerprint)
            resumed = load.state
            advanceTicks(128, state: &resumed)

            XCTAssertEqual(resumed, uninterrupted)
            XCTAssertEqual(
                try CityStateFingerprinter.fingerprint(resumed),
                try CityStateFingerprinter.fingerprint(uninterrupted)
            )
            XCTAssertEqual(resumed.progression?.strategy?.currentPhase, .completed)
        }
    }

    func testAcceptedStrategyCommandsProduceFrozenCheckpoints() throws {
        var industry = CityGameState.newCity(seed: 42)
        apply([
            .build(kind: .industrial, coordinate: GridCoordinate(x: 8, y: 11)),
            .build(kind: .industrial, coordinate: GridCoordinate(x: 7, y: 11))
        ], to: &industry)
        advanceDailyBoundaries(4, state: &industry)
        apply([
            .build(kind: .powerPlant, coordinate: GridCoordinate(x: 6, y: 11)),
            .build(kind: .waterTower, coordinate: GridCoordinate(x: 5, y: 11))
        ], to: &industry)
        advanceDailyBoundaries(220, state: &industry)

        var commerce = CityGameState.newCity(seed: 42)
        apply([
            .setTaxRate(0.14),
            .build(kind: .commercial, coordinate: GridCoordinate(x: 8, y: 11)),
            .build(kind: .commercial, coordinate: GridCoordinate(x: 7, y: 11))
        ], to: &commerce)
        advanceDailyBoundaries(2, state: &commerce)
        apply([
            .build(kind: .powerPlant, coordinate: GridCoordinate(x: 6, y: 11)),
            .build(kind: .waterTower, coordinate: GridCoordinate(x: 5, y: 11))
        ], to: &commerce)
        advanceDailyBoundaries(220, state: &commerce)

        printCheckpoint("accepted-industrial", state: industry)
        printCheckpoint("accepted-commercial", state: commerce)
        XCTAssertEqual(industry.tick, 896)
        XCTAssertEqual(commerce.tick, 888)
        XCTAssertEqual(industry.treasury, 56_433.2, accuracy: 0.001)
        XCTAssertEqual(commerce.treasury, 58_993.26, accuracy: 0.001)
        XCTAssertEqual(CityAnalytics(state: industry).projectedBalance, 310.25, accuracy: 0.001)
        XCTAssertEqual(CityAnalytics(state: commerce).projectedBalance, 403.49, accuracy: 0.001)
        XCTAssertTrue(industry.progression?.townCharterAwarded ?? false)
        XCTAssertTrue(commerce.progression?.townCharterAwarded ?? false)
        XCTAssertTrue(industry.messages.contains { $0.title == "Town Charter Standards" })
        XCTAssertTrue(commerce.messages.contains { $0.title == "Town Charter Standards" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Industrial Load Absorbed" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Load Forecast" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Contract Watch" })
        XCTAssertFalse(industry.messages.contains { $0.title == "Choose a Growth Engine" })
        XCTAssertTrue(commerce.messages.contains { $0.title == "Chain Store Rumor" })
        XCTAssertTrue(commerce.messages.contains { $0.title == "Main Street Crossroads" })
        XCTAssertFalse(commerce.messages.contains { $0.title == "Choose a Growth Engine" })
        XCTAssertEqual(industry.progression?.strategy?.committedStrategy, .industrialExpansion)
        XCTAssertEqual(industry.progression?.strategy?.currentPhase, .completed)
        XCTAssertNil(industry.progression?.strategy?.nextScheduledTick)
        XCTAssertEqual(industry.progression?.strategy?.recoveryResolution, .industrialUtilityExpansion)
        XCTAssertEqual(CityAnalytics(state: industry).strategyRecoveryResolution, .industrialUtilityExpansion)
        XCTAssertEqual(commerce.progression?.strategy?.committedStrategy, .commercialStewardship)
        XCTAssertEqual(commerce.progression?.strategy?.currentPhase, .completed)
        XCTAssertNil(commerce.progression?.strategy?.nextScheduledTick)
        XCTAssertNil(commerce.progression?.strategy?.recoveryResolution)
        XCTAssertNil(CityAnalytics(state: commerce).strategyRecoveryResolution)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(industry).digest,
            "9640c2d5b481e6c257657b3f0a2b7eaf121cb9a44eaba1888b5728a7b83a53be"
        )
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(commerce).digest,
            "d5b58792b70d119acc4a35344e1c1c9f141e56ab6c220a9eec20b860c2e01d18"
        )
        XCTAssertEqual(
            Set(try (0..<5).map { _ in try CityStateFingerprinter.fingerprint(industry).digest }),
            Set(["9640c2d5b481e6c257657b3f0a2b7eaf121cb9a44eaba1888b5728a7b83a53be"])
        )
        XCTAssertEqual(
            Set(try (0..<5).map { _ in try CityStateFingerprinter.fingerprint(commerce).digest }),
            Set(["d5b58792b70d119acc4a35344e1c1c9f141e56ab6c220a9eec20b860c2e01d18"])
        )
    }

    func testStrategyPhaseFingerprintsAreFrozen() throws {
        let expected = [
            "commercialStewardship.opportunity": "2cace0ea8802121aa20b09290467151a41a50febc9f9387d173ac4ebfd87fd63",
            "commercialStewardship.complication": "fee970b179d521b263f0a88931c95afe80d3e270428abf93df0a54eeb63f2cde",
            "commercialStewardship.setback": "c9ccc91744fc55b32bc5d3bd824772e70b7043b3da5d9b72900bc05edcdf771c",
            "commercialStewardship.recovery": "f8d8d1a1ae89ed6ed34b6b0c82ef1e66a00be28676a7de2dfb598b859aaad5a0",
            "commercialStewardship.completed": "550a334c2e8d1692696e63f31c74d0be72906cf1acc648c3f3f6124e456f6232",
            "industrialExpansion.opportunity": "6925de40f282ea591af88d799633ad2f49ffd6f5b86ac80e6b29fdbf4ae1fc5b",
            "industrialExpansion.complication": "bf224d530d68bac4934d3ccad61edaa08eb908ce911f73d07c58c91561ac23b4",
            "industrialExpansion.setback": "dccab9562ed39a8b6ceec4234058c0f907ea12da573135ebcaeeb2d374215c63",
            "industrialExpansion.recovery": "57fafd73980a3dc45ada65e8432a8951c1eaa9cdab66fa393e63f2f5fa0a7609",
            "industrialExpansion.completed": "c7e934c3a28bcc915491a731f1e30586af183e5e476c45b4c9c697c9507ef3eb"
        ]

        for strategy in [CityStrategy.commercialStewardship, .industrialExpansion] {
            for (phase, state) in try strategyPhaseFixtures(for: strategy) {
                let fingerprint = try CityStateFingerprinter.fingerprint(state)
                let key = "\(strategy.rawValue).\(phase.rawValue)"
                XCTAssertEqual(fingerprint.digest, expected[key], key)
                XCTAssertEqual(
                    Set(try (0..<5).map { _ in try CityStateFingerprinter.fingerprint(state).digest }),
                    Set([try XCTUnwrap(expected[key])]),
                    key
                )
                XCTAssertEqual(state.progression?.strategy?.committedStrategy, strategy)
                XCTAssertEqual(state.progression?.strategy?.currentPhase, phase)
                XCTAssertFalse(CityAnalytics(state: state).awaitingStrategyChoice)
                XCTAssertEqual(CityAnalytics(state: state).committedStrategy, strategy)
                XCTAssertEqual(CityAnalytics(state: state).strategyPhase, phase)
                XCTAssertEqual(
                    CityAnalytics(state: state).strategyDaysUntilConsequence,
                    phase == .completed ? nil : 16
                )

                try withTemporaryRoot { root in
                    let service = SaveGameService(rootURL: root)
                    let write = try service.save(state)
                    let load = try service.load()
                    XCTAssertEqual(write.schemaVersion, 1)
                    XCTAssertEqual(write.fingerprint, fingerprint)
                    XCTAssertEqual(load.state, state)
                    XCTAssertEqual(load.fingerprint, fingerprint)
                }
            }
        }
    }

    func testDenseSessionSimulationAndPersistencePerformance() throws {
        try withTemporaryRoot { root in
            var state = play013DenseTerminalFixtureV5()
            let simulationStart = ProcessInfo.processInfo.systemUptime
            for _ in 0..<400 { CitySimulation.step(&state) }
            let simulationMilliseconds = elapsedMilliseconds(since: simulationStart)

            let fingerprintStart = ProcessInfo.processInfo.systemUptime
            let fingerprint = try CityStateFingerprinter.fingerprint(state)
            let fingerprintMilliseconds = elapsedMilliseconds(since: fingerprintStart)

            let snapshotStart = ProcessInfo.processInfo.systemUptime
            let snapshot = try CityPresentationSnapshot(state: state)
            let snapshotMilliseconds = elapsedMilliseconds(since: snapshotStart)
            let retainedSampleBytes = MemoryLayout<CitySpatialConsequence>.stride
                * snapshot.spatialConsequences.samples.count

            let service = SaveGameService(rootURL: root)
            let saveStart = ProcessInfo.processInfo.systemUptime
            let write = try service.save(state)
            let saveMilliseconds = elapsedMilliseconds(since: saveStart)

            let loadStart = ProcessInfo.processInfo.systemUptime
            let load = try service.load()
            let loadMilliseconds = elapsedMilliseconds(since: loadStart)

            printCheckpoint("dense-terminal", state: state)
            XCTAssertEqual(state.tick, 44)
            XCTAssertEqual(state.status, .lost)
            XCTAssertEqual(state.treasury, 6_602_062.55, accuracy: 0.001)
            XCTAssertEqual(state.population, 46_459)
            XCTAssertEqual(state.jobs, 32_739)
            XCTAssertEqual(
                state.progression,
                CityProgressionState(
                    strategy: CityStrategyProgression(
                        committedStrategy: .industrialExpansion,
                        currentPhase: .opportunity,
                        nextScheduledTick: 68
                    )
                )
            )
            XCTAssertTrue(state.messages.contains { $0.title == "Town Charter Standards" })
            XCTAssertEqual(fingerprint.digest, Self.play013DenseTerminalFixtureDigest)
            XCTAssertEqual(snapshot.fingerprint, fingerprint)
            XCTAssertEqual(snapshot.analytics.committedStrategy, .industrialExpansion)
            XCTAssertEqual(snapshot.analytics.strategyPhase, .opportunity)
            XCTAssertEqual(load.state, state)
            XCTAssertEqual(load.fingerprint, fingerprint)
            XCTAssertEqual(write.fingerprint, fingerprint)
            XCTAssertLessThan(simulationMilliseconds, 5_000)
            XCTAssertLessThan(fingerprintMilliseconds, 500)
            XCTAssertLessThan(snapshotMilliseconds, 500)
            XCTAssertLessThan(saveMilliseconds, 1_500)
            XCTAssertLessThan(loadMilliseconds, 1_500)
            XCTAssertLessThan(write.byteCount, 2_000_000)
            XCTAssertLessThanOrEqual(retainedSampleBytes, 128 * 1_024)

            print(
                "CITYSIM_SESSION_PERFORMANCE fixture=\(Self.play013DenseTerminalFixtureName) " +
                "step_attempts=400 final_tick=\(state.tick) status=\(state.status.rawValue) " +
                "simulation_ms=\(metric(simulationMilliseconds)) " +
                "fingerprint_ms=\(metric(fingerprintMilliseconds)) " +
                "snapshot_ms=\(metric(snapshotMilliseconds)) " +
                "save_ms=\(metric(saveMilliseconds)) " +
                "load_ms=\(metric(loadMilliseconds)) bytes=\(write.byteCount) " +
                "retained_sample_bytes=\(retainedSampleBytes) " +
                "digest=\(fingerprint.digest)"
            )
        }
    }

    private func withTemporaryRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play040-\(UUID().uuidString)", directoryHint: .isDirectory)
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

    private func apply(
        _ commands: [CitySimulationCommand],
        to state: inout CityGameState
    ) {
        for command in commands {
            let result = CitySimulationCommandExecutor.apply(command, to: &state)
            XCTAssertEqual(result, .applied, "Fixture command rejected: \(command) -> \(result)")
        }
    }

    private func advanceDailyBoundaries(_ count: Int, state: inout CityGameState) {
        for _ in 0..<count {
            apply([.advanceOneDailyBoundary], to: &state)
        }
    }

    private func advanceTicks(_ count: Int, state: inout CityGameState) {
        for _ in 0..<count { CitySimulation.step(&state) }
    }

    private func strategyPhaseFixtures(
        for strategy: CityStrategy
    ) throws -> [(CityStrategyPhase, CityGameState)] {
        var state = CityGameState.newCity(seed: 42)
        let kind: BuildingKind = strategy == .commercialStewardship ? .commercial : .industrial
        apply([
            .build(kind: kind, coordinate: GridCoordinate(x: 8, y: 11)),
            .build(kind: kind, coordinate: GridCoordinate(x: 7, y: 11)),
            .advanceOneDailyBoundary
        ], to: &state)

        var fixtures: [(CityStrategyPhase, CityGameState)] = []
        while let progression = state.progression?.strategy {
            fixtures.append((progression.currentPhase, state))
            guard let scheduledTick = progression.nextScheduledTick else { break }
            while state.tick < scheduledTick { CitySimulation.step(&state) }
        }
        return fixtures
    }

    // V5 runs the unchanged dense generator under PLAY-013's additive durable
    // strategy semantics. The industrial majority now commits at tick 4.
    private func play013DenseTerminalFixtureV5() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        let kinds: [BuildingKind] = [
            .residential, .commercial, .industrial, .park,
            .powerPlant, .waterTower, .fireStation, .policeStation, .school
        ]
        for index in state.tiles.indices where state.tiles[index].kind == .empty {
            state.tiles[index].kind = kinds[index % kinds.count]
            state.tiles[index].level = 4
            state.tiles[index].occupancy = 180
            state.tiles[index].condition = 0.92
            state.tiles[index].constructionProgress = 1
        }
        state.population = 50_000
        state.treasury = 8_000_000
        return state
    }

    private func elapsedMilliseconds(since start: TimeInterval) -> Double {
        (ProcessInfo.processInfo.systemUptime - start) * 1_000
    }

    private func printCheckpoint(_ name: String, state: CityGameState) {
        let analytics = CityAnalytics(state: state)
        let active = CitySimulation.activeTiles(in: state)
        let powerPlants = active.filter { $0.kind == .powerPlant }.count
        let waterTowers = active.filter { $0.kind == .waterTower }.count
        let messageTitles = state.messages.map(\.title).joined(separator: "|")
        print(
            "CITYSIM_CHECKPOINT name=\(name) tick=\(state.tick) status=\(state.status.rawValue) " +
            "treasury=\(metric(state.treasury)) population=\(state.population) jobs=\(state.jobs) " +
            "happiness=\(metric(state.happiness)) approval=\(metric(state.approval)) " +
            "power=\(state.powerUsed)/\(state.powerCapacity) water=\(state.waterUsed)/\(state.waterCapacity) " +
            "powerPlants=\(powerPlants) waterTowers=\(waterTowers) " +
            "balance=\(metric(analytics.projectedBalance)) reserve=\(metric(analytics.utilityReserve)) " +
            "progression=\(state.progression?.townCharterQualifyingCycles ?? -1)/" +
            "\(state.progression?.townCharterAwarded ?? false) " +
            "strategy=\(state.progression?.strategy?.committedStrategy.rawValue ?? "nil")/" +
            "\(state.progression?.strategy?.currentPhase.rawValue ?? "nil")/" +
            "\(state.progression?.strategy?.nextScheduledTick ?? -1) " +
            "seed=\(state.seed) messages=\(messageTitles)"
        )
    }

    private func metric(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
