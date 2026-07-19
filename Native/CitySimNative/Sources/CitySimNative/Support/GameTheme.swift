import SwiftUI

enum GameTheme {
    static let accent = Color(red: 0.23, green: 0.78, blue: 0.68)
    static let information = Color(red: 0.25, green: 0.72, blue: 0.92)
    static let warning = Color(red: 1.0, green: 0.67, blue: 0.24)
    static let danger = Color(red: 0.95, green: 0.31, blue: 0.31)
    static let panel = Color.black.opacity(0.56)
    static let panelStroke = Color.white.opacity(0.14)
    static let strongPanelStroke = Color.white.opacity(0.22)
    static let inactiveControl = Color.primary.opacity(0.09)
    static let contextCard = Color.primary.opacity(0.065)
    static let contextCardSelected = accent.opacity(0.14)
    static let subtleDivider = Color.white.opacity(0.10)

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
