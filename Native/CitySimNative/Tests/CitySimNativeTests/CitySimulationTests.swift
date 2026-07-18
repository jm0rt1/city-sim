import XCTest
import AppKit
import SpriteKit
@testable import CitySimNative

final class CitySimulationTests: XCTestCase {
    func testNewCityHasPlayableFoundation() {
        let state = CityGameState.newCity(seed: 42)
        XCTAssertEqual(state.tiles.count, state.gridWidth * state.gridHeight)
        XCTAssertTrue(state.tiles.contains { $0.kind == .cityHall })
        XCTAssertTrue(state.tiles.contains { $0.kind == .road })
        XCTAssertGreaterThan(state.treasury, 0)
    }

    func testSimulationIsDeterministic() {
        var lhs = CityGameState.newCity(seed: 1337)
        var rhs = CityGameState.newCity(seed: 1337)
        for _ in 0..<100 {
            CitySimulation.step(&lhs)
            CitySimulation.step(&rhs)
        }
        XCTAssertEqual(lhs, rhs)
    }

    func testRoadAccessIsRequiredForZoning() {
        let state = CityGameState.newCity()
        let remote = GridCoordinate(x: 0, y: 0)
        guard case .failure(let rejection) = CitySimulation.validateBuild(.residential, at: remote, in: state) else {
            return XCTFail("Expected road access rejection")
        }
        XCTAssertEqual(rejection, .roadAccessRequired)
    }

    func testBuildingChargesTreasuryAndStartsConstruction() {
        var state = CityGameState.newCity()
        let coordinate = GridCoordinate(x: 8, y: 11)
        let startingTreasury = state.treasury
        guard case .success = CitySimulation.build(.residential, at: coordinate, in: &state) else {
            return XCTFail("Expected construction to succeed")
        }
        XCTAssertEqual(state.treasury, startingTreasury - BuildingKind.residential.buildCost)
        XCTAssertEqual(state.tile(at: coordinate)?.kind, .residential)
        XCTAssertEqual(state.tile(at: coordinate)?.constructionProgress, 0)
    }

    func testConstructionCompletesAndPopulationResponds() {
        var state = CityGameState.newCity()
        let coordinate = GridCoordinate(x: 8, y: 11)
        _ = CitySimulation.build(.residential, at: coordinate, in: &state)
        for _ in 0..<8 { CitySimulation.step(&state) }
        XCTAssertEqual(state.tile(at: coordinate)?.constructionProgress, 1)
        XCTAssertGreaterThanOrEqual(state.population, 180)
    }

    func testStateRoundTripsThroughJSON() throws {
        var state = CityGameState.newCity(seed: 99)
        for _ in 0..<12 { CitySimulation.step(&state) }
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(CityGameState.self, from: data)
        XCTAssertEqual(decoded, state)
    }

    func testDemolitionProtectsCityHall() {
        var state = CityGameState.newCity()
        XCTAssertFalse(CitySimulation.demolish(at: GridCoordinate(x: 11, y: 11), in: &state))
        XCTAssertEqual(state.tile(at: GridCoordinate(x: 11, y: 11))?.kind, .cityHall)
    }

    func testCityUsesDayOnlyPresentation() {
        var state = CityGameState.newCity()
        XCTAssertEqual(state.formattedDay, "Day 1")
        for _ in 0..<4 { CitySimulation.step(&state) }
        XCTAssertEqual(state.formattedDay, "Day 2")
    }

    @MainActor
    func testBulldozerModeActsOnMapAndSupportsUndo() {
        let coordinate = GridCoordinate(x: 10, y: 11)
        let store = CityGameStore(state: .newCity())
        XCTAssertEqual(store.state.tile(at: coordinate)?.kind, .residential)

        store.toggleBulldozer()
        store.primaryAction(at: coordinate)

        XCTAssertEqual(store.state.tile(at: coordinate)?.kind, .empty)
        XCTAssertTrue(store.canUndo)
        store.undoLastAction()
        XCTAssertEqual(store.state.tile(at: coordinate)?.kind, .residential)
    }

    @MainActor
    func testHUDRoutesMessagesAndSupportsDismissal() throws {
        let storm = CityMessage(
            tick: 8,
            severity: .warning,
            title: "Severe Storm",
            detail: "Utility crews are responding."
        )
        var state = CityGameState.newCity()
        state.messages = [storm]
        let store = CityGameStore(state: state)

        store.openMessage(storm)
        XCTAssertEqual(store.overlay, .utilities)
        XCTAssertEqual(store.inspectorSection, .utilities)
        XCTAssertTrue(store.showInspector)

        store.dismissMessage(storm.id)
        XCTAssertTrue(store.state.messages.isEmpty)

        let populationObjective = try XCTUnwrap(store.objectives.first { $0.id == "population" })
        store.openObjective(populationObjective)
        XCTAssertEqual(store.inspectorSection, .population)
    }

    func testAnalyticsMatchSimulationEconomyContract() {
        let state = CityGameState.newCity()
        let analytics = CityAnalytics(state: state)
        XCTAssertGreaterThan(analytics.housingCapacity, 0)
        XCTAssertGreaterThan(analytics.jobCapacity, 0)
        XCTAssertEqual(analytics.projectedBalance, analytics.projectedRevenue - analytics.projectedUpkeep, accuracy: 0.001)
    }

    @MainActor
    func testRendererProducesInspectableFrame() throws {
        let size = CGSize(width: 1_280, height: 800)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = CityScene(size: size)
        view.presentScene(scene)
        scene.render(
            state: .newCity(seed: 42),
            overlay: .none,
            selection: GridCoordinate(x: 11, y: 11),
            selectedTool: .residential,
            bulldozeMode: false
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        let texture = try XCTUnwrap(view.texture(from: scene))
        let image = texture.cgImage()
        XCTAssertGreaterThan(image.width, 1_000)
        XCTAssertGreaterThan(image.height, 600)

        if let path = ProcessInfo.processInfo.environment["CITYSIM_RENDER_PROOF"] {
            let representation = NSBitmapImageRep(cgImage: image)
            let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
}
