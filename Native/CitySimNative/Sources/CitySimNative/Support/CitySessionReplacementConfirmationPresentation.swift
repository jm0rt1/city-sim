import Foundation

enum CitySessionReplacementAction: Equatable, Sendable {
    case newRegion
    case loadQuicksave
}

struct CitySessionReplacementConfirmationPresentation: Equatable, Sendable {
    let action: CitySessionReplacementAction
    let title: String
    let message: String
    let destructiveActionTitle: String
    let cancelActionTitle: String

    static func make(
        state: CityGameState,
        action: CitySessionReplacementAction
    ) -> Self {
        let checkpoint = "\(state.cityName) · \(state.formattedDay) · "
            + "\(state.population.formatted()) residents"
        return switch action {
        case .newRegion:
            Self(
                action: action,
                title: "Replace \(state.cityName)?",
                message: "\(checkpoint) will be replaced. "
                    + "Save the city first if you want to return to this checkpoint.",
                destructiveActionTitle: "Start New Region",
                cancelActionTitle: "Keep \(state.cityName)"
            )
        case .loadQuicksave:
            Self(
                action: action,
                title: "Load Quicksave over \(state.cityName)?",
                message: "\(checkpoint) is currently open. Loading the quicksave will replace it. "
                    + "Save this city first if you want to return to this checkpoint.",
                destructiveActionTitle: "Load Quicksave",
                cancelActionTitle: "Keep \(state.cityName)"
            )
        }
    }
}
