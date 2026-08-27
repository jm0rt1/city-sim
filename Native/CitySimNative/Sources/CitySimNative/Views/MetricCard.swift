import SwiftUI

struct MetricCard: View {
    let identifier: String
    let title: String
    var shortTitle: String? = nil
    let value: String
    let symbol: String
    var tint: Color = .primary
    var detail: String? = nil
    var progress: Double? = nil
    var dense = false
    let action: () -> Void

    static let criticalTextSize = GameTheme.hudCriticalTextSize
    static let supportTextSize = GameTheme.hudSupportTextSize

    var body: some View {
        Button(action: action) {
            if dense {
                denseContent
            } else {
                regularContent
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: dense ? 60 : 104, maxWidth: .infinity, alignment: .leading)
        .background(GameTheme.hudRaisedFill, in: RoundedRectangle(cornerRadius: 9))
        .help("Open \(title.lowercased()) details")
        .accessibilityLabel(title)
        .accessibilityValue([value, detail].compactMap { $0 }.joined(separator: ", "))
        .accessibilityIdentifier(identifier)
    }

    private var denseContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 3) {
                Text((shortTitle ?? title).uppercased())
                    .font(.system(size: Self.criticalTextSize, weight: .bold, design: .rounded))
                    .tracking(0.15)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(.system(size: GameTheme.hudMetricValueTextSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .font(.system(size: Self.supportTextSize, weight: .semibold, design: .rounded))
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
                .frame(height: 2)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, minHeight: GameTheme.controlMinimum, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 9))
    }

    private var regularContent: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: Self.criticalTextSize, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 19, height: 19)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
                Text(title.uppercased())
                    .font(.system(size: Self.criticalTextSize, weight: .bold, design: .rounded))
                    .tracking(0.15)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)

            if let detail {
                Text(detail)
                    .font(.system(size: Self.supportTextSize, weight: .semibold, design: .rounded))
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
        .padding(.vertical, 2)
        .frame(minHeight: 52)
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}
