import SwiftUI

struct OverlayLegendView: View {
    let overlay: DataOverlay

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(overlay.title.uppercased(), systemImage: overlay.symbol)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
            HStack(spacing: 12) {
                legendDot(.green, label: positiveLabel)
                legendDot(.yellow, label: "Watch")
                legendDot(.red, label: negativeLabel)
            }
        }
        .padding(10)
        .frame(width: 220, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.1)))
    }

    private var positiveLabel: String {
        switch overlay {
        case .traffic: "Flowing"
        case .utilities: "Supplied"
        case .pollution: "Clean"
        default: "Strong"
        }
    }

    private var negativeLabel: String {
        switch overlay {
        case .traffic: "Congested"
        case .utilities: "Shortfall"
        case .pollution: "Polluted"
        default: "Weak"
        }
    }

    private func legendDot(_ color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
