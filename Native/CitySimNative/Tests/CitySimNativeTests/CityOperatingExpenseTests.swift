import AppKit
import SwiftUI
import XCTest
@testable import CitySimNative

final class CityOperatingExpenseTests: XCTestCase {
    func testExpenseAttributionReconcilesEveryFundingAndSandboxEconomyWithoutMutation() {
        for economy in CitySandboxEconomy.allCases {
            for roadPolicy in CityRoadMaintenancePolicy.allCases {
                for civicPolicy in CityCivicServiceFundingPolicy.allCases {
                    var state = mixedCity()
                    state.sandboxRules = CitySandboxRules(
                        economy: economy, incidentsEnabled: true, unlimitedFunds: false
                    )
                    state.roadMaintenancePolicy = roadPolicy
                    state.civicServiceFundingPolicy = civicPolicy
                    state.treasury = -6_000
                    let before = state

                    let expenses = CityOperatingExpensePresentation.make(in: state)

                    XCTAssertEqual(expenses.total, CitySimulation.projectedUpkeep(in: state))
                    XCTAssertEqual(expenses.rows.reduce(0) { $0 + $1.amount }, expenses.total, accuracy: 0.000_001)
                    XCTAssertEqual(expenses.rows.reduce(0) { $0 + $1.share }, 1, accuracy: 0.000_001)
                    XCTAssertEqual(expenses.rows.count, 6)
                    XCTAssertEqual(expenses.rows.map(\.amount), expenses.rows.map(\.amount).sorted(by: >))
                    XCTAssertEqual(expenses, .make(in: state))
                    XCTAssertEqual(state, before)
                    XCTAssertEqual(row(.roads, in: expenses).amount, CitySimulation.projectedRoadMaintenanceUpkeep(in: state))
                    XCTAssertEqual(row(.civicServices, in: expenses).amount, CitySimulation.projectedCivicServiceUpkeep(in: state))
                    XCTAssertEqual(row(.debtInterest, in: expenses).amount, 36 * economy.upkeepMultiplier)
                }
            }
        }
    }

    func testReserveUtilitiesLevelsAndIncompleteSitesUseTheExistingUpkeepRules() {
        var state = emptyCity()
        put(.powerPlant, x: 1, level: 2, in: &state)
        put(.powerPlant, x: 2, in: &state)
        put(.waterTower, x: 3, in: &state)
        put(.waterTower, x: 4, in: &state)
        put(.powerPlant, x: 5, progress: 0.5, in: &state)
        put(.school, x: 6, progress: 0.5, in: &state)

        let expenses = CityOperatingExpensePresentation.make(in: state)
        let utility = row(.utilities, in: expenses)

        XCTAssertEqual(utility.completedSites, 4)
        XCTAssertEqual(utility.amount, 690.75, accuracy: 0.000_001)
        XCTAssertEqual(expenses.total, utility.amount)
        XCTAssertEqual(utility.share, 1)
        XCTAssertEqual(row(.civicServices, in: expenses).amount, 0)
        XCTAssertEqual(row(.civicServices, in: expenses).completedSites, 0)
        XCTAssertTrue(utility.accessibilitySummary.contains("reserve-facility discounts"))
        XCTAssertTrue(utility.amountText.contains("690.75"))
    }

    func testZeroCostsAndUnlimitedFundsRemainTruthful() {
        let empty = CityOperatingExpensePresentation.make(in: emptyCity())
        XCTAssertEqual(empty.total, 0)
        XCTAssertTrue(empty.rows.allSatisfy { $0.amount == 0 && $0.share == 0 })
        XCTAssertEqual(empty.rows.map(\.category), CityOperatingExpensePresentation.Category.allCases)
        var state = mixedCity()
        state.sandboxRules = CitySandboxRules(economy: .standard, incidentsEnabled: true, unlimitedFunds: true)
        state.treasury = 0
        let expenses = CityOperatingExpensePresentation.make(in: state)
        XCTAssertGreaterThan(expenses.total, 0, "Unlimited funds do not erase the operating model")
        XCTAssertEqual(expenses.total, CitySimulation.projectedUpkeep(in: state))
        XCTAssertEqual(row(.debtInterest, in: expenses).detail, "No debt interest")
    }

    @MainActor
    func testEveryExpenseFitsTheExistingCompactAndRegularDetailsBudget() {
        let expenses = CityOperatingExpensePresentation.make(in: mixedCity())
        for compact in [true, false] {
            let width = compact ? BuildToolbarView.compactDetailsWidth : BuildToolbarView.regularDetailsWidth
            let host = NSHostingView(rootView: CityOperatingExpenseBreakdownView(
                presentation: expenses, compact: compact
            ).frame(width: width - 6))
            host.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(host.fittingSize.height, 50)
            XCTAssertLessThanOrEqual(
                host.fittingSize.height + (compact ? 59 : 63),
                BuildToolbarView.detailsHeight(compact: compact, selectedBlock: false),
                "All six expense groups must fit without expanding the map-obscuring panel"
            )
        }
    }

    private func row(_ category: CityOperatingExpensePresentation.Category, in expenses: CityOperatingExpensePresentation) -> CityOperatingExpensePresentation.Row {
        expenses.rows.first { $0.category == category }!
    }

    private func mixedCity() -> CityGameState {
        var state = emptyCity()
        for (index, kind) in BuildingKind.allCases.enumerated() {
            put(kind, x: index, level: 2, in: &state)
        }
        state.updateTile(at: GridCoordinate(x: 1, y: 6)) {
            $0 = CityTile(coordinate: $0.coordinate, kind: .powerPlant)
        }
        state.updateTile(at: GridCoordinate(x: 2, y: 6)) {
            $0 = CityTile(coordinate: $0.coordinate, kind: .waterTower)
        }
        return state
    }

    private func emptyCity() -> CityGameState {
        var state = CityGameState.newCity(seed: 42)
        for index in state.tiles.indices {
            state.tiles[index] = CityTile(coordinate: state.tiles[index].coordinate, kind: .empty)
        }
        return state
    }

    private func put(_ kind: BuildingKind, x: Int, level: Int = 1, progress: Double = 1, in state: inout CityGameState) {
        state.updateTile(at: GridCoordinate(x: x, y: 5)) {
            $0.kind = kind
            $0.level = level
            $0.constructionProgress = progress
        }
    }
}
