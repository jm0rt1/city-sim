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
    let currentDemand: DemandLevels
    let proposedDemand: DemandLevels
    let currentEligibleUpgrades: Int
    let proposedEligibleUpgrades: Int

    var developmentAccessibilitySummary: String {
        "Development estimate at \(currentRateText) versus \(proposedRateText), after demand refresh. "
            + "Residential demand \((currentDemand.residential * 100).percentText) to \((proposedDemand.residential * 100).percentText). "
            + "Commercial demand \((currentDemand.commercial * 100).percentText) to \((proposedDemand.commercial * 100).percentText). "
            + "Industrial demand \((currentDemand.industrial * 100).percentText) to \((proposedDemand.industrial * 100).percentText). "
            + "Eligible upgrades \(currentEligibleUpgrades) to \(proposedEligibleUpgrades). "
            + "Other city conditions held fixed. Each site is checked independently; upgrades are not guaranteed."
    }

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
        var currentDevelopment = state
        currentDevelopment.demand = CitySimulation.projectedDemand(in: state)
        proposal.demand = CitySimulation.projectedDemand(in: proposal)
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
            canApply: state.status == .playing && changed,
            currentDemand: currentDevelopment.demand,
            proposedDemand: proposal.demand,
            currentEligibleUpgrades: eligibleUpgrades(in: currentDevelopment),
            proposedEligibleUpgrades: eligibleUpgrades(in: proposal)
        )
    }

    private static func eligibleUpgrades(in state: CityGameState) -> Int {
        state.tiles.filter { CitySimulation.developmentUpgradeEvaluation(for: $0, in: state).isEligible }.count
    }
}
