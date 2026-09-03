import Foundation

struct CityTaxPolicyPreview: Equatable {
    let currentRate: Double
    let proposedRate: Double
    let currentRevenue: Double
    let proposedRevenue: Double
    let upkeep: Double
    let currentBalance: Double
    let proposedBalance: Double
    let tradeoff: String
    let canApply: Bool

    var balanceChange: Double { proposedBalance - currentBalance }
    var currentRateText: String { (currentRate * 100).percentText }
    var proposedRateText: String { (proposedRate * 100).percentText }
    var accessibilitySummary: String {
        "Tax preview, not applied. \(currentRateText) to \(proposedRateText). "
            + "Revenue \(currentRevenue.currencyText) to \(proposedRevenue.currencyText). "
            + "Upkeep remains \(upkeep.currencyText). "
            + "Net \(currentBalance.signedCurrencyText) to \(proposedBalance.signedCurrencyText) per cycle. "
            + tradeoff
    }

    static func make(in state: CityGameState, proposedRate: Double) -> Self {
        let rate = proposedRate.isFinite ? min(0.18, max(0.04, proposedRate)) : state.taxRate
        var proposal = state
        proposal.taxRate = rate
        let changed = abs(rate - state.taxRate) > 0.000_001
        let mainStreet = state.progression?.strategy
        let taxReliefOpen = mainStreet?.committedStrategy == .commercialStewardship
            && mainStreet?.recoveryResolution == nil
            && mainStreet?.currentPhase != .completed
        let tradeoff: String
        if !changed {
            tradeoff = "Choose a different rate to compare. Nothing changes until Apply."
        } else if taxReliefOpen && rate <= 0.09 {
            tradeoff = "Meets Main Street's 9% tax-relief threshold. Lower tax supports demand but reduces revenue."
        } else if taxReliefOpen && state.taxRate <= 0.09 && rate > 0.09 {
            tradeoff = "Ends Main Street's tax-relief route. Higher tax raises revenue but cools demand."
        } else if rate < state.taxRate {
            tradeoff = "Lower tax supports demand but reduces current revenue."
        } else {
            tradeoff = "Higher tax raises current revenue but cools demand."
        }
        return Self(
            currentRate: state.taxRate, proposedRate: rate,
            currentRevenue: CitySimulation.projectedRevenue(in: state),
            proposedRevenue: CitySimulation.projectedRevenue(in: proposal),
            upkeep: CitySimulation.projectedUpkeep(in: state),
            currentBalance: CitySimulation.projectedBalance(in: state),
            proposedBalance: CitySimulation.projectedBalance(in: proposal),
            tradeoff: tradeoff,
            canApply: state.status == .playing && changed
        )
    }
}
