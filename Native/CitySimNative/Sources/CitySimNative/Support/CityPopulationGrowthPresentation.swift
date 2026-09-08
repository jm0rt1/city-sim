import Foundation

/// Current move-in conditions, distinct from capacity for a future population.
struct CityPopulationGrowthPresentation: Equatable, Sendable {
    let dailyChange: Int
    let title: String
    let detail: String
    let response: CityDirectResponse

    var accessibilitySummary: String {
        "Population growth. \(title). \(detail) This is a daily estimate at current conditions, not a guaranteed future result."
    }

    static func make(analytics: CityAnalytics, speed: SimulationSpeed) -> Self {
        let state = analytics.state
        let change = CitySimulation.projectedDailyPopulationChange(in: state)
        let title = change > 0 ? "Move-ins +\(change)/day" : change < 0 ? "Residents \(change)/day" : "Move-ins held"
        func inspect(_ command: CityCommandID, _ action: String, _ detail: String) -> Self {
            .init(dailyChange: change, title: title, detail: detail,
                  response: .init(title: action, command: command, explanation: detail, focusesMap: false))
        }
        if analytics.utilityCoverage < 0.82 {
            return inspect(.inspectorUtilities, "Review utilities",
                "Utility coverage is \((analytics.utilityCoverage * 100).percentText); residents leave below 82%.")
        }
        if state.happiness < 32 {
            return inspect(.inspectorHappiness, "Review happiness",
                "Happiness is \(state.happiness.percentText); residents leave below 32%.")
        }
        if analytics.utilityCoverage <= 0.88 {
            return inspect(.inspectorUtilities, "Review utilities",
                "Utility coverage is \((analytics.utilityCoverage * 100).percentText); move-ins need more than 88%.")
        }
        if state.happiness <= 45 {
            return inspect(.inspectorHappiness, "Review happiness",
                "Happiness is \(state.happiness.percentText); move-ins need more than 45%.")
        }
        if analytics.housingCapacity <= state.population {
            return .init(dailyChange: change, title: title,
                detail: "Completed housing is full. Add housing capacity before more residents can move in.",
                response: .init(title: "Build homes", command: .buildResidential,
                    explanation: "Create residential capacity for more residents.", focusesMap: true))
        }
        if max(120, analytics.jobCapacity * 2) <= state.population {
            return inspect(.inspectorEmployment, "Review jobs",
                "Job capacity limits population to \(max(120, analytics.jobCapacity * 2).formatted()). More homes alone will not restart move-ins.")
        }
        let paused = speed == .paused
        let detail = "Existing homes have room for \(analytics.housingHeadroom.formatted()) more residents. \(paused ? "Resume simulation to allow move-ins." : "Move-ins are running with the simulation.")"
        return .init(dailyChange: change, title: title, detail: detail,
            response: .init(title: paused ? "Resume growth" : "Pause growth", command: .togglePause,
                explanation: paused ? "Resume the city without building or spending; growth depends on city conditions." : "Pause the city to review growth conditions.",
                focusesMap: false))
    }
}
