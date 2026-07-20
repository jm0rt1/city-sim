import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityCommandCatalogTests: XCTestCase {
    func testCatalogDeclaresEveryCommandExactlyOnceAndCoversNonSpatialInventory() {
        let descriptors = CityCommandCatalog.descriptors
        let descriptorIDs = descriptors.map(\.id)
        let spatialIDs: Set<CityCommandID> = [.cameraZoomIn, .cameraZoomOut, .cameraFrameCity]
        let expectedNonSpatial = Set(CityCommandID.allCases).subtracting(spatialIDs)
        let actualNonSpatial = Set(descriptors.filter { !$0.isSpatial }.map(\.id))

        XCTAssertEqual(descriptors.count, CityCommandID.allCases.count)
        XCTAssertEqual(Set(descriptorIDs), Set(CityCommandID.allCases))
        XCTAssertEqual(actualNonSpatial, expectedNonSpatial)
        for id in CityCommandID.allCases {
            XCTAssertEqual(descriptorIDs.filter { $0 == id }.count, 1, "\(id.rawValue) must appear exactly once")
            let descriptor = CityCommandCatalog.descriptor(for: id)
            XCTAssertFalse(descriptor.title.isEmpty)
            XCTAssertFalse(descriptor.discoverability.isEmpty)
        }

        XCTAssertEqual(Set(BuildingKind.buildPalette.map(CityCommandCatalog.id(for:))), Set([
            .buildRoad, .buildResidential, .buildCommercial, .buildIndustrial, .buildPark,
            .buildPowerPlant, .buildWaterTower, .buildFireStation, .buildPoliceStation,
            .buildSchool, .buildCityHall
        ]))
        XCTAssertEqual(Set(DataOverlay.allCases.map(CityCommandCatalog.id(for:))), Set([
            .overlayCity, .overlayLandValue, .overlayTraffic, .overlayUtilities,
            .overlayHappiness, .overlayPollution
        ]))
    }

    func testCatalogHasNoShortcutCollisionWithinAFocusScope() {
        var owners: [String: CityCommandID] = [:]

        for descriptor in CityCommandCatalog.descriptors {
            guard let shortcut = descriptor.shortcut else { continue }
            let signature = "\(shortcut.focusScope.rawValue)|\(shortcut.modifiers.rawValue)|\(shortcut.key.lowercased())"
            XCTAssertNil(
                owners.updateValue(descriptor.id, forKey: signature),
                "\(descriptor.id.rawValue) collides with another command at \(signature)"
            )
        }
    }

    func testFocusMetadataKeepsUnmodifiedGameplayKeysOutOfGlobalMenus() {
        let gameplayIDs: Set<CityCommandID> = [
            .togglePause, .speedNormal, .speedFast, .speedFastest,
            .inspectMode, .buildMode, .bulldozeMode, .cancelInteraction
        ]

        for id in gameplayIDs {
            let shortcut = CityCommandCatalog.descriptor(for: id).shortcut
            XCTAssertEqual(shortcut?.focusScope, .gameplay)
            XCTAssertFalse(shortcut?.modifiers.contains(.command) ?? true)
            XCTAssertFalse(shortcut?.modifiers.contains(.control) ?? true)
            XCTAssertFalse(shortcut?.modifiers.contains(.option) ?? true)
        }

        for descriptor in CityCommandCatalog.descriptors where descriptor.shortcut?.focusScope == .global {
            XCTAssertNotEqual(descriptor.shortcut?.modifiers, [], "Global commands must not claim bare text-entry keys")
        }
    }

    @MainActor
    func testDisabledCommandsExplainWhyAndCannotExecute() {
        let store = CityGameStore(state: .newCity(seed: 42))

        XCTAssertFalse(store.canPerform(.undo))
        XCTAssertEqual(store.disabledReason(for: .undo), "There is no reversible construction action")
        XCTAssertFalse(store.perform(.undo))
        XCTAssertNil(store.lastFeedback, "Rejected catalog commands must not invoke the underlying intent")

        XCTAssertFalse(store.canPerform(.dismissFeedback))
        XCTAssertEqual(store.disabledReason(for: .dismissFeedback), "There is no transient action message")
        XCTAssertFalse(store.perform(.dismissFeedback))

        XCTAssertFalse(store.canPerform(.cameraZoomIn))
        XCTAssertEqual(store.disabledReason(for: .cameraZoomIn), "Available when the city map has focus")
    }

    @MainActor
    func testCatalogRouteMatchesExistingStoreIntentEndState() {
        let direct = CityGameStore(state: .newCity(seed: 42))
        let catalog = CityGameStore(state: .newCity(seed: 42))

        direct.selectTool(.commercial)
        catalog.perform(.buildCommercial)
        XCTAssertEqual(catalog.selectedTool, direct.selectedTool)
        XCTAssertEqual(catalog.selectedBuildCategory, direct.selectedBuildCategory)
        XCTAssertEqual(catalog.interactionMode, direct.interactionMode)

        direct.overlay = .pollution
        catalog.perform(.overlayPollution)
        XCTAssertEqual(catalog.overlay, direct.overlay)

        direct.openInspector(.employment)
        catalog.perform(.inspectorEmployment)
        XCTAssertEqual(catalog.inspectorSection, direct.inspectorSection)
        XCTAssertEqual(catalog.hudContextScope, direct.hudContextScope)
        XCTAssertEqual(catalog.showInspector, direct.showInspector)

        direct.setSpeed(.fastest)
        catalog.perform(.speedFastest)
        XCTAssertEqual(catalog.speed, direct.speed)
    }

    @MainActor
    func testPauseRestoresLastActiveSpeedAndEscapeClosesTopmostSurfaceFirst() {
        let store = CityGameStore(state: .newCity(seed: 42))
        store.perform(.speedFastest)
        store.perform(.togglePause)
        XCTAssertEqual(store.speed, .paused)
        store.perform(.togglePause)
        XCTAssertEqual(store.speed, .fastest)

        store.perform(.buildResidential)
        store.perform(.toggleObjectives)
        store.perform(.inspectorUtilities)
        store.perform(.openCommandGuide)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showCommandGuide)
        XCTAssertTrue(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertEqual(store.interactionMode, .inspect)
    }

    @MainActor
    func testFocusedMapShortcutDispatchesTheSameStoreIntentExactlyOnce() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        var dispatchCount = 0
        scene.onCommandAction = { command in
            dispatchCount += 1
            store.perform(command)
        }

        scene.keyDown(with: try keyEvent(characters: "3", keyCode: 20))
        XCTAssertEqual(store.speed, .fastest)
        XCTAssertEqual(dispatchCount, 1)

        scene.keyDown(with: try keyEvent(characters: "b", keyCode: 11))
        XCTAssertEqual(store.interactionMode, .bulldoze)
        XCTAssertEqual(dispatchCount, 2)

        scene.keyDown(with: try keyEvent(characters: "\u{1b}", keyCode: 53))
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertEqual(dispatchCount, 3)

        scene.keyDown(with: try keyEvent(characters: "b", keyCode: 11, modifiers: .command))
        XCTAssertEqual(dispatchCount, 3, "Modified input belongs to SwiftUI menus and must not double invoke")
    }

    @MainActor
    func testCommandGuideRendersWithinCompactAndDefaultBounds() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let compact = try bitmap(
            of: CommandGuideView(store: store).frame(width: 620, height: 480),
            size: CGSize(width: 620, height: 480)
        )
        let regular = try bitmap(
            of: CommandGuideView(store: store).frame(width: 760, height: 560),
            size: CGSize(width: 760, height: 560)
        )

        XCTAssertEqual(compact.size.width, 620, accuracy: 0.5)
        XCTAssertEqual(compact.size.height, 480, accuracy: 0.5)
        XCTAssertEqual(regular.size.width, 760, accuracy: 0.5)
        XCTAssertEqual(regular.size.height, 560, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(compact.pixelsWide, 620)
        XCTAssertGreaterThanOrEqual(compact.pixelsHigh, 480)

        if let path = ProcessInfo.processInfo.environment["CITYSIM_COMMAND_GUIDE_PROOF"] {
            let data = try XCTUnwrap(compact.representation(using: .png, properties: [:]))
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

    private func keyEvent(
        characters: String,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        ))
    }
}
