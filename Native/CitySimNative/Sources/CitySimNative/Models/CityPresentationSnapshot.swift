import Foundation

struct CityPresentationSnapshot: Equatable, Sendable {
    let state: CityGameState
    let fingerprint: CityStateFingerprint

    init(state: CityGameState) throws {
        self.state = state
        self.fingerprint = try CityStateFingerprinter.fingerprint(state)
    }

    var authoritativeTick: Int { state.tick }
    var analytics: CityAnalytics { CityAnalytics(state: state) }
}
