import CryptoKit
import XCTest
@testable import CitySimNative

final class SessionPlatformTests: XCTestCase {
    private static let play071DenseTerminalFixtureName =
        "dense-24x24-terminal-post-play071-v7"
    private static let play071DenseTerminalFixtureDigest =
        "65e5f505f7b1c4532de2dc20401222e11121b21b2be0def8333a203b6f6daeaa"

    func testVersionOneFingerprintFixturesAreFrozen() throws {
        let explicitProgression = CityGameState.newCity(seed: 42)
        var legacyNilProgression = explicitProgression
        legacyNilProgression.progression = nil

        XCTAssertTrue(CityAnalytics(state: explicitProgression).awaitingStrategyChoice)

        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(explicitProgression),
            CityStateFingerprint(digest: "28b567b4e0da5302aeb28d81f3644bb6c07c44005b70d4f3dce146494a4ce1e5")
        )
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(legacyNilProgression),
            CityStateFingerprint(digest: "0e966e432ec6eff89e9a3785f2d083d74ccb4a32d6155a55e54eb64de788a888")
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
        advanceDailyBoundaries(206, state: &industry)
        let industryBeforeVictory = industry

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
        XCTAssertEqual(industryBeforeVictory.progression?.townCharterQualifyingCycles, 11)
        XCTAssertEqual(commerceBeforeVictory.progression?.townCharterQualifyingCycles, 11)
        XCTAssertFalse(industryBeforeVictory.progression?.townCharterAwarded ?? true)
        XCTAssertFalse(commerceBeforeVictory.progression?.townCharterAwarded ?? true)
        XCTAssertEqual(industryBeforeVictory.treasury, 76_487.40, accuracy: 0.001)
        XCTAssertEqual(commerceBeforeVictory.treasury, 67_506.90, accuracy: 0.001)
        XCTAssertEqual(industryBeforeVictory.population, 510)
        XCTAssertEqual(commerceBeforeVictory.population, 510)
        XCTAssertEqual(industryBeforeVictory.jobs, 356)
        XCTAssertEqual(commerceBeforeVictory.jobs, 356)
        XCTAssertEqual(industryBeforeVictory.happiness, 53.0, accuracy: 0.001)
        XCTAssertEqual(commerceBeforeVictory.happiness, 55.9, accuracy: 0.001)
        XCTAssertEqual(
            CityAnalytics(state: industryBeforeVictory).projectedBalance,
            404.05,
            accuracy: 0.001
        )
        XCTAssertEqual(
            CityAnalytics(state: commerceBeforeVictory).projectedBalance,
            480.65,
            accuracy: 0.001
        )
        XCTAssertEqual(
            Set(try (0..<5).map {
                _ in try CityStateFingerprinter.fingerprint(industryBeforeVictory).digest
            }),
            Set(["dcd18ec4870de1c67613aa5ab3ebe28ba7bb38d8859068099847b5113dbf330c"])
        )
        XCTAssertEqual(
            Set(try (0..<5).map {
                _ in try CityStateFingerprinter.fingerprint(commerceBeforeVictory).digest
            }),
            Set(["9815a24299634aecf90347586832be51c10af6e445d5875f30bd9b708fe51854"])
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
        XCTAssertEqual(industry.treasury, 76_892.75, accuracy: 0.001)
        XCTAssertEqual(commerce.treasury, 67_989.37, accuracy: 0.001)
        XCTAssertEqual(CityAnalytics(state: industry).projectedBalance, 405.35, accuracy: 0.001)
        XCTAssertEqual(CityAnalytics(state: commerce).projectedBalance, 482.47, accuracy: 0.001)
        XCTAssertTrue(industry.progression?.townCharterAwarded ?? false)
        XCTAssertTrue(commerce.progression?.townCharterAwarded ?? false)
        XCTAssertTrue(industry.messages.contains { $0.title == "Neighborhood Upgraded" })
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
        XCTAssertEqual(industry.progression?.secondAct?.phase, .mandate)
        XCTAssertEqual(industry.progression?.secondAct?.nextScheduledTick, 908)
        XCTAssertEqual(industry.progression?.secondAct?.qualifyingCycles, 0)
        XCTAssertFalse(industry.progression?.secondAct?.regionalCapitalAwarded ?? true)
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
            "78cabfde8dabf2a9efc63518d3adeb6e06ccf64745dbe85135b9145c20dcc0f2"
        )
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(commerce).digest,
            "fca0e6ba03b420369d3b75215fc6dda8b0656bcd08cad36b2a283cf5bd8d3401"
        )
        XCTAssertEqual(
            Set(try (0..<5).map { _ in try CityStateFingerprinter.fingerprint(industry).digest }),
            Set(["78cabfde8dabf2a9efc63518d3adeb6e06ccf64745dbe85135b9145c20dcc0f2"])
        )
        XCTAssertEqual(
            Set(try (0..<5).map { _ in try CityStateFingerprinter.fingerprint(commerce).digest }),
            Set(["fca0e6ba03b420369d3b75215fc6dda8b0656bcd08cad36b2a283cf5bd8d3401"])
        )
    }

    func testStrategyPhaseFingerprintsAreFrozen() throws {
        let expected = [
            "commercialStewardship.opportunity": "9fd06662bef502189614d05a1f3d2f711ccbbb5b73bb4053b96d2a968db1a1f8",
            "commercialStewardship.complication": "9ccb03a811ca0719bb3ecebff9d9e2d7b5a569317b8c6bacddda454949c3b4bc",
            "commercialStewardship.setback": "436f8d4bc8f3f4c980e39d19fe0bdff42663c67022ac7efc10f1729b92b504c8",
            "commercialStewardship.recovery": "666547e90e9e8077a638db31213c2d929def4796e87e76581bc319c6fb37b118",
            "commercialStewardship.completed": "ff8152a444b4ab386b9dfc9aca05bdc0358a439a51a55b7e5147af2fd453cf90",
            "industrialExpansion.opportunity": "2188b29bf14b4948e9dbf7fed81257247ba145d5e63d1ca42b1c8791b4212b16",
            "industrialExpansion.complication": "bb7ca9a0e7a58d0c12b007c709bdc5a541f90615aa958f1721c69359abde506b",
            "industrialExpansion.setback": "dc95ec8e596d30a44072f0d524f8b51004bcfaaf2119b799aa4fdd3e2832847c",
            "industrialExpansion.recovery": "4d242e6f14733ac36d3b48c33611107340dcc1324e5522d8d5f822dc53036b58",
            "industrialExpansion.completed": "778f10a148d8f742fe3205d0a7c5ba3366c8f26d731cd549861ec8ccef91b632"
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
            var state = play071DenseTerminalFixtureV7()
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
            XCTAssertEqual(state.treasury, 6_853_267.90, accuracy: 0.001)
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
            XCTAssertEqual(fingerprint.digest, Self.play071DenseTerminalFixtureDigest)
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
                "CITYSIM_SESSION_PERFORMANCE fixture=\(Self.play071DenseTerminalFixtureName) " +
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

    // V6 runs the unchanged dense generator from PLAY-016's richer authoritative
    // starter district. The industrial majority still commits at tick 4.
    private func play071DenseTerminalFixtureV7() -> CityGameState {
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
