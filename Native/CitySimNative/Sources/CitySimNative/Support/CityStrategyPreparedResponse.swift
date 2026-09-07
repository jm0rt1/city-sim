import Foundation

/// Prepared is reversible; only the simulation can lock a recovery result.
struct CityStrategyPreparedResponse: Equatable {
    let resolution: CityStrategyRecoveryResolution
    let title: String
    let detail: String
    let days: Int

    static func make(analytics: CityAnalytics) -> Self? {
        guard analytics.state.authoredScenario == nil,
              analytics.state.sandboxRules == nil,
              analytics.secondActPhase == nil,
              let story = analytics.state.progression?.strategy,
              story.currentPhase != .completed,
              story.recoveryResolution == nil,
              let days = analytics.strategyDaysUntilConsequence,
              let resolution = CitySimulation.qualifyingResolution(
                for: story.committedStrategy, in: analytics.state
              ) else { return nil }

        let title: String
        let requirement: String
        switch resolution {
        case .commercialTaxRelief:
            title = "Tax relief ready"
            requirement = "Keep tax at 9% or less"
        case .commercialPublicRealmInvestment:
            title = "Public space ready"
            requirement = "Keep two completed parks"
        case .industrialUtilityExpansion:
            title = "Utility response ready"
            requirement = "Keep two completed power plants and water towers"
        case .industrialGreenBuffer:
            title = "Green buffer ready"
            requirement = "Keep two completed parks"
        }
        let review = days == 1 ? "1 day" : "\(days) days"
        let budget = analytics.projectedBalance < 0
            ? " Operations still forecast \(analytics.projectedBalance.signedCurrencyText) per cycle."
            : ""
        return Self(
            resolution: resolution,
            title: title,
            detail: "\(title). \(requirement) until the next review in \(review). The result is not locked in yet.\(budget)",
            days: days
        )
    }
}
