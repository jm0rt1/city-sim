import Foundation

struct NewRegionConfirmationPresentation: Equatable, Sendable {
    let title: String
    let message: String
    let destructiveActionTitle: String
    let cancelActionTitle: String

    static func make(state: CityGameState) -> Self {
        Self(
            title: "Replace \(state.cityName)?",
            message: "\(state.cityName) · \(state.formattedDay) · "
                + "\(state.population.formatted()) residents will be replaced. "
                + "Save the city first if you want to return to this checkpoint.",
            destructiveActionTitle: "Start New Region",
            cancelActionTitle: "Keep \(state.cityName)"
        )
    }
}
