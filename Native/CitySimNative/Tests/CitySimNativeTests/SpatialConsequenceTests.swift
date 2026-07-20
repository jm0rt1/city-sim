import Foundation
import XCTest
@testable import CitySimNative

final class SpatialConsequenceTests: XCTestCase {
    func testMapIsImmutableRowMajorAndProvidesBoundedConstantIndexLookup() throws {
        var state = CityGameState.newCity(seed: 42)
        let snapshot = try CityPresentationSnapshot(state: state)

        XCTAssertEqual(snapshot.spatialConsequences.width, 24)
        XCTAssertEqual(snapshot.spatialConsequences.height, 24)
        XCTAssertEqual(snapshot.spatialConsequences.samples.count, 576)
        XCTAssertEqual(snapshot.spatialConsequences.samples.first?.coordinate, GridCoordinate(x: 0, y: 0))
        XCTAssertEqual(snapshot.spatialConsequences.samples.last?.coordinate, GridCoordinate(x: 23, y: 23))
        XCTAssertEqual(
            snapshot.spatialConsequences[GridCoordinate(x: 10, y: 11)],
            snapshot.spatialConsequences.samples[11 * 24 + 10]
        )
        XCTAssertNil(snapshot.spatialConsequences[GridCoordinate(x: -1, y: 0)])
        XCTAssertNil(snapshot.spatialConsequences[GridCoordinate(x: 24, y: 0)])

        state.powerCapacity = 0
        state.updateTile(at: GridCoordinate(x: 10, y: 11)) { $0.condition = 0 }
        XCTAssertNotEqual(
            try CityPresentationSnapshot(state: state).spatialConsequences,
            snapshot.spatialConsequences
        )
    }

    func testUtilityPublishesIndependentBandsFromFullyActiveSources() throws {
        var state = CityGameState.newCity(seed: 42)
        state.powerCapacity = 100
        state.powerUsed = 200
        state.waterCapacity = 50
        state.waterUsed = 200

        let sample = try XCTUnwrap(
            CityPresentationSnapshot(state: state).spatialConsequences[GridCoordinate(x: 12, y: 13)]
        )
        XCTAssertEqual(sample.utility.power, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(sample.utility.water, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(sample.utility.combined, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(sample.utility.powerBand, .strained)
        XCTAssertEqual(sample.utility.waterBand, .severe)
        XCTAssertEqual(sample.utility.combinedBand, .severe)

        state.updateTile(at: GridCoordinate(x: 13, y: 13)) { $0.constructionProgress = 0.75 }
        let inactiveSource = try XCTUnwrap(
            CityPresentationSnapshot(state: state).spatialConsequences[GridCoordinate(x: 13, y: 13)]
        )
        XCTAssertEqual(inactiveSource.utility.power, 0)
        XCTAssertEqual(inactiveSource.utility.powerBand, .severe)
    }

    func testPollutionExposureIsBoundedSourceDrivenAndMitigatedByActiveParks() throws {
        var withPark = CityGameState.newCity(seed: 42)
        let coordinate = GridCoordinate(x: 12, y: 13)
        var clean = withPark
        clean.updateTile(at: GridCoordinate(x: 14, y: 11)) { $0.kind = .empty }
        clean.updateTile(at: GridCoordinate(x: 13, y: 13)) { $0.kind = .empty }
        let cleanSnapshot = try CityPresentationSnapshot(state: clean)

        withPark.tick = 1
        let pollutedSnapshot = try CityPresentationSnapshot(state: withPark)
        let mitigated = try XCTUnwrap(
            pollutedSnapshot.spatialConsequences[coordinate]
        )

        withPark.updateTile(at: GridCoordinate(x: 11, y: 13)) { $0.kind = .empty }
        let withoutPark = try XCTUnwrap(
            CityPresentationSnapshot(state: withPark).spatialConsequences[coordinate]
        )
        let far = try XCTUnwrap(
            CityPresentationSnapshot(state: withPark).spatialConsequences[GridCoordinate(x: 0, y: 0)]
        )

        XCTAssertGreaterThan(withoutPark.pollutionExposure, mitigated.pollutionExposure)
        XCTAssertGreaterThan(withoutPark.pollutionExposure, far.pollutionExposure)
        XCTAssertTrue((0...1).contains(mitigated.pollutionExposure))
        XCTAssertEqual(withoutPark.pollutionBand, .severe)
        XCTAssertEqual(far.pollutionBand, .healthy)

        let worsening = try XCTUnwrap(pollutedSnapshot.consequenceEvents(since: cleanSnapshot).first {
            $0.coordinate == coordinate && $0.dimension == .pollution
        })
        XCTAssertEqual(worsening.direction, .worsening)
        XCTAssertEqual(worsening.fromBand, .healthy)
        XCTAssertEqual(worsening.toBand, .severe)
    }

    func testVitalityUsesOnlyActiveAuthoritativeLocationInputs() throws {
        let coordinate = GridCoordinate(x: 10, y: 11)
        var prosperous = CityGameState.newCity(seed: 42)
        prosperous.happiness = 100
        prosperous.updateTile(at: coordinate) {
            $0.condition = 1
            $0.occupancy = 280
            $0.constructionProgress = 1
        }
        let prosperousSample = try XCTUnwrap(
            CityPresentationSnapshot(state: prosperous).spatialConsequences[coordinate]
        )
        XCTAssertEqual(prosperousSample.vitality, .prosperous)
        XCTAssertTrue((0...1).contains(prosperousSample.vitalityScore))

        var strained = prosperous
        strained.happiness = 0
        strained.powerCapacity = 0
        strained.waterCapacity = 0
        strained.updateTile(at: coordinate) {
            $0.condition = 0
            $0.occupancy = 0
        }
        let strainedSample = try XCTUnwrap(
            CityPresentationSnapshot(state: strained).spatialConsequences[coordinate]
        )
        XCTAssertEqual(strainedSample.vitality, .strained)
        XCTAssertLessThan(strainedSample.vitalityScore, prosperousSample.vitalityScore)

        strained.updateTile(at: coordinate) { $0.constructionProgress = 0.75 }
        let incomplete = try XCTUnwrap(
            CityPresentationSnapshot(state: strained).spatialConsequences[coordinate]
        )
        XCTAssertEqual(incomplete.vitality, .notApplicable)
        XCTAssertEqual(incomplete.vitality.comparisonBand, nil)
    }

    func testTransitionEventsAreStableOrderedAndSuppressDiscontinuities() throws {
        var strained = CityGameState.newCity(seed: 42)
        strained.powerCapacity = 0
        strained.waterCapacity = 0
        let previous = try CityPresentationSnapshot(state: strained)

        var recovered = strained
        recovered.tick = 1
        recovered.powerCapacity = 300
        recovered.waterCapacity = 270
        let current = try CityPresentationSnapshot(state: recovered)

        let first = current.consequenceEvents(since: previous)
        let repeated = current.consequenceEvents(since: previous)
        XCTAssertEqual(first, repeated)
        XCTAssertFalse(first.isEmpty)
        XCTAssertTrue(first.allSatisfy { $0.direction == .recovery })
        XCTAssertEqual(first.map(\.id), first.map(\.id).sorted(by: eventIDOrder))
        XCTAssertTrue(first.allSatisfy {
            $0.id.hasPrefix("spatial-v1:\(current.fingerprint.version):\(current.fingerprint.digest):")
        })

        XCTAssertTrue(current.consequenceEvents(since: nil).isEmpty)
        XCTAssertTrue(current.consequenceEvents(since: current).isEmpty)

        var sameTick = recovered
        sameTick.treasury += 1
        XCTAssertTrue(
            try CityPresentationSnapshot(state: sameTick).consequenceEvents(since: current).isEmpty
        )

        var wrongDimensions = recovered
        wrongDimensions.tick = 2
        wrongDimensions.gridWidth = 12
        wrongDimensions.gridHeight = 48
        XCTAssertTrue(
            try CityPresentationSnapshot(state: wrongDimensions).consequenceEvents(since: current).isEmpty
        )
    }

    func testVitalityEventsSuppressNotApplicableEndpointsAndReportRecovery() throws {
        let coordinate = GridCoordinate(x: 10, y: 11)
        var inactive = CityGameState.newCity(seed: 42)
        inactive.updateTile(at: coordinate) { $0.constructionProgress = 0.75 }
        let inactiveSnapshot = try CityPresentationSnapshot(state: inactive)

        var active = inactive
        active.tick = 1
        active.updateTile(at: coordinate) { $0.constructionProgress = 1 }
        let activeSnapshot = try CityPresentationSnapshot(state: active)
        XCTAssertFalse(activeSnapshot.consequenceEvents(since: inactiveSnapshot).contains {
            $0.coordinate == coordinate && $0.dimension == .vitality
        })

        var strained = active
        strained.happiness = 0
        strained.powerCapacity = 0
        strained.waterCapacity = 0
        strained.updateTile(at: coordinate) {
            $0.condition = 0
            $0.occupancy = 0
        }
        let strainedSnapshot = try CityPresentationSnapshot(state: strained)

        var recovered = strained
        recovered.tick = 2
        recovered.happiness = 100
        recovered.powerCapacity = 300
        recovered.waterCapacity = 270
        recovered.updateTile(at: coordinate) {
            $0.condition = 1
            $0.occupancy = 280
        }
        let recoveredSnapshot = try CityPresentationSnapshot(state: recovered)
        let event = try XCTUnwrap(recoveredSnapshot.consequenceEvents(since: strainedSnapshot).first {
            $0.coordinate == coordinate && $0.dimension == .vitality
        })
        XCTAssertEqual(event.direction, .recovery)
        XCTAssertEqual(event.fromBand, .severe)
        XCTAssertEqual(event.toBand, .healthy)
    }

    @MainActor
    func testSaveLoadLegacyAndUndoPreserveExactDerivedTruthWithoutChangingBytes() throws {
        try withTemporaryRoot { root in
            let state = CityGameState.newCity(seed: 42)
            let canonicalBefore = try CityStateFingerprinter.canonicalData(for: state)
            let service = SaveGameService(rootURL: root)
            let write = try service.save(state)
            let saveBeforeSnapshot = try Data(contentsOf: service.saveURL)
            let before = try CityPresentationSnapshot(state: state)
            let load = try service.load()
            let after = try CityPresentationSnapshot(state: load.state)

            XCTAssertEqual(before.spatialConsequences, after.spatialConsequences)
            XCTAssertEqual(before.fingerprint, after.fingerprint)
            XCTAssertEqual(write.fingerprint, before.fingerprint)
            XCTAssertEqual(saveBeforeSnapshot, try Data(contentsOf: service.saveURL))
            XCTAssertEqual(canonicalBefore, try CityStateFingerprinter.canonicalData(for: state))

            let legacyRoot = root.appending(path: "legacy", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: legacyRoot, withIntermediateDirectories: true)
            let legacyService = SaveGameService(rootURL: legacyRoot)
            try JSONEncoder().encode(state).write(to: legacyService.saveURL, options: .atomic)
            let legacy = try legacyService.load()
            XCTAssertEqual(legacy.schemaVersion, 0)
            XCTAssertEqual(
                try CityPresentationSnapshot(state: legacy.state).spatialConsequences,
                before.spatialConsequences
            )
        }

        let store = CityGameStore(state: .newCity(seed: 42))
        let beforeState = store.state
        let before = try CityPresentationSnapshot(state: beforeState)
        store.selectTool(.residential)
        store.primaryAction(at: GridCoordinate(x: 8, y: 11))
        store.undoLastAction()
        let undoneState = store.state
        let undone = try CityPresentationSnapshot(state: undoneState)
        XCTAssertEqual(undone, before)
        XCTAssertTrue(undone.consequenceEvents(since: before).isEmpty)
    }

    func testReplayProducesExactMapsAcrossEquivalentTickGrouping() throws {
        let startingState = CityGameState.newCity(seed: 42)
        let snapshots = try SimulationSpeed.allCases.filter { $0 != .paused }.map { speed in
            var state = startingState
            var remaining = 120
            while remaining > 0 {
                let group = min(speed.ticksPerPulse, remaining)
                for _ in 0..<group { CitySimulation.step(&state) }
                remaining -= group
            }
            return try CityPresentationSnapshot(state: state)
        }

        XCTAssertEqual(snapshots[0], snapshots[1])
        XCTAssertEqual(snapshots[1], snapshots[2])
        XCTAssertEqual(snapshots[0].spatialConsequences, snapshots[2].spatialConsequences)
    }

    func testAcceptedAndDenseFixturesMeetDerivationDiffAndStorageBudgets() throws {
        let states = [
            CityGameState.newCity(seed: 42),
            strategyState(kind: .commercial),
            strategyState(kind: .industrial),
            strainedState(),
            recoveredState(),
            denseState()
        ]

        var derivationMilliseconds: [Double] = []
        for state in states {
            _ = CitySpatialConsequenceMap(state: state)
            let start = ProcessInfo.processInfo.systemUptime
            let map = CitySpatialConsequenceMap(state: state)
            derivationMilliseconds.append(elapsedMilliseconds(since: start))
            XCTAssertEqual(map.samples.count, 576)
        }

        let previous = try CityPresentationSnapshot(state: strainedState())
        let current = try CityPresentationSnapshot(state: recoveredState())
        let diffStart = ProcessInfo.processInfo.systemUptime
        let events = current.consequenceEvents(since: previous)
        let diffMilliseconds = elapsedMilliseconds(since: diffStart)
        let retainedBytes = MemoryLayout<CitySpatialConsequence>.stride * 576

        XCTAssertLessThanOrEqual(derivationMilliseconds.reduce(0, +) / Double(states.count), 5)
        XCTAssertLessThanOrEqual(try XCTUnwrap(derivationMilliseconds.max()), 10)
        XCTAssertLessThanOrEqual(diffMilliseconds, 5)
        XCTAssertLessThanOrEqual(events.count, 1_728)
        XCTAssertLessThanOrEqual(retainedBytes, 128 * 1_024)

        let selected = GridCoordinate(x: 10, y: 11)
        let rendererInput = current.spatialConsequences[selected]
        let uiInput = current.spatialConsequences[selected]
        XCTAssertEqual(rendererInput, uiInput)

        print(
            "CITYSIM_PLAY041_SPATIAL_DIAGNOSTICS fixtures=\(states.count) " +
            "average_ms=\(metric(derivationMilliseconds.reduce(0, +) / Double(states.count))) " +
            "max_ms=\(metric(try XCTUnwrap(derivationMilliseconds.max()))) " +
            "diff_ms=\(metric(diffMilliseconds)) events=\(events.count) " +
            "retained_sample_bytes=\(retainedBytes)"
        )
    }

    private func eventIDOrder(_ lhs: String, _ rhs: String) -> Bool {
        func components(_ id: String) -> (Int, Int, Int) {
            let values = id.split(separator: ":")
            return (
                Int(values[3]) ?? -1,
                Int(values[4]) ?? -1,
                CitySpatialConsequenceDimension(rawValue: String(values[5]))?.order ?? -1
            )
        }
        let left = components(lhs)
        let right = components(rhs)
        if left.1 != right.1 { return left.1 < right.1 }
        if left.0 != right.0 { return left.0 < right.0 }
        return left.2 < right.2
    }

    private func strategyState(kind: BuildingKind) -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.updateTile(at: GridCoordinate(x: 8, y: 11)) {
            $0.kind = kind
            $0.occupancy = CitySimulation.jobCapacity(for: kind)
        }
        return state
    }

    private func strainedState() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.tick = 4
        state.powerCapacity = 0
        state.waterCapacity = 0
        state.happiness = 20
        state.updateTile(at: GridCoordinate(x: 10, y: 11)) {
            $0.condition = 0.2
            $0.occupancy = 0
        }
        return state
    }

    private func recoveredState() -> CityGameState {
        var state = strainedState()
        state.tick = 8
        state.powerCapacity = 300
        state.waterCapacity = 270
        state.happiness = 80
        state.updateTile(at: GridCoordinate(x: 10, y: 11)) {
            $0.condition = 1
            $0.occupancy = 280
        }
        return state
    }

    private func denseState() -> CityGameState {
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

    private func withTemporaryRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play041-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func elapsedMilliseconds(since start: TimeInterval) -> Double {
        (ProcessInfo.processInfo.systemUptime - start) * 1_000
    }

    private func metric(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

private extension CitySpatialConsequenceDimension {
    var order: Int {
        switch self {
        case .utility: 0
        case .pollution: 1
        case .vitality: 2
        }
    }
}
