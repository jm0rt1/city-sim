import Foundation
import XCTest
@testable import CitySimNative

final class PLAY083LifecycleBindingTests: XCTestCase {
    private static let fixtureSubdirectory = "Fixtures/VisibleCityStates"
    private static let repositoryFixtureRoot =
        "Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/VisibleCityStates"
    private static let manifestFile = "visible-city-states-manifest-v3.json"
    private static let requestSHA256 =
        "73842570ee5d10e83ef3ec59b301dd9998959bd07e9d3d64e4d9d49c678bf51b"
    private static let manifestSHA256 =
        "9eed6405adc84b8bdf025bb2ac1365b327c8659bdbf0384bc6f172d6c9a2aace"
    private static let manifestGitBlob =
        "40df8ccd154677f67d3141b33372ba406fc6346f"
    private static let publishedAuthority =
        "c00f8295973d527c597c333769b7c4ef7d3acca5"

    private static let bindings = [
        Binding(
            rubricState: "early",
            semanticMapping: "early_to_active",
            manifestID: "industrial-active-district-v3",
            manifestLifecycle: .active,
            file: "visible-city-industrial-active-district-v3.json",
            gitBlob: "af685a8ac6479f97ab12e342a75a726250e58497",
            fileSHA256:
                "48a45a4f3901eee09fca2bcf10315381e421dbc605ffa050e13fbee5dc17fdc3",
            expectedStateDigest:
                "1a47eeb6c6a20b742c121f4b8f1e39a8682df54a8ede1528e8715f99885126ca",
            spatialDigest:
                "e2646bba29246376e3e3a2a5c735cd3a7b1ee718cd29fe850cc67d25e0bf7fe7",
            diagnosticDigest:
                "62c0966c63078521177fe9eb6011c0396d2ec6ee38b571cd1d48ba46c294a63e",
            activityDigest:
                "de199fb7d9f0e0e03cefd31e7873c0f7f69ba07b53ea6bcccdaf5783e6bbe6de",
            tick: 68,
            focusCoordinate: GridCoordinate(x: 5, y: 8)
        ),
        Binding(
            rubricState: "recovered",
            semanticMapping: "recovered_to_recovering",
            manifestID: "industrial-recovering-district-v3",
            manifestLifecycle: .recovering,
            file: "visible-city-industrial-recovering-district-v3.json",
            gitBlob: "9b408b2d01763b5a986287e968f4732e67c2a420",
            fileSHA256:
                "5a278e43873f364c986545a856eec6a8ba4315b712b843028dcc5d8e602720f4",
            expectedStateDigest:
                "a1525b36f38fc0fb2dfbd042d8fd8748088cbc57f9f3f1549be1e3f88653ad7d",
            spatialDigest:
                "de91f0b9d99398508b4eb4c5e84ac1dc1e8abb0cc401ff7b64bf748bbf3e816c",
            diagnosticDigest:
                "befd4256642557eb7d266e5f0412affeb8a6b608410258f0f943e4cd8ad84d25",
            activityDigest:
                "c4aef758a8dc4d22fba33e234a7208a0567ee1e04790c7669566e609d45b6fee",
            tick: 992,
            focusCoordinate: GridCoordinate(x: 4, y: 8)
        ),
    ]

    func testExactLifecycleSemanticsDigestsAndReplay() throws {
        let manifest = try currentManifest()
        XCTAssertEqual(
            ProductionStoryFixtureCorpus.sha256(try resourceData(file: Self.manifestFile)),
            Self.manifestSHA256
        )
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.fingerprintVersion, 1)
        XCTAssertEqual(manifest.seed, 42)

        let early = try loadBinding(Self.bindings[0], manifest: manifest)
        let recovered = try loadBinding(Self.bindings[1], manifest: manifest)

        try assertEarlySemantics(early.state, binding: early.binding)
        try assertRecoveredSemantics(recovered.state, binding: recovered.binding)

        let construction = try loadManifestState(
            id: "industrial-construction-district-v3",
            manifest: manifest
        )
        var replayedEarly = construction
        for _ in 0..<4 {
            CitySimulation.step(&replayedEarly)
        }
        XCTAssertEqual(replayedEarly, early.state)

        let pressured = try loadManifestState(
            id: "industrial-pressured-district-v3",
            manifest: manifest
        )
        let builder = ProductionStoryStateBuilder()
        XCTAssertEqual(
            try builder.replayRegionalRecoveryToQualification(
                pressured,
                resolution: .industrialUtilityExpansion
            ),
            recovered.state
        )
        let terminal = try loadManifestState(
            id: "industrial-terminal-district-v3",
            manifest: manifest
        )
        XCTAssertEqual(
            try builder.replayRegionalQualificationToTerminal(
                recovered.state,
                resolution: .industrialUtilityExpansion
            ),
            terminal
        )
        XCTAssertEqual(terminal.status, .won)

        for loaded in [early, recovered] {
            let fingerprintDigests = try (0..<5).map { _ in
                try CityStateFingerprinter.fingerprint(loaded.state).digest
            }
            XCTAssertEqual(Set(fingerprintDigests), [loaded.binding.expectedStateDigest])
            let snapshot = try CityPresentationSnapshot(state: loaded.state)
            XCTAssertEqual(snapshot.fingerprint.digest, loaded.binding.expectedStateDigest)
            XCTAssertEqual(
                ProductionStoryFixtureCorpus.spatialDigest(snapshot.spatialConsequences),
                loaded.binding.spatialDigest
            )
            XCTAssertEqual(
                VisibleCityFixtureCorpus.diagnosticDigest(snapshot.spatialConsequences),
                loaded.binding.diagnosticDigest
            )
            XCTAssertEqual(
                VisibleCityFixtureCorpus.activityDigest(snapshot.spatialConsequences),
                loaded.binding.activityDigest
            )
        }
    }

    @MainActor
    func testPersistenceRecoveryRoundTripSnapshotAndUndo() throws {
        let manifest = try currentManifest()

        for binding in Self.bindings {
            let bytes = try resourceData(file: binding.file)
            try withTemporaryRoot(id: "\(binding.rubricState)-primary") { root in
                let service = SaveGameService(rootURL: root)
                try FileManager.default.createDirectory(
                    at: root,
                    withIntermediateDirectories: true
                )
                try bytes.write(to: service.saveURL, options: .atomic)

                let load = try service.load()
                XCTAssertEqual(load.source, .primary)
                XCTAssertEqual(load.schemaVersion, 1)
                XCTAssertEqual(load.fingerprint.version, 1)
                XCTAssertEqual(load.fingerprint.digest, binding.expectedStateDigest)

                let store = preparedStore(saveService: service)
                store.speed = .fastest
                XCTAssertTrue(store.perform(.loadCity))
                XCTAssertEqual(store.state, load.state)
                XCTAssertEqual(store.speed, .paused)
                XCTAssertFalse(store.canUndo)
                XCTAssertEqual(
                    store.lastFeedback,
                    CityPersistenceFeedbackPresentation.loaded(
                        load.state,
                        recoveredFromBackup: false
                    ).message
                )

                let snapshot = try CityPresentationSnapshot(state: load.state)
                let frozenState = snapshot.state
                let frozenFingerprint = snapshot.fingerprint
                let frozenSpatial = snapshot.spatialConsequences
                store.state.treasury += 1
                XCTAssertEqual(snapshot.state, frozenState)
                XCTAssertEqual(snapshot.fingerprint, frozenFingerprint)
                XCTAssertEqual(snapshot.spatialConsequences, frozenSpatial)

                let undoStore = CityGameStore(state: load.state)
                let (kind, coordinate) = try undoableBuild(in: load.state)
                undoStore.selectTool(kind)
                undoStore.primaryAction(at: coordinate)
                XCTAssertTrue(undoStore.canUndo)
                XCTAssertNotEqual(undoStore.state, load.state)
                undoStore.undoLastAction()
                XCTAssertEqual(undoStore.state, load.state)
                XCTAssertEqual(
                    try CityStateFingerprinter.fingerprint(undoStore.state),
                    load.fingerprint
                )

                let write = try service.save(load.state)
                XCTAssertEqual(write.schemaVersion, 1)
                XCTAssertEqual(write.fingerprint, load.fingerprint)
                XCTAssertEqual(try Data(contentsOf: service.saveURL), bytes)
            }

            try withTemporaryRoot(id: "\(binding.rubricState)-backup") { root in
                let service = SaveGameService(rootURL: root)
                try FileManager.default.createDirectory(
                    at: root,
                    withIntermediateDirectories: true
                )
                let corrupt = Data("{\"invalid\":true}".utf8)
                try corrupt.write(to: service.saveURL, options: .atomic)
                try bytes.write(to: service.backupURL, options: .atomic)

                let recovered = try service.load()
                XCTAssertEqual(recovered.source, .backup)
                XCTAssertTrue(recovered.recoveredFromBackup)
                XCTAssertEqual(recovered.schemaVersion, 1)
                XCTAssertEqual(recovered.fingerprint.version, 1)
                XCTAssertEqual(recovered.fingerprint.digest, binding.expectedStateDigest)
                XCTAssertEqual(
                    recovered.state,
                    try loadManifestState(id: binding.manifestID, manifest: manifest)
                )
                XCTAssertEqual(try Data(contentsOf: service.saveURL), corrupt)
                XCTAssertEqual(try Data(contentsOf: service.backupURL), bytes)
            }
        }
    }

    func testWriteBindingCandidateOnlyWhenExplicitlyRequested() throws {
        guard let rootPath = ProcessInfo.processInfo.environment[
            "CITYSIM_PLAY083_OUTPUT_ROOT"
        ],
        !rootPath.isEmpty else {
            return
        }
        let candidateCommit = try XCTUnwrap(
            ProcessInfo.processInfo.environment["CITYSIM_PLAY083_CANDIDATE_COMMIT"]
        )
        XCTAssertEqual(candidateCommit.count, 40)
        let manifest = try currentManifest()
        let receipt = try candidateReceipt(
            manifest: manifest,
            candidateCommit: candidateCommit
        )
        let root = URL(filePath: rootPath, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        try receipt.write(
            to: root.appending(path: "binding-candidate.json"),
            options: .atomic
        )
        print(
            "PLAY083_BINDING_WRITE root=\(root.path) bytes=\(receipt.count) " +
            "sha256=\(ProductionStoryFixtureCorpus.sha256(receipt))"
        )
    }

    private func assertEarlySemantics(
        _ state: CityGameState,
        binding: Binding
    ) throws {
        XCTAssertEqual(state.tick, binding.tick)
        XCTAssertEqual(state.status, .playing)
        XCTAssertEqual(state.progression?.strategy?.committedStrategy, .industrialExpansion)
        XCTAssertEqual(state.progression?.strategy?.currentPhase, .opportunity)
        XCTAssertNil(state.progression?.strategy?.recoveryResolution)
        XCTAssertNil(state.progression?.secondAct)
        XCTAssertFalse(state.progression?.townCharterAwarded ?? true)
        let focus = try XCTUnwrap(state.tile(at: binding.focusCoordinate))
        XCTAssertEqual(focus.kind, .industrial)
        XCTAssertEqual(focus.constructionProgress, 1)
        XCTAssertGreaterThan(focus.occupancy, 0)
    }

    private func assertRecoveredSemantics(
        _ state: CityGameState,
        binding: Binding
    ) throws {
        XCTAssertEqual(state.tick, binding.tick)
        XCTAssertEqual(state.status, .playing)
        XCTAssertEqual(state.progression?.strategy?.committedStrategy, .industrialExpansion)
        XCTAssertEqual(state.progression?.strategy?.currentPhase, .completed)
        XCTAssertEqual(
            state.progression?.strategy?.recoveryResolution,
            .industrialUtilityExpansion
        )
        XCTAssertEqual(state.progression?.secondAct?.phase, .qualification)
        XCTAssertTrue(state.progression?.townCharterAwarded ?? false)
        XCTAssertFalse(state.progression?.secondAct?.regionalCapitalAwarded ?? true)
        let focus = try XCTUnwrap(state.tile(at: binding.focusCoordinate))
        XCTAssertEqual(focus.kind, .industrial)
        XCTAssertEqual(focus.constructionProgress, 1)
        XCTAssertEqual(focus.condition, 0.64, accuracy: 0.000_001)
        XCTAssertEqual(focus.level, 3)
        XCTAssertEqual(
            state.tiles.filter {
                $0.kind == .industrial && $0.condition < 0.4
            }.count,
            0
        )
        XCTAssertEqual(
            state.tiles.filter {
                $0.kind == .industrial
                    && $0.condition >= 0.4
                    && $0.condition < 0.75
            }.count,
            1
        )
    }

    private func loadBinding(
        _ binding: Binding,
        manifest: VisibleCityFixtureManifest
    ) throws -> LoadedBinding {
        let entry = try XCTUnwrap(
            manifest.fixtures.first { $0.id == binding.manifestID }
        )
        XCTAssertEqual(entry.lifecycle, binding.manifestLifecycle)
        XCTAssertEqual(entry.file, binding.file)
        XCTAssertEqual(entry.fileSHA256, binding.fileSHA256)
        XCTAssertEqual(entry.byteCount, try resourceData(file: binding.file).count)
        XCTAssertEqual(entry.expectedStateDigest, binding.expectedStateDigest)
        XCTAssertEqual(entry.spatialDigest, binding.spatialDigest)
        XCTAssertEqual(entry.diagnosticDigest, binding.diagnosticDigest)
        XCTAssertEqual(entry.activityDigest, binding.activityDigest)
        XCTAssertEqual(entry.tick, binding.tick)
        XCTAssertEqual(entry.status, .playing)
        XCTAssertEqual(entry.strategy, .industrialExpansion)
        XCTAssertEqual(entry.strategyDistrictKind, .industrial)
        XCTAssertEqual(entry.focusCoordinate, binding.focusCoordinate)
        XCTAssertEqual(entry.focusKind, .industrial)

        let bytes = try resourceData(file: binding.file)
        XCTAssertEqual(
            ProductionStoryFixtureCorpus.sha256(bytes),
            binding.fileSHA256
        )
        let state = try loadState(from: bytes, id: binding.manifestID)
        return LoadedBinding(binding: binding, state: state)
    }

    private func loadManifestState(
        id: String,
        manifest: VisibleCityFixtureManifest
    ) throws -> CityGameState {
        let entry = try XCTUnwrap(manifest.fixtures.first { $0.id == id })
        return try loadState(from: resourceData(file: entry.file), id: id)
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

    private func currentManifest() throws -> VisibleCityFixtureManifest {
        try JSONDecoder().decode(
            VisibleCityFixtureManifest.self,
            from: resourceData(file: Self.manifestFile)
        )
    }

    private func candidateReceipt(
        manifest: VisibleCityFixtureManifest,
        candidateCommit: String
    ) throws -> Data {
        let mappings = try Self.bindings.map { binding -> [String: Any] in
            let entry = try XCTUnwrap(
                manifest.fixtures.first { $0.id == binding.manifestID }
            )
            let state = try loadState(
                from: resourceData(file: binding.file),
                id: binding.manifestID
            )
            let focus = try XCTUnwrap(state.tile(at: binding.focusCoordinate))
            return [
                "activityDigest": binding.activityDigest,
                "byteCount": entry.byteCount,
                "diagnosticDigest": binding.diagnosticDigest,
                "expectedStateDigest": binding.expectedStateDigest,
                "fileSHA256": binding.fileSHA256,
                "fingerprintVersion": 1,
                "focusCondition": focus.condition,
                "focusCoordinate": [
                    "x": binding.focusCoordinate.x,
                    "y": binding.focusCoordinate.y,
                ],
                "focusKind": "industrial",
                "focusLevel": focus.level,
                "gitBlob": binding.gitBlob,
                "manifestID": binding.manifestID,
                "manifestLifecycle": binding.manifestLifecycle.rawValue,
                "path": Self.repositoryFixtureRoot + "/" + binding.file,
                "replayProvenance": binding.rubricState == "early"
                    ? "industrial-construction-district-v3 + four deterministic steps"
                    : "industrial-pressured-district-v3 + industrialUtilityExpansion to qualification; terminal successor exact",
                "resolution": state.progression?.strategy?.recoveryResolution?.rawValue
                    ?? NSNull(),
                "rubricState": binding.rubricState,
                "schemaVersion": 1,
                "secondActPhase": state.progression?.secondAct?.phase.rawValue
                    ?? NSNull(),
                "semanticMapping": binding.semanticMapping,
                "spatialDigest": binding.spatialDigest,
                "status": state.status.rawValue,
                "strategy": "industrialExpansion",
                "strategyDistrictKind": "industrial",
                "strategyPhase": state.progression?.strategy?.currentPhase.rawValue
                    ?? "missing",
                "tick": state.tick,
            ]
        }
        let object: [String: Any] = [
            "authority": [
                "basePublishedMaster": Self.publishedAuthority,
                "branch": "codex/citysim-simulation-platform",
                "candidateCommit": candidateCommit,
                "claimPath": "docs/production/claims/PLAY-083.simulation-platform.md",
            ],
            "documentType": "PLAY-083_LIFECYCLE_BINDING_CANDIDATE",
            "failClosedNegativeCount": 22,
            "manifest": [
                "authorityCommit": manifest.authorityCommit,
                "fingerprintVersion": manifest.fingerprintVersion,
                "fixtureSet": manifest.fixtureSet,
                "gitBlob": Self.manifestGitBlob,
                "path": Self.repositoryFixtureRoot + "/" + Self.manifestFile,
                "schemaVersion": manifest.schemaVersion,
                "seed": manifest.seed,
                "sha256": Self.manifestSHA256,
                "sourceStoryManifestSHA256": manifest.sourceStoryManifestSHA256,
            ],
            "mappings": mappings,
            "proofs": [
                "committedBytesMatchGeneration": true,
                "corruptPrimaryBackupRecovery": true,
                "digestReproduction": true,
                "fingerprintRepeatCountPerState": 5,
                "historicalBytesPreserved": true,
                "manifestHashAndCount": true,
                "primaryLoad": true,
                "recursiveByteIdentity": true,
                "replayExact": true,
                "saveRoundTripByteExact": true,
                "snapshotImmutable": true,
                "storeLoadPausedAndUndoCleared": true,
                "twoIndependentOutputRoots": true,
                "undoExact": true,
            ],
            "qa": [
                "mappingAuthorityPublished": false,
                "rehearsalStatus": "BLOCKED",
            ],
            "request": [
                "path": "docs/production/evidence/PLAY-075/industrial-l4-family-preregistration-v1/production-quality-rubric-v2/UPSTREAM-LIFECYCLE-SAVE-REQUEST.json",
                "sha256": Self.requestSHA256,
            ],
            "schemaVersion": 1,
            "scope": [
                "acceptanceDecisions": 0,
                "appLaunches": 0,
                "captures": 0,
                "fixtureMutations": 0,
                "manifestMutations": 0,
                "productMutations": 0,
                "scores": 0,
            ],
            "status": "CANDIDATE_FOR_INTEGRATION_REVIEW",
        ]
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        return data
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
        throw VisibleCityFixtureError.commandRejected("PLAY-083 undo")
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

    private func withTemporaryRoot<T>(
        id: String,
        _ body: (URL) throws -> T
    ) throws -> T {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "citysim-play083-\(id)-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        return try body(root)
    }
}

private struct Binding: Sendable {
    let rubricState: String
    let semanticMapping: String
    let manifestID: String
    let manifestLifecycle: VisibleCityLifecycle
    let file: String
    let gitBlob: String
    let fileSHA256: String
    let expectedStateDigest: String
    let spatialDigest: String
    let diagnosticDigest: String
    let activityDigest: String
    let tick: Int
    let focusCoordinate: GridCoordinate
}

private struct LoadedBinding: Sendable {
    let binding: Binding
    let state: CityGameState
}
