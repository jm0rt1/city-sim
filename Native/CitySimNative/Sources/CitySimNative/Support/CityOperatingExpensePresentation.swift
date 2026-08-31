import Foundation

/// Read-only attribution of the existing upkeep forecast. Never feeds simulation or saves.
struct CityOperatingExpensePresentation: Equatable {
    enum Category: Int, CaseIterable {
        case utilities, civicServices, roads, cityHall, buildingsAndParks, debtInterest

        var title: String {
            switch self {
            case .utilities: "Utilities"
            case .civicServices: "Civic services"
            case .roads: "Roads"
            case .cityHall: "City Hall"
            case .buildingsAndParks: "Buildings & parks"
            case .debtInterest: "Debt interest"
            }
        }

        var explanation: String {
            switch self {
            case .utilities: "Completed power and water facilities, including reserve-facility discounts."
            case .civicServices: "Completed fire stations, police stations, and schools at current service funding."
            case .roads: "Completed road blocks at current maintenance funding."
            case .cityHall: "Completed City Hall administration."
            case .buildingsAndParks: "Completed homes, workplaces, and parks."
            case .debtInterest: "Interest on a negative treasury balance."
            }
        }
    }

    struct Row: Equatable, Identifiable {
        let category: Category
        let amount: Double
        let completedSites: Int
        let share: Double
        var id: Category { category }
        var amountText: String { CityOperatingExpensePresentation.money(amount) }
        var detail: String {
            let percentage = "\(Int((share * 100).rounded()))%"
            if category == .debtInterest {
                return amount > 0 ? "Borrowing cost · \(percentage)" : "No debt interest"
            }
            let noun = category == .roads ? "block" : "site"
            let unit = completedSites == 1 ? noun : noun + "s"
            return "\(completedSites) completed \(unit) · \(percentage)"
        }
        var accessibilitySummary: String {
            "\(category.title), \(amountText) per cycle. \(detail). \(category.explanation)"
        }
    }

    let total: Double
    let rows: [Row]
    var totalText: String { "Upkeep \(Self.money(total)) / cycle" }

    static func make(in state: CityGameState) -> Self {
        let active = CitySimulation.activeTiles(in: state)
        let economyMultiplier = state.sandboxRules?.economy.upkeepMultiplier ?? 1
        let siteMultiplier = CitySimulation.upkeepMultiplier * economyMultiplier
        let total = CitySimulation.projectedUpkeep(in: state)
        func tiles(_ kinds: Set<BuildingKind>) -> [CityTile] {
            active.filter { kinds.contains($0.kind) }
        }
        func gross(_ sites: [CityTile]) -> Double {
            sites.reduce(0) { $0 + $1.kind.upkeep * Double(max(1, $1.level)) }
        }
        let utilities = tiles([.powerPlant, .waterTower])
        let reserveDiscount = [BuildingKind.powerPlant, .waterTower].reduce(0.0) { sum, kind in
            let reserves = max(0, utilities.filter { $0.kind == kind }.count - 1)
            return sum + Double(reserves) * kind.upkeep * (1 - CitySimulation.reserveUtilityUpkeepFactor)
        }
        let civic = tiles([.fireStation, .policeStation, .school])
        let roads = tiles([.road])
        let halls = tiles([.cityHall])
        let buildings = tiles([.residential, .commercial, .industrial, .park])
        let components: [(Category, Double, Int)] = [
            (.utilities, (gross(utilities) - reserveDiscount) * siteMultiplier, utilities.count),
            (.civicServices, CitySimulation.projectedCivicServiceUpkeep(in: state), civic.count),
            (.roads, CitySimulation.projectedRoadMaintenanceUpkeep(in: state), roads.count),
            (.cityHall, gross(halls) * siteMultiplier, halls.count),
            (.buildingsAndParks, gross(buildings) * siteMultiplier, buildings.count),
            (.debtInterest, max(0, -state.treasury) * 0.006 * economyMultiplier, 0)
        ]
        return Self(total: total, rows: components.map { category, amount, count in
            Row(category: category, amount: amount, completedSites: count, share: total > 0 ? amount / total : 0)
        }.sorted {
            $0.amount == $1.amount ? $0.category.rawValue < $1.category.rawValue : $0.amount > $1.amount
        })
    }

    private static func money(_ amount: Double) -> String {
        amount.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
}
