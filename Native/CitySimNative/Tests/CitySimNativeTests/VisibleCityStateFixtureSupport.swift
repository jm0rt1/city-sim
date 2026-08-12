import CryptoKit
import Foundation
@testable import CitySimNative

enum VisibleCityLifecycle: String, Codable, CaseIterable, Sendable {
    case vacant
    case construction
    case active
    case pressured
    case recovering
    case upgraded
    case terminal
}

struct VisibleCityFixtureDefinition: Equatable, Sendable {
    let id: String
    let file: String
    let strategy: CityStrategy
    let lifecycle: VisibleCityLifecycle
    let focusCoordinate: GridCoordinate
    let focusKind: BuildingKind
    let strategyDistrictKind: BuildingKind
}

struct VisibleCityFixtureState: Equatable, Sendable {
    let definition: VisibleCityFixtureDefinition
    let state: CityGameState
}

struct VisibleCityFixtureManifest: Codable, Equatable, Sendable {
    let fixtureSet: String
    let authorityCommit: String
    let sourceStoryManifestSHA256: String
    let schemaVersion: Int
    let fingerprintVersion: Int
    let seed: UInt64
    let fixtures: [Entry]

    struct Entry: Codable, Equatable, Sendable {
        let id: String
        let file: String
        let strategy: CityStrategy
        let lifecycle: VisibleCityLifecycle
        let focusCoordinate: GridCoordinate
        let focusKind: BuildingKind
        let strategyDistrictKind: BuildingKind
        let tick: Int
        let status: GameStatus
        let strategyPhase: CityStrategyPhase
        let secondActPhase: CitySecondActPhase?
        let resolution: CityStrategyRecoveryResolution?
        let expectedStateDigest: String
        let spatialDigest: String
        let diagnosticDigest: String
        let activityDigest: String
        let fileSHA256: String
        let byteCount: Int
    }
}

struct VisibleCityFixtureArtifact: Equatable, Sendable {
    let definition: VisibleCityFixtureDefinition
    let state: CityGameState
    let fingerprint: CityStateFingerprint
    let spatialDigest: String
    let diagnosticDigest: String
    let activityDigest: String
    let bytes: Data
    let fileSHA256: String
}

struct VisibleCityFixtureCorpus: Equatable, Sendable {
    static let fixtureSet = "PLAY-130 current visible-city states"
    static let authorityCommit =
        "703a8968e62654b7037c9b0437686930f46368f8"
    static let sourceStoryManifestSHA256 =
        "f7b9feb3c581cf194616213886ccd6f68a9991702a69834cd3662e055245d4aa"
    static let manifestFile = "visible-city-states-manifest-v5.json"
    static let schemaVersion = 1
    static let fingerprintVersion = 1
    static let seed: UInt64 = 42

    let artifacts: [VisibleCityFixtureArtifact]
    let manifest: VisibleCityFixtureManifest
    let manifestData: Data

    static func build() throws -> VisibleCityFixtureCorpus {
        let states = try VisibleCityStateBuilder().buildAll()
        let artifacts = try states.map { fixture -> VisibleCityFixtureArtifact in
            let fingerprint = try CityStateFingerprinter.fingerprint(fixture.state)
            let snapshot = try CityPresentationSnapshot(state: fixture.state)
            let bytes = try schemaOneBytes(
                for: fixture.state,
                id: fixture.definition.id
            )
            return VisibleCityFixtureArtifact(
                definition: fixture.definition,
                state: fixture.state,
                fingerprint: fingerprint,
                spatialDigest: ProductionStoryFixtureCorpus.spatialDigest(
                    snapshot.spatialConsequences
                ),
                diagnosticDigest: diagnosticDigest(snapshot.spatialConsequences),
                activityDigest: activityDigest(snapshot.spatialConsequences),
                bytes: bytes,
                fileSHA256: ProductionStoryFixtureCorpus.sha256(bytes)
            )
        }
        let manifest = VisibleCityFixtureManifest(
            fixtureSet: fixtureSet,
            authorityCommit: authorityCommit,
            sourceStoryManifestSHA256: sourceStoryManifestSHA256,
            schemaVersion: schemaVersion,
            fingerprintVersion: fingerprintVersion,
            seed: seed,
            fixtures: artifacts.map { artifact in
                let progression = artifact.state.progression
                return VisibleCityFixtureManifest.Entry(
                    id: artifact.definition.id,
                    file: artifact.definition.file,
                    strategy: artifact.definition.strategy,
                    lifecycle: artifact.definition.lifecycle,
                    focusCoordinate: artifact.definition.focusCoordinate,
                    focusKind: artifact.definition.focusKind,
                    strategyDistrictKind: artifact.definition.strategyDistrictKind,
                    tick: artifact.state.tick,
                    status: artifact.state.status,
                    strategyPhase: progression?.strategy?.currentPhase ?? .opportunity,
                    secondActPhase: progression?.secondAct?.phase,
                    resolution: progression?.strategy?.recoveryResolution,
                    expectedStateDigest: artifact.fingerprint.digest,
                    spatialDigest: artifact.spatialDigest,
                    diagnosticDigest: artifact.diagnosticDigest,
                    activityDigest: artifact.activityDigest,
                    fileSHA256: artifact.fileSHA256,
                    byteCount: artifact.bytes.count
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return VisibleCityFixtureCorpus(
            artifacts: artifacts,
            manifest: manifest,
            manifestData: try encoder.encode(manifest)
        )
    }

    func write(to root: URL) throws {
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        for artifact in artifacts {
            try artifact.bytes.write(
                to: root.appending(path: artifact.definition.file),
                options: .atomic
            )
        }
        try manifestData.write(
            to: root.appending(path: Self.manifestFile),
            options: .atomic
        )
    }

    static func diagnosticDigest(_ map: CitySpatialConsequenceMap) -> String {
        var canonical = "spatial-diagnostics-v1|\(map.width)|\(map.height)\n"
        for sample in map.samples {
            canonical += [
                String(sample.coordinate.x),
                String(sample.coordinate.y),
                optionalBitPattern(sample.landValueIndex),
                optionalBitPattern(sample.localHappinessIndex),
                optionalBitPattern(sample.trafficPressure),
            ].joined(separator: ",")
            canonical += "\n"
        }
        return sha256(Data(canonical.utf8))
    }

    static func activityDigest(_ map: CitySpatialConsequenceMap) -> String {
        var canonical = "local-activity-v1|\(map.width)|\(map.height)\n"
        for sample in map.samples {
            canonical += [
                String(sample.coordinate.x),
                String(sample.coordinate.y),
                optionalBitPattern(sample.streetActivityIndex),
                optionalBitPattern(sample.placeActivityIndex),
            ].joined(separator: ",")
            canonical += "\n"
        }
        return sha256(Data(canonical.utf8))
    }

    private static func schemaOneBytes(
        for state: CityGameState,
        id: String
    ) throws -> Data {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "citysim-play078-visible-\(id)-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        let write = try service.save(state)
        guard write.schemaVersion == schemaVersion,
              write.fingerprint.version == fingerprintVersion else {
            throw VisibleCityFixtureError.unexpectedState(
                "\(id): schema \(write.schemaVersion), fingerprint \(write.fingerprint.version)"
            )
        }
        return try Data(contentsOf: service.saveURL)
    }

    private static func optionalBitPattern(_ value: Double?) -> String {
        value.map { String($0.bitPattern) } ?? "nil"
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct VisibleCityStateBuilder {
    func buildAll() throws -> [VisibleCityFixtureState] {
        try build(strategy: .commercialStewardship)
            + build(strategy: .industrialExpansion)
    }

    func build(strategy: CityStrategy) throws -> [VisibleCityFixtureState] {
        let storyBuilder = ProductionStoryStateBuilder()
        let districtKind = jobs(for: strategy)
        let resolution = defaultResolution(for: strategy)

        let vacant = try storyBuilder.committedOpening(strategy: strategy)
        let focus = try focusCoordinate(for: districtKind, in: vacant)
        var construction = vacant
        guard case .success = CitySimulation.build(
            districtKind,
            at: focus,
            in: &construction
        ) else {
            throw VisibleCityFixtureError.commandRejected(districtKind.rawValue)
        }

        var active = construction
        for _ in 0..<4 { CitySimulation.step(&active) }
        let firstActComplication = try storyBuilder.replayOpeningToComplication(
            active,
            strategy: strategy
        )
        let firstActRecovery = try storyBuilder.replayComplicationToRecovery(
            firstActComplication,
            strategy: strategy
        )
        let upgraded = try storyBuilder.replayRecoveryToCharterMidpoint(
            firstActRecovery,
            strategy: strategy
        )
        let upgradedFocus = try upgradedCoordinate(
            in: upgraded,
            kind: districtKind
        )
        let pressured = try storyBuilder.replayCharterMidpointToRegionalRecovery(
            upgraded,
            resolution: resolution
        )
        let pressureFocus = try weatheredCoordinate(
            in: pressured,
            kind: districtKind
        )
        let recovering = try storyBuilder.replayRegionalRecoveryToQualification(
            pressured,
            resolution: resolution
        )
        let terminal = try storyBuilder.replayRegionalQualificationToTerminal(
            recovering,
            resolution: resolution
        )

        return [
            fixture(.vacant, state: vacant, strategy: strategy, focus: focus),
            fixture(
                .construction,
                state: construction,
                strategy: strategy,
                focus: focus
            ),
            fixture(.active, state: active, strategy: strategy, focus: focus),
            fixture(
                .pressured,
                state: pressured,
                strategy: strategy,
                focus: pressureFocus
            ),
            fixture(
                .recovering,
                state: recovering,
                strategy: strategy,
                focus: pressureFocus
            ),
            fixture(
                .upgraded,
                state: upgraded,
                strategy: strategy,
                focus: upgradedFocus
            ),
            fixture(
                .terminal,
                state: terminal,
                strategy: strategy,
                focus: pressureFocus
            ),
        ]
    }

    private func fixture(
        _ lifecycle: VisibleCityLifecycle,
        state: CityGameState,
        strategy: CityStrategy,
        focus: GridCoordinate
    ) -> VisibleCityFixtureState {
        let prefix = strategy == .commercialStewardship
            ? "commercial"
            : "industrial"
        let id = "\(prefix)-\(lifecycle.rawValue)-district-v5"
        return VisibleCityFixtureState(
            definition: VisibleCityFixtureDefinition(
                id: id,
                file: "visible-city-\(id).json",
                strategy: strategy,
                lifecycle: lifecycle,
                focusCoordinate: focus,
                focusKind: state.tile(at: focus)?.kind ?? .empty,
                strategyDistrictKind: jobs(for: strategy)
            ),
            state: state
        )
    }

    private func upgradedCoordinate(
        in state: CityGameState,
        kind: BuildingKind
    ) throws -> GridCoordinate {
        let upgraded = state.tiles
            .filter {
                $0.kind == kind
                    && $0.level > 1
                    && $0.constructionProgress >= 1
            }
            .sorted {
                if $0.level != $1.level { return $0.level > $1.level }
                if $0.coordinate.y != $1.coordinate.y {
                    return $0.coordinate.y < $1.coordinate.y
                }
                return $0.coordinate.x < $1.coordinate.x
            }
        guard let focus = upgraded.first?.coordinate else {
            throw VisibleCityFixtureError.unexpectedState(
                "missing authoritative upgraded \(kind.rawValue) place"
            )
        }
        return focus
    }

    private func weatheredCoordinate(
        in state: CityGameState,
        kind: BuildingKind
    ) throws -> GridCoordinate {
        let pressured = state.tiles
            .filter { $0.kind == kind && $0.condition < 0.4 }
            .sorted {
                if $0.condition != $1.condition {
                    return $0.condition < $1.condition
                }
                if $0.coordinate.y != $1.coordinate.y {
                    return $0.coordinate.y < $1.coordinate.y
                }
                return $0.coordinate.x < $1.coordinate.x
            }
        guard let focus = pressured.first?.coordinate else {
            throw VisibleCityFixtureError.unexpectedState(
                "missing authoritative pressured \(kind.rawValue) place"
            )
        }
        return focus
    }

    private func focusCoordinate(
        for kind: BuildingKind,
        in state: CityGameState
    ) throws -> GridCoordinate {
        for tile in state.tiles where tile.kind == .empty {
            if case .success = CitySimulation.validateBuild(
                kind,
                at: tile.coordinate,
                in: state
            ) {
                return tile.coordinate
            }
        }
        throw VisibleCityFixtureError.commandRejected(kind.rawValue)
    }

    private func defaultResolution(
        for strategy: CityStrategy
    ) -> CityStrategyRecoveryResolution {
        switch strategy {
        case .commercialStewardship: .commercialTaxRelief
        case .industrialExpansion: .industrialUtilityExpansion
        }
    }

    private func jobs(for strategy: CityStrategy) -> BuildingKind {
        switch strategy {
        case .commercialStewardship: .commercial
        case .industrialExpansion: .industrial
        }
    }
}

enum VisibleCityFixtureError: Error, Equatable {
    case commandRejected(String)
    case unexpectedState(String)
}
