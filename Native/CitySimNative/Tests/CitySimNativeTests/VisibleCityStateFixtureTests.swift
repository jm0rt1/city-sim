import Foundation
import XCTest
@testable import CitySimNative

final class VisibleCityStateFixtureTests: XCTestCase {
    private static let fixtureSubdirectory = "Fixtures/VisibleCityStates"
    private static let manifestFile = "visible-city-states-manifest-v6.json"
    private static let play072ManifestFile = "visible-city-states-manifest-v2.json"
    private static let e380ManifestFile = "visible-city-states-manifest-v1.json"

    func testWriteFixtureCorpusOnlyWhenExplicitlyRequested() throws {
        guard let rootPath = ProcessInfo.processInfo.environment[
            "CITYSIM_PLAY078_WRITE_FIXTURES"
        ],
        !rootPath.isEmpty else {
            return
        }
        let first = try VisibleCityFixtureCorpus.build()
        let second = try VisibleCityFixtureCorpus.build()
        XCTAssertEqual(first, second)
        let root = URL(filePath: rootPath, directoryHint: .isDirectory)
        try first.write(to: root)
        print(
            "PLAY078_FIXTURE_WRITE root=\(root.path) " +
            "fixtures=\(first.artifacts.count) manifest=\(Self.manifestFile)"
        )
    }

    func testMatrixMatchesTwoIndependentBuildsAndFrozenManifest() throws {
        let firstStart = ProcessInfo.processInfo.systemUptime
        let first = try VisibleCityFixtureCorpus.build()
        let firstMilliseconds = elapsedMilliseconds(since: firstStart)
        let secondStart = ProcessInfo.processInfo.systemUptime
        let second = try VisibleCityFixtureCorpus.build()
        let secondMilliseconds = elapsedMilliseconds(since: secondStart)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.artifacts.count, 14)
        XCTAssertEqual(first.manifest.fixtures.count, 14)
        XCTAssertEqual(Set(first.artifacts.map(\.definition.id)).count, 14)
        XCTAssertTrue(first.artifacts.allSatisfy {
            $0.definition.id.hasSuffix("-v6")
                && $0.definition.file.hasSuffix("-v6.json")
        })
        for strategy in [CityStrategy.commercialStewardship, .industrialExpansion] {
            XCTAssertEqual(
                first.artifacts.filter {
                    $0.definition.strategy == strategy
                }.map(\.definition.lifecycle),
                VisibleCityLifecycle.allCases
            )
        }
        XCTAssertLessThan(firstMilliseconds, 20_000)
        XCTAssertLessThan(secondMilliseconds, 20_000)

        let committedManifestData = try resourceData(file: Self.manifestFile)
        XCTAssertEqual(committedManifestData, first.manifestData)
        let committedManifest = try JSONDecoder().decode(
            VisibleCityFixtureManifest.self,
            from: committedManifestData
        )
        XCTAssertEqual(committedManifest, first.manifest)
        XCTAssertEqual(
            committedManifest.authorityCommit,
            VisibleCityFixtureCorpus.authorityCommit
        )
        XCTAssertEqual(
            committedManifest.sourceStoryManifestSHA256,
            VisibleCityFixtureCorpus.sourceStoryManifestSHA256
        )
        XCTAssertEqual(committedManifest.schemaVersion, 1)
        XCTAssertEqual(committedManifest.fingerprintVersion, 1)
        XCTAssertEqual(committedManifest.seed, 42)

        for artifact in first.artifacts {
            let entry = try XCTUnwrap(
                committedManifest.fixtures.first {
                    $0.id == artifact.definition.id
                }
            )
            let committedBytes = try resourceData(file: entry.file)
            XCTAssertEqual(committedBytes, artifact.bytes, entry.id)
            XCTAssertEqual(
                ProductionStoryFixtureCorpus.sha256(committedBytes),
                entry.fileSHA256,
                entry.id
            )
            XCTAssertEqual(entry.expectedStateDigest, artifact.fingerprint.digest)
            XCTAssertEqual(entry.spatialDigest, artifact.spatialDigest)
            XCTAssertEqual(entry.diagnosticDigest, artifact.diagnosticDigest)
            XCTAssertEqual(entry.activityDigest, artifact.activityDigest)
            XCTAssertEqual(entry.byteCount, committedBytes.count)
            XCTAssertEqual(entry.focusCoordinate, artifact.definition.focusCoordinate)
            XCTAssertEqual(entry.focusKind, artifact.definition.focusKind)
            XCTAssertEqual(
                entry.strategyDistrictKind,
                artifact.definition.strategyDistrictKind
            )
            XCTAssertEqual(
                Set(try (0..<5).map { _ in
                    try CityStateFingerprinter.fingerprint(artifact.state).digest
                }),
                Set([entry.expectedStateDigest]),
                entry.id
            )
            print(
                "PLAY078_MATRIX id=\(entry.id) tick=\(entry.tick) " +
                "state=\(entry.expectedStateDigest) spatial=\(entry.spatialDigest) " +
                "diagnostics=\(entry.diagnosticDigest) activity=\(entry.activityDigest) " +
                "file=\(entry.fileSHA256) bytes=\(entry.byteCount)"
            )
        }
        print(
            "PLAY078_CORPUS generation_one_ms=\(metric(firstMilliseconds)) " +
            "generation_two_ms=\(metric(secondMilliseconds)) fixtures=14"
        )
    }

    func testE380ComparisonCorpusRemainsByteExact() throws {
        let manifestData = try resourceData(file: Self.e380ManifestFile)
        XCTAssertEqual(
            ProductionStoryFixtureCorpus.sha256(manifestData),
            "e9ee17bc14a5d61334a9598bddb5d25bc1cfe0cb12443f0b08cb6100526af236"
        )
        let manifest = try JSONDecoder().decode(
            VisibleCityFixtureManifest.self,
            from: manifestData
        )
        XCTAssertEqual(
            manifest.authorityCommit,
            "e38059e721dae05c8df421754e3cb63ddf3fa153"
        )
        XCTAssertEqual(
            manifest.sourceStoryManifestSHA256,
            "a793dc9ea5cfc50b7482fb7f4bf4e7a3a3c5e9cfb1cad6e47722fc17cbf22153"
        )
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.fingerprintVersion, 1)
        XCTAssertEqual(manifest.fixtures.count, 14)

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

    func testPlay072V2CorpusRemainsByteExact() throws {
        let manifestData = try resourceData(file: Self.play072ManifestFile)
        XCTAssertEqual(
            ProductionStoryFixtureCorpus.sha256(manifestData),
            "babc84514ccae064f3d1b856868ef14a4bc0d54e3477597b24e41349601a5eeb"
        )
        let manifest = try JSONDecoder().decode(
            VisibleCityFixtureManifest.self,
            from: manifestData
        )
        XCTAssertEqual(manifest.fixtures.count, 14)
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

    func testLifecycleInvariantsAndExactReplayRemainAuthoritative() throws {
        let builder = ProductionStoryStateBuilder()
        let artifacts = try committedArtifacts()

        for strategy in [CityStrategy.commercialStewardship, .industrialExpansion] {
            let vacant = try artifact(.vacant, strategy: strategy, in: artifacts)
            let construction = try artifact(
                .construction,
                strategy: strategy,
                in: artifacts
            )
            let active = try artifact(.active, strategy: strategy, in: artifacts)
            let pressured = try artifact(.pressured, strategy: strategy, in: artifacts)
            let recovering = try artifact(
                .recovering,
                strategy: strategy,
                in: artifacts
            )
            let upgraded = try artifact(.upgraded, strategy: strategy, in: artifacts)
            let terminal = try artifact(.terminal, strategy: strategy, in: artifacts)
            let focus = vacant.definition.focusCoordinate
            let kind = vacant.definition.strategyDistrictKind
            let resolution = defaultResolution(for: strategy)

            XCTAssertEqual(vacant.state.tile(at: focus)?.kind, .empty)
            XCTAssertEqual(vacant.definition.focusKind, .empty)

            var replayConstruction = vacant.state
            if case .failure(let rejection) = CitySimulation.build(
                kind,
                at: focus,
                in: &replayConstruction
            ) {
                XCTFail("Rejected \(kind.rawValue): \(rejection)")
            }
            XCTAssertEqual(replayConstruction, construction.state)
            XCTAssertEqual(construction.state.tile(at: focus)?.kind, kind)
            XCTAssertEqual(construction.state.tile(at: focus)?.constructionProgress, 0)

            var replayActive = construction.state
            for _ in 0..<4 { CitySimulation.step(&replayActive) }
            XCTAssertEqual(replayActive, active.state)
            XCTAssertEqual(active.state.tile(at: focus)?.constructionProgress, 1)
            XCTAssertGreaterThan(active.state.tile(at: focus)?.occupancy ?? 0, 0)

            let firstActComplication = try builder.replayOpeningToComplication(
                active.state,
                strategy: strategy
            )
            let firstActRecovery = try builder.replayComplicationToRecovery(
                firstActComplication,
                strategy: strategy
            )
            XCTAssertEqual(
                try builder.replayRecoveryToCharterMidpoint(
                    firstActRecovery,
                    strategy: strategy
                ),
                upgraded.state
            )
            XCTAssertEqual(upgraded.state.progression?.secondAct?.phase, .mandate)
            let upgradedFocus = upgraded.definition.focusCoordinate
            XCTAssertEqual(upgraded.definition.focusKind, kind)
            XCTAssertEqual(upgraded.state.tile(at: upgradedFocus)?.kind, kind)
            XCTAssertGreaterThan(
                upgraded.state.tile(at: upgradedFocus)?.level ?? 0,
                1
            )
            XCTAssertEqual(
                upgraded.state.tile(at: upgradedFocus)?.constructionProgress,
                1
            )

            XCTAssertEqual(
                try builder.replayCharterMidpointToRegionalRecovery(
                    upgraded.state,
                    resolution: resolution
                ),
                pressured.state
            )
            XCTAssertEqual(pressured.state.progression?.secondAct?.phase, .recovery)
            XCTAssertEqual(pressured.definition.focusCoordinate, recovering.definition.focusCoordinate)
            XCTAssertEqual(pressured.state.tile(at: pressured.definition.focusCoordinate)?.kind, kind)
            XCTAssertLessThan(
                pressured.state.tile(at: pressured.definition.focusCoordinate)?.condition ?? 1,
                0.4
            )
            XCTAssertEqual(
                pressured.state.tiles.filter {
                    $0.kind == kind && $0.condition < 0.75
                }.count,
                2
            )

            XCTAssertEqual(
                try builder.replayRegionalRecoveryToQualification(
                    pressured.state,
                    resolution: resolution
                ),
                recovering.state
            )
            XCTAssertEqual(recovering.state.progression?.secondAct?.phase, .qualification)
            let recoveringCondition =
                recovering.state.tile(at: recovering.definition.focusCoordinate)?.condition ?? 1
            XCTAssertGreaterThanOrEqual(recoveringCondition, 0.4)
            XCTAssertLessThan(recoveringCondition, 0.75)
            XCTAssertEqual(
                recovering.state.tiles.filter {
                    $0.kind == kind
                        && $0.condition >= 0.4
                        && $0.condition < 0.75
                }.count,
                1
            )
            XCTAssertFalse(recovering.state.tiles.contains {
                $0.kind == kind && $0.condition < 0.4
            })

            XCTAssertEqual(
                try builder.replayRegionalQualificationToTerminal(
                    recovering.state,
                    resolution: resolution
                ),
                terminal.state
            )
            XCTAssertEqual(terminal.state.status, .won)
            XCTAssertEqual(terminal.state.progression?.secondAct?.phase, .completed)
            XCTAssertTrue(
                terminal.state.progression?.secondAct?.regionalCapitalAwarded ?? false
            )
            XCTAssertEqual(
                terminal.definition.focusCoordinate,
                recovering.definition.focusCoordinate
            )
            XCTAssertEqual(terminal.definition.focusKind, kind)
            XCTAssertEqual(
                terminal.state.tile(at: terminal.definition.focusCoordinate)?.kind,
                kind
            )
            XCTAssertEqual(terminal.state.tile(at: focus)?.kind, kind)
        }
    }

    @MainActor
    func testPersistenceBackupUndoSnapshotsAndBudgetsRemainExact() throws {
        let manifest = try currentManifest()
        let retainedSpatialBytes =
            MemoryLayout<CitySpatialConsequence>.stride * 24 * 24
        XCTAssertLessThanOrEqual(retainedSpatialBytes, 128 * 1_024)

        for entry in manifest.fixtures {
            let bytes = try resourceData(file: entry.file)
            try withTemporaryRoot(id: entry.id) { root in
                let service = SaveGameService(rootURL: root)
                try FileManager.default.createDirectory(
                    at: root,
                    withIntermediateDirectories: true
                )
                try bytes.write(to: service.saveURL, options: .atomic)

                let loadStart = ProcessInfo.processInfo.systemUptime
                let direct = try service.load()
                let loadMilliseconds = elapsedMilliseconds(since: loadStart)
                let fingerprintStart = ProcessInfo.processInfo.systemUptime
                let fingerprint = try CityStateFingerprinter.fingerprint(direct.state)
                let fingerprintMilliseconds = elapsedMilliseconds(since: fingerprintStart)
                let snapshotStart = ProcessInfo.processInfo.systemUptime
                let snapshot = try CityPresentationSnapshot(state: direct.state)
                let snapshotMilliseconds = elapsedMilliseconds(since: snapshotStart)

                XCTAssertEqual(direct.source, .primary, entry.id)
                XCTAssertEqual(direct.schemaVersion, 1, entry.id)
                XCTAssertEqual(fingerprint.version, 1, entry.id)
                XCTAssertEqual(fingerprint.digest, entry.expectedStateDigest, entry.id)
                XCTAssertEqual(snapshot.fingerprint, fingerprint, entry.id)
                XCTAssertEqual(
                    direct.state.tile(at: entry.focusCoordinate)?.kind,
                    entry.focusKind,
                    entry.id
                )
                XCTAssertEqual(
                    ProductionStoryFixtureCorpus.spatialDigest(
                        snapshot.spatialConsequences
                    ),
                    entry.spatialDigest,
                    entry.id
                )
                XCTAssertEqual(
                    VisibleCityFixtureCorpus.diagnosticDigest(
                        snapshot.spatialConsequences
                    ),
                    entry.diagnosticDigest,
                    entry.id
                )
                XCTAssertEqual(
                    VisibleCityFixtureCorpus.activityDigest(
                        snapshot.spatialConsequences
                    ),
                    entry.activityDigest,
                    entry.id
                )

                let store = preparedStore(saveService: service)
                store.speed = .fastest
                XCTAssertTrue(store.perform(.loadCity), entry.id)
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
                    ).message
                )

                let frozenState = snapshot.state
                let frozenFingerprint = snapshot.fingerprint
                let frozenSpatial = snapshot.spatialConsequences
                store.state.treasury += 1
                XCTAssertEqual(snapshot.state, frozenState, entry.id)
                XCTAssertEqual(snapshot.fingerprint, frozenFingerprint, entry.id)
                XCTAssertEqual(snapshot.spatialConsequences, frozenSpatial, entry.id)

                if direct.state.status == .playing {
                    let undoStore = CityGameStore(state: direct.state)
                    let (kind, coordinate) = try undoableBuild(in: direct.state)
                    undoStore.selectTool(kind)
                    undoStore.primaryAction(at: coordinate)
                    XCTAssertTrue(undoStore.canUndo, entry.id)
                    XCTAssertNotEqual(undoStore.state, direct.state, entry.id)
                    undoStore.undoLastAction()
                    XCTAssertEqual(undoStore.state, direct.state, entry.id)
                    XCTAssertEqual(
                        try CityStateFingerprinter.fingerprint(undoStore.state),
                        fingerprint,
                        entry.id
                    )
                } else {
                    var attempted = direct.state
                    XCTAssertEqual(
                        CitySimulationCommandExecutor.apply(
                            .advanceOneDailyBoundary,
                            to: &attempted
                        ),
                        .rejected(.simulationNotPlaying)
                    )
                    XCTAssertEqual(attempted, direct.state)
                }

                let saveStart = ProcessInfo.processInfo.systemUptime
                let write = try service.save(direct.state)
                let saveMilliseconds = elapsedMilliseconds(since: saveStart)
                XCTAssertEqual(write.schemaVersion, 1, entry.id)
                XCTAssertEqual(write.fingerprint, fingerprint, entry.id)
                XCTAssertEqual(try Data(contentsOf: service.saveURL), bytes, entry.id)
                XCTAssertLessThan(bytes.count, 2_000_000, entry.id)
                XCTAssertLessThan(fingerprintMilliseconds, 500, entry.id)
                XCTAssertLessThan(snapshotMilliseconds, 500, entry.id)
                XCTAssertLessThan(saveMilliseconds, 1_500, entry.id)
                XCTAssertLessThan(loadMilliseconds, 1_500, entry.id)

                try bytes.write(to: service.backupURL, options: .atomic)
                let corrupt = Data("{\"invalid\":true}".utf8)
                try corrupt.write(to: service.saveURL, options: .atomic)
                let recovered = try service.load()
                XCTAssertEqual(recovered.source, .backup, entry.id)
                XCTAssertTrue(recovered.recoveredFromBackup, entry.id)
                XCTAssertEqual(recovered.state, direct.state, entry.id)
                XCTAssertEqual(recovered.fingerprint, fingerprint, entry.id)
                XCTAssertEqual(try Data(contentsOf: service.saveURL), corrupt, entry.id)
                XCTAssertEqual(try Data(contentsOf: service.backupURL), bytes, entry.id)

                print(
                    "PLAY078_BUDGET id=\(entry.id) bytes=\(entry.byteCount) " +
                    "fingerprint_ms=\(metric(fingerprintMilliseconds)) " +
                    "snapshot_ms=\(metric(snapshotMilliseconds)) " +
                    "save_ms=\(metric(saveMilliseconds)) " +
                    "load_ms=\(metric(loadMilliseconds)) retained=\(retainedSpatialBytes)"
                )
            }
        }
    }

    func testAuthenticLegacyAndCurrentStoryCorporaRemainByteExact() throws {
        let fixtures = [
            (
                subdirectory: "Fixtures",
                file: "strategy-legacy-schema0-v1.json",
                sha256: "28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908"
            ),
            (
                subdirectory: "Fixtures",
                file: "strategy-legacy-schema1-envelope-v1.json",
                sha256: "56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9"
            ),
            (
                subdirectory: "Fixtures/StoryStates",
                file: "story-states-manifest-v1.json",
                sha256: "3614c6f7cd6eeed473c499f05a29c122aa92858744a717cc2e34bdb98f72fef0"
            ),
            (
                subdirectory: "Fixtures/StoryStates",
                file: "story-states-manifest-v2.json",
                sha256: "a793dc9ea5cfc50b7482fb7f4bf4e7a3a3c5e9cfb1cad6e47722fc17cbf22153"
            ),
            (
                subdirectory: "Fixtures/StoryStates",
                file: "story-states-manifest-v3.json",
                sha256: "bb27da325a259eb4186c54a749e6eb0391731a7f277860103099813ded7fba69"
            ),
            (
                subdirectory: "Fixtures/StoryStates",
                file: "story-states-manifest-v4.json",
                sha256: "cfbff099a9064f83cbf1a279987722191ec23acc1f03b915bba816169543003a"
            ),
        ]

        for fixture in fixtures {
            let bytes = try resourceData(
                file: fixture.file,
                subdirectory: fixture.subdirectory
            )
            XCTAssertEqual(
                ProductionStoryFixtureCorpus.sha256(bytes),
                fixture.sha256,
                fixture.file
            )
        }
    }

    private func currentManifest() throws -> VisibleCityFixtureManifest {
        try JSONDecoder().decode(
            VisibleCityFixtureManifest.self,
            from: resourceData(file: Self.manifestFile)
        )
    }

    private func committedArtifacts() throws -> [VisibleCityFixtureArtifact] {
        let generated = try VisibleCityFixtureCorpus.build()
        return try generated.artifacts.map { artifact in
            let bytes = try resourceData(file: artifact.definition.file)
            let state = try loadState(from: bytes, id: artifact.definition.id)
            let snapshot = try CityPresentationSnapshot(state: state)
            return VisibleCityFixtureArtifact(
                definition: artifact.definition,
                state: state,
                fingerprint: try CityStateFingerprinter.fingerprint(state),
                spatialDigest: ProductionStoryFixtureCorpus.spatialDigest(
                    snapshot.spatialConsequences
                ),
                diagnosticDigest: VisibleCityFixtureCorpus.diagnosticDigest(
                    snapshot.spatialConsequences
                ),
                activityDigest: VisibleCityFixtureCorpus.activityDigest(
                    snapshot.spatialConsequences
                ),
                bytes: bytes,
                fileSHA256: ProductionStoryFixtureCorpus.sha256(bytes)
            )
        }
    }

    private func artifact(
        _ lifecycle: VisibleCityLifecycle,
        strategy: CityStrategy,
        in artifacts: [VisibleCityFixtureArtifact]
    ) throws -> VisibleCityFixtureArtifact {
        try XCTUnwrap(
            artifacts.first {
                $0.definition.strategy == strategy
                    && $0.definition.lifecycle == lifecycle
            }
        )
    }

    private func loadState(from bytes: Data, id: String) throws -> CityGameState {
        try withTemporaryRoot(id: "load-\(id)") { root in
            let service = SaveGameService(rootURL: root)
            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: true
            )
            try bytes.write(to: service.saveURL, options: .atomic)
            return try service.load().state
        }
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
        for kind in [BuildingKind.road, .park, .commercial, .industrial]
        where state.treasury >= kind.buildCost {
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
        throw VisibleCityFixtureError.commandRejected("undo")
    }

    private func defaultResolution(
        for strategy: CityStrategy
    ) -> CityStrategyRecoveryResolution {
        switch strategy {
        case .commercialStewardship: .commercialTaxRelief
        case .industrialExpansion: .industrialUtilityExpansion
        }
    }

    private func resourceData(
        file: String,
        subdirectory: String? = nil
    ) throws -> Data {
        let name = String(file.dropLast(".json".count))
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: name,
                withExtension: "json",
                subdirectory: subdirectory ?? Self.fixtureSubdirectory
            )
        )
        return try Data(contentsOf: url)
    }

    private func withTemporaryRoot<T>(
        id: String,
        _ body: (URL) throws -> T
    ) throws -> T {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "citysim-play078-\(id)-\(UUID().uuidString)",
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
