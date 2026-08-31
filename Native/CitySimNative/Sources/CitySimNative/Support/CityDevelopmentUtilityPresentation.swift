import Foundation

/// The same completed-site sample used by the development forecast, split into
/// its two networks so the player can investigate the actual limiting service.
struct CityDevelopmentUtilityPresentation: Equatable, Sendable {
    struct Network: Equatable, Sendable, Identifiable {
        var id: DataOverlay { overlay }
        let overlay: DataOverlay
        let percent: Int
        let band: CityConsequenceBand
        let limitsSite: Bool

        var title: String { "\(overlay.title) \(percent)%" }
        var detail: String { limitsSite ? "Limits site" : "After build" }
        var accessibilitySummary: String {
            "After completion, \(overlay.title.lowercased()) service \(percent) percent, \(band.title)"
                + (limitsSite ? "; limits this site's utility service" : "")
        }
    }

    let networks: [Network]

    init(service: CityLocationUtilityService) {
        networks = [
            Network(overlay: .power, percent: Int((service.power * 100).rounded()),
                    band: service.powerBand,
                    limitsSite: service.powerBand != .healthy && service.power <= service.water),
            Network(overlay: .water, percent: Int((service.water * 100).rounded()),
                    band: service.waterBand,
                    limitsSite: service.waterBand != .healthy && service.water <= service.power),
        ]
    }

    var accessibilitySummary: String {
        networks.map(\.accessibilitySummary).joined(separator: ". ")
    }
}
