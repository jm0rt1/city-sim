import Foundation
import XCTest
@testable import CitySimNative

final class GameplayLoopTests: XCTestCase {
    private let stormSeed: UInt64 = 3
    private let calmSeed: UInt64 = 0
    private let expectedStormSeed: UInt64 = 2_088_359_638_719_790_806
    private let expectedCalmSeed: UInt64 = 1_442_695_040_888_963_407
    private let expectedTargets = [
        GridCoordinate(x: 3, y: 10),
        GridCoordinate(x: 6, y: 10),
        GridCoordinate(x: 9, y: 10),
    ]

    func testThreeActCadenceCreatesThreeCommercialAndIndustrialDecisions() throws {
        var commerce = CityGameState.newCity(seed: 42)
        try buildFirstValid(.commercial, in: &commerce)
        try buildFirstValid(.commercial, in: &commerce)
        let commerceStart = commerce
        advanceToTick(&commerce, tick: 4)
        XCTAssertEqual(commerce.progression?.strategy?.committedStrategy, .commercialStewardship)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Main Street Crossroads" })
        let commerceOpportunity = advanceThroughStrategyPhase(&commerce, phase: .opportunity)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Market Weekend" && $0.detail.contains("$2,400") })
        let commerceComplication = advanceThroughStrategyPhase(&commerce, phase: .complication)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Chain Store Rumor" })
        let commerceSetback = advanceThroughStrategyPhase(&commerce, phase: .setback)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Storefront Slump" })
        try buildFirstValid(.park, in: &commerce)
        let commercePayoff = advanceThroughStrategyPhase(&commerce, phase: .recovery)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Main Street Rebound" })

        var industry = CityGameState.newCity(seed: 42)
        try buildFirstValid(.industrial, in: &industry)
        try buildFirstValid(.industrial, in: &industry)
        let industryStart = industry
        advanceToTick(&industry, tick: 4)
        XCTAssertEqual(industry.progression?.strategy?.committedStrategy, .industrialExpansion)
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Contract Watch" })
        _ = advanceThroughStrategyPhase(&industry, phase: .opportunity)
        XCTAssertTrue(industry.messages.contains { $0.title == "Regional Freight Contract" && $0.detail.contains("$6,500") })
        _ = advanceThroughStrategyPhase(&industry, phase: .complication)
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Load Forecast" })
        _ = advanceThroughStrategyPhase(&industry, phase: .setback)
        XCTAssertTrue(industry.messages.contains { $0.title == "Industrial Load Surge" })
        try prepareReserveUtilities(in: &industry)
        _ = advanceThroughStrategyPhase(&industry, phase: .recovery)
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Network Secured" })

        let beatTicks = [4, commerceOpportunity, commerceComplication, commerceSetback, commercePayoff]
        for gap in zip(beatTicks, beatTicks.dropFirst()).map({ $1 - $0 }) {
            XCTAssertLessThanOrEqual(Double(gap) * 0.42, 30)
        }
        XCTAssertGreaterThan(commerce.treasury, commerceStart.treasury - 8_000)
        XCTAssertGreaterThan(industry.treasury, industryStart.treasury - 12_000)
        XCTAssertGreaterThan(commerce.happiness, industry.happiness)
        XCTAssertGreaterThan(CityAnalytics(state: industry).pollutionPressure, CityAnalytics(state: commerce).pollutionPressure)
        XCTAssertGreaterThan(CityAnalytics(state: industry).jobCapacity, CityAnalytics(state: commerce).jobCapacity)
    }

    func testCostlyPreparationCanAvoidEitherStrategySetback() throws {
        var commerce = CityGameState.newCity(seed: 42)
        try buildFirstValid(.commercial, in: &commerce)
        commerce.taxRate = 0.09
        advanceToTick(&commerce, tick: 4)
        advanceThroughStrategyPhase(&commerce, phase: .opportunity)
        advanceThroughStrategyPhase(&commerce, phase: .complication)
        advanceThroughStrategyPhase(&commerce, phase: .setback)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Storefront Slump Avoided" })
        XCTAssertFalse(commerce.messages.contains { $0.title == "Storefront Slump" })
        XCTAssertLessThan(commerce.demand.residential, 0.8)

        var industry = CityGameState.newCity(seed: 42)
        try buildFirstValid(.industrial, in: &industry)
        advanceToTick(&industry, tick: 4)
        try prepareReserveUtilities(in: &industry)
        advanceThroughStrategyPhase(&industry, phase: .opportunity)
        advanceThroughStrategyPhase(&industry, phase: .complication)
        advanceThroughStrategyPhase(&industry, phase: .setback)
        XCTAssertTrue(industry.messages.contains { $0.title == "Industrial Load Absorbed" })
        XCTAssertFalse(industry.messages.contains { $0.title == "Industrial Load Surge" })
        XCTAssertGreaterThan(CityAnalytics(state: industry).projectedUpkeep, CityAnalytics(state: commerce).projectedUpkeep)
    }

    func testMaterialDecisionsProduceNumericalFeedbackWithinFifteenSeconds() throws {
        var commerce = CityGameState.newCity(seed: 42)
        let opening = CityAnalytics(state: commerce)
        let treasuryBeforeZone = commerce.treasury
        try buildFirstValid(.commercial, in: &commerce)
        XCTAssertEqual(commerce.treasury, treasuryBeforeZone - BuildingKind.commercial.buildCost)
        advanceToTick(&commerce, tick: 4)
        let afterZone = CityAnalytics(state: commerce)
        XCTAssertGreaterThan(afterZone.jobCapacity, opening.jobCapacity)
        XCTAssertGreaterThan(afterZone.projectedBalance, opening.projectedBalance)

        advanceThroughStrategyPhase(&commerce, phase: .opportunity)
        advanceThroughStrategyPhase(&commerce, phase: .complication)
        advanceThroughStrategyPhase(&commerce, phase: .setback)
        var noParkResponse = commerce
        let treasuryBeforePark = commerce.treasury
        try buildFirstValid(.park, in: &commerce)
        XCTAssertEqual(commerce.treasury, treasuryBeforePark - BuildingKind.park.buildCost)
        advance(&commerce, cycles: 1)
        advance(&noParkResponse, cycles: 1)
        XCTAssertGreaterThan(commerce.happiness, noParkResponse.happiness)

        var industry = CityGameState.newCity(seed: 42)
        try buildFirstValid(.industrial, in: &industry)
        advanceToTick(&industry, tick: 4)
        let powerBefore = industry.powerCapacity
        let treasuryBeforePower = industry.treasury
        try buildFirstValid(.powerPlant, in: &industry)
        XCTAssertEqual(industry.treasury, treasuryBeforePower - BuildingKind.powerPlant.buildCost)
        advance(&industry, cycles: 1)
        XCTAssertGreaterThan(industry.powerCapacity, powerBefore)

        // Each observation above occurs within one four-tick day: 1.68 seconds at 1x.
        XCTAssertLessThan(4.0 * 0.42, 15)
    }

    @MainActor
    func testGrowthEngineMakesTheFirstArcPrimaryAndActionable() throws {
        var commerce = CityGameState.newCity(seed: 42)
        try buildFirstValid(.commercial, in: &commerce)
        advanceToTick(&commerce, tick: 4)

        let commerceStore = CityGameStore(state: commerce)
        XCTAssertEqual(commerceStore.primaryObjective.id, "strategy")
        XCTAssertEqual(commerceStore.primaryObjective.title, "Protect Main Street")
        XCTAssertEqual(commerceStore.primaryObjective.progress, 0.25, accuracy: 0.001)
        XCTAssertTrue(commerceStore.primaryObjective.remaining.contains("Chain-store pressure arrives in 16 days"))
        XCTAssertTrue(commerceStore.primaryObjective.remaining.contains("Lower tax to 9% or build a second park"))

        advanceToTick(&commerceStore.state, tick: 68)
        XCTAssertEqual(commerceStore.primaryObjective.progress, 0.50, accuracy: 0.001)
        XCTAssertTrue(commerceStore.primaryObjective.remaining.contains("Chain-store pressure arrives in 16 days"))

        var commerceRecovery = commerce
        advanceThroughStrategyPhase(&commerceRecovery, phase: .opportunity)
        advanceThroughStrategyPhase(&commerceRecovery, phase: .complication)
        advanceThroughStrategyPhase(&commerceRecovery, phase: .setback)
        let commerceRecoveryObjective = CityGameStore(state: commerceRecovery).primaryObjective
        XCTAssertEqual(commerceRecoveryObjective.title, "Recover Main Street")
        XCTAssertTrue(commerceRecoveryObjective.remaining.contains("The storefront slump cost $3,000 and 5 happiness"))
        XCTAssertTrue(commerceRecoveryObjective.remaining.contains("Lower tax to 9% or build a second park within 16 days"))

        var industry = CityGameState.newCity(seed: 42)
        try buildFirstValid(.industrial, in: &industry)
        advanceToTick(&industry, tick: 4)
        let industryStore = CityGameStore(state: industry)
        XCTAssertEqual(industryStore.primaryObjective.title, "Secure the Freight Network")
        XCTAssertTrue(industryStore.primaryObjective.remaining.contains("Add a second Power Plant and Water Tower"))

        advanceThroughStrategyPhase(&industry, phase: .opportunity)
        advanceThroughStrategyPhase(&industry, phase: .complication)
        advanceThroughStrategyPhase(&industry, phase: .setback)
        let industryRecoveryObjective = CityGameStore(state: industry).primaryObjective
        XCTAssertEqual(industryRecoveryObjective.title, "Recover the Freight Network")
        XCTAssertTrue(industryRecoveryObjective.remaining.contains("The freight load cost $5,500 and 8 happiness"))
        XCTAssertTrue(industryRecoveryObjective.remaining.contains("Add a second Power Plant and Water Tower, or build a second park within 16 days"))
    }

    func testDemandDrivenDevelopmentCreatesVariedLevelsForBothStrategies() throws {
        var commerce = try commercialStrategy()
        var industry = try industrialStrategy()

        advanceToTick(&commerce, tick: 64)
        advanceToTick(&industry, tick: 64)
        XCTAssertEqual(commerce.progression?.strategy?.committedStrategy, .commercialStewardship)
        XCTAssertEqual(industry.progression?.strategy?.committedStrategy, .industrialExpansion)
        XCTAssertFalse(
            commerce.tiles.contains { $0.kind == .commercial && $0.level > 1 },
            "A thin utility reserve should delay Commercial density"
        )
        XCTAssertFalse(
            industry.tiles.contains { $0.kind == .industrial && $0.level > 1 },
            "A thin utility reserve should delay Industrial density"
        )

        try prepareReserveUtilities(in: &commerce)
        try prepareReserveUtilities(in: &industry)
        advanceToTick(&commerce, tick: 128)
        advanceToTick(&industry, tick: 128)
        XCTAssertFalse(
            commerce.tiles.contains { $0.kind == .commercial && $0.level > 1 },
            "Commercial density still needs its supporting recovery decision"
        )
        XCTAssertTrue(
            industry.tiles.contains { $0.kind == .industrial && $0.level > 1 },
            "Player-funded reserve utilities should let Industrial develop first at tick 128"
        )
        XCTAssertTrue(industry.messages.contains {
            $0.title == "Neighborhood Upgraded" && $0.tick == 128
        })

        advanceToTick(&commerce, tick: 256)
        advanceToTick(&industry, tick: 256)
        XCTAssertFalse(
            commerce.tiles.contains { $0.kind == .commercial && $0.level > 1 },
            "Commercial should not develop at the obsolete tick-256 checkpoint"
        )
        advanceToTick(&commerce, tick: 384)
        XCTAssertTrue(
            commerce.tiles.contains { $0.kind == .commercial && $0.level > 1 },
            "Commercial occupancy, demand, and recovery should change an actual storefront at tick 384: \(scenarioSummary(commerce))"
        )
        XCTAssertTrue(
            industry.tiles.contains { $0.kind == .industrial && $0.level > 1 },
            "Industrial occupancy and demand should change an actual factory: \(scenarioSummary(industry))"
        )
        for (state, kind) in [(commerce, BuildingKind.commercial), (industry, .industrial)] {
            let developed = try XCTUnwrap(
                state.tiles.first { $0.kind == kind && $0.level > 1 }
            )
            XCTAssertTrue(state.messages.contains {
                $0.title == "Neighborhood Upgraded"
                    && $0.detail.contains(
                        "block \(developed.coordinate.x + 1), \(developed.coordinate.y + 1)"
                    )
            })
        }

        for state in [commerce, industry] {
            let levels = Set(
                state.tiles
                    .filter { [.residential, .commercial, .industrial].contains($0.kind) }
                    .map(\.level)
            )
            XCTAssertGreaterThanOrEqual(levels.count, 2)
            XCTAssertTrue(state.messages.contains {
                $0.title == "Neighborhood Upgraded"
                    && $0.detail.contains("occupancy and demand")
                    && $0.detail.contains("utility load")
            })
        }
    }

    func testIndustrialDemandUsesEmploymentPressureNotLatentHousing() throws {
        var baseline = CityGameState.newCity(seed: 42)
        var additionalHousing = baseline
        let coordinate = try firstValidCoordinate(for: .residential, in: additionalHousing)
        additionalHousing.updateTile(at: coordinate) {
            $0.kind = .residential
            $0.constructionProgress = 1
            $0.level = 1
            $0.condition = 1
        }

        CitySimulation.step(&baseline)
        CitySimulation.step(&additionalHousing)

        let jobCapacity = CitySimulation.jobCapacity(in: baseline)
        let workforceTarget = max(1, baseline.population * 7 / 10)
        let employment = min(1, Double(baseline.jobs) / Double(workforceTarget))
        let utilization = min(
            1,
            Double(baseline.jobs) / Double(max(1, jobCapacity))
        )
        let active = CitySimulation.activeTiles(in: baseline)
        let industrial = active.filter { $0.kind == .industrial }
        let industrialLevelGrowth = industrial.reduce(0) {
            $0 + max(0, $1.level - 1)
        }
        let pollution = min(
            26,
            Double(industrial.count) * 3.5
                + Double(industrialLevelGrowth) * 0.5
                + Double(active.filter { $0.kind == .powerPlant }.count) * 4
        )
        let expected = min(
            1,
            max(
                0,
                0.36 + employment * utilization * 0.35
                    + max(0, 1 - employment) * 0.65
                    - pollution / 140
                    - max(0, baseline.taxRate - 0.10)
            )
        )

        XCTAssertEqual(baseline.demand.industrial, expected, accuracy: 0.000_001)
        XCTAssertEqual(
            additionalHousing.demand.industrial,
            baseline.demand.industrial,
            accuracy: 0.000_001,
            "Latent Residential capacity must not create Industrial labor demand"
        )
        XCTAssertLessThan(
            additionalHousing.demand.residential,
            baseline.demand.residential,
            "Actual additional housing vacancy should still affect Residential demand"
        )
    }

    func testDevelopedLevelsCarryUtilityUpkeepAndPollutionTradeoffs() throws {
        var baseline = CityGameState.newCity(seed: 42)
        advanceDays(&baseline, days: 1)

        var commercialDensity = baseline
        let commercialIndex = try XCTUnwrap(
            commercialDensity.tiles.firstIndex { $0.kind == .commercial }
        )
        commercialDensity.tiles[commercialIndex].level = 2
        let commercialUpkeep = CitySimulation.projectedUpkeep(in: commercialDensity)
        let baselineUpkeep = CitySimulation.projectedUpkeep(in: baseline)
        XCTAssertGreaterThan(
            CitySimulation.projectedRevenue(in: commercialDensity),
            CitySimulation.projectedRevenue(in: baseline)
        )
        CitySimulation.step(&baseline)
        CitySimulation.step(&commercialDensity)
        XCTAssertEqual(commercialDensity.powerUsed - baseline.powerUsed, 2)
        XCTAssertEqual(commercialDensity.waterUsed - baseline.waterUsed, 1)
        XCTAssertGreaterThan(commercialUpkeep, baselineUpkeep)

        var industrialDensity = baseline
        let industrialIndex = try XCTUnwrap(
            industrialDensity.tiles.firstIndex { $0.kind == .industrial }
        )
        industrialDensity.tiles[industrialIndex].level = 2
        CitySimulation.step(&industrialDensity)
        XCTAssertEqual(industrialDensity.powerUsed - baseline.powerUsed, 2)
        XCTAssertEqual(industrialDensity.waterUsed - baseline.waterUsed, 1)
        XCTAssertGreaterThan(
            CityAnalytics(state: industrialDensity).pollutionPressure,
            CityAnalytics(state: baseline).pollutionPressure
        )
    }

    func testLiveCommercialRecoveryReachesACharterPathByDay128() throws {
        var state = CityGameState.newCity(seed: 42)
        advanceToTick(&state, tick: 60)
        try buildFirstValid(.commercial, in: &state)
        advance(&state, cycles: 4)
        try buildFirstValid(.powerPlant, in: &state)
        state.taxRate = 0.14
        advanceToTick(&state, tick: 509)

        let analytics = CityAnalytics(state: state)
        XCTAssertTrue(state.messages.contains { $0.title == "Main Street Crossroads" })
        XCTAssertTrue(state.messages.contains { $0.title == "Main Street Recovery Delayed" })
        XCTAssertGreaterThan(analytics.projectedBalance, 0)
        XCTAssertGreaterThanOrEqual(state.treasury, BuildingKind.waterTower.buildCost)
        XCTAssertEqual(analytics.waterHeadroom, 0)
        XCTAssertTrue(analytics.townCharterStatusText.contains("add water capacity"))
        XCTAssertGreaterThanOrEqual(state.population, 390)

        try buildFirstValid(.waterTower, in: &state)
        advanceUntil(&state, maximumCycles: 40) {
            $0.treasury >= BuildingKind.commercial.buildCost
        }
        try buildFirstValid(.commercial, in: &state)
        state.taxRate = 0.10
        advanceUntil(&state, maximumCycles: 240) {
            $0.progression?.townCharterAwarded == true
        }

        XCTAssertTrue(state.progression?.townCharterAwarded ?? false)
        XCTAssertLessThanOrEqual(state.tick, 2_200)
        XCTAssertEqual(state.status, .playing)
        XCTAssertEqual(state.progression?.secondAct?.phase, .mandate)
    }

    func testBothDiscoverableStrategiesReachDurablePayoffWithInteractionMargin() throws {
        var commerce = CityGameState.newCity(seed: 42)
        advanceToTick(&commerce, tick: 60)
        try buildFirstValid(.commercial, in: &commerce)
        advanceToTick(&commerce, tick: 64)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Main Street Crossroads" })
        advanceThroughStrategyPhase(&commerce, phase: .opportunity)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Market Weekend" })
        advanceThroughStrategyPhase(&commerce, phase: .complication)
        advanceThroughStrategyPhase(&commerce, phase: .setback)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Storefront Slump" })
        try buildFirstValid(.park, in: &commerce)
        advanceThroughStrategyPhase(&commerce, phase: .recovery)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Main Street Rebound" })
        try prepareCharterCapacity(in: &commerce, jobs: .commercial)
        commerce.taxRate = 0.10
        let commerceAwardTick = advanceUntil(&commerce, maximumCycles: 430) {
            $0.progression?.townCharterAwarded == true
        }

        var industry = CityGameState.newCity(seed: 42)
        advanceToTick(&industry, tick: 60)
        try buildFirstValid(.industrial, in: &industry)
        advanceToTick(&industry, tick: 64)
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Contract Watch" })
        advanceThroughStrategyPhase(&industry, phase: .opportunity)
        XCTAssertTrue(industry.messages.contains { $0.title == "Regional Freight Contract" })
        advanceThroughStrategyPhase(&industry, phase: .complication)
        advanceThroughStrategyPhase(&industry, phase: .setback)
        XCTAssertTrue(industry.messages.contains { $0.title == "Industrial Load Surge" })
        try prepareReserveUtilities(in: &industry)
        advanceThroughStrategyPhase(&industry, phase: .recovery)
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Network Secured" })
        try prepareCharterCapacity(in: &industry, jobs: .industrial)
        industry.taxRate = 0.10
        let industryAwardTick = advanceUntil(&industry, maximumCycles: 430) {
            $0.progression?.townCharterAwarded == true
        }

        XCTAssertLessThanOrEqual(commerceAwardTick, 2_200)
        XCTAssertLessThanOrEqual(industryAwardTick, 2_200)
        XCTAssertEqual(commerceAwardTick, 844)
        XCTAssertEqual(industryAwardTick, 868, "The deterministic first severe storm and recovery add 24 ticks.")
        XCTAssertGreaterThan(commerce.happiness, industry.happiness)
        XCTAssertGreaterThan(CityAnalytics(state: industry).pollutionPressure, CityAnalytics(state: commerce).pollutionPressure)
        XCTAssertGreaterThan(CityAnalytics(state: industry).jobCapacity, CityAnalytics(state: commerce).jobCapacity)
        XCTAssertTrue(commerce.progression?.townCharterAwarded ?? false)
        XCTAssertTrue(industry.progression?.townCharterAwarded ?? false)
        XCTAssertEqual(commerce.status, .playing)
        XCTAssertEqual(industry.status, .playing)
        XCTAssertEqual(commerce.progression?.secondAct?.phase, .mandate)
        XCTAssertEqual(industry.progression?.secondAct?.phase, .mandate)
    }

    func testOpeningExposesARealButRecoverableTradeoff() {
        let state = CityGameState.newCity(seed: 42)
        let analytics = CityAnalytics(state: state)

        XCTAssertEqual(state.treasury, 32_000)
        XCTAssertEqual(state.population, 300)
        XCTAssertEqual(analytics.jobShortfall, 20)
        XCTAssertEqual(analytics.powerHeadroom, 54)
        XCTAssertEqual(analytics.waterHeadroom, 48)
        XCTAssertEqual(analytics.employmentRate, 190.0 / 210.0, accuracy: 0.000_001)
        XCTAssertEqual(analytics.utilityReserve, 48.0 / 270.0, accuracy: 0.000_001)
        XCTAssertEqual(state.taxRate, 0.10, accuracy: 0.000_001)
        XCTAssertEqual(analytics.projectedBalance, -126.2, accuracy: 0.001)
        XCTAssertEqual(analytics.operatingRunwayCycles ?? 0, 253.57, accuracy: 0.01)
        XCTAssertGreaterThan(state.demand.residential, 0.7)
        XCTAssertTrue(state.messages.contains { $0.title == "A Town at the Crossroads" })
    }

    func testIgnoredGrowthWarnsBeforeAUtilityShortfallAndCanRecover() throws {
        var state = CityGameState.newCity(seed: 42)

        advanceUntil(&state, maximumCycles: 120) {
            $0.messages.contains { $0.title == "Utility Shortfall" }
        }

        XCTAssertTrue(state.messages.contains { $0.title == "Utility Reserve Tight" })
        XCTAssertTrue(state.messages.contains { $0.title == "Hiring Bottleneck" })
        let shortfall = try XCTUnwrap(state.messages.first { $0.title == "Utility Shortfall" })
        XCTAssertTrue(shortfall.detail.contains("short by"))
        XCTAssertTrue(shortfall.detail.contains("Add both utility projects"))
        XCTAssertFalse(shortfall.detail.contains("Power or water"))
        XCTAssertLessThan(CityAnalytics(state: state).utilityCoverage, 0.98)
        XCTAssertEqual(state.status, .playing)

        state.taxRate = 0.18
        advance(&state, cycles: 24)
        try buildFirstValid(.powerPlant, in: &state)
        try buildFirstValid(.waterTower, in: &state)
        try buildFirstValid(.industrial, in: &state)
        advance(&state, cycles: 8)

        let recovered = CityAnalytics(state: state)
        XCTAssertEqual(recovered.utilityCoverage, 1, accuracy: 0.000_001)
        XCTAssertGreaterThan(recovered.utilityReserve, 0.4)
        XCTAssertGreaterThan(recovered.projectedBalance, 0)
        XCTAssertGreaterThan(state.treasury, 0)
        XCTAssertGreaterThan(state.happiness, 35)
        XCTAssertEqual(state.status, .playing)
    }

    func testTwoStrategiesReachVictoryAndRemainTerminalThroughTheTwentyMinuteHorizon() throws {
        var industryFirst = try industrialStrategy()
        advance(&industryFirst, cycles: 4)
        try buildFirstValid(.powerPlant, in: &industryFirst)
        try buildFirstValid(.waterTower, in: &industryFirst)
        advanceStrategyToCompletion(&industryFirst)

        var commerceAndTax = try commercialStrategy()
        commerceAndTax.taxRate = 0.10
        advanceToTick(&commerceAndTax, tick: 4)
        advanceThroughStrategyPhase(&commerceAndTax, phase: .opportunity)
        try buildFirstValid(.powerPlant, in: &commerceAndTax)
        try buildFirstValid(.waterTower, in: &commerceAndTax)
        advanceThroughStrategyPhase(&commerceAndTax, phase: .complication)
        advanceThroughStrategyPhase(&commerceAndTax, phase: .setback)
        commerceAndTax.taxRate = 0.09
        advanceThroughStrategyPhase(&commerceAndTax, phase: .recovery)

        XCTAssertTrue(industryFirst.messages.contains { $0.title == "Freight Network Secured" })
        XCTAssertTrue(commerceAndTax.messages.contains { $0.title == "Main Street Rebound" })
        commerceAndTax.taxRate = 0.10

        advanceUntil(&industryFirst, maximumCycles: 430) {
            $0.progression?.townCharterAwarded == true
        }
        advanceUntil(&commerceAndTax, maximumCycles: 430) {
            $0.progression?.townCharterAwarded == true
        }
        let industryVictoryTick = try completeSecondAct(&industryFirst)
        let commerceVictoryTick = try completeSecondAct(&commerceAndTax)

        let industryAnalytics = CityAnalytics(state: industryFirst)
        let commerceAnalytics = CityAnalytics(state: commerceAndTax)
        XCTAssertGreaterThan(industryAnalytics.jobCapacity, commerceAnalytics.jobCapacity)
        XCTAssertGreaterThan(industryAnalytics.pollutionPressure, commerceAnalytics.pollutionPressure)
        XCTAssertGreaterThan(industryAnalytics.utilityReserve, commerceAnalytics.utilityReserve)
        XCTAssertNotEqual(industryFirst.treasury, commerceAndTax.treasury)
        XCTAssertNotEqual(industryFirst.happiness, commerceAndTax.happiness)
        XCTAssertGreaterThanOrEqual(industryFirst.population, 500)
        XCTAssertGreaterThanOrEqual(commerceAndTax.population, 500)
        XCTAssertLessThanOrEqual(industryVictoryTick, 2_800)
        XCTAssertLessThanOrEqual(commerceVictoryTick, 2_800)
        XCTAssertTrue(industryFirst.progression?.townCharterAwarded ?? false)
        XCTAssertTrue(commerceAndTax.progression?.townCharterAwarded ?? false)
        XCTAssertEqual(industryFirst.status, .won)
        XCTAssertEqual(commerceAndTax.status, .won)
        XCTAssertGreaterThan(industryFirst.treasury, 0)
        XCTAssertGreaterThan(commerceAndTax.treasury, 0)

        let industryVictory = industryFirst
        let commerceVictory = commerceAndTax
        for _ in 0..<2_800 {
            CitySimulation.step(&industryFirst)
            CitySimulation.step(&commerceAndTax)
        }
        XCTAssertEqual(industryFirst, industryVictory)
        XCTAssertEqual(commerceAndTax, commerceVictory)
    }

    func testStrategyStoriesWarnOnDailyBoundaryAndCreateDifferentOpportunities() throws {
        var commerce = try commercialStrategy()
        var industry = try industrialStrategy()

        advanceToTick(&commerce, tick: 3)
        advanceToTick(&industry, tick: 3)
        XCTAssertFalse(commerce.messages.contains { $0.title == "Main Street Crossroads" })
        XCTAssertFalse(industry.messages.contains { $0.title == "Freight Contract Watch" })

        CitySimulation.step(&commerce)
        CitySimulation.step(&industry)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Main Street Crossroads" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Contract Watch" })

        advanceThroughStrategyPhase(&commerce, phase: .opportunity)
        advanceThroughStrategyPhase(&industry, phase: .opportunity)
        let commerceAnalytics = CityAnalytics(state: commerce)
        let industryAnalytics = CityAnalytics(state: industry)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Market Weekend" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Regional Freight Contract" })
        XCTAssertGreaterThan(industry.treasury, commerce.treasury)
        XCTAssertGreaterThan(industryAnalytics.jobCapacity, commerceAnalytics.jobCapacity)
        XCTAssertGreaterThan(industryAnalytics.pollutionPressure, commerceAnalytics.pollutionPressure)
        XCTAssertLessThan(industryAnalytics.utilityReserve, commerceAnalytics.utilityReserve)
        XCTAssertLessThan(industry.happiness, commerce.happiness)
    }

    func testCommercialSetbackSupportsTaxReliefAndParkRecovery() throws {
        var pressured = try commercialStrategy()
        pressured.taxRate = 0.14
        advanceToTick(&pressured, tick: 4)
        advanceThroughStrategyPhase(&pressured, phase: .opportunity)
        advanceThroughStrategyPhase(&pressured, phase: .complication)
        advanceThroughStrategyPhase(&pressured, phase: .setback)
        XCTAssertTrue(pressured.messages.contains { $0.title == "Storefront Slump" })
        XCTAssertEqual(pressured.status, .playing)

        var taxRelief = pressured
        taxRelief.taxRate = 0.09
        advanceDays(&taxRelief, days: 1)
        XCTAssertNil(taxRelief.progression?.strategy?.recoveryResolution)
        advanceThroughStrategyPhase(&taxRelief, phase: .recovery)
        let taxPayoff = try XCTUnwrap(taxRelief.messages.first { $0.title == "Main Street Rebound" })
        XCTAssertTrue(taxPayoff.detail.contains("tax relief"))
        XCTAssertEqual(taxRelief.progression?.strategy?.recoveryResolution, .commercialTaxRelief)
        XCTAssertEqual(CityAnalytics(state: taxRelief).strategyRecoveryResolution, .commercialTaxRelief)
        XCTAssertEqual(taxRelief.status, .playing)

        var placemaking = pressured
        try buildFirstValid(.park, in: &placemaking)
        XCTAssertNil(placemaking.progression?.strategy?.recoveryResolution)
        advanceThroughStrategyPhase(&placemaking, phase: .recovery)
        let parkPayoff = try XCTUnwrap(placemaking.messages.first { $0.title == "Main Street Rebound" })
        XCTAssertTrue(parkPayoff.detail.contains("new park"))
        XCTAssertEqual(
            placemaking.progression?.strategy?.recoveryResolution,
            .commercialPublicRealmInvestment
        )
        XCTAssertEqual(
            CityAnalytics(state: placemaking).strategyRecoveryResolution,
            .commercialPublicRealmInvestment
        )
        XCTAssertEqual(placemaking.status, .playing)
        XCTAssertGreaterThan(placemaking.treasury, taxRelief.treasury)
        XCTAssertNotEqual(placemaking.happiness, taxRelief.happiness)
    }

    func testTaxReliefPublishesAVisibleDailyStrategyConsequence() throws {
        var commercial = CityGameState.newCity(seed: 42)
        try buildFirstValid(.commercial, in: &commercial)
        advanceToTick(&commercial, tick: 64)
        XCTAssertEqual(commercial.day, 17)
        XCTAssertEqual(commercial.progression?.strategy?.currentPhase, .opportunity)
        XCTAssertNil(commercial.progression?.strategy?.recoveryResolution)

        var taxRelief = commercial
        taxRelief.taxRate = 0.09
        advanceToTick(&taxRelief, tick: 67)
        XCTAssertFalse(taxRelief.messages.contains { $0.title == "Tax Relief Confirmed" })
        CitySimulation.step(&taxRelief)

        let confirmation = try XCTUnwrap(taxRelief.messages.first {
            $0.title == "Tax Relief Confirmed"
        })
        XCTAssertEqual(confirmation.tick, taxRelief.tick)
        XCTAssertTrue(confirmation.detail.contains("removes the current tax-pressure penalty from demand"))
        XCTAssertEqual(taxRelief.day, 18)
        XCTAssertEqual(taxRelief.progression?.strategy?.currentPhase, .complication)
        XCTAssertTrue(taxRelief.messages.contains { $0.title == "Market Weekend" })
        XCTAssertNil(taxRelief.progression?.strategy?.recoveryResolution)

        var noChangeControl = commercial
        noChangeControl.taxRate = 0.10
        advanceToTick(&noChangeControl, tick: 68)
        XCTAssertFalse(noChangeControl.messages.contains { $0.title == "Tax Relief Confirmed" })

        var resolvedControl = commercial
        resolvedControl.taxRate = 0.09
        resolvedControl.progression?.strategy?.recoveryResolution = .commercialTaxRelief
        advanceToTick(&resolvedControl, tick: 68)
        XCTAssertFalse(resolvedControl.messages.contains { $0.title == "Tax Relief Confirmed" })

        let replayed = try JSONDecoder().decode(
            CityGameState.self,
            from: JSONEncoder().encode(taxRelief)
        )
        XCTAssertEqual(replayed, taxRelief)

        var resumed = replayed
        var uninterrupted = taxRelief
        advanceDays(&resumed, days: 1)
        advanceDays(&uninterrupted, days: 1)
        XCTAssertEqual(resumed, uninterrupted)
        XCTAssertEqual(
            uninterrupted.messages.filter { $0.title == "Tax Relief Confirmed" }.count,
            1
        )
    }

    func testIndustrialSetbackSupportsUtilityAndGreenBufferRecovery() throws {
        var pressured = try industrialStrategy()
        advanceToTick(&pressured, tick: 4)
        advanceThroughStrategyPhase(&pressured, phase: .opportunity)
        advanceThroughStrategyPhase(&pressured, phase: .complication)
        advanceThroughStrategyPhase(&pressured, phase: .setback)
        XCTAssertTrue(pressured.messages.contains { $0.title == "Industrial Load Surge" })
        XCTAssertEqual(pressured.status, .playing)

        var utilityReserve = pressured
        try buildFirstValid(.powerPlant, in: &utilityReserve)
        try buildFirstValid(.waterTower, in: &utilityReserve)
        XCTAssertNil(utilityReserve.progression?.strategy?.recoveryResolution)
        advanceThroughStrategyPhase(&utilityReserve, phase: .recovery)
        XCTAssertTrue(utilityReserve.messages.contains { $0.title == "Freight Network Secured" })
        XCTAssertEqual(
            utilityReserve.progression?.strategy?.recoveryResolution,
            .industrialUtilityExpansion
        )
        XCTAssertEqual(
            CityAnalytics(state: utilityReserve).strategyRecoveryResolution,
            .industrialUtilityExpansion
        )
        XCTAssertGreaterThan(CityAnalytics(state: utilityReserve).utilityReserve, 0.35)
        XCTAssertEqual(utilityReserve.status, .playing)

        var greenBuffer = pressured
        try buildFirstValid(.park, in: &greenBuffer)
        XCTAssertNil(greenBuffer.progression?.strategy?.recoveryResolution)
        advanceThroughStrategyPhase(&greenBuffer, phase: .recovery)
        XCTAssertTrue(greenBuffer.messages.contains { $0.title == "Cleaner Industry Compact" })
        XCTAssertEqual(greenBuffer.progression?.strategy?.recoveryResolution, .industrialGreenBuffer)
        XCTAssertEqual(CityAnalytics(state: greenBuffer).strategyRecoveryResolution, .industrialGreenBuffer)
        XCTAssertGreaterThan(greenBuffer.happiness, pressured.happiness)
        XCTAssertGreaterThan(greenBuffer.treasury, pressured.treasury)
        XCTAssertEqual(greenBuffer.status, .playing)
        XCTAssertNotEqual(greenBuffer.treasury, utilityReserve.treasury)
        XCTAssertNotEqual(greenBuffer.happiness, utilityReserve.happiness)
        XCTAssertNotEqual(greenBuffer.approval, utilityReserve.approval)
    }

    func testFirstQualifyingResolutionIsCapturedOnceAndNeverFlips() throws {
        var state = try commercialStrategy()
        advanceToTick(&state, tick: 4)
        advanceThroughStrategyPhase(&state, phase: .opportunity)
        advanceThroughStrategyPhase(&state, phase: .complication)

        state.taxRate = 0.09
        XCTAssertNil(state.progression?.strategy?.recoveryResolution)
        advanceThroughStrategyPhase(&state, phase: .setback)
        XCTAssertEqual(state.progression?.strategy?.recoveryResolution, .commercialTaxRelief)
        XCTAssertTrue(state.messages.contains {
            $0.title == "Storefront Slump Avoided" && $0.detail.contains("Early tax relief")
        })

        state.taxRate = 0.10
        try buildFirstValid(.park, in: &state)
        advanceThroughStrategyPhase(&state, phase: .recovery)

        XCTAssertEqual(state.progression?.strategy?.recoveryResolution, .commercialTaxRelief)
        XCTAssertTrue(state.messages.contains {
            $0.title == "Main Street Rebound" && $0.detail.contains("tax relief")
        })
        XCTAssertFalse(state.messages.contains {
            $0.title == "Main Street Rebound" && $0.detail.contains("new park")
        })
    }

    func testAllFourDurableResolutionsReachTownCharterInsideTwentyMinutes() throws {
        let resolutions: [CityStrategyRecoveryResolution] = [
            .commercialTaxRelief,
            .commercialPublicRealmInvestment,
            .industrialUtilityExpansion,
            .industrialGreenBuffer,
        ]

        for resolution in resolutions {
            var state = try charterCity(resolvedBy: resolution)
            XCTAssertEqual(state.progression?.strategy?.recoveryResolution, resolution)
            XCTAssertEqual(CityAnalytics(state: state).strategyRecoveryResolution, resolution)
            XCTAssertTrue(state.progression?.townCharterAwarded ?? false, resolution.rawValue)
            let expectedCharterTick = resolution == .industrialUtilityExpansion ? 868 : 844
            XCTAssertEqual(state.tick, expectedCharterTick, resolution.rawValue)
            XCTAssertEqual(state.status, .playing, resolution.rawValue)
            XCTAssertGreaterThan(state.treasury, 0, resolution.rawValue)

            let victoryTick = try completeSecondAct(&state)
            XCTAssertLessThanOrEqual(victoryTick, 2_800, resolution.rawValue)
            XCTAssertEqual(state.status, .won, resolution.rawValue)
            XCTAssertTrue(state.progression?.secondAct?.regionalCapitalAwarded ?? false)
            let zoneLevels = state.tiles
                .filter { [.residential, .commercial, .industrial].contains($0.kind) }
                .map(\.level)
            XCTAssertGreaterThanOrEqual(Set(zoneLevels).count, 2, resolution.rawValue)
            XCTAssertGreaterThanOrEqual(
                zoneLevels.filter { $0 > 1 }.count,
                2,
                resolution.rawValue
            )
            let strategyKind: BuildingKind = switch resolution {
            case .commercialTaxRelief, .commercialPublicRealmInvestment: .commercial
            case .industrialUtilityExpansion, .industrialGreenBuffer: .industrial
            }
            XCTAssertEqual(
                state.tiles.filter {
                    $0.kind == strategyKind
                        && $0.condition >= 0.4
                        && $0.condition < 0.75
                }.count,
                1,
                resolution.rawValue
            )
            let terminal = state
            for _ in 0..<128 {
                CitySimulation.step(&state)
            }
            XCTAssertEqual(state, terminal, resolution.rawValue)
        }
    }

    func testIgnoringEitherSetbackCostsMoreButLeavesARecoveryPath() throws {
        var commerce = try commercialStrategy()
        commerce.taxRate = 0.14
        var industry = try industrialStrategy()
        advanceToTick(&commerce, tick: 4)
        advanceToTick(&industry, tick: 4)
        advanceStrategyToCompletion(&commerce)
        advanceStrategyToCompletion(&industry)

        XCTAssertTrue(commerce.messages.contains { $0.title == "Main Street Recovery Delayed" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Freight Recovery Delayed" })
        XCTAssertEqual(commerce.status, .playing)
        XCTAssertEqual(industry.status, .playing)
        XCTAssertGreaterThan(commerce.treasury, 0)
        XCTAssertGreaterThan(industry.treasury, 0)
        XCTAssertGreaterThan(commerce.happiness, 20)
        XCTAssertGreaterThan(industry.happiness, 20)
    }

    func testRetainedDay25MissCommitsLateWithoutSkippingOrCascadingPhases() throws {
        var state = CityGameState.newCity(seed: 42)
        advanceToTick(&state, tick: 204)
        XCTAssertEqual(state.day, 52)
        XCTAssertNil(state.progression?.strategy)
        XCTAssertTrue(state.messages.contains { $0.title == "Choose a Growth Engine" })

        let beforeRejectedPlacement = state
        let occupied = GridCoordinate(x: 13, y: 11)
        guard case .failure(.occupied) = CitySimulation.build(.commercial, at: occupied, in: &state) else {
            return XCTFail("Expected the retained invalid placement to be rejected as occupied")
        }
        XCTAssertEqual(state, beforeRejectedPlacement)
        XCTAssertNil(state.progression?.strategy)

        try buildFirstValid(.commercial, in: &state)
        XCTAssertNil(state.progression?.strategy)
        advanceToTick(&state, tick: 207)
        XCTAssertNil(state.progression?.strategy)
        CitySimulation.step(&state)

        let analytics = CityAnalytics(state: state)
        XCTAssertEqual(state.tick, 208)
        XCTAssertFalse(analytics.awaitingStrategyChoice)
        XCTAssertEqual(analytics.committedStrategy, .commercialStewardship)
        XCTAssertEqual(analytics.strategyPhase, .opportunity)
        XCTAssertEqual(analytics.strategyDaysUntilConsequence, 16)
        XCTAssertFalse(state.messages.contains { $0.title == "Choose a Growth Engine" })
        XCTAssertEqual(state.messages.filter { $0.title == "Main Street Crossroads" }.count, 1)

        let opportunityTick = advanceThroughStrategyPhase(&state, phase: .opportunity)
        XCTAssertEqual(state.messages.filter { $0.title == "Market Weekend" }.count, 1)
        XCTAssertEqual(state.progression?.strategy?.currentPhase, .complication)
        XCTAssertEqual(state.progression?.strategy?.nextScheduledTick, opportunityTick + 64)

        let warningTick = advanceThroughStrategyPhase(&state, phase: .complication)
        XCTAssertEqual(state.messages.filter { $0.title == "Chain Store Rumor" }.count, 1)
        XCTAssertEqual(state.progression?.strategy?.currentPhase, .setback)
        let setbackTick = try XCTUnwrap(state.progression?.strategy?.nextScheduledTick)
        XCTAssertEqual(setbackTick - warningTick, CitySimulation.strategyMinimumWarningTicks)
        advanceToTick(&state, tick: setbackTick - 1)
        XCTAssertFalse(state.messages.contains { $0.title == "Storefront Slump" })
        CitySimulation.step(&state)
        XCTAssertEqual(state.messages.filter { $0.title == "Storefront Slump" }.count, 1)

        state.taxRate = 0.09
        advanceThroughStrategyPhase(&state, phase: .recovery)
        XCTAssertEqual(state.messages.filter { $0.title == "Main Street Rebound" }.count, 1)
        XCTAssertEqual(state.progression?.strategy?.currentPhase, .completed)
        XCTAssertNil(state.progression?.strategy?.nextScheduledTick)

        advanceDays(&state, days: 1)
        XCTAssertEqual(state.messages.filter { $0.title == "Market Weekend" }.count, 1)
        XCTAssertEqual(state.messages.filter { $0.title == "Chain Store Rumor" }.count, 1)
        XCTAssertEqual(state.messages.filter { $0.title == "Main Street Rebound" }.count, 1)
    }

    func testCommittedStrategyDoesNotFlipWhenLaterTileCountsReverse() throws {
        var state = CityGameState.newCity(seed: 42)
        try buildFirstValid(.commercial, in: &state)
        advanceToTick(&state, tick: 4)
        XCTAssertEqual(state.progression?.strategy?.committedStrategy, .commercialStewardship)

        try buildFirstValid(.industrial, in: &state)
        try buildFirstValid(.industrial, in: &state)
        XCTAssertGreaterThan(
            state.tiles.filter { $0.kind == .industrial }.count,
            state.tiles.filter { $0.kind == .commercial }.count
        )

        advanceStrategyToCompletion(&state)
        XCTAssertEqual(state.progression?.strategy?.committedStrategy, .commercialStewardship)
        XCTAssertTrue(state.messages.contains { $0.title == "Market Weekend" })
        XCTAssertTrue(state.messages.contains { $0.title == "Main Street Recovery Delayed" })
        XCTAssertFalse(state.messages.contains { $0.title == "Regional Freight Contract" })
        XCTAssertFalse(state.messages.contains { $0.title == "Freight Recovery Delayed" })
    }

    func testOverduePhaseAdvancesOnceAndSchedulesForwardFromCurrentBoundary() throws {
        var state = try commercialStrategy()
        state.tick = 196
        state.progression?.strategy = CityStrategyProgression(
            committedStrategy: .commercialStewardship,
            currentPhase: .opportunity,
            nextScheduledTick: 96
        )

        for _ in 0..<3 { CitySimulation.step(&state) }
        XCTAssertEqual(state.tick, 199)
        XCTAssertFalse(state.messages.contains { $0.title == "Market Weekend" })
        CitySimulation.step(&state)

        XCTAssertEqual(state.tick, 200)
        XCTAssertEqual(state.messages.filter { $0.title == "Market Weekend" }.count, 1)
        XCTAssertEqual(state.progression?.strategy?.currentPhase, .complication)
        XCTAssertEqual(state.progression?.strategy?.nextScheduledTick, 264)
        XCTAssertFalse(state.messages.contains { $0.title == "Chain Store Rumor" })

        advanceDays(&state, days: 1)
        XCTAssertEqual(state.messages.filter { $0.title == "Market Weekend" }.count, 1)
        XCTAssertFalse(state.messages.contains { $0.title == "Chain Store Rumor" })
    }

    func testStrategyProgressionSaveLoadsEveryPhaseWithoutMutation() throws {
        var state = try commercialStrategy()
        advanceToTick(&state, tick: 4)
        var snapshots = [state]
        for phase in [CityStrategyPhase.opportunity, .complication, .setback, .recovery] {
            advanceThroughStrategyPhase(&state, phase: phase)
            snapshots.append(state)
        }

        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play013-phase-roundtrip-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let saves = SaveGameService(rootURL: root)

        for expected in snapshots {
            let beforeSave = expected
            let write = try saves.save(expected)
            let load = try saves.load()
            XCTAssertEqual(write.schemaVersion, 1)
            XCTAssertEqual(load.schemaVersion, 1)
            XCTAssertEqual(load.state, beforeSave)
            XCTAssertEqual(load.fingerprint, try CityStateFingerprinter.fingerprint(beforeSave))
        }
    }

    func testRecoveryResolutionLegacyDecodeAndAllCasesRoundTrip() throws {
        let legacyData = try XCTUnwrap(
            """
            {
              "committedStrategy": "commercialStewardship",
              "currentPhase": "recovery",
              "nextScheduledTick": 260
            }
            """.data(using: .utf8)
        )
        let legacy = try JSONDecoder().decode(CityStrategyProgression.self, from: legacyData)
        XCTAssertEqual(legacy.committedStrategy, .commercialStewardship)
        XCTAssertEqual(legacy.currentPhase, .recovery)
        XCTAssertEqual(legacy.nextScheduledTick, 260)
        XCTAssertNil(legacy.recoveryResolution)

        let resolutions: [CityStrategyRecoveryResolution] = [
            .commercialTaxRelief,
            .commercialPublicRealmInvestment,
            .industrialUtilityExpansion,
            .industrialGreenBuffer,
        ]
        for resolution in resolutions {
            let strategy: CityStrategy = switch resolution {
            case .commercialTaxRelief, .commercialPublicRealmInvestment: .commercialStewardship
            case .industrialUtilityExpansion, .industrialGreenBuffer: .industrialExpansion
            }
            let expected = CityStrategyProgression(
                committedStrategy: strategy,
                currentPhase: .completed,
                nextScheduledTick: nil,
                recoveryResolution: resolution
            )
            let roundTrip = try JSONDecoder().decode(
                CityStrategyProgression.self,
                from: JSONEncoder().encode(expected)
            )
            XCTAssertEqual(roundTrip, expected)
        }
    }

    func testMissingLegacyStrategyLoadsNilAndCommitsOnlyAtDailyBoundary() throws {
        var state = CityGameState.newCity(seed: 42)
        try buildFirstValid(.industrial, in: &state)
        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play013-legacy-strategy-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let saves = SaveGameService(rootURL: root)
        try saves.save(state)

        let envelopeData = try Data(contentsOf: saves.saveURL)
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: envelopeData) as? [String: Any])
        let encodedState = try XCTUnwrap(envelope["state"] as? [String: Any])
        let encodedProgression = try XCTUnwrap(encodedState["progression"] as? [String: Any])
        XCTAssertNil(encodedProgression["strategy"])

        var resumed = try saves.load().state
        XCTAssertNil(resumed.progression?.strategy)
        for expectedTick in 1...3 {
            CitySimulation.step(&resumed)
            XCTAssertEqual(resumed.tick, expectedTick)
            XCTAssertNil(resumed.progression?.strategy)
        }
        CitySimulation.step(&resumed)
        XCTAssertEqual(resumed.progression?.strategy?.committedStrategy, .industrialExpansion)
        XCTAssertEqual(resumed.progression?.strategy?.currentPhase, .opportunity)
        XCTAssertEqual(resumed.progression?.strategy?.nextScheduledTick, 68)
    }

    @MainActor
    func testUndoBeforeAndAfterCommitRestoresExactAwaitingStrategyState() throws {
        let opening = CityGameState.newCity(seed: 42)
        let coordinate = try firstValidCoordinate(for: .commercial, in: opening)

        let beforeCommit = CityGameStore(state: opening)
        beforeCommit.selectTool(.commercial)
        beforeCommit.primaryAction(at: coordinate)
        XCTAssertTrue(beforeCommit.canUndo)
        XCTAssertNil(beforeCommit.state.progression?.strategy)
        beforeCommit.undoLastAction()
        XCTAssertEqual(beforeCommit.state, opening)

        let afterCommit = CityGameStore(state: opening)
        afterCommit.selectTool(.commercial)
        afterCommit.primaryAction(at: coordinate)
        for _ in 0..<4 { CitySimulation.step(&afterCommit.state) }
        XCTAssertEqual(afterCommit.state.progression?.strategy?.committedStrategy, .commercialStewardship)
        afterCommit.undoLastAction()
        XCTAssertEqual(afterCommit.state, opening)
        XCTAssertNil(afterCommit.state.progression?.strategy)
    }

    @MainActor
    func testUndoRestoresExactPreResolutionState() throws {
        var state = try commercialStrategy()
        advanceToTick(&state, tick: 4)
        advanceThroughStrategyPhase(&state, phase: .opportunity)
        advanceThroughStrategyPhase(&state, phase: .complication)
        advanceThroughStrategyPhase(&state, phase: .setback)
        let beforeInvestment = state

        let store = CityGameStore(state: state)
        store.selectTool(.park)
        store.primaryAction(at: try firstValidCoordinate(for: .park, in: state))
        XCTAssertTrue(store.canUndo)
        XCTAssertNil(store.state.progression?.strategy?.recoveryResolution)

        advanceThroughStrategyPhase(&store.state, phase: .recovery)
        XCTAssertEqual(
            store.state.progression?.strategy?.recoveryResolution,
            .commercialPublicRealmInvestment
        )

        store.undoLastAction()
        XCTAssertEqual(store.state, beforeInvestment)
        XCTAssertNil(store.state.progression?.strategy?.recoveryResolution)
        XCTAssertEqual(store.state.progression?.strategy?.currentPhase, .recovery)
    }

    func testTemporaryTaxRecoveryImprovesCashflowButSuppressesDemandAndHappiness() {
        var standardTax = CityGameState.newCity(seed: 42)
        var recoveryTax = standardTax
        recoveryTax.taxRate = 0.18

        advance(&standardTax, cycles: 1)
        advance(&recoveryTax, cycles: 1)

        XCTAssertGreaterThan(
            CityAnalytics(state: recoveryTax).projectedBalance,
            CityAnalytics(state: standardTax).projectedBalance
        )
        XCTAssertLessThan(recoveryTax.demand.residential, standardTax.demand.residential)
        XCTAssertLessThan(recoveryTax.happiness, standardTax.happiness)
    }

    func testLegacyStateWithoutProgressionNormalizesOnlyOnDailyBoundary() throws {
        let encoded = try JSONEncoder().encode(CityGameState.newCity(seed: 42))
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        payload.removeValue(forKey: "progression")
        let legacyData = try JSONSerialization.data(withJSONObject: payload)
        var decoded = try JSONDecoder().decode(CityGameState.self, from: legacyData)

        XCTAssertNil(decoded.progression)
        for expectedTick in 1...3 {
            CitySimulation.step(&decoded)
            XCTAssertEqual(decoded.tick, expectedTick)
            XCTAssertNil(decoded.progression)
        }
        CitySimulation.step(&decoded)
        XCTAssertEqual(decoded.tick, 4)
        XCTAssertEqual(decoded.progression, CityProgressionState())
    }

    func testProgressionRoundTripsNewAndAwardedStateExactly() throws {
        let newState = CityGameState.newCity(seed: 42)
        let newRoundTrip = try JSONDecoder().decode(
            CityGameState.self,
            from: JSONEncoder().encode(newState)
        )
        XCTAssertEqual(newRoundTrip.progression, CityProgressionState())

        var awarded = newState
        awarded.progression = CityProgressionState(
            townCharterQualifyingCycles: 12,
            townCharterAwarded: true
        )
        let awardedRoundTrip = try JSONDecoder().decode(
            CityGameState.self,
            from: JSONEncoder().encode(awarded)
        )
        XCTAssertEqual(awardedRoundTrip.progression, awarded.progression)
    }

    func testTownCharterRequiresTwelveConsecutiveDailyChecksAndAwardsOnce() throws {
        var state = try qualifyingTown()
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 1)

        advanceDays(&state, days: 10)
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 11)
        XCTAssertFalse(state.progression?.townCharterAwarded ?? true)
        XCTAssertFalse(state.messages.contains { $0.title == "Town Charter Awarded" })
        XCTAssertEqual(state.status, .playing)

        advanceDays(&state, days: 1)
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 12)
        XCTAssertTrue(state.progression?.townCharterAwarded ?? false)
        XCTAssertEqual(state.messages.filter { $0.title == "Town Charter Awarded" }.count, 1)
        XCTAssertEqual(state.status, .playing)
        XCTAssertEqual(state.progression?.secondAct?.phase, .mandate)
        XCTAssertEqual(
            CityAnalytics(state: state).townCharterStatusText,
            "Town Charter secured · Regional Capital chapter is active"
        )

        let charter = state
        advance(&state, cycles: 20)
        XCTAssertGreaterThan(state.tick, charter.tick)
        XCTAssertEqual(state.status, .playing)
    }

    func testFailedTownCharterCheckResetsBeforeLaterSuccessfulRun() throws {
        var state = try qualifyingTown()
        advanceDays(&state, days: 4)
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 5)

        state.happiness = 0
        for _ in 0..<3 { CitySimulation.step(&state) }
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 5)
        CitySimulation.step(&state)
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 0)
        XCTAssertFalse(state.progression?.townCharterAwarded ?? true)
        XCTAssertEqual(state.status, .playing)

        advanceQualifyingTown(&state, days: 12)
        XCTAssertTrue(state.progression?.townCharterAwarded ?? false)
        XCTAssertEqual(state.messages.filter { $0.title == "Town Charter Awarded" }.count, 1)
        XCTAssertEqual(state.status, .playing)
        XCTAssertEqual(state.progression?.secondAct?.phase, .mandate)
    }

    func testLegacyAwardedPlayingStateNormalizesOnlyAtNextDailyBoundary() throws {
        var legacy = CityGameState.newCity(seed: 42)
        legacy.progression = CityProgressionState(
            townCharterQualifyingCycles: 12,
            townCharterAwarded: true
        )
        legacy.messages.insert(
            CityMessage(
                tick: legacy.tick,
                severity: .good,
                title: "Town Charter Awarded",
                detail: "Existing legacy award"
            ),
            at: 0
        )

        var decoded = try JSONDecoder().decode(
            CityGameState.self,
            from: JSONEncoder().encode(legacy)
        )
        XCTAssertEqual(decoded, legacy)
        XCTAssertEqual(decoded.status, .playing)
        XCTAssertEqual(decoded.messages.filter { $0.title == "Town Charter Awarded" }.count, 1)
        XCTAssertEqual(
            CityAnalytics(state: decoded).townCharterStatusText,
            "Town Charter secured permanently · Charter victory is complete"
        )

        for expectedTick in 1...3 {
            CitySimulation.step(&decoded)
            XCTAssertEqual(decoded.tick, expectedTick)
            XCTAssertEqual(decoded.status, .playing)
            XCTAssertEqual(decoded.messages.filter { $0.title == "Town Charter Awarded" }.count, 1)
        }

        CitySimulation.step(&decoded)
        XCTAssertEqual(decoded.tick, 4)
        XCTAssertEqual(decoded.status, .won)
        XCTAssertEqual(
            CityAnalytics(state: decoded).townCharterStatusText,
            "Town Charter secured permanently · Charter victory is complete"
        )
        XCTAssertEqual(decoded.progression?.townCharterQualifyingCycles, 12)
        XCTAssertTrue(decoded.progression?.townCharterAwarded ?? false)
        XCTAssertEqual(decoded.messages.filter { $0.title == "Town Charter Awarded" }.count, 1)

        let normalized = decoded
        CitySimulation.step(&decoded)
        XCTAssertEqual(decoded, normalized)
    }

    func testFailedCharterCheckCanStillReachExistingTerminalLoss() throws {
        var state = try qualifyingTown()
        state.progression?.townCharterQualifyingCycles = 11
        state.treasury = -80_000

        advanceDays(&state, days: 1)

        XCTAssertEqual(state.status, .lost)
        XCTAssertFalse(state.progression?.townCharterAwarded ?? true)
        XCTAssertEqual(state.progression?.townCharterQualifyingCycles, 0)
        XCTAssertFalse(state.messages.contains { $0.title == "Town Charter Awarded" })
    }

    @MainActor
    func testUndoRestoresExactTownCharterProgression() throws {
        var state = CityGameState.newCity(seed: 42)
        state.progression = CityProgressionState(
            townCharterQualifyingCycles: 7,
            townCharterAwarded: false
        )
        let store = CityGameStore(state: state)
        let beforeBuild = store.state

        store.selectTool(.residential)
        store.primaryAction(at: try firstValidCoordinate(for: .residential, in: state))
        store.state.progression?.townCharterQualifyingCycles = 9
        store.undoLastAction()

        XCTAssertEqual(store.state, beforeBuild)
        XCTAssertEqual(store.state.progression?.townCharterQualifyingCycles, 7)
    }

    @MainActor
    func testTownCharterObjectiveAndAwardMessageRouteToExistingContext() throws {
        var state = try qualifyingTown()
        let store = CityGameStore(state: state)
        let charter = try XCTUnwrap(store.objectives.first { $0.id == "town-charter" })
        let capacity = try XCTUnwrap(store.objectives.first { $0.id == "capacity" })

        XCTAssertEqual(charter.remaining, "1 of 12 qualifying days complete")
        store.openObjective(capacity)
        XCTAssertEqual(store.inspectorSection, .utilities)
        store.openObjective(charter)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.inspectorSection, .overview)

        state.progression = CityProgressionState(
            townCharterQualifyingCycles: 12,
            townCharterAwarded: true
        )
        let award = CityMessage(
            tick: state.tick,
            severity: .good,
            title: "Town Charter Awarded",
            detail: "Sustained achievement"
        )
        store.showObjectives = false
        store.openMessage(award)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.inspectorSection, .overview)
    }

    func testTownCharterOpensDistinctWarnedSecondActsWithoutImmediatePressure() throws {
        var commerce = try charterCity(resolvedBy: .commercialPublicRealmInvestment)
        var industry = try charterCity(resolvedBy: .industrialGreenBuffer)

        XCTAssertEqual(commerce.progression?.secondAct?.phase, .mandate)
        XCTAssertEqual(industry.progression?.secondAct?.phase, .mandate)
        XCTAssertEqual(commerce.status, .playing)
        XCTAssertEqual(industry.status, .playing)
        XCTAssertFalse(commerce.messages.contains { $0.title == "Regional Retail Pressure" })
        XCTAssertFalse(industry.messages.contains { $0.title == "Regional Freight Overload" })

        let commerceWarningTick = try XCTUnwrap(commerce.progression?.secondAct?.nextScheduledTick)
        let industryWarningTick = try XCTUnwrap(industry.progression?.secondAct?.nextScheduledTick)
        advanceToTick(&commerce, tick: commerceWarningTick)
        advanceToTick(&industry, tick: industryWarningTick)

        XCTAssertEqual(commerce.progression?.secondAct?.phase, .warnedPressure)
        XCTAssertEqual(industry.progression?.secondAct?.phase, .warnedPressure)
        XCTAssertTrue(commerce.messages.contains {
            $0.title == "Regional Retail Challenge"
                && $0.detail.contains("$4,500")
                && $0.detail.contains("third park")
        })
        XCTAssertTrue(industry.messages.contains {
            $0.title == "Regional Grid Mandate"
                && $0.detail.contains("$7,000")
                && $0.detail.contains("third park")
        })

        let commercePressureTick = try XCTUnwrap(commerce.progression?.secondAct?.nextScheduledTick)
        let industryPressureTick = try XCTUnwrap(industry.progression?.secondAct?.nextScheduledTick)
        XCTAssertEqual(
            commercePressureTick - commerceWarningTick,
            CitySimulation.strategyMinimumWarningTicks
        )
        XCTAssertEqual(
            industryPressureTick - industryWarningTick,
            CitySimulation.strategyMinimumWarningTicks
        )

        advanceToTick(&commerce, tick: commercePressureTick - 1)
        advanceToTick(&industry, tick: industryPressureTick - 1)
        XCTAssertFalse(commerce.messages.contains { $0.title == "Regional Retail Pressure" })
        XCTAssertFalse(industry.messages.contains { $0.title == "Regional Freight Overload" })
        let commerceTreasury = commerce.treasury
        let commerceHappiness = commerce.happiness
        let industryTreasury = industry.treasury
        let industryHappiness = industry.happiness
        CitySimulation.step(&commerce)
        CitySimulation.step(&industry)

        XCTAssertEqual(commerce.progression?.secondAct?.phase, .recovery)
        XCTAssertEqual(industry.progression?.secondAct?.phase, .recovery)
        XCTAssertTrue(commerce.messages.contains { $0.title == "Regional Retail Pressure" })
        XCTAssertTrue(industry.messages.contains { $0.title == "Regional Freight Overload" })
        let commerceTreasuryChange = commerce.treasury - commerceTreasury
        let industryTreasuryChange = industry.treasury - industryTreasury
        XCTAssertLessThan(commerceTreasuryChange, -3_000)
        XCTAssertLessThan(commerce.happiness, commerceHappiness)
        XCTAssertLessThan(industryTreasuryChange, -5_000)
        XCTAssertLessThan(industry.happiness, industryHappiness)
        XCTAssertLessThan(industryTreasuryChange, commerceTreasuryChange)
        XCTAssertLessThan(
            industry.happiness - industryHappiness,
            commerce.happiness - commerceHappiness
        )
    }

    func testRegionalPressureDamagesRouteLotsAndRecoveryLeavesWeatheredHistory() throws {
        var commerce = try charterCity(resolvedBy: .commercialPublicRealmInvestment)
        var industry = try charterCity(resolvedBy: .industrialGreenBuffer)

        for route in [CityStrategy.commercialStewardship, .industrialExpansion] {
            var state = route == .commercialStewardship ? commerce : industry
            let warningTick = try XCTUnwrap(state.progression?.secondAct?.nextScheduledTick)
            advanceToTick(&state, tick: warningTick)
            let pressureTick = try XCTUnwrap(state.progression?.secondAct?.nextScheduledTick)
            advanceToTick(&state, tick: pressureTick)

            let kind: BuildingKind = route == .commercialStewardship
                ? .commercial
                : .industrial
            let pressured = state.tiles.filter {
                $0.kind == kind && $0.condition < 0.75
            }
            XCTAssertEqual(pressured.count, 2)
            XCTAssertEqual(pressured.filter { $0.condition < 0.4 }.count, 1)
            XCTAssertEqual(
                pressured.filter { $0.condition >= 0.4 && $0.condition < 0.75 }.count,
                1
            )
            XCTAssertTrue(state.messages.contains {
                $0.title == (
                    route == .commercialStewardship
                        ? "Regional Retail Pressure"
                        : "Regional Freight Overload"
                ) && $0.detail.contains("developed")
            })

            try buildFirstValid(.park, in: &state)
            advanceDays(&state, days: 1)
            XCTAssertEqual(state.progression?.secondAct?.phase, .qualification)
            XCTAssertFalse(state.tiles.contains {
                $0.kind == kind && $0.condition < 0.4
            })
            XCTAssertEqual(state.tiles.filter {
                $0.kind == kind && $0.condition >= 0.4 && $0.condition < 0.75
            }.count, 1)
            XCTAssertTrue(state.messages.contains {
                $0.title == (
                    route == .commercialStewardship
                        ? "Regional Main Street Recovery"
                        : "Regional Freight Recovery"
                ) && $0.detail.contains("visible recovery record")
            })

            if route == .commercialStewardship {
                commerce = state
            } else {
                industry = state
            }
        }
    }

    func testSecondActLegacyDecodeAndEveryPhaseRoundTripExactly() throws {
        let newCity = CityGameState.newCity(seed: 42)
        XCTAssertNil(newCity.progression?.secondAct)

        let encoded = try JSONEncoder().encode(newCity)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let progression = try XCTUnwrap(payload["progression"] as? [String: Any])
        XCTAssertNil(progression["secondAct"])
        let legacy = try JSONDecoder().decode(CityGameState.self, from: encoded)
        XCTAssertNil(legacy.progression?.secondAct)

        for phase in [
            CitySecondActPhase.mandate,
            .warnedPressure,
            .recovery,
            .qualification,
            .completed,
        ] {
            let expected = CitySecondActProgression(
                phase: phase,
                nextScheduledTick: [.mandate, .warnedPressure].contains(phase) ? 960 : nil,
                qualifyingCycles: phase == .qualification ? 7 : 0,
                regionalCapitalAwarded: phase == .completed
            )
            let roundTrip = try JSONDecoder().decode(
                CitySecondActProgression.self,
                from: JSONEncoder().encode(expected)
            )
            XCTAssertEqual(roundTrip, expected)
        }
    }

    func testRegionalQualificationCountsOnlyDailyBoundariesResetsAndAwardsOnce() throws {
        var state = try charterCity(resolvedBy: .commercialTaxRelief)
        try enterRegionalQualification(&state)
        prepareRegionalMetrics(&state)

        for _ in 0..<3 { CitySimulation.step(&state) }
        XCTAssertEqual(state.progression?.secondAct?.qualifyingCycles, 0)
        CitySimulation.step(&state)
        XCTAssertEqual(state.progression?.secondAct?.qualifyingCycles, 1)

        advanceRegionalQualifying(&state, days: 5)
        XCTAssertEqual(state.progression?.secondAct?.qualifyingCycles, 6)
        state.happiness = 0
        advanceDays(&state, days: 1)
        XCTAssertEqual(state.progression?.secondAct?.qualifyingCycles, 0)
        XCTAssertEqual(state.progression?.secondAct?.phase, .qualification)
        XCTAssertFalse(state.progression?.secondAct?.regionalCapitalAwarded ?? true)
        let interruption = try XCTUnwrap(
            state.messages.first { $0.title == "Regional Qualification Interrupted" }
        )
        XCTAssertEqual(interruption.severity, .warning)
        XCTAssertTrue(interruption.detail.contains("6 qualifying days were lost"))
        XCTAssertTrue(interruption.detail.contains("Raise happiness to 56%"))

        advanceRegionalQualifying(&state, days: 12)
        XCTAssertEqual(state.status, .won)
        XCTAssertEqual(state.progression?.secondAct?.phase, .completed)
        XCTAssertTrue(state.progression?.secondAct?.regionalCapitalAwarded ?? false)
        XCTAssertEqual(state.messages.filter { $0.title == "Regional Capital Recognized" }.count, 1)

        let terminal = state
        for _ in 0..<64 { CitySimulation.step(&state) }
        XCTAssertEqual(state, terminal)
        XCTAssertEqual(state.messages.filter { $0.title == "Regional Capital Recognized" }.count, 1)
    }

    func testSecondActSaveLoadBackupAndReplayPreserveExactState() throws {
        var state = try charterCity(resolvedBy: .industrialGreenBuffer)
        let pressureTick = try XCTUnwrap(state.progression?.secondAct?.nextScheduledTick)
        advanceToTick(&state, tick: pressureTick)
        let setbackTick = try XCTUnwrap(state.progression?.secondAct?.nextScheduledTick)
        advanceToTick(&state, tick: setbackTick)
        XCTAssertEqual(state.progression?.secondAct?.phase, .recovery)

        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play064-save-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let saves = SaveGameService(rootURL: root)
        let write = try saves.save(state)
        let load = try saves.load()
        XCTAssertEqual(write.schemaVersion, 1)
        XCTAssertEqual(load.schemaVersion, 1)
        XCTAssertEqual(load.state, state)
        XCTAssertEqual(load.fingerprint, try CityStateFingerprinter.fingerprint(state))

        var uninterrupted = state
        var replay = load.state
        for _ in 0..<31 {
            CitySimulation.step(&uninterrupted)
            CitySimulation.step(&replay)
        }
        XCTAssertEqual(replay, uninterrupted)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(replay),
            try CityStateFingerprinter.fingerprint(uninterrupted)
        )

        try saves.save(uninterrupted)
        try Data("corrupt".utf8).write(to: saves.saveURL, options: .atomic)
        let recovered = try saves.load()
        XCTAssertEqual(recovered.source, .backup)
        XCTAssertEqual(recovered.state, state)
        XCTAssertEqual(recovered.fingerprint, write.fingerprint)
    }

    @MainActor
    func testUndoRestoresExactSecondActRecoverySnapshotAndMappingsRouteRemedies() throws {
        var state = try charterCity(resolvedBy: .commercialPublicRealmInvestment)
        let warningTick = try XCTUnwrap(state.progression?.secondAct?.nextScheduledTick)
        advanceToTick(&state, tick: warningTick)
        let pressureTick = try XCTUnwrap(state.progression?.secondAct?.nextScheduledTick)
        advanceToTick(&state, tick: pressureTick)
        let beforeBuild = state

        let store = CityGameStore(state: state)
        store.selectTool(.park)
        let coordinate = try XCTUnwrap(
            store.state.tiles.first {
                guard $0.kind == .empty else { return false }
                if case .success = CitySimulation.validateBuild(
                    .park,
                    at: $0.coordinate,
                    in: store.state
                ) {
                    return true
                }
                return false
            }?.coordinate
        )
        store.primaryAction(at: coordinate)
        advanceDays(&store.state, days: 1)
        XCTAssertEqual(store.state.progression?.secondAct?.phase, .qualification)
        store.undoLastAction()
        XCTAssertEqual(store.state, beforeBuild)
        XCTAssertEqual(store.state.progression?.secondAct?.phase, .recovery)

        let regional = try XCTUnwrap(store.objectives.first { $0.id == "regional-capital" })
        XCTAssertTrue(regional.remaining.contains("third park"))
        store.openObjective(regional)
        XCTAssertTrue(store.showObjectives)
        XCTAssertEqual(store.inspectorSection, .overview)

        store.openMessage(
            CityMessage(
                tick: store.state.tick,
                severity: .critical,
                title: "Regional Retail Pressure",
                detail: "Cause and remedy"
            )
        )
        XCTAssertEqual(store.overlay, .happiness)
        XCTAssertEqual(store.inspectorSection, .demand)
    }

    func testCurrentSevereStormScheduleSeedTitleAndEconomicEffectsAreFrozen() throws {
        var offSchedule = stormReadyState(seed: stormSeed)
        offSchedule.tick = 638
        let offScheduleSeed = offSchedule.seed
        CitySimulation.step(&offSchedule)
        XCTAssertEqual(offSchedule.tick, 639)
        XCTAssertEqual(offSchedule.seed, offScheduleSeed)
        XCTAssertFalse(offSchedule.messages.contains { $0.title == "Severe Storm" })

        var belowPopulationGate = stormReadyState(seed: stormSeed)
        belowPopulationGate.population = 499
        CitySimulation.step(&belowPopulationGate)
        XCTAssertEqual(belowPopulationGate.tick, 640)
        XCTAssertEqual(belowPopulationGate.seed, stormSeed)
        XCTAssertFalse(belowPopulationGate.messages.contains { $0.title == "Severe Storm" })

        var storm = stormReadyState(seed: stormSeed)
        var calm = stormReadyState(seed: calmSeed)
        CitySimulation.step(&storm)
        CitySimulation.step(&calm)

        XCTAssertEqual(storm.tick, 640)
        XCTAssertEqual(calm.tick, 640)
        XCTAssertEqual(storm.seed, expectedStormSeed)
        XCTAssertEqual(calm.seed, expectedCalmSeed)
        XCTAssertEqual(storm.treasury, calm.treasury - 2_000, accuracy: 0.000_001)
        XCTAssertEqual(storm.happiness, calm.happiness - 3, accuracy: 0.000_001)
        XCTAssertEqual(storm.messages.first?.title, "Severe Storm")
        XCTAssertFalse(calm.messages.contains { $0.title == "Severe Storm" })
        XCTAssertFalse(storm.messages.contains { $0.title == "State Growth Grant" })
    }

    @MainActor
    func testFirstOrdinaryCityQualifyingEventIsDeterministicVisibleStorm() throws {
        func ordinaryCityBeforeFirstEligibleEvent() throws -> CityGameState {
            var state = CityGameState.newCity(seed: calmSeed)
            try buildFirstValid(.commercial, in: &state)
            try buildFirstValid(.powerPlant, in: &state)
            try buildFirstValid(.waterTower, in: &state)
            while state.tick < 799 {
                CitySimulation.step(&state)
            }
            return state
        }

        var first = try ordinaryCityBeforeFirstEligibleEvent()
        var replay = try ordinaryCityBeforeFirstEligibleEvent()
        var calmControl = first
        calmControl.stormRecovery = CityStormRecoveryState(
            latestEventTick: 640,
            latestEventSeed: calmSeed,
            targets: [],
            disposition: .recovered
        )

        XCTAssertEqual(first.population, 499)
        XCTAssertGreaterThan(CitySimulation.utilityCoverage(in: first), 0.88)

        CitySimulation.step(&first)
        CitySimulation.step(&replay)
        CitySimulation.step(&calmControl)

        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.tick, 800)
        XCTAssertEqual(first.day, 201)
        XCTAssertEqual(first.population, 500)
        XCTAssertEqual(first.seed, calmControl.seed)
        XCTAssertEqual(first.treasury, calmControl.treasury - 2_000, accuracy: 0.000_001)
        XCTAssertEqual(first.happiness, calmControl.happiness - 3, accuracy: 0.000_001)

        let stormMessages = first.messages.filter { $0.title == "Severe Storm" }
        let stormMessage = try XCTUnwrap(stormMessages.first)
        XCTAssertEqual(stormMessages.count, 1)
        XCTAssertEqual(stormMessage.tick, 800)
        XCTAssertEqual(stormMessage.severity, .warning)

        let recovery = try XCTUnwrap(first.stormRecovery)
        XCTAssertEqual(recovery.latestEventTick, 800)
        XCTAssertEqual(recovery.disposition, .active)
        XCTAssertEqual(recovery.targets.map(\.coordinate), expectedTargets)
        XCTAssertTrue(recovery.targets.allSatisfy { $0.remainingConditionDamage > 0 })
        XCTAssertEqual(
            CityNoticeActionCatalog.actions(for: stormMessage.title).map(\.command),
            [.inspectorUtilities]
        )

        let store = CityGameStore(state: first)
        store.openMessage(stormMessage)
        XCTAssertEqual(store.inspectorSection, .utilities)

        var laterCalmEvent = first
        laterCalmEvent.tick = 959
        laterCalmEvent.seed = calmSeed
        CitySimulation.step(&laterCalmEvent)
        XCTAssertEqual(
            laterCalmEvent.messages.filter { $0.title == "Severe Storm" }.count,
            1,
            "After the first recorded storm, later eligible events remain seeded instead of forced"
        )
    }

    func testCurrentMasterPostStormDecisionProjection() throws {
        var state = stormReadyState(seed: stormSeed)
        guard case .applied = CitySimulationCommandExecutor.apply(
            .advanceOneDailyBoundary,
            to: &state
        ) else {
            XCTFail("The frozen daily-boundary player action must apply")
            return
        }

        let stormMessage = try XCTUnwrap(
            state.messages.first { $0.title == "Severe Storm" }
        )
        XCTAssertEqual(stormMessage.tick, 640)
        XCTAssertEqual(stormMessage.severity, .warning)
        XCTAssertEqual(stormMessage.title, "Severe Storm")
        XCTAssertEqual(
            stormMessage.detail,
            "Next decision: protect recovery by keeping utility reserve at or above 15%, or invest in a park or emergency service. Consequence: Emergency repairs cost $2,000, happiness fell 3 points, and weathered 3 completed homes at blocks 4, 11; 7, 11; 10, 11. Diagnosis: 31% utility reserve, 1 park, and 0 emergency services limited average damage to 28%. Objective: keep utilities fully covered with at least 15% reserve while parks and emergency services accelerate Residential repairs until all recorded storm damage clears."
        )
    }

    func testSevereStormDamagesStableCompletedResidentialTargetsAndExplainsRemedy() throws {
        var state = stormReadyState(seed: stormSeed)
        var calm = stormReadyState(seed: calmSeed)

        CitySimulation.step(&state)
        CitySimulation.step(&calm)

        let damaged = damagedResidentialCoordinates(in: state)
        XCTAssertEqual(damaged, expectedTargets)
        for coordinate in expectedTargets {
            XCTAssertEqual(
                try XCTUnwrap(state.tile(at: coordinate)?.condition),
                0.718_703_703_703_703_7,
                accuracy: 0.000_001
            )
            let prior = try XCTUnwrap(calm.tile(at: coordinate))
            let after = try XCTUnwrap(state.tile(at: coordinate))
            XCTAssertEqual(after.kind, prior.kind)
            XCTAssertEqual(after.level, prior.level)
            XCTAssertEqual(after.occupancy, prior.occupancy)
            XCTAssertEqual(after.constructionProgress, prior.constructionProgress)
        }
        XCTAssertEqual(
            state.tiles.filter {
                $0.kind == .residential
                    && $0.constructionProgress >= 1
                    && $0.condition >= 0.75
            }.count,
            3
        )

        let message = try XCTUnwrap(state.messages.first { $0.title == "Severe Storm" })
        XCTAssertEqual(message.severity, .warning)
        XCTAssertTrue(message.detail.contains("weathered 3 completed homes"))
        XCTAssertTrue(message.detail.contains("31% utility reserve"))
        XCTAssertTrue(message.detail.contains("1 park"))
        XCTAssertTrue(message.detail.contains("0 emergency services"))
        XCTAssertTrue(message.detail.contains("15% reserve"))
        XCTAssertTrue(message.detail.contains("parks and emergency services accelerate"))

        let recovery = try XCTUnwrap(state.stormRecovery)
        XCTAssertEqual(recovery.latestEventTick, 640)
        XCTAssertEqual(recovery.latestEventSeed, expectedStormSeed)
        XCTAssertEqual(recovery.disposition, .active)
        XCTAssertEqual(recovery.targets.map(\.coordinate), expectedTargets)
        assertConditions(
            recovery.targets.map(\.remainingConditionDamage),
            equalTo: Array(repeating: 0.281_296_296_296_296_3, count: 3)
        )
    }

    func testExistingResilienceMitigatesButDoesNotEraseDeterministicDamage() throws {
        var unmitigated = stormReadyState(seed: stormSeed)
        var resilient = stormReadyState(seed: stormSeed, resilient: true)

        CitySimulation.step(&unmitigated)
        CitySimulation.step(&resilient)

        XCTAssertEqual(damagedResidentialCoordinates(in: unmitigated), expectedTargets)
        XCTAssertEqual(damagedResidentialCoordinates(in: resilient), expectedTargets)
        for coordinate in expectedTargets {
            let unmitigatedCondition = try XCTUnwrap(unmitigated.tile(at: coordinate)?.condition)
            let resilientCondition = try XCTUnwrap(resilient.tile(at: coordinate)?.condition)
            XCTAssertEqual(unmitigatedCondition, 0.718_703_703_703_703_7, accuracy: 0.000_001)
            XCTAssertEqual(resilientCondition, 0.878_703_703_703_703_7, accuracy: 0.000_001)
            XCTAssertGreaterThan(resilientCondition, unmitigatedCondition)
            XCTAssertLessThan(resilientCondition, 1)
        }

        let message = try XCTUnwrap(resilient.messages.first { $0.title == "Severe Storm" })
        XCTAssertTrue(message.detail.contains("3 parks"))
        XCTAssertTrue(message.detail.contains("3 emergency services"))
        XCTAssertTrue(message.detail.contains("12%"))
    }

    func testHealthyDailyOperationRepairsResidentialDamageWithinTwelveDaysWithoutHealingScars() throws {
        var healthy = stormReadyState(seed: stormSeed)
        CitySimulation.step(&healthy)
        let damagedConditions = expectedTargets.map {
            healthy.tile(at: $0)?.condition
        }
        XCTAssertTrue(damagedConditions.allSatisfy { ($0 ?? 1) < 0.75 })

        let commercialScar = try XCTUnwrap(
            healthy.tiles.first(where: { $0.kind == .commercial })?.coordinate
        )
        let industrialScar = try XCTUnwrap(
            healthy.tiles.first(where: { $0.kind == .industrial })?.coordinate
        )
        healthy.updateTile(at: commercialScar) { $0.condition = 0.64 }
        healthy.updateTile(at: industrialScar) { $0.condition = 0.25 }

        for _ in 0..<3 { CitySimulation.step(&healthy) }
        XCTAssertEqual(
            expectedTargets.map { healthy.tile(at: $0)?.condition },
            damagedConditions,
            "Repair must wait for the next governed daily boundary"
        )

        var recoveryTrace: [[Double]] = []
        for _ in 1...12 {
            advanceDays(&healthy, days: 1)
            recoveryTrace.append(expectedTargets.map {
                healthy.tile(at: $0)?.condition ?? -1
            })
            if expectedTargets.allSatisfy({ healthy.tile(at: $0)?.condition == 1 }) {
                break
            }
        }

        XCTAssertEqual(recoveryTrace.count, 6)
        assertConditions(
            recoveryTrace.first ?? [],
            equalTo: Array(repeating: 0.768_703_703_703_703_7, count: 3)
        )
        XCTAssertEqual(recoveryTrace.last ?? [], Array(repeating: 1, count: 3))
        XCTAssertEqual(
            try XCTUnwrap(healthy.tile(at: commercialScar)?.condition),
            0.64,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(healthy.tile(at: industrialScar)?.condition),
            0.25,
            accuracy: 0.000_001
        )

        let completion = try XCTUnwrap(
            healthy.messages.first { $0.title == "Storm Recovery Complete" }
        )
        XCTAssertTrue(completion.detail.contains("3 Residential lots"))
        XCTAssertTrue(completion.detail.contains("cleared their recorded storm damage"))
        XCTAssertTrue(completion.detail.contains("Keep utilities healthy"))
        XCTAssertEqual(
            healthy.messages.filter { $0.title == "Storm Recovery Complete" }.count,
            1
        )

        var ignored = stormReadyState(seed: stormSeed)
        CitySimulation.step(&ignored)
        let ignoredDamage = expectedTargets.map {
            ignored.tile(at: $0)?.condition
        }
        removeReserveUtilities(from: &ignored)
        advanceDays(&ignored, days: 12)
        XCTAssertEqual(expectedTargets.map { ignored.tile(at: $0)?.condition }, ignoredDamage)
        XCTAssertFalse(ignored.messages.contains { $0.title == "Storm Recovery Complete" })
    }

    func testRecoveryRestoresOnlyRecordedStormDamageAndPreservesEveryPreexistingScar() throws {
        let targetedScar = GridCoordinate(x: 3, y: 10)
        let unrecordedResidentialScar = GridCoordinate(x: 17, y: 10)
        var state = stormReadyState(seed: stormSeed)
        state.updateTile(at: targetedScar) { $0.condition = 0.60 }
        state.updateTile(at: unrecordedResidentialScar) { $0.condition = 0.55 }
        let commercialScar = try XCTUnwrap(
            state.tiles.first(where: { $0.kind == .commercial })?.coordinate
        )
        let industrialScar = try XCTUnwrap(
            state.tiles.first(where: { $0.kind == .industrial })?.coordinate
        )
        state.updateTile(at: commercialScar) { $0.condition = 0.64 }
        state.updateTile(at: industrialScar) { $0.condition = 0.25 }

        CitySimulation.step(&state)
        XCTAssertEqual(
            try XCTUnwrap(state.tile(at: targetedScar)?.condition),
            0.318_703_703_703_703_7,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                state.stormRecovery?.targets.first {
                    $0.coordinate == targetedScar
                }?.remainingConditionDamage
            ),
            0.281_296_296_296_296_3,
            accuracy: 0.000_001
        )

        advanceDays(&state, days: 6)

        XCTAssertEqual(
            try XCTUnwrap(state.tile(at: targetedScar)?.condition),
            0.60,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(state.tile(at: unrecordedResidentialScar)?.condition),
            0.55,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(state.tile(at: commercialScar)?.condition),
            0.64,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(state.tile(at: industrialScar)?.condition),
            0.25,
            accuracy: 0.000_001
        )
        XCTAssertEqual(state.stormRecovery?.disposition, .recovered)
    }

    @MainActor
    func testStormRecoverySurvivesMessageDismissalAndTwelveMessageEvictionExactlyOnce() throws {
        var dismissedState = stormReadyState(seed: stormSeed)
        CitySimulation.step(&dismissedState)
        let store = CityGameStore(state: dismissedState)
        let stormMessage = try XCTUnwrap(
            store.state.messages.first { $0.title == "Severe Storm" }
        )
        store.dismissMessage(stormMessage.id)
        XCTAssertFalse(store.state.messages.contains { $0.title == "Severe Storm" })
        advanceDays(&store.state, days: 6)
        XCTAssertEqual(store.state.stormRecovery?.disposition, .recovered)
        XCTAssertEqual(
            store.state.messages.filter { $0.title == "Storm Recovery Complete" }.count,
            1
        )

        var evictedState = stormReadyState(seed: stormSeed)
        CitySimulation.step(&evictedState)
        evictedState.messages = (0..<12).map { index in
            CityMessage(
                tick: 641 + index,
                severity: .information,
                title: "Newer Notice \(index)",
                detail: "Message-cap eviction proof"
            )
        }
        XCTAssertFalse(evictedState.messages.contains { $0.title == "Severe Storm" })
        advanceDays(&evictedState, days: 6)
        XCTAssertEqual(evictedState.stormRecovery?.disposition, .recovered)
        XCTAssertEqual(
            evictedState.messages.filter { $0.title == "Storm Recovery Complete" }.count,
            1
        )

        evictedState.messages.removeAll { $0.title == "Storm Recovery Complete" }
        advanceDays(&evictedState, days: 12)
        XCTAssertFalse(
            evictedState.messages.contains { $0.title == "Storm Recovery Complete" },
            "A dismissed completion message must not reactivate or duplicate recovery"
        )
    }

    func testDemolishedAndRezonedTargetsRetireWithoutHealingAReplacement() throws {
        let demolished = GridCoordinate(x: 3, y: 10)
        let rezoned = GridCoordinate(x: 6, y: 10)
        var state = stormReadyState(seed: stormSeed)
        CitySimulation.step(&state)

        state.updateTile(at: demolished) {
            $0 = CityTile(coordinate: demolished, kind: .empty)
        }
        state.updateTile(at: rezoned) {
            $0.kind = .commercial
            $0.condition = 0.40
        }
        advanceDays(&state, days: 1)
        XCTAssertEqual(
            state.stormRecovery?.targets.map(\.coordinate),
            [GridCoordinate(x: 9, y: 10)]
        )
        XCTAssertEqual(
            try XCTUnwrap(state.tile(at: rezoned)?.condition),
            0.40,
            accuracy: 0.000_001
        )

        install(.residential, at: demolished, in: &state)
        state.updateTile(at: demolished) { $0.condition = 0.41 }
        advanceDays(&state, days: 5)

        XCTAssertEqual(
            try XCTUnwrap(state.tile(at: demolished)?.condition),
            0.41,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(state.tile(at: rezoned)?.condition),
            0.40,
            accuracy: 0.000_001
        )
        XCTAssertEqual(state.stormRecovery?.disposition, .recovered)
        let completion = try XCTUnwrap(
            state.messages.first { $0.title == "Storm Recovery Complete" }
        )
        XCTAssertTrue(completion.detail.contains("1 Residential lot"))
    }

    func testDemolishThenCompletedReplacementBeforeBoundaryRetiresOwnershipSynchronously() throws {
        let coordinate = GridCoordinate(x: 3, y: 10)
        var state = singleTargetStormState()

        XCTAssertEqual(state.stormRecovery?.targets.map(\.coordinate), [coordinate])
        XCTAssertEqual(
            CitySimulationCommandExecutor.apply(.demolish(coordinate: coordinate), to: &state),
            .applied
        )
        XCTAssertEqual(state.tile(at: coordinate)?.kind, .empty)
        XCTAssertFalse(
            state.stormRecovery?.targets.contains {
                $0.coordinate == coordinate
            } ?? false
        )
        XCTAssertEqual(state.stormRecovery?.disposition, .recovered)
        XCTAssertFalse(
            state.messages.contains { $0.title == "Storm Recovery Complete" }
        )

        XCTAssertEqual(
            CitySimulationCommandExecutor.apply(
                .build(kind: .residential, coordinate: coordinate),
                to: &state
            ),
            .applied
        )
        state.updateTile(at: coordinate) { $0.condition = 0.41 }
        XCTAssertEqual(state.tile(at: coordinate)?.constructionProgress, 0)
        XCTAssertFalse(
            state.stormRecovery?.targets.contains {
                $0.coordinate == coordinate
            } ?? false
        )

        for _ in 0..<4 { CitySimulation.step(&state) }

        XCTAssertEqual(state.tick, 644)
        XCTAssertEqual(state.tile(at: coordinate)?.constructionProgress, 1)
        XCTAssertEqual(
            try XCTUnwrap(state.tile(at: coordinate)?.condition),
            0.41,
            accuracy: 0.000_001
        )
        XCTAssertEqual(state.stormRecovery?.disposition, .recovered)
        XCTAssertFalse(
            state.stormRecovery?.targets.contains {
                $0.coordinate == coordinate
            } ?? false
        )
        XCTAssertFalse(
            state.messages.contains { $0.title == "Storm Recovery Complete" }
        )
    }

    @MainActor
    func testDemolishRebuildOwnershipSaveReplayFingerprintAndUndoRemainExact() throws {
        let coordinate = GridCoordinate(x: 3, y: 10)
        let damaged = singleTargetStormState()
        let damagedFingerprint = try CityStateFingerprinter.fingerprint(damaged)
        let commands: [CitySimulationCommand] = [
            .demolish(coordinate: coordinate),
            .build(kind: .residential, coordinate: coordinate),
        ]

        var uninterrupted = damaged
        var replay = damaged
        for command in commands {
            XCTAssertEqual(
                CitySimulationCommandExecutor.apply(command, to: &uninterrupted),
                .applied
            )
            XCTAssertEqual(
                CitySimulationCommandExecutor.apply(command, to: &replay),
                .applied
            )
        }
        uninterrupted.updateTile(at: coordinate) { $0.condition = 0.41 }
        replay.updateTile(at: coordinate) { $0.condition = 0.41 }
        XCTAssertEqual(uninterrupted, replay)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(uninterrupted),
            try CityStateFingerprinter.fingerprint(replay)
        )

        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play085-race-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let saves = SaveGameService(rootURL: root)
        let write = try saves.save(uninterrupted)
        let load = try saves.load()
        XCTAssertEqual(write.schemaVersion, 1)
        XCTAssertEqual(load.schemaVersion, 1)
        XCTAssertEqual(load.state, uninterrupted)
        XCTAssertEqual(
            load.fingerprint,
            try CityStateFingerprinter.fingerprint(uninterrupted)
        )

        var loadedReplay = load.state
        XCTAssertEqual(
            CitySimulationCommandExecutor.apply(.advanceOneDailyBoundary, to: &uninterrupted),
            .applied
        )
        XCTAssertEqual(
            CitySimulationCommandExecutor.apply(.advanceOneDailyBoundary, to: &replay),
            .applied
        )
        XCTAssertEqual(
            CitySimulationCommandExecutor.apply(.advanceOneDailyBoundary, to: &loadedReplay),
            .applied
        )
        XCTAssertEqual(uninterrupted, replay)
        XCTAssertEqual(loadedReplay, uninterrupted)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(replay),
            try CityStateFingerprinter.fingerprint(uninterrupted)
        )
        XCTAssertEqual(
            try XCTUnwrap(uninterrupted.tile(at: coordinate)?.condition),
            0.41,
            accuracy: 0.000_001
        )
        XCTAssertFalse(
            uninterrupted.messages.contains {
                $0.title == "Storm Recovery Complete"
            }
        )

        let store = CityGameStore(state: damaged)
        store.demolish(at: coordinate)
        let retired = store.state
        XCTAssertNotEqual(retired, damaged)
        XCTAssertTrue(store.canUndo)
        store.selectTool(.residential)
        store.primaryAction(at: coordinate)
        XCTAssertNotEqual(store.state, retired)
        store.undoLastAction()
        XCTAssertEqual(store.state, retired)
        store.undoLastAction()
        XCTAssertEqual(store.state, damaged)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(store.state),
            damagedFingerprint
        )
    }

    func testOverlappingStormMergesActualDamageRowMajorAndZeroDeltaCannotReplaceAuthority() throws {
        var state = stormReadyState(seed: stormSeed)
        CitySimulation.step(&state)
        state.tick = 799
        state.seed = stormSeed

        CitySimulation.step(&state)

        let merged = try XCTUnwrap(state.stormRecovery)
        XCTAssertEqual(merged.latestEventTick, 800)
        XCTAssertEqual(merged.latestEventSeed, expectedStormSeed)
        XCTAssertEqual(merged.disposition, .active)
        XCTAssertEqual(merged.targets.map(\.coordinate), expectedTargets)
        for target in merged.targets {
            XCTAssertEqual(
                target.remainingConditionDamage,
                1 - (state.tile(at: target.coordinate)?.condition ?? 1),
                accuracy: 0.000_001
            )
            XCTAssertGreaterThan(
                target.remainingConditionDamage,
                0.281_296_296_296_296_3
            )
        }

        var zeroDelta = state
        zeroDelta.stormRecovery?.disposition = .recovered
        let identityBeforeZeroDelta = try XCTUnwrap(zeroDelta.stormRecovery)
        for coordinate in expectedTargets {
            zeroDelta.updateTile(at: coordinate) { $0.condition = 0 }
        }
        zeroDelta.tick = 959
        zeroDelta.seed = stormSeed
        CitySimulation.step(&zeroDelta)

        XCTAssertEqual(zeroDelta.stormRecovery, identityBeforeZeroDelta)
    }

    func testZeroTargetAndZeroDeltaStormsDoNotCreateRecoveryOrCompletion() {
        var zeroTarget = stormReadyState(seed: stormSeed)
        for tile in zeroTarget.tiles where tile.kind == .residential {
            zeroTarget.updateTile(at: tile.coordinate) {
                $0.constructionProgress = 0.50
            }
        }
        CitySimulation.step(&zeroTarget)
        XCTAssertNil(zeroTarget.stormRecovery)
        XCTAssertFalse(
            zeroTarget.messages.contains { $0.title == "Storm Recovery Complete" }
        )

        var zeroDelta = stormReadyState(seed: stormSeed)
        for coordinate in expectedTargets {
            zeroDelta.updateTile(at: coordinate) { $0.condition = 0 }
        }
        CitySimulation.step(&zeroDelta)
        XCTAssertNil(zeroDelta.stormRecovery)
        XCTAssertFalse(
            zeroDelta.messages.contains { $0.title == "Storm Recovery Complete" }
        )
    }

    func testUnrelatedHealingClampsRemainingDamageAndConditionHeadroom() throws {
        var state = stormReadyState(seed: stormSeed)
        CitySimulation.step(&state)
        let coordinate = expectedTargets[0]
        state.updateTile(at: coordinate) { $0.condition = 0.98 }

        advanceDays(&state, days: 1)

        XCTAssertEqual(
            try XCTUnwrap(state.tile(at: coordinate)?.condition),
            1,
            accuracy: 0.000_001
        )
        XCTAssertLessThanOrEqual(
            try XCTUnwrap(state.tile(at: coordinate)?.condition),
            1
        )
        XCTAssertEqual(
            try XCTUnwrap(
                state.stormRecovery?.targets.first {
                    $0.coordinate == coordinate
                }?.remainingConditionDamage
            ),
            0,
            accuracy: 0.000_001
        )

        advanceDays(&state, days: 5)
        XCTAssertEqual(state.stormRecovery?.disposition, .recovered)
        XCTAssertTrue(state.tiles.allSatisfy { $0.condition <= 1 })
    }

    func testLegacyAndNewCityNilRecoveryKeepCanonicalBytesAndVersionOneFingerprint() throws {
        let newCity = CityGameState.newCity(seed: 42)
        XCTAssertNil(newCity.stormRecovery)
        let canonical = try CityStateFingerprinter.canonicalData(for: newCity)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: canonical) as? [String: Any]
        )
        XCTAssertNil(object["stormRecovery"])

        let legacy = try JSONDecoder().decode(CityGameState.self, from: canonical)
        XCTAssertNil(legacy.stormRecovery)
        XCTAssertEqual(
            try CityStateFingerprinter.canonicalData(for: legacy),
            canonical
        )
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(legacy).version,
            1
        )

        var messageOnlyLegacy = legacy
        messageOnlyLegacy.tick = 640
        let scar = GridCoordinate(x: 3, y: 10)
        messageOnlyLegacy.updateTile(at: scar) { $0.condition = 0.60 }
        messageOnlyLegacy.messages.insert(
            CityMessage(
                tick: 640,
                severity: .warning,
                title: "Severe Storm",
                detail: "Legacy presentation without durable ownership"
            ),
            at: 0
        )
        advanceDays(&messageOnlyLegacy, days: 12)
        XCTAssertNil(messageOnlyLegacy.stormRecovery)
        XCTAssertEqual(
            try XCTUnwrap(messageOnlyLegacy.tile(at: scar)?.condition),
            0.60,
            accuracy: 0.000_001
        )
    }

    func testStormTargetsOnlyCompletedHomesAndDoesNotHealWithoutAStorm() throws {
        let incompleteCoordinate = GridCoordinate(x: 3, y: 10)
        var state = stormReadyState(seed: stormSeed)
        state.updateTile(at: incompleteCoordinate) {
            $0.constructionProgress = 0.50
        }

        CitySimulation.step(&state)

        XCTAssertEqual(
            damagedResidentialCoordinates(in: state),
            [
                GridCoordinate(x: 6, y: 10),
                GridCoordinate(x: 9, y: 10),
                GridCoordinate(x: 17, y: 10),
            ]
        )
        XCTAssertEqual(
            try XCTUnwrap(state.tile(at: incompleteCoordinate)?.condition),
            1,
            accuracy: 0.000_001
        )

        var noStorm = stormReadyState(seed: calmSeed)
        noStorm.tick = 640
        let existingCondition = GridCoordinate(x: 3, y: 10)
        noStorm.updateTile(at: existingCondition) { $0.condition = 0.60 }
        advanceDays(&noStorm, days: 12)
        XCTAssertEqual(
            try XCTUnwrap(noStorm.tile(at: existingCondition)?.condition),
            0.60,
            accuracy: 0.000_001
        )
        XCTAssertFalse(noStorm.messages.contains { $0.title == "Storm Recovery Complete" })
    }

    @MainActor
    func testStormDamageSaveReplayBackupFingerprintAndUndoRemainExact() throws {
        var uninterrupted = stormReadyState(seed: stormSeed)
        var replay = stormReadyState(seed: stormSeed)
        CitySimulation.step(&uninterrupted)
        CitySimulation.step(&replay)
        let damaged = uninterrupted

        XCTAssertEqual(uninterrupted, replay)
        let damagedFingerprint = try CityStateFingerprinter.fingerprint(damaged)
        XCTAssertEqual(
            damagedFingerprint,
            try CityStateFingerprinter.fingerprint(replay)
        )

        let root = FileManager.default.temporaryDirectory
            .appending(path: "citysim-play085-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let saves = SaveGameService(rootURL: root)
        let damagedWrite = try saves.save(damaged)
        let damagedLoad = try saves.load()
        XCTAssertEqual(damagedWrite.schemaVersion, 1)
        XCTAssertEqual(damagedLoad.schemaVersion, 1)
        XCTAssertEqual(damagedLoad.state, damaged)
        XCTAssertEqual(damagedLoad.fingerprint, damagedFingerprint)
        XCTAssertEqual(
            try CityPresentationSnapshot(state: damaged).fingerprint,
            damagedFingerprint
        )

        var sameTilesWithoutOwnership = damaged
        sameTilesWithoutOwnership.stormRecovery = nil
        XCTAssertNotEqual(
            try CityStateFingerprinter.fingerprint(sameTilesWithoutOwnership),
            damagedFingerprint
        )
        var recoveredLedger = damaged
        recoveredLedger.stormRecovery?.disposition = .recovered
        XCTAssertNotEqual(
            try CityStateFingerprinter.fingerprint(recoveredLedger),
            damagedFingerprint
        )

        advanceDays(&uninterrupted, days: 6)
        advanceDays(&replay, days: 6)
        XCTAssertEqual(replay, uninterrupted)
        XCTAssertEqual(
            try CityStateFingerprinter.fingerprint(replay),
            try CityStateFingerprinter.fingerprint(uninterrupted)
        )
        XCTAssertNotEqual(
            try CityStateFingerprinter.fingerprint(uninterrupted),
            damagedFingerprint
        )

        let recoveredWrite = try saves.save(uninterrupted)
        let recoveredLoad = try saves.load()
        XCTAssertEqual(recoveredLoad.state, uninterrupted)
        XCTAssertEqual(recoveredLoad.fingerprint, recoveredWrite.fingerprint)
        XCTAssertEqual(recoveredLoad.state.stormRecovery?.disposition, .recovered)
        try Data("corrupt".utf8).write(to: saves.saveURL, options: .atomic)
        let backup = try saves.load()
        XCTAssertEqual(backup.source, .backup)
        XCTAssertEqual(backup.state, damaged)
        XCTAssertEqual(backup.fingerprint, damagedFingerprint)

        var undoState = damaged
        undoState.treasury = 50_000
        let store = CityGameStore(state: undoState)
        store.selectTool(.park)
        let coordinate = try XCTUnwrap(
            store.state.tiles.first {
                guard $0.kind == .empty else { return false }
                if case .success = CitySimulation.validateBuild(
                    .park,
                    at: $0.coordinate,
                    in: store.state
                ) {
                    return true
                }
                return false
            }?.coordinate
        )
        store.primaryAction(at: coordinate)
        XCTAssertNotEqual(store.state, undoState)
        XCTAssertTrue(store.canUndo)
        store.undoLastAction()
        XCTAssertEqual(store.state, undoState)
    }

    private func stormReadyState(
        seed: UInt64,
        resilient: Bool = false
    ) -> CityGameState {
        var state = CityGameState.newCity(seed: seed)
        state.tick = 639
        state.treasury = 4_000
        state.population = 500
        state.happiness = 70
        state.approval = 70
        install(.powerPlant, at: GridCoordinate(x: 5, y: 8), in: &state)
        install(.waterTower, at: GridCoordinate(x: 6, y: 8), in: &state)

        if resilient {
            install(.park, at: GridCoordinate(x: 7, y: 8), in: &state)
            install(.park, at: GridCoordinate(x: 8, y: 8), in: &state)
            install(.fireStation, at: GridCoordinate(x: 9, y: 8), in: &state)
            install(.policeStation, at: GridCoordinate(x: 10, y: 8), in: &state)
            install(.school, at: GridCoordinate(x: 11, y: 8), in: &state)
        }
        return state
    }

    private func singleTargetStormState() -> CityGameState {
        var state = stormReadyState(seed: stormSeed)
        for coordinate in expectedTargets.dropFirst() {
            state.updateTile(at: coordinate) { $0.condition = 0 }
        }
        CitySimulation.step(&state)
        state.treasury = 50_000
        return state
    }

    private func install(
        _ kind: BuildingKind,
        at coordinate: GridCoordinate,
        in state: inout CityGameState
    ) {
        state.updateTile(at: coordinate) {
            $0.kind = kind
            $0.level = 1
            $0.occupancy = 0
            $0.condition = 1
            $0.constructionProgress = 1
        }
    }

    private func damagedResidentialCoordinates(
        in state: CityGameState
    ) -> [GridCoordinate] {
        state.tiles
            .filter {
                $0.kind == .residential
                    && $0.constructionProgress >= 1
                    && $0.condition < 1
            }
            .map(\.coordinate)
            .sorted {
                if $0.y != $1.y { return $0.y < $1.y }
                return $0.x < $1.x
            }
    }

    private func assertConditions(
        _ actual: [Double],
        equalTo expected: [Double],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actualValue, expectedValue) in zip(actual, expected) {
            XCTAssertEqual(
                actualValue,
                expectedValue,
                accuracy: 0.000_001,
                file: file,
                line: line
            )
        }
    }

    private func removeReserveUtilities(from state: inout CityGameState) {
        for coordinate in [GridCoordinate(x: 5, y: 8), GridCoordinate(x: 6, y: 8)] {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
    }

    @discardableResult
    private func advanceThroughStrategyPhase(
        _ state: inout CityGameState,
        phase: CityStrategyPhase
    ) -> Int {
        XCTAssertEqual(state.progression?.strategy?.currentPhase, phase)
        guard let scheduledTick = state.progression?.strategy?.nextScheduledTick else {
            XCTFail("Expected a scheduled tick for strategy phase \(phase.rawValue)")
            return state.tick
        }
        advanceToTick(&state, tick: scheduledTick)
        return scheduledTick
    }

    private func advanceStrategyToCompletion(_ state: inout CityGameState) {
        while let phase = state.progression?.strategy?.currentPhase, phase != .completed {
            advanceThroughStrategyPhase(&state, phase: phase)
        }
    }

    private func advance(_ state: inout CityGameState, cycles: Int) {
        for _ in 0..<(cycles * 4) {
            CitySimulation.step(&state)
        }
    }

    private func advanceDays(_ state: inout CityGameState, days: Int) {
        for _ in 0..<(days * 4) {
            CitySimulation.step(&state)
        }
    }

    private func advanceToTick(_ state: inout CityGameState, tick: Int) {
        XCTAssertLessThanOrEqual(state.tick, tick)
        while state.tick < tick {
            CitySimulation.step(&state)
        }
    }

    private func advanceQualifyingTown(_ state: inout CityGameState, days: Int) {
        for _ in 0..<days {
            state.population = 500
            state.treasury = max(state.treasury, 50_000)
            state.happiness = 57
            advanceDays(&state, days: 1)
            XCTAssertTrue(
                CitySimulation.meetsTownCharterStandards(in: state),
                CityAnalytics(state: state).townCharterStatusText
            )
        }
    }

    private func prepareRegionalMetrics(_ state: inout CityGameState) {
        state.population = max(state.population, 525)
        state.treasury = max(state.treasury, 75_000)
        state.happiness = max(state.happiness, 70)
        state.taxRate = 0.10
    }

    private func advanceRegionalQualifying(_ state: inout CityGameState, days: Int) {
        for _ in 0..<days {
            prepareRegionalMetrics(&state)
            advanceDays(&state, days: 1)
            XCTAssertTrue(
                CitySimulation.meetsRegionalCapitalStandards(in: state),
                CityAnalytics(state: state).regionalCapitalStatusText
            )
        }
    }

    private func enterRegionalQualification(_ state: inout CityGameState) throws {
        let warningTick = try XCTUnwrap(state.progression?.secondAct?.nextScheduledTick)
        advanceToTick(&state, tick: warningTick)
        let pressureTick = try XCTUnwrap(state.progression?.secondAct?.nextScheduledTick)
        advanceToTick(&state, tick: pressureTick)
        XCTAssertEqual(state.progression?.secondAct?.phase, .recovery)

        guard let story = state.progression?.strategy,
              let resolution = story.recoveryResolution else {
            XCTFail("Expected a durable first-act recovery resolution")
            return
        }
        let jobs: BuildingKind = story.committedStrategy == .commercialStewardship
            ? .commercial
            : .industrial
        if story.committedStrategy == .industrialExpansion {
            for kind in [BuildingKind.powerPlant, .waterTower] {
                while CityAnalytics(state: state).count(kind) < 3 {
                    advanceUntil(&state, maximumCycles: 160) { $0.treasury >= kind.buildCost }
                    try buildFirstValid(kind, in: &state)
                    advance(&state, cycles: 1)
                }
            }
        }
        while CityAnalytics(state: state).jobCapacity < 500 {
            advanceUntil(&state, maximumCycles: 160) { $0.treasury >= jobs.buildCost }
            try buildFirstValid(jobs, in: &state)
            advance(&state, cycles: 1)
        }

        switch resolution {
        case .commercialTaxRelief:
            state.taxRate = 0.08
        case .commercialPublicRealmInvestment, .industrialGreenBuffer:
            try buildFirstValid(.park, in: &state)
        case .industrialUtilityExpansion:
            break
        }

        advanceUntil(&state, maximumCycles: 80) {
            $0.progression?.secondAct?.phase == .qualification
        }
        state.taxRate = 0.10
    }

    @discardableResult
    private func completeSecondAct(_ state: inout CityGameState) throws -> Int {
        try enterRegionalQualification(&state)
        return advanceUntil(&state, maximumCycles: 430) {
            $0.status == .won
        }
    }

    @discardableResult
    private func advanceUntil(
        _ state: inout CityGameState,
        maximumCycles: Int,
        condition: (CityGameState) -> Bool
    ) -> Int {
        for _ in 0..<maximumCycles {
            advance(&state, cycles: 1)
            if condition(state) { return state.tick }
        }
        XCTFail(
            "Expected scenario condition within \(maximumCycles) cycles: \(scenarioSummary(state))"
        )
        return state.tick
    }

    private func scenarioSummary(_ state: CityGameState) -> String {
        let analytics = CityAnalytics(state: state)
        let zoneSummary = state.tiles
            .filter { [.residential, .commercial, .industrial].contains($0.kind) }
            .map {
                "\($0.kind.title.prefix(1))L\($0.level):occ\($0.occupancy):cond\(String(format: "%.2f", $0.condition))"
            }
            .joined(separator: ",")
        return "tick=\(state.tick) treasury=\(state.treasury) balance=\(analytics.projectedBalance) happiness=\(String(format: "%.1f", state.happiness)) reserve=\(String(format: "%.2f", analytics.utilityReserve)) demand=R\(String(format: "%.2f", state.demand.residential))/C\(String(format: "%.2f", state.demand.commercial))/I\(String(format: "%.2f", state.demand.industrial)) charter=\(analytics.townCharterStatusText) zones=[\(zoneSummary)]"
    }

    private func qualifyingTown() throws -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 50_000
        try buildFirstValid(.industrial, in: &state)
        try buildFirstValid(.industrial, in: &state)
        try buildFirstValid(.powerPlant, in: &state)
        try buildFirstValid(.waterTower, in: &state)
        state.population = 500
        state.treasury = 50_000
        state.happiness = 60
        advance(&state, cycles: 1)
        XCTAssertTrue(CityAnalytics(state: state).meetsTownCharterStandards)
        return state
    }

    private func commercialStrategy() throws -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        try buildFirstValid(.commercial, in: &state)
        try buildFirstValid(.commercial, in: &state)
        return state
    }

    private func industrialStrategy() throws -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        try buildFirstValid(.industrial, in: &state)
        try buildFirstValid(.industrial, in: &state)
        return state
    }

    private func firstValidCoordinate(
        for kind: BuildingKind,
        in state: CityGameState
    ) throws -> GridCoordinate {
        try XCTUnwrap(
            state.tiles.first { tile in
                guard tile.kind == .empty else { return false }
                if case .success = CitySimulation.validateBuild(
                    kind,
                    at: tile.coordinate,
                    in: state
                ) {
                    return true
                }
                return false
            }?.coordinate
        )
    }

    private func build(
        _ kind: BuildingKind,
        at coordinate: GridCoordinate,
        in state: inout CityGameState
    ) throws {
        switch CitySimulation.build(kind, at: coordinate, in: &state) {
        case .success:
            return
        case .failure(let rejection):
            throw rejection
        }
    }

    private func buildFirstValid(_ kind: BuildingKind, in state: inout CityGameState) throws {
        for tile in state.tiles where tile.kind == .empty {
            if case .success = CitySimulation.validateBuild(kind, at: tile.coordinate, in: state) {
                try build(kind, at: tile.coordinate, in: &state)
                return
            }
        }
        XCTFail("Expected a visible valid placement for \(kind.title)")
        throw BuildRejection.outsideMap
    }

    private func charterCity(
        resolvedBy resolution: CityStrategyRecoveryResolution
    ) throws -> CityGameState {
        let strategy: CityStrategy
        let jobs: BuildingKind
        switch resolution {
        case .commercialTaxRelief, .commercialPublicRealmInvestment:
            strategy = .commercialStewardship
            jobs = .commercial
        case .industrialUtilityExpansion, .industrialGreenBuffer:
            strategy = .industrialExpansion
            jobs = .industrial
        }

        var state = CityGameState.newCity(seed: 42)
        advanceToTick(&state, tick: 60)
        try buildFirstValid(jobs, in: &state)
        advanceToTick(&state, tick: 64)
        XCTAssertEqual(state.progression?.strategy?.committedStrategy, strategy)
        advanceThroughStrategyPhase(&state, phase: .opportunity)
        advanceThroughStrategyPhase(&state, phase: .complication)
        advanceThroughStrategyPhase(&state, phase: .setback)
        XCTAssertNil(state.progression?.strategy?.recoveryResolution)

        switch resolution {
        case .commercialTaxRelief:
            state.taxRate = 0.09
        case .commercialPublicRealmInvestment, .industrialGreenBuffer:
            try buildFirstValid(.park, in: &state)
        case .industrialUtilityExpansion:
            try prepareReserveUtilities(in: &state)
        }

        advanceThroughStrategyPhase(&state, phase: .recovery)
        XCTAssertEqual(state.progression?.strategy?.recoveryResolution, resolution)

        if resolution == .commercialTaxRelief {
            state.taxRate = 0.10
        }
        try prepareCharterCapacity(in: &state, jobs: jobs)
        state.taxRate = 0.10
        advanceUntil(&state, maximumCycles: 430) {
            $0.progression?.townCharterAwarded == true
        }
        return state
    }

    private func prepareReserveUtilities(in state: inout CityGameState) throws {
        for kind in [BuildingKind.powerPlant, .waterTower] {
            while CityAnalytics(state: state).count(kind) < 2 {
                advanceUntil(&state, maximumCycles: 160) { $0.treasury >= kind.buildCost }
                guard state.status == .playing, state.treasury >= kind.buildCost else {
                    throw BuildRejection.insufficientFunds
                }
                try buildFirstValid(kind, in: &state)
                advance(&state, cycles: 1)
            }
        }
    }

    private func prepareCharterCapacity(in state: inout CityGameState, jobs: BuildingKind) throws {
        try prepareReserveUtilities(in: &state)
        while CityAnalytics(state: state).jobCapacity < 350 {
            advanceUntil(&state, maximumCycles: 160) { $0.treasury >= jobs.buildCost }
            guard state.status == .playing, state.treasury >= jobs.buildCost else {
                throw BuildRejection.insufficientFunds
            }
            try buildFirstValid(jobs, in: &state)
            advance(&state, cycles: 1)
        }
    }
}
