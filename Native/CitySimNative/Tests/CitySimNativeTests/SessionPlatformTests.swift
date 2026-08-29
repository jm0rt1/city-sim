import CryptoKit
import XCTest
@testable import CitySimNative

final class SessionPlatformTests: XCTestCase {
    private static let play078DenseTerminalFixtureName =
        "dense-24x24-terminal-post-play076-v8"
    private static let play078DenseTerminalFixtureDigest =
        "c557d3d0bc8a35e755cfca54f0985970ba3d7ae265f7d478cd887db1bfb79c14"

    func testVersionOneFingerprintFixturesAreFrozen() throws {
        let explicitProgression = CityGameState.newCity(seed: 42)
        var legacyNilProgression = explicitProgression
        legacyNilProgression.progression = nil

        XCTAssertTrue(CityAnalytics(state: explicitProgression).awaitingStrategyChoice)

        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(explicitProgression),
            CityStateFingerprint(digest: "ee95ebc98d8314e2ae2661baa03bc11809a70811cec1fdfb5633930ee78186d3")
        )
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(legacyNilProgression),
            CityStateFingerprint(digest: "bba31f738c9b3b4d4e91d22714d151520736cf3aa48fabb67f15e0b2d9bbceb7")
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
        store.primaryAction(at: GridCoordinate(x: 6, y: 8))
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
            .build(kind: .commercial, coordinate: GridCoordinate(x: 4, y: 8)),
            .advanceOneDailyBoundary,
            .demolish(coordinate: GridCoordinate(x: 4, y: 8))
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
        XCTAssertEqual(state.tile(at: GridCoordinate(x: 4, y: 8))?.kind, .empty)

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
            .build(kind: .industrial, coordinate: GridCoordinate(x: 4, y: 8)),
            .build(kind: .industrial, coordinate: GridCoordinate(x: 5, y: 8)),
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

    func testDenseDeferredSecondActPressureRecoverySurvivesSaveResume() throws {
        func denseDeferredSecondAct() -> CityGameState {
            var state = play078DenseTerminalFixtureV8()
            for index in state.tiles.indices where state.tiles[index].kind == .park {
                state.tiles[index].kind = .commercial
            }
            state.population = 10_000
            state.treasury = 100_000_000
            state.happiness = 70
            state.approval = 70
            state.taxRate = 0.10
            state.progression = CityProgressionState(
                townCharterQualifyingCycles: 12,
                townCharterAwarded: true,
                strategy: CityStrategyProgression(
                    committedStrategy: .commercialStewardship,
                    currentPhase: .completed,
                    nextScheduledTick: nil,
                    recoveryResolution: nil
                ),
                secondAct: CitySecondActProgression(
                    phase: .mandate,
                    nextScheduledTick: 4
                )
            )
            return state
        }

        var uninterrupted = denseDeferredSecondAct()
        while uninterrupted.tick < 4 { CitySimulation.step(&uninterrupted) }
        XCTAssertEqual(uninterrupted.progression?.secondAct?.phase, .warnedPressure)
        XCTAssertNil(uninterrupted.progression?.strategy?.recoveryResolution)

        try withTemporaryRoot { root in
            let service = SaveGameService(rootURL: root)
            let write = try service.save(uninterrupted)
            let loaded = try service.load()
            XCTAssertEqual(write.schemaVersion, 1)
            XCTAssertEqual(loaded.state, uninterrupted)
            XCTAssertEqual(loaded.fingerprint, write.fingerprint)

            var resumed = loaded.state
            for _ in 0..<CitySimulation.strategyMinimumWarningTicks {
                CitySimulation.step(&uninterrupted)
                CitySimulation.step(&resumed)
            }
            XCTAssertEqual(uninterrupted.progression?.secondAct?.phase, .recovery)
            XCTAssertEqual(resumed, uninterrupted)

            XCTAssertEqual(
                CitySimulationCommandExecutor.apply(.setTaxRate(0.08), to: &uninterrupted),
                .applied
            )
            XCTAssertEqual(
                CitySimulationCommandExecutor.apply(.setTaxRate(0.08), to: &resumed),
                .applied
            )
            for _ in 0..<8 {
                CitySimulation.step(&uninterrupted)
                CitySimulation.step(&resumed)
                if uninterrupted.progression?.secondAct?.phase == .qualification {
                    break
                }
            }

            XCTAssertEqual(uninterrupted.progression?.secondAct?.phase, .qualification)
            XCTAssertFalse(uninterrupted.progression?.secondAct?.regionalCapitalAwarded ?? true)
            XCTAssertEqual(uninterrupted.status, .playing)
            XCTAssertEqual(resumed, uninterrupted)
            XCTAssertEqual(
                try CityStateFingerprinter.fingerprint(resumed),
                try CityStateFingerprinter.fingerprint(uninterrupted)
            )
        }
    }

    func testAcceptedStrategyCommandsProduceFrozenCheckpoints() throws {
        var industry = CityGameState.newCity(seed: 42)
        apply([
            .build(kind: .industrial, coordinate: GridCoordinate(x: 4, y: 8)),
            .build(kind: .industrial, coordinate: GridCoordinate(x: 5, y: 8))
        ], to: &industry)
        advanceDailyBoundaries(4, state: &industry)
        apply([
            .build(kind: .powerPlant, coordinate: GridCoordinate(x: 6, y: 8)),
            .build(kind: .waterTower, coordinate: GridCoordinate(x: 7, y: 8))
        ], to: &industry)
        advanceDailyBoundaries(206, state: &industry)
        let industryBeforeVictory = industry

        var commerce = CityGameState.newCity(seed: 42)
        apply([
            .setTaxRate(0.14),
            .build(kind: .commercial, coordinate: GridCoordinate(x: 4, y: 8)),
            .build(kind: .commercial, coordinate: GridCoordinate(x: 5, y: 8))
        ], to: &commerce)
        advanceDailyBoundaries(2, state: &commerce)
        apply([
            .build(kind: .powerPlant, coordinate: GridCoordinate(x: 6, y: 8)),
            .build(kind: .waterTower, coordinate: GridCoordinate(x: 7, y: 8))
        ], to: &commerce)
        advanceDailyBoundaries(208, state: &commerce)
        let commerceBeforeVictory = commerce

        printCheckpoint("accepted-industrial-pre-victory", state: industryBeforeVictory)
        printCheckpoint("accepted-commercial-pre-victory", state: commerceBeforeVictory)
        print(
            "PLAY046_PRE_VICTORY_DIGESTS industrial=" +
            "\(try CityStateFingerprinter.fingerprint(industryBeforeVictory).digest) commercial=" +
            "\(try CityStateFingerprinter.fingerprint(commerceBeforeVictory).digest)"
        )

        XCTAssertEqual(industryBeforeVictory.tick, 840)
        XCTAssertEqual(commerceBeforeVictory.tick, 840)
        XCTAssertEqual(industryBeforeVictory.status, .playing)
        XCTAssertEqual(commerceBeforeVictory.status, .playing)
        XCTAssertEqual(industryBeforeVictory.progression?.townCharterQualifyingCycles, 4)
        XCTAssertEqual(commerceBeforeVictory.progression?.townCharterQualifyingCycles, 11)
        XCTAssertFalse(industryBeforeVictory.progression?.townCharterAwarded ?? true)
        XCTAssertFalse(commerceBeforeVictory.progression?.townCharterAwarded ?? true)
        XCTAssertEqual(industryBeforeVictory.treasury, 67_748.20, accuracy: 0.001)
        XCTAssertEqual(commerceBeforeVictory.treasury, 57_946.90, accuracy: 0.001)
        XCTAssertEqual(industryBeforeVictory.population, 510)
        XCTAssertEqual(commerceBeforeVictory.population, 510)
        XCTAssertEqual(industryBeforeVictory.jobs, 356)
        XCTAssertEqual(commerceBeforeVictory.jobs, 356)
        XCTAssertEqual(industryBeforeVictory.happiness, 52.209060243739934, accuracy: 0.001)
        XCTAssertEqual(commerceBeforeVictory.happiness, 55.59198776401641, accuracy: 0.001)
        XCTAssertEqual(
            CityAnalytics(state: industryBeforeVictory).projectedBalance,
            413.65,
            accuracy: 0.001
        )
        XCTAssertEqual(
            CityAnalytics(state: commerceBeforeVictory).projectedBalance,
            444.65,
            accuracy: 0.001
        )
        XCTAssertEqual(
            Set(try (0..<5).map {
                _ in try CityStateFingerprinter.fingerprint(industryBeforeVictory).digest
            }),
            Set(["6ccce1225c9fc51bbd03811211faf34d1219dc22c2014da7fc2e615874e8ca22"])
        )
        XCTAssertEqual(
            Set(try (0..<5).map {
                _ in try CityStateFingerprinter.fingerprint(commerceBeforeVictory).digest
            }),
            Set(["1bc073ad5f23e943a26dfda92a6005f431eeb6db95f8de6ddd7b02400eb15982"])
        )

        XCTAssertEqual(
            CitySimulationCommandExecutor.apply(.advanceOneDailyBoundary, to: &industry),
            .applied
        )
        XCTAssertEqual(
            CitySimulationCommandExecutor.apply(.advanceOneDailyBoundary, to: &commerce),
            .applied
        )

        printCheckpoint("accepted-industrial-charter-midpoint", state: industry)
        printCheckpoint("accepted-commercial-charter-midpoint", state: commerce)
        XCTAssertEqual(industry.tick, 844)
        XCTAssertEqual(commerce.tick, 844)
        XCTAssertEqual(industry.status, .playing)
        XCTAssertEqual(commerce.status, .playing)
        XCTAssertEqual(industry.treasury, 68_163.15, accuracy: 0.001)
        XCTAssertEqual(commerce.treasury, 58_393.37, accuracy: 0.001)
        XCTAssertEqual(CityAnalytics(state: industry).projectedBalance, 414.95, accuracy: 0.001)
        XCTAssertEqual(CityAnalytics(state: commerce).projectedBalance, 446.47, accuracy: 0.001)
        XCTAssertFalse(industry.progression?.townCharterAwarded ?? true)
        XCTAssertTrue(commerce.progression?.townCharterAwarded ?? false)
        XCTAssertTrue(industry.messages.contains { $0.title == "Neighborhood Upgraded" })
        XCTAssertTrue(commerce.messages.contains { $0.title == "Town Charter Standards" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Industrial Load Absorbed" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Load Forecast" })
        XCTAssertFalse(industryBeforeVictory.messages.contains { $0.title == "Freight Contract Watch" })
        XCTAssertFalse(industry.messages.contains { $0.title == "Choose a Growth Engine" })
        XCTAssertTrue(commerce.messages.contains { $0.title == "Chain Store Rumor" })
        XCTAssertFalse(commerce.messages.contains { $0.title == "Main Street Crossroads" })
        XCTAssertFalse(commerce.messages.contains { $0.title == "Choose a Growth Engine" })
        XCTAssertEqual(industry.progression?.strategy?.committedStrategy, .industrialExpansion)
        XCTAssertEqual(industry.progression?.strategy?.currentPhase, .completed)
        XCTAssertNil(industry.progression?.strategy?.nextScheduledTick)
        XCTAssertEqual(industry.progression?.strategy?.recoveryResolution, .industrialUtilityExpansion)
        XCTAssertEqual(CityAnalytics(state: industry).strategyRecoveryResolution, .industrialUtilityExpansion)
        XCTAssertNil(industry.progression?.secondAct)
        XCTAssertEqual(commerce.progression?.strategy?.committedStrategy, .commercialStewardship)
        XCTAssertEqual(commerce.progression?.strategy?.currentPhase, .completed)
        XCTAssertNil(commerce.progression?.strategy?.nextScheduledTick)
        XCTAssertNil(commerce.progression?.strategy?.recoveryResolution)
        XCTAssertNil(CityAnalytics(state: commerce).strategyRecoveryResolution)
        XCTAssertEqual(commerce.progression?.secondAct?.phase, .mandate)
        XCTAssertEqual(commerce.progression?.secondAct?.nextScheduledTick, 908)
        XCTAssertEqual(commerce.progression?.secondAct?.qualifyingCycles, 0)
        XCTAssertFalse(commerce.progression?.secondAct?.regionalCapitalAwarded ?? true)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(industry).digest,
            "2a6f9cfa7df64233bab923b9038eb4b41a78e03e9fa5468c4a5b3f60baef7498"
        )
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(commerce).digest,
            "d4cd76df1a4cd355a477d2afd839a122680fafa6454b960dbf5ec2117610ade5"
        )
        XCTAssertEqual(
            Set(try (0..<5).map { _ in try CityStateFingerprinter.fingerprint(industry).digest }),
            Set(["2a6f9cfa7df64233bab923b9038eb4b41a78e03e9fa5468c4a5b3f60baef7498"])
        )
        XCTAssertEqual(
            Set(try (0..<5).map { _ in try CityStateFingerprinter.fingerprint(commerce).digest }),
            Set(["d4cd76df1a4cd355a477d2afd839a122680fafa6454b960dbf5ec2117610ade5"])
        )
    }

    func testStrategyPhaseFingerprintsAreFrozen() throws {
        let expected = [
            "commercialStewardship.opportunity": "d88cfc4c057fd5535cfd4e60fa7a8905ffb9fb5b59709492cc9c5f49a88e7dec",
            "commercialStewardship.complication": "acae994bea4246f75ed2c5b1518b378803c73c7853ef7528d276e9bd769621a6",
            "commercialStewardship.setback": "3e95b463a04b4dd42ab755b3b029a67f10e42ea87143fe6f4cb9b1d8aa8c60ac",
            "commercialStewardship.recovery": "53561d23484f0877f563abf7e2846928d741cd429487016862d698353041acfa",
            "commercialStewardship.completed": "0383116d8453a6335491e3a35f3df944f5102b0cc7722267411cd00f3df762c1",
            "industrialExpansion.opportunity": "06db24a5dda82e3831934871321692a4e5bd220c5414aedc02ccb87688c09dde",
            "industrialExpansion.complication": "5a09c48230c3040498e5e71b38fd38a348573460e40799b9816655bd48ad9dc8",
            "industrialExpansion.setback": "db4dfffa8cc727bbde3dad31151a749cd09d3dc5f994394efff2ccdf0a9c9b8f",
            "industrialExpansion.recovery": "63cbd32c3ebe24cff5098c6a6792d3452467c6cc4fac02258f22202e076c505d",
            "industrialExpansion.completed": "be313c6dd7d4bd1e9b1563178423814c14c4ddb733cf5bcd8349b271d937e79b"
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
            var state = play078DenseTerminalFixtureV8()
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
            XCTAssertEqual(state.treasury, 6_866_800.10, accuracy: 0.001)
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
            XCTAssertEqual(fingerprint.digest, Self.play078DenseTerminalFixtureDigest)
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
                "CITYSIM_SESSION_PERFORMANCE fixture=\(Self.play078DenseTerminalFixtureName) " +
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

    func testDenseThreeXRunningCityRuntimeIsDeterministic() throws {
        func runProfile() throws -> (state: CityGameState, fingerprint: CityStateFingerprint, milliseconds: Double) {
            var state = play078DenseTerminalFixtureV8()
            state.population = 10_000
            state.treasury = 100_000_000
            state.happiness = 70
            state.approval = 70

            let pulseCount = 400
            let ticksPerPulse = SimulationSpeed.fastest.ticksPerPulse
            let start = ProcessInfo.processInfo.systemUptime
            for _ in 0..<pulseCount {
                for _ in 0..<ticksPerPulse {
                    CitySimulation.step(&state)
                }
            }
            let milliseconds = elapsedMilliseconds(since: start)
            let fingerprint = try CityStateFingerprinter.fingerprint(state)
            return (state, fingerprint, milliseconds)
        }

        let first = try runProfile()
        let second = try runProfile()

        XCTAssertEqual(first.state, second.state)
        XCTAssertEqual(first.fingerprint, second.fingerprint)
        XCTAssertEqual(first.state.tick, 400 * SimulationSpeed.fastest.ticksPerPulse)
        XCTAssertEqual(first.state.status, .playing)
        print(
            "CITYSIM_DENSE_3X_PROFILE fixture=dense-24x24-running " +
            "pulses=400 ticks=\(first.state.tick) status=\(first.state.status.rawValue) " +
            "run_a_ms=\(metric(first.milliseconds)) run_b_ms=\(metric(second.milliseconds)) " +
            "digest=\(first.fingerprint.digest)"
        )
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
            .build(kind: kind, coordinate: GridCoordinate(x: 4, y: 8)),
            .build(kind: kind, coordinate: GridCoordinate(x: 5, y: 8)),
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

    // V8 runs the unchanged dense generator from PLAY-016 against PLAY-076's
    // richer starter district. The industrial majority still commits at tick 4.
    private func play078DenseTerminalFixtureV8() -> CityGameState {
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
