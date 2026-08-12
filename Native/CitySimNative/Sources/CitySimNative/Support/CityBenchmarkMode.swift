import Foundation

struct CityBenchmarkDefinition: Equatable, Sendable {
    static let verticalSlice = CityBenchmarkDefinition(
        id: "native-vertical-slice-v1",
        title: "Native Vertical Slice",
        detail: "Runs 400 deterministic simulation pulses across a fully developed 24×24 city, then verifies the final state hash.",
        seed: 2_026_081_202,
        pulseCount: 400,
        provisionalAverageBudgetMilliseconds: 16,
        expectedFinalFingerprint: "78643578ae520d9e0963056964cc302a6d908c1cafaca202b5b5522054e3ac71"
    )

    let id: String
    let title: String
    let detail: String
    let seed: UInt64
    let pulseCount: Int
    let provisionalAverageBudgetMilliseconds: Double
    let expectedFinalFingerprint: String?

    var citySize: String { "24×24 · 576 tiles" }
    var qualification: String {
        "Local diagnostic only · results do not certify release hardware or renderer performance."
    }

    func makeState() -> CityGameState {
        var state = CityGameState.newCity(seed: seed)
        state.cityName = "Benchmark City"
        state.treasury = 5_000_000
        state.population = 3_000
        state.jobs = 2_100
        state.happiness = 62
        state.approval = 61
        state.taxRate = 0.12
        state.progression = nil
        state.messages = []

        for index in state.tiles.indices {
            guard state.tiles[index].kind == .empty else { continue }
            let coordinate = state.tiles[index].coordinate
            guard (2...21).contains(coordinate.x), (2...21).contains(coordinate.y) else { continue }
            let kind: BuildingKind
            if coordinate.x.isMultiple(of: 4) || coordinate.y.isMultiple(of: 4) {
                kind = .road
            } else {
                kind = switch (coordinate.x * 7 + coordinate.y * 11) % 16 {
                case 0...7: .residential
                case 8...10: .commercial
                case 11...12: .industrial
                case 13: .powerPlant
                case 14: .waterTower
                default: .park
                }
            }
            state.tiles[index] = CityTile(
                coordinate: coordinate,
                kind: kind,
                level: kind == .road || kind == .park ? 1 : 3,
                occupancy: kind == .residential ? 210 : (kind == .commercial ? 60 : 80),
                condition: 0.92,
                constructionProgress: 1
            )
        }

        let replacements: [(GridCoordinate, BuildingKind)] = [
            (GridCoordinate(x: 3, y: 3), .powerPlant),
            (GridCoordinate(x: 7, y: 3), .powerPlant),
            (GridCoordinate(x: 11, y: 3), .waterTower),
            (GridCoordinate(x: 15, y: 3), .waterTower),
            (GridCoordinate(x: 19, y: 3), .fireStation),
            (GridCoordinate(x: 3, y: 7), .policeStation),
            (GridCoordinate(x: 7, y: 7), .school),
        ]
        for (coordinate, kind) in replacements {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: kind)
            }
        }
        state.powerCapacity = state.tiles.filter { $0.kind == .powerPlant }.count
            * CitySimulation.powerCapacityPerPlant
        state.waterCapacity = state.tiles.filter { $0.kind == .waterTower }.count
            * CitySimulation.waterCapacityPerTower
        state.powerUsed = 2_500
        state.waterUsed = 2_200
        return state
    }
}

struct CityBenchmarkResult: Codable, Equatable, Sendable {
    let benchmarkID: String
    let pulseCount: Int
    let logicalTicks: Int
    let developedTiles: Int
    let totalMilliseconds: Double
    let averagePulseMilliseconds: Double
    let p95PulseMilliseconds: Double
    let pulsesPerSecond: Double
    let finalFingerprint: String
    let finalPopulation: Int
    let finalTreasury: Double
    let finalStatus: String
    let withinProvisionalBudget: Bool
    let fingerprintVerified: Bool

    var assessment: String {
        if !fingerprintVerified { return "Deterministic workload identity did not match" }
        return withinProvisionalBudget
            ? "Verified state · within the provisional 16 ms pulse budget"
            : "Verified state · outside the provisional 16 ms pulse budget"
    }

    var shortFingerprint: String { String(finalFingerprint.prefix(12)) }
}

enum CityBenchmarkRunError: Error, Equatable {
    case canceled
}

enum CityBenchmarkRunner {
    static func run(
        definition: CityBenchmarkDefinition = .verticalSlice,
        progress: @escaping @Sendable (Int, Int) async -> Void = { _, _ in }
    ) async throws -> CityBenchmarkResult {
        var state = definition.makeState()
        let startingTick = state.tick
        let developedTiles = state.tiles.filter { $0.kind != .empty }.count
        var samples = [Double]()
        samples.reserveCapacity(definition.pulseCount)
        let totalStart = DispatchTime.now().uptimeNanoseconds

        for pulse in 1...definition.pulseCount {
            if Task.isCancelled { throw CityBenchmarkRunError.canceled }
            let start = DispatchTime.now().uptimeNanoseconds
            CitySimulation.step(&state)
            let end = DispatchTime.now().uptimeNanoseconds
            samples.append(Double(end - start) / 1_000_000)
            if pulse == 1 || pulse.isMultiple(of: 20) || pulse == definition.pulseCount {
                await progress(pulse, definition.pulseCount)
                await Task.yield()
            }
        }

        let totalEnd = DispatchTime.now().uptimeNanoseconds
        let totalMilliseconds = Double(totalEnd - totalStart) / 1_000_000
        let sortedSamples = samples.sorted()
        let p95Index = max(0, min(sortedSamples.count - 1, Int(ceil(Double(sortedSamples.count) * 0.95)) - 1))
        let average = samples.reduce(0, +) / Double(max(1, samples.count))
        let fingerprint = try CityStateFingerprinter.fingerprint(state).digest
        return CityBenchmarkResult(
            benchmarkID: definition.id,
            pulseCount: definition.pulseCount,
            logicalTicks: state.tick - startingTick,
            developedTiles: developedTiles,
            totalMilliseconds: totalMilliseconds,
            averagePulseMilliseconds: average,
            p95PulseMilliseconds: sortedSamples[p95Index],
            pulsesPerSecond: totalMilliseconds > 0
                ? Double(definition.pulseCount) / (totalMilliseconds / 1_000)
                : 0,
            finalFingerprint: fingerprint,
            finalPopulation: state.population,
            finalTreasury: state.treasury,
            finalStatus: state.status.rawValue,
            withinProvisionalBudget: average <= definition.provisionalAverageBudgetMilliseconds,
            fingerprintVerified: definition.expectedFinalFingerprint.map { $0 == fingerprint } ?? true
        )
    }
}

enum CityBenchmarkPhase: Equatable, Sendable {
    case ready
    case running
    case complete
    case canceled
    case failed
}

struct CityBenchmarkSessionPresentation: Equatable, Sendable {
    let definition: CityBenchmarkDefinition
    var phase: CityBenchmarkPhase
    var completedPulses: Int
    var result: CityBenchmarkResult?
    var reportURL: URL?
    var message: String?

    static func ready(definition: CityBenchmarkDefinition = .verticalSlice) -> Self {
        Self(
            definition: definition,
            phase: .ready,
            completedPulses: 0,
            result: nil,
            reportURL: nil,
            message: nil
        )
    }

    var progress: Double {
        Double(completedPulses) / Double(max(1, definition.pulseCount))
    }
}
