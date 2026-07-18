import SwiftUI

enum GameTheme {
    static let accent = Color(red: 0.23, green: 0.78, blue: 0.68)
    static let warning = Color(red: 1.0, green: 0.67, blue: 0.24)
    static let danger = Color(red: 0.95, green: 0.31, blue: 0.31)
    static let panel = Color.black.opacity(0.56)
}

extension Double {
    var currencyText: String {
        formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    var percentText: String {
        formatted(.number.precision(.fractionLength(0))) + "%"
    }
}

extension Int {
    var compactText: String {
        formatted(.number.notation(.compactName))
    }
}
