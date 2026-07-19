import SwiftUI

struct MetricCard: View {
    let identifier: String
    let title: String
    let value: String
    let symbol: String
    var tint: Color = .primary
    var detail: String? = nil
    var progress: Double? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 27, height: 27)
                        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(0.65)
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                if let detail {
                    Text(detail)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let progress {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.primary.opacity(0.10))
                            Capsule()
                                .fill(tint)
                                .frame(width: proxy.size.width * min(1, max(0, progress)))
                        }
                    }
                    .frame(height: 3)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .frame(minHeight: 52)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .frame(minWidth: 104, maxWidth: .infinity, alignment: .leading)
        .background(GameTheme.contextCard.opacity(0.42), in: RoundedRectangle(cornerRadius: 10))
        .help("Open \(title.lowercased()) details")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue([value, detail].compactMap { $0 }.joined(separator: ", "))
        .accessibilityIdentifier(identifier)
    }
}
