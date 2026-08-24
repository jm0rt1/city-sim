import SwiftUI

enum GameTheme {
    static let accent = Color(red: 0.23, green: 0.78, blue: 0.68)
    static let primaryAction = Color(red: 0.96, green: 0.69, blue: 0.30)
    static let information = Color(red: 0.25, green: 0.72, blue: 0.92)
    static let warning = Color(red: 1.0, green: 0.67, blue: 0.24)
    static let danger = Color(red: 0.95, green: 0.31, blue: 0.31)
    static let panel = Color.black.opacity(0.56)
    static let opaquePanel = Color(red: 0.075, green: 0.082, blue: 0.095)
    static let panelStroke = Color(red: 0.88, green: 0.83, blue: 0.66).opacity(0.18)
    static let strongPanelStroke = Color(red: 0.90, green: 0.84, blue: 0.64).opacity(0.28)
    static let inactiveControl = Color.primary.opacity(0.12)
    static let contextCard = Color.primary.opacity(0.10)
    static let contextCardSelected = accent.opacity(0.14)
    static let subtleDivider = Color.white.opacity(0.16)
    static let hudSurfaceFill = Color(red: 0.075, green: 0.105, blue: 0.09).opacity(0.94)
    static let hudRaisedFill = Color(red: 0.17, green: 0.20, blue: 0.16).opacity(0.92)
    static let hudChromeRadius: CGFloat = 12
    static let hudShadow = Color.black.opacity(0.16)
    static let hudCriticalTextSize: CGFloat = 13
    static let hudSupportTextSize: CGFloat = 12
    static let hudMetricValueTextSize: CGFloat = 15

    static let controlMinimum: CGFloat = 44
    static let compactRadius: CGFloat = 12
    static let panelRadius: CGFloat = 16
    static let shellSpacing: CGFloat = 10
    static let compactPadding: CGFloat = 9
    static let regularPadding: CGFloat = 14
    static let contextCardWidth: CGFloat = 238
    static let compactContextCardWidth: CGFloat = 214
    static let motionDuration = 0.22

    static func animation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: motionDuration)
    }

    static func transition(edge: Edge, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }
}

private struct CityHUDSurfaceModifier: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: GameTheme.hudChromeRadius,
            style: .continuous
        )
        content
            .background(GameTheme.hudSurfaceFill, in: shape)
            .overlay(
                shape.stroke(
                    prominent ? GameTheme.strongPanelStroke : GameTheme.panelStroke,
                    lineWidth: 1
                )
            )
            .shadow(color: GameTheme.hudShadow, radius: prominent ? 9 : 7, y: 3)
    }
}

extension View {
    func cityHUDSurface(prominent: Bool = false) -> some View {
        modifier(CityHUDSurfaceModifier(prominent: prominent))
    }
}

extension Double {
    var currencyText: String {
        formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    var percentText: String {
        formatted(.number.precision(.fractionLength(0))) + "%"
    }

    var signedCurrencyText: String {
        self > 0 ? "+" + currencyText : currencyText
    }
}

extension Int {
    var compactText: String {
        formatted(.number.notation(.compactName))
    }
}
