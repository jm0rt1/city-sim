import XCTest
@testable import CitySimNative

final class CityUtilityOverlayTests: XCTestCase {
    @MainActor
    func testMapAndLocalReadingSeparatePowerFromWaterWithoutChangingCombinedCoverage() throws {
        let state = district()
        let tile = try XCTUnwrap(state.tile(at: .init(x: 3, y: 9)))
        let consequence = try XCTUnwrap(CitySpatialConsequenceMap(state: state)[tile.coordinate])
        let renderer = WorldOverlayRenderer(style: WorldVisualStyle())
        let expected: [(DataOverlay, Double, String)] = [
            (.power, 11.0 / 12, "power plants"), (.water, 0, "water towers"), (.utilities, 0, "Spatial consequences")
        ]
        for (overlay, value, source) in expected {
            let sample = try XCTUnwrap(renderer.sample(for: tile, state: state, consequence: consequence, overlay: overlay))
            XCTAssertEqual(sample.value, value, accuracy: 0.000_001)
            XCTAssertEqual(sample.pattern, .utilityEdge)
            let reading = OverlayDiagnosticsPalettePresentation.make(
                overlay: overlay, consequence: consequence, tick: 48, selectionApplies: true
            )
            XCTAssertEqual(reading.value, "\(Int((value * 100).rounded())) / 100")
            XCTAssertTrue(reading.source.contains(source))
            XCTAssertTrue(reading.accessibilityValue.contains("fresh at tick 48"))
            if overlay != .utilities {
                XCTAssertTrue(reading.visualKey.contains("less \(overlay.title.lowercased()) service"))
                XCTAssertTrue(reading.source.contains("distance and citywide capacity"))
            }
            XCTAssertNil(overlay.utilityValue(in: nil))
            for kind in [BuildingKind.empty, .road] {
                var excluded = tile
                excluded.kind = kind
                XCTAssertNil(renderer.sample(for: excluded, state: state, consequence: consequence, overlay: overlay))
            }
            let missing = OverlayDiagnosticsPalettePresentation.make(
                overlay: overlay, consequence: nil, tick: 48, selectionApplies: true
            )
            XCTAssertEqual(missing.value, "No data")
        }
        var limited = state
        limited.powerCapacity = 20
        limited.powerUsed = 100
        let limitedConsequence = try XCTUnwrap(CitySpatialConsequenceMap(state: limited)[tile.coordinate])
        XCTAssertEqual(try XCTUnwrap(renderer.sample(for: tile, state: limited, consequence: limitedConsequence, overlay: .power)).value, 0.2, accuracy: 0.000_001)
    }

    @MainActor
    func testEachNetworkFindsItsOwnWeakestPlaceAndMapRoutingPreservesCityAndSelection() throws {
        let state = district()
        let snapshot = try CityPresentationSnapshot(state: state)
        let store = CityGameStore(state: state)
        let fingerprint = try CityStateFingerprinter.fingerprint(state)
        let expected: [(DataOverlay, GridCoordinate)] = [
            (.power, .init(x: 15, y: 9)), (.water, .init(x: 2, y: 9))
        ]
        for (overlay, coordinate) in expected {
            let hotspot = try XCTUnwrap(OverlayDiagnosticHotspot.make(overlay: overlay, snapshot: snapshot))
            XCTAssertEqual(hotspot.coordinate, coordinate)
            XCTAssertTrue(hotspot.accessibilityLabel.contains("weakest \(overlay.title.lowercased()) service"))
            let focus = store.mapFocusRequestGeneration
            XCTAssertTrue(store.performMapFocused(CityCommandCatalog.id(for: overlay)))
            XCTAssertEqual(store.mapFocusRequestGeneration, focus + 1)
            XCTAssertTrue(store.focusDiagnosticHotspot(hotspot.coordinate))
            XCTAssertEqual(store.selectedCoordinate, coordinate)
            XCTAssertEqual(store.interactionMode, .inspect)
            XCTAssertEqual(store.overlay, overlay)
            XCTAssertEqual(store.state, state)
            XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state), fingerprint)
        }
        let selected = store.selectedCoordinate
        XCTAssertTrue(store.perform(.overlayUtilities))
        XCTAssertEqual(store.overlay, .utilities)
        XCTAssertEqual(store.selectedCoordinate, selected)
        XCTAssertEqual(store.state, state)
    }

    @MainActor
    func testPausedNetworkSwitchOnlyRefreshesDiagnosticMarks() throws {
        let snapshot = try CityPresentationSnapshot(state: district())
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.render(snapshot: snapshot, overlay: .power, selection: nil, interactionMode: .inspect)
        scene.render(snapshot: snapshot, overlay: .water, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(scene.diagnosticsSnapshot.createdTileCount, 0)
        XCTAssertGreaterThan(scene.diagnosticsSnapshot.overlayUpdateCount, 0)
        scene.render(snapshot: snapshot, overlay: .water, selection: nil, interactionMode: .inspect)
        XCTAssertEqual(scene.diagnosticsSnapshot.overlayUpdateCount, 0)
    }

    func testNetworkCommandsAreDiscoverableWithoutChangingExistingShortcuts() {
        for overlay in [DataOverlay.power, .water] {
            let id = CityCommandCatalog.id(for: overlay)
            let descriptor = CityCommandCatalog.descriptor(for: id)
            XCTAssertEqual(CityCommandCatalog.overlay(for: id), overlay)
            XCTAssertTrue(CityCommandCatalog.matchingDescriptors(query: overlay.title).contains { $0.id == id })
            XCTAssertNil(descriptor.shortcut)
        }
        let existing: [DataOverlay] = [.none, .landValue, .traffic, .utilities, .services, .happiness, .pollution, .roadCondition]
        for (number, overlay) in existing.enumerated() {
            let descriptor = CityCommandCatalog.descriptor(for: CityCommandCatalog.id(for: overlay))
            XCTAssertEqual(descriptor.shortcut?.key, String(number))
            XCTAssertEqual(descriptor.shortcut?.modifiers, [.control])
        }
    }

    private func district() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for index in state.tiles.indices {
            state.tiles[index] = CityTile(coordinate: state.tiles[index].coordinate, kind: .empty)
        }
        for (kind, x) in [(BuildingKind.powerPlant, 2), (.residential, 3), (.commercial, 15), (.waterTower, 16)] {
            let coordinate = GridCoordinate(x: x, y: 9)
            state.updateTile(at: coordinate) { $0 = CityTile(coordinate: coordinate, kind: kind) }
        }
        state.powerCapacity = 200
        state.waterCapacity = 200
        state.powerUsed = 100
        state.waterUsed = 100
        return state
    }
}
