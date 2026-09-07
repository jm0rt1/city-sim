import XCTest
@testable import CitySimNative

final class CityDiagnosisPriorityTests: XCTestCase {
    private let target = GridCoordinate(x: 3, y: 9)

    func testOperatingPlantMovesSeverePollutionAheadOfStrainedPowerWithoutDroppingRemedies() throws {
        let state = postInvestmentCity()
        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        let snapshot = try CityPresentationSnapshot(state: state)
        let sample = try XCTUnwrap(snapshot.spatialConsequences[target])
        XCTAssertEqual(sample.utility.powerBand, .strained)
        XCTAssertEqual(sample.utility.power, 10.0 / 12, accuracy: 0.000_001)
        XCTAssertEqual(sample.pollutionBand, .severe)
        XCTAssertEqual(sample.pollutionExposure, 0.615, accuracy: 0.000_001)
        let diagnosis = try diagnose(state)
        XCTAssertTrue(diagnosis.cause.hasPrefix("Pollution exposure is severe at 62%"))
        XCTAssertEqual(diagnosis.responses.first?.command, .buildPark)
        XCTAssertEqual(diagnosis.responses.map(\.command), [
            .buildPark, .buildPowerPlant, .buildFireStation, .overlayServices,
            .overlayUtilities, .overlayPollution
        ])
        XCTAssertEqual(diagnosis.responses.first?.explanation,
            "Place a park nearby to mitigate exposure; it does not promise a specific vitality score.")
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(state), fingerprint)
    }

    func testSevereWaterBeatsStrainedPowerAndKeepsWaterBeforeEquallySeverePollution() throws {
        var state = postInvestmentCity()
        state.waterCapacity = 100
        state.waterUsed = 400
        let diagnosis = try diagnose(state)
        XCTAssertTrue(diagnosis.cause.hasPrefix("Water service is severe"))
        XCTAssertEqual(Array(diagnosis.responses.prefix(3)).map(\.command),
            [.buildWaterTower, .buildPark, .buildPowerPlant])
    }

    func testGenuineUtilityShortfallsKeepStablePriorityOverEquallySeverePollution() throws {
        var state = postInvestmentCity()
        state.powerCapacity = 100
        state.powerUsed = 400
        state.waterCapacity = 100
        state.waterUsed = 400
        let diagnosis = try diagnose(state)
        XCTAssertTrue(diagnosis.cause.hasPrefix("Power service is severe"))
        XCTAssertEqual(Array(diagnosis.responses.prefix(3)).map(\.command),
            [.buildPowerPlant, .buildWaterTower, .buildPark])
    }

    func testPriorityReevaluatesAfterMitigationAndSurvivesStateRoundTrip() throws {
        let before = postInvestmentCity()
        XCTAssertEqual(try diagnose(before).responses.first?.command, .buildPark)
        var buffered = before
        buffered.updateTile(at: .init(x: 3, y: 8)) { $0.kind = .park }
        let snapshot = try CityPresentationSnapshot(state: buffered)
        let sample = try XCTUnwrap(snapshot.spatialConsequences[target])
        XCTAssertEqual(sample.utility.powerBand, .strained)
        XCTAssertEqual(sample.pollutionBand, .strained)
        let diagnosis = try diagnose(buffered)
        XCTAssertTrue(diagnosis.cause.hasPrefix("Power service is strained"))
        XCTAssertEqual(Array(diagnosis.responses.prefix(2)).map(\.command), [.buildPowerPlant, .buildPark])
        let restored = try JSONDecoder().decode(CityGameState.self, from: JSONEncoder().encode(buffered))
        XCTAssertEqual(try diagnose(restored), diagnosis)
        XCTAssertEqual(try diagnose(before).responses.first?.command, .buildPark,
            "Revisiting the prior state must not retain a stale diagnosis priority")
    }

    func testHealthyUtilitiesDoNotGainUnnecessaryConstructionActions() throws {
        var state = postInvestmentCity()
        state.updateTile(at: .init(x: 4, y: 8)) { $0.kind = .empty }
        state.updateTile(at: .init(x: 3, y: 8)) { $0.kind = .powerPlant }
        let diagnosis = try diagnose(state)
        XCTAssertEqual(diagnosis.responses.first?.command, .buildPark)
        XCTAssertFalse(diagnosis.responses.contains { [.buildPowerPlant, .buildWaterTower].contains($0.command) })
        XCTAssertEqual(Set(diagnosis.responses.map(\.command)).count, diagnosis.responses.count)
    }

    private func postInvestmentCity() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.updateTile(at: target) { $0.kind = .waterTower }
        state.updateTile(at: .init(x: 4, y: 8)) { $0.kind = .powerPlant }
        state.powerCapacity = 600
        state.waterCapacity = 540
        return state
    }

    private func diagnose(_ state: CityGameState) throws -> CitySelectedLocationDiagnosis {
        try XCTUnwrap(CitySelectedLocationDiagnosis.make(
            tile: XCTUnwrap(state.tile(at: target)), snapshot: CityPresentationSnapshot(state: state)))
    }
}
