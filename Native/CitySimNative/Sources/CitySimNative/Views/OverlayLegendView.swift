import SwiftUI

struct OverlayLegendView: View {
    let overlay: DataOverlay

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(overlay.title.uppercased(), systemImage: overlay.symbol)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
            HStack(spacing: 12) {
                legendItem("checkmark.circle.fill", color: .green, label: positiveLabel)
                legendItem("exclamationmark.triangle.fill", color: .yellow, label: "Watch")
                legendItem("xmark.octagon.fill", color: .red, label: negativeLabel)
            }
        }
        .padding(10)
        .frame(width: 220, alignment: .leading)
        .cityPanelBackground(.ultraThin, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(GameTheme.panelStroke))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(overlay.title) layer legend")
    }

    private var positiveLabel: String {
        switch overlay {
        case .traffic: "Flowing"
        case .utilities: "Supplied"
        case .services: "Covered"
        case .pollution: "Clean"
        case .roadCondition: "Maintained"
        default: "Strong"
        }
    }

    private var negativeLabel: String {
        switch overlay {
        case .traffic: "Congested"
        case .utilities: "Shortfall"
        case .services: "Unserved"
        case .pollution: "Polluted"
        case .roadCondition: "Damaged"
        default: "Weak"
        }
    }

    private func legendItem(_ symbol: String, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
