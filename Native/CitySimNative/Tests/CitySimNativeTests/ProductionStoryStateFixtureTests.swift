import Foundation
import XCTest
@testable import CitySimNative

final class ProductionStoryStateFixtureTests: XCTestCase {
    private static let fixtureSubdirectory = "Fixtures/StoryStates"
    private static let manifestFile = "story-states-manifest-v1.json"

    func testWriteFixtureCorpusOnlyWhenExplicitlyRequested() throws {
        guard let rootPath = ProcessInfo.processInfo.environment[
            "CITYSIM_PLAY047_WRITE_FIXTURES"
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
            "PLAY047_FIXTURE_WRITE root=\(root.path) fixtures=\(first.artifacts.count) " +
            "manifest=\(Self.manifestFile)"
        )
    }

    func testFrozenCorpusMatchesTwoIndependentBuildsAndManifest() throws {
        let firstStart = ProcessInfo.processInfo.systemUptime
        let first = try ProductionStoryFixtureCorpus.build()
        let firstMilliseconds = elapsedMilliseconds(since: firstStart)
        let secondStart = ProcessInfo.processInfo.systemUptime
        let second = try ProductionStoryFixtureCorpus.build()
        let secondMilliseconds = elapsedMilliseconds(since: secondStart)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.artifacts.count, 8)
        XCTAssertEqual(first.manifest.fixtures.count, 8)
        XCTAssertEqual(Set(first.artifacts.map(\.definition.id)).count, 8)
        XCTAssertLessThan(firstMilliseconds, 10_000)
        XCTAssertLessThan(secondMilliseconds, 10_000)

        let committedManifestData = try resourceData(file: Self.manifestFile)
        XCTAssertEqual(committedManifestData, first.manifestData)
        let committedManifest = try JSONDecoder().decode(
            ProductionStoryFixtureManifest.self,
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
            XCTAssertEqual(entry.moment, artifact.definition.moment)
            XCTAssertEqual(entry.phase, artifact.definition.phase)
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
            "PLAY047_CORPUS generation_one_ms=\(metric(firstMilliseconds)) " +
            "generation_two_ms=\(metric(secondMilliseconds)) fixtures=8"
        )
    }

    @MainActor
    func testPrimaryAndBackupFixturesLoadPausedWithExactImmutableSnapshots() throws {
        let manifest = try committedManifest()

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
                XCTAssertEqual(store.state, direct.state, entry.id)
                XCTAssertEqual(store.speed, .paused, entry.id)
                XCTAssertFalse(store.canUndo, entry.id)
                XCTAssertEqual(store.lastFeedback, "City loaded · Simulation paused", entry.id)
                XCTAssertEqual(try Data(contentsOf: service.saveURL), bytes, entry.id)

                let snapshot = try CityPresentationSnapshot(state: store.state)
                let frozenState = snapshot.state
                let frozenFingerprint = snapshot.fingerprint
                let frozenSpatial = snapshot.spatialConsequences
                store.state.treasury += 1
                XCTAssertEqual(snapshot.state, frozenState, entry.id)
                XCTAssertEqual(snapshot.fingerprint, frozenFingerprint, entry.id)
                XCTAssertEqual(snapshot.spatialConsequences, frozenSpatial, entry.id)
            }

            try withTemporaryRoot(id: "\(entry.id)-backup") { root in
                let service = SaveGameService(rootURL: root)
                try FileManager.default.createDirectory(
                    at: root,
                    withIntermediateDirectories: true
                )
                try bytes.write(to: service.backupURL, options: .atomic)

                let direct = try service.load()
                XCTAssertEqual(direct.source, .backup, entry.id)
                XCTAssertTrue(direct.recoveredFromBackup, entry.id)
                XCTAssertEqual(direct.fingerprint.digest, entry.expectedStateDigest, entry.id)

                let store = preparedStore(saveService: service)
                XCTAssertTrue(store.canUndo, entry.id)
                store.speed = .fastest
                XCTAssertTrue(store.perform(.loadCity), entry.id)
                XCTAssertEqual(store.state, direct.state, entry.id)
                XCTAssertEqual(store.speed, .paused, entry.id)
                XCTAssertFalse(store.canUndo, entry.id)
                XCTAssertEqual(
                    store.lastFeedback,
                    "Recovered last known-good city · Simulation paused",
                    entry.id
                )
                XCTAssertFalse(FileManager.default.fileExists(atPath: service.saveURL.path))
                XCTAssertEqual(try Data(contentsOf: service.backupURL), bytes, entry.id)
            }
        }
    }

    @MainActor
    func testReplayAndUndoBoundariesMatchEveryFrozenStoryMoment() throws {
        let artifacts = try committedArtifacts()
        let builder = ProductionStoryStateBuilder()

        for strategy in [CityStrategy.commercialStewardship, .industrialExpansion] {
            let opening = try artifact(
                strategy: strategy,
                moment: .opening,
                in: artifacts
            )
            let complication = try artifact(
                strategy: strategy,
                moment: .complication,
                in: artifacts
            )
            let recovery = try artifact(
                strategy: strategy,
                moment: .recovery,
                in: artifacts
            )
            let victory = try artifact(
                strategy: strategy,
                moment: .charterVictory,
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
                try builder.replayRecoveryToVictory(
                    recovery.state,
                    strategy: strategy
                ),
                victory.state
            )

            for artifact in [opening, complication, recovery] {
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

            let terminalStore = CityGameStore(state: victory.state)
            let terminal = terminalStore.state
            XCTAssertEqual(terminalStore.speed, .paused)
            XCTAssertFalse(terminalStore.canUndo)
            XCTAssertFalse(terminalStore.perform(.undo))
            XCTAssertEqual(terminalStore.state, terminal)
            var attempted = terminal
            XCTAssertEqual(
                CitySimulationCommandExecutor.apply(
                    .advanceOneDailyBoundary,
                    to: &attempted
                ),
                .rejected(.simulationNotPlaying)
            )
            XCTAssertEqual(attempted, terminal)
        }
    }

    func testFixtureIdentityLegacyCompatibilityAndBudgetsRemainFrozen() throws {
        let manifest = try committedManifest()
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
                XCTAssertEqual(
                    analytics.strategyRecoveryResolution,
                    entry.resolution,
                    entry.id
                )
                XCTAssertEqual(analytics.committedStrategy, entry.strategy, entry.id)
                XCTAssertEqual(analytics.strategyPhase, entry.phase, entry.id)
                XCTAssertEqual(state.status, entry.status, entry.id)
                XCTAssertEqual(state.tick, entry.tick, entry.id)
                XCTAssertEqual(
                    entry.status == .won,
                    state.progression?.townCharterAwarded == true,
                    entry.id
                )

                let fingerprintStart = ProcessInfo.processInfo.systemUptime
                let fingerprint = try CityStateFingerprinter.fingerprint(state)
                let fingerprintMilliseconds = elapsedMilliseconds(
                    since: fingerprintStart
                )
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
                    "PLAY047_FIXTURE id=\(entry.id) tick=\(entry.tick) " +
                    "bytes=\(entry.byteCount) digest=\(entry.expectedStateDigest) " +
                    "spatial=\(entry.spatialDigest) " +
                    "fingerprint_ms=\(metric(fingerprintMilliseconds)) " +
                    "snapshot_ms=\(metric(snapshotMilliseconds)) " +
                    "save_ms=\(metric(saveMilliseconds)) " +
                    "load_ms=\(metric(loadMilliseconds))"
                )
            }
        }

        let legacy: [(file: String, sha256: String, schema: Int, digest: String)] = [
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
        for fixture in legacy {
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
            }
        }
    }

    private func committedManifest() throws -> ProductionStoryFixtureManifest {
        try JSONDecoder().decode(
            ProductionStoryFixtureManifest.self,
            from: resourceData(file: Self.manifestFile)
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
        strategy: CityStrategy,
        moment: ProductionStoryMoment,
        in artifacts: [ProductionStoryFixtureArtifact]
    ) throws -> ProductionStoryFixtureArtifact {
        try XCTUnwrap(
            artifacts.first {
                $0.definition.strategy == strategy
                    && $0.definition.moment == moment
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
        store.primaryAction(at: GridCoordinate(x: 8, y: 11))
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
            path: "citysim-play047-\(id)-\(UUID().uuidString)",
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
