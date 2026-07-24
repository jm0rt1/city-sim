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
        XCTAssertTrue(CityCommandCatalog.descriptor(for: .inspectorFinances).title.contains("Tax Policy"))
    }

    func testStrategyHUDConsumesEveryFrozenStoryMomentFromAuthoritativeAnalytics() throws {
        let fixtures = try ProductionStoryStateBuilder().buildAll()
        XCTAssertEqual(fixtures.count, 8)

        for fixture in fixtures {
            let presentation = CityStrategyHUDPresentation.make(
                analytics: CityAnalytics(state: fixture.state)
            )

            switch fixture.definition.moment {
            case .opening:
                XCTAssertEqual(presentation.tone, .active, fixture.definition.id)
                XCTAssertEqual(presentation.status, "OPPORTUNITY · 16 DAYS", fixture.definition.id)
                XCTAssertFalse(presentation.actions.isEmpty, fixture.definition.id)
            case .complication:
                XCTAssertEqual(presentation.tone, .active, fixture.definition.id)
                XCTAssertEqual(presentation.status, "DECISION WINDOW · 16 DAYS", fixture.definition.id)
                XCTAssertFalse(presentation.actions.isEmpty, fixture.definition.id)
            case .recovery:
                XCTAssertEqual(presentation.tone, .recovery, fixture.definition.id)
                XCTAssertEqual(presentation.status, "REVIEW · 16 DAYS", fixture.definition.id)
                XCTAssertTrue(presentation.title.contains("locked in"), fixture.definition.id)
                XCTAssertTrue(presentation.actions.isEmpty, fixture.definition.id)
            case .charterVictory:
                XCTAssertEqual(presentation.tone, .resolved, fixture.definition.id)
                XCTAssertEqual(presentation.status, "STORY COMPLETE", fixture.definition.id)
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
        store.perform(.openCommandGuide)
        let focusGeneration = store.mapFocusRequestGeneration

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showCommandGuide)
        XCTAssertTrue(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 1)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 2)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 2)
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

        scene.keyDown(with: try keyEvent(characters: "\u{1b}", keyCode: 53))
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertFalse(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, shiftedSelection)
        XCTAssertEqual(store.state, stateBeforeEscape)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 1)
        XCTAssertTrue(window.firstResponder === mapView)

        scene.keyDown(with: try keyEvent(characters: "\u{1b}", keyCode: 53))
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertFalse(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, shiftedSelection)
        XCTAssertEqual(store.state, stateBeforeEscape)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 2)
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
    func testStrategyCommandCenterRendersAtDefaultAndExactCompactSizes() throws {
        let state = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .commercialStewardship
                    && $0.definition.moment == .complication
            }?.state
        )
        let store = CityGameStore(state: state)
        let compactSize = CGSize(width: 390, height: StrategyCommandCenterView.compactMaximumHeight)
        let compact = try bitmap(
            of: StrategyCommandCenterView(store: store, compact: true)
                .frame(width: compactSize.width, height: compactSize.height),
            size: compactSize
        )
        let regularSize = CGSize(width: 430, height: 124)
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
