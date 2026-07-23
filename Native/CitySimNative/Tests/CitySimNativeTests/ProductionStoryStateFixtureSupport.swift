import CryptoKit
import Foundation
@testable import CitySimNative

enum ProductionStoryMoment: String, Codable, CaseIterable, Sendable {
    case opening
    case complication
    case recovery
    case charterVictory
}

struct ProductionStoryFixtureDefinition: Equatable, Sendable {
    let id: String
    let file: String
    let strategy: CityStrategy
    let moment: ProductionStoryMoment
    let phase: CityStrategyPhase
    let resolution: CityStrategyRecoveryResolution?
    let status: GameStatus
    let messageTitle: String
}

struct ProductionStoryFixtureState: Equatable, Sendable {
    let definition: ProductionStoryFixtureDefinition
    let state: CityGameState
}

struct ProductionStoryFixtureManifest: Codable, Equatable, Sendable {
    let fixtureSet: String
    let schemaVersion: Int
    let fingerprintVersion: Int
    let seed: UInt64
    let fixtures: [Entry]

    struct Entry: Codable, Equatable, Sendable {
        let id: String
        let file: String
        let strategy: CityStrategy
        let moment: ProductionStoryMoment
        let tick: Int
        let status: GameStatus
        let phase: CityStrategyPhase
        let resolution: CityStrategyRecoveryResolution?
        let expectedStateDigest: String
        let spatialDigest: String
        let fileSHA256: String
        let byteCount: Int
    }
}

struct ProductionStoryFixtureArtifact: Equatable, Sendable {
    let definition: ProductionStoryFixtureDefinition
    let state: CityGameState
    let fingerprint: CityStateFingerprint
    let spatialDigest: String
    let bytes: Data
    let fileSHA256: String
}

struct ProductionStoryFixtureCorpus: Equatable, Sendable {
    static let fixtureSet = "PLAY-047 production story states"
    static let schemaVersion = 1
    static let fingerprintVersion = 1
    static let seed: UInt64 = 42

    let artifacts: [ProductionStoryFixtureArtifact]
    let manifest: ProductionStoryFixtureManifest
    let manifestData: Data

    static func build() throws -> ProductionStoryFixtureCorpus {
        let states = try ProductionStoryStateBuilder().buildAll()
        let artifacts = try states.map { fixture -> ProductionStoryFixtureArtifact in
            let fingerprint = try CityStateFingerprinter.fingerprint(fixture.state)
            let snapshot = try CityPresentationSnapshot(state: fixture.state)
            let bytes = try schemaOneBytes(for: fixture.state, id: fixture.definition.id)
            return ProductionStoryFixtureArtifact(
                definition: fixture.definition,
                state: fixture.state,
                fingerprint: fingerprint,
                spatialDigest: spatialDigest(snapshot.spatialConsequences),
                bytes: bytes,
                fileSHA256: sha256(bytes)
            )
        }
        let manifest = ProductionStoryFixtureManifest(
            fixtureSet: fixtureSet,
            schemaVersion: schemaVersion,
            fingerprintVersion: fingerprintVersion,
            seed: seed,
            fixtures: artifacts.map { artifact in
                ProductionStoryFixtureManifest.Entry(
                    id: artifact.definition.id,
                    file: artifact.definition.file,
                    strategy: artifact.definition.strategy,
                    moment: artifact.definition.moment,
                    tick: artifact.state.tick,
                    status: artifact.state.status,
                    phase: artifact.definition.phase,
                    resolution: artifact.definition.resolution,
                    expectedStateDigest: artifact.fingerprint.digest,
                    spatialDigest: artifact.spatialDigest,
                    fileSHA256: artifact.fileSHA256,
                    byteCount: artifact.bytes.count
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return ProductionStoryFixtureCorpus(
            artifacts: artifacts,
            manifest: manifest,
            manifestData: try encoder.encode(manifest)
        )
    }

    func write(to root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for artifact in artifacts {
            try artifact.bytes.write(
                to: root.appending(path: artifact.definition.file),
                options: .atomic
            )
        }
        try manifestData.write(
            to: root.appending(path: "story-states-manifest-v1.json"),
            options: .atomic
        )
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func spatialDigest(_ map: CitySpatialConsequenceMap) -> String {
        var canonical = "spatial-v1|\(map.width)|\(map.height)\n"
        canonical.reserveCapacity(map.samples.count * 96)
        for sample in map.samples {
            canonical += [
                String(sample.coordinate.x),
                String(sample.coordinate.y),
                String(sample.utility.power.bitPattern),
                String(sample.utility.water.bitPattern),
                String(sample.utility.combined.bitPattern),
                String(sample.utility.powerBand.rawValue),
                String(sample.utility.waterBand.rawValue),
                String(sample.utility.combinedBand.rawValue),
                String(sample.pollutionExposure.bitPattern),
                String(sample.pollutionBand.rawValue),
                String(sample.vitalityScore.bitPattern),
                String(sample.vitality.rawValue),
            ].joined(separator: ",")
            canonical += "\n"
        }
        return sha256(Data(canonical.utf8))
    }

    private static func schemaOneBytes(for state: CityGameState, id: String) throws -> Data {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "citysim-play047-\(id)-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SaveGameService(rootURL: root)
        let write = try service.save(state)
        guard write.schemaVersion == schemaVersion,
              write.fingerprint.version == fingerprintVersion else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(id): schema \(write.schemaVersion), fingerprint \(write.fingerprint.version)"
            )
        }
        return try Data(contentsOf: service.saveURL)
    }
}

struct ProductionStoryStateBuilder {
    func buildAll() throws -> [ProductionStoryFixtureState] {
        try build(strategy: .commercialStewardship)
            + build(strategy: .industrialExpansion)
    }

    func replayOpeningToComplication(
        _ state: CityGameState,
        strategy: CityStrategy
    ) throws -> CityGameState {
        try requireIdentity(
            state,
            strategy: strategy,
            phase: .opportunity,
            resolution: nil,
            status: .playing
        )
        var replay = state
        try advanceThroughStrategyPhase(&replay, phase: .opportunity)
        return replay
    }

    func replayComplicationToRecovery(
        _ state: CityGameState,
        strategy: CityStrategy
    ) throws -> CityGameState {
        try requireIdentity(
            state,
            strategy: strategy,
            phase: .complication,
            resolution: nil,
            status: .playing
        )
        var replay = state
        try advanceThroughStrategyPhase(&replay, phase: .complication)
        try applyRecoveryPreparation(for: strategy, to: &replay)
        try advanceThroughStrategyPhase(&replay, phase: .setback)
        return replay
    }

    func replayRecoveryToVictory(
        _ state: CityGameState,
        strategy: CityStrategy
    ) throws -> CityGameState {
        let resolution = resolution(for: strategy)
        try requireIdentity(
            state,
            strategy: strategy,
            phase: .recovery,
            resolution: resolution,
            status: .playing
        )
        var replay = state
        try advanceThroughStrategyPhase(&replay, phase: .recovery)
        if strategy == .commercialStewardship {
            replay.taxRate = 0.10
        }
        try prepareCharterCapacity(in: &replay, jobs: jobs(for: strategy))
        replay.taxRate = 0.10
        try advanceUntil(&replay, maximumCycles: 430) {
            $0.progression?.townCharterAwarded == true
        }
        return replay
    }

    private func build(strategy: CityStrategy) throws -> [ProductionStoryFixtureState] {
        var state = CityGameState.newCity(seed: ProductionStoryFixtureCorpus.seed)
        try advanceToTick(&state, tick: 60)
        try buildFirstValid(jobs(for: strategy), in: &state)
        try advanceToTick(&state, tick: 64)

        try requireIdentity(
            state,
            strategy: strategy,
            phase: .opportunity,
            resolution: nil,
            status: .playing
        )
        let opening = ProductionStoryFixtureState(
            definition: definition(for: strategy, moment: .opening),
            state: state
        )

        state = try replayOpeningToComplication(state, strategy: strategy)
        try requireIdentity(
            state,
            strategy: strategy,
            phase: .complication,
            resolution: nil,
            status: .playing
        )
        let complication = ProductionStoryFixtureState(
            definition: definition(for: strategy, moment: .complication),
            state: state
        )

        state = try replayComplicationToRecovery(state, strategy: strategy)
        try requireIdentity(
            state,
            strategy: strategy,
            phase: .recovery,
            resolution: resolution(for: strategy),
            status: .playing
        )
        let recovery = ProductionStoryFixtureState(
            definition: definition(for: strategy, moment: .recovery),
            state: state
        )

        state = try replayRecoveryToVictory(state, strategy: strategy)
        try requireIdentity(
            state,
            strategy: strategy,
            phase: .completed,
            resolution: resolution(for: strategy),
            status: .won
        )
        guard state.tick == 844,
              state.progression?.townCharterQualifyingCycles == 12,
              state.progression?.townCharterAwarded == true else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(strategy.rawValue): expected tick-844 Charter victory"
            )
        }
        let victory = ProductionStoryFixtureState(
            definition: definition(for: strategy, moment: .charterVictory),
            state: state
        )

        return [opening, complication, recovery, victory]
    }

    private func definition(
        for strategy: CityStrategy,
        moment: ProductionStoryMoment
    ) -> ProductionStoryFixtureDefinition {
        let prefix: String
        let resolution: CityStrategyRecoveryResolution?
        let phase: CityStrategyPhase
        let status: GameStatus
        let messageTitle: String

        switch (strategy, moment) {
        case (.commercialStewardship, .opening):
            prefix = "commercial"
            resolution = nil
            phase = .opportunity
            status = .playing
            messageTitle = "Main Street Crossroads"
        case (.commercialStewardship, .complication):
            prefix = "commercial"
            resolution = nil
            phase = .complication
            status = .playing
            messageTitle = "Market Weekend"
        case (.commercialStewardship, .recovery):
            prefix = "commercial"
            resolution = .commercialTaxRelief
            phase = .recovery
            status = .playing
            messageTitle = "Storefront Slump Avoided"
        case (.commercialStewardship, .charterVictory):
            prefix = "commercial"
            resolution = .commercialTaxRelief
            phase = .completed
            status = .won
            messageTitle = "Town Charter Awarded"
        case (.industrialExpansion, .opening):
            prefix = "industrial"
            resolution = nil
            phase = .opportunity
            status = .playing
            messageTitle = "Freight Contract Watch"
        case (.industrialExpansion, .complication):
            prefix = "industrial"
            resolution = nil
            phase = .complication
            status = .playing
            messageTitle = "Regional Freight Contract"
        case (.industrialExpansion, .recovery):
            prefix = "industrial"
            resolution = .industrialUtilityExpansion
            phase = .recovery
            status = .playing
            messageTitle = "Industrial Load Absorbed"
        case (.industrialExpansion, .charterVictory):
            prefix = "industrial"
            resolution = .industrialUtilityExpansion
            phase = .completed
            status = .won
            messageTitle = "Town Charter Awarded"
        }

        let suffix = switch moment {
        case .opening: "opening"
        case .complication: "complication"
        case .recovery: "recovery"
        case .charterVictory: "charter-victory"
        }
        return ProductionStoryFixtureDefinition(
            id: "\(prefix)-\(suffix)-v1",
            file: "story-\(prefix)-\(suffix)-v1.json",
            strategy: strategy,
            moment: moment,
            phase: phase,
            resolution: resolution,
            status: status,
            messageTitle: messageTitle
        )
    }

    private func resolution(
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

    private func applyRecoveryPreparation(
        for strategy: CityStrategy,
        to state: inout CityGameState
    ) throws {
        guard state.progression?.strategy?.currentPhase == .setback,
              state.progression?.strategy?.recoveryResolution == nil else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(strategy.rawValue): expected unresolved setback"
            )
        }
        switch strategy {
        case .commercialStewardship:
            state.taxRate = 0.09
        case .industrialExpansion:
            try prepareReserveUtilities(in: &state)
        }
    }

    private func prepareReserveUtilities(in state: inout CityGameState) throws {
        for kind in [BuildingKind.powerPlant, .waterTower] {
            while CityAnalytics(state: state).count(kind) < 2 {
                try advanceUntil(&state, maximumCycles: 160) {
                    $0.treasury >= kind.buildCost
                }
                guard state.status == .playing, state.treasury >= kind.buildCost else {
                    throw ProductionStoryFixtureError.unexpectedState(
                        "insufficient treasury for \(kind.rawValue)"
                    )
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
                throw ProductionStoryFixtureError.unexpectedState(
                    "insufficient treasury for \(jobs.rawValue)"
                )
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
            if case .success = CitySimulation.validateBuild(
                kind,
                at: tile.coordinate,
                in: state
            ) {
                guard case .success = CitySimulation.build(
                    kind,
                    at: tile.coordinate,
                    in: &state
                ) else {
                    throw ProductionStoryFixtureError.commandRejected(kind.rawValue)
                }
                return
            }
        }
        throw ProductionStoryFixtureError.commandRejected(kind.rawValue)
    }

    private func advanceThroughStrategyPhase(
        _ state: inout CityGameState,
        phase: CityStrategyPhase
    ) throws {
        guard state.progression?.strategy?.currentPhase == phase,
              let scheduledTick = state.progression?.strategy?.nextScheduledTick else {
            throw ProductionStoryFixtureError.unexpectedState(
                "expected scheduled \(phase.rawValue) phase"
            )
        }
        try advanceToTick(&state, tick: scheduledTick)
    }

    private func advanceToTick(
        _ state: inout CityGameState,
        tick: Int
    ) throws {
        guard state.tick <= tick else {
            throw ProductionStoryFixtureError.unexpectedState(
                "cannot replay backward from \(state.tick) to \(tick)"
            )
        }
        while state.tick < tick {
            guard state.status == .playing else {
                throw ProductionStoryFixtureError.unexpectedState(
                    "terminal state before tick \(tick)"
                )
            }
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
        throw ProductionStoryFixtureError.conditionNotReached
    }

    private func advanceOneCycle(_ state: inout CityGameState) {
        for _ in 0..<4 { CitySimulation.step(&state) }
    }

    private func requireIdentity(
        _ state: CityGameState,
        strategy: CityStrategy,
        phase: CityStrategyPhase,
        resolution: CityStrategyRecoveryResolution?,
        status: GameStatus
    ) throws {
        guard state.progression?.strategy?.committedStrategy == strategy,
              state.progression?.strategy?.currentPhase == phase,
              state.progression?.strategy?.recoveryResolution == resolution,
              state.status == status else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(strategy.rawValue): expected \(phase.rawValue)/\(status.rawValue)"
            )
        }
    }
}

enum ProductionStoryFixtureError: Error, Equatable {
    case commandRejected(String)
    case conditionNotReached
    case unexpectedState(String)
}
