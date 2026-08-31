import XCTest
@testable import CitySimNative

final class CityServiceCoverageOverlayTests: XCTestCase {
    @MainActor
    func testRendererAndSelectedReadingUseEachAuthoritativeServiceChannel() throws {
        let tile = CityTile(coordinate: GridCoordinate(x: 3, y: 9), kind: .residential)
        let service = CityLocationCivicService(fire: 0.15, police: 0.90, school: 0.45, combined: 0.50)
        let consequence = CitySpatialConsequence(
            coordinate: tile.coordinate,
            utility: .init(power: 1, water: 1, combined: 1, powerBand: .healthy, waterBand: .healthy, combinedBand: .healthy),
            pollutionExposure: 0,
            pollutionBand: .healthy,
            vitalityScore: 0,
            vitality: .notApplicable,
            civicService: service
        )
        let renderer = WorldOverlayRenderer(style: WorldVisualStyle())
        let expected: [(DataOverlay, Double, String)] = [
            (.services, 0.50, "civic"),
            (.fireCoverage, 0.15, "fire station"),
            (.policeCoverage, 0.90, "police station"),
            (.schoolCoverage, 0.45, "school")
        ]
        for (overlay, value, source) in expected {
            let sample = try XCTUnwrap(renderer.sample(
                for: tile, state: .newCity(seed: 42), consequence: consequence, overlay: overlay
            ))
            XCTAssertEqual(sample.value, value, accuracy: 0.000_001)
            XCTAssertEqual(sample.pattern, .civicServiceSignals)
            let reading = OverlayDiagnosticsPalettePresentation.make(
                overlay: overlay, consequence: consequence, tick: 72,
                selectionApplies: true, civicServiceFundingPolicy: .expanded
            )
            XCTAssertEqual(reading.value, "\(Int(value * 100)) / 100")
            XCTAssertTrue(reading.source.contains(source))
            XCTAssertTrue(reading.accessibilityValue.contains("16-block reach"))
            XCTAssertTrue(reading.accessibilityValue.contains("fresh at tick 72"))
            if overlay != .services {
                XCTAssertTrue(reading.visualKey.contains(overlay.title.lowercased()))
            }
            var unfinished = tile
            unfinished.constructionProgress = 0.5
            XCTAssertNil(renderer.sample(
                for: unfinished, state: .newCity(seed: 42), consequence: consequence, overlay: overlay
            ))
            XCTAssertNil(overlay.civicServiceValue(in: nil))
        }
    }

    @MainActor
    func testDifferentServiceHotspotsAndRoutingPreserveTheCity() throws {
        let state = serviceDistrict()
        let snapshot = try CityPresentationSnapshot(state: state)
        let store = CityGameStore(state: state)
        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        let expected: [(DataOverlay, GridCoordinate, String)] = [
            (.fireCoverage, GridCoordinate(x: 12, y: 9), "fire"),
            (.policeCoverage, GridCoordinate(x: 4, y: 9), "police"),
            (.schoolCoverage, GridCoordinate(x: 4, y: 9), "school")
        ]
        for (overlay, coordinate, label) in expected {
            let hotspot = try XCTUnwrap(OverlayDiagnosticHotspot.make(overlay: overlay, snapshot: snapshot))
            XCTAssertEqual(hotspot.coordinate, coordinate)
            XCTAssertTrue(hotspot.accessibilityLabel.contains("weakest \(label) coverage"))
            XCTAssertTrue(store.perform(CityCommandCatalog.id(for: overlay)))
            XCTAssertTrue(store.focusDiagnosticHotspot(hotspot.coordinate))
            XCTAssertEqual(store.selectedCoordinate, coordinate)
            XCTAssertEqual(store.interactionMode, .inspect)
            XCTAssertFalse(store.showInspector)
            XCTAssertEqual(store.state, state)
            XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
        }
        XCTAssertTrue(store.perform(.overlayServices))
        XCTAssertEqual(store.overlay, .services)
        XCTAssertEqual(store.state, state)
    }

    @MainActor
    func testSwitchingCoverageOnPausedCityRefreshesOverlayWithoutRebuildingWorld() throws {
        let state = serviceDistrict()
        let snapshot = try CityPresentationSnapshot(state: state)
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.render(snapshot: snapshot, overlay: .fireCoverage, selection: nil, interactionMode: .inspect)
        scene.render(snapshot: snapshot, overlay: .schoolCoverage, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(scene.diagnosticsSnapshot.createdTileCount, 0)
        XCTAssertGreaterThan(scene.diagnosticsSnapshot.overlayUpdateCount, 0)
        scene.render(snapshot: snapshot, overlay: .schoolCoverage, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(scene.diagnosticsSnapshot.overlayUpdateCount, 0)
    }

    func testExistingOverlayShortcutsRemainStableAndNewLensesAreDiscoverable() {
        let existing: [DataOverlay] = [.none, .landValue, .traffic, .utilities, .services, .happiness, .pollution, .roadCondition]
        for (number, overlay) in existing.enumerated() {
            let descriptor = CityCommandCatalog.descriptor(for: CityCommandCatalog.id(for: overlay))
            XCTAssertEqual(descriptor.shortcut?.key, String(number))
            XCTAssertEqual(descriptor.shortcut?.modifiers, [.control])
        }
        for overlay in [DataOverlay.fireCoverage, .policeCoverage, .schoolCoverage] {
            let descriptor = CityCommandCatalog.descriptor(for: CityCommandCatalog.id(for: overlay))
            XCTAssertEqual(CityCommandCatalog.overlay(for: descriptor.id), overlay)
            XCTAssertTrue(descriptor.title.contains(overlay.title))
            XCTAssertNil(descriptor.shortcut, "Do not invent multi-character or conflicting numeric shortcuts")
        }
    }

    private func serviceDistrict() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for tile in state.tiles {
            state.updateTile(at: tile.coordinate) { $0 = CityTile(coordinate: tile.coordinate, kind: .empty) }
        }
        for x in 4...12 {
            let coordinate = GridCoordinate(x: x, y: 10)
            state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: .road) }
        }
        let sites: [(BuildingKind, Int, Int)] = [
            (.residential, 4, 9), (.commercial, 12, 9),
            (.fireStation, 4, 11), (.policeStation, 8, 11), (.school, 12, 11)
        ]
        for (kind, x, y) in sites {
            let coordinate = GridCoordinate(x: x, y: y)
            state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: kind) }
        }
        return state
    }
}
