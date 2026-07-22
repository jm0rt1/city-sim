import AppKit
import SpriteKit
import SwiftUI
import XCTest
@testable import CitySimNative

@MainActor
private final class FocusProbeView: NSView {
    override var acceptsFirstResponder: Bool { true }
}

final class CityCommandCatalogTests: XCTestCase {
    func testCatalogDeclaresEveryCommandExactlyOnceAndCoversNonSpatialInventory() {
        let descriptors = CityCommandCatalog.descriptors
        let descriptorIDs = descriptors.map(\.id)
        let spatialIDs = Set<CityCommandID>([.cameraZoomIn, .cameraZoomOut, .cameraFrameCity])
            .union(CityCommandCatalog.mapFocusedCommands)
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

    func testWarningLanguageFindsTaxPolicyThroughTheCatalog() {
        for query in ["tax", "budget", "storefront"] {
            let matches = CityCommandCatalog.matchingDescriptors(query: query)
            XCTAssertTrue(
                matches.contains { $0.id == .inspectorFinances },
                "\(query) must find the existing Tax Policy route"
            )
        }
        XCTAssertEqual(
            CityCommandCatalog.matchingDescriptors(query: "tax").filter { $0.id == .inspectorFinances }.count,
            1
        )
    }

    @MainActor
    func testTaxPolicySearchResultUsesCurrentAvailabilityAndDisabledReason() throws {
        let enabled = CityGameStore(state: .newCity(seed: 42))
        let result = try XCTUnwrap(CityCommandCatalog.matchingDescriptors(query: "storefront").first)
        XCTAssertEqual(result.id, .inspectorFinances)
        XCTAssertTrue(enabled.canPerform(result.id))
        XCTAssertNil(enabled.disabledReason(for: result.id))

        let blocked = CityGameStore(state: .newCity(seed: 42), commandPolicy: .blocked(.welcome))
        XCTAssertFalse(blocked.canPerform(result.id))
        XCTAssertEqual(
            blocked.disabledReason(for: result.id),
            "Finish Welcome to New Arcadia to use city commands"
        )
    }

    func testFocusMetadataKeepsUnmodifiedGameplayKeysOutOfGlobalMenus() {
        let gameplayIDs = Set<CityCommandID>([
            .togglePause, .speedNormal, .speedFast, .speedFastest,
            .inspectMode, .buildMode, .bulldozeMode, .cancelInteraction
        ]).union(CityCommandCatalog.mapFocusedCommands)

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
    func testWelcomePolicyBlocksEveryCatalogAndRendererRouteUntilExplicitDismissal() throws {
        let authoredStart = CityGameState.newCity(seed: 42)
        let store = CityGameStore(state: authoredStart, commandPolicy: .blocked(.welcome))
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        var routedCommands: [CityCommandID] = []
        scene.allowsCommand = { store.commandPolicy.allows($0) }
        scene.onCommandAction = { command in
            routedCommands.append(command)
            store.perform(command)
        }
        let cameraScale = scene.cameraScale

        let blockedKeys: [(String, UInt16)] = [
            (" ", 49), ("1", 18), ("2", 19), ("3", 20),
            ("b", 11), ("v", 9), ("\u{1b}", 53),
            ("+", 24), ("-", 27), ("0", 29),
            ("", 126), ("\r", 36)
        ]
        for key in blockedKeys {
            scene.keyDown(with: try keyEvent(characters: key.0, keyCode: key.1))
        }

        let blockedCatalogCommands: [CityCommandID] = [
            .togglePause, .speedNormal, .speedFast, .speedFastest,
            .bulldozeMode, .inspectMode, .cancelInteraction, .openCommandGuide,
            .toggleObjectives, .toggleCommandCenter, .saveCity
        ]
        XCTAssertEqual(
            CityCommandCatalog.matchingCommand(key: "/", modifiers: [.command], scope: .global),
            .openCommandGuide,
            "The D005 Command-/ route must resolve through the same blocked catalog intent"
        )
        for command in blockedCatalogCommands {
            XCTAssertFalse(store.perform(command), "\(command.rawValue) must be rejected by Welcome")
            XCTAssertEqual(
                store.disabledReason(for: command),
                "Finish Welcome to New Arcadia to use city commands"
            )
        }
        store.primaryAction(at: GridCoordinate(x: 4, y: 4))
        store.secondaryAction(at: GridCoordinate(x: 4, y: 4))
        store.pulse()

        XCTAssertEqual(routedCommands, [])
        XCTAssertEqual(scene.cameraScale, cameraScale)
        XCTAssertEqual(store.state, authoredStart)
        XCTAssertEqual(store.speed, .normal)
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertFalse(store.showObjectives)
        XCTAssertFalse(store.showInspector)
        XCTAssertFalse(store.showCommandGuide)

        XCTAssertTrue(store.dismissBlockingModal(.welcome))
        XCTAssertEqual(store.commandPolicy, .enabled)
        XCTAssertEqual(store.speed, .normal, "Dismissal must preserve the authored 1x start")
        XCTAssertFalse(store.dismissBlockingModal(.welcome), "Dismissal is a one-way explicit transition")

        scene.keyDown(with: try keyEvent(characters: "3", keyCode: 20))
        XCTAssertEqual(store.speed, .fastest)
        scene.keyDown(with: try keyEvent(characters: "b", keyCode: 11))
        XCTAssertEqual(store.interactionMode, .bulldoze)
        XCTAssertTrue(store.perform(.openCommandGuide))
        XCTAssertTrue(store.showCommandGuide)
    }

    @MainActor
    func testWelcomePolicyTransitionQueuesOneLifecycleSafeMapFocusHandoff() {
        let store = CityGameStore(state: .newCity(seed: 42), commandPolicy: .blocked(.welcome))
        var queuedActions: [CitySceneView.Coordinator.MainLoopAction] = []
        let coordinator = CitySceneView.Coordinator(store: store) { action in
            queuedActions.append(action)
        }
        let mapView = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let priorResponder = FocusProbeView(frame: CGRect(x: 10, y: 10, width: 180, height: 24))
        let contentView = NSView(frame: mapView.frame)
        let window = NSWindow(
            contentRect: mapView.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        contentView.addSubview(mapView)
        contentView.addSubview(priorResponder)
        window.contentView = contentView

        XCTAssertTrue(window.makeFirstResponder(priorResponder))
        XCTAssertFalse(coordinator.synchronizeCommandPolicy(.blocked(.welcome), in: mapView))
        XCTAssertTrue(store.dismissBlockingModal(.welcome))
        XCTAssertTrue(coordinator.synchronizeCommandPolicy(store.commandPolicy, in: mapView))
        XCTAssertTrue(window.firstResponder === priorResponder, "Focus must wait until SwiftUI finishes its lifecycle turn")
        XCTAssertEqual(queuedActions.count, 1)
        XCTAssertEqual(coordinator.pendingFocusHandoffGeneration, 1)
        XCTAssertFalse(
            coordinator.synchronizeCommandPolicy(.enabled, in: mapView),
            "Repeated enabled renders must not enqueue another handoff"
        )
        XCTAssertEqual(queuedActions.count, 1)

        queuedActions.removeFirst()()
        XCTAssertTrue(window.firstResponder === mapView)
        XCTAssertEqual(coordinator.previousCommandPolicy, .enabled)
        XCTAssertNil(coordinator.pendingFocusHandoffGeneration)
        XCTAssertFalse(
            coordinator.synchronizeCommandPolicy(.enabled, in: mapView),
            "The completed policy transition must not churn first responder"
        )
        XCTAssertFalse(CitySceneView.Coordinator.requiresGameplayFocus(from: .enabled, to: .blocked(.welcome)))
        XCTAssertFalse(CitySceneView.Coordinator.requiresGameplayFocus(from: .enabled, to: .enabled))
    }

    @MainActor
    func testQueuedWelcomeFocusHandoffCancelsWhenModalReblocksOrMapDetaches() throws {
        let store = CityGameStore(state: .newCity(seed: 42), commandPolicy: .blocked(.welcome))
        var queuedActions: [CitySceneView.Coordinator.MainLoopAction] = []
        let coordinator = CitySceneView.Coordinator(store: store) { action in
            queuedActions.append(action)
        }
        let mapView = SKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let priorResponder = FocusProbeView(frame: CGRect(x: 10, y: 10, width: 180, height: 24))
        let contentView = NSView(frame: mapView.frame)
        let window = NSWindow(
            contentRect: mapView.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        contentView.addSubview(mapView)
        contentView.addSubview(priorResponder)
        window.contentView = contentView
        XCTAssertTrue(window.makeFirstResponder(priorResponder))

        XCTAssertTrue(store.dismissBlockingModal(.welcome))
        XCTAssertTrue(coordinator.synchronizeCommandPolicy(.enabled, in: mapView))
        let staleGeneration = try XCTUnwrap(coordinator.pendingFocusHandoffGeneration)
        store.presentBlockingModal(.welcome)
        XCTAssertFalse(coordinator.synchronizeCommandPolicy(store.commandPolicy, in: mapView))
        XCTAssertNil(coordinator.pendingFocusHandoffGeneration)
        XCTAssertGreaterThan(coordinator.focusHandoffGeneration, staleGeneration)
        queuedActions.removeFirst()()
        XCTAssertTrue(window.firstResponder === priorResponder, "A reblocked modal must stale the queued handoff")

        XCTAssertTrue(store.dismissBlockingModal(.welcome))
        XCTAssertTrue(coordinator.synchronizeCommandPolicy(.enabled, in: mapView))
        mapView.removeFromSuperview()
        queuedActions.removeFirst()()
        XCTAssertTrue(window.firstResponder === priorResponder, "A detached map must not receive focus")
        XCTAssertNil(coordinator.pendingFocusHandoffGeneration)
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

        scene.keyDown(with: try keyEvent(characters: "5", keyCode: 23, modifiers: .shift))
        XCTAssertEqual(store.selectedBuildCategory, .civic)
        XCTAssertEqual(store.selectedTool, .park)
        XCTAssertEqual(store.interactionMode, .build(.park))
        XCTAssertEqual(dispatchCount, 4)

        scene.keyDown(with: try keyEvent(characters: "h", keyCode: 4))
        XCTAssertEqual(store.selectedBuildCategory, .zones)
        XCTAssertEqual(store.selectedTool, .residential)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(dispatchCount, 5)

        scene.keyDown(with: try keyEvent(characters: "b", keyCode: 11, modifiers: .command))
        XCTAssertEqual(dispatchCount, 5, "Modified input belongs to SwiftUI menus and must not double invoke")
    }

    @MainActor
    func testMapNavigationRequiresActualSKViewFirstResponderAndDispatchesOnce() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        let mapView = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        mapView.presentScene(scene)
        let priorResponder = FocusProbeView(frame: CGRect(x: 10, y: 10, width: 180, height: 24))
        let contentView = NSView(frame: mapView.frame)
        contentView.addSubview(mapView)
        contentView.addSubview(priorResponder)
        let window = NSWindow(contentRect: mapView.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = contentView
        var routed: [CityCommandID] = []
        scene.allowsCommand = { store.canPerformMapCommand($0) }
        scene.onCommandAction = {
            routed.append($0)
            store.performMapCommand($0)
        }

        XCTAssertTrue(window.makeFirstResponder(priorResponder))
        scene.keyDown(with: try keyEvent(characters: "", keyCode: 126))
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(routed, [])

        XCTAssertTrue(window.makeFirstResponder(mapView))
        scene.keyDown(with: try keyEvent(characters: "", keyCode: 124))
        let first = try XCTUnwrap(store.selectedCoordinate)
        XCTAssertEqual(routed, [.mapMoveEast])

        scene.keyDown(with: try keyEvent(characters: "", keyCode: 125, modifiers: .shift))
        XCTAssertEqual(store.selectedCoordinate?.x, first.x)
        XCTAssertEqual(store.selectedCoordinate?.y, min(store.state.gridHeight - 1, first.y + 5))
        XCTAssertEqual(routed, [.mapMoveEast, .mapMoveSouthFast])

        scene.keyDown(with: try keyEvent(characters: "\r", keyCode: 36))
        XCTAssertEqual(routed.last, .mapPrimaryAction)
        XCTAssertTrue(store.showInspector)

        let coordinator = CitySceneView.Coordinator(store: store)
        coordinator.configureMapAccessibility(in: mapView)
        XCTAssertEqual(mapView.accessibilityLabel(), "City map")
        XCTAssertTrue((mapView.accessibilityValue() as? String)?.contains("Selected") == true)
        let selected = try XCTUnwrap(store.selectedCoordinate)
        let selectedKind = try XCTUnwrap(store.selectedTile?.kind)
        XCTAssertEqual(
            mapView.accessibilityCustomActions()?.map(\.name),
            ["Inspect \(selectedKind.title) at block \(selected.x + 1), \(selected.y + 1)"]
        )
    }

    @MainActor
    func testMeasuredHUDChromeKeepsKeyboardSelectionInsideDefaultAndExactCompactMapViewport() throws {
        let cases: [(size: CGSize, compact: Bool, chrome: CityHUDChromeFrames)] = [
            (
                CGSize(width: 1280, height: 800),
                false,
                CityHUDChromeFrames(
                    top: CGRect(x: 18, y: 18, width: 1244, height: 68),
                    bottom: CGRect(x: 80, y: 642, width: 1120, height: 140)
                )
            ),
            (
                CGSize(width: 900, height: 600),
                true,
                CityHUDChromeFrames(
                    top: CGRect(x: 12, y: 12, width: 876, height: 116),
                    bottom: CGRect(x: 12, y: 374, width: 876, height: 214)
                )
            )
        ]

        for scenario in cases {
            let state = CityGameState.newCity(seed: 42)
            let scene = CityScene(size: scenario.size)
            scene.render(state: state, overlay: .none, selection: nil, interactionMode: .inspect)
            scene.configureProofCamera(detail: .block, centeredOn: GridCoordinate(x: 12, y: 12))
            let insets = ContentView.mapViewportInsets(
                windowSize: scenario.size,
                compact: scenario.compact,
                chromeFrames: scenario.chrome
            )
            XCTAssertGreaterThan(insets.bottom, insets.top, "Bottom command chrome must produce asymmetric protection")

            for target in [GridCoordinate(x: 0, y: 0), GridCoordinate(x: 23, y: 23)] {
                scene.revealSelection(target, viewportInsets: insets)
                let safeRect = scene.safeViewportRectForTesting(insets)
                let targetPoint = scene.scenePointForTesting(at: target)
                XCTAssertGreaterThanOrEqual(targetPoint.x, safeRect.minX - 0.001)
                XCTAssertLessThanOrEqual(targetPoint.x, safeRect.maxX + 0.001)
                XCTAssertGreaterThanOrEqual(targetPoint.y, safeRect.minY - 0.001)
                XCTAssertLessThanOrEqual(
                    targetPoint.y,
                    safeRect.maxY + 0.001,
                    "Keyboard target \(target) is occluded at \(Int(scenario.size.width))x\(Int(scenario.size.height))"
                )
            }
        }
    }

    @MainActor
    func testStoreOwnsBoundedSelectionAndKeyboardUsesExactPointerAction() throws {
        let initial = CityGameState.newCity(seed: 42)
        let keyboard = CityGameStore(state: initial)
        let pointer = CityGameStore(state: initial)

        XCTAssertTrue(keyboard.moveMapSelection(dx: -1, dy: -1, distance: 10_000))
        XCTAssertEqual(keyboard.selectedCoordinate, GridCoordinate(x: 0, y: 0))
        XCTAssertTrue(keyboard.moveMapSelection(dx: 1, dy: 1, distance: 10_000))
        XCTAssertEqual(
            keyboard.selectedCoordinate,
            GridCoordinate(x: initial.gridWidth - 1, y: initial.gridHeight - 1)
        )

        let target = try XCTUnwrap(initial.tiles.first { $0.kind != .empty }?.coordinate)
        keyboard.selectedCoordinate = target
        pointer.primaryAction(at: target)
        XCTAssertTrue(keyboard.performMapCommand(.mapPrimaryAction))
        XCTAssertEqual(keyboard.selectedCoordinate, pointer.selectedCoordinate)
        XCTAssertEqual(keyboard.hudContextScope, pointer.hudContextScope)
        XCTAssertEqual(keyboard.showInspector, pointer.showInspector)

        keyboard.presentBlockingModal(.welcome)
        XCTAssertFalse(keyboard.performMapCommand(.mapMoveEast))
        XCTAssertFalse(keyboard.performMapCommand(.mapPrimaryAction))
    }

    @MainActor
    func testApprovedRemedyRequestsOneLifecycleSafeMapFocus() {
        let store = CityGameStore(state: .newCity(seed: 42))
        var queuedActions: [CitySceneView.Coordinator.MainLoopAction] = []
        let coordinator = CitySceneView.Coordinator(store: store) { queuedActions.append($0) }
        let mapView = SKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let priorResponder = FocusProbeView(frame: CGRect(x: 10, y: 10, width: 180, height: 24))
        let contentView = NSView(frame: mapView.frame)
        contentView.addSubview(mapView)
        contentView.addSubview(priorResponder)
        let window = NSWindow(contentRect: mapView.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = contentView
        XCTAssertTrue(window.makeFirstResponder(priorResponder))

        XCTAssertFalse(store.performMapFocused(.inspectorFinances), "Only approved map-entry remedies may request focus")
        XCTAssertEqual(store.mapFocusRequestGeneration, 0)
        XCTAssertTrue(store.performMapFocused(.buildPark))
        XCTAssertEqual(store.mapFocusRequestGeneration, 1)
        XCTAssertTrue(coordinator.synchronizeMapFocusRequest(store.mapFocusRequestGeneration, in: mapView))
        XCTAssertFalse(coordinator.synchronizeMapFocusRequest(store.mapFocusRequestGeneration, in: mapView))
        XCTAssertEqual(queuedActions.count, 1)
        queuedActions.removeFirst()()
        XCTAssertTrue(window.firstResponder === mapView)
    }

    @MainActor
    func testMapPrimaryActionDisclosesTargetCostAndDisablesProtectedOrInvalidTargets() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let coordinator = CitySceneView.Coordinator(store: store)
        let mapView = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let demolitionTile = try XCTUnwrap(store.state.tiles.first {
            $0.kind != .empty && $0.kind != .cityHall
        })
        store.interactionMode = .bulldoze
        store.selectedCoordinate = demolitionTile.coordinate
        coordinator.configureMapAccessibility(in: mapView)

        let demolitionCost = demolitionTile.kind.demolitionCost.currencyText
        let expectedName = "Demolish \(demolitionTile.kind.title) at block \(demolitionTile.coordinate.x + 1), \(demolitionTile.coordinate.y + 1) for \(demolitionCost)"
        XCTAssertEqual(mapView.accessibilityCustomActions()?.first?.name, expectedName)
        XCTAssertTrue((mapView.accessibilityValue() as? String)?.contains(expectedName) == true)
        XCTAssertTrue((mapView.accessibilityValue() as? String)?.contains("Undo is available") == true)
        XCTAssertTrue(store.canPerformMapCommand(.mapPrimaryAction))
        let beforeDemolition = store.state
        XCTAssertTrue(store.performMapCommand(.mapPrimaryAction))
        XCTAssertEqual(store.state.tile(at: demolitionTile.coordinate)?.kind, .empty)
        XCTAssertTrue(store.perform(.undo))
        XCTAssertEqual(store.state, beforeDemolition)

        let cityHall = try XCTUnwrap(store.state.tiles.first { $0.kind == .cityHall })
        store.selectedCoordinate = cityHall.coordinate
        coordinator.configureMapAccessibility(in: mapView)
        XCTAssertFalse(store.canPerformMapCommand(.mapPrimaryAction))
        XCTAssertFalse(mapView.accessibilityCustomActions()?.contains { $0.name.hasPrefix("Demolish") } ?? true)
        XCTAssertTrue((mapView.accessibilityValue() as? String)?.contains("protected landmark") == true)

        let openLand = try XCTUnwrap(store.state.tiles.first { $0.kind == .empty })
        store.interactionMode = .build(.residential)
        store.selectedCoordinate = openLand.coordinate
        coordinator.configureMapAccessibility(in: mapView)
        let buildPresentation = CityMapPrimaryActionPresentation.make(
            interactionMode: store.interactionMode,
            tile: openLand,
            state: store.state
        )
        XCTAssertEqual(store.canPerformMapCommand(.mapPrimaryAction), buildPresentation.isAvailable)
        XCTAssertEqual(
            mapView.accessibilityCustomActions()?.contains { $0.name == buildPresentation.name } ?? false,
            buildPresentation.isAvailable
        )
        XCTAssertTrue((mapView.accessibilityValue() as? String)?.contains(buildPresentation.disclosure) == true)
    }

    @MainActor
    func testDiagnosisConsumesExactSpatialSnapshotAndAuthoredNoticeInventoryHasHonestActions() throws {
        let state = CityGameState.newCity(seed: 42)
        let snapshot = try CityPresentationSnapshot(state: state)
        let tile = try XCTUnwrap(state.tiles.first {
            guard $0.kind != .empty, $0.kind != .road, $0.constructionProgress >= 1,
                  let sample = snapshot.spatialConsequences[$0.coordinate] else { return false }
            return sample.vitality != .notApplicable
        })
        let sample = try XCTUnwrap(snapshot.spatialConsequences[tile.coordinate])
        let diagnosis = try XCTUnwrap(CitySelectedLocationDiagnosis.make(tile: tile, snapshot: snapshot))

        XCTAssertEqual(diagnosis.coordinate, tile.coordinate)
        XCTAssertTrue(diagnosis.consequence.contains((sample.vitalityScore * 100).percentText))
        XCTAssertTrue(diagnosis.accessibilitySummary.contains("Cause:"))
        XCTAssertTrue(diagnosis.accessibilitySummary.contains("Consequence:"))
        XCTAssertTrue(diagnosis.responses.allSatisfy { CityCommandCatalog.descriptor(for: $0.command).route == .store })

        let simulationSource = try String(
            contentsOf: authoredSimulationSourceURL(),
            encoding: .utf8
        )
        let expression = try NSRegularExpression(
            pattern: #"severity:\s*\.(?:warning|critical),\s*title:\s*\"([^\"]+)\""#
        )
        let sourceRange = NSRange(simulationSource.startIndex..., in: simulationSource)
        let authoredWarningAndCriticalTitles = Set(expression.matches(
            in: simulationSource,
            range: sourceRange
        ).compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: simulationSource) else { return nil }
            return String(simulationSource[range])
        })
        let expectedPLAY012Titles: Set<String> = [
            "Budget Gap", "Chain Store Rumor", "Freight Contract Watch",
            "Freight Load Forecast", "Freight Recovery Delayed", "Hiring Bottleneck",
            "Industrial Load Surge", "Main Street Crossroads", "Main Street Recovery Delayed",
            "Severe Storm", "Storefront Slump", "Utility Reserve Tight", "Utility Shortfall"
        ]
        XCTAssertEqual(
            authoredWarningAndCriticalTitles,
            expectedPLAY012Titles,
            "Any authored warning/critical addition or rename requires an explicit UI action disposition"
        )
        XCTAssertTrue(CityNoticeActionCatalog.governedTitles.isSuperset(of: authoredWarningAndCriticalTitles))

        for title in authoredWarningAndCriticalTitles {
            let actions = CityNoticeActionCatalog.actions(for: title)
            XCTAssertFalse(actions.isEmpty, "\(title) requires an explicit action disposition")
            XCTAssertTrue(actions.allSatisfy { !$0.explanation.isEmpty })
        }
    }

    @MainActor
    func testSelectedDiagnosisRendersAtDefaultAndCompactSizes() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let tile = try XCTUnwrap(store.state.tiles.first { $0.kind != .empty && $0.kind != .road })
        store.select(tile.coordinate)
        let compact = try bitmap(
            of: InspectorView(store: store, compact: true).frame(width: 820, height: 220),
            size: CGSize(width: 820, height: 220)
        )
        let regular = try bitmap(
            of: InspectorView(store: store, compact: false).frame(width: 1120, height: 240),
            size: CGSize(width: 1120, height: 240)
        )
        XCTAssertEqual(compact.size.width, 820, accuracy: 0.5)
        XCTAssertEqual(compact.size.height, 220, accuracy: 0.5)
        XCTAssertEqual(regular.size.width, 1120, accuracy: 0.5)
        XCTAssertEqual(regular.size.height, 240, accuracy: 0.5)
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

    private func authoredSimulationSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/CitySimNative/Services/CitySimulation.swift")
    }
}
