import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class OverlayDiagnosticsPaletteTests: XCTestCase {
    func testEveryDiagnosticLayerFindsItsDeterministicCitywideExtreme() throws {
        let state = CityGameState.newCity(seed: 42)
        let snapshot = try CityPresentationSnapshot(state: state)

        for overlay in DataOverlay.allCases.dropFirst() {
            let hotspot = try XCTUnwrap(OverlayDiagnosticHotspot.make(
                overlay: overlay,
                snapshot: snapshot
            ))
            let tile = try XCTUnwrap(state.tile(at: hotspot.coordinate))
            XCTAssertTrue(overlay.applies(to: tile), "\(overlay.title) must focus a rendered diagnostic tile")

            let eligibleValues = snapshot.spatialConsequences.samples.compactMap { consequence -> Double? in
                guard let tile = state.tile(at: consequence.coordinate), overlay.applies(to: tile) else {
                    return nil
                }
                switch overlay {
                case .none:
                    return nil
                case .landValue:
                    return consequence.landValueIndex
                case .traffic:
                    return consequence.trafficPressure
                case .utilities:
                    return consequence.utility.combined
                case .services, .fireCoverage, .policeCoverage, .schoolCoverage:
                    return overlay.civicServiceValue(in: consequence.civicService)
                case .happiness:
                    return consequence.localHappinessIndex
                case .pollution:
                    return consequence.pollutionExposure
                case .roadCondition:
                    return CityRoadMaintenance.clamp(tile.condition)
                }
            }
            let expected: Double?
            switch overlay {
            case .traffic, .pollution:
                expected = eligibleValues.max()
            case .landValue, .utilities, .services, .fireCoverage, .policeCoverage, .schoolCoverage, .happiness, .roadCondition:
                expected = eligibleValues.min()
            case .none:
                expected = nil
            }
            XCTAssertEqual(hotspot.value, try XCTUnwrap(expected), accuracy: 0.000_001)
            XCTAssertEqual(
                hotspot,
                OverlayDiagnosticHotspot.make(overlay: overlay, snapshot: snapshot),
                "Tie-breaking must remain deterministic"
            )
        }

        XCTAssertNil(OverlayDiagnosticHotspot.make(overlay: .none, snapshot: snapshot))
    }

    @MainActor
    func testHotspotFocusesInspectSelectionWithoutOpeningDetailsOrChangingCityState() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        XCTAssertTrue(store.perform(CityCommandCatalog.id(for: .traffic)))
        let snapshot = try CityPresentationSnapshot(state: store.state)
        let hotspot = try XCTUnwrap(OverlayDiagnosticHotspot.make(
            overlay: .traffic,
            snapshot: snapshot
        ))
        let stateBefore = store.state
        let focusBefore = store.mapFocusRequestGeneration
        let feedbackBefore = store.lastFeedback

        XCTAssertTrue(store.focusDiagnosticHotspot(hotspot.coordinate))

        XCTAssertEqual(store.selectedCoordinate, hotspot.coordinate)
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertEqual(store.hudContextScope, .selection)
        XCTAssertFalse(store.showInspector)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusBefore + 1)
        XCTAssertEqual(store.lastFeedback, feedbackBefore)
        XCTAssertEqual(store.state, stateBefore)

        let selectedConsequence = try XCTUnwrap(snapshot.spatialConsequences[hotspot.coordinate])
        let selectedPresentation = OverlayDiagnosticsPalettePresentation.make(
            overlay: .traffic,
            consequence: selectedConsequence,
            tick: stateBefore.tick,
            selectionApplies: true
        )
        XCTAssertEqual(
            selectedPresentation.value,
            "\(Int((hotspot.value * 100).rounded())) / 100"
        )
    }

    func testUnselectedDiagnosticPresentationOffersTheActionableHotspot() throws {
        let snapshot = try CityPresentationSnapshot(state: .newCity(seed: 42))
        let hotspot = try XCTUnwrap(OverlayDiagnosticHotspot.make(
            overlay: .traffic,
            snapshot: snapshot
        ))
        let traffic = OverlayDiagnosticsPalettePresentation.make(
            overlay: .traffic,
            consequence: nil,
            tick: snapshot.state.tick,
            hotspot: hotspot
        )

        XCTAssertEqual(traffic.value, hotspot.conciseReading)
        XCTAssertTrue(traffic.value.hasPrefix("Peak "))
        XCTAssertTrue(traffic.value.contains(" · B"))
        XCTAssertTrue(traffic.accessibilityValue.contains("Activate the citywide hotspot"))
        XCTAssertTrue(hotspot.accessibilityLabel.contains("highest traffic delay road"))
    }

    func testRoadConditionHotspotUsesSavedWorstRoadAndSelectedReading() throws {
        var state = CityGameState.newCity(seed: 42)
        let roadIndices = state.tiles.indices.filter { state.tiles[$0].kind == .road }
        XCTAssertGreaterThanOrEqual(roadIndices.count, 2)
        state.tiles[roadIndices[0]].condition = 0.77
        state.tiles[roadIndices[1]].condition = 0.41

        let snapshot = try CityPresentationSnapshot(state: state)
        let hotspot = try XCTUnwrap(OverlayDiagnosticHotspot.make(
            overlay: .roadCondition,
            snapshot: snapshot
        ))
        XCTAssertEqual(hotspot.coordinate, state.tiles[roadIndices[1]].coordinate)
        XCTAssertEqual(hotspot.value, 0.41, accuracy: 0.000_001)
        XCTAssertEqual(hotspot.conciseReading, "Lowest 41 · B\(hotspot.coordinate.x + 1),\(hotspot.coordinate.y + 1)")
        XCTAssertTrue(hotspot.accessibilityLabel.contains("lowest road condition"))

        let presentation = OverlayDiagnosticsPalettePresentation.make(
            overlay: .roadCondition,
            consequence: snapshot.spatialConsequences[hotspot.coordinate],
            tick: state.tick,
            selectionApplies: true,
            selectedRoadCondition: state.tiles[roadIndices[1]].condition
        )
        XCTAssertEqual(presentation.value, "41 / 100")
        XCTAssertEqual(presentation.source, "Saved road condition")
    }

    @MainActor
    func testPaletteRoutesEveryLayerAndPublishesHonestNormalizedMetadata() {
        let store = CityGameStore(state: .newCity(seed: 42))

        for overlay in DataOverlay.allCases {
            XCTAssertTrue(store.perform(CityCommandCatalog.id(for: overlay)))
            XCTAssertEqual(store.overlay, overlay)
        }

        let traffic = OverlayDiagnosticsPalettePresentation.make(
            overlay: .traffic,
            consequence: nil,
            tick: 12
        )
        XCTAssertEqual(traffic.title, "Traffic pressure")
        XCTAssertEqual(traffic.value, "Select a place")
        XCTAssertEqual(traffic.scale, "0–100")
        XCTAssertEqual(traffic.applicability, "Roads only")
        XCTAssertEqual(traffic.visualKey, "More road ticks signal higher modeled delay")
        XCTAssertEqual(traffic.source, "Home-to-work route assignment")
        XCTAssertEqual(traffic.freshness, "fresh at tick 12")
        XCTAssertTrue(traffic.accessibilityValue.contains("Scale 0–100"))
        XCTAssertTrue(traffic.accessibilityValue.contains("More road ticks"))
        XCTAssertTrue(traffic.accessibilityValue.contains("Click a place to open details"))
    }

    func testEveryDiagnosticLayerSharesRendererApplicabilityAndExplainsItsMarks() {
        let open = CityTile(coordinate: GridCoordinate(x: 0, y: 0), kind: .empty)
        let road = CityTile(coordinate: GridCoordinate(x: 1, y: 0), kind: .road)
        let building = CityTile(coordinate: GridCoordinate(x: 2, y: 0), kind: .commercial)
        let construction = CityTile(
            coordinate: GridCoordinate(x: 3, y: 0),
            kind: .residential,
            constructionProgress: 0.5
        )

        XCTAssertTrue(DataOverlay.none.applies(to: open))
        XCTAssertTrue(DataOverlay.traffic.applies(to: road))
        XCTAssertFalse(DataOverlay.traffic.applies(to: building))
        XCTAssertTrue(DataOverlay.roadCondition.applies(to: road))
        XCTAssertFalse(DataOverlay.roadCondition.applies(to: building))
        XCTAssertTrue(DataOverlay.utilities.applies(to: building))
        XCTAssertTrue(DataOverlay.services.applies(to: building))
        XCTAssertFalse(DataOverlay.services.applies(to: construction))
        XCTAssertTrue(DataOverlay.pollution.applies(to: construction))
        XCTAssertFalse(DataOverlay.landValue.applies(to: construction))
        XCTAssertTrue(DataOverlay.landValue.applies(to: building))
        XCTAssertTrue(DataOverlay.happiness.applies(to: building))
        XCTAssertFalse(DataOverlay.utilities.applies(to: open))

        let roadCondition = OverlayDiagnosticsPalettePresentation.make(
            overlay: .roadCondition,
            consequence: nil,
            tick: 12,
            selectionApplies: true,
            selectedRoadCondition: 0.42
        )
        XCTAssertEqual(roadCondition.title, "Road Condition")
        XCTAssertEqual(roadCondition.value, "42 / 100")
        XCTAssertEqual(roadCondition.applicability, "Roads only")
        XCTAssertEqual(roadCondition.source, "Saved road condition")
        XCTAssertEqual(roadCondition.visualKey, "More shoulder bars signal worse road condition")

        let keys = DataOverlay.allCases.dropFirst().map {
            OverlayDiagnosticsPalettePresentation.make(
                overlay: $0,
                consequence: nil,
                tick: 12
            ).visualKey
        }
        XCTAssertEqual(Set(keys).count, DataOverlay.allCases.count - 1)
        XCTAssertTrue(keys.allSatisfy { $0.hasPrefix("More ") })
    }

    @MainActor
    func testComposedLegendYieldsToHigherPriorityBottomSurfaces() {
        XCTAssertFalse(ContentView.presentsOverlayDiagnostics(
            overlay: .none,
            showInspector: false,
            hasBuildDecision: false,
            hasPresentedFeedback: false
        ))
        XCTAssertTrue(ContentView.presentsOverlayDiagnostics(
            overlay: .utilities,
            showInspector: false,
            hasBuildDecision: false,
            hasPresentedFeedback: false
        ))
        XCTAssertFalse(ContentView.presentsOverlayDiagnostics(
            overlay: .utilities,
            showInspector: true,
            hasBuildDecision: false,
            hasPresentedFeedback: false
        ))
        XCTAssertFalse(ContentView.presentsOverlayDiagnostics(
            overlay: .utilities,
            showInspector: false,
            hasBuildDecision: true,
            hasPresentedFeedback: false
        ))
        XCTAssertFalse(ContentView.presentsOverlayDiagnostics(
            overlay: .utilities,
            showInspector: false,
            hasBuildDecision: false,
            hasPresentedFeedback: true
        ))
    }

    @MainActor
    func testPaletteRendersWithinRegularAndExactCompactBounds() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        store.setCivicServiceFundingPolicy(.expanded)
        XCTAssertTrue(store.perform(CityCommandCatalog.id(for: DataOverlay.services)))
        XCTAssertEqual(store.overlay, .services)
        let compactSize = CGSize(width: 884, height: OverlayDiagnosticsPaletteView.compactMaximumHeight)
        let regularSize = CGSize(width: 1_120, height: OverlayDiagnosticsPaletteView.regularMaximumHeight)

        let compact = try bitmap(
            of: OverlayDiagnosticsPaletteView(store: store, compact: true)
                .frame(width: compactSize.width, height: compactSize.height),
            size: compactSize
        )
        let regular = try bitmap(
            of: OverlayDiagnosticsPaletteView(store: store, compact: false)
                .frame(width: regularSize.width, height: regularSize.height),
            size: regularSize
        )

        XCTAssertEqual(compact.size.width, compactSize.width, accuracy: 0.5)
        XCTAssertEqual(compact.size.height, compactSize.height, accuracy: 0.5)
        XCTAssertEqual(regular.size.width, regularSize.width, accuracy: 0.5)
        XCTAssertEqual(regular.size.height, regularSize.height, accuracy: 0.5)
        XCTAssertLessThanOrEqual(OverlayDiagnosticsPaletteView.compactMaximumHeight, 70)

        if let path = ProcessInfo.processInfo.environment["CITYSIM_PLAY087_COMPACT_PROOF"] {
            let data = try XCTUnwrap(compact.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        if let path = ProcessInfo.processInfo.environment["CITYSIM_PLAY087_REGULAR_PROOF"] {
            let data = try XCTUnwrap(regular.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @MainActor
    private func bitmap<Content: View>(of content: Content, size: CGSize) throws -> NSBitmapImageRep {
        let view = NSHostingView(rootView: content)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: representation)
        return representation
    }
}
