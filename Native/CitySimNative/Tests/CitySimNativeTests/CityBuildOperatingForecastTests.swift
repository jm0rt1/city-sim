import XCTest
@testable import CitySimNative

final class CityBuildOperatingForecastTests: XCTestCase {
    func testServiceForecastUsesAuthoritativeOperatingCharge() throws {
        let state = CityGameState.newCity(seed: 42)
        let tile = try validTile(for: .park, in: state)
        let forecast = try XCTUnwrap(
            CityBuildOperatingForecast.make(kind: .park, tile: tile, state: state)
        )

        XCTAssertEqual(
            forecast.change,
            -BuildingKind.park.upkeep * CitySimulation.upkeepMultiplier,
            accuracy: 0.001
        )
        XCTAssertNotEqual(forecast.change, -BuildingKind.park.upkeep)
    }

    func testProductiveWorkplaceForecastIncludesRevenueAndEmploymentChange() throws {
        var state = CityGameState.newCity(seed: 42)
        state.population = 500
        state.jobs = 120
        let tile = try validTile(for: .commercial, in: state)
        let forecast = try XCTUnwrap(
            CityBuildOperatingForecast.make(kind: .commercial, tile: tile, state: state)
        )

        XCTAssertGreaterThan(forecast.completedBalance, forecast.currentBalance)
        XCTAssertGreaterThan(forecast.change, 0)
    }

    func testReserveUtilityForecastIncludesDiscountAndDemandingEconomy() throws {
        var state = CityGameState.newCity(seed: 42)
        state.sandboxRules = CitySandboxRules(
            economy: .demanding,
            incidentsEnabled: true,
            unlimitedFunds: false
        )
        let tile = try validTile(for: .waterTower, in: state)
        let forecast = try XCTUnwrap(
            CityBuildOperatingForecast.make(kind: .waterTower, tile: tile, state: state)
        )
        let undiscounted = -BuildingKind.waterTower.upkeep
            * CitySimulation.upkeepMultiplier
            * CitySandboxEconomy.demanding.upkeepMultiplier

        XCTAssertGreaterThan(forecast.change, undiscounted)
        XCTAssertLessThan(forecast.change, 0)
    }

    func testUnlimitedFundsPresentationLabelsTrackedNetAndCompletionTiming() throws {
        var state = CityGameState.newCity(seed: 42)
        state.sandboxRules = CitySandboxRules(
            economy: .standard,
            incidentsEnabled: true,
            unlimitedFunds: true
        )
        let tile = try validTile(for: .school, in: state)
        let decision = try XCTUnwrap(
            CityMapPrimaryActionPresentation.make(
                interactionMode: .build(.school),
                tile: tile,
                state: state
            ).buildDecision
        )

        XCTAssertEqual(decision.cost, "Cost waived · online in 4 ticks")
        XCTAssertTrue(decision.operatingImpact.hasPrefix("Tracked net"))
        XCTAssertNotNil(decision.operatingForecast)
    }

    func testRoadPlacementForecastDistinguishesNetworkShapeAndNewAccess() throws {
        var state = CityGameState.newCity(seed: 42)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        let target = GridCoordinate(x: 10, y: 10)
        let north = GridCoordinate(x: 10, y: 9)
        let east = GridCoordinate(x: 11, y: 10)
        let south = GridCoordinate(x: 10, y: 11)
        let west = GridCoordinate(x: 9, y: 10)

        XCTAssertEqual(
            CityRoadPlacementForecast.make(at: target, in: state)?.summary,
            "Separate road segment · serves 4 open parcels"
        )

        state.updateTile(at: north) { $0.kind = .road }
        XCTAssertEqual(
            CityRoadPlacementForecast.make(at: target, in: state)?.summary,
            "Extends 1 approach · serves 3 open parcels"
        )

        state.updateTile(at: south) { $0.kind = .road }
        let twoApproach = try XCTUnwrap(
            CityRoadPlacementForecast.make(at: target, in: state)
        )
        XCTAssertEqual(twoApproach.adjacentRoadApproaches, 2)
        XCTAssertEqual(twoApproach.newlyServedOpenParcels, 2)
        XCTAssertEqual(
            twoApproach.summary,
            "Connects 2 approaches · serves 2 open parcels"
        )

        let targetTile = try XCTUnwrap(state.tile(at: target))
        let decision = CityBuildDecisionPresentation.make(
            kind: .road,
            tile: targetTile,
            rejection: nil,
            state: state
        )
        XCTAssertEqual(decision.likelyConsequence, twoApproach.summary)
        XCTAssertTrue(decision.accessibilitySummary.contains(twoApproach.summary))

        state.updateTile(at: east) { $0.kind = .road }
        XCTAssertEqual(
            CityRoadPlacementForecast.make(at: target, in: state)?.summary,
            "3-way junction · serves 1 open parcel"
        )

        state.updateTile(at: west) { $0.kind = .road }
        XCTAssertEqual(
            CityRoadPlacementForecast.make(at: target, in: state)?.summary,
            "4-way junction · serves no new open parcel"
        )

        state.updateTile(at: target) { $0.kind = .residential }
        let occupied = CityBuildDecisionPresentation.make(
            kind: .road,
            tile: try XCTUnwrap(state.tile(at: target)),
            rejection: .occupied,
            state: state
        )
        XCTAssertEqual(
            occupied.likelyConsequence,
            "Clear this occupied block before the road network can change"
        )
        XCTAssertNil(CityRoadPlacementForecast.make(at: target, in: state))
    }

    func testParkPlacementForecastCountsCurrentLocalBenefitsAndPollutionRelief() throws {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 100_000
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        let target = GridCoordinate(x: 10, y: 10)
        let developed: [(GridCoordinate, BuildingKind)] = [
            (GridCoordinate(x: 10, y: 8), .industrial),
            (GridCoordinate(x: 10, y: 9), .residential),
            (GridCoordinate(x: 11, y: 10), .residential),
            (GridCoordinate(x: 10, y: 11), .residential),
            (GridCoordinate(x: 9, y: 10), .residential),
        ]
        for (coordinate, kind) in developed {
            state.updateTile(at: coordinate) {
                $0 = CityTile(
                    coordinate: coordinate,
                    kind: kind,
                    occupancy: kind == .industrial ? 60 : 180,
                    constructionProgress: 1
                )
            }
        }

        let forecast = try XCTUnwrap(
            CityParkPlacementForecast.make(at: target, in: state)
        )
        XCTAssertEqual(forecast.benefitedDevelopedBlocks, 5)
        XCTAssertEqual(forecast.pollutionRelievedBlocks, 5)
        XCTAssertEqual(forecast.greatestPollutionReduction, 0.16 * (2.0 / 3.0), accuracy: 0.000_001)
        XCTAssertEqual(
            forecast.summary,
            "Benefits 5 blocks · pollution up to 11 pts lower"
        )

        let targetTile = try XCTUnwrap(state.tile(at: target))
        let decision = CityBuildDecisionPresentation.make(
            kind: .park,
            tile: targetTile,
            rejection: nil,
            state: state
        )
        XCTAssertEqual(decision.likelyConsequence, forecast.summary)
        XCTAssertTrue(decision.accessibilitySummary.contains(forecast.summary))
    }

    func testParkPlacementForecastIsTruthfulWithNoCurrentLocalBenefitAndNoFunds() throws {
        var state = CityGameState.newCity(seed: 42)
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        state.treasury = 0
        let target = GridCoordinate(x: 10, y: 10)
        let targetTile = try XCTUnwrap(state.tile(at: target))
        let forecast = try XCTUnwrap(
            CityParkPlacementForecast.make(at: target, in: state)
        )
        XCTAssertEqual(forecast.benefitedDevelopedBlocks, 0)
        XCTAssertEqual(forecast.pollutionRelievedBlocks, 0)
        XCTAssertEqual(forecast.greatestPollutionReduction, 0)
        XCTAssertEqual(forecast.summary, "No additional local benefit at this site")

        let neighbor = GridCoordinate(x: 10, y: 9)
        state.updateTile(at: neighbor) {
            $0 = CityTile(
                coordinate: neighbor,
                kind: .residential,
                occupancy: 180,
                constructionProgress: 1
            )
        }
        let valueOnlyForecast = try XCTUnwrap(
            CityParkPlacementForecast.make(at: target, in: state)
        )
        XCTAssertEqual(valueOnlyForecast.benefitedDevelopedBlocks, 1)
        XCTAssertEqual(valueOnlyForecast.pollutionRelievedBlocks, 0)
        XCTAssertEqual(
            valueOnlyForecast.summary,
            "Benefits 1 block · local value or happiness rises"
        )

        let blockedDecision = CityBuildDecisionPresentation.make(
            kind: .park,
            tile: targetTile,
            rejection: .insufficientFunds,
            state: state
        )
        XCTAssertEqual(blockedDecision.disabledReason, BuildRejection.insufficientFunds.message)
        XCTAssertEqual(blockedDecision.likelyConsequence, valueOnlyForecast.summary)
        XCTAssertEqual(state.treasury, 0)
        XCTAssertEqual(state.tile(at: target)?.kind, .empty)
    }

    func testUtilityPlacementForecastMeasuresSiteReachForPowerAndWater() throws {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 100_000
        state.powerCapacity = 0
        state.powerUsed = 150
        state.waterCapacity = 0
        state.waterUsed = 135
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        let target = GridCoordinate(x: 10, y: 10)
        let road = GridCoordinate(x: 9, y: 10)
        state.updateTile(at: road) {
            $0 = CityTile(coordinate: road, kind: .road)
        }
        let connector = GridCoordinate(x: 9, y: 9)
        state.updateTile(at: connector) {
            $0 = CityTile(coordinate: connector, kind: .road)
        }
        let developed = [
            GridCoordinate(x: 10, y: 9),
            GridCoordinate(x: 12, y: 10),
            GridCoordinate(x: 10, y: 13),
        ]
        for coordinate in developed {
            state.updateTile(at: coordinate) {
                $0 = CityTile(
                    coordinate: coordinate,
                    kind: .residential,
                    occupancy: 180,
                    constructionProgress: 1
                )
            }
        }

        let targetTile = try XCTUnwrap(state.tile(at: target))
        for kind in [BuildingKind.powerPlant, .waterTower] {
            let forecast = try XCTUnwrap(
                CityUtilityPlacementForecast.make(
                    kind: kind,
                    at: target,
                    in: state
                )
            )
            XCTAssertEqual(forecast.kind, kind)
            XCTAssertEqual(forecast.improvedDevelopedBlocks, 3)
            XCTAssertEqual(forecast.restoredHealthyBlocks, 1)
            XCTAssertEqual(forecast.greatestServiceGain, 11.0 / 12.0, accuracy: 0.000_001)

            let decision = CityBuildDecisionPresentation.make(
                kind: kind,
                tile: targetTile,
                rejection: nil,
                state: state
            )
            XCTAssertEqual(decision.likelyConsequence, forecast.summary)
            XCTAssertTrue(decision.accessibilitySummary.contains(forecast.summary))
        }
        XCTAssertEqual(
            CityUtilityPlacementForecast.make(
                kind: .powerPlant,
                at: target,
                in: state
            )?.summary,
            "Power: 3 blocks improve · 1 reaches healthy"
        )
        XCTAssertEqual(
            CityUtilityPlacementForecast.make(
                kind: .waterTower,
                at: target,
                in: state
            )?.summary,
            "Water: 3 blocks improve · 1 reaches healthy"
        )
        XCTAssertEqual(
            CityUtilityPlacementForecast(
                kind: .powerPlant,
                improvedDevelopedBlocks: 1,
                restoredHealthyBlocks: 0,
                greatestServiceGain: 0.004
            ).summary,
            "Power: 1 block improves · best under +1 pt"
        )
        XCTAssertEqual(state.treasury, 100_000)
        XCTAssertEqual(state.tile(at: target)?.kind, .empty)
    }

    func testUtilityPlacementForecastNamesNoCurrentReachAndRejectsInvalidTargets() throws {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 0
        state.powerCapacity = 0
        state.powerUsed = 150
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        let target = GridCoordinate(x: 0, y: 0)
        let road = GridCoordinate(x: 1, y: 0)
        let remote = GridCoordinate(x: state.gridWidth - 1, y: state.gridHeight - 1)
        state.updateTile(at: road) {
            $0 = CityTile(coordinate: road, kind: .road)
        }
        state.updateTile(at: remote) {
            $0 = CityTile(
                coordinate: remote,
                kind: .residential,
                occupancy: 180,
                constructionProgress: 1
            )
        }
        for x in 2..<state.gridWidth {
            let coordinate = GridCoordinate(x: x, y: 0)
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .road)
            }
        }
        for y in 1..<(state.gridHeight - 1) {
            let coordinate = GridCoordinate(x: state.gridWidth - 1, y: y)
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .road)
            }
        }

        let targetTile = try XCTUnwrap(state.tile(at: target))
        let forecast = try XCTUnwrap(
            CityUtilityPlacementForecast.make(
                kind: .powerPlant,
                at: target,
                in: state
            )
        )
        XCTAssertEqual(forecast.improvedDevelopedBlocks, 0)
        XCTAssertEqual(forecast.restoredHealthyBlocks, 0)
        XCTAssertEqual(forecast.greatestServiceGain, 0)
        XCTAssertEqual(
            forecast.summary,
            "No current block gains power service here"
        )

        let blockedDecision = CityBuildDecisionPresentation.make(
            kind: .powerPlant,
            tile: targetTile,
            rejection: .insufficientFunds,
            state: state
        )
        XCTAssertEqual(blockedDecision.likelyConsequence, forecast.summary)
        XCTAssertNil(
            CityUtilityPlacementForecast.make(
                kind: .park,
                at: target,
                in: state
            )
        )
        state.updateTile(at: target) { $0.kind = .residential }
        XCTAssertNil(
            CityUtilityPlacementForecast.make(
                kind: .powerPlant,
                at: target,
                in: state
            )
        )
        XCTAssertEqual(state.treasury, 0)
    }

    func testCivicServicePlacementForecastNamesExactHappinessAndStormPayoff() throws {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 0
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        let target = GridCoordinate(x: 10, y: 10)
        let road = GridCoordinate(x: 9, y: 10)
        state.updateTile(at: road) {
            $0 = CityTile(coordinate: road, kind: .road)
        }
        let targetTile = try XCTUnwrap(state.tile(at: target))

        for kind in [BuildingKind.fireStation, .policeStation, .school] {
            let forecast = try XCTUnwrap(
                CityCivicServicePlacementForecast.make(
                    kind: kind,
                    at: target,
                    in: state
                )
            )
            XCTAssertEqual(forecast.kind, kind)
            XCTAssertEqual(forecast.happinessTargetGain, 2.5, accuracy: 0.000_001)
            XCTAssertEqual(forecast.stormDamageReduction, 0.04, accuracy: 0.000_001)
            XCTAssertEqual(
                forecast.summary,
                "Happiness target +2.5 pts · storm damage -4 pts"
            )

            let decision = CityBuildDecisionPresentation.make(
                kind: kind,
                tile: targetTile,
                rejection: .insufficientFunds,
                state: state
            )
            XCTAssertEqual(decision.likelyConsequence, forecast.summary)
            XCTAssertTrue(decision.accessibilitySummary.contains(forecast.summary))
        }
        XCTAssertEqual(state.treasury, 0)
        XCTAssertEqual(state.tile(at: target)?.kind, .empty)
    }

    func testCivicServicePlacementForecastReportsBenefitCapsAndInvalidTargets() throws {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 100_000
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        let target = GridCoordinate(x: 10, y: 10)
        state.updateTile(at: GridCoordinate(x: 9, y: 10)) {
            $0 = CityTile(coordinate: GridCoordinate(x: 9, y: 10), kind: .road)
        }
        let services = [
            GridCoordinate(x: 2, y: 2),
            GridCoordinate(x: 4, y: 2),
            GridCoordinate(x: 6, y: 2),
            GridCoordinate(x: 8, y: 2),
        ]
        for (index, coordinate) in services.enumerated() {
            state.updateTile(at: coordinate) {
                $0 = CityTile(
                    coordinate: coordinate,
                    kind: index == 0 ? .fireStation : index == 1 ? .policeStation : .school,
                    constructionProgress: 1
                )
            }
        }
        for y in 2...9 {
            let coordinate = GridCoordinate(x: 9, y: y)
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .road)
            }
        }

        let capped = try XCTUnwrap(
            CityCivicServicePlacementForecast.make(
                kind: .fireStation,
                at: target,
                in: state
            )
        )
        XCTAssertEqual(capped.happinessTargetGain, 0)
        XCTAssertEqual(capped.stormDamageReduction, 0)
        XCTAssertEqual(
            capped.summary,
            "No additional citywide service benefit at current staffing"
        )
        XCTAssertNil(
            CityCivicServicePlacementForecast.make(
                kind: .park,
                at: target,
                in: state
            )
        )
        state.updateTile(at: target) { $0.kind = .residential }
        XCTAssertNil(
            CityCivicServicePlacementForecast.make(
                kind: .school,
                at: target,
                in: state
            )
        )
    }

    func testDisconnectedStreetBlocksDevelopmentWithTruthfulRecovery() throws {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 100_000
        for coordinate in state.tiles.map(\.coordinate) {
            state.updateTile(at: coordinate) {
                $0 = CityTile(coordinate: coordinate, kind: .empty)
            }
        }
        let cityHall = GridCoordinate(x: 2, y: 2)
        let cityRoad = GridCoordinate(x: 3, y: 2)
        let isolatedRoad = GridCoordinate(x: 9, y: 10)
        let target = GridCoordinate(x: 10, y: 10)
        state.updateTile(at: cityHall) {
            $0 = CityTile(coordinate: cityHall, kind: .cityHall, constructionProgress: 1)
        }
        state.updateTile(at: cityRoad) {
            $0 = CityTile(coordinate: cityRoad, kind: .road, constructionProgress: 1)
        }
        state.updateTile(at: isolatedRoad) {
            $0 = CityTile(coordinate: isolatedRoad, kind: .road, constructionProgress: 1)
        }

        let tile = try XCTUnwrap(state.tile(at: target))
        let action = CityMapPrimaryActionPresentation.make(
            interactionMode: .build(.commercial),
            tile: tile,
            state: state
        )
        XCTAssertFalse(action.isAvailable)
        XCTAssertTrue(action.disclosure.contains(BuildRejection.cityRoadConnectionRequired.message))
        let decision = try XCTUnwrap(action.buildDecision)
        XCTAssertEqual(decision.availability, "Blocked")
        XCTAssertEqual(decision.disabledReason, BuildRejection.cityRoadConnectionRequired.message)
        XCTAssertEqual(decision.recovery?.title, "Connect street")
        XCTAssertEqual(decision.recovery?.command, .buildRoad)
        XCTAssertTrue(decision.recovery?.focusesMap == true)
        XCTAssertTrue(decision.accessibilitySummary.contains("Connect street"))
        XCTAssertTrue(decision.accessibilitySummary.contains("active city network"))
        XCTAssertEqual(state.tile(at: target)?.kind, .empty)
        XCTAssertEqual(state.treasury, 100_000)
    }

    func testDemolitionForecastNamesHousingJobsUtilitiesRoadsAndServices() throws {
        var state = CityGameState.newCity(seed: 42)
        state.treasury = 100_000
        for kind in [BuildingKind.commercial, .powerPlant, .waterTower, .fireStation] {
            let coordinate = try validTile(for: kind, in: state).coordinate
            guard case .success = CitySimulation.build(kind, at: coordinate, in: &state) else {
                return XCTFail("Expected \(kind.title) fixture to build")
            }
            state.updateTile(at: coordinate) { $0.constructionProgress = 1 }
        }
        state.powerCapacity = CitySimulation.powerCapacityPerPlant * 2
        state.waterCapacity = CitySimulation.waterCapacityPerTower * 2

        let residential = try XCTUnwrap(state.tiles.first { $0.kind == .residential })
        let road = try XCTUnwrap(state.tiles.first { $0.kind == .road })
        XCTAssertTrue(try XCTUnwrap(CityDemolitionForecast.make(tile: residential, state: state)).capacityImpact.hasPrefix("Housing "))
        XCTAssertTrue(try XCTUnwrap(CityDemolitionForecast.make(tile: try tile(.commercial, in: state), state: state)).capacityImpact.hasPrefix("Jobs "))
        XCTAssertTrue(try XCTUnwrap(CityDemolitionForecast.make(tile: try tile(.powerPlant, in: state), state: state)).capacityImpact.hasPrefix("Power "))
        XCTAssertTrue(try XCTUnwrap(CityDemolitionForecast.make(tile: try tile(.waterTower, in: state), state: state)).capacityImpact.hasPrefix("Water "))
        XCTAssertEqual(
            try XCTUnwrap(CityDemolitionForecast.make(tile: road, state: state)).capacityImpact,
            "Road access may change for adjacent blocks"
        )
        XCTAssertEqual(
            try XCTUnwrap(CityDemolitionForecast.make(tile: try tile(.fireStation, in: state), state: state)).capacityImpact,
            "Removes civic service and storm protection"
        )
    }

    func testDemolitionForecastIncludesFeeDebtAndUnlimitedFundsRules() throws {
        var funded = CityGameState.newCity(seed: 42)
        let residential = try XCTUnwrap(funded.tiles.first { $0.kind == .residential })
        let fundedForecast = try XCTUnwrap(CityDemolitionForecast.make(tile: residential, state: funded))
        funded.treasury = 0
        let debtForecast = try XCTUnwrap(CityDemolitionForecast.make(tile: residential, state: funded))
        funded.sandboxRules = CitySandboxRules(
            economy: .standard,
            incidentsEnabled: true,
            unlimitedFunds: true
        )
        let unlimitedForecast = try XCTUnwrap(CityDemolitionForecast.make(tile: residential, state: funded))

        XCTAssertLessThan(debtForecast.balanceChange, fundedForecast.balanceChange)
        XCTAssertGreaterThan(unlimitedForecast.balanceChange, debtForecast.balanceChange)
    }

    private func validTile(for kind: BuildingKind, in state: CityGameState) throws -> CityTile {
        try XCTUnwrap(state.tiles.first { tile in
            guard tile.kind == .empty else { return false }
            if case .success = CitySimulation.validateBuild(kind, at: tile.coordinate, in: state) {
                return true
            }
            return false
        })
    }

    private func tile(_ kind: BuildingKind, in state: CityGameState) throws -> CityTile {
        try XCTUnwrap(state.tiles.first { $0.kind == kind })
    }
}
