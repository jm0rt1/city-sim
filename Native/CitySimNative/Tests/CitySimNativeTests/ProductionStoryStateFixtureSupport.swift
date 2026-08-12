import CryptoKit
import Foundation
@testable import CitySimNative

enum ProductionStoryMoment: String, Codable, CaseIterable, Sendable {
    case opening
    case complication
    case recovery
    case charterVictory
}

enum ProductionStoryStage: String, Codable, CaseIterable, Sendable {
    case opening
    case complication
    case recovery
    case charterMidpoint
    case regionalCapital
}

struct ProductionStoryFixtureDefinition: Equatable, Sendable {
    let id: String
    let file: String
    let strategy: CityStrategy
    // Retained for dependent renderer/UI consumers until their claimed adoption.
    let moment: ProductionStoryMoment
    let stage: ProductionStoryStage
    let phase: CityStrategyPhase
    let secondActPhase: CitySecondActPhase?
    let resolution: CityStrategyRecoveryResolution?
    let status: GameStatus
    let messageTitle: String
}

struct ProductionStoryFixtureState: Equatable, Sendable {
    let definition: ProductionStoryFixtureDefinition
    let state: CityGameState
}

// This exact shape decodes the immutable PLAY-047 v1 manifest.
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

// PLAY-069 v2, PLAY-072 v3, and PLAY-078 v4 intentionally share this shape.
struct ProductionStoryFixtureManifestV2: Codable, Equatable, Sendable {
    let fixtureSet: String
    let schemaVersion: Int
    let fingerprintVersion: Int
    let seed: UInt64
    let fixtures: [Entry]

    struct Entry: Codable, Equatable, Sendable {
        let id: String
        let file: String
        let strategy: CityStrategy
        let stage: ProductionStoryStage
        let tick: Int
        let status: GameStatus
        let phase: CityStrategyPhase
        let secondActPhase: CitySecondActPhase?
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
    static let fixtureSet = "PLAY-130 current production story states"
    static let manifestFile = "story-states-manifest-v6.json"
    static let schemaVersion = 1
    static let fingerprintVersion = 1
    static let seed: UInt64 = 42

    let artifacts: [ProductionStoryFixtureArtifact]
    let manifest: ProductionStoryFixtureManifestV2
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
        let manifest = ProductionStoryFixtureManifestV2(
            fixtureSet: fixtureSet,
            schemaVersion: schemaVersion,
            fingerprintVersion: fingerprintVersion,
            seed: seed,
            fixtures: artifacts.map { artifact in
                ProductionStoryFixtureManifestV2.Entry(
                    id: artifact.definition.id,
                    file: artifact.definition.file,
                    strategy: artifact.definition.strategy,
                    stage: artifact.definition.stage,
                    tick: artifact.state.tick,
                    status: artifact.state.status,
                    phase: artifact.definition.phase,
                    secondActPhase: artifact.definition.secondActPhase,
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
            to: root.appending(path: Self.manifestFile),
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
            path: "citysim-play078-story-\(id)-\(UUID().uuidString)",
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
    private let resolutions: [CityStrategyRecoveryResolution] = [
        .commercialTaxRelief,
        .commercialPublicRealmInvestment,
        .industrialUtilityExpansion,
        .industrialGreenBuffer,
    ]

    func buildAll() throws -> [ProductionStoryFixtureState] {
        var fixtures = try buildFirstAct(strategy: .commercialStewardship)
            + buildFirstAct(strategy: .industrialExpansion)
        for resolution in resolutions {
            let state = try regionalCapitalTerminal(resolvedBy: resolution)
            fixtures.append(
                ProductionStoryFixtureState(
                    definition: definition(
                        for: strategy(for: resolution),
                        stage: .regionalCapital,
                        resolution: resolution
                    ),
                    state: state
                )
            )
        }
        return fixtures
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

    func replayRecoveryToCharterMidpoint(
        _ state: CityGameState,
        strategy: CityStrategy
    ) throws -> CityGameState {
        let resolution = defaultResolution(for: strategy)
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
        try requireCharterMidpoint(replay, resolution: resolution)
        return replay
    }

    func replayCharterMidpointToRegionalRecovery(
        _ state: CityGameState,
        resolution: CityStrategyRecoveryResolution
    ) throws -> CityGameState {
        try requireCharterMidpoint(state, resolution: resolution)
        var replay = state
        guard let warningTick = replay.progression?.secondAct?.nextScheduledTick else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(resolution.rawValue): missing Regional warning tick"
            )
        }
        try advanceToTick(&replay, tick: warningTick)
        guard replay.progression?.secondAct?.phase == .warnedPressure,
              let pressureTick = replay.progression?.secondAct?.nextScheduledTick else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(resolution.rawValue): missing Regional pressure tick"
            )
        }
        try advanceToTick(&replay, tick: pressureTick)
        guard replay.progression?.secondAct?.phase == .recovery else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(resolution.rawValue): expected Regional recovery"
            )
        }
        return replay
    }

    func replayRegionalRecoveryToTerminal(
        _ state: CityGameState,
        resolution: CityStrategyRecoveryResolution
    ) throws -> CityGameState {
        let qualification = try replayRegionalRecoveryToQualification(
            state,
            resolution: resolution
        )
        return try replayRegionalQualificationToTerminal(
            qualification,
            resolution: resolution
        )
    }

    func replayRegionalRecoveryToQualification(
        _ state: CityGameState,
        resolution: CityStrategyRecoveryResolution
    ) throws -> CityGameState {
        guard state.status == .playing,
              state.progression?.strategy?.recoveryResolution == resolution,
              state.progression?.secondAct?.phase == .recovery,
              state.progression?.secondAct?.regionalCapitalAwarded == false else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(resolution.rawValue): expected active Regional recovery"
            )
        }
        var replay = state
        try enterRegionalQualification(&replay, resolution: resolution)
        guard replay.progression?.secondAct?.phase == .qualification,
              replay.progression?.secondAct?.regionalCapitalAwarded == false else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(resolution.rawValue): expected Regional qualification"
            )
        }
        return replay
    }

    func replayRegionalQualificationToTerminal(
        _ state: CityGameState,
        resolution: CityStrategyRecoveryResolution
    ) throws -> CityGameState {
        guard state.status == .playing,
              state.progression?.strategy?.recoveryResolution == resolution,
              state.progression?.secondAct?.phase == .qualification,
              state.progression?.secondAct?.regionalCapitalAwarded == false else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(resolution.rawValue): expected active Regional qualification"
            )
        }
        var replay = state
        try advanceUntil(&replay, maximumCycles: 430) {
            $0.status == .won
        }
        guard replay.status == .won,
              replay.progression?.secondAct?.phase == .completed,
              replay.progression?.secondAct?.qualifyingCycles
                == CitySimulation.regionalCapitalQualificationCycles,
              replay.progression?.secondAct?.regionalCapitalAwarded == true,
              replay.messages.filter({
                  $0.title == "Regional Capital Recognized"
              }).count == 1 else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(resolution.rawValue): expected Regional Capital terminal"
            )
        }
        return replay
    }

    func regionalRecovery(
        resolvedBy resolution: CityStrategyRecoveryResolution
    ) throws -> CityGameState {
        try replayCharterMidpointToRegionalRecovery(
            charterCity(resolvedBy: resolution),
            resolution: resolution
        )
    }

    func regionalCapitalTerminal(
        resolvedBy resolution: CityStrategyRecoveryResolution
    ) throws -> CityGameState {
        try replayRegionalRecoveryToTerminal(
            regionalRecovery(resolvedBy: resolution),
            resolution: resolution
        )
    }

    func committedOpening(strategy: CityStrategy) throws -> CityGameState {
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
        return state
    }

    private func buildFirstAct(
        strategy: CityStrategy
    ) throws -> [ProductionStoryFixtureState] {
        var state = try committedOpening(strategy: strategy)
        let opening = ProductionStoryFixtureState(
            definition: definition(for: strategy, stage: .opening),
            state: state
        )

        state = try replayOpeningToComplication(state, strategy: strategy)
        let complication = ProductionStoryFixtureState(
            definition: definition(for: strategy, stage: .complication),
            state: state
        )

        state = try replayComplicationToRecovery(state, strategy: strategy)
        let recovery = ProductionStoryFixtureState(
            definition: definition(for: strategy, stage: .recovery),
            state: state
        )

        state = try replayRecoveryToCharterMidpoint(state, strategy: strategy)
        let midpoint = ProductionStoryFixtureState(
            definition: definition(for: strategy, stage: .charterMidpoint),
            state: state
        )

        return [opening, complication, recovery, midpoint]
    }

    private func charterCity(
        resolvedBy resolution: CityStrategyRecoveryResolution
    ) throws -> CityGameState {
        let strategy = strategy(for: resolution)
        var state = CityGameState.newCity(seed: ProductionStoryFixtureCorpus.seed)
        try advanceToTick(&state, tick: 60)
        try buildFirstValid(jobs(for: strategy), in: &state)
        try advanceToTick(&state, tick: 64)
        try advanceThroughStrategyPhase(&state, phase: .opportunity)
        try advanceThroughStrategyPhase(&state, phase: .complication)
        try advanceThroughStrategyPhase(&state, phase: .setback)
        guard state.progression?.strategy?.recoveryResolution == nil else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(resolution.rawValue): premature first-act recovery"
            )
        }

        switch resolution {
        case .commercialTaxRelief:
            state.taxRate = 0.09
        case .commercialPublicRealmInvestment, .industrialGreenBuffer:
            try buildFirstValid(.park, in: &state)
        case .industrialUtilityExpansion:
            try prepareReserveUtilities(in: &state, count: 2)
        }

        try advanceThroughStrategyPhase(&state, phase: .recovery)
        guard state.progression?.strategy?.recoveryResolution == resolution else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(resolution.rawValue): wrong first-act recovery"
            )
        }

        if resolution == .commercialTaxRelief {
            state.taxRate = 0.10
        }
        try prepareCharterCapacity(in: &state, jobs: jobs(for: strategy))
        state.taxRate = 0.10
        try advanceUntil(&state, maximumCycles: 430) {
            $0.progression?.townCharterAwarded == true
        }
        try requireCharterMidpoint(state, resolution: resolution)
        return state
    }

    private func enterRegionalQualification(
        _ state: inout CityGameState,
        resolution: CityStrategyRecoveryResolution
    ) throws {
        let strategy = strategy(for: resolution)
        if strategy == .industrialExpansion {
            try prepareReserveUtilities(in: &state, count: 3)
        }
        while CityAnalytics(state: state).jobCapacity < 500 {
            let kind = jobs(for: strategy)
            try advanceUntil(&state, maximumCycles: 160) {
                $0.treasury >= kind.buildCost
            }
            try buildFirstValid(kind, in: &state)
            advanceOneCycle(&state)
        }

        switch resolution {
        case .commercialTaxRelief:
            state.taxRate = 0.08
        case .commercialPublicRealmInvestment, .industrialGreenBuffer:
            try buildFirstValid(.park, in: &state)
        case .industrialUtilityExpansion:
            break
        }

        try advanceUntil(&state, maximumCycles: 80) {
            $0.progression?.secondAct?.phase == .qualification
        }
        state.taxRate = 0.10
    }

    private func definition(
        for strategy: CityStrategy,
        stage: ProductionStoryStage,
        resolution suppliedResolution: CityStrategyRecoveryResolution? = nil
    ) -> ProductionStoryFixtureDefinition {
        let prefix = strategy == .commercialStewardship ? "commercial" : "industrial"
        let resolution: CityStrategyRecoveryResolution?
        let phase: CityStrategyPhase
        let secondActPhase: CitySecondActPhase?
        let status: GameStatus
        let messageTitle: String
        let suffix: String
        let moment: ProductionStoryMoment

        switch stage {
        case .opening:
            resolution = nil
            phase = .opportunity
            secondActPhase = nil
            status = .playing
            messageTitle = strategy == .commercialStewardship
                ? "Main Street Crossroads"
                : "Freight Contract Watch"
            suffix = "opening-v6"
            moment = .opening
        case .complication:
            resolution = nil
            phase = .complication
            secondActPhase = nil
            status = .playing
            messageTitle = strategy == .commercialStewardship
                ? "Market Weekend"
                : "Regional Freight Contract"
            suffix = "complication-v6"
            moment = .complication
        case .recovery:
            resolution = defaultResolution(for: strategy)
            phase = .recovery
            secondActPhase = nil
            status = .playing
            messageTitle = strategy == .commercialStewardship
                ? "Storefront Slump Avoided"
                : "Industrial Load Absorbed"
            suffix = "recovery-v6"
            moment = .recovery
        case .charterMidpoint:
            resolution = defaultResolution(for: strategy)
            phase = .completed
            secondActPhase = .mandate
            status = .playing
            messageTitle = "Town Charter Awarded"
            suffix = "charter-midpoint-v6"
            moment = .charterVictory
        case .regionalCapital:
            let route = suppliedResolution ?? defaultResolution(for: strategy)
            resolution = route
            phase = .completed
            secondActPhase = .completed
            status = .won
            messageTitle = "Regional Capital Recognized"
            suffix = "\(route.fixtureName)-regional-capital-v6"
            moment = .charterVictory
        }

        return ProductionStoryFixtureDefinition(
            id: "\(prefix)-\(suffix)",
            file: "story-\(prefix)-\(suffix).json",
            strategy: strategy,
            moment: moment,
            stage: stage,
            phase: phase,
            secondActPhase: secondActPhase,
            resolution: resolution,
            status: status,
            messageTitle: messageTitle
        )
    }

    private func strategy(
        for resolution: CityStrategyRecoveryResolution
    ) -> CityStrategy {
        switch resolution {
        case .commercialTaxRelief, .commercialPublicRealmInvestment:
            .commercialStewardship
        case .industrialUtilityExpansion, .industrialGreenBuffer:
            .industrialExpansion
        }
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
            try prepareReserveUtilities(in: &state, count: 2)
        }
    }

    private func prepareReserveUtilities(
        in state: inout CityGameState,
        count: Int
    ) throws {
        for kind in [BuildingKind.powerPlant, .waterTower] {
            while CityAnalytics(state: state).count(kind) < count {
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
        try prepareReserveUtilities(in: &state, count: 2)
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

    private func requireCharterMidpoint(
        _ state: CityGameState,
        resolution: CityStrategyRecoveryResolution
    ) throws {
        guard state.progression?.townCharterQualifyingCycles
                == CitySimulation.townCharterQualificationCycles,
              state.progression?.townCharterAwarded == true,
              state.progression?.strategy?.recoveryResolution == resolution,
              state.progression?.secondAct?.phase == .mandate,
              state.progression?.secondAct?.regionalCapitalAwarded == false,
              state.status == .playing else {
            throw ProductionStoryFixtureError.unexpectedState(
                "\(resolution.rawValue): expected active Charter midpoint"
            )
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

private extension CityStrategyRecoveryResolution {
    var fixtureName: String {
        switch self {
        case .commercialTaxRelief: "tax-relief"
        case .commercialPublicRealmInvestment: "public-realm"
        case .industrialUtilityExpansion: "utility-expansion"
        case .industrialGreenBuffer: "green-buffer"
        }
    }
}

enum ProductionStoryFixtureError: Error, Equatable {
    case commandRejected(String)
    case conditionNotReached
    case unexpectedState(String)
}
