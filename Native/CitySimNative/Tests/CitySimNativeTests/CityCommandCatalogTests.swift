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
    func testUtilityDecisionSupportNamesTheConstraintAndPrioritizesItsProject() throws {
        var state = CityGameState.newCity(seed: 42)
        state.powerUsed = state.powerCapacity + 18
        state.waterUsed = state.waterCapacity - 40
        let analytics = CityAnalytics(state: state)
        let support = CityUtilityDecisionSupport.make(analytics: analytics)

        XCTAssertEqual(support.status, .shortfall)
        XCTAssertEqual(support.priorityKind, .powerPlant)
        XCTAssertEqual(support.title, "Power shortfall")
        XCTAssertTrue(support.detail.contains("short by 18"))
        XCTAssertTrue(support.detail.contains("Water still has 40 spare"))
        XCTAssertEqual(support.response?.command, .buildPowerPlant)

        let actions = CityNoticeActionCatalog.actions(
            for: "Utility Shortfall",
            analytics: analytics
        )
        XCTAssertEqual(actions.first?.command, .buildPowerPlant)
        XCTAssertEqual(actions.filter { $0.command == .buildPowerPlant }.count, 1)
        XCTAssertTrue(actions.contains { $0.command == .overlayUtilities })
        XCTAssertTrue(actions.contains { $0.command == .buildWaterTower })

        state.powerUsed = state.powerCapacity - 30
        state.waterUsed = state.waterCapacity + 12
        let waterSupport = CityUtilityDecisionSupport.make(
            analytics: CityAnalytics(state: state)
        )
        XCTAssertEqual(waterSupport.priorityKind, .waterTower)
        XCTAssertEqual(waterSupport.response?.command, .buildWaterTower)
    }

    @MainActor
    func testUrgentUtilityRemedyPausesAndTargetsAReadyParcel() throws {
        var state = CityGameState.newCity(seed: 42)
        state.powerUsed = state.powerCapacity + 18
        let store = CityGameStore(state: state)
        store.speed = .fastest
        let response = try XCTUnwrap(
            CityNoticeActionCatalog.actions(
                for: "Utility Shortfall",
                analytics: store.analytics
            ).first
        )

        StrategyCommandCenterView.perform(response, on: store)

        XCTAssertEqual(response.command, .buildPowerPlant)
        XCTAssertEqual(store.interactionMode, .build(.powerPlant))
        XCTAssertEqual(store.speed, .paused)
        let target = try XCTUnwrap(store.selectedCoordinate)
        if case .failure(let rejection) = CitySimulation.validateBuild(
            .powerPlant,
            at: target,
            in: store.state
        ) {
            XCTFail("Urgent utility remedy selected a blocked parcel: \(rejection)")
        }
        store.togglePause()
        XCTAssertEqual(store.speed, .fastest)
    }

    @MainActor
    func testUtilityAlertOpensLiveDiagnosisAndProtectsDecisionTime() {
        let message = CityMessage(
            tick: 80,
            severity: .critical,
            title: "Utility Shortfall",
            detail: "Power is short by 18."
        )
        var state = CityGameState.newCity(seed: 42)
        state.messages = [message]
        let store = CityGameStore(state: state)
        store.speed = .fastest

        store.openMessage(message)

        XCTAssertEqual(store.overlay, .utilities)
        XCTAssertTrue(store.showInspector)
        XCTAssertEqual(store.inspectorSection, .utilities)
        XCTAssertEqual(store.speed, .paused)
        store.togglePause()
        XCTAssertEqual(store.speed, .fastest)

        let consequence = HUDConsequenceFeedbackPresentation.make(from: [message])
        XCTAssertEqual(consequence?.message.title, "Utility Shortfall")
        XCTAssertEqual(consequence?.direction, .negative)
    }

    @MainActor
    func testCompactUtilityDiagnosisRendersThePriorityWithinTheDetailsBudget() throws {
        var state = CityGameState.newCity(seed: 42)
        state.powerUsed = state.powerCapacity + 18
        state.waterUsed = state.waterCapacity - 40
        let store = CityGameStore(state: state)
        store.openInspector(.utilities)
        let size = CGSize(width: 854, height: BuildToolbarView.compactDetailsMaxHeight)

        let utilityDetails = try bitmap(
            of: InspectorView(store: store, compact: true)
                .frame(width: size.width, height: size.height, alignment: .top),
            size: size
        )

        XCTAssertEqual(utilityDetails.size.height, BuildToolbarView.compactDetailsMaxHeight, accuracy: 0.5)
        XCTAssertEqual(store.inspectorSection, .utilities)
        XCTAssertEqual(
            CityUtilityDecisionSupport.make(analytics: store.analytics).title,
            "Power shortfall"
        )
    }

    @MainActor
    func testCompactUtilityDetailNamesPowerAndWaterWithoutWeakeningAccessibilityTruth() {
        let store = CityGameStore(state: .newCity(seed: 42))
        let presentation = HUDUtilityHeadroomPresentation.make(
            powerHeadroom: store.analytics.powerHeadroom,
            waterHeadroom: store.analytics.waterHeadroom
        )

        XCTAssertEqual(presentation.powerLabel, "Power 54")
        XCTAssertEqual(presentation.waterLabel, "Water 48")
        XCTAssertEqual(
            presentation.accessibilityValue,
            "Power headroom 54, Water headroom 48"
        )
        let coverage = (store.analytics.utilityCoverage * 100).percentText
        XCTAssertEqual(coverage, "100%")
        XCTAssertEqual(
            "\(coverage), \(presentation.accessibilityValue)",
            "100%, Power headroom 54, Water headroom 48"
        )
        XCTAssertEqual(TopHUDView.compactMaximumHeight, 64)
        XCTAssertEqual(TopHUDView.regularMaximumHeight, 68)
    }

    func testCompactFinancePulseKeepsCashflowLegibleAndHonest() {
        XCTAssertEqual(
            HUDFinancePulsePresentation.make(
                treasury: 31_450,
                projectedBalance: -119,
                usesUnlimitedFunds: false
            ),
            HUDFinancePulsePresentation(
                value: "$31,450",
                detail: "Net -$119",
                isHealthy: false
            )
        )
        XCTAssertEqual(
            HUDFinancePulsePresentation.make(
                treasury: -50,
                projectedBalance: -500,
                usesUnlimitedFunds: true
            ),
            HUDFinancePulsePresentation(
                value: "Unlimited",
                detail: "Net -$500",
                isHealthy: true
            )
        )
    }

    @MainActor
    func testCompactResilienceForecastRendersWithinTheDetailsBudget() throws {
        var state = CityGameState.newCity(seed: 20260812)
        state.population = 500
        state.tick = 639
        let store = CityGameStore(state: state)
        store.openInspector(.resilience)
        let size = CGSize(width: 854, height: BuildToolbarView.compactDetailsMaxHeight)

        let resilienceDetails = try bitmap(
            of: InspectorView(store: store, compact: true)
                .frame(width: size.width, height: size.height, alignment: .top),
            size: size
        )

        XCTAssertEqual(
            resilienceDetails.size.height,
            BuildToolbarView.compactDetailsMaxHeight,
            accuracy: 0.5
        )
        XCTAssertEqual(store.inspectorSection, .resilience)
        XCTAssertEqual(
            CityResiliencePresentation.make(analytics: store.analytics).status,
            "READY"
        )
    }

    func testResilienceCommandIsSearchableAndUsesTheTenthGlobalShortcut() {
        let descriptor = CityCommandCatalog.descriptor(for: .inspectorResilience)

        XCTAssertEqual(descriptor.category, .inspectors)
        XCTAssertEqual(descriptor.shortcut?.key, "0")
        XCTAssertEqual(descriptor.shortcut?.display, "⌥0")
        XCTAssertEqual(descriptor.shortcut?.modifiers, [.option])
        XCTAssertEqual(
            CityCommandCatalog.matchingCommand(
                key: "0",
                modifiers: [.option],
                scope: .global
            ),
            .inspectorResilience
        )
        for query in ["storm", "emergency", "weather", "preparedness"] {
            XCTAssertTrue(
                CityCommandCatalog.matchingDescriptors(query: query).contains {
                    $0.id == .inspectorResilience
                }
            )
        }
    }

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
            .overlayServices, .overlayHappiness, .overlayPollution, .overlayRoadCondition,
            .overlayFireCoverage, .overlayPoliceCoverage, .overlaySchoolCoverage
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

    @MainActor
    func testStrategyHUDAdvancesTheSelectedGrowthToolThroughSiteAndForecast() throws {
        let initialState = CityGameState.newCity(seed: 42)
        let commercialStore = CityGameStore(state: initialState, startsPaused: true)
        commercialStore.selectTool(.commercial)

        var presentation = CityStrategyHUDPresentation.make(
            state: commercialStore.state,
            speed: commercialStore.speed,
            interactionMode: commercialStore.interactionMode,
            activeTarget: commercialStore.activeMapActionTargetPresentation
        )
        XCTAssertEqual(presentation.actions.first?.title, "Choose a site")
        XCTAssertEqual(presentation.actions.first?.command, .buildCommercial)
        XCTAssertTrue(presentation.actions.first?.explanation.contains("review its forecast") == true)

        let stateBeforeTargeting = commercialStore.state
        let response = try XCTUnwrap(presentation.actions.first)
        StrategyCommandCenterView.perform(response, on: commercialStore)
        XCTAssertEqual(commercialStore.state, stateBeforeTargeting)
        XCTAssertNotNil(commercialStore.activeMapActionTargetPresentation?.primaryAction.buildDecision)

        presentation = CityStrategyHUDPresentation.make(
            state: commercialStore.state,
            speed: commercialStore.speed,
            interactionMode: commercialStore.interactionMode,
            activeTarget: commercialStore.activeMapActionTargetPresentation
        )
        XCTAssertEqual(presentation.actions.first?.title, "Review Commercial forecast")
        XCTAssertEqual(presentation.actions.first?.command, .buildCommercial)
        XCTAssertTrue(presentation.actions.first?.explanation.contains("before confirming") == true)
        let targetBeforeReview = try XCTUnwrap(commercialStore.activeMapActionTargetPresentation)
        let stateBeforeReview = commercialStore.state
        StrategyCommandCenterView.perform(
            try XCTUnwrap(presentation.actions.first),
            on: commercialStore
        )
        XCTAssertEqual(commercialStore.activeMapActionTargetPresentation, targetBeforeReview)
        XCTAssertEqual(commercialStore.state, stateBeforeReview)

        let industrialStore = CityGameStore(state: initialState, startsPaused: true)
        industrialStore.selectTool(.industrial)
        let industrial = CityStrategyHUDPresentation.make(
            state: industrialStore.state,
            speed: industrialStore.speed,
            interactionMode: industrialStore.interactionMode,
            activeTarget: industrialStore.activeMapActionTargetPresentation
        )
        XCTAssertEqual(industrial.actions.first?.title, "Choose a site")
        XCTAssertEqual(industrial.actions.first?.command, .buildIndustrial)
        XCTAssertEqual(industrial.actions.last?.command, .buildCommercial)

        commercialStore.activateInspectMode()
        let reset = CityStrategyHUDPresentation.make(
            state: commercialStore.state,
            speed: commercialStore.speed,
            interactionMode: commercialStore.interactionMode,
            activeTarget: commercialStore.activeMapActionTargetPresentation
        )
        XCTAssertEqual(reset.actions.map(\.title), ["Choose Commercial", "Choose Industrial"])
    }

    @MainActor
    func testGrowthProjectConstructionOwnsTheImmediateActionUntilStrategyCommitment() throws {
        var state = CityGameState.newCity(seed: 42)
        let coordinate = try XCTUnwrap(state.tiles.first(where: { tile in
            guard tile.kind == .empty else { return false }
            if case .success = CitySimulation.validateBuild(
                .commercial,
                at: tile.coordinate,
                in: state
            ) {
                return true
            }
            return false
        })?.coordinate)
        guard case .success = CitySimulation.build(
            .commercial,
            at: coordinate,
            in: &state
        ) else {
            return XCTFail("Expected Commercial construction to start")
        }

        let store = CityGameStore(state: state, startsPaused: true)
        let paused = CityStrategyHUDPresentation.make(
            analytics: store.analytics,
            speed: store.speed
        )
        XCTAssertEqual(paused.eyebrow, "GROWTH PROJECT")
        XCTAssertEqual(paused.title, "Commercial under construction")
        XCTAssertEqual(paused.status, "BUILDING · 0%")
        XCTAssertEqual(paused.actions.map(\.title), ["Resume Commercial"])
        XCTAssertEqual(paused.actions.map(\.command), [.togglePause])
        XCTAssertFalse(paused.actions.contains { [.buildCommercial, .buildIndustrial].contains($0.command) })
        XCTAssertTrue(paused.summary.contains("Block \(coordinate.x + 1), \(coordinate.y + 1)"))
        XCTAssertTrue(paused.summary.contains("4 construction ticks"))

        let resume = try XCTUnwrap(paused.actions.first)
        StrategyCommandCenterView.perform(resume, on: store)
        XCTAssertEqual(store.speed, .normal)
        let running = CityStrategyHUDPresentation.make(
            analytics: store.analytics,
            speed: store.speed
        )
        XCTAssertEqual(running.actions.map(\.title), ["Pause to inspect"])
        StrategyCommandCenterView.perform(try XCTUnwrap(running.actions.first), on: store)
        XCTAssertEqual(store.speed, .paused)

        CitySimulation.step(&store.state)
        let progressing = CityStrategyHUDPresentation.make(
            analytics: store.analytics,
            speed: store.speed
        )
        XCTAssertEqual(progressing.status, "BUILDING · 25%")
        XCTAssertTrue(progressing.summary.contains("3 construction ticks"))

        for _ in 0..<3 { CitySimulation.step(&store.state) }
        XCTAssertEqual(store.state.tile(at: coordinate)?.constructionProgress, 1)
        XCTAssertEqual(store.analytics.committedStrategy, .commercialStewardship)
        let committed = CityStrategyHUDPresentation.make(
            analytics: store.analytics,
            speed: store.speed
        )
        XCTAssertEqual(committed.title, "Commercial stewardship")
        XCTAssertFalse(committed.actions.contains { [.buildCommercial, .buildIndustrial].contains($0.command) })
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
    func testRegionalQualificationRoutesTheCurrentBlockerAndNamesConcurrentStandards() throws {
        var populationState = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .industrialExpansion
                    && $0.definition.stage == .charterMidpoint
            }?.state
        )
        populationState.progression?.secondAct?.phase = .qualification
        populationState.progression?.secondAct?.nextScheduledTick = nil
        populationState.population = 500
        populationState.happiness = 40

        let populationStore = CityGameStore(state: populationState)
        populationStore.speed = .fastest
        let population = CityStrategyHUDPresentation.make(analytics: populationStore.analytics)
        XCTAssertEqual(population.title, "Grow to 525 residents")
        XCTAssertEqual(population.status, "INTERRUPTED · 0/12")
        XCTAssertEqual(population.tone, .recovery)
        XCTAssertEqual(population.diagnostic?.command, .buildResidential)
        XCTAssertTrue(population.actions.contains { $0.command == .inspectorPopulation })
        XCTAssertTrue(population.summary.contains("Also below standard:"))

        let regionalObjective = try XCTUnwrap(
            populationStore.objectives.first { $0.id == "regional-capital" }
        )
        XCTAssertEqual(regionalObjective.remaining, population.summary)
        populationStore.openObjective(regionalObjective)
        XCTAssertTrue(populationStore.showObjectives)
        XCTAssertEqual(populationStore.inspectorSection, .population)

        let homes = try XCTUnwrap(population.diagnostic)
        let focusBeforeHomes = populationStore.mapFocusRequestGeneration
        StrategyCommandCenterView.perform(homes, on: populationStore)
        XCTAssertEqual(populationStore.interactionMode, .build(.residential))
        XCTAssertEqual(populationStore.mapFocusRequestGeneration, focusBeforeHomes + 1)
        XCTAssertEqual(populationStore.speed, .paused)
        let homeTarget = try XCTUnwrap(populationStore.selectedCoordinate)
        if case .failure(let rejection) = CitySimulation.validateBuild(
            .residential,
            at: homeTarget,
            in: populationStore.state
        ) {
            XCTFail("Regional housing route selected a blocked parcel: \(rejection)")
        }

        var utilityState = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .industrialExpansion
                    && $0.definition.stage == .regionalCapital
            }?.state
        )
        utilityState.status = .playing
        utilityState.progression?.secondAct?.phase = .qualification
        utilityState.progression?.secondAct?.regionalCapitalAwarded = false
        utilityState.progression?.secondAct?.qualifyingCycles = 0
        utilityState.powerUsed = Int(Double(utilityState.powerCapacity) * 0.81)
        utilityState.waterUsed = Int(Double(utilityState.waterCapacity) * 0.81)

        let utility = CityStrategyHUDPresentation.make(analytics: CityAnalytics(state: utilityState))
        XCTAssertEqual(utility.title, "Build regional utility reserve")
        XCTAssertTrue([CityCommandID.buildPowerPlant, .buildWaterTower].contains(utility.diagnostic?.command))
        XCTAssertTrue(utility.actions.contains { $0.command == .inspectorUtilities })
        XCTAssertTrue(utility.summary.contains("20%"))

        var healthyState = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .industrialExpansion
                    && $0.definition.stage == .regionalCapital
            }?.state
        )
        healthyState.status = .playing
        healthyState.progression?.secondAct?.phase = .qualification
        healthyState.progression?.secondAct?.regionalCapitalAwarded = false
        healthyState.progression?.secondAct?.qualifyingCycles = 7
        let healthyAnalytics = CityAnalytics(state: healthyState)
        XCTAssertTrue(healthyAnalytics.meetsRegionalCapitalStandards)
        let healthy = CityStrategyHUDPresentation.make(analytics: healthyAnalytics)
        XCTAssertEqual(healthy.status, "QUALIFYING · 7/12")
        XCTAssertEqual(healthy.tone, .active)
        XCTAssertEqual(healthy.title, "Hold every regional standard")
        XCTAssertTrue(healthy.accessibilityValue.contains("QUALIFYING · 7/12"))
    }

    @MainActor
    func testCompletedStrategyHandsThePrimaryHUDToActionableTownCharterProgress() throws {
        var state = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .commercialStewardship
                    && $0.definition.stage == .regionalCapital
            }?.state
        )
        state.status = .playing
        state.progression?.townCharterAwarded = false
        state.progression?.townCharterQualifyingCycles = 4
        state.progression?.secondAct = nil
        state.population = 470

        let store = CityGameStore(state: state)
        store.speed = .fastest
        let blocked = CityStrategyHUDPresentation.make(analytics: store.analytics)
        XCTAssertEqual(blocked.eyebrow, "TOWN CHARTER")
        XCTAssertEqual(blocked.title, "Grow to 500 residents")
        XCTAssertEqual(blocked.status, "AT RISK · 4/12")
        XCTAssertEqual(blocked.tone, .recovery)
        XCTAssertEqual(blocked.diagnostic?.command, .buildResidential)
        XCTAssertTrue(blocked.actions.contains { $0.command == .inspectorPopulation })

        let interruption = CityMessage(
            tick: state.tick,
            severity: .warning,
            title: "Town Charter Qualification Interrupted",
            detail: "Four qualifying days were lost. Grow to 500 residents."
        )
        let interruptionActions = CityNoticeActionCatalog.actions(
            for: interruption.title,
            analytics: store.analytics
        )
        XCTAssertEqual(interruptionActions.first?.command, .buildResidential)
        XCTAssertTrue(interruptionActions.contains { $0.command == .inspectorPopulation })
        store.openMessage(interruption)
        XCTAssertEqual(store.inspectorSection, .population)
        XCTAssertEqual(store.speed, .paused)
        store.speed = .fastest

        let objective = try XCTUnwrap(store.objectives.first { $0.id == "town-charter" })
        store.openObjective(objective)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.inspectorSection, .population)

        let homes = try XCTUnwrap(blocked.diagnostic)
        StrategyCommandCenterView.perform(homes, on: store)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.speed, .paused)
        let target = try XCTUnwrap(store.selectedCoordinate)
        if case .failure(let rejection) = CitySimulation.validateBuild(
            .residential,
            at: target,
            in: store.state
        ) {
            XCTFail("Town Charter housing route selected a blocked parcel: \(rejection)")
        }

        state.population = 500
        let healthyAnalytics = CityAnalytics(state: state)
        XCTAssertTrue(healthyAnalytics.meetsTownCharterStandards)
        let healthy = CityStrategyHUDPresentation.make(analytics: healthyAnalytics)
        XCTAssertEqual(healthy.title, "Hold every Charter standard")
        XCTAssertEqual(healthy.status, "QUALIFYING · 4/12")
        XCTAssertEqual(healthy.tone, .active)
        XCTAssertTrue(healthy.accessibilityValue.contains("QUALIFYING · 4/12"))
    }

    @MainActor
    func testTownCharterStandardsNoticeRoutesTheLiveFirstActBlockerWithoutChangingSpeed() throws {
        var state = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .commercialStewardship
                    && $0.definition.stage == .regionalCapital
            }?.state
        )
        state.status = .playing
        state.progression?.townCharterAwarded = false
        state.progression?.townCharterQualifyingCycles = 0
        state.progression?.secondAct = nil
        state.population = 470

        let store = CityGameStore(state: state)
        store.speed = .fastest
        let notice = CityMessage(
            tick: state.tick,
            severity: .information,
            title: "Town Charter Standards",
            detail: "Sustain every standard for 12 consecutive days."
        )

        let actions = CityNoticeActionCatalog.actions(
            for: notice.title,
            analytics: store.analytics
        )
        XCTAssertEqual(actions.first?.command, .buildResidential)
        XCTAssertTrue(actions.contains { $0.command == .inspectorPopulation })

        store.openMessage(notice)

        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.inspectorSection, .population)
        XCTAssertEqual(store.speed, .fastest)
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertNil(store.selectedCoordinate)
    }

    func testTownCharterGuidancePreparesForecastUtilityReserveBeforeMoreHousing() throws {
        var state = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .commercialStewardship
                    && $0.definition.stage == .regionalCapital
            }?.state
        )
        state.status = .playing
        state.progression?.townCharterAwarded = false
        state.progression?.townCharterQualifyingCycles = 0
        state.progression?.secondAct = nil
        state.population = 470
        state.powerUsed = 410
        state.powerCapacity = 500
        state.waterUsed = 360
        state.waterCapacity = 540

        let analytics = CityAnalytics(state: state)
        XCTAssertGreaterThan(analytics.utilityReserve, 0.15)
        let forecast = try XCTUnwrap(analytics.townCharterUtilityForecast)
        XCTAssertEqual(forecast.kind, .powerPlant)
        XCTAssertEqual(forecast.projectedUse, 435)
        XCTAssertEqual(forecast.requiredCapacity, 512)
        XCTAssertEqual(forecast.capacityGap, 12)
        XCTAssertEqual(
            analytics.townCharterStatusText,
            "Next: prepare 12 more power capacity for 500 residents"
        )

        let support = CityTownCharterDecisionSupport.make(analytics: analytics)
        XCTAssertEqual(support.title, "Prepare power for 500 residents")
        XCTAssertEqual(support.primaryResponse.command, .buildPowerPlant)
        XCTAssertTrue(support.primaryResponse.explanation.contains("projected use of 435"))
        XCTAssertTrue(support.primaryResponse.explanation.contains("15% reserve"))
        XCTAssertTrue(support.secondaryResponses.contains { $0.command == .inspectorUtilities })
        XCTAssertFalse(
            ([support.primaryResponse] + support.secondaryResponses).contains {
                $0.command == .buildResidential
            }
        )
    }

    @MainActor
    func testEveryStrategyRecoveryResultHandsOffToTheLiveTownCharterBlocker() throws {
        let cases: [(CityStrategy, String)] = [
            (.commercialStewardship, "Main Street Rebound"),
            (.commercialStewardship, "Main Street Recovery Delayed"),
            (.industrialExpansion, "Freight Network Secured"),
            (.industrialExpansion, "Cleaner Industry Compact"),
            (.industrialExpansion, "Freight Recovery Delayed")
        ]
        let fixtures = try ProductionStoryStateBuilder().buildAll()

        for (strategy, title) in cases {
            var state = try XCTUnwrap(fixtures.first {
                $0.definition.strategy == strategy
                    && $0.definition.stage == .regionalCapital
            }?.state, title)
            state.status = .playing
            state.progression?.townCharterAwarded = false
            state.progression?.townCharterQualifyingCycles = 0
            state.progression?.strategy?.currentPhase = .completed
            state.progression?.secondAct = nil
            state.population = 470
            state.happiness = max(60, state.happiness)
            state.treasury = max(20_000, state.treasury)

            let store = CityGameStore(state: state)
            store.speed = .fastest
            let support = CityTownCharterDecisionSupport.make(analytics: store.analytics)
            let actions = CityNoticeActionCatalog.actions(for: title, analytics: store.analytics)
            XCTAssertEqual(actions.first?.command, support.primaryResponse.command, title)
            XCTAssertEqual(
                Set(actions.map(\.command)),
                Set(([support.primaryResponse] + support.secondaryResponses).map(\.command)),
                title
            )

            let result = CityMessage(
                tick: state.tick,
                severity: title.contains("Delayed") ? .warning : .good,
                title: title,
                detail: "Strategy result"
            )
            store.openMessage(result)
            XCTAssertTrue(store.showObjectives, title)
            XCTAssertEqual(store.inspectorSection, .population, title)
            XCTAssertEqual(store.speed, .fastest, title)
            XCTAssertEqual(store.interactionMode, .inspect, title)
            XCTAssertNil(store.selectedCoordinate, title)
        }

        XCTAssertEqual(
            CityNoticeActionCatalog.actions(for: "Industrial Load Absorbed").map(\.command),
            [.inspectorUtilities],
            "The complication-stage success must retain its utility diagnosis"
        )
    }

    @MainActor
    func testRegionalQualificationInterruptionRoutesTheLiveRemedyAndPauses() throws {
        var state = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .commercialStewardship
                    && $0.definition.stage == .regionalCapital
            }?.state
        )
        state.status = .playing
        state.progression?.secondAct?.phase = .qualification
        state.progression?.secondAct?.regionalCapitalAwarded = false
        state.progression?.secondAct?.qualifyingCycles = 0
        state.happiness = 40

        let store = CityGameStore(state: state)
        store.speed = .fastest
        let interruption = CityMessage(
            tick: state.tick,
            severity: .warning,
            title: "Regional Qualification Interrupted",
            detail: "Three qualifying days were lost. Raise happiness to 56%."
        )
        let actions = CityNoticeActionCatalog.actions(
            for: interruption.title,
            analytics: store.analytics
        )
        XCTAssertEqual(actions.first?.command, .buildPark)
        XCTAssertTrue(actions.contains { $0.command == .inspectorHappiness })

        store.openMessage(interruption)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.inspectorSection, .happiness)
        XCTAssertEqual(store.speed, .paused)
    }

    @MainActor
    func testOpeningBudgetAndCommittedHiringWarningsExposeExactDiagnosisAndPause() {
        var opening = CityGameState.newCity(seed: 42)
        for _ in 0..<4 { CitySimulation.step(&opening) }
        XCTAssertEqual(opening.messages.first?.title, "Budget Gap")
        XCTAssertEqual(
            HUDConsequenceFeedbackPresentation.make(from: opening.messages)?.message.title,
            "Budget Gap"
        )
        XCTAssertEqual(
            CityNoticeActionCatalog.actions(
                for: "Budget Gap",
                analytics: CityAnalytics(state: opening)
            ).map(\.command),
            [.inspectorFinances]
        )

        var state = CityGameState.newCity(seed: 42)
        state.progression?.strategy = CityStrategyProgression(
            committedStrategy: .industrialExpansion,
            currentPhase: .opportunity,
            nextScheduledTick: state.tick + 64
        )
        let store = CityGameStore(state: state)
        store.speed = .fastest

        let hiring = CityMessage(
            tick: state.tick,
            severity: .warning,
            title: "Hiring Bottleneck",
            detail: "The city needs more jobs."
        )
        let hiringActions = CityNoticeActionCatalog.actions(
            for: hiring.title,
            analytics: store.analytics
        )
        XCTAssertEqual(hiringActions.map(\.command), [.buildIndustrial, .inspectorEmployment])
        XCTAssertFalse(hiringActions.contains { $0.command == .buildCommercial })
        store.openMessage(hiring)
        XCTAssertEqual(store.inspectorSection, .employment)
        XCTAssertEqual(store.speed, .paused)

        store.speed = .fastest
        let budget = CityMessage(
            tick: state.tick,
            severity: .warning,
            title: "Budget Gap",
            detail: "Operations are running a deficit."
        )
        XCTAssertEqual(
            CityNoticeActionCatalog.actions(
                for: budget.title,
                analytics: store.analytics
            ).map(\.command),
            [.inspectorFinances]
        )
        store.openMessage(budget)
        XCTAssertEqual(store.inspectorSection, .finances)
        XCTAssertEqual(store.speed, .paused)
    }

    @MainActor
    func testStrategyHUDDiagnosisAndMapRemediesUseOneStoreIntentAndFocusHandoff() throws {
        let fixtures = try ProductionStoryStateBuilder().buildAll()
        let commercialState = try XCTUnwrap(fixtures.first {
            $0.definition.strategy == .commercialStewardship
                && $0.definition.moment == .complication
        }?.state)
        let commercialStore = CityGameStore(state: commercialState)
        commercialStore.speed = .fastest
        let commercial = CityStrategyHUDPresentation.make(analytics: commercialStore.analytics)
        let diagnostic = try XCTUnwrap(commercial.diagnostic)
        let park = try XCTUnwrap(commercial.actions.first { $0.command == .buildPark })

        StrategyCommandCenterView.perform(diagnostic, on: commercialStore)
        XCTAssertTrue(commercialStore.showInspector)
        XCTAssertEqual(commercialStore.inspectorSection, .finances)
        XCTAssertEqual(commercialStore.speed, .paused)
        commercialStore.speed = .fastest
        let focusBeforePark = commercialStore.mapFocusRequestGeneration
        StrategyCommandCenterView.perform(park, on: commercialStore)
        XCTAssertEqual(commercialStore.interactionMode, .build(.park))
        XCTAssertEqual(commercialStore.mapFocusRequestGeneration, focusBeforePark + 1)
        XCTAssertEqual(commercialStore.speed, .paused)
        let commercialTarget = try XCTUnwrap(commercialStore.selectedCoordinate)
        if case .failure(let rejection) = CitySimulation.validateBuild(
            .park,
            at: commercialTarget,
            in: commercialStore.state
        ) {
            XCTFail("Strategic Park route selected a blocked parcel: \(rejection)")
        }
        commercialStore.togglePause()
        XCTAssertEqual(commercialStore.speed, .fastest, "Space resumes the player's prior decision speed")
        commercialStore.togglePause()

        let industrialState = try XCTUnwrap(fixtures.first {
            $0.definition.strategy == .industrialExpansion
                && $0.definition.moment == .complication
        }?.state)
        let industrialStore = CityGameStore(state: industrialState)
        industrialStore.speed = .fastest
        let industrial = CityStrategyHUDPresentation.make(analytics: industrialStore.analytics)
        let power = try XCTUnwrap(industrial.actions.first { $0.command == .buildPowerPlant })
        let focusBeforePower = industrialStore.mapFocusRequestGeneration
        StrategyCommandCenterView.perform(power, on: industrialStore)
        XCTAssertEqual(industrialStore.interactionMode, .build(.powerPlant))
        XCTAssertEqual(industrialStore.mapFocusRequestGeneration, focusBeforePower + 1)
        XCTAssertEqual(industrialStore.speed, .paused)
        let industrialTarget = try XCTUnwrap(industrialStore.selectedCoordinate)
        if case .failure(let rejection) = CitySimulation.validateBuild(
            .powerPlant,
            at: industrialTarget,
            in: industrialStore.state
        ) {
            XCTFail("Strategic Power Plant route selected a blocked parcel: \(rejection)")
        }
    }

    @MainActor
    func testStrategyHUDRecoveryRoutesStateDestinationAndUncertainOutcomeAtCompactAndRegularSizes() throws {
        let state = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .commercialStewardship
                    && $0.definition.moment == .complication
            }?.state
        )
        let store = CityGameStore(state: state)
        let presentation = CityStrategyHUDPresentation.make(analytics: store.analytics)
        let taxPolicy = try XCTUnwrap(presentation.diagnostic)
        let park = try XCTUnwrap(presentation.actions.first { $0.command == .buildPark })

        XCTAssertEqual(StrategyCommandCenterView.recoveryRouteTitle(for: taxPolicy, compact: true), "Tax Policy")
        XCTAssertEqual(StrategyCommandCenterView.recoveryRouteTitle(for: taxPolicy, compact: false), "Open Tax Policy")
        XCTAssertEqual(
            StrategyCommandCenterView.recoveryRouteOutcome(for: taxPolicy),
            "Tax relief may support demand; revenue may fall."
        )
        XCTAssertEqual(StrategyCommandCenterView.recoveryRouteTitle(for: park, compact: true), "Build Park")
        XCTAssertEqual(
            StrategyCommandCenterView.recoveryRouteOutcome(for: park),
            "A park may support recovery; placement is not guaranteed."
        )

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
        XCTAssertEqual(compact.size, compactSize)
        XCTAssertEqual(regular.size, regularSize)

        XCTAssertTrue(store.perform(taxPolicy.command), "Pointer and FKA retain the existing Tax Policy command")
        XCTAssertEqual(store.inspectorSection, .finances)
        let focusBeforePark = store.mapFocusRequestGeneration
        XCTAssertTrue(store.performMapFocused(park.command), "Pointer and FKA retain the existing map-focused route")
        XCTAssertEqual(store.interactionMode, .build(.park))
        XCTAssertEqual(store.mapFocusRequestGeneration, focusBeforePark + 1)
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
    func testBlockedPlacementFeedbackReplacesPriorSuccess() throws {
        let occupiedCoordinate = GridCoordinate(x: 5, y: 7) // authored block 6,8
        var initial = CityGameState.newCity(seed: 42)
        initial.updateTile(at: occupiedCoordinate) { tile in
            tile.kind = .commercial
        }
        XCTAssertNotEqual(initial.tile(at: occupiedCoordinate)?.kind, .empty)
        let validRoadCoordinate = try XCTUnwrap(initial.tiles.first { tile in
            guard tile.kind == .empty else { return false }
            if case .success = CitySimulation.validateBuild(.road, at: tile.coordinate, in: initial) {
                return true
            }
            return false
        }).coordinate

        let store = CityGameStore(state: initial)
        store.selectTool(.road)
        store.primaryAction(at: validRoadCoordinate)

        let stateAfterSuccess = store.state
        XCTAssertEqual(store.lastFeedback, "Road construction approved")
        XCTAssertEqual(store.lastFeedbackTone, .positive)
        XCTAssertTrue(store.canUndo)

        store.primaryAction(at: occupiedCoordinate)

        XCTAssertEqual(store.state, stateAfterSuccess)
        XCTAssertEqual(store.lastFeedback, "Demolish the existing structure before building here. Road remains selected — choose another block.")
        XCTAssertEqual(store.lastFeedbackTone, .caution)
        XCTAssertFalse(store.lastFeedback?.contains("construction approved") == true)
        XCTAssertTrue(store.canUndo, "A rejected placement must not erase the prior undo entry")
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
    func testCityNameDraftCannotLeakBlankIdentityAndConstructionUndoPreservesRename() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-name-draft-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CityGameStore(
            state: .newCity(seed: 42),
            saveService: SaveGameService(rootURL: root)
        )
        XCTAssertEqual(store.cityNameDraft, "New Arcadia")

        store.updateCityNameDraft("   ")
        XCTAssertEqual(store.state.cityName, "New Arcadia")
        store.commitCityNameDraft()
        XCTAssertEqual(store.state.cityName, "New Arcadia")
        XCTAssertEqual(store.cityNameDraft, "New Arcadia")

        store.updateCityNameDraft("  Harbor Light  ")
        XCTAssertEqual(
            store.state.cityName,
            "New Arcadia",
            "Typing edits only the draft until submit or focus loss"
        )
        store.commitCityNameDraft()
        XCTAssertEqual(store.state.cityName, "Harbor Light")
        XCTAssertEqual(store.cityNameDraft, "Harbor Light")

        store.selectTool(.commercial)
        let target = try XCTUnwrap(store.state.tiles.first { tile in
            guard tile.kind == .empty else { return false }
            if case .success = CitySimulation.validateBuild(
                .commercial,
                at: tile.coordinate,
                in: store.state
            ) {
                return true
            }
            return false
        }?.coordinate)
        store.primaryAction(at: target)
        XCTAssertTrue(store.canUndo)

        store.setCityName("Harbor Point")
        store.undoLastAction()
        XCTAssertEqual(store.state.cityName, "Harbor Point")
        XCTAssertEqual(store.cityNameDraft, "Harbor Point")
        XCTAssertEqual(store.state.tile(at: target)?.kind, .empty)

        store.save()
        store.setCityName("Transient Rename")
        store.load()
        XCTAssertEqual(store.state.cityName, "Harbor Point")
        XCTAssertEqual(store.cityNameDraft, "Harbor Point")
        XCTAssertEqual(store.speed, .paused)

        store.newCity()
        XCTAssertEqual(store.state.cityName, "New Arcadia")
        XCTAssertEqual(store.cityNameDraft, "New Arcadia")
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
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 1)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.isCityFocusModeEnabled)
        XCTAssertTrue(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 2)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showInspector)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 3)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertFalse(store.showObjectives)
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertEqual(store.selectedCoordinate, selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 4)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertEqual(store.interactionMode, .build(.residential))
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 5)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 5)
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
    func testFocusCityFramesDevelopedCityOnceWhilePreservingSelectedTargetIdentity() throws {
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
            scene.frameCity()
            let expectedFocusScale = scene.cameraScale
            let expectedFocusPosition = scene.camera?.position
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
            XCTAssertTrue(
                coordinator.synchronizeCityFocusCamera(
                    isEnabled: store.isCityFocusModeEnabled,
                    selectedCoordinate: store.selectedCoordinate
                )
            )
            XCTAssertEqual(scene.cameraScale, expectedFocusScale, accuracy: 0.000_001)
            XCTAssertEqual(scene.camera?.position, expectedFocusPosition)
            XCTAssertNotEqual(scene.cameraScale, retainedScale)
            XCTAssertNotEqual(scene.camera?.position, retainedPosition)
            XCTAssertEqual(store.selectedCoordinate, retainedTarget)

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
            let escapedPosition = scene.camera?.position

            XCTAssertTrue(store.perform(.toggleCityFocus))
            XCTAssertTrue(
                coordinator.synchronizeCityFocusCamera(
                    isEnabled: store.isCityFocusModeEnabled,
                    selectedCoordinate: store.selectedCoordinate
                )
            )
            XCTAssertEqual(scene.cameraScale, expectedFocusScale, accuracy: 0.000_001)
            XCTAssertEqual(scene.camera?.position, expectedFocusPosition)
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
            let undoPosition = scene.camera?.position

            XCTAssertTrue(store.perform(.toggleCityFocus))
            XCTAssertTrue(
                coordinator.synchronizeCityFocusCamera(
                    isEnabled: store.isCityFocusModeEnabled,
                    selectedCoordinate: store.selectedCoordinate
                )
            )
            XCTAssertEqual(scene.cameraScale, expectedFocusScale, accuracy: 0.000_001)
            XCTAssertEqual(scene.camera?.position, expectedFocusPosition)
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

        let cases: [(size: CGSize, compact: Bool)] = [
            (CGSize(width: 1_278, height: 768), false),
            (CGSize(width: 900, height: 600), true),
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

            let expectedInsets = ContentView.focusCityViewportInsets(
                compact: testCase.compact,
                chromeFrame: .zero
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
    func testCompactCatalogItemPointerCaptureIsImmediateAndCanceledMenusExpire() throws {
        _ = NSApplication.shared
        let contentWindow = NSWindow(
            contentRect: CGRect(x: 100, y: 120, width: 900, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let popupWindow = NSWindow(
            contentRect: CGRect(x: 360, y: 330, width: 260, height: 320),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let gate = CityMapPointerTransitionGate()
        let binding = CityBuildCatalogWindowBindingView(pointerTransitionGate: gate)
        binding.frame = CGRect(x: 40, y: 40, width: 140, height: 44)
        contentWindow.contentView?.addSubview(binding)
        contentWindow.orderFront(nil)
        popupWindow.orderFront(nil)
        let catalogMenu = NSMenu()
        for kind in BuildingKind.allCases {
            catalogMenu.addItem(
                NSMenuItem(
                    title: "\(kind.title) · \(kind.buildCost.currencyText) · forecast at block",
                    action: nil,
                    keyEquivalent: ""
                )
            )
        }

        let openingLocation = NSPoint(x: 100, y: 62)
        let openingUp = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: openingLocation,
                modifierFlags: [],
                timestamp: 1,
                windowNumber: contentWindow.windowNumber,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 0
            )
        )
        let popupLocation = NSPoint(x: 80, y: 96)
        let selectionDown = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: popupLocation,
                modifierFlags: [],
                timestamp: 1.9,
                windowNumber: popupWindow.windowNumber,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 0
            )
        )
        let selectionUp = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: popupLocation,
                modifierFlags: [],
                timestamp: 2,
                windowNumber: popupWindow.windowNumber,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 0
            )
        )
        let semanticActionEvent = try XCTUnwrap(
            NSEvent.otherEvent(
                with: .applicationDefined,
                location: .zero,
                modifierFlags: [],
                timestamp: 2,
                windowNumber: 0,
                context: nil,
                subtype: 0,
                data1: 0,
                data2: 0
            )
        )
        let store = CityGameStore(state: .newCity(seed: 42))

        gate.observeCompactCatalogInput(
            try keyEvent(characters: "\r", keyCode: 36),
            controlView: binding
        )
        NotificationCenter.default.post(
            name: NSMenu.didBeginTrackingNotification,
            object: catalogMenu
        )
        XCTAssertTrue(gate.compactCatalogIsTracking)
        gate.observeCompactCatalogInput(selectionDown, controlView: binding)
        gate.observeCompactCatalogInput(selectionUp, controlView: binding)
        XCTAssertTrue(
            BuildToolbarView.performCompactCatalogSelection(
                .commercial,
                store: store,
                pointerTransitionGate: gate,
                event: semanticActionEvent
            )
        )
        XCTAssertTrue(gate.isActive)
        let expectedAnchor = contentWindow.convertPoint(
            fromScreen: popupWindow.convertPoint(toScreen: popupLocation)
        )
        let gateAnchor = try XCTUnwrap(gate.anchor)
        XCTAssertEqual(gateAnchor.x, expectedAnchor.x, accuracy: 0.001)
        XCTAssertEqual(gateAnchor.y, expectedAnchor.y, accuracy: 0.001)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.interactionMode, .build(.commercial))
        NotificationCenter.default.post(
            name: NSMenu.didEndTrackingNotification,
            object: catalogMenu
        )
        XCTAssertFalse(gate.compactCatalogIsTracking)

        gate.cancel()
        NotificationCenter.default.post(
            name: NSMenu.didBeginTrackingNotification,
            object: catalogMenu
        )
        gate.observeCompactCatalogInput(openingUp, controlView: binding)
        gate.observeCompactCatalogInput(selectionDown, controlView: binding)
        gate.observeCompactCatalogInput(selectionUp, controlView: binding)
        XCTAssertTrue(
            BuildToolbarView.performCompactCatalogSelection(
                .residential,
                store: store,
                pointerTransitionGate: gate,
                event: semanticActionEvent
            )
        )
        XCTAssertTrue(gate.isActive, "Pointer-open and pointer-selected items use the same item capture")
        NotificationCenter.default.post(
            name: NSMenu.didEndTrackingNotification,
            object: catalogMenu
        )
        gate.cancel()

        NotificationCenter.default.post(
            name: NSMenu.didBeginTrackingNotification,
            object: catalogMenu
        )
        gate.observeCompactCatalogInput(selectionDown, controlView: binding)
        gate.observeCompactCatalogInput(selectionUp, controlView: binding)
        gate.observeCompactCatalogInput(
            try keyEvent(characters: "\r", keyCode: 36),
            controlView: binding
        )
        XCTAssertTrue(
            BuildToolbarView.performCompactCatalogSelection(
                .industrial,
                store: store,
                pointerTransitionGate: gate,
                event: semanticActionEvent
            )
        )
        XCTAssertFalse(gate.isActive, "Keyboard selection must clear pointer capture and stay immediate")
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.interactionMode, .build(.industrial))
        NotificationCenter.default.post(
            name: NSMenu.didEndTrackingNotification,
            object: catalogMenu
        )

        NotificationCenter.default.post(
            name: NSMenu.didBeginTrackingNotification,
            object: catalogMenu
        )
        gate.observeCompactCatalogInput(selectionDown, controlView: binding)
        gate.observeCompactCatalogInput(selectionUp, controlView: binding)
        NotificationCenter.default.post(
            name: NSMenu.didEndTrackingNotification,
            object: catalogMenu
        )
        XCTAssertTrue(
            BuildToolbarView.performCompactCatalogSelection(
                .road,
                store: store,
                pointerTransitionGate: gate,
                event: semanticActionEvent
            )
        )
        XCTAssertFalse(gate.isActive, "A canceled menu cannot leak pointer capture into a later action")
        XCTAssertNil(store.selectedCoordinate)

        binding.removeFromSuperview()
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

        let expectedFocusedScene = CityScene(size: size)
        expectedFocusedScene.reducedMotion = true
        expectedFocusedScene.updateViewportInsets(
            ContentView.focusCityViewportInsets(compact: true, chromeFrame: .zero)
        )
        expectedFocusedScene.render(
            state: stateBeforeEscape,
            overlay: store.overlay,
            selection: shiftedSelection,
            interactionMode: store.interactionMode
        )
        expectedFocusedScene.frameCity()

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
        XCTAssertNotEqual(scene.cameraScale, cameraScale)
        XCTAssertNotEqual(scene.camera?.position, cameraPosition)
        XCTAssertEqual(scene.cameraScale, expectedFocusedScene.cameraScale, accuracy: 0.000_001)
        XCTAssertEqual(
            scene.cameraPositionForTesting.x,
            expectedFocusedScene.cameraPositionForTesting.x,
            accuracy: 0.5
        )
        XCTAssertEqual(
            scene.cameraPositionForTesting.y,
            expectedFocusedScene.cameraPositionForTesting.y,
            accuracy: 0.5
        )
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
    func testTrafficMapAccessibilityAnnouncesSelectedResidentialCommuteRoute() throws {
        let residence = GridCoordinate(x: 6, y: 10)
        let store = CityGameStore(state: .newCity(seed: 42))
        store.interactionMode = .inspect
        store.selectedCoordinate = residence
        store.overlay = .traffic
        let expectedRoute = try XCTUnwrap(
            CityPresentationSnapshot(state: store.state)
                .spatialConsequences.commuteRoute(from: residence)
        )
        let coordinator = CitySceneView.Coordinator(store: store)
        let mapView = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))

        coordinator.configureMapAccessibility(in: mapView)

        let value = try XCTUnwrap(mapView.accessibilityValue() as? String)
        XCTAssertTrue(value.contains("Traffic overlay active"))
        XCTAssertTrue(
            value.contains(
                "Assigned commute route visible across \(expectedRoute.roadCoordinates.count) road blocks"
            )
        )

        store.overlay = .none
        coordinator.configureMapAccessibility(in: mapView)
        XCTAssertFalse(
            (mapView.accessibilityValue() as? String)?.contains("Assigned commute route visible")
                ?? true
        )
    }

    @MainActor
    func testNativeMapAccessibilityActionPublishesAndBuildsCommercial() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        store.selectTool(.commercial)
        store.clearFeedback()
        let mapView = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let coordinator = CitySceneView.Coordinator(store: store)
        let window = NSWindow(
            contentRect: mapView.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = mapView
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        coordinator.configureMapAccessibility(in: mapView)
        XCTAssertTrue(mapView.isAccessibilityElement())
        XCTAssertEqual(mapView.accessibilityValue() as? String, "No block selected")
        XCTAssertEqual(
            mapView.accessibilityCustomActions()?.map(\.name),
            ["Select buildable block"]
        )

        let action = try XCTUnwrap(mapView.accessibilityCustomActions()?.first)
        XCTAssertTrue(action.handler?() == true)
        let expected = try XCTUnwrap(
            CityBuildOpportunityInventory.make(
                kind: .commercial,
                in: store.state
            )?.outlinedCoordinates.first
        )
        XCTAssertEqual(store.selectedCoordinate, expected)
        XCTAssertEqual(store.selectedTile?.kind, .empty)
        XCTAssertTrue(store.state.neighbors(of: expected).contains { $0.kind == .road })

        let accessibilityValue = try XCTUnwrap(mapView.accessibilityValue() as? String)
        XCTAssertTrue(
            accessibilityValue.contains("block \(expected.x + 1), \(expected.y + 1)")
        )
        XCTAssertTrue(store.performMapCommand(.mapPrimaryAction))
        XCTAssertEqual(store.state.tile(at: expected)?.kind, .commercial)
    }

    @MainActor
    func testNativeMapAccessibilityRoadTargetExtendsTheExistingNetwork() throws {
        let store = CityGameStore(state: .newTrackedCity(seed: 2_026_082_301))
        let target = try XCTUnwrap(
            CitySceneView.Coordinator.firstBuildableCoordinate(for: .road, in: store.state)
        )
        XCTAssertTrue(store.state.neighbors(of: target).contains { $0.kind == .road })
        if case .failure(let rejection) = CitySimulation.validateBuild(
            .road,
            at: target,
            in: store.state
        ) {
            XCTFail("The accessibility target must be a valid street extension, got \(rejection)")
        }
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

        let coordinator = CitySceneView.Coordinator(store: store)
        let accessibilityMap = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        coordinator.configureMapAccessibility(in: accessibilityMap)
        let accessibilityValue = try XCTUnwrap(accessibilityMap.accessibilityValue() as? String)
        XCTAssertTrue(accessibilityValue.contains(BuildRejection.occupied.message))
        XCTAssertFalse(accessibilityValue.contains("construction approved"))

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
    func testPointerPlaceSelectionPublishesForecastBeforeExplicitCommitAndAXCommitsOnce() throws {
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

        XCTAssertEqual(pointerDispatchCount, 0)
        XCTAssertEqual(pointerStore.selectedCoordinate, valid.coordinate)
        XCTAssertEqual(pointerStore.state, authored)
        XCTAssertEqual(pointerStore.state.treasury, pointerTreasury)
        let pointerDecision = try XCTUnwrap(
            pointerStore.activeMapActionTargetPresentation?.primaryAction.buildDecision
        )
        XCTAssertEqual(pointerDecision.buildingTitle, BuildingKind.commercial.title)
        XCTAssertTrue(pointerDecision.operatingImpact.contains("→"))

        XCTAssertTrue(pointerStore.performMapCommand(.mapPrimaryAction))
        XCTAssertEqual(pointerStore.state.tile(at: valid.coordinate)?.kind, .commercial)
        XCTAssertEqual(pointerStore.state.treasury, pointerTreasury - BuildingKind.commercial.buildCost)
        XCTAssertTrue(pointerStore.canUndo)

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
    func testPointerBlockedPlacementPublishesOneCoherentLatestResult() throws {
        let occupiedCoordinate = GridCoordinate(x: 5, y: 7) // authored block 6,8
        var initial = CityGameState.newCity(seed: 42)
        initial.updateTile(at: occupiedCoordinate) { tile in
            tile.kind = .commercial
        }
        let validRoadCoordinate = try XCTUnwrap(initial.tiles.first { tile in
            guard tile.kind == .empty else { return false }
            if case .success = CitySimulation.validateBuild(.road, at: tile.coordinate, in: initial) {
                return true
            }
            return false
        }).coordinate

        let store = CityGameStore(state: initial)
        store.selectTool(.road)
        store.clearFeedback()
        let coordinator = CitySceneView.Coordinator(store: store)
        let mapView = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let scene = CityScene(size: CGSize(width: 900, height: 600))
        mapView.presentScene(scene)
        coordinator.scene = scene
        scene.onActiveActionTargetCandidate = { coordinate in
            coordinator.acceptPointerMapActionCandidate(coordinate, in: mapView)
        }
        scene.onPrimaryAction = { coordinate in
            _ = coordinator.performPointerPrimaryAction(at: coordinate, in: mapView)
        }
        scene.render(
            state: store.state,
            overlay: store.overlay,
            selection: store.selectedCoordinate,
            interactionMode: store.interactionMode,
            activeActionTarget: store.activeMapActionTargetPresentation
        )

        let initialTreasury = store.state.treasury
        scene.activatePrimaryActionForTesting(at: validRoadCoordinate)
        XCTAssertEqual(store.state.tile(at: validRoadCoordinate)?.kind, .road)
        XCTAssertEqual(store.state.treasury, initialTreasury - BuildingKind.road.buildCost)
        XCTAssertTrue(store.canUndo)
        XCTAssertEqual(store.lastFeedback, "Road construction approved")
        XCTAssertEqual(store.lastFeedbackTone, .positive)

        // A real SwiftUI update would render the post-success authoritative state
        // before the next pointer event. Keep that publication boundary explicit.
        scene.render(
            state: store.state,
            overlay: store.overlay,
            selection: store.selectedCoordinate,
            interactionMode: store.interactionMode,
            activeActionTarget: store.activeMapActionTargetPresentation
        )
        scene.activatePrimaryActionForTesting(at: occupiedCoordinate)

        let blockedPresentation = try XCTUnwrap(store.activeMapActionTargetPresentation)
        XCTAssertEqual(blockedPresentation.coordinate, occupiedCoordinate)
        XCTAssertFalse(blockedPresentation.primaryAction.isAvailable)
        XCTAssertTrue(
            blockedPresentation.primaryAction.disclosure.contains(BuildRejection.occupied.message)
        )
        XCTAssertEqual(store.state.tile(at: validRoadCoordinate)?.kind, .road)
        XCTAssertEqual(store.state.treasury, initialTreasury - BuildingKind.road.buildCost)
        XCTAssertTrue(store.canUndo, "A rejected pointer attempt must preserve the prior undo entry")
        XCTAssertEqual(store.lastFeedbackTone, .caution)
        XCTAssertEqual(
            store.lastFeedback,
            BuildRejection.occupied.message + " Road remains selected — choose another block."
        )

        coordinator.configureMapAccessibility(in: mapView)
        let accessibilityValue = try XCTUnwrap(mapView.accessibilityValue() as? String)
        XCTAssertTrue(accessibilityValue.contains("block 6, 8"))
        XCTAssertTrue(accessibilityValue.contains(blockedPresentation.primaryAction.disclosure))
        XCTAssertFalse(accessibilityValue.contains("Road construction approved"))
        XCTAssertFalse(
            mapView.accessibilityCustomActions()?.contains { $0.name.hasPrefix("Build Road") } ?? true,
            "A blocked target must not expose an available build action"
        )
        XCTAssertEqual(scene.activeActionTargetForTesting, blockedPresentation)
    }

    @MainActor
    func testBlockedTargetBecomesAvailableAfterOneAuthoritativeConnectedRoadChange() throws {
        var state = CityGameState.newCity(seed: 42)
        let pair = try XCTUnwrap(state.tiles.lazy.compactMap { target -> (CityTile, CityTile)? in
            guard target.kind == .empty,
                  case .failure(.roadAccessRequired) = CitySimulation.validateBuild(
                    .commercial,
                    at: target.coordinate,
                    in: state
                  ),
                  let road = state.neighbors(of: target.coordinate).first(where: { road in
                      guard road.kind == .empty else { return false }
                      let connectedRoads = state.neighbors(of: road.coordinate).filter {
                          $0.kind == .road
                      }
                      return !connectedRoads.isEmpty
                          && CitySimulation.roadNetworkConnectsToCity(
                              from: connectedRoads.map(\.coordinate),
                              in: state
                          )
                  })
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
        let demolitionTile = try XCTUnwrap(store.state.tiles.first { $0.kind == .residential })
        store.interactionMode = .bulldoze
        store.selectedCoordinate = demolitionTile.coordinate
        coordinator.configureMapAccessibility(in: mapView)

        let demolitionCost = demolitionTile.kind.demolitionCost.currencyText
        let expectedName = "Demolish \(demolitionTile.kind.title) at block \(demolitionTile.coordinate.x + 1), \(demolitionTile.coordinate.y + 1) for \(demolitionCost)"
        XCTAssertEqual(mapView.accessibilityCustomActions()?.first?.name, expectedName)
        XCTAssertTrue((mapView.accessibilityValue() as? String)?.contains(expectedName) == true)
        XCTAssertTrue((mapView.accessibilityValue() as? String)?.contains("Net ") == true)
        XCTAssertTrue((mapView.accessibilityValue() as? String)?.contains("Housing ") == true)
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
            XCTAssertTrue(decision.cost.contains(kind == .road ? "online now" : "online in 4 ticks"))
            XCTAssertEqual(decision.operatingImpact, "Net forecast available when ready")
            XCTAssertNil(decision.operatingForecast)
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
        XCTAssertTrue(validDecision.operatingImpact.contains("Net on completion"))
        XCTAssertTrue(validDecision.operatingImpact.contains("→"))
        XCTAssertTrue(validDecision.accessibilitySummary.contains(validDecision.operatingImpact))
        XCTAssertNotNil(validDecision.operatingForecast)

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
        let roadRecoveryTreasury = roadRecovery.state.treasury
        XCTAssertTrue(roadRecovery.performBuildRecovery(try XCTUnwrap(roadDecision.recovery)))
        XCTAssertEqual(roadRecovery.interactionMode, .build(.road))
        XCTAssertEqual(roadRecovery.selectedTool, .road)
        let roadCoordinate = try XCTUnwrap(roadRecovery.selectedCoordinate)
        XCTAssertNotEqual(roadCoordinate, roadless.coordinate)
        XCTAssertTrue(
            roadRecovery.state.neighbors(of: roadless.coordinate).contains {
                $0.coordinate == roadCoordinate
            }
        )
        if case .failure(let rejection) = CitySimulation.validateBuild(
            .road,
            at: roadCoordinate,
            in: roadRecovery.state
        ) {
            XCTFail("Road recovery must select a valid adjacent block, got \(rejection)")
        }
        XCTAssertEqual(roadRecovery.hudContextScope, .selection)
        XCTAssertEqual(roadRecovery.state, roadRecoveryState)
        XCTAssertEqual(roadRecovery.mapFocusRequestGeneration, roadRecoveryFocus + 1)
        XCTAssertFalse(roadRecovery.canUndo, "Recovery selects a target but never auto-builds")

        XCTAssertTrue(roadRecovery.performMapCommand(.mapPrimaryAction))
        XCTAssertEqual(roadRecovery.state.tile(at: roadCoordinate)?.kind, .road)
        XCTAssertEqual(
            roadRecovery.state.treasury,
            roadRecoveryTreasury - BuildingKind.road.buildCost
        )
        guard case .failure(.cityRoadConnectionRequired) = CitySimulation.validateBuild(
            .residential,
            at: roadless.coordinate,
            in: roadRecovery.state
        ) else {
            return XCTFail("A remote road should gain direct access without pretending to join the city")
        }
        let networkDecision = try XCTUnwrap(
            CityMapPrimaryActionPresentation.make(
                interactionMode: .build(.residential),
                tile: try XCTUnwrap(roadRecovery.state.tile(at: roadless.coordinate)),
                state: roadRecovery.state
            ).buildDecision
        )
        XCTAssertEqual(
            networkDecision.disabledReason,
            BuildRejection.cityRoadConnectionRequired.message
        )
        XCTAssertEqual(networkDecision.recovery?.title, "Connect street")
        XCTAssertTrue(networkDecision.accessibilitySummary.contains("active city network"))
        XCTAssertTrue(roadRecovery.canUndo)
        XCTAssertTrue(roadRecovery.perform(.undo))
        XCTAssertEqual(roadRecovery.state, roadRecoveryState)
        XCTAssertEqual(roadRecovery.state.treasury, roadRecoveryTreasury)
        XCTAssertNil(roadRecovery.selectedCoordinate)
        XCTAssertFalse(roadRecovery.canUndo)

        let cancelledRecovery = CityGameStore(state: authored)
        cancelledRecovery.selectTool(.residential)
        cancelledRecovery.selectedCoordinate = roadless.coordinate
        cancelledRecovery.clearFeedback()
        XCTAssertTrue(cancelledRecovery.performBuildRecovery(try XCTUnwrap(roadDecision.recovery)))
        XCTAssertNotEqual(cancelledRecovery.selectedCoordinate, roadless.coordinate)
        XCTAssertTrue(cancelledRecovery.perform(.cancelInteraction))
        XCTAssertEqual(cancelledRecovery.state, authored)
        XCTAssertNil(cancelledRecovery.selectedCoordinate)
        XCTAssertEqual(cancelledRecovery.interactionMode, .inspect)
        XCTAssertFalse(cancelledRecovery.canUndo)

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
    func testRoadAccessRecoveryPreservesBlockedIntentWhenNoAdjacentRoadTargetExists() throws {
        var authored = CityGameState.newCity(seed: 42)
        let blockedCoordinate = GridCoordinate(x: 0, y: 0)
        authored.updateTile(at: blockedCoordinate) { $0 = CityTile(coordinate: blockedCoordinate, kind: .empty) }
        for neighbor in authored.neighbors(of: blockedCoordinate) {
            authored.updateTile(at: neighbor.coordinate) {
                $0 = CityTile(coordinate: neighbor.coordinate, kind: .residential)
            }
        }
        let store = CityGameStore(state: authored)
        store.selectTool(.commercial)
        store.selectedCoordinate = blockedCoordinate
        store.clearFeedback()
        let state = store.state
        let focusGeneration = store.mapFocusRequestGeneration
        let decision = try XCTUnwrap(store.activeMapActionTargetPresentation?.primaryAction.buildDecision)
        let recovery = try XCTUnwrap(decision.recovery)

        XCTAssertFalse(store.performBuildRecovery(recovery))
        XCTAssertEqual(store.state, state)
        XCTAssertEqual(store.interactionMode, .build(.commercial))
        XCTAssertEqual(store.selectedTool, .commercial)
        XCTAssertEqual(store.selectedCoordinate, blockedCoordinate)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration)
        XCTAssertFalse(store.canUndo)
        XCTAssertTrue(store.lastFeedback?.contains("choose another parcel") == true)
        XCTAssertEqual(
            store.activeMapActionTargetPresentation?.primaryAction.isAvailable,
            false
        )
    }

    @MainActor
    func testRoadAccessRecoveryPrefersARealRoadExtensionAndAXConfirmsExactlyOnce() throws {
        let authored = CityGameState.newCity(seed: 42)
        let fixture = try XCTUnwrap(authored.tiles.lazy.compactMap { blocked -> (CityTile, CityTile)? in
            guard blocked.kind == .empty,
                  case .failure(.roadAccessRequired) = CitySimulation.validateBuild(
                      .commercial,
                      at: blocked.coordinate,
                      in: authored
                  )
            else { return nil }
            let extendingCandidates = authored.neighbors(of: blocked.coordinate).filter { candidate in
                guard candidate.kind == .empty,
                      case .success = CitySimulation.validateBuild(
                          .road,
                          at: candidate.coordinate,
                          in: authored
                      )
                else { return false }
                return authored.neighbors(of: candidate.coordinate).contains { $0.kind == .road }
            }
            guard extendingCandidates.count == 1 else { return nil }
            return (blocked, extendingCandidates[0])
        }.first)
        let store = CityGameStore(state: authored)
        store.selectTool(.commercial)
        store.selectedCoordinate = fixture.0.coordinate
        store.clearFeedback()
        let recovery = try XCTUnwrap(
            store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.recovery
        )
        let treasury = store.state.treasury

        XCTAssertTrue(store.performBuildRecovery(recovery))
        XCTAssertEqual(store.selectedCoordinate, fixture.1.coordinate)
        XCTAssertEqual(store.interactionMode, .build(.road))
        XCTAssertEqual(store.state, authored)
        XCTAssertEqual(store.state.treasury, treasury)
        XCTAssertFalse(store.canUndo)

        let coordinator = CitySceneView.Coordinator(store: store)
        let mapView = CityMapSKView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        coordinator.configureMapAccessibility(in: mapView)
        let action = try XCTUnwrap(
            mapView.accessibilityCustomActions()?.first {
                $0.name == store.activeMapActionTargetPresentation?.primaryAction.name
            }
        )
        XCTAssertTrue(action.handler?() == true)
        XCTAssertEqual(store.state.tile(at: fixture.1.coordinate)?.kind, .road)
        XCTAssertEqual(store.state.treasury, treasury - BuildingKind.road.buildCost)
        XCTAssertTrue(store.canUndo)

        coordinator.configureMapAccessibility(in: mapView)
        XCTAssertFalse(
            mapView.accessibilityCustomActions()?.contains { $0.name.hasPrefix("Build Road") } ?? true,
            "The occupied road target must not advertise a second build action"
        )
    }

    @MainActor
    func testCityStreetRecoveryPreservesDevelopmentAndGuidesShortestRouteUntilReady() throws {
        var authored = CityGameState.newCity(seed: 42)
        authored.treasury = 100_000
        for coordinate in authored.tiles.map(\.coordinate) {
            authored.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }

        let cityHall = GridCoordinate(x: 2, y: 2)
        let connectedRoad = GridCoordinate(x: 3, y: 2)
        let isolatedRoad = GridCoordinate(x: 8, y: 2)
        let blockedCoordinate = GridCoordinate(x: 8, y: 3)
        authored.updateTile(at: cityHall) {
            $0 = CityTile(coordinate: cityHall, kind: .cityHall, constructionProgress: 1)
        }
        authored.updateTile(at: connectedRoad) {
            $0 = CityTile(coordinate: connectedRoad, kind: .road, constructionProgress: 1)
        }
        authored.updateTile(at: isolatedRoad) {
            $0 = CityTile(coordinate: isolatedRoad, kind: .road, constructionProgress: 1)
        }

        let store = CityGameStore(state: authored)
        store.selectTool(.commercial)
        store.selectedCoordinate = blockedCoordinate
        store.clearFeedback()
        let recovery = try XCTUnwrap(
            store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.recovery
        )
        XCTAssertEqual(recovery.title, "Connect street")
        let focusGeneration = store.mapFocusRequestGeneration
        let treasury = store.state.treasury

        XCTAssertTrue(store.performBuildRecovery(recovery))
        XCTAssertEqual(
            store.roadConnectionRecovery,
            CityRoadConnectionRecovery(
                blockedKind: .commercial,
                blockedCoordinate: blockedCoordinate
            )
        )
        XCTAssertEqual(store.interactionMode, .build(.road))
        XCTAssertEqual(store.selectedTool, .road)
        XCTAssertEqual(store.selectedCoordinate, GridCoordinate(x: 7, y: 2))
        XCTAssertEqual(
            store.roadConnectionRecoveryRoute,
            [
                GridCoordinate(x: 7, y: 2),
                GridCoordinate(x: 6, y: 2),
                GridCoordinate(x: 5, y: 2),
                GridCoordinate(x: 4, y: 2),
            ]
        )
        let initialPlan = try XCTUnwrap(store.roadConnectionPlanPresentation)
        XCTAssertEqual(initialPlan.remainingBlocks, 4)
        XCTAssertEqual(initialPlan.constructionCost, 4 * BuildingKind.road.buildCost)
        XCTAssertEqual(initialPlan.fundingGap, 0)
        XCTAssertEqual(
            initialPlan.balanceChange,
            -4 * BuildingKind.road.upkeep * CitySimulation.upkeepMultiplier,
            accuracy: 0.001
        )
        XCTAssertEqual(initialPlan.headline, "4 blocks · $480 route · $2,880 project")
        XCTAssertTrue(initialPlan.operatingImpact.contains("route"))
        XCTAssertTrue(initialPlan.operatingImpact.contains("Commercial"))
        XCTAssertEqual(
            initialPlan.projectConstructionCost,
            4 * BuildingKind.road.buildCost + BuildingKind.commercial.buildCost
        )
        XCTAssertEqual(initialPlan.projectFundingGap, 0)
        XCTAssertEqual(initialPlan.destinationTitle, "Commercial")
        XCTAssertGreaterThan(initialPlan.projectCompletedBalance, initialPlan.completedBalance)
        XCTAssertTrue(initialPlan.accessibilitySummary.contains("Currently funded"))
        XCTAssertTrue(initialPlan.accessibilitySummary.contains("Full project currently funded"))
        XCTAssertEqual(store.state, authored)
        XCTAssertEqual(store.state.tile(at: blockedCoordinate)?.kind, .empty)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusGeneration + 1)
        XCTAssertTrue(store.lastFeedback?.contains("preserves Commercial block 9, 4") == true)
        XCTAssertTrue(store.lastFeedback?.contains("4 road blocks to connect") == true)

        for (index, expectedNext) in [
            GridCoordinate(x: 6, y: 2),
            GridCoordinate(x: 5, y: 2),
            GridCoordinate(x: 4, y: 2),
        ].enumerated() {
            XCTAssertTrue(store.performMapCommand(.mapPrimaryAction))
            XCTAssertEqual(store.selectedCoordinate, expectedNext)
            XCTAssertEqual(
                store.roadConnectionRecoveryRoute,
                Array([
                    GridCoordinate(x: 6, y: 2),
                    GridCoordinate(x: 5, y: 2),
                    GridCoordinate(x: 4, y: 2),
                ].dropFirst(index))
            )
            let remainingPlan = try XCTUnwrap(store.roadConnectionPlanPresentation)
            XCTAssertEqual(remainingPlan.remainingBlocks, 3 - index)
            XCTAssertEqual(
                remainingPlan.constructionCost,
                Double(3 - index) * BuildingKind.road.buildCost
            )
            XCTAssertEqual(remainingPlan.completedBalance, initialPlan.completedBalance, accuracy: 0.001)
            XCTAssertEqual(
                remainingPlan.projectConstructionCost,
                Double(3 - index) * BuildingKind.road.buildCost + BuildingKind.commercial.buildCost
            )
            XCTAssertEqual(
                remainingPlan.projectCompletedBalance,
                initialPlan.projectCompletedBalance,
                accuracy: 0.001
            )
            XCTAssertEqual(store.interactionMode, .build(.road))
            XCTAssertNotNil(store.roadConnectionRecovery)
            XCTAssertEqual(store.state.tile(at: blockedCoordinate)?.kind, .empty)
        }

        XCTAssertTrue(store.performMapCommand(.mapPrimaryAction))
        XCTAssertNil(store.roadConnectionRecovery)
        XCTAssertTrue(store.roadConnectionRecoveryRoute.isEmpty)
        XCTAssertNil(store.roadConnectionPlanPresentation)
        XCTAssertEqual(store.interactionMode, .build(.commercial))
        XCTAssertEqual(store.selectedTool, .commercial)
        XCTAssertEqual(store.selectedCoordinate, blockedCoordinate)
        XCTAssertEqual(store.state.tile(at: blockedCoordinate)?.kind, .empty)
        XCTAssertEqual(
            store.state.treasury,
            treasury - Double(4 * BuildingKind.road.buildCost)
        )
        XCTAssertTrue(store.activeMapActionTargetPresentation?.primaryAction.isAvailable == true)
        XCTAssertTrue(store.lastFeedback?.contains("Street connected · Commercial is ready") == true)
        XCTAssertEqual(store.lastFeedbackTone, .positive)
        XCTAssertTrue(store.canUndo)
    }

    @MainActor
    func testCityStreetRecoveryBuildsTheWholePlannedRouteAsOneUndoableAction() throws {
        var authored = CityGameState.newCity(seed: 42)
        authored.treasury = 100_000
        for coordinate in authored.tiles.map(\.coordinate) {
            authored.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }

        let cityHall = GridCoordinate(x: 2, y: 2)
        let connectedRoad = GridCoordinate(x: 3, y: 2)
        let isolatedRoad = GridCoordinate(x: 8, y: 2)
        let blockedCoordinate = GridCoordinate(x: 8, y: 3)
        authored.updateTile(at: cityHall) {
            $0 = CityTile(coordinate: cityHall, kind: .cityHall, constructionProgress: 1)
        }
        authored.updateTile(at: connectedRoad) {
            $0 = CityTile(coordinate: connectedRoad, kind: .road, constructionProgress: 1)
        }
        authored.updateTile(at: isolatedRoad) {
            $0 = CityTile(coordinate: isolatedRoad, kind: .road, constructionProgress: 1)
        }

        let store = CityGameStore(state: authored)
        store.selectTool(.commercial)
        store.selectedCoordinate = blockedCoordinate
        store.clearFeedback()
        let recovery = try XCTUnwrap(
            store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.recovery
        )
        XCTAssertTrue(store.performBuildRecovery(recovery))

        let route = store.roadConnectionRecoveryRoute
        let selectedRoad = store.selectedCoordinate
        XCTAssertEqual(route.count, 4)
        XCTAssertTrue(store.canBuildRoadConnectionPlan)
        XCTAssertEqual(
            store.roadConnectionPlanPresentation?.buildActionHint,
            "Builds all 4 blocks for $480 as one reversible construction action."
        )

        XCTAssertTrue(store.buildRoadConnectionPlan())
        XCTAssertTrue(route.allSatisfy { store.state.tile(at: $0)?.kind == .road })
        XCTAssertEqual(
            store.state.treasury,
            authored.treasury - Double(route.count) * BuildingKind.road.buildCost
        )
        XCTAssertNil(store.roadConnectionRecovery)
        XCTAssertTrue(store.roadConnectionRecoveryRoute.isEmpty)
        XCTAssertEqual(store.interactionMode, .build(.commercial))
        XCTAssertEqual(store.selectedTool, .commercial)
        XCTAssertEqual(store.selectedCoordinate, blockedCoordinate)
        XCTAssertTrue(store.activeMapActionTargetPresentation?.primaryAction.isAvailable == true)
        XCTAssertEqual(
            store.lastFeedback,
            "4-block street route built · Commercial is ready at block 9, 4"
        )
        XCTAssertTrue(store.canUndo)

        XCTAssertTrue(store.perform(.undo))
        XCTAssertEqual(store.state, authored)
        XCTAssertEqual(
            store.roadConnectionRecovery,
            CityRoadConnectionRecovery(
                blockedKind: .commercial,
                blockedCoordinate: blockedCoordinate
            )
        )
        XCTAssertEqual(store.roadConnectionRecoveryRoute, route)
        XCTAssertEqual(store.interactionMode, .build(.road))
        XCTAssertEqual(store.selectedTool, .road)
        XCTAssertEqual(store.selectedCoordinate, selectedRoad)
        XCTAssertEqual(store.roadConnectionPlanPresentation?.remainingBlocks, 4)
        XCTAssertEqual(store.lastFeedback, "Street route undone · 4 blocks restored to plan")
        XCTAssertFalse(store.canUndo)
    }

    @MainActor
    func testCityStreetRecoveryRejectsAnUnfundedWholeRouteWithoutPartialConstruction() throws {
        var authored = CityGameState.newCity(seed: 42)
        authored.treasury = 100_000
        for coordinate in authored.tiles.map(\.coordinate) {
            authored.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }

        let cityHall = GridCoordinate(x: 2, y: 2)
        let connectedRoad = GridCoordinate(x: 3, y: 2)
        let isolatedRoad = GridCoordinate(x: 8, y: 2)
        let blockedCoordinate = GridCoordinate(x: 8, y: 3)
        authored.updateTile(at: cityHall) {
            $0 = CityTile(coordinate: cityHall, kind: .cityHall, constructionProgress: 1)
        }
        authored.updateTile(at: connectedRoad) {
            $0 = CityTile(coordinate: connectedRoad, kind: .road, constructionProgress: 1)
        }
        authored.updateTile(at: isolatedRoad) {
            $0 = CityTile(coordinate: isolatedRoad, kind: .road, constructionProgress: 1)
        }

        let store = CityGameStore(state: authored)
        store.selectTool(.commercial)
        store.selectedCoordinate = blockedCoordinate
        let recovery = try XCTUnwrap(
            store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.recovery
        )
        XCTAssertTrue(store.performBuildRecovery(recovery))
        store.state.treasury = 3 * BuildingKind.road.buildCost
        store.clearFeedback()
        let stateBeforeAttempt = store.state
        let routeBeforeAttempt = store.roadConnectionRecoveryRoute

        XCTAssertFalse(store.canBuildRoadConnectionPlan)
        XCTAssertEqual(store.roadConnectionPlanPresentation?.fundingGap, BuildingKind.road.buildCost)
        XCTAssertEqual(
            store.roadConnectionPlanPresentation?.buildActionHint,
            "Needs $120 more to build all 4 blocks without a partial route."
        )
        XCTAssertFalse(store.buildRoadConnectionPlan())
        XCTAssertEqual(store.state, stateBeforeAttempt)
        XCTAssertEqual(store.roadConnectionRecoveryRoute, routeBeforeAttempt)
        XCTAssertTrue(routeBeforeAttempt.allSatisfy {
            store.state.tile(at: $0)?.kind == .empty
        })
        XCTAssertEqual(store.lastFeedback, "Route needs $120 more · no street construction was committed")
        XCTAssertFalse(store.canUndo)
    }

    @MainActor
    func testCityStreetRecoveryBuildsAFundedRouteWithoutPretendingTheDestinationIsFunded() throws {
        var authored = CityGameState.newCity(seed: 42)
        authored.treasury = 100_000
        for coordinate in authored.tiles.map(\.coordinate) {
            authored.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }

        let cityHall = GridCoordinate(x: 2, y: 2)
        let connectedRoad = GridCoordinate(x: 3, y: 2)
        let isolatedRoad = GridCoordinate(x: 8, y: 2)
        let blockedCoordinate = GridCoordinate(x: 8, y: 3)
        authored.updateTile(at: cityHall) {
            $0 = CityTile(coordinate: cityHall, kind: .cityHall, constructionProgress: 1)
        }
        authored.updateTile(at: connectedRoad) {
            $0 = CityTile(coordinate: connectedRoad, kind: .road, constructionProgress: 1)
        }
        authored.updateTile(at: isolatedRoad) {
            $0 = CityTile(coordinate: isolatedRoad, kind: .road, constructionProgress: 1)
        }

        let store = CityGameStore(state: authored)
        store.selectTool(.commercial)
        store.selectedCoordinate = blockedCoordinate
        let recovery = try XCTUnwrap(
            store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.recovery
        )
        XCTAssertTrue(store.performBuildRecovery(recovery))
        store.state.treasury = 500
        store.clearFeedback()

        XCTAssertTrue(store.canBuildRoadConnectionPlan)
        XCTAssertTrue(store.buildRoadConnectionPlan())
        XCTAssertEqual(store.state.treasury, 20)
        XCTAssertEqual(store.interactionMode, .build(.commercial))
        XCTAssertEqual(
            store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.disabledReason,
            BuildRejection.insufficientFunds.message
        )
        XCTAssertEqual(store.lastFeedback, "4-block street route built · Commercial needs $2,380 more")
        XCTAssertTrue(store.canUndo)
    }

    @MainActor
    func testCancellingCityStreetRecoveryRestoresTheBlockedDevelopmentDecision() throws {
        var authored = CityGameState.newCity(seed: 42)
        authored.treasury = 100_000
        for coordinate in authored.tiles.map(\.coordinate) {
            authored.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }

        let cityHall = GridCoordinate(x: 2, y: 2)
        let connectedRoad = GridCoordinate(x: 3, y: 2)
        let isolatedRoad = GridCoordinate(x: 8, y: 2)
        let blockedCoordinate = GridCoordinate(x: 8, y: 3)
        authored.updateTile(at: cityHall) {
            $0 = CityTile(coordinate: cityHall, kind: .cityHall, constructionProgress: 1)
        }
        authored.updateTile(at: connectedRoad) {
            $0 = CityTile(coordinate: connectedRoad, kind: .road, constructionProgress: 1)
        }
        authored.updateTile(at: isolatedRoad) {
            $0 = CityTile(coordinate: isolatedRoad, kind: .road, constructionProgress: 1)
        }

        let store = CityGameStore(state: authored)
        store.selectTool(.commercial)
        store.selectedCoordinate = blockedCoordinate
        store.clearFeedback()
        let recovery = try XCTUnwrap(
            store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.recovery
        )

        XCTAssertTrue(store.performBuildRecovery(recovery))
        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertEqual(store.state, authored)
        XCTAssertNil(store.roadConnectionRecovery)
        XCTAssertTrue(store.roadConnectionRecoveryRoute.isEmpty)
        XCTAssertNil(store.roadConnectionPlanPresentation)
        XCTAssertEqual(store.interactionMode, .build(.commercial))
        XCTAssertEqual(store.selectedTool, .commercial)
        XCTAssertEqual(store.selectedCoordinate, blockedCoordinate)
        XCTAssertEqual(store.state.tile(at: blockedCoordinate)?.kind, .empty)
        XCTAssertFalse(store.activeMapActionTargetPresentation?.primaryAction.isAvailable ?? true)
        XCTAssertEqual(
            store.activeMapActionTargetPresentation?.primaryAction.buildDecision?.disabledReason,
            BuildRejection.cityRoadConnectionRequired.message
        )
        XCTAssertFalse(store.canUndo)
        XCTAssertEqual(
            store.lastFeedback,
            "Street connection paused · Commercial decision restored"
        )
        XCTAssertEqual(store.lastFeedbackTone, .neutral)
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
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertEqual(store.hudContextScope, .selection)
        XCTAssertTrue(
            store.activeMapActionTargetPresentation?.primaryAction.name.hasPrefix(
                "Inspect Commercial"
            ) == true
        )
        XCTAssertTrue(store.canUndo)

        XCTAssertTrue(store.perform(.undo))
        XCTAssertEqual(store.state, stateBefore)
    }

    @MainActor
    func testCancellingOrdinaryBuildDecisionReturnsToTheSameOpportunityLoop() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        store.selectTool(.commercial)
        let inventory = try XCTUnwrap(
            CityBuildOpportunityInventory.make(kind: .commercial, in: store.state)
        )
        let first = try XCTUnwrap(inventory.outlinedCoordinates.first)
        let second = try XCTUnwrap(inventory.outlinedCoordinates.dropFirst().first)
        let stateBefore = store.state
        let fingerprintBefore = try CityStateFingerprinter.fingerprint(stateBefore)

        XCTAssertNotNil(store.acceptPointerMapActionCandidate(first)?.primaryAction.buildDecision)
        XCTAssertEqual(store.interactionMode, .build(.commercial))
        XCTAssertEqual(store.selectedCoordinate, first)

        let focusBefore = store.mapFocusRequestGeneration
        XCTAssertTrue(store.perform(.cancelInteraction))

        XCTAssertEqual(store.state, stateBefore)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(store.state),
            fingerprintBefore
        )
        XCTAssertEqual(store.interactionMode, .build(.commercial))
        XCTAssertEqual(store.selectedTool, .commercial)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.hudContextScope, .city)
        XCTAssertFalse(store.showInspector)
        XCTAssertFalse(store.canUndo)
        XCTAssertEqual(store.mapFocusRequestGeneration, focusBefore + 1)
        XCTAssertEqual(
            store.lastFeedback,
            "Commercial remains selected · choose another block"
        )
        XCTAssertEqual(
            CityBuildOpportunityInventory.make(kind: .commercial, in: store.state),
            inventory
        )

        let secondDecision = try XCTUnwrap(
            store.acceptPointerMapActionCandidate(second)?.primaryAction.buildDecision
        )
        XCTAssertEqual(store.selectedCoordinate, second)
        let comparison = try XCTUnwrap(secondDecision.siteComparison)
        XCTAssertEqual(comparison.referenceTarget, "Block \(first.x + 1), \(first.y + 1)")
        XCTAssertTrue(secondDecision.accessibilitySummary.contains(comparison.accessibilitySummary))
        XCTAssertEqual(store.state, stateBefore)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(store.state),
            fingerprintBefore
        )
        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertEqual(store.interactionMode, .build(.commercial))
        XCTAssertNil(store.selectedCoordinate)

        XCTAssertTrue(store.perform(.cancelInteraction))
        XCTAssertEqual(store.interactionMode, .inspect)
        XCTAssertNil(store.selectedCoordinate)
        XCTAssertEqual(store.state, stateBefore)
    }

    @MainActor
    func testDevelopmentSiteComparisonClearsAfterToolChangeAndCommittedBuild() throws {
        let store = CityGameStore(state: .newCity(seed: 42))
        store.selectTool(.commercial)
        let commercialSites = try XCTUnwrap(
            CityBuildOpportunityInventory.make(kind: .commercial, in: store.state)
        ).outlinedCoordinates
        let first = try XCTUnwrap(commercialSites.first)
        let second = try XCTUnwrap(commercialSites.dropFirst().first)

        XCTAssertNotNil(store.acceptPointerMapActionCandidate(first))
        store.cancelBuildDecision()
        XCTAssertNotNil(
            store.acceptPointerMapActionCandidate(second)?
                .primaryAction.buildDecision?.siteComparison
        )

        store.selectTool(.residential)
        let residential = try XCTUnwrap(
            CityBuildOpportunityInventory.make(kind: .residential, in: store.state)?
                .outlinedCoordinates.first
        )
        XCTAssertNil(
            store.acceptPointerMapActionCandidate(residential)?
                .primaryAction.buildDecision?.siteComparison
        )

        store.selectTool(.commercial)
        XCTAssertNotNil(store.acceptPointerMapActionCandidate(first))
        store.cancelBuildDecision()
        XCTAssertNotNil(
            store.acceptPointerMapActionCandidate(second)?
                .primaryAction.buildDecision?.siteComparison
        )
        let stateBeforeBuild = store.state
        XCTAssertTrue(store.performMapCommand(.mapPrimaryAction))
        XCTAssertTrue(store.perform(.undo))
        XCTAssertEqual(store.state, stateBeforeBuild)

        store.interactionMode = .build(.commercial)
        XCTAssertNil(
            store.acceptPointerMapActionCandidate(first)?
                .primaryAction.buildDecision?.siteComparison
        )
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
            "Regional Grid Mandate", "Regional Freight Overload",
            "Regional Qualification Interrupted", "Town Charter Qualification Interrupted"
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
    func testSelectedProblemBlockPrioritizesDiagnosisAndDemotesDemolition() {
        XCTAssertEqual(
            InspectorView.selectionActionOrder(
                for: .residential,
                diagnosisAvailable: true
            ),
            [.diagnosis, .siteActions]
        )
        XCTAssertEqual(
            InspectorView.selectionActionOrder(
                for: .road,
                diagnosisAvailable: true
            ),
            [.diagnosis, .nextAction, .siteActions]
        )
        XCTAssertEqual(
            InspectorView.selectionActionOrder(
                for: .cityHall,
                diagnosisAvailable: true
            ),
            [.diagnosis, .nextAction]
        )
        XCTAssertEqual(
            InspectorView.selectionActionOrder(
                for: .empty,
                diagnosisAvailable: false
            ),
            [.nextAction]
        )
        XCTAssertEqual(
            InspectorView.selectionActionOrder(
                for: .residential,
                diagnosisAvailable: false
            ),
            [.siteActions]
        )
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
        var state = try XCTUnwrap(
            ProductionStoryStateBuilder().buildAll().first {
                $0.definition.strategy == .commercialStewardship
                    && $0.definition.moment == .complication
            }?.state
        )
        state.messages.insert(
            CityMessage(
                tick: state.tick,
                severity: .warning,
                title: "Severe Storm",
                detail: "Emergency repairs cost $2,000 and happiness fell 3 points."
            ),
            at: 0
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
        if let path = ProcessInfo.processInfo.environment["CITYSIM_STRATEGY_HUD_REGULAR_PROOF"] {
            let data = try XCTUnwrap(regular.representation(using: .png, properties: [:]))
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
    func testCompactFinancePutsTheTaxDecisionInTheFirstVisibleRow() throws {
        XCTAssertEqual(
            InspectorView.financeCardOrder(compact: true, projectedBalance: -168),
            [.taxPolicy, .decisionSupport, .nextCycle, .treasury]
        )
        XCTAssertEqual(
            InspectorView.financeCardOrder(compact: true, projectedBalance: 20),
            [.taxPolicy, .treasury, .nextCycle, .decisionSupport]
        )
        XCTAssertEqual(
            InspectorView.financeCardOrder(compact: false, projectedBalance: -168),
            [.treasury, .nextCycle, .taxPolicy, .decisionSupport]
        )

        var state = CityGameState.newCity(seed: 42)
        let damagedRoad = try XCTUnwrap(state.tiles.first { $0.kind == .road }?.coordinate)
        state.updateTile(at: damagedRoad) { $0.condition = 0.40 }
        let serviceSite = GridCoordinate(x: 5, y: 10)
        state.updateTile(at: serviceSite) {
            $0 = CityTile(coordinate: serviceSite, kind: .fireStation)
        }
        let store = CityGameStore(state: state)
        store.openInspector(.finances)
        let size = CGSize(width: 854, height: BuildToolbarView.compactDetailsMaxHeight)
        let finance = try bitmap(
            of: InspectorView(store: store, compact: true)
                .frame(width: size.width, height: size.height, alignment: .top),
            size: size
        )

        XCTAssertEqual(finance.size.height, BuildToolbarView.compactDetailsMaxHeight, accuracy: 0.5)
        XCTAssertEqual(store.inspectorSection, .finances)
        let backlog = CityRoadMaintenanceBacklog.make(in: store.state)
        XCTAssertEqual(backlog.damagedCount, 1)
        XCTAssertEqual(backlog.actionTitle, "Resurface 1 · $80")
        XCTAssertTrue(backlog.canAffordResurfacing)
        let standardServiceCoverage = CityCivicServiceAnalysis(state: store.state)
            .citywideResidentialCoverage
        XCTAssertGreaterThan(standardServiceCoverage, 0)
        XCTAssertEqual(CitySimulation.projectedCivicServiceUpkeep(in: store.state), 144)

        let routineBalance = store.analytics.projectedBalance
        store.setRoadMaintenancePolicy(.preventive)
        store.setCivicServiceFundingPolicy(.expanded)
        XCTAssertLessThan(store.analytics.projectedBalance, routineBalance)
        XCTAssertEqual(store.state.effectiveRoadMaintenancePolicy, .preventive)
        XCTAssertEqual(store.state.effectiveCivicServiceFundingPolicy, .expanded)
        XCTAssertGreaterThan(
            CityCivicServiceAnalysis(state: store.state).citywideResidentialCoverage,
            standardServiceCoverage
        )
        let fundedCompact = try bitmap(
            of: InspectorView(store: store, compact: true)
                .frame(width: size.width, height: size.height, alignment: .top),
            size: size
        )
        XCTAssertEqual(fundedCompact.size.height, BuildToolbarView.compactDetailsMaxHeight, accuracy: 0.5)

        let regularSize = CGSize(width: 1_120, height: 240)
        let fundedRegular = try bitmap(
            of: InspectorView(store: store, compact: false)
                .frame(width: regularSize.width, height: regularSize.height, alignment: .top),
            size: regularSize
        )
        XCTAssertEqual(fundedRegular.size.width, regularSize.width, accuracy: 0.5)
        if let path = ProcessInfo.processInfo.environment["CITYSIM_SERVICE_FUNDING_COMPACT_PROOF"] {
            let data = try XCTUnwrap(fundedCompact.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        if let path = ProcessInfo.processInfo.environment["CITYSIM_SERVICE_FUNDING_REGULAR_PROOF"] {
            let data = try XCTUnwrap(fundedRegular.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        store.resurfaceDamagedRoads()
        XCTAssertEqual(CityRoadMaintenanceBacklog.make(in: store.state).damagedCount, 0)
        XCTAssertEqual(store.state.tile(at: damagedRoad)?.condition, 1)
        XCTAssertTrue(store.canUndo)
        XCTAssertEqual(
            CityRoadMaintenancePolicy.allCases.map(\.title),
            ["Deferred", "Routine", "Preventive"]
        )
        XCTAssertEqual(
            CityRoadMaintenancePolicy.allCases.map(\.wearSummary),
            ["+45% wear", "baseline", "−50% wear"]
        )
    }

    func testFinanceDecisionSupportNamesTheFirstWholePercentThatRestoresCashflow() throws {
        var state = CityGameState.newCity(seed: 42)
        state.taxRate = 0.04
        let analytics = CityAnalytics(state: state)
        let recoveryRate = try XCTUnwrap(analytics.breakEvenTaxRate)
        let recoveryPercent = Int((recoveryRate * 100).rounded())

        XCTAssertGreaterThan(recoveryRate, state.taxRate)
        XCTAssertGreaterThanOrEqual(analytics.projectedBalance(atTaxRate: recoveryRate), 0)
        XCTAssertLessThan(
            analytics.projectedBalance(atTaxRate: Double(recoveryPercent - 1) / 100),
            0
        )

        let support = CityFinanceDecisionSupport.make(analytics: analytics)
        XCTAssertEqual(support.recoveryTaxRate, recoveryRate)
        XCTAssertTrue(support.detail.contains("\(recoveryPercent)% tax forecasts"))
        XCTAssertTrue(support.detail.contains("Higher tax cools demand"))
        XCTAssertTrue(support.accessibilityHint.contains("restore non-negative cashflow"))
        XCTAssertFalse(support.offersParkAlternative)
    }

    func testFinanceDecisionSupportFallsBackToTaxBaseOrUpkeepWhenTaxCannotCloseGap() {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = -1_000_000
        let analytics = CityAnalytics(state: state)
        let support = CityFinanceDecisionSupport.make(analytics: analytics)

        XCTAssertNil(analytics.breakEvenTaxRate)
        XCTAssertNil(support.recoveryTaxRate)
        XCTAssertTrue(support.detail.contains("Tax alone cannot close"))
        XCTAssertTrue(support.detail.contains("occupied homes or jobs"))
        XCTAssertTrue(support.detail.contains("remove unneeded upkeep"))
        XCTAssertFalse(support.offersParkAlternative)
    }

    func testFinanceDecisionSupportExplainsMainStreetConflictAndOffersParkRoute() throws {
        var state = CityGameState.newCity(seed: 42)
        state.taxRate = 0.04
        state.progression?.strategy = CityStrategyProgression(
            committedStrategy: .commercialStewardship,
            currentPhase: .complication,
            nextScheduledTick: state.tick + 40
        )
        let analytics = CityAnalytics(state: state)
        let support = CityFinanceDecisionSupport.make(analytics: analytics)

        XCTAssertGreaterThan(try XCTUnwrap(support.recoveryTaxRate), 0.09)
        XCTAssertTrue(support.detail.contains("ends the 9% tax-relief route"))
        XCTAssertTrue(support.detail.contains("Build a second park"))
        XCTAssertTrue(support.accessibilityHint.contains("conflicts with the 9% Main Street"))
        XCTAssertTrue(support.offersParkAlternative)
    }

    func testFinanceDecisionSupportStopsOfferingParkAfterMainStreetResponseIsLocked() {
        var state = CityGameState.newCity(seed: 42)
        state.taxRate = 0.04
        state.progression?.strategy = CityStrategyProgression(
            committedStrategy: .commercialStewardship,
            currentPhase: .recovery,
            nextScheduledTick: state.tick + 40,
            recoveryResolution: .commercialTaxRelief
        )
        let support = CityFinanceDecisionSupport.make(analytics: CityAnalytics(state: state))

        XCTAssertFalse(support.detail.contains("ends the 9% tax-relief route"))
        XCTAssertFalse(support.offersParkAlternative)
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
