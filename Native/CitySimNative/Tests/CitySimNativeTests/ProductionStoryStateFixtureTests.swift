import Foundation
import XCTest
@testable import CitySimNative

final class ProductionStoryStateFixtureTests: XCTestCase {
    private static let fixtureSubdirectory = "Fixtures/StoryStates"
    private static let currentManifestFile = "story-states-manifest-v7.json"
    private static let play072ManifestFile = "story-states-manifest-v3.json"
    private static let play069ManifestFile = "story-states-manifest-v2.json"
    private static let legacyManifestFile = "story-states-manifest-v1.json"

    private let resolutions: [CityStrategyRecoveryResolution] = [
        .commercialTaxRelief,
        .commercialPublicRealmInvestment,
        .industrialUtilityExpansion,
        .industrialGreenBuffer,
    ]

    func testWriteCurrentFixtureCorpusOnlyWhenExplicitlyRequested() throws {
        guard let rootPath = ProcessInfo.processInfo.environment[
            "CITYSIM_PLAY078_WRITE_STORY_FIXTURES"
        ],
        !rootPath.isEmpty else {
            return
        }

        let first = try ProductionStoryFixtureCorpus.build()
        let second = try ProductionStoryFixtureCorpus.build()
        XCTAssertEqual(first, second)

        let root = URL(filePath: rootPath, directoryHint: .isDirectory)
        try first.write(to: root)
        print(
            "PLAY078_STORY_FIXTURE_WRITE root=\(root.path) fixtures=\(first.artifacts.count) " +
            "manifest=\(Self.currentManifestFile)"
        )
    }

    func testAuthenticV1CorpusRemainsByteExactAndMissingSecondActCompatible() throws {
        let expectedSHA256 = [
            "story-commercial-opening-v1.json":
                "d19b5e6b27af6133ec90548cd480d3707c4a3e693dfb34e49585d044cd4a0e0a",
            "story-commercial-complication-v1.json":
                "fbcff0377fb1692595292cabd81c2ea70f2b69681a9964006078d031546fe03a",
            "story-commercial-recovery-v1.json":
                "d3620bdee148cc0093e7303890df3facba7914208f39079affc29fc882e2e1b4",
            "story-commercial-charter-victory-v1.json":
                "4df448848a8fa71a536df60d3fcf9a8d0c096025bc7d04cfcb6af5ad8f772c60",
            "story-industrial-opening-v1.json":
                "b6fb32abafca99592a5ad5f0e7312c0cad7520c556c4b785e19e8894936ce0d3",
            "story-industrial-complication-v1.json":
                "7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7",
            "story-industrial-recovery-v1.json":
                "a9c3e22db19c9c880178b5928e2af867b5de67e2dec686357b845194dd00d411",
            "story-industrial-charter-victory-v1.json":
                "e5b2c53592149960400e15948518d0aaab9e9977184118d12d3a0c4e96088aab",
            Self.legacyManifestFile:
                "3614c6f7cd6eeed473c499f05a29c122aa92858744a717cc2e34bdb98f72fef0",
        ]
        let manifestData = try resourceData(file: Self.legacyManifestFile)
        XCTAssertEqual(
            ProductionStoryFixtureCorpus.sha256(manifestData),
            expectedSHA256[Self.legacyManifestFile]
        )
        let manifest = try JSONDecoder().decode(
            ProductionStoryFixtureManifest.self,
            from: manifestData
        )
        XCTAssertEqual(manifest.fixtures.count, 8)
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.fingerprintVersion, 1)
        XCTAssertEqual(manifest.seed, 42)

        for entry in manifest.fixtures {
            let bytes = try resourceData(file: entry.file)
            XCTAssertEqual(
                ProductionStoryFixtureCorpus.sha256(bytes),
                expectedSHA256[entry.file],
                entry.id
            )
            XCTAssertEqual(
                ProductionStoryFixtureCorpus.sha256(bytes),
                entry.fileSHA256,
                entry.id
            )
            XCTAssertEqual(bytes.count, entry.byteCount, entry.id)

            try withTemporaryRoot(id: "legacy-\(entry.id)") { root in
                let service = SaveGameService(rootURL: root)
                let state = try decodedState(from: bytes, using: service)
                let load = try service.load()
                XCTAssertEqual(load.schemaVersion, 1, entry.id)
                XCTAssertEqual(load.fingerprint.version, 1, entry.id)
                XCTAssertEqual(load.fingerprint.digest, entry.expectedStateDigest, entry.id)
                XCTAssertEqual(state.progression?.secondAct, nil, entry.id)
                XCTAssertEqual(state.status, entry.status, entry.id)
                XCTAssertEqual(state.tick, entry.tick, entry.id)
                XCTAssertEqual(try Data(contentsOf: service.saveURL), bytes, entry.id)
            }
        }
    }

    func testPlay069V2CorpusRemainsByteExact() throws {
        let expectedSHA256 = [
            "story-commercial-charter-midpoint-v2.json":
                "bf7d2234043ca757fd62a711d55168f9c26be646a61cb1ab9f662eb47bd69824",
            "story-commercial-tax-relief-regional-capital-v2.json":
                "3c9b71abd681676ed5d8acd58bb8f41e9fb88c24f95281c0f41b0b61cf144d02",
            "story-commercial-public-realm-regional-capital-v2.json":
                "2a2044f43c05cf5b87e87f1f1a4a2f75c9c222f1a812e99128859a24094a0676",
            "story-industrial-charter-midpoint-v2.json":
                "17040195a2c76f7bb149b6d89c22e3b3dfdf6be1325a32cca917d2555c42840b",
            "story-industrial-utility-expansion-regional-capital-v2.json":
                "78781f5bc0e989ea41cb3fed1de2a445211fa0aa0e9634173bcd8b615cb13d5d",
            "story-industrial-green-buffer-regional-capital-v2.json":
                "f25bca43bf2c6506200a969eb16e3cde25cb14fc092c8f31303f621dfe334a9d",
            Self.play069ManifestFile:
                "a793dc9ea5cfc50b7482fb7f4bf4e7a3a3c5e9cfb1cad6e47722fc17cbf22153",
        ]
        let manifestData = try resourceData(file: Self.play069ManifestFile)
        XCTAssertEqual(
            ProductionStoryFixtureCorpus.sha256(manifestData),
            expectedSHA256[Self.play069ManifestFile]
        )
        let manifest = try JSONDecoder().decode(
            ProductionStoryFixtureManifestV2.self,
            from: manifestData
        )
        XCTAssertEqual(manifest.fixtures.count, 12)
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.fingerprintVersion, 1)
        XCTAssertEqual(manifest.seed, 42)

        for entry in manifest.fixtures where entry.file.contains("-v2.json") {
            let bytes = try resourceData(file: entry.file)
            XCTAssertEqual(
                ProductionStoryFixtureCorpus.sha256(bytes),
                expectedSHA256[entry.file],
                entry.id
            )
            XCTAssertEqual(
                ProductionStoryFixtureCorpus.sha256(bytes),
                entry.fileSHA256,
                entry.id
            )
        }
    }

    func testPlay072V3CorpusRemainsByteExact() throws {
        let manifestData = try resourceData(file: Self.play072ManifestFile)
        XCTAssertEqual(
            ProductionStoryFixtureCorpus.sha256(manifestData),
            "bb27da325a259eb4186c54a749e6eb0391731a7f277860103099813ded7fba69"
        )
        let manifest = try JSONDecoder().decode(
            ProductionStoryFixtureManifestV2.self,
            from: manifestData
        )
        XCTAssertEqual(manifest.fixtures.count, 12)
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.fingerprintVersion, 1)
        XCTAssertEqual(manifest.seed, 42)

        for entry in manifest.fixtures {
            let bytes = try resourceData(file: entry.file)
            XCTAssertEqual(
                ProductionStoryFixtureCorpus.sha256(bytes),
                entry.fileSHA256,
                entry.id
            )
            XCTAssertEqual(bytes.count, entry.byteCount, entry.id)
        }
    }

    func testCurrentCorpusMatchesTwoIndependentBuildsAndManifest() throws {
        let firstStart = ProcessInfo.processInfo.systemUptime
        let first = try ProductionStoryFixtureCorpus.build()
        let firstMilliseconds = elapsedMilliseconds(since: firstStart)
        let secondStart = ProcessInfo.processInfo.systemUptime
        let second = try ProductionStoryFixtureCorpus.build()
        let secondMilliseconds = elapsedMilliseconds(since: secondStart)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.artifacts.count, 12)
        XCTAssertEqual(first.manifest.fixtures.count, 12)
        XCTAssertEqual(Set(first.artifacts.map(\.definition.id)).count, 12)
        XCTAssertTrue(first.artifacts.allSatisfy {
            $0.definition.id.hasSuffix("-v7")
                && $0.definition.file.hasSuffix("-v7.json")
        })
        XCTAssertEqual(
            first.artifacts.filter { $0.definition.stage == .charterMidpoint }.count,
            2
        )
        XCTAssertEqual(
            first.artifacts.filter { $0.definition.stage == .regionalCapital }.count,
            4
        )
        XCTAssertLessThan(firstMilliseconds, 20_000)
        XCTAssertLessThan(secondMilliseconds, 20_000)

        let committedManifestData = try resourceData(file: Self.currentManifestFile)
        XCTAssertEqual(committedManifestData, first.manifestData)
        let committedManifest = try JSONDecoder().decode(
            ProductionStoryFixtureManifestV2.self,
            from: committedManifestData
        )
        XCTAssertEqual(committedManifest, first.manifest)
        XCTAssertEqual(committedManifest.schemaVersion, 1)
        XCTAssertEqual(committedManifest.fingerprintVersion, 1)
        XCTAssertEqual(committedManifest.seed, 42)

        for artifact in first.artifacts {
            let committedBytes = try resourceData(file: artifact.definition.file)
            let entry = try XCTUnwrap(
                committedManifest.fixtures.first { $0.id == artifact.definition.id }
            )
            XCTAssertEqual(committedBytes, artifact.bytes, artifact.definition.id)
            XCTAssertEqual(
                ProductionStoryFixtureCorpus.sha256(committedBytes),
                entry.fileSHA256,
                artifact.definition.id
            )
            XCTAssertEqual(entry.expectedStateDigest, artifact.fingerprint.digest)
            XCTAssertEqual(entry.spatialDigest, artifact.spatialDigest)
            XCTAssertEqual(entry.byteCount, committedBytes.count)
            XCTAssertEqual(entry.strategy, artifact.definition.strategy)
            XCTAssertEqual(entry.stage, artifact.definition.stage)
            XCTAssertEqual(entry.phase, artifact.definition.phase)
            XCTAssertEqual(entry.secondActPhase, artifact.definition.secondActPhase)
            XCTAssertEqual(entry.resolution, artifact.definition.resolution)
            XCTAssertEqual(entry.status, artifact.definition.status)
            XCTAssertTrue(
                artifact.state.messages.contains {
                    $0.title == artifact.definition.messageTitle
                },
                artifact.definition.id
            )
            XCTAssertEqual(
                Set(try (0..<5).map { _ in
                    try CityStateFingerprinter.fingerprint(artifact.state).digest
                }),
                Set([entry.expectedStateDigest]),
                artifact.definition.id
            )
        }

        print(
            "PLAY078_STORY_CORPUS generation_one_ms=\(metric(firstMilliseconds)) " +
            "generation_two_ms=\(metric(secondMilliseconds)) fixtures=12"
        )
    }

    @MainActor
    func testCurrentPrimaryAndCorruptPrimaryBackupLoadPausedWithImmutableSnapshots() throws {
        let manifest = try currentManifest()

        for entry in manifest.fixtures {
            let bytes = try resourceData(file: entry.file)
            try withTemporaryRoot(id: "\(entry.id)-primary") { root in
                let service = SaveGameService(rootURL: root)
                try FileManager.default.createDirectory(
                    at: root,
                    withIntermediateDirectories: true
                )
                try bytes.write(to: service.saveURL, options: .atomic)

                let direct = try service.load()
                XCTAssertEqual(direct.source, .primary, entry.id)
                XCTAssertEqual(direct.schemaVersion, 1, entry.id)
                XCTAssertEqual(direct.fingerprint.version, 1, entry.id)
                XCTAssertEqual(direct.fingerprint.digest, entry.expectedStateDigest, entry.id)
                XCTAssertEqual(
                    ProductionStoryFixtureCorpus.spatialDigest(
                        try CityPresentationSnapshot(state: direct.state).spatialConsequences
                    ),
                    entry.spatialDigest,
                    entry.id
                )

                let store = preparedStore(saveService: service)
                XCTAssertTrue(store.canUndo, entry.id)
                store.speed = .fastest
                XCTAssertTrue(store.perform(.loadCity), entry.id)
                try store.selectNewestCheckpointForTesting()
                XCTAssertEqual(
                    store.sessionReplacementConfirmation?.action,
                    .loadQuicksave,
                    entry.id
                )
                XCTAssertTrue(store.confirmSessionReplacement(), entry.id)
                XCTAssertEqual(store.state, direct.state, entry.id)
                XCTAssertEqual(store.speed, .paused, entry.id)
                XCTAssertFalse(store.canUndo, entry.id)
                XCTAssertEqual(
                    store.lastFeedback,
                    CityPersistenceFeedbackPresentation.loaded(
                        direct.state,
                        recoveredFromBackup: false
                    ).message,
                    entry.id
                )
                XCTAssertEqual(try Data(contentsOf: service.saveURL), bytes, entry.id)

                let snapshot = try CityPresentationSnapshot(state: store.state)
                let frozenState = snapshot.state
                let frozenFingerprint = snapshot.fingerprint
                let frozenSecondActPhase = snapshot.analytics.secondActPhase
                let frozenRegionalStatus = snapshot.analytics.regionalCapitalStatusText
                let frozenSpatial = snapshot.spatialConsequences
                store.state.treasury += 1
                XCTAssertEqual(snapshot.state, frozenState, entry.id)
                XCTAssertEqual(snapshot.fingerprint, frozenFingerprint, entry.id)
                XCTAssertEqual(snapshot.analytics.secondActPhase, frozenSecondActPhase, entry.id)
                XCTAssertEqual(
                    snapshot.analytics.regionalCapitalStatusText,
                    frozenRegionalStatus,
                    entry.id
                )
                XCTAssertEqual(snapshot.spatialConsequences, frozenSpatial, entry.id)
            }

            try withTemporaryRoot(id: "\(entry.id)-backup") { root in
                let service = SaveGameService(rootURL: root)
                try FileManager.default.createDirectory(
                    at: root,
                    withIntermediateDirectories: true
                )
                try bytes.write(to: service.backupURL, options: .atomic)
                let corruptBytes = Data("{\"invalid\":true}".utf8)
                try corruptBytes.write(to: service.saveURL, options: .atomic)

                let direct = try service.load()
                XCTAssertEqual(direct.source, .backup, entry.id)
                XCTAssertTrue(direct.recoveredFromBackup, entry.id)
                XCTAssertEqual(direct.fingerprint.digest, entry.expectedStateDigest, entry.id)
                XCTAssertEqual(try Data(contentsOf: service.saveURL), corruptBytes, entry.id)

                let store = preparedStore(saveService: service)
                store.speed = .fastest
                XCTAssertTrue(store.perform(.loadCity), entry.id)
                try store.selectNewestCheckpointForTesting()
                XCTAssertEqual(
                    store.sessionReplacementConfirmation?.action,
                    .loadQuicksave,
                    entry.id
                )
                XCTAssertTrue(store.confirmSessionReplacement(), entry.id)
                XCTAssertEqual(store.state, direct.state, entry.id)
                XCTAssertEqual(store.speed, .paused, entry.id)
                XCTAssertFalse(store.canUndo, entry.id)
                XCTAssertEqual(
                    store.lastFeedback,
                    CityPersistenceFeedbackPresentation.loaded(
                        direct.state,
                        recoveredFromBackup: true
                    ).message,
                    entry.id
                )
                XCTAssertEqual(try Data(contentsOf: service.saveURL), corruptBytes, entry.id)
                XCTAssertEqual(try Data(contentsOf: service.backupURL), bytes, entry.id)
            }
        }
    }

    @MainActor
    func testReplayUndoAndTerminalBoundariesMatchEveryCurrentStoryIdentity() throws {
        let artifacts = try committedArtifacts()
        let builder = ProductionStoryStateBuilder()

        for strategy in [CityStrategy.commercialStewardship, .industrialExpansion] {
            let opening = try artifact(strategy: strategy, stage: .opening, in: artifacts)
            let complication = try artifact(
                strategy: strategy,
                stage: .complication,
                in: artifacts
            )
            let recovery = try artifact(strategy: strategy, stage: .recovery, in: artifacts)
            let midpoint = try artifact(
                strategy: strategy,
                stage: .charterMidpoint,
                in: artifacts
            )

            XCTAssertEqual(
                try builder.replayOpeningToComplication(
                    opening.state,
                    strategy: strategy
                ),
                complication.state
            )
            XCTAssertEqual(
                try builder.replayComplicationToRecovery(
                    complication.state,
                    strategy: strategy
                ),
                recovery.state
            )
            XCTAssertEqual(
                try builder.replayRecoveryToCharterMidpoint(
                    recovery.state,
                    strategy: strategy
                ),
                midpoint.state
            )

            for artifact in [opening, complication, recovery, midpoint] {
                let store = CityGameStore(state: artifact.state)
                let before = store.state
                let beforeFingerprint = try CityStateFingerprinter.fingerprint(before)
                let (kind, coordinate) = try undoableBuild(in: before)
                store.selectTool(kind)
                store.primaryAction(at: coordinate)
                XCTAssertTrue(store.canUndo, artifact.definition.id)
                XCTAssertNotEqual(store.state, before, artifact.definition.id)
                store.undoLastAction()
                XCTAssertEqual(store.state, before, artifact.definition.id)
                XCTAssertEqual(
                    try CityStateFingerprinter.fingerprint(store.state),
                    beforeFingerprint,
                    artifact.definition.id
                )
            }
        }

        for resolution in resolutions {
            let terminal = try artifact(
                resolution: resolution,
                stage: .regionalCapital,
                in: artifacts
            )
            XCTAssertEqual(
                try builder.regionalCapitalTerminal(resolvedBy: resolution),
                terminal.state,
                terminal.definition.id
            )
            let terminalStore = CityGameStore(state: terminal.state)
            XCTAssertEqual(terminalStore.speed, .paused)
            XCTAssertFalse(terminalStore.canUndo)
            XCTAssertFalse(terminalStore.perform(.undo))
            var attempted = terminal.state
            XCTAssertEqual(
                CitySimulationCommandExecutor.apply(
                    .advanceOneDailyBoundary,
                    to: &attempted
                ),
                .rejected(.simulationNotPlaying)
            )
            XCTAssertEqual(attempted, terminal.state)
        }
    }

    func testCurrentIdentityAndExistingBudgetsRemainFrozen() throws {
        let manifest = try currentManifest()
        let retainedSpatialBytes =
            MemoryLayout<CitySpatialConsequence>.stride * 24 * 24
        XCTAssertLessThanOrEqual(retainedSpatialBytes, 128 * 1_024)

        for entry in manifest.fixtures {
            let bytes = try resourceData(file: entry.file)
            try withTemporaryRoot(id: "\(entry.id)-budgets") { root in
                let service = SaveGameService(rootURL: root)
                let state = try decodedState(from: bytes, using: service)
                let analytics = CityAnalytics(state: state)

                XCTAssertEqual(
                    state.progression?.strategy?.committedStrategy,
                    entry.strategy,
                    entry.id
                )
                XCTAssertEqual(
                    state.progression?.strategy?.currentPhase,
                    entry.phase,
                    entry.id
                )
                XCTAssertEqual(
                    state.progression?.strategy?.recoveryResolution,
                    entry.resolution,
                    entry.id
                )
                XCTAssertEqual(analytics.strategyRecoveryResolution, entry.resolution, entry.id)
                XCTAssertEqual(analytics.committedStrategy, entry.strategy, entry.id)
                XCTAssertEqual(analytics.strategyPhase, entry.phase, entry.id)
                XCTAssertEqual(state.progression?.secondAct?.phase, entry.secondActPhase, entry.id)
                XCTAssertEqual(state.status, entry.status, entry.id)
                XCTAssertEqual(state.tick, entry.tick, entry.id)

                switch entry.stage {
                case .opening, .complication, .recovery:
                    XCTAssertNil(state.progression?.secondAct, entry.id)
                    XCTAssertFalse(state.progression?.townCharterAwarded ?? true, entry.id)
                case .charterMidpoint:
                    XCTAssertTrue(state.progression?.townCharterAwarded ?? false, entry.id)
                    XCTAssertEqual(state.progression?.secondAct?.phase, .mandate, entry.id)
                    XCTAssertFalse(
                        state.progression?.secondAct?.regionalCapitalAwarded ?? true,
                        entry.id
                    )
                    XCTAssertEqual(state.status, .playing, entry.id)
                case .regionalCapital:
                    XCTAssertTrue(state.progression?.townCharterAwarded ?? false, entry.id)
                    XCTAssertTrue(
                        state.progression?.secondAct?.regionalCapitalAwarded ?? false,
                        entry.id
                    )
                    XCTAssertEqual(state.progression?.secondAct?.qualifyingCycles, 12, entry.id)
                    XCTAssertEqual(
                        state.messages.filter { $0.title == "Regional Capital Recognized" }.count,
                        1,
                        entry.id
                    )
                    XCTAssertEqual(state.status, .won, entry.id)
                }

                let fingerprintStart = ProcessInfo.processInfo.systemUptime
                let fingerprint = try CityStateFingerprinter.fingerprint(state)
                let fingerprintMilliseconds = elapsedMilliseconds(since: fingerprintStart)
                let snapshotStart = ProcessInfo.processInfo.systemUptime
                let snapshot = try CityPresentationSnapshot(state: state)
                let snapshotMilliseconds = elapsedMilliseconds(since: snapshotStart)
                let saveStart = ProcessInfo.processInfo.systemUptime
                let write = try service.save(state)
                let saveMilliseconds = elapsedMilliseconds(since: saveStart)
                let loadStart = ProcessInfo.processInfo.systemUptime
                let load = try service.load()
                let loadMilliseconds = elapsedMilliseconds(since: loadStart)

                XCTAssertEqual(fingerprint.version, 1, entry.id)
                XCTAssertEqual(fingerprint.digest, entry.expectedStateDigest, entry.id)
                XCTAssertEqual(write.schemaVersion, 1, entry.id)
                XCTAssertEqual(write.fingerprint, fingerprint, entry.id)
                XCTAssertEqual(load.schemaVersion, 1, entry.id)
                XCTAssertEqual(load.state, state, entry.id)
                XCTAssertEqual(load.fingerprint, fingerprint, entry.id)
                XCTAssertEqual(snapshot.fingerprint, fingerprint, entry.id)
                XCTAssertEqual(
                    ProductionStoryFixtureCorpus.spatialDigest(
                        snapshot.spatialConsequences
                    ),
                    entry.spatialDigest,
                    entry.id
                )
                XCTAssertEqual(try Data(contentsOf: service.saveURL), bytes, entry.id)
                XCTAssertEqual(bytes.count, entry.byteCount, entry.id)
                XCTAssertLessThan(bytes.count, 2_000_000, entry.id)
                XCTAssertLessThan(fingerprintMilliseconds, 500, entry.id)
                XCTAssertLessThan(snapshotMilliseconds, 500, entry.id)
                XCTAssertLessThan(saveMilliseconds, 1_500, entry.id)
                XCTAssertLessThan(loadMilliseconds, 1_500, entry.id)

                print(
                    "PLAY078_STORY_FIXTURE id=\(entry.id) tick=\(entry.tick) " +
                    "bytes=\(entry.byteCount) digest=\(entry.expectedStateDigest) " +
                    "spatial=\(entry.spatialDigest) " +
                    "fingerprint_ms=\(metric(fingerprintMilliseconds)) " +
                    "snapshot_ms=\(metric(snapshotMilliseconds)) " +
                    "save_ms=\(metric(saveMilliseconds)) " +
                    "load_ms=\(metric(loadMilliseconds))"
                )
            }
        }

        let authenticLegacy: [(file: String, sha256: String, schema: Int, digest: String)] = [
            (
                "strategy-legacy-schema0-v1.json",
                "28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908",
                0,
                "b7608f0aa748f5b40086d59ffeba746908599780f791b6483d6c613e80dedeb5"
            ),
            (
                "strategy-legacy-schema1-envelope-v1.json",
                "56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9",
                1,
                "947b383684145d6d18738f313fec4f648861680165134f33b4f65ad42e5c0e3f"
            ),
        ]
        for fixture in authenticLegacy {
            let bytes = try legacyResourceData(file: fixture.file)
            XCTAssertEqual(
                ProductionStoryFixtureCorpus.sha256(bytes),
                fixture.sha256,
                fixture.file
            )
            try withTemporaryRoot(id: fixture.file) { root in
                let service = SaveGameService(rootURL: root)
                let state = try decodedState(from: bytes, using: service)
                let load = try service.load()
                XCTAssertEqual(load.schemaVersion, fixture.schema, fixture.file)
                XCTAssertEqual(load.fingerprint.version, 1, fixture.file)
                XCTAssertEqual(load.fingerprint.digest, fixture.digest, fixture.file)
                XCTAssertNil(state.progression?.strategy, fixture.file)
                XCTAssertNil(state.progression?.secondAct, fixture.file)
            }
        }
    }

    private func currentManifest() throws -> ProductionStoryFixtureManifestV2 {
        try JSONDecoder().decode(
            ProductionStoryFixtureManifestV2.self,
            from: resourceData(file: Self.currentManifestFile)
        )
    }

    private func committedArtifacts() throws -> [ProductionStoryFixtureArtifact] {
        let generated = try ProductionStoryFixtureCorpus.build()
        return try generated.artifacts.map { artifact in
            let bytes = try resourceData(file: artifact.definition.file)
            return ProductionStoryFixtureArtifact(
                definition: artifact.definition,
                state: try loadState(from: bytes, id: artifact.definition.id),
                fingerprint: artifact.fingerprint,
                spatialDigest: artifact.spatialDigest,
                bytes: bytes,
                fileSHA256: ProductionStoryFixtureCorpus.sha256(bytes)
            )
        }
    }

    private func artifact(
        strategy: CityStrategy? = nil,
        resolution: CityStrategyRecoveryResolution? = nil,
        stage: ProductionStoryStage,
        in artifacts: [ProductionStoryFixtureArtifact]
    ) throws -> ProductionStoryFixtureArtifact {
        try XCTUnwrap(
            artifacts.first {
                (strategy == nil || $0.definition.strategy == strategy)
                    && (resolution == nil || $0.definition.resolution == resolution)
                    && $0.definition.stage == stage
            }
        )
    }

    @MainActor
    private func preparedStore(saveService: SaveGameService) -> CityGameStore {
        let store = CityGameStore(
            state: .newCity(seed: 42),
            saveService: saveService
        )
        store.selectTool(.commercial)
        store.primaryAction(at: GridCoordinate(x: 4, y: 8))
        return store
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
        throw ProductionStoryFixtureError.commandRejected(
            "no deterministic undoable build"
        )
    }

    private func loadState(from bytes: Data, id: String) throws -> CityGameState {
        try withTemporaryRootReturning(id: id) { root in
            let service = SaveGameService(rootURL: root)
            return try decodedState(from: bytes, using: service)
        }
    }

    private func decodedState(
        from bytes: Data,
        using service: SaveGameService
    ) throws -> CityGameState {
        try FileManager.default.createDirectory(
            at: service.rootURL,
            withIntermediateDirectories: true
        )
        try bytes.write(to: service.saveURL, options: .atomic)
        return try service.load().state
    }

    private func resourceData(file: String) throws -> Data {
        let name = String(file.dropLast(".json".count))
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: name,
                withExtension: "json",
                subdirectory: Self.fixtureSubdirectory
            )
        )
        return try Data(contentsOf: url)
    }

    private func legacyResourceData(file: String) throws -> Data {
        let name = String(file.dropLast(".json".count))
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: name,
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        return try Data(contentsOf: url)
    }

    private func withTemporaryRoot(
        id: String,
        _ body: (URL) throws -> Void
    ) throws {
        try withTemporaryRootReturning(id: id) { root in
            try body(root)
        }
    }

    private func withTemporaryRootReturning<T>(
        id: String,
        _ body: (URL) throws -> T
    ) throws -> T {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "citysim-play069-\(id)-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        return try body(root)
    }

    private func elapsedMilliseconds(since start: TimeInterval) -> Double {
        (ProcessInfo.processInfo.systemUptime - start) * 1_000
    }

    private func metric(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
