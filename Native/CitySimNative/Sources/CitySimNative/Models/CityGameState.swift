import Foundation

enum CityStrategy: String, Codable, Equatable, Sendable {
    case commercialStewardship
    case industrialExpansion
}

enum CityStrategyPhase: String, Codable, Equatable, Sendable {
    case opportunity
    case complication
    case setback
    case recovery
    case completed
}

enum CityStrategyRecoveryResolution: String, Codable, Equatable, Sendable {
    case commercialTaxRelief
    case commercialPublicRealmInvestment
    case industrialUtilityExpansion
    case industrialGreenBuffer
}

struct CityStrategyProgression: Codable, Equatable, Sendable {
    var committedStrategy: CityStrategy
    var currentPhase: CityStrategyPhase
    var nextScheduledTick: Int?
    var recoveryResolution: CityStrategyRecoveryResolution? = nil
}

enum CitySecondActPhase: String, Codable, Equatable, Sendable {
    case mandate
    case warnedPressure
    case recovery
    case qualification
    case completed
}

struct CitySecondActProgression: Codable, Equatable, Sendable {
    var phase: CitySecondActPhase
    var nextScheduledTick: Int?
    var qualifyingCycles: Int = 0
    var regionalCapitalAwarded = false
}

struct CityProgressionState: Codable, Equatable, Sendable {
    var townCharterQualifyingCycles: Int = 0
    var townCharterAwarded = false
    var strategy: CityStrategyProgression?
    var secondAct: CitySecondActProgression? = nil

    /// This is decode-derived process provenance for a sealed historical replay.
    /// It is intentionally excluded from public state encoding and equality.
    private var suppressCurrentConsequenceMessagesForLegacyReplay = false

    init(
        townCharterQualifyingCycles: Int = 0,
        townCharterAwarded: Bool = false,
        strategy: CityStrategyProgression? = nil,
        secondAct: CitySecondActProgression? = nil
    ) {
        self.townCharterQualifyingCycles = townCharterQualifyingCycles
        self.townCharterAwarded = townCharterAwarded
        self.strategy = strategy
        self.secondAct = secondAct
    }

    private enum CodingKeys: String, CodingKey {
        case townCharterQualifyingCycles
        case townCharterAwarded
        case strategy
        case secondAct
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        townCharterQualifyingCycles = try container.decodeIfPresent(Int.self, forKey: .townCharterQualifyingCycles) ?? 0
        townCharterAwarded = try container.decodeIfPresent(Bool.self, forKey: .townCharterAwarded) ?? false
        strategy = try container.decodeIfPresent(CityStrategyProgression.self, forKey: .strategy)
        secondAct = try container.decodeIfPresent(CitySecondActProgression.self, forKey: .secondAct)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(townCharterQualifyingCycles, forKey: .townCharterQualifyingCycles)
        try container.encode(townCharterAwarded, forKey: .townCharterAwarded)
        try container.encodeIfPresent(strategy, forKey: .strategy)
        try container.encodeIfPresent(secondAct, forKey: .secondAct)
    }

    static func == (lhs: CityProgressionState, rhs: CityProgressionState) -> Bool {
        lhs.townCharterQualifyingCycles == rhs.townCharterQualifyingCycles
            && lhs.townCharterAwarded == rhs.townCharterAwarded
            && lhs.strategy == rhs.strategy
            && lhs.secondAct == rhs.secondAct
    }

    mutating func preserveLegacyReplayConsequences() {
        suppressCurrentConsequenceMessagesForLegacyReplay = true
    }

    var preservesLegacyReplayConsequences: Bool {
        suppressCurrentConsequenceMessagesForLegacyReplay
    }
}

enum CityStormRecoveryDisposition: String, Codable, Equatable, Sendable {
    case active
    case recovered
}

struct CityStormRecoveryTarget: Codable, Equatable, Sendable {
    let coordinate: GridCoordinate
    var remainingConditionDamage: Double
}

struct CityStormRecoveryState: Codable, Equatable, Sendable {
    var latestEventTick: Int
    var latestEventSeed: UInt64
    var targets: [CityStormRecoveryTarget]
    var disposition: CityStormRecoveryDisposition
}

struct CityStormProtectionSnapshot: Equatable, Sendable {
    let utilityReserve: Double
    let parkCount: Int
    let serviceCount: Int
    let exposedResidentialLots: Int
    let estimatedConditionDamage: Double
}

struct CityHistorySample: Codable, Equatable, Sendable, Identifiable {
    let tick: Int
    let treasury: Double
    let population: Int
    let jobs: Int
    let happiness: Double
    let approval: Double
    let projectedBalance: Double

    var id: Int { tick }
    var day: Int { tick / 4 + 1 }
}

struct CityGameState: Codable, Equatable, Sendable {
    /// Immutable PLAY083 v3 starting states whose historical replay predates
    /// the current player-facing construction and tax-relief consequences.
    /// This provenance remains private to a live replay and is excluded from
    /// schema-1 encoding and fingerprint-v1 canonical bytes.
    private static let legacyReplayFixtureDigests: Set<String> = [
        "c6b15615848267ab1387049a2b43979ecf15dbf6680343fcc2ffb7c2b6de6f17",
        "789979ccca42365c7a03107bade3939437d60417cdb2915da3f258d630303eba",
    ]

    var cityName: String
    var gridWidth: Int
    var gridHeight: Int
    var tiles: [CityTile]
    var tick: Int
    var treasury: Double
    var population: Int
    var jobs: Int
    var happiness: Double
    var approval: Double
    var powerUsed: Int
    var powerCapacity: Int
    var waterUsed: Int
    var waterCapacity: Int
    var taxRate: Double
    var demand: DemandLevels
    var messages: [CityMessage]
    var progression: CityProgressionState?
    var stormRecovery: CityStormRecoveryState? = nil
    var authoredScenario: CityAuthoredScenarioSession? = nil
    var sandboxRules: CitySandboxRules? = nil
    /// Daily, bounded observations for cities created by versions that support
    /// trend history. `nil` preserves the exact identity of older checkpoints.
    var cityHistory: [CityHistorySample]? = nil
    var status: GameStatus
    var seed: UInt64

    var day: Int { tick / 4 + 1 }
    var formattedDay: String { "Day \(day)" }

    var usesUnlimitedFunds: Bool { sandboxRules?.unlimitedFunds == true }

    var preservesLegacyReplayConsequences: Bool {
        progression?.preservesLegacyReplayConsequences ?? false
    }

    mutating func preserveLegacyReplayConsequences() {
        guard progression != nil else { return }
        progression?.preserveLegacyReplayConsequences()
    }

    mutating func preserveLegacyReplayConsequencesIfKnownFixture() {
        guard !preservesLegacyReplayConsequences,
              let digest = try? CityStateFingerprinter.fingerprint(self).digest,
              Self.legacyReplayFixtureDigests.contains(digest) else {
            return
        }
        preserveLegacyReplayConsequences()
    }

    static func newCity(seed: UInt64 = 0xC17C1A) -> CityGameState {
        let width = 24
        let height = 24
        var tiles = (0..<(width * height)).map { index in
            CityTile(
                coordinate: GridCoordinate(x: index % width, y: index / width),
                kind: .empty
            )
        }
        func set(_ x: Int, _ y: Int, _ kind: BuildingKind) {
            tiles[y * width + x].kind = kind
        }
        for x in 4..<17 {
            set(x, 9, .road)
            set(x, 12, .road)
        }
        for y in 9...12 {
            set(4, y, .road)
            set(12, y, .road)
            set(16, y, .road)
        }
        set(8, 10, .road)
        set(8, 11, .road)

        set(11, 11, .cityHall)
        set(10, 11, .residential)
        set(9, 10, .residential)
        set(6, 10, .residential)
        set(6, 11, .residential)
        set(3, 10, .residential)
        set(17, 10, .residential)
        set(13, 11, .commercial)
        set(14, 11, .industrial)
        set(11, 13, .park)
        set(13, 13, .powerPlant)
        set(15, 13, .waterTower)

        return CityGameState(
            cityName: "New Arcadia", gridWidth: width, gridHeight: height,
            tiles: tiles, tick: 0, treasury: 32_000, population: 300, jobs: 190,
            happiness: 58, approval: 56, powerUsed: 246, powerCapacity: 300,
            waterUsed: 222, waterCapacity: 270, taxRate: 0.10,
            demand: DemandLevels(residential: 0.72, commercial: 0.68, industrial: 0.56),
            messages: [CityMessage(tick: 0, severity: .information,
                                   title: "A Town at the Crossroads",
                                   detail: "New Arcadia's three-block starter town runs a $126 operating deficit with only 54 power and 48 water spare. Choose Commercial for a cleaner recovery or Industrial for faster cash, or secure utility headroom before growth exposes the shortfall.")],
            progression: CityProgressionState(), stormRecovery: nil,
            status: .playing, seed: seed
        )
    }

    func tile(at coordinate: GridCoordinate) -> CityTile? {
        guard coordinate.x >= 0, coordinate.y >= 0,
              coordinate.x < gridWidth, coordinate.y < gridHeight else { return nil }
        return tiles[coordinate.y * gridWidth + coordinate.x]
    }

    mutating func updateTile(at coordinate: GridCoordinate, _ update: (inout CityTile) -> Void) {
        guard coordinate.x >= 0, coordinate.y >= 0,
              coordinate.x < gridWidth, coordinate.y < gridHeight else { return }
        update(&tiles[coordinate.y * gridWidth + coordinate.x])
    }

    func neighbors(of coordinate: GridCoordinate) -> [CityTile] {
        [(1, 0), (-1, 0), (0, 1), (0, -1)].compactMap {
            tile(at: GridCoordinate(x: coordinate.x + $0.0, y: coordinate.y + $0.1))
        }
    }
}

extension CityGameState {
    static let maximumHistorySampleCount = 90

    static func newTrackedCity(seed: UInt64 = 0xC17C1A) -> CityGameState {
        var state = newCity(seed: seed)
        state.beginHistoryTracking()
        return state
    }

    mutating func beginHistoryTracking() {
        cityHistory = []
        recordHistorySample()
    }

    mutating func recordHistorySample() {
        guard var history = cityHistory else { return }
        let sample = CityHistorySample(
            tick: tick,
            treasury: treasury,
            population: population,
            jobs: jobs,
            happiness: happiness,
            approval: approval,
            projectedBalance: CitySimulation.projectedBalance(in: self)
        )
        if history.last?.tick == tick {
            history[history.count - 1] = sample
        } else {
            history.append(sample)
        }
        if history.count > Self.maximumHistorySampleCount {
            history.removeFirst(history.count - Self.maximumHistorySampleCount)
        }
        cityHistory = history
    }
}
