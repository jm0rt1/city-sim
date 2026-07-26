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

    func testFocusCityIsOneDiscoverableGlobalCatalogCommand() {
        let descriptor = CityCommandCatalog.descriptor(for: .toggleCityFocus)

        XCTAssertEqual(descriptor.category, .panels)
        XCTAssertEqual(descriptor.route, .store)
        XCTAssertFalse(descriptor.isSpatial)
        XCTAssertEqual(descriptor.shortcut?.key, "f")
        XCTAssertEqual(descriptor.shortcut?.modifiers, [.command, .shift])
        XCTAssertEqual(descriptor.shortcut?.display, "⇧⌘F")
        XCTAssertEqual(descriptor.shortcut?.focusScope, .global)
        XCTAssertEqual(
            CityCommandCatalog.matchingCommand(
                key: "f",
                modifiers: [.command, .shift],
                scope: .global
            ),
            .toggleCityFocus
        )
        XCTAssertEqual(
            CityCommandCatalog.matchingDescriptors(query: "focus city").filter {
                $0.id == .toggleCityFocus
            }.count,
            1
        )
    }

    @MainActor
    func testFocusCityNoticeUrgencyUsesAuthoritativeCountSeverityAndExistingRoute() {
        var state = CityGameState.newCity(seed: 42)
        state.messages = []
        var store = CityGameStore(state: state)
        var presentation = FocusCityNoticeUrgencyPresentation(
            count: store.alertCount,
            severity: store.highestAlertSeverity
        )
        XCTAssertEqual(presentation.compactLabel, "0")
        XCTAssertEqual(presentation.regularLabel, "No notices")
        XCTAssertEqual(presentation.accessibilityValue, "No active notices")

        state.messages = [
            CityMessage(
                tick: state.tick,
                severity: .warning,
                title: "Utility Reserve Tight",
                detail: "Authoritative warning detail"
            )
        ]
        store = CityGameStore(state: state)
        presentation = FocusCityNoticeUrgencyPresentation(
            count: store.alertCount,
            severity: store.highestAlertSeverity
        )
        XCTAssertEqual(presentation.compactLabel, "WARNING 1")
        XCTAssertEqual(presentation.regularLabel, "1 WARNING")
        XCTAssertEqual(presentation.accessibilityValue, "1 notice, highest severity warning")

        state.messages.append(CityMessage(
            tick: state.tick,
            severity: .critical,
            title: "Severe Storm",
            detail: "Authoritative critical detail"
        ))
        store = CityGameStore(state: state)
        presentation = FocusCityNoticeUrgencyPresentation(
            count: store.alertCount,
            severity: store.highestAlertSeverity
        )
        XCTAssertEqual(
            CityStrategyHUDPresentation.make(analytics: store.analytics).tone,
            .decision,
            "The strategy presentation may remain calm while notice truth is independently critical"
        )
        XCTAssertEqual(presentation.severity, .critical)
        XCTAssertEqual(presentation.compactLabel, "CRITICAL 2")
        XCTAssertEqual(presentation.regularLabel, "2 CRITICAL")
        XCTAssertEqual(presentation.accessibilityValue, "2 notices, highest severity critical")

        XCTAssertTrue(store.perform(.toggleCityFocus))
        XCTAssertTrue(store.isCityFocusModeEnabled)
        XCTAssertTrue(store.perform(.openNotices))
        XCTAssertFalse(store.isCityFocusModeEnabled)
        XCTAssertTrue(store.showInspector)
        XCTAssertEqual(store.inspectorSection, .journal)
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
        XCTAssertTrue(CityCommandCatalog.descriptor(for: .inspectorFinances).title.contains("Tax Policy"))
    }

    func testStrategyHUDConsumesEveryFrozenStoryMomentFromAuthoritativeAnalytics() throws {
        let fixtures = try ProductionStoryStateBuilder().buildAll()
        XCTAssertEqual(fixtures.count, 12)

        for fixture in fixtures {
            let presentation = CityStrategyHUDPresentation.make(
                analytics: CityAnalytics(state: fixture.state)
            )

            switch fixture.definition.stage {
            case .opening:
                XCTAssertEqual(presentation.tone, .active, fixture.definition.id)
                XCTAssertEqual(presentation.status, "OPPORTUNITY · 16 DAYS", fixture.definition.id)
                XCTAssertFalse(presentation.actions.isEmpty, fixture.definition.id)
            case .complication:
                XCTAssertEqual(presentation.tone, .active, fixture.definition.id)
                XCTAssertEqual(presentation.status, "DECISION · 16 DAYS", fixture.definition.id)
                XCTAssertFalse(presentation.actions.isEmpty, fixture.definition.id)
            case .recovery:
                XCTAssertEqual(presentation.tone, .recovery, fixture.definition.id)
                XCTAssertEqual(presentation.status, "REVIEW · 16 DAYS", fixture.definition.id)
                XCTAssertTrue(presentation.title.contains("locked in"), fixture.definition.id)
                XCTAssertTrue(presentation.actions.isEmpty, fixture.definition.id)
            case .charterMidpoint:
                XCTAssertEqual(presentation.tone, .active, fixture.definition.id)
                XCTAssertEqual(presentation.status, "MANDATE · 16 DAYS", fixture.definition.id)
                XCTAssertEqual(presentation.title, "Regional Capital mandate", fixture.definition.id)
                XCTAssertFalse(presentation.actions.isEmpty, fixture.definition.id)
            case .regionalCapital:
                XCTAssertEqual(presentation.tone, .resolved, fixture.definition.id)
                XCTAssertEqual(presentation.status, "RECOGNIZED", fixture.definition.id)
                XCTAssertEqual(presentation.title, "Regional Capital secured", fixture.definition.id)
                XCTAssertTrue(presentation.actions.isEmpty, fixture.definition.id)
            }

            switch fixture.definition.strategy {
            case .commercialStewardship:
                XCTAssertTrue(presentation.eyebrow.contains("MAIN STREET"), fixture.definition.id)
                XCTAssertEqual(presentation.diagnostic?.command, .inspectorFinances, fixture.definition.id)
            case .industrialExpansion:
                XCTAssertTrue(presentation.eyebrow.contains("FREIGHT"), fixture.definition.id)
                XCTAssertEqual(presentation.diagnostic?.command, .inspectorUtilities, fixture.definition.id)
            }
        }
    }

    func testStrategyHUDCountdownIgnoresMessageProseAndUrgentRoutesUseCatalogCommands() throws {
        var commercial = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .commercialStewardship
                    && $0.definition.moment == .complication
            }?.state
        )
        commercial.progression?.strategy?.currentPhase = .setback
        commercial.progression?.strategy?.nextScheduledTick = commercial.tick + 20
        let original = CityStrategyHUDPresentation.make(analytics: CityAnalytics(state: commercial))

        XCTAssertEqual(original.tone, .urgent)
        XCTAssertEqual(original.status, "ACT NOW · 5 DAYS")
        XCTAssertEqual(original.diagnostic?.command, .inspectorFinances)
        XCTAssertEqual(Set(original.actions.map(\.command)), Set([.inspectorFinances, .buildPark]))

        commercial.messages = [
            CityMessage(
                tick: 999_999,
                severity: .good,
                title: "Unrelated prose",
                detail: "This text claims a different deadline and must not affect typed HUD truth."
            )
        ]
        XCTAssertEqual(
            CityStrategyHUDPresentation.make(analytics: CityAnalytics(state: commercial)),
            original
        )

        var industrial = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .industrialExpansion
                    && $0.definition.moment == .complication
            }?.state
        )
        industrial.progression?.strategy?.currentPhase = .setback
        industrial.progression?.strategy?.nextScheduledTick = industrial.tick
        let industrialPresentation = CityStrategyHUDPresentation.make(
            analytics: CityAnalytics(state: industrial)
        )
        XCTAssertEqual(industrialPresentation.status, "ACT NOW · TODAY")
        XCTAssertEqual(industrialPresentation.diagnostic?.command, .inspectorUtilities)
        XCTAssertEqual(
            Set(industrialPresentation.actions.map(\.command)),
            Set([.buildPowerPlant, .buildWaterTower, .buildPark])
        )
    }

    @MainActor
    func testStrategyHUDDiagnosisAndMapRemediesUseOneStoreIntentAndFocusHandoff() throws {
        let fixtures = try ProductionStoryStateBuilder().buildAll()
        let commercialState = try XCTUnwrap(fixtures.first {
            $0.definition.strategy == .commercialStewardship
                && $0.definition.moment == .complication
        }?.state)
        let commercialStore = CityGameStore(state: commercialState)
        let commercial = CityStrategyHUDPresentation.make(analytics: commercialStore.analytics)
        let diagnostic = try XCTUnwrap(commercial.diagnostic)
        let park = try XCTUnwrap(commercial.actions.first { $0.command == .buildPark })

        XCTAssertTrue(commercialStore.perform(diagnostic.command))
        XCTAssertTrue(commercialStore.showInspector)
        XCTAssertEqual(commercialStore.inspectorSection, .finances)
        let focusBeforePark = commercialStore.mapFocusRequestGeneration
        XCTAssertTrue(commercialStore.performMapFocused(park.command))
        XCTAssertEqual(commercialStore.interactionMode, .build(.park))
        XCTAssertEqual(commercialStore.mapFocusRequestGeneration, focusBeforePark + 1)

        let industrialState = try XCTUnwrap(fixtures.first {
            $0.definition.strategy == .industrialExpansion
                && $0.definition.moment == .complication
        }?.state)
        let industrialStore = CityGameStore(state: industrialState)
        let industrial = CityStrategyHUDPresentation.make(analytics: industrialStore.analytics)
        let power = try XCTUnwrap(industrial.actions.first { $0.command == .buildPowerPlant })
        let focusBeforePower = industrialStore.mapFocusRequestGeneration
        XCTAssertTrue(industrialStore.performMapFocused(power.command))
        XCTAssertEqual(industrialStore.interactionMode, .build(.powerPlant))
        XCTAssertEqual(industrialStore.mapFocusRequestGeneration, focusBeforePower + 1)
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

    @MainActor
    func testCommandGuideActivationUsesExistingStoreIntentAndKeepsDisabledReason() {
        let available = CityGameStore(state: .newCity(seed: 42))
        available.showCommandGuide = true

        XCTAssertTrue(available.performFromCommandGuide(.inspectorFinances))
        XCTAssertFalse(available.showCommandGuide)
        XCTAssertTrue(available.showInspector)
        XCTAssertEqual(available.inspectorSection, .finances)

        let blocked = CityGameStore(
            state: .newCity(seed: 42),
            commandPolicy: .blocked(.welcome)
        )
        blocked.showCommandGuide = true

        XCTAssertFalse(blocked.performFromCommandGuide(.inspectorFinances))
        XCTAssertTrue(blocked.showCommandGuide)
        XCTAssertFalse(blocked.showInspector)
        XCTAssertEqual(
            blocked.disabledReason(for: .inspectorFinances),
            "Finish Welcome to New Arcadia to use city commands"
        )
    }

    @MainActor
    func testRejectedPlacementPreservesToolTargetAndDurableAcceptedReason() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let occupied = try XCTUnwrap(store.state.tiles.first { $0.kind != .empty })
        store.selectTool(.commercial)

        store.primaryAction(at: occupied.coordinate)

        XCTAssertEqual(store.interactionMode, .build(.commercial))
        XCTAssertEqual(store.selectedTool, .commercial)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.hudContextScope, .city)
        XCTAssertTrue(store.lastFeedback?.contains(BuildRejection.occupied.message) == true)
        XCTAssertTrue(store.lastFeedback?.contains("Commercial remains selected") == true)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 3.3))
        XCTAssertNotNil(store.lastFeedback, "Placement recovery must remain until the player acts or dismisses it")
        XCTAssertTrue(store.perform(.dismissFeedback))
        XCTAssertNil(store.lastFeedback)
        XCTAssertEqual(store.interactionMode, .build(.commercial))
    }

    @MainActor
    func testRejectedReturnRoutesOccupiedRoadlessAndUnaffordableTargetsWithoutAdvertisingAvailability() throws {
        let authored = CityGameState.newCity(seed: 42)
        let occupied = try XCTUnwrap(authored.tiles.first { $0.kind != .empty })
        let roadless = try XCTUnwrap(authored.tiles.first { tile in
            guard tile.kind == .empty else { return false }
            if case .failure(.roadAccessRequired) = CitySimulation.validateBuild(
                .commercial,
                at: tile.coordinate,
                in: authored
            ) {
                return true
            }
            return false
        })
        var unaffordableState = authored
        unaffordableState.treasury = 0
        let unaffordable = try XCTUnwrap(unaffordableState.tiles.first { $0.kind == .empty })
        let cases: [(state: CityGameState, coordinate: GridCoordinate, rejection: BuildRejection)] = [
            (authored, occupied.coordinate, .occupied),
            (authored, roadless.coordinate, .roadAccessRequired),
            (unaffordableState, unaffordable.coordinate, .insufficientFunds)
        ]
        var routedStores: [CityGameStore] = []

        for scenario in cases {
            let pointer = CityGameStore(state: scenario.state)
            let keyboard = CityGameStore(state: scenario.state)
            pointer.selectTool(.commercial)
            keyboard.selectTool(.commercial)
            keyboard.selectedCoordinate = scenario.coordinate
            keyboard.hudContextScope = .selection
            let before = keyboard.state

            pointer.primaryAction(at: scenario.coordinate)

            XCTAssertTrue(keyboard.canRouteMapCommand(.mapPrimaryAction))
            XCTAssertFalse(keyboard.canPerformMapCommand(.mapPrimaryAction))
            XCTAssertTrue(keyboard.performMapCommand(.mapPrimaryAction))
            XCTAssertEqual(keyboard.state, before)
            XCTAssertFalse(keyboard.canUndo)
            XCTAssertEqual(keyboard.selectedCoordinate, scenario.coordinate)
            XCTAssertEqual(keyboard.hudContextScope, .selection)
            XCTAssertEqual(keyboard.selectedTool, .commercial)
            XCTAssertEqual(keyboard.interactionMode, .build(.commercial))
            XCTAssertEqual(
                keyboard.lastFeedback,
                "\(scenario.rejection.message) Commercial remains selected — choose another block."
            )
            XCTAssertEqual(keyboard.lastFeedback, pointer.lastFeedback)
            routedStores.append(keyboard)
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 3.3))
        for (store, scenario) in zip(routedStores, cases) {
            XCTAssertNotNil(store.lastFeedback)
            XCTAssertTrue(store.perform(.dismissFeedback))
            XCTAssertNil(store.lastFeedback)
            XCTAssertEqual(store.selectedCoordinate, scenario.coordinate)
            XCTAssertEqual(store.interactionMode, .build(.commercial))
        }
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
        let selectedCoordinate = GridCoordinate(x: 14, y: 13)
        store.selectedCoordinate = selectedCoordinate
        store.hudContextScope = .selection
        store.perform(.toggleObjectives)
        store.perform(.inspectorUtilities)
        store.perform(.toggleCityFocus)
        store.perform(.openCommandGuide)
        let focusGeneration = store.mapFocusRequestGeneration

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showCommandGuide)
        XCTAssertTrue(store.isCityFocusModeEnabled)
        XCTAssertTrue(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.isCityFocusModeEnabled)
        XCTAssertTrue(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 1)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 2)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 3)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 3)
    }

    @MainActor
    func testFocusCityTogglePreservesPresentationIdentityAndUsesOneStoreIntent() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let target = try XCTUnwrap(store.state.tiles.first { $0.kind != .empty }?.coordinate)
        store.selectTool(.residential)
        store.selectedCoordinate = target
        store.hudContextScope = .selection
        store.showObjectives = true
        store.openInspector(.utilities)
        let state = store.state
        let speed = store.speed
        let tool = store.selectedTool
        let mode = store.interactionMode
        let section = store.inspectorSection
        let scope = store.hudContextScope
        let focusGeneration = store.mapFocusRequestGeneration

        XCTAssertTrue(store.perform(.toggleCityFocus))
        XCTAssertTrue(store.isCityFocusModeEnabled)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 1)
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(store.speed, speed)
        XCTAssertEqual(store.selectedTool, tool)
        XCTAssertEqual(store.interactionMode, mode)
        XCTAssertEqual(store.selectedCoordinate, target)
        XCTAssertEqual(store.inspectorSection, section)
        XCTAssertEqual(store.hudContextScope, scope)
        XCTAssertTrue(store.showInspector)
        XCTAssertTrue(store.showObjectives)

        XCTAssertTrue(store.perform(.toggleCityFocus))
        XCTAssertFalse(store.isCityFocusModeEnabled)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 2)
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(store.selectedCoordinate, target)
        XCTAssertEqual(store.interactionMode, mode)
        XCTAssertTrue(store.showInspector)
        XCTAssertTrue(store.showObjectives)

        store.showCommandGuide = true
        XCTAssertTrue(store.performFromCommandGuide(.toggleCityFocus))
        XCTAssertTrue(store.isCityFocusModeEnabled)
        XCTAssertFalse(store.showCommandGuide)
        XCTAssertEqual(store.selectedCoordinate, target)
        XCTAssertEqual(store.interactionMode, mode)
    }

    @MainActor
    func testFocusCityFramesDevelopedCityAfterSelectionClearsButPreservesRealTargetCamera() throws {
        _ = NSApplication.shared
        for size in [
            CGSize(width: 1_278, height: 768),
            CGSize(width: 900, height: 600),
        ] {
            let store = CityGameStore(state: .newCity(seed: 42))
            store.speed = .paused
            let scene = CityScene(size: size)
            scene.reducedMotion = true
            scene.render(
                state: store.state,
                overlay: .none,
                selection: nil,
                interactionMode: .inspect
            )
            let coordinator = CitySceneView.Coordinator(store: store)
            coordinator.scene = scene

            let retainedTarget = try XCTUnwrap(store.state.tiles.first {
                $0.kind == .cityHall
            }?.coordinate)
            store.selectedCoordinate = retainedTarget
            scene.configureProofCamera(detail: .block, centeredOn: GridCoordinate(x: 0, y: 0))
            let retainedScale = scene.cameraScale
            let retainedPosition = scene.camera?.position

            XCTAssertTrue(store.perform(.toggleCityFocus))
            XCTAssertFalse(
                coordinator.synchronizeCityFocusCamera(
                    isEnabled: store.isCityFocusModeEnabled,
                    selectedCoordinate: store.selectedCoordinate
                )
            )
            XCTAssertEqual(scene.cameraScale, retainedScale, accuracy: 0.000_001)
            XCTAssertEqual(scene.camera?.position, retainedPosition)

            XCTAssertTrue(store.perform(.toggleCityFocus))
            XCTAssertFalse(
                coordinator.synchronizeCityFocusCamera(
                    isEnabled: store.isCityFocusModeEnabled,
                    selectedCoordinate: store.selectedCoordinate
                )
            )

            store.cancelInteraction()
            XCTAssertNil(store.selectedCoordinate, "Escape cancellation leaves no active target")
            scene.configureProofCamera(detail: .block, centeredOn: GridCoordinate(x: 0, y: 0))
            let escapedScale = scene.cameraScale
            let escapedPosition = scene.camera?.position

            XCTAssertTrue(store.perform(.toggleCityFocus))
            XCTAssertTrue(
                coordinator.synchronizeCityFocusCamera(
                    isEnabled: store.isCityFocusModeEnabled,
                    selectedCoordinate: store.selectedCoordinate
                )
            )
            XCTAssertNotEqual(scene.cameraScale, escapedScale)
            XCTAssertNotEqual(scene.camera?.position, escapedPosition)
            let framedScale = scene.cameraScale
            let framedPosition = scene.camera?.position
            XCTAssertFalse(
                coordinator.synchronizeCityFocusCamera(
                    isEnabled: store.isCityFocusModeEnabled,
                    selectedCoordinate: store.selectedCoordinate
                ),
                "A settled Focus City update must not repeatedly reset the camera"
            )
            XCTAssertEqual(scene.cameraScale, framedScale, accuracy: 0.000_001)
            XCTAssertEqual(scene.camera?.position, framedPosition)

            XCTAssertTrue(store.perform(.toggleCityFocus))
            XCTAssertFalse(
                coordinator.synchronizeCityFocusCamera(
                    isEnabled: store.isCityFocusModeEnabled,
                    selectedCoordinate: store.selectedCoordinate
                )
            )

            let buildTarget = try XCTUnwrap(store.state.tiles.first { tile in
                guard tile.kind == .empty else { return false }
                if case .success = CitySimulation.validateBuild(
                    .road,
                    at: tile.coordinate,
                    in: store.state
                ) {
                    return true
                }
                return false
            }?.coordinate)
            store.selectTool(.road)
            store.selectedCoordinate = buildTarget
            let treasury = store.state.treasury
            store.primaryAction(at: buildTarget)
            XCTAssertEqual(store.state.treasury, treasury - BuildingKind.road.buildCost)
            store.undoLastAction()
            XCTAssertEqual(store.state.treasury, treasury)
            XCTAssertNil(store.selectedCoordinate, "Undo intentionally clears the reverted build target")
            scene.configureProofCamera(detail: .block, centeredOn: buildTarget)
            let undoScale = scene.cameraScale
            let undoPosition = scene.camera?.position

            XCTAssertTrue(store.perform(.toggleCityFocus))
            XCTAssertTrue(
                coordinator.synchronizeCityFocusCamera(
                    isEnabled: store.isCityFocusModeEnabled,
                    selectedCoordinate: store.selectedCoordinate
                )
            )
            XCTAssertNotEqual(scene.cameraScale, undoScale)
            XCTAssertNotEqual(scene.camera?.position, undoPosition)
            XCTAssertEqual(store.state.treasury, treasury)
            XCTAssertNil(store.selectedCoordinate)
        }
    }

    @MainActor
    func testHostedFocusCityRendersRestoredUndoSnapshotBeforeReframing() throws {
        _ = NSApplication.shared
        let defaults = UserDefaults.standard
        let welcomeKey = "hasSeenCitySimWelcome"
        let priorWelcome = defaults.object(forKey: welcomeKey)
        defaults.set(true, forKey: welcomeKey)
        defer {
            if let priorWelcome {
                defaults.set(priorWelcome, forKey: welcomeKey)
            } else {
                defaults.removeObject(forKey: welcomeKey)
            }
        }

        let cases: [(size: CGSize, compact: Bool, chrome: CityHUDChromeFrames)] = [
            (
                CGSize(width: 1_278, height: 768),
                false,
                CityHUDChromeFrames(
                    top: CGRect(x: 16, y: 16, width: 1_246, height: 118),
                    bottom: CGRect(x: 79, y: 688, width: 1_120, height: 64)
                )
            ),
            (
                CGSize(width: 900, height: 600),
                true,
                CityHUDChromeFrames(
                    top: CGRect(x: 8, y: 8, width: 884, height: 104),
                    bottom: CGRect(x: 8, y: 528, width: 884, height: 64)
                )
            ),
        ]

        for testCase in cases {
            let store = CityGameStore(state: .newCity(seed: 42))
            store.speed = .paused
            let host = NSHostingView(
                rootView: ContentView(store: store)
                    .frame(width: testCase.size.width, height: testCase.size.height)
            )
            host.frame = CGRect(origin: .zero, size: testCase.size)
            let window = NSWindow(
                contentRect: host.frame,
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

            let mapView = try XCTUnwrap(firstDescendant(of: CityMapSKView.self, in: host))
            let scene = try XCTUnwrap(mapView.scene as? CityScene)
            let target = try XCTUnwrap(store.state.tiles.first { tile in
                if case .success = CitySimulation.validateBuild(
                    .commercial,
                    at: tile.coordinate,
                    in: store.state
                ) {
                    return true
                }
                return false
            }?.coordinate)
            let restoredState = store.state
            let restoredTreasury = store.state.treasury

            store.selectTool(.commercial)
            store.selectedCoordinate = target
            store.primaryAction(at: target)
            XCTAssertNotEqual(store.state, restoredState)
            scene.render(
                state: store.state,
                overlay: store.overlay,
                selection: store.selectedCoordinate,
                interactionMode: store.interactionMode
            )

            store.undoLastAction()
            XCTAssertEqual(store.state, restoredState)
            XCTAssertEqual(store.state.treasury, restoredTreasury)
            XCTAssertNil(store.selectedCoordinate)
            scene.configureProofCamera(detail: .block, centeredOn: target)
            let staleCameraPosition = scene.cameraPositionForTesting

            XCTAssertTrue(store.perform(.toggleCityFocus))
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

            let expectedInsets = ContentView.mapViewportInsets(
                windowSize: testCase.size,
                compact: testCase.compact,
                chromeFrames: testCase.chrome
            )
            let expectedScene = CityScene(size: testCase.size)
            expectedScene.reducedMotion = true
            expectedScene.updateViewportInsets(expectedInsets)
            expectedScene.render(
                state: restoredState,
                overlay: store.overlay,
                selection: nil,
                interactionMode: store.interactionMode
            )
            expectedScene.frameCity()

            XCTAssertTrue(store.isCityFocusModeEnabled)
            XCTAssertNil(store.selectedCoordinate)
            XCTAssertNotEqual(scene.cameraPositionForTesting, staleCameraPosition)
            XCTAssertEqual(scene.cameraScale, expectedScene.cameraScale, accuracy: 0.000_001)
            XCTAssertEqual(
                scene.cameraPositionForTesting.x,
                expectedScene.cameraPositionForTesting.x,
                accuracy: 0.5
            )
            XCTAssertEqual(
                scene.cameraPositionForTesting.y,
                expectedScene.cameraPositionForTesting.y,
                accuracy: 0.5
            )
            XCTAssertEqual(
                scene.cameraPriorityCoordinatesForTesting,
                expectedScene.cameraPriorityCoordinatesForTesting,
                "Focus City must frame the restored snapshot's developed district"
            )
        }
    }

    @MainActor
    func testFocusCityPointerMonitorLifecyclePreservesTransitionGateAfterCompletedClick() throws {
        _ = NSApplication.shared
        let gate = CityMapPointerTransitionGate()
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let content = NSView(frame: window.contentView?.bounds ?? .zero)
        window.contentView = content
        window.orderFront(nil)
        let monitor = CityFocusPointerTransitionView(pointerTransitionGate: gate)
        monitor.frame = CGRect(x: 40, y: 40, width: 120, height: 44)
        let down = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 100, y: 62),
                modifierFlags: [],
                timestamp: 1,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )
        let up = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: NSPoint(x: 100, y: 62),
                modifierFlags: [],
                timestamp: 2,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 0
            )
        )

        content.addSubview(monitor)
        XCTAssertTrue(monitor.monitorIsInstalled)
        XCTAssertNil(
            monitor.hitTest(NSPoint(x: 60, y: 22)),
            "The AppKit boundary must not replace or cover the SwiftUI Button semantic action"
        )

        XCTAssertTrue(monitor.handleLocalPointerEvent(down) === down)
        XCTAssertTrue(gate.isActive)
        monitor.removeFromSuperview()
        XCTAssertFalse(monitor.monitorIsInstalled)
        XCTAssertFalse(gate.isActive)

        let completedMonitor = CityFocusPointerTransitionView(pointerTransitionGate: gate)
        completedMonitor.frame = monitor.frame
        content.addSubview(completedMonitor)
        XCTAssertTrue(completedMonitor.handleLocalPointerEvent(down) === down)
        XCTAssertTrue(completedMonitor.handleLocalPointerEvent(up) === up)
        completedMonitor.removeFromSuperview()
        XCTAssertTrue(
            gate.isActive,
            "SwiftUI replacing the originating control after its click must not reopen the map"
        )
        gate.cancel()
        window.orderOut(nil)
    }

    @MainActor
    func testFocusCityPointerTransitionGateIgnoresZeroDeltaAndClearsAfterRealMovement() async throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.orderFront(nil)

        func mouseEvent(
            _ type: NSEvent.EventType,
            location: NSPoint,
            eventNumber: Int
        ) throws -> NSEvent {
            try XCTUnwrap(
                NSEvent.mouseEvent(
                    with: type,
                    location: location,
                    modifierFlags: [],
                    timestamp: TimeInterval(eventNumber),
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: eventNumber,
                    clickCount: 1,
                    pressure: type == .leftMouseUp ? 0 : 1
                )
            )
        }

        let gate = CityMapPointerTransitionGate()
        let anchor = NSPoint(x: 100, y: 62)
        gate.begin(window: window, anchor: anchor)
        XCTAssertTrue(gate.isActive)
        XCTAssertTrue(gate.blocksPointerInput(in: window))

        XCTAssertFalse(
            gate.observeMovement(try mouseEvent(.mouseMoved, location: anchor, eventNumber: 1))
        )
        XCTAssertTrue(gate.isActive, "Synthetic hover at the stationary anchor must not reopen the map")

        let threshold = CityMapPointerTransitionGate.movementThreshold
        XCTAssertFalse(
            gate.observeMovement(
                try mouseEvent(
                    .mouseMoved,
                    location: NSPoint(x: anchor.x + threshold, y: anchor.y),
                    eventNumber: 2
                )
            )
        )
        XCTAssertTrue(gate.isActive, "Only movement exceeding the fixed threshold may reopen the map")

        XCTAssertTrue(
            gate.observeMovement(
                try mouseEvent(
                    .mouseMoved,
                    location: NSPoint(x: anchor.x + threshold + 0.5, y: anchor.y),
                    eventNumber: 3
                )
            )
        )
        XCTAssertFalse(gate.isActive)
        XCTAssertFalse(gate.blocksPointerInput(in: window))

        gate.begin(window: window, anchor: anchor)
        XCTAssertTrue(gate.isActive)
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: window)
        await Task.yield()
        XCTAssertFalse(gate.isActive, "Window removal must safely cancel the transition gate")
        window.orderOut(nil)
    }

    @MainActor
    func testCompactCatalogPointerSelectionQuarantinesEveryMapBridgeUntilIntentionalMovement() throws {
        _ = NSApplication.shared
        let contentWindow = NSWindow(
            contentRect: CGRect(x: 120, y: 140, width: 900, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let popupWindow = NSWindow(
            contentRect: CGRect(x: 420, y: 360, width: 240, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let mapView = CityMapSKView(frame: contentWindow.contentView?.bounds ?? .zero)
        contentWindow.contentView = mapView
        contentWindow.orderFront(nil)
        popupWindow.orderFront(nil)

        let gate = CityMapPointerTransitionGate()
        gate.bindCompactCatalogWindow(contentWindow)
        let store = CityGameStore(state: .newCity(seed: 42))
        store.clearFeedback()
        let coordinator = CitySceneView.Coordinator(
            store: store,
            pointerTransitionGate: gate
        )
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        let cameraCoordinate = GridCoordinate(x: 12, y: 12)
        scene.configureProofCamera(detail: .block, centeredOn: cameraCoordinate)
        coordinator.scene = scene

        let state = store.state
        let fingerprint = try CityStateFingerprinter.fingerprint(state).digest
        let treasury = store.state.treasury
        let undoAvailable = store.canUndo
        let cameraPosition = scene.cameraPositionForTesting
        let cameraScale = scene.cameraScaleForTesting
        let popupLocation = NSPoint(x: 72, y: 88)
        let pointerUp = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: popupLocation,
                modifierFlags: [],
                timestamp: 1,
                windowNumber: popupWindow.windowNumber,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 0
            )
        )
        let expectedAnchor = contentWindow.convertPoint(
            fromScreen: popupWindow.convertPoint(toScreen: popupLocation)
        )

        XCTAssertTrue(
            BuildToolbarView.performCompactCatalogSelection(
                .commercial,
                store: store,
                pointerTransitionGate: gate,
                event: pointerUp
            )
        )
        XCTAssertTrue(gate.isActive)
        XCTAssertEqual(gate.originatingWindowNumber, contentWindow.windowNumber)
        let gateAnchor = try XCTUnwrap(gate.anchor)
        XCTAssertEqual(gateAnchor.x, expectedAnchor.x, accuracy: 0.001)
        XCTAssertEqual(gateAnchor.y, expectedAnchor.y, accuracy: 0.001)
        XCTAssertEqual(store.interactionMode, .build(.commercial))
        XCTAssertEqual(store.selectedTool, .commercial)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state).digest, fingerprint)
        XCTAssertEqual(store.state.treasury, treasury)
        XCTAssertEqual(store.canUndo, undoAvailable)
        XCTAssertEqual(scene.cameraPositionForTesting, cameraPosition)
        XCTAssertEqual(scene.cameraScaleForTesting, cameraScale)

        let mapCoordinate = GridCoordinate(x: 19, y: 17)
        XCTAssertNil(coordinator.acceptPointerMapActionCandidate(mapCoordinate, in: mapView))
        XCTAssertFalse(coordinator.performPointerPrimaryAction(at: mapCoordinate, in: mapView))
        XCTAssertFalse(coordinator.performPointerSecondaryAction(at: mapCoordinate, in: mapView))
        XCTAssertNil(store.selectedCoordinate)

        let otherWindowMovement = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .mouseMoved,
                location: NSPoint(x: popupLocation.x + 40, y: popupLocation.y + 40),
                modifierFlags: [],
                timestamp: 2,
                windowNumber: popupWindow.windowNumber,
                context: nil,
                eventNumber: 2,
                clickCount: 0,
                pressure: 0
            )
        )
        XCTAssertFalse(gate.observeMovement(otherWindowMovement))
        XCTAssertTrue(gate.isActive, "Transient popup events must not reopen the map")

        let stationary = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .mouseMoved,
                location: expectedAnchor,
                modifierFlags: [],
                timestamp: 3,
                windowNumber: contentWindow.windowNumber,
                context: nil,
                eventNumber: 3,
                clickCount: 0,
                pressure: 0
            )
        )
        XCTAssertFalse(gate.observeMovement(stationary))
        XCTAssertTrue(gate.isActive)

        let intentionalMovement = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .mouseMoved,
                location: NSPoint(
                    x: expectedAnchor.x + CityMapPointerTransitionGate.movementThreshold + 1,
                    y: expectedAnchor.y
                ),
                modifierFlags: [],
                timestamp: 4,
                windowNumber: contentWindow.windowNumber,
                context: nil,
                eventNumber: 4,
                clickCount: 0,
                pressure: 0
            )
        )
        XCTAssertTrue(gate.observeMovement(intentionalMovement))
        XCTAssertFalse(gate.isActive)
        XCTAssertNotNil(coordinator.acceptPointerMapActionCandidate(mapCoordinate, in: mapView))
        XCTAssertEqual(store.selectedCoordinate, mapCoordinate)

        gate.cancel()
        popupWindow.orderOut(nil)
        contentWindow.orderOut(nil)
    }

    @MainActor
    func testCompactCatalogWindowBindingAndNonPointerRoutesRemainSemanticAndImmediate() throws {
        _ = NSApplication.shared
        let contentWindow = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let gate = CityMapPointerTransitionGate()
        let binding = CityBuildCatalogWindowBindingView(pointerTransitionGate: gate)
        binding.frame = CGRect(x: 40, y: 40, width: 120, height: 44)
        contentWindow.contentView?.addSubview(binding)
        contentWindow.orderFront(nil)
        XCTAssertNil(binding.hitTest(NSPoint(x: 60, y: 22)))

        let store = CityGameStore(state: .newCity(seed: 42))
        let keyboardEvent = try keyEvent(characters: "c", keyCode: 8)
        XCTAssertTrue(
            BuildToolbarView.performCompactCatalogSelection(
                .commercial,
                store: store,
                pointerTransitionGate: gate,
                event: keyboardEvent
            )
        )
        XCTAssertFalse(gate.isActive)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.interactionMode, .build(.commercial))

        XCTAssertTrue(
            BuildToolbarView.performCompactCatalogSelection(
                .industrial,
                store: store,
                pointerTransitionGate: gate,
                event: nil
            ),
            "FKA and accessibility activation remain on the semantic SwiftUI route"
        )
        XCTAssertFalse(gate.isActive)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.interactionMode, .build(.industrial))

        binding.removeFromSuperview()
        let pointerUp = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: .zero,
                modifierFlags: [],
                timestamp: 1,
                windowNumber: contentWindow.windowNumber,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 0
            )
        )
        XCTAssertFalse(gate.beginCompactCatalogSelection(event: pointerUp))
        contentWindow.orderOut(nil)
    }

    @MainActor
    func testFocusCityPointerMonitorCancelsDragOutAndPreservesEveryModeExactlyOnce() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let content = NSView(frame: window.contentView?.bounds ?? .zero)
        let mapView = CityMapSKView(frame: content.bounds)
        content.addSubview(mapView)
        window.contentView = content
        window.orderFront(nil)

        func mouseEvent(
            _ type: NSEvent.EventType,
            location: NSPoint,
            eventNumber: Int
        ) throws -> NSEvent {
            try XCTUnwrap(
                NSEvent.mouseEvent(
                    with: type,
                    location: location,
                    modifierFlags: [],
                    timestamp: TimeInterval(eventNumber),
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: eventNumber,
                    clickCount: 1,
                    pressure: type == .leftMouseUp ? 0 : 1
                )
            )
        }

        let inside = NSPoint(x: 100, y: 62)
        let outside = NSPoint(x: 260, y: 160)
        let mouseDownInside = try mouseEvent(.leftMouseDown, location: inside, eventNumber: 1)
        let mouseDraggedOutside = try mouseEvent(.leftMouseDragged, location: outside, eventNumber: 2)
        let mouseUpInside = try mouseEvent(.leftMouseUp, location: inside, eventNumber: 3)
        let mouseDownOutside = try mouseEvent(.leftMouseDown, location: outside, eventNumber: 4)

        for mode in [
            CityInteractionMode.inspect,
            .build(.commercial),
            .bulldoze
        ] {
            let store = CityGameStore(state: .newCity(seed: 42))
            store.interactionMode = mode
            store.selectedTool = .commercial
            store.selectedCoordinate = GridCoordinate(x: 11, y: 11)
            store.showObjectives = true
            store.showInspector = true
            let state = store.state
            let digest = try CityStateFingerprinter.fingerprint(state).digest
            let coordinate = try XCTUnwrap(store.selectedCoordinate)
            let target = try XCTUnwrap(store.activeMapActionTargetPresentation)
            let focusGeneration = store.mapFocusRequestGeneration
            let undoAvailable = store.canUndo
            let undoDepth = try XCTUnwrap(
                Mirror(reflecting: store).children.first { $0.label == "undoStates" }?.value
                    as? [CityGameState]
            ).count
            let treasury = store.state.treasury
            let gate = CityMapPointerTransitionGate()
            let coordinator = CitySceneView.Coordinator(
                store: store,
                pointerTransitionGate: gate
            )
            let scene = CityScene(size: CGSize(width: 320, height: 200))
            scene.configureProofCamera(detail: .block, centeredOn: coordinate)
            coordinator.scene = scene
            let cameraPosition = scene.cameraPositionForTesting
            let cameraScale = scene.cameraScaleForTesting

            let monitor = CityFocusPointerTransitionView(pointerTransitionGate: gate)
            monitor.frame = CGRect(x: 40, y: 40, width: 120, height: 44)
            content.addSubview(monitor)
            XCTAssertTrue(monitor.monitorIsInstalled)

            XCTAssertTrue(
                monitor.handleLocalPointerEvent(mouseDownOutside) === mouseDownOutside,
                "Pointer events beginning outside the exact control bounds must remain untouched"
            )

            XCTAssertTrue(monitor.handleLocalPointerEvent(mouseDownInside) === mouseDownInside)
            XCTAssertTrue(gate.isActive)
            XCTAssertTrue(monitor.handleLocalPointerEvent(mouseDraggedOutside) === mouseDraggedOutside)
            XCTAssertFalse(gate.isActive)
            XCTAssertTrue(monitor.handleLocalPointerEvent(mouseUpInside) === mouseUpInside)
            XCTAssertFalse(store.isCityFocusModeEnabled)

            XCTAssertTrue(monitor.handleLocalPointerEvent(mouseDownInside) === mouseDownInside)
            XCTAssertTrue(monitor.handleLocalPointerEvent(mouseUpInside) === mouseUpInside)
            XCTAssertTrue(gate.isActive)
            XCTAssertNil(coordinator.acceptPointerMapActionCandidate(GridCoordinate(x: 18, y: 14), in: mapView))
            XCTAssertFalse(coordinator.performPointerPrimaryAction(at: coordinate, in: mapView))
            XCTAssertFalse(coordinator.performPointerSecondaryAction(at: coordinate, in: mapView))
            XCTAssertTrue(store.perform(.toggleCityFocus), "The existing SwiftUI Button route executes once")
            XCTAssertTrue(store.isCityFocusModeEnabled)
            XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 1)

            XCTAssertFalse(
                gate.observeMovement(
                    try mouseEvent(.mouseMoved, location: inside, eventNumber: 5)
                )
            )
            XCTAssertTrue(gate.isActive)
            XCTAssertTrue(monitor.handleLocalPointerEvent(mouseDownInside) === mouseDownInside)
            XCTAssertTrue(monitor.handleLocalPointerEvent(mouseUpInside) === mouseUpInside)
            XCTAssertTrue(store.perform(.toggleCityFocus), "The existing SwiftUI Button exit route executes once")
            XCTAssertFalse(store.isCityFocusModeEnabled)
            XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 2)
            XCTAssertEqual(store.state, state)
            XCTAssertEqual(try CityStateFingerprinter.fingerprint(store.state).digest, digest)
            XCTAssertEqual(store.state.treasury, treasury)
            XCTAssertEqual(store.selectedCoordinate, coordinate)
            XCTAssertEqual(store.activeMapActionTargetPresentation, target)
            XCTAssertEqual(store.interactionMode, mode)
            XCTAssertEqual(store.selectedTool, .commercial)
            XCTAssertEqual(store.canUndo, undoAvailable)
            XCTAssertEqual(
                try XCTUnwrap(
                    Mirror(reflecting: store).children.first { $0.label == "undoStates" }?.value
                        as? [CityGameState]
                ).count,
                undoDepth
            )
            XCTAssertTrue(store.showInspector)
            XCTAssertTrue(store.showObjectives)
            XCTAssertEqual(scene.cameraPositionForTesting, cameraPosition)
            XCTAssertEqual(scene.cameraScaleForTesting, cameraScale)

            monitor.removeFromSuperview()
            XCTAssertFalse(monitor.monitorIsInstalled)
            XCTAssertTrue(gate.isActive, "Removing transitioned chrome must not reopen a stationary pointer")
            gate.cancel()
        }

        window.orderOut(nil)
    }

    @MainActor
    func testFocusCityPointerMonitorConsumesOnlyExactWindowSequence() throws {
        _ = NSApplication.shared
        let owningWindow = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let otherWindow = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let gate = CityMapPointerTransitionGate()
        let monitor = CityFocusPointerTransitionView(pointerTransitionGate: gate)
        monitor.frame = CGRect(x: 40, y: 40, width: 120, height: 44)
        owningWindow.contentView?.addSubview(monitor)
        owningWindow.orderFront(nil)
        otherWindow.orderFront(nil)

        let foreignDown = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: NSPoint(x: 100, y: 62),
                modifierFlags: [],
                timestamp: 1,
                windowNumber: otherWindow.windowNumber,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )
        XCTAssertTrue(monitor.handleLocalPointerEvent(foreignDown) === foreignDown)
        XCTAssertFalse(gate.isActive)

        let unrelatedRightDown = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: NSPoint(x: 100, y: 62),
                modifierFlags: [],
                timestamp: 2,
                windowNumber: owningWindow.windowNumber,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 1
            )
        )
        XCTAssertTrue(monitor.handleLocalPointerEvent(unrelatedRightDown) === unrelatedRightDown)
        XCTAssertFalse(gate.isActive, "The transition boundary must not own unrelated pointer input")

        gate.begin(window: owningWindow, anchor: NSPoint(x: 100, y: 62))
        XCTAssertTrue(gate.blocksPointerInput(in: owningWindow))
        XCTAssertFalse(gate.blocksPointerInput(in: otherWindow))
        XCTAssertFalse(gate.isActive, "A different map window must safely cancel the stale window-local gate")
        monitor.removeFromSuperview()
        owningWindow.orderOut(nil)
        otherWindow.orderOut(nil)
    }

    @MainActor
    func testFocusCityShortcutRespectsTextAndWelcomeQuarantine() throws {
        let shortcutEvent = try keyEvent(
            characters: "f",
            keyCode: 3,
            modifiers: [.command, .shift]
        )
        let textField = NSTextField(frame: CGRect(x: 0, y: 0, width: 180, height: 24))
        let nonText = FocusProbeView(frame: .zero)

        XCTAssertTrue(
            CityGameStore.shouldQuarantineCityFocusShortcut(
                firstResponder: textField,
                event: shortcutEvent
            )
        )
        XCTAssertFalse(
            CityGameStore.shouldQuarantineCityFocusShortcut(
                firstResponder: nonText,
                event: shortcutEvent
            )
        )
        XCTAssertFalse(
            CityGameStore.shouldQuarantineCityFocusShortcut(
                firstResponder: textField,
                event: try keyEvent(characters: "\r", keyCode: 36)
            )
        )

        let blocked = CityGameStore(
            state: .newCity(seed: 42),
            commandPolicy: .blocked(.welcome)
        )
        XCTAssertFalse(blocked.canPerform(.toggleCityFocus))
        XCTAssertFalse(blocked.perform(.toggleCityFocus))
        XCTAssertFalse(blocked.isCityFocusModeEnabled)
        XCTAssertEqual(
            blocked.disabledReason(for: .toggleCityFocus),
            "Finish Welcome to New Arcadia to use city commands"
        )
    }

    @MainActor
    func testExactCompactRetainsSemanticMapIdentityKeyboardSelectionAndEscapeFocus() throws {
        let defaults = UserDefaults.standard
        let priorWelcome = defaults.object(forKey: "hasSeenCitySimWelcome")
        defaults.set(true, forKey: "hasSeenCitySimWelcome")
        defer {
            if let priorWelcome { defaults.set(priorWelcome, forKey: "hasSeenCitySimWelcome") }
            else { defaults.removeObject(forKey: "hasSeenCitySimWelcome") }
        }

        let store = CityGameStore(state: .newCity(seed: 42))
        store.speed = .paused
        let size = CGSize(width: 900, height: 600)
        let host = NSHostingView(rootView: ContentView(store: store).frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        if store.commandPolicy == .blocked(.welcome) {
            XCTAssertTrue(store.dismissBlockingModal(.welcome))
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        let mapView = try XCTUnwrap(firstDescendant(of: CityMapSKView.self, in: host))
        XCTAssertEqual(mapView.accessibilityLabel(), "City map")
        XCTAssertEqual(mapView.accessibilityValue() as? String, "No block selected")
        XCTAssertEqual(mapView.accessibilityHelp(), CityMapSKView.defaultAccessibilityHelp)
        XCTAssertTrue(window.makeFirstResponder(mapView))

        let scene = try XCTUnwrap(mapView.scene as? CityScene)
        scene.keyDown(with: try keyEvent(characters: "", keyCode: 124))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let firstSelection = try XCTUnwrap(store.selectedCoordinate)
        XCTAssertTrue((mapView.accessibilityValue() as? String)?.contains("Selected") == true)
        XCTAssertFalse(mapView.accessibilityCustomActions()?.isEmpty ?? true)

        store.selectTool(.residential)
        store.clearFeedback()
        store.showObjectives = true
        store.showInspector = true
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        let recomposedMapView = try XCTUnwrap(firstDescendant(of: CityMapSKView.self, in: host))
        XCTAssertTrue(recomposedMapView === mapView, "Compact panel arbitration must not replace the semantic map view")
        XCTAssertEqual(recomposedMapView.accessibilityLabel(), "City map")
        XCTAssertTrue((recomposedMapView.accessibilityValue() as? String)?.contains("Selected") == true)
        XCTAssertFalse(recomposedMapView.accessibilityHelp()?.isEmpty ?? true)
        XCTAssertFalse(recomposedMapView.accessibilityCustomActions()?.isEmpty ?? true)

        scene.keyDown(with: try keyEvent(characters: "", keyCode: 124, modifiers: .shift))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(store.selectedCoordinate?.x, min(store.state.gridWidth - 1, firstSelection.x + 5))
        XCTAssertEqual(store.selectedCoordinate?.y, firstSelection.y)
        let shiftedSelection = store.selectedCoordinate
        let stateBeforeEscape = store.state
        let focusGeneration = store.mapFocusRequestGeneration
        let cameraScale = scene.cameraScale
        let cameraPosition = scene.camera?.position

        XCTAssertTrue(store.perform(.toggleCityFocus))
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let focusedMapView = try XCTUnwrap(firstDescendant(of: CityMapSKView.self, in: host))
        XCTAssertTrue(focusedMapView === mapView, "Focus City must retain the semantic map instance")
        XCTAssertTrue(store.isCityFocusModeEnabled)
        XCTAssertTrue(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, shiftedSelection)
        XCTAssertEqual(store.state, stateBeforeEscape)
        XCTAssertEqual(scene.cameraScale, cameraScale, accuracy: 0.000_001)
        XCTAssertEqual(scene.camera?.position, cameraPosition)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 1)

        scene.keyDown(with: try keyEvent(characters: "\u{1b}", keyCode: 53))
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertFalse(store.isCityFocusModeEnabled)
        XCTAssertTrue(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, shiftedSelection)
        XCTAssertEqual(store.state, stateBeforeEscape)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 2)
        XCTAssertTrue(window.firstResponder === mapView)

        scene.keyDown(with: try keyEvent(characters: "\u{1b}", keyCode: 53))
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertFalse(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, shiftedSelection)
        XCTAssertEqual(store.state, stateBeforeEscape)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 3)
        XCTAssertTrue(window.firstResponder === mapView)

        scene.keyDown(with: try keyEvent(characters: "\u{1b}", keyCode: 53))
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertFalse(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, shiftedSelection)
        XCTAssertEqual(store.state, stateBeforeEscape)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 4)
        XCTAssertTrue(window.firstResponder === mapView)
    }

    @MainActor
    func testSemanticMapHandsTabAndShiftTabToFullKeyboardAccessLoop() throws {
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let mapView = CityMapSKView(frame: content.bounds)
        let focusProbe = FocusProbeView(frame: .zero)
        content.addSubview(mapView)
        content.addSubview(focusProbe)
        mapView.nextKeyView = focusProbe
        focusProbe.nextKeyView = mapView

        let window = NSWindow(
            contentRect: content.bounds,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = content

        XCTAssertTrue(window.makeFirstResponder(mapView))
        mapView.keyDown(with: try keyEvent(characters: "\t", keyCode: 48))
        XCTAssertTrue(window.firstResponder === focusProbe)

        XCTAssertTrue(window.makeFirstResponder(mapView))
        mapView.keyDown(with: try keyEvent(characters: "\t", keyCode: 48, modifiers: .shift))
        XCTAssertTrue(window.firstResponder === focusProbe)
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
        scene.allowsCommand = { store.canRouteMapCommand($0) }
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
    func testFocusedReturnRoutesOneRejectedAttemptButTextAndWelcomeRemainQuarantined() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let occupied = try XCTUnwrap(store.state.tiles.first { $0.kind != .empty })
        let valid = try XCTUnwrap(store.state.tiles.first { tile in
            if case .success = CitySimulation.validateBuild(.commercial, at: tile.coordinate, in: store.state) {
                return true
            }
            return false
        })
        store.selectTool(.commercial)
        store.selectedCoordinate = occupied.coordinate
        store.clearFeedback()

        let scene = CityScene(size: CGSize(width: 900, height: 600))
        let mapView = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        mapView.presentScene(scene)
        let textField = NSTextField(frame: CGRect(x: 10, y: 10, width: 180, height: 24))
        let contentView = NSView(frame: mapView.frame)
        contentView.addSubview(mapView)
        contentView.addSubview(textField)
        let window = NSWindow(contentRect: mapView.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = contentView
        var routed: [CityCommandID] = []
        scene.allowsCommand = { store.canRouteMapCommand($0) }
        scene.onCommandAction = {
            routed.append($0)
            store.performMapCommand($0)
        }

        XCTAssertTrue(window.makeFirstResponder(textField))
        scene.keyDown(with: try keyEvent(characters: "\r", keyCode: 36))
        XCTAssertEqual(routed, [])
        XCTAssertNil(store.lastFeedback)

        XCTAssertTrue(window.makeFirstResponder(mapView))
        store.presentBlockingModal(.welcome)
        scene.keyDown(with: try keyEvent(characters: "\r", keyCode: 36))
        XCTAssertEqual(routed, [])
        XCTAssertNil(store.lastFeedback)

        XCTAssertTrue(store.dismissBlockingModal(.welcome))
        let rejectedState = store.state
        scene.keyDown(with: try keyEvent(characters: "\r", keyCode: 36))
        XCTAssertEqual(routed, [.mapPrimaryAction])
        XCTAssertEqual(store.state, rejectedState)
        XCTAssertEqual(store.selectedCoordinate, occupied.coordinate)
        XCTAssertEqual(store.lastFeedback, "\(BuildRejection.occupied.message) Commercial remains selected — choose another block.")

        store.clearFeedback()
        store.selectedCoordinate = valid.coordinate
        let treasuryBeforeValidBuild = store.state.treasury
        scene.keyDown(with: try keyEvent(characters: "\r", keyCode: 36))
        XCTAssertEqual(routed, [.mapPrimaryAction, .mapPrimaryAction])
        XCTAssertEqual(store.state.tile(at: valid.coordinate)?.kind, .commercial)
        XCTAssertEqual(store.state.treasury, treasuryBeforeValidBuild - BuildingKind.commercial.buildCost)
        XCTAssertTrue(store.canUndo)
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
    func testOneActiveMapActionTargetAlternatesPointerKeyboardAndAccessibilityTruth() throws {
        let authored = CityGameState.newCity(seed: 42)
        let occupied = try XCTUnwrap(authored.tiles.first { $0.kind != .empty })
        let roadless = try XCTUnwrap(authored.tiles.first { tile in
            guard tile.kind == .empty else { return false }
            if case .failure(.roadAccessRequired) = CitySimulation.validateBuild(
                .commercial,
                at: tile.coordinate,
                in: authored
            ) {
                return true
            }
            return false
        })
        let valid = try XCTUnwrap(authored.tiles.first { tile in
            if case .success = CitySimulation.validateBuild(.commercial, at: tile.coordinate, in: authored) {
                return true
            }
            return false
        })
        let store = CityGameStore(state: authored)
        store.selectTool(.commercial)
        store.clearFeedback()
        store.selectedCoordinate = valid.coordinate

        let scene = CityScene(size: CGSize(width: 900, height: 600))
        scene.onActiveActionTargetCandidate = { store.acceptPointerMapActionCandidate($0) }
        scene.render(
            state: store.state,
            overlay: .none,
            selection: store.selectedCoordinate,
            interactionMode: store.interactionMode,
            activeActionTarget: store.activeMapActionTargetPresentation
        )

        scene.configureProofInteraction(at: occupied.coordinate)
        XCTAssertEqual(store.selectedCoordinate, occupied.coordinate)
        XCTAssertEqual(scene.activeActionTargetForTesting?.coordinate, occupied.coordinate)
        XCTAssertEqual(
            scene.activeActionTargetForTesting?.primaryAction,
            store.activeMapActionTargetPresentation?.primaryAction
        )
        XCTAssertTrue(
            scene.activeActionTargetForTesting?.primaryAction.disclosure.contains(
                BuildRejection.occupied.message
            ) == true
        )
        XCTAssertTrue(scene.interactionNamesForTesting.contains("interaction.invalidHatch"))

        store.selectedCoordinate = valid.coordinate
        scene.render(
            state: store.state,
            overlay: .none,
            selection: store.selectedCoordinate,
            interactionMode: store.interactionMode,
            activeActionTarget: store.activeMapActionTargetPresentation
        )
        XCTAssertEqual(scene.activeActionTargetForTesting?.coordinate, valid.coordinate)
        XCTAssertTrue(scene.activeActionTargetForTesting?.primaryAction.isAvailable == true)
        XCTAssertFalse(scene.interactionNamesForTesting.contains("interaction.invalidHatch"))

        scene.configureProofInteraction(at: roadless.coordinate)
        XCTAssertEqual(store.selectedCoordinate, roadless.coordinate)
        XCTAssertEqual(scene.activeActionTargetForTesting?.coordinate, roadless.coordinate)
        XCTAssertTrue(
            scene.activeActionTargetForTesting?.primaryAction.disclosure.contains(
                BuildRejection.roadAccessRequired.message
            ) == true
        )

        var unaffordableState = authored
        unaffordableState.treasury = 0
        let unaffordableStore = CityGameStore(state: unaffordableState)
        unaffordableStore.selectTool(.commercial)
        unaffordableStore.clearFeedback()
        let unaffordable = try XCTUnwrap(
            unaffordableStore.acceptPointerMapActionCandidate(valid.coordinate)
        )
        XCTAssertFalse(unaffordable.primaryAction.isAvailable)
        XCTAssertTrue(
            unaffordable.primaryAction.disclosure.contains(
                BuildRejection.insufficientFunds.message
            )
        )

        let pointerSelection = store.selectedCoordinate
        store.presentBlockingModal(.welcome)
        XCTAssertNil(store.acceptPointerMapActionCandidate(valid.coordinate))
        XCTAssertEqual(store.selectedCoordinate, pointerSelection)
        XCTAssertTrue(store.dismissBlockingModal(.welcome))
        store.activateInspectMode()
        store.clearFeedback()
        XCTAssertNil(store.acceptPointerMapActionCandidate(valid.coordinate))
        XCTAssertEqual(store.selectedCoordinate, pointerSelection, "Inspect hover must remain non-selecting")
    }

    @MainActor
    func testPointerClickAndAXUseOneStoreCommandAndMutateValidTargetExactlyOnce() throws {
        let authored = CityGameState.newCity(seed: 42)
        let valid = try XCTUnwrap(authored.tiles.first { tile in
            if case .success = CitySimulation.validateBuild(.commercial, at: tile.coordinate, in: authored) {
                return true
            }
            return false
        })
        let pointerStore = CityGameStore(state: authored)
        pointerStore.selectTool(.commercial)
        pointerStore.clearFeedback()
        let pointerScene = CityScene(size: CGSize(width: 900, height: 600))
        var pointerDispatchCount = 0
        pointerScene.onActiveActionTargetCandidate = {
            pointerStore.acceptPointerMapActionCandidate($0)
        }
        pointerScene.onPrimaryAction = { coordinate in
            guard pointerStore.selectedCoordinate == coordinate else { return }
            pointerDispatchCount += 1
            pointerStore.performMapCommand(.mapPrimaryAction)
        }
        pointerScene.render(
            state: pointerStore.state,
            overlay: .none,
            selection: pointerStore.selectedCoordinate,
            interactionMode: pointerStore.interactionMode,
            activeActionTarget: pointerStore.activeMapActionTargetPresentation
        )
        let pointerTreasury = pointerStore.state.treasury

        pointerScene.activatePrimaryActionForTesting(at: valid.coordinate)

        XCTAssertEqual(pointerDispatchCount, 1)
        XCTAssertEqual(pointerStore.selectedCoordinate, valid.coordinate)
        XCTAssertEqual(pointerStore.state.tile(at: valid.coordinate)?.kind, .commercial)
        XCTAssertEqual(pointerStore.state.treasury, pointerTreasury - BuildingKind.commercial.buildCost)

        let accessibilityStore = CityGameStore(state: authored)
        accessibilityStore.selectTool(.commercial)
        accessibilityStore.clearFeedback()
        accessibilityStore.selectedCoordinate = valid.coordinate
        let coordinator = CitySceneView.Coordinator(store: accessibilityStore)
        let mapView = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        coordinator.configureMapAccessibility(in: mapView)
        let action = try XCTUnwrap(mapView.accessibilityCustomActions()?.first)
        let accessibilityTreasury = accessibilityStore.state.treasury

        XCTAssertTrue(action.handler?() == true)
        XCTAssertEqual(accessibilityStore.state.tile(at: valid.coordinate)?.kind, .commercial)
        XCTAssertEqual(
            accessibilityStore.state.treasury,
            accessibilityTreasury - BuildingKind.commercial.buildCost
        )
    }

    @MainActor
    func testBlockedTargetBecomesAvailableAfterOneAuthoritativeRoadChange() throws {
        var state = CityGameState.newCity(seed: 42)
        let pair = try XCTUnwrap(state.tiles.lazy.compactMap { target -> (CityTile, CityTile)? in
            guard target.kind == .empty,
                  case .failure(.roadAccessRequired) = CitySimulation.validateBuild(
                    .commercial,
                    at: target.coordinate,
                    in: state
                  ),
                  let road = state.neighbors(of: target.coordinate).first(where: { $0.kind == .empty })
            else { return nil }
            return (target, road)
        }.first)
        let store = CityGameStore(state: state)
        store.selectTool(.commercial)
        store.clearFeedback()

        let blocked = try XCTUnwrap(store.acceptPointerMapActionCandidate(pair.0.coordinate))
        XCTAssertFalse(blocked.primaryAction.isAvailable)
        XCTAssertTrue(blocked.primaryAction.disclosure.contains(BuildRejection.roadAccessRequired.message))

        guard case .success = CitySimulation.build(.road, at: pair.1.coordinate, in: &state) else {
            XCTFail("The adjacent road fixture must be buildable")
            return
        }
        store.state = state
        let connected = try XCTUnwrap(store.activeMapActionTargetPresentation)
        XCTAssertEqual(connected.coordinate, pair.0.coordinate)
        XCTAssertTrue(connected.primaryAction.isAvailable)
        let treasuryBefore = store.state.treasury

        XCTAssertTrue(store.performMapCommand(.mapPrimaryAction))
        XCTAssertEqual(store.state.tile(at: pair.0.coordinate)?.kind, .commercial)
        XCTAssertEqual(store.state.treasury, treasuryBefore - BuildingKind.commercial.buildCost)
    }

    @MainActor
    func testPointerCandidateBridgeQuarantinesTextFocus() {
        let store = CityGameStore(state: .newCity(seed: 42))
        store.selectTool(.commercial)
        let coordinator = CitySceneView.Coordinator(store: store)
        let mapView = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let textField = NSTextField(frame: CGRect(x: 10, y: 10, width: 180, height: 24))
        let content = NSView(frame: mapView.frame)
        content.addSubview(mapView)
        content.addSubview(textField)
        let window = NSWindow(
            contentRect: mapView.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = content

        XCTAssertTrue(window.makeFirstResponder(textField))
        XCTAssertFalse(coordinator.allowsPointerMapActionCandidate(in: mapView))
        XCTAssertTrue(window.makeFirstResponder(mapView))
        XCTAssertTrue(coordinator.allowsPointerMapActionCandidate(in: mapView))
    }

    @MainActor
    func testApprovedRemedyRequestsOneLifecycleSafeMapFocus() {
        let store = CityGameStore(state: .newCity(seed: 42))
        var queuedActions: [CitySceneView.Coordinator.MainLoopAction] = []
        let coordinator = CitySceneView.Coordinator(store: store) { queuedActions.append($0) }
        let mapView = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
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
    func testBuildDecisionPresentsEveryCommitFactAndRoutesOneTruthfulRecovery() throws {
        let authored = CityGameState.newCity(seed: 42)
        let occupied = try XCTUnwrap(authored.tiles.first { $0.kind != .empty })
        let roadless = try XCTUnwrap(authored.tiles.first { tile in
            guard tile.kind == .empty else { return false }
            if case .failure(.roadAccessRequired) = CitySimulation.validateBuild(
                .residential,
                at: tile.coordinate,
                in: authored
            ) {
                return true
            }
            return false
        })
        let valid = try XCTUnwrap(authored.tiles.first { tile in
            guard tile.kind == .empty else { return false }
            if case .success = CitySimulation.validateBuild(.residential, at: tile.coordinate, in: authored) {
                return true
            }
            return false
        })

        for kind in BuildingKind.buildPalette {
            let decision = try XCTUnwrap(
                CityMapPrimaryActionPresentation.make(
                    interactionMode: .build(kind),
                    tile: occupied,
                    state: authored
                ).buildDecision
            )
            XCTAssertEqual(decision.target, "Block \(occupied.coordinate.x + 1), \(occupied.coordinate.y + 1)")
            XCTAssertEqual(decision.footprint, "1 × 1 block")
            XCTAssertTrue(decision.cost.contains(kind.buildCost.currencyText))
            XCTAssertTrue(decision.cost.contains(kind.upkeep.currencyText))
            XCTAssertFalse(decision.likelyConsequence.isEmpty)
            XCTAssertTrue(decision.cancellation.contains("Escape"))
            XCTAssertTrue(decision.accessibilitySummary.contains("Likely consequence"))
            XCTAssertTrue(decision.accessibilitySummary.contains("without changing the city"))
        }

        let validDecision = try XCTUnwrap(
            CityMapPrimaryActionPresentation.make(
                interactionMode: .build(.residential),
                tile: valid,
                state: authored
            ).buildDecision
        )
        XCTAssertEqual(validDecision.availability, "Ready to build")
        XCTAssertNil(validDecision.disabledReason)
        XCTAssertNil(validDecision.recovery)
        XCTAssertTrue(validDecision.likelyConsequence.contains("280 homes"))

        let roadDecision = try XCTUnwrap(
            CityMapPrimaryActionPresentation.make(
                interactionMode: .build(.residential),
                tile: roadless,
                state: authored
            ).buildDecision
        )
        XCTAssertEqual(roadDecision.availability, "Blocked")
        XCTAssertEqual(roadDecision.disabledReason, BuildRejection.roadAccessRequired.message)
        XCTAssertEqual(roadDecision.recovery?.command, .buildRoad)
        XCTAssertTrue(roadDecision.recovery?.focusesMap == true)

        let roadRecovery = CityGameStore(state: authored)
        roadRecovery.selectTool(.residential)
        roadRecovery.selectedCoordinate = roadless.coordinate
        roadRecovery.hudContextScope = .selection
        roadRecovery.clearFeedback()
        let roadRecoveryState = roadRecovery.state
        let roadRecoveryFocus = roadRecovery.mapFocusRequestGeneration
        XCTAssertTrue(roadRecovery.performMapFocused(try XCTUnwrap(roadDecision.recovery?.command)))
        XCTAssertEqual(roadRecovery.interactionMode, .build(.road))
        XCTAssertEqual(roadRecovery.selectedTool, .road)
        XCTAssertEqual(roadRecovery.selectedCoordinate, roadless.coordinate)
        XCTAssertEqual(roadRecovery.hudContextScope, .selection)
        XCTAssertEqual(roadRecovery.state, roadRecoveryState)
        XCTAssertEqual(roadRecovery.mapFocusRequestGeneration, roadRecoveryFocus + 1)

        let occupiedDecision = try XCTUnwrap(
            CityMapPrimaryActionPresentation.make(
                interactionMode: .build(.residential),
                tile: occupied,
                state: authored
            ).buildDecision
        )
        XCTAssertEqual(occupiedDecision.recovery?.command, .bulldozeMode)
        let occupiedRecovery = CityGameStore(state: authored)
        occupiedRecovery.selectTool(.residential)
        occupiedRecovery.selectedCoordinate = occupied.coordinate
        occupiedRecovery.clearFeedback()
        let occupiedState = occupiedRecovery.state
        XCTAssertTrue(occupiedRecovery.performMapFocused(try XCTUnwrap(occupiedDecision.recovery?.command)))
        XCTAssertEqual(occupiedRecovery.interactionMode, .bulldoze)
        XCTAssertEqual(occupiedRecovery.selectedCoordinate, occupied.coordinate)
        XCTAssertEqual(occupiedRecovery.state, occupiedState)

        var unfunded = authored
        unfunded.treasury = 0
        let unfundedDecision = try XCTUnwrap(
            CityMapPrimaryActionPresentation.make(
                interactionMode: .build(.residential),
                tile: valid,
                state: unfunded
            ).buildDecision
        )
        XCTAssertEqual(unfundedDecision.disabledReason, BuildRejection.insufficientFunds.message)
        XCTAssertEqual(unfundedDecision.recovery?.command, .inspectorFinances)
        XCTAssertFalse(unfundedDecision.recovery?.focusesMap ?? true)

        XCTAssertEqual(
            BuildToolbarView.closedMaximumHeight(
                compact: true,
                isBuildMode: true,
                hasBuildDecision: true
            ),
            BuildToolbarView.compactBuildDecisionMaximumHeight
        )
    }

    @MainActor
    func testBuildDecisionCommitUsesTheExistingPrimaryMapIntentExactlyOnce() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        let valid = try XCTUnwrap(store.state.tiles.first { tile in
            guard tile.kind == .empty else { return false }
            if case .success = CitySimulation.validateBuild(.commercial, at: tile.coordinate, in: store.state) {
                return true
            }
            return false
        })
        store.selectTool(.commercial)
        store.selectedCoordinate = valid.coordinate
        store.hudContextScope = .selection
        store.clearFeedback()
        let stateBefore = store.state
        let treasuryBefore = store.state.treasury

        XCTAssertTrue(store.canPerformMapCommand(.mapPrimaryAction))
        XCTAssertTrue(store.performMapCommand(.mapPrimaryAction))
        XCTAssertEqual(store.state.tile(at: valid.coordinate)?.kind, .commercial)
        XCTAssertEqual(store.state.treasury, treasuryBefore - BuildingKind.commercial.buildCost)
        XCTAssertEqual(store.selectedCoordinate, valid.coordinate)
        XCTAssertEqual(store.interactionMode, .build(.commercial))
        XCTAssertTrue(store.canUndo)

        XCTAssertTrue(store.perform(.undo))
        XCTAssertEqual(store.state, stateBefore)
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
            "Severe Storm", "Storefront Slump", "Utility Reserve Tight", "Utility Shortfall",
            "Regional Retail Challenge", "Regional Retail Pressure",
            "Regional Grid Mandate", "Regional Freight Overload"
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

        for title in ["Regional Retail Challenge", "Regional Retail Pressure"] {
            XCTAssertEqual(
                Set(CityNoticeActionCatalog.actions(for: title).map(\.command)),
                Set([.inspectorFinances, .buildPark])
            )
        }
        for title in ["Regional Grid Mandate", "Regional Freight Overload"] {
            XCTAssertEqual(
                Set(CityNoticeActionCatalog.actions(for: title).map(\.command)),
                Set([.buildPowerPlant, .buildWaterTower, .buildPark])
            )
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
    func testStrategyCommandCenterRendersAtDefaultAndExactCompactSizes() throws {
        let state = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .commercialStewardship
                    && $0.definition.moment == .complication
            }?.state
        )
        let store = CityGameStore(state: state)
        let compactSize = CGSize(width: 884, height: StrategyCommandCenterView.compactMaximumHeight)
        let compact = try bitmap(
            of: StrategyCommandCenterView(store: store, compact: true)
                .frame(width: compactSize.width, height: compactSize.height),
            size: compactSize
        )
        let regularSize = CGSize(width: 1_240, height: StrategyCommandCenterView.regularMaximumHeight)
        let regular = try bitmap(
            of: StrategyCommandCenterView(store: store, compact: false)
                .frame(width: regularSize.width, height: regularSize.height),
            size: regularSize
        )

        XCTAssertEqual(compact.size.width, compactSize.width, accuracy: 0.5)
        XCTAssertEqual(compact.size.height, compactSize.height, accuracy: 0.5)
        XCTAssertEqual(regular.size.width, regularSize.width, accuracy: 0.5)
        XCTAssertEqual(regular.size.height, regularSize.height, accuracy: 0.5)

        if let path = ProcessInfo.processInfo.environment["CITYSIM_STRATEGY_HUD_PROOF"] {
            let data = try XCTUnwrap(compact.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @MainActor
    func testCompactOverviewAndJournalRenderUsefulDecisionRowsWithinOpenDeckBudget() throws {
        let state = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .industrialExpansion
                    && $0.definition.moment == .complication
            }?.state
        )
        let store = CityGameStore(state: state)
        store.openInspector(.overview)
        let size = CGSize(width: 854, height: BuildToolbarView.compactDetailsMaxHeight)

        let overview = try bitmap(
            of: InspectorView(store: store, compact: true)
                .frame(width: size.width, height: size.height, alignment: .top),
            size: size
        )
        XCTAssertEqual(overview.size.height, BuildToolbarView.compactDetailsMaxHeight, accuracy: 0.5)
        XCTAssertEqual(InspectorView.compactColumnCount, 2)

        store.openInspector(.journal)
        let journal = try bitmap(
            of: InspectorView(store: store, compact: true)
                .frame(width: size.width, height: size.height, alignment: .top),
            size: size
        )
        XCTAssertEqual(journal.size.height, BuildToolbarView.compactDetailsMaxHeight, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(store.messageSummaries.count, InspectorView.compactMinimumVisibleNoticeCount)
        XCTAssertTrue(store.messageSummaries.prefix(2).allSatisfy { !$0.message.detail.isEmpty })
        XCTAssertTrue(
            store.messageSummaries.prefix(2).allSatisfy {
                CityNoticeActionCatalog.governedTitles.contains($0.message.title)
                    || CityNoticeActionCatalog.actions(for: $0.message.title).isEmpty
            }
        )
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

    @MainActor
    private func firstDescendant<ViewType: NSView>(
        of type: ViewType.Type,
        in root: NSView
    ) -> ViewType? {
        if let match = root as? ViewType { return match }
        for child in root.subviews {
            if let match = firstDescendant(of: type, in: child) { return match }
        }
        return nil
    }

    private func authoredSimulationSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/CitySimNative/Services/CitySimulation.swift")
    }
}
