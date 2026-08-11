import Foundation
import XCTest
@testable import CitySimNative

@MainActor
final class StormRecoveryPlatformTests: XCTestCase {
    private let stormSeed: UInt64 = 3
    private let expectedTargets = [
        GridCoordinate(x: 3, y: 10),
        GridCoordinate(x: 6, y: 10),
        GridCoordinate(x: 9, y: 10),
    ]

    func testPhaseBStormRecoveryPersistsReplaysAndRetiresSafely() throws {
        var uninterrupted = stormReadyState(seed: stormSeed)
        var replay = stormReadyState(seed: stormSeed)

        CitySimulation.step(&uninterrupted)
        CitySimulation.step(&replay)
        XCTAssertEqual(uninterrupted, replay)
        XCTAssertEqual(uninterrupted.stormRecovery?.disposition, .active)
        XCTAssertEqual(uninterrupted.stormRecovery?.targets.map(\.coordinate), expectedTargets)

        let activeFingerprint = try CityStateFingerprinter.fingerprint(uninterrupted)
        let activeSnapshot = try CityPresentationSnapshot(state: uninterrupted)
        XCTAssertEqual(activeSnapshot.state, uninterrupted)
        XCTAssertEqual(activeSnapshot.fingerprint, activeFingerprint)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(replay),
            activeFingerprint,
            "same seed and command sequence must produce one storm authority"
        )

        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play088-phase-b-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let saves = SaveGameService(rootURL: root)

        let activeWrite = try saves.save(uninterrupted)
        let primaryLoad = try saves.load()
        XCTAssertEqual(activeWrite.schemaVersion, 1)
        XCTAssertEqual(primaryLoad.source, .primary)
        XCTAssertEqual(primaryLoad.state, uninterrupted)
        XCTAssertEqual(primaryLoad.fingerprint, activeFingerprint)

        let stormMessage = try XCTUnwrap(
            primaryLoad.state.messages.first { $0.title == "Severe Storm" }
        )
        let messageStore = CityGameStore(state: primaryLoad.state, saveService: saves)
        messageStore.openMessage(stormMessage)
        XCTAssertEqual(messageStore.overlay, .utilities)
        XCTAssertEqual(messageStore.inspectorSection, .utilities)
        messageStore.dismissMessage(stormMessage.id)
        XCTAssertFalse(messageStore.state.messages.contains { $0.id == stormMessage.id })
        XCTAssertEqual(messageStore.state.stormRecovery, uninterrupted.stormRecovery)

        advanceDays(&uninterrupted, days: 6)
        advanceDays(&replay, days: 6)
        XCTAssertEqual(uninterrupted, replay)
        XCTAssertEqual(uninterrupted.stormRecovery?.disposition, .recovered)
        let recoveredFingerprint = try CityStateFingerprinter.fingerprint(uninterrupted)
        let recoveredSnapshot = try CityPresentationSnapshot(state: uninterrupted)
        XCTAssertEqual(recoveredSnapshot.state, uninterrupted)
        XCTAssertEqual(recoveredSnapshot.fingerprint, recoveredFingerprint)
        XCTAssertNotEqual(activeFingerprint, recoveredFingerprint)

        let recoveredWrite = try saves.save(uninterrupted)
        let recoveredLoad = try saves.load()
        XCTAssertEqual(recoveredLoad.source, .primary)
        XCTAssertEqual(recoveredLoad.state, uninterrupted)
        XCTAssertEqual(recoveredLoad.fingerprint, recoveredWrite.fingerprint)

        try Data("corrupt-primary".utf8).write(to: saves.saveURL, options: .atomic)
        let backupLoad = try saves.load()
        XCTAssertEqual(backupLoad.source, .backup)
        XCTAssertEqual(backupLoad.state, primaryLoad.state)
        XCTAssertEqual(backupLoad.fingerprint, activeFingerprint)
        XCTAssertEqual(try Data(contentsOf: saves.saveURL), Data("corrupt-primary".utf8))

        var retired = stormReadyState(seed: stormSeed)
        CitySimulation.step(&retired)
        retired.updateTile(at: expectedTargets[0]) {
            $0 = CityTile(coordinate: expectedTargets[0], kind: .empty)
        }
        retired.updateTile(at: expectedTargets[1]) {
            $0.kind = .commercial
            $0.condition = 0.40
        }
        advanceDays(&retired, days: 1)
        XCTAssertEqual(
            retired.stormRecovery?.targets.map(\.coordinate),
            [expectedTargets[2]]
        )
        XCTAssertEqual(try XCTUnwrap(retired.tile(at: expectedTargets[1])?.condition), 0.40, accuracy: 0.000_001)

        var undoState = stormReadyState(seed: stormSeed)
        CitySimulation.step(&undoState)
        undoState.treasury = 50_000
        let undoStore = CityGameStore(state: undoState)
        undoStore.selectTool(.park)
        let buildCoordinate = try XCTUnwrap(
            undoStore.state.tiles.first {
                guard $0.kind == .empty else { return false }
                if case .success = CitySimulation.validateBuild(
                    .park,
                    at: $0.coordinate,
                    in: undoStore.state
                ) {
                    return true
                }
                return false
            }?.coordinate
        )
        undoStore.primaryAction(at: buildCoordinate)
        XCTAssertTrue(undoStore.canUndo)
        undoStore.undoLastAction()
        XCTAssertEqual(undoStore.state, undoState)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(undoStore.state),
            try CityStateFingerprinter.fingerprint(undoState)
        )

        print(
            "PLAY088_PHASE_B_RESULT " +
                "active=\(activeFingerprint.digest) " +
                "recovered=\(recoveredFingerprint.digest) " +
                "targets=\(expectedTargets.map(\.id).joined(separator: ",")) " +
                "backup=\(backupLoad.source.rawValue)"
        )
    }

    private func stormReadyState(seed: UInt64) -> CityGameState {
        var state = CityGameState.newCity(seed: seed)
        state.tick = 639
        state.treasury = 4_000
        state.population = 500
        state.happiness = 70
        state.approval = 70
        install(.powerPlant, at: GridCoordinate(x: 5, y: 8), in: &state)
        install(.waterTower, at: GridCoordinate(x: 6, y: 8), in: &state)
        return state
    }

    private func install(
        _ kind: BuildingKind,
        at coordinate: GridCoordinate,
        in state: inout CityGameState
    ) {
        state.updateTile(at: coordinate) {
            $0.kind = kind
            $0.level = 1
            $0.occupancy = 0
            $0.condition = 1
            $0.constructionProgress = 1
        }
    }

    private func advanceDays(_ state: inout CityGameState, days: Int) {
        for _ in 0..<(days * 4) {
            CitySimulation.step(&state)
        }
    }
}
