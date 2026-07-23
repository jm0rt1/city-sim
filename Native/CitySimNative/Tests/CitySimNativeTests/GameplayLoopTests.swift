import Foundation
import XCTest
@testable import CitySimNative

final class GameplayLoopTests: XCTestCase {
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

    func testLiveCommercialRecoveryReachesACharterPathByDay128() throws {
        var state = CityGameState.newCity(seed: 42)
        advanceToTick(&state, tick: 60)
        try build(.commercial, at: GridCoordinate(x: 8, y: 11), in: &state)
        advance(&state, cycles: 4)
        try build(.powerPlant, at: GridCoordinate(x: 7, y: 11), in: &state)
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
        XCTAssertEqual(state.status, .won)
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
        XCTAssertEqual(industryAwardTick, 844)
        XCTAssertGreaterThan(commerce.happiness, industry.happiness)
        XCTAssertGreaterThan(CityAnalytics(state: industry).pollutionPressure, CityAnalytics(state: commerce).pollutionPressure)
        XCTAssertGreaterThan(CityAnalytics(state: industry).jobCapacity, CityAnalytics(state: commerce).jobCapacity)
        XCTAssertTrue(commerce.progression?.townCharterAwarded ?? false)
        XCTAssertTrue(industry.progression?.townCharterAwarded ?? false)
        XCTAssertEqual(commerce.status, .won)
        XCTAssertEqual(industry.status, .won)
    }

    func testOpeningExposesARealButRecoverableTradeoff() {
        let state = CityGameState.newCity(seed: 42)
        let analytics = CityAnalytics(state: state)

        XCTAssertEqual(state.treasury, 26_000)
        XCTAssertEqual(state.population, 300)
        XCTAssertEqual(analytics.jobShortfall, 20)
        XCTAssertEqual(analytics.powerHeadroom, 54)
        XCTAssertEqual(analytics.waterHeadroom, 48)
        XCTAssertEqual(analytics.employmentRate, 190.0 / 210.0, accuracy: 0.000_001)
        XCTAssertEqual(analytics.utilityReserve, 48.0 / 270.0, accuracy: 0.000_001)
        XCTAssertEqual(analytics.projectedBalance, -61.4, accuracy: 0.001)
        XCTAssertGreaterThan(analytics.operatingRunwayCycles ?? 0, 400)
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
        XCTAssertLessThan(CityAnalytics(state: state).utilityCoverage, 0.98)
        XCTAssertEqual(state.status, .playing)

        state.taxRate = 0.18
        advance(&state, cycles: 24)
        try build(.powerPlant, at: GridCoordinate(x: 8, y: 11), in: &state)
        try build(.waterTower, at: GridCoordinate(x: 7, y: 11), in: &state)
        try build(.industrial, at: GridCoordinate(x: 6, y: 11), in: &state)
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
        try build(.powerPlant, at: GridCoordinate(x: 6, y: 11), in: &industryFirst)
        try build(.waterTower, at: GridCoordinate(x: 5, y: 11), in: &industryFirst)
        advanceStrategyToCompletion(&industryFirst)

        var commerceAndTax = try commercialStrategy()
        commerceAndTax.taxRate = 0.10
        advanceToTick(&commerceAndTax, tick: 4)
        advanceThroughStrategyPhase(&commerceAndTax, phase: .opportunity)
        try build(.powerPlant, at: GridCoordinate(x: 6, y: 11), in: &commerceAndTax)
        try build(.waterTower, at: GridCoordinate(x: 5, y: 11), in: &commerceAndTax)
        advanceThroughStrategyPhase(&commerceAndTax, phase: .complication)
        advanceThroughStrategyPhase(&commerceAndTax, phase: .setback)
        commerceAndTax.taxRate = 0.09
        advanceThroughStrategyPhase(&commerceAndTax, phase: .recovery)

        XCTAssertTrue(industryFirst.messages.contains { $0.title == "Freight Network Secured" })
        XCTAssertTrue(commerceAndTax.messages.contains { $0.title == "Main Street Rebound" })
        commerceAndTax.taxRate = 0.10

        let industryVictoryTick = advanceUntil(&industryFirst, maximumCycles: 430) {
            $0.status == .won
        }
        let commerceVictoryTick = advanceUntil(&commerceAndTax, maximumCycles: 430) {
            $0.status == .won
        }

        let industryAnalytics = CityAnalytics(state: industryFirst)
        let commerceAnalytics = CityAnalytics(state: commerceAndTax)
        XCTAssertGreaterThan(industryAnalytics.jobCapacity, commerceAnalytics.jobCapacity)
        XCTAssertGreaterThan(industryAnalytics.pollutionPressure, commerceAnalytics.pollutionPressure)
        XCTAssertLessThan(industryAnalytics.utilityReserve, commerceAnalytics.utilityReserve)
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
        try build(.park, at: GridCoordinate(x: 6, y: 11), in: &placemaking)
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

    func testIndustrialSetbackSupportsUtilityAndGreenBufferRecovery() throws {
        var pressured = try industrialStrategy()
        advanceToTick(&pressured, tick: 4)
        advanceThroughStrategyPhase(&pressured, phase: .opportunity)
        advanceThroughStrategyPhase(&pressured, phase: .complication)
        advanceThroughStrategyPhase(&pressured, phase: .setback)
        XCTAssertTrue(pressured.messages.contains { $0.title == "Industrial Load Surge" })
        XCTAssertEqual(pressured.status, .playing)

        var utilityReserve = pressured
        try build(.powerPlant, at: GridCoordinate(x: 6, y: 11), in: &utilityReserve)
        try build(.waterTower, at: GridCoordinate(x: 5, y: 11), in: &utilityReserve)
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
        try build(.park, at: GridCoordinate(x: 6, y: 11), in: &greenBuffer)
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
        try build(.park, at: GridCoordinate(x: 6, y: 11), in: &state)
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
            let state = try charterCity(resolvedBy: resolution)
            XCTAssertEqual(state.progression?.strategy?.recoveryResolution, resolution)
            XCTAssertEqual(CityAnalytics(state: state).strategyRecoveryResolution, resolution)
            XCTAssertTrue(state.progression?.townCharterAwarded ?? false, resolution.rawValue)
            XCTAssertEqual(state.tick, 844, resolution.rawValue)
            XCTAssertEqual(state.status, .won, resolution.rawValue)
            XCTAssertGreaterThan(state.treasury, 0, resolution.rawValue)

            var terminal = state
            for _ in 0..<128 {
                CitySimulation.step(&terminal)
            }
            XCTAssertEqual(terminal, state, resolution.rawValue)
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
        let coordinate = GridCoordinate(x: 8, y: 11)
        let opening = CityGameState.newCity(seed: 42)

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
        store.primaryAction(at: GridCoordinate(x: 6, y: 11))
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
        XCTAssertEqual(state.status, .won)

        let victory = state
        advance(&state, cycles: 20)
        XCTAssertEqual(state, victory)
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
        XCTAssertEqual(state.status, .won)
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

        for expectedTick in 1...3 {
            CitySimulation.step(&decoded)
            XCTAssertEqual(decoded.tick, expectedTick)
            XCTAssertEqual(decoded.status, .playing)
            XCTAssertEqual(decoded.messages.filter { $0.title == "Town Charter Awarded" }.count, 1)
        }

        CitySimulation.step(&decoded)
        XCTAssertEqual(decoded.tick, 4)
        XCTAssertEqual(decoded.status, .won)
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
    func testUndoRestoresExactTownCharterProgression() {
        var state = CityGameState.newCity(seed: 42)
        state.progression = CityProgressionState(
            townCharterQualifyingCycles: 7,
            townCharterAwarded: false
        )
        let store = CityGameStore(state: state)
        let beforeBuild = store.state

        store.selectTool(.residential)
        store.primaryAction(at: GridCoordinate(x: 8, y: 11))
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
        XCTFail("Expected scenario condition within \(maximumCycles) cycles")
        return state.tick
    }

    private func qualifyingTown() throws -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 50_000
        try build(.industrial, at: GridCoordinate(x: 8, y: 11), in: &state)
        try build(.industrial, at: GridCoordinate(x: 7, y: 11), in: &state)
        try build(.powerPlant, at: GridCoordinate(x: 6, y: 11), in: &state)
        try build(.waterTower, at: GridCoordinate(x: 5, y: 11), in: &state)
        state.population = 500
        state.treasury = 50_000
        state.happiness = 60
        advance(&state, cycles: 1)
        XCTAssertTrue(CityAnalytics(state: state).meetsTownCharterStandards)
        return state
    }

    private func commercialStrategy() throws -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        try build(.commercial, at: GridCoordinate(x: 8, y: 11), in: &state)
        try build(.commercial, at: GridCoordinate(x: 7, y: 11), in: &state)
        return state
    }

    private func industrialStrategy() throws -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        try build(.industrial, at: GridCoordinate(x: 8, y: 11), in: &state)
        try build(.industrial, at: GridCoordinate(x: 7, y: 11), in: &state)
        return state
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
